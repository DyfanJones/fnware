#' @importFrom adorn := decorator
#' @include rate_limit.R async_utils.R
NULL

#' Limit how often an asynchronous function can be called
#'
#' Asynchronous version of [rate_limit()]. It allows at most `calls` calls to
#' start in any window of `period` seconds, but a call over the limit is
#' scheduled with [later::later()] instead of sleeping, so the session carries
#' on. The decorated function returns a [promise][promises::promise] that
#' follows the wrapped function's result, a plain value or a promise.
#'
#' Each call reserves its slot when it is made, so calls start in order and
#' queued calls count toward the limit. As with [rate_limit()], an error still
#' uses its slot. It limits when calls start, not how many run, so slow calls can
#' overlap. Stack it inside [async_retry()] to throttle every attempt.
#'
#' Needs the promises and later packages, and an event loop.
#'
#' @inheritParams rate_limit
#' @return A decorator. The decorated function returns a promise.
#' @examples
#' \dontrun{
#' f <- async_rate_limit(calls = 2, period = 0.2) %@% function(i) i
#' start <- Sys.time()
#' for (i in 1:4) {
#'   local({
#'     i <- i
#'     promises::then(f(i), function(value) {
#'       cat("call", value, "at", round(as.numeric(Sys.time() - start), 1), "s\n")
#'     })
#'   })
#' }
#' while (!later::loop_empty()) later::run_now(0.05)
#' }
#' @rdname async_rate_limit
#' @usage async_rate_limit(f, calls, period = 1)
#' @export
async_rate_limit := decorator(
  function(f, calls, period = 1) {
    check_async("async_rate_limit")
    check_number(calls, ge = 1, whole = TRUE)
    check_number(period, gt = 0)
    # Start times, oldest first, of calls inside the window. Calls that are
    # waiting have reserved a start time in the future.
    starts <- numeric()
    function(...) {
      now <- proc.time()[["elapsed"]]
      starts <<- starts[starts > now - period]
      n <- length(starts)
      # The earliest moment that fewer than `calls` starts are in the window,
      # and never before a call that is already queued.
      at <- if (n < calls) now else starts[[n - calls + 1L]] + period
      at <- max(at, now, if (n) starts[[n]] else 0)
      starts <<- c(starts, at)

      run <- function() call_as_promise(f, ...)
      if (at <= now) {
        return(run())
      }
      promises::promise(function(resolve, reject) {
        later::later(
          function() tryCatch(resolve(run()), error = reject),
          delay = at - now
        )
      })
    }
  }
)
