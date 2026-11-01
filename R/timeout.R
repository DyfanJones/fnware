#' @importFrom adorn := decorator decorator_context
#' @importFrom rlang abort cnd_signal
#' @include timeout_method.R timeout_utils.R
NULL

# Absolute deadlines (in `proc.time()` elapsed seconds) of the timeouts that are
# currently running, outermost first. The effective deadline is the minimum.
.timeout_state <- new.env(parent = emptyenv())
.timeout_state$deadlines <- numeric()

elapsed_now <- function() proc.time()[["elapsed"]]

# Re-arm the limit for the timeouts that enclose the one that just finished, or
# leave it cleared if there are none.
restore_time_limit <- function(deadlines) {
  if (length(deadlines)) {
    remaining <- min(deadlines) - elapsed_now()
    # A limit of 0 or less would mean "no limit", so use a tiny positive one.
    setTimeLimit(elapsed = max(remaining, 1e-3), transient = TRUE)
  }
}

# Seconds left before a deadline passed in by a parent process through the
# `GARNISH_TIMEOUT_DEADLINE` environment variable (seconds since the epoch), or
# `Inf` if there is none.
inherited_remaining <- function() {
  deadline <- suppressWarnings(
    as.numeric(Sys.getenv("GARNISH_TIMEOUT_DEADLINE", NA_character_))
  )
  if (is.na(deadline)) {
    return(Inf)
  }
  max(deadline - as.numeric(Sys.time()), 0)
}

is_time_limit_error <- function(cnd) {
  grepl("reached elapsed time limit", conditionMessage(cnd), fixed = TRUE)
}

#' Bound how long a call can run
#'
#' Decorator that stops a single call after `seconds` and signals a
#' `garnish_timeout_error`. Unlike [stop_after_delay()], which only checks between
#' attempts, it bounds the call itself.
#'
#' The condition inherits from `error`, so [retry_if_error()] retries it and
#' [circuit_breaker()] counts it as a failure. It records the limit in `$limit`
#' and the function name in `$fn`. Stack `timeout()` inside [retry()] so each
#' attempt is capped. Outside `retry()` the limit is already spent when the
#' error is caught, so later attempts run unbounded.
#'
#' Timeouts can nest. The soonest active deadline always applies, so an inner
#' timeout never outlasts an outer one. `timeout_remaining()` returns the seconds
#' left before that deadline, or `Inf` outside any `timeout()`, so you can pass
#' the budget to a library with its own timeout. It does not see deadlines in
#' other R processes unless a method passes one on, see [timeout_fn()].
#'
#' For functions that return a promise, use [async_timeout()].
#'
#' @section Limitations:
#' `timeout_r()` uses [setTimeLimit()], which R only checks between R
#' expressions. It cannot interrupt compiled code that never checks for
#' interrupts (many blocking network and database calls), or a single long
#' `Sys.sleep()`. For those, pass `timeout_remaining()` to a native timeout or
#' use a process-based method. Code that catches every error around the slow
#' part will also catch the time limit error.
#'
#' @section Timeout methods:
#' `method` decides how the limit is enforced. `timeout_r()` is the only
#' built-in method. To write your own, see [timeout_fn()].
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param seconds Time limit for one call, in seconds. A number greater than 0.
#' @param method How to enforce the limit: a timeout method such as
#'   `timeout_r()`. See [timeout_fn()] to write your own.
#' @return `timeout()` returns a decorator, `timeout_r()` a timeout method and
#'   `timeout_remaining()` a number of seconds.
#' @examples
#' # A loop of short steps is interrupted between steps
#' slow <- function() {
#'   for (i in 1:100) Sys.sleep(0.05)
#'   "done"
#' }
#' f <- timeout(0.2) %@% slow
#' try(f())
#'
#' # Each attempt is capped, and a timeout is retried
#' attempts <- 0
#' flaky <- retry(stop = stop_after_attempt(3)) %@%
#'   timeout(0.2) %@%
#'   function() {
#'     attempts <<- attempts + 1
#'     if (attempts < 3) slow() else "worked"
#'   }
#' flaky()
#'
#' # Pass the remaining budget on
#' budget <- timeout(10) %@% function() timeout_remaining()
#' budget()
#' @rdname timeout
#' @usage timeout(f, seconds, method = timeout_r())
#' @export
timeout := decorator(
  function(f, seconds, method = timeout_r()) {
    check_number(seconds, gt = 0)
    check_s7(method, timeout_base, "a timeout method, e.g. `timeout_r()`")
    name <- decorator_context()$name
    function(...) {
      start <- elapsed_now()
      outer <- .timeout_state$deadlines
      deadline <- start + seconds
      .timeout_state$deadlines <- c(outer, deadline)
      on.exit({
        .timeout_state$deadlines <- outer
        restore_time_limit(outer)
      })
      bound <- min(outer, start + inherited_remaining())
      enclosing <- bound < deadline
      # Never more than this timeout's own limit, whatever the float rounding.
      remaining <- min(min(bound, deadline) - start, seconds)
      if (remaining <= 0) {
        cnd_signal(timeout_cnd(name, seconds, enclosing))
      }

      res <- NULL
      started <- FALSE
      call <- function() {
        started <<- TRUE
        res <<- withVisible(f(...))
        res$value
      }
      outcome <- tryCatch(
        list(value = timeout_fn(method, call, remaining)),
        garnish_timeout_error = function(err) list(timeout = err)
      )
      if (!is.null(outcome$timeout)) {
        err <- outcome$timeout
        # Already built by an inner `timeout()`: pass it on unchanged.
        if (isTRUE(err$finalised)) {
          stop(err)
        }
        cnd_signal(timeout_cnd(name, seconds, enclosing))
      }
      if (started && (is.null(res) || !identical(outcome$value, res$value))) {
        abort(
          c(
            "The `method` of `timeout()` broke its contract.",
            i = paste(
              "It must return the value of `call()` unchanged,",
              "or signal a `garnish_timeout_error`."
            )
          ),
          class = "garnish_timeout_method_error",
          call = NULL
        )
      }
      if (is.null(res) || res$visible) {
        outcome$value
      } else {
        invisible(outcome$value)
      }
    }
  }
)

#' @rdname timeout
#' @export
timeout_remaining <- function() {
  deadlines <- .timeout_state$deadlines
  local <- if (length(deadlines)) min(deadlines) - elapsed_now() else Inf
  max(min(local, inherited_remaining()), 0)
}
