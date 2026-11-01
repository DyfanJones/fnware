#' @importFrom adorn := decorator
#' @include retry_stop.R retry_wait.R retry_retry.R retry_before.R retry_after.R retry_utils.R async_utils.R
NULL

#' Retry a function without blocking
#'
#' Asynchronous version of [retry()], for functions that return a
#' [promise][promises::promise]. It uses the same strategies and hooks, but
#' schedules the next attempt with [later::later()] instead of sleeping, so the
#' session is free between attempts.
#'
#' The decorated function returns a promise. It resolves with the first
#' acceptable result, and rejects with the last error, or a `retry_error` once
#' `stop` fires. The wrapped function may return a promise or a plain value, and
#' a rejection or a thrown error counts as a failure.
#'
#' Use it as the outermost decorator. [timeout()] cannot bound a promise, so cap
#' each attempt with [async_timeout()]. The hooks and `retry_error_callback` run
#' in the event loop, so keep them quick. Needs the promises and later packages,
#' and an event loop for the promise to settle.
#'
#' @inheritParams retry
#' @return A decorator. The decorated function returns a promise.
#' @examples
#' \dontrun{
#' n <- 0
#' flaky <- function() {
#'   n <<- n + 1
#'   if (n < 3) stop("not yet")
#'   n
#' }
#' f <- async_retry(stop = stop_after_attempt(5), wait = wait_fixed(0.05)) %@%
#'   flaky
#' promises::then(f(), function(value) cat("worked on attempt", value, "\n"))
#'
#' # Shiny and plumber run the event loop for you. In a script, run it yourself.
#' while (!later::loop_empty()) later::run_now(0.1)
#' }
#' @rdname async_retry
#' @usage async_retry(
#'   f,
#'   stop = stop_never(),
#'   wait = wait_none(),
#'   retry = retry_all(),
#'   before_sleep = before_sleep_none(),
#'   after_sleep = after_sleep_none(),
#'   reraise = FALSE,
#'   retry_error_callback = NULL
#' )
#' @export
async_retry := decorator(
  function(
    f,
    stop = stop_never(),
    wait = wait_none(),
    retry = retry_all(),
    before_sleep = before_sleep_none(),
    after_sleep = after_sleep_none(),
    reraise = FALSE,
    retry_error_callback = NULL
  ) {
    check_async("async_retry")
    check_function(retry_error_callback, null = TRUE)
    cfg <- list(
      stop = stop,
      wait = wait,
      retry = retry,
      reraise = reraise,
      retry_error_callback = retry_error_callback
    )
    function(...) {
      start <- proc.time()[["elapsed"]]
      attempt <- 0L
      prev_wait <- NULL
      promises::promise(function(resolve, reject) {
        # An error in a strategy or hook rejects the promise rather than being
        # lost in the event loop.
        guard <- function(expr) tryCatch(expr, error = reject)

        run_attempt <- function() {
          attempt <<- attempt + 1L
          promises::then(
            call_as_promise(f, ...),
            onFulfilled = function(value) {
              settle(list(value = value, error = NULL))
            },
            onRejected = function(err) {
              settle(list(value = NULL, error = as_condition(err)))
            }
          )
          invisible()
        }

        settle <- function(outcome) {
          guard({
            step <- retry_decide(outcome, attempt, prev_wait, start, cfg)
            if (step$action == "return") {
              resolve(step$value)
            } else if (step$action == "signal") {
              reject(step$error)
            } else {
              before_sleep_fn(before_sleep, step$state)
              later::later(
                function() {
                  guard({
                    after_sleep_fn(after_sleep, step$state)
                    prev_wait <<- step$wait
                    run_attempt()
                  })
                },
                delay = step$wait
              )
            }
          })
          invisible()
        }

        run_attempt()
      })
    }
  }
)

# A promise can reject with any value; strategies expect a condition.
as_condition <- function(x) {
  if (inherits(x, "condition")) {
    x
  } else {
    structure(
      class = c("simpleError", "error", "condition"),
      list(message = paste(format(x), collapse = " "), call = NULL)
    )
  }
}
