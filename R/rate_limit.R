#' @importFrom adorn decorator
NULL

#' Limit how often a function can be called
#'
#' Decorator that allows at most `calls` calls in any window of `period` seconds.
#' A call that would exceed the limit sleeps until the oldest call in the window
#' has aged out. Calls are counted when they start, so a call that errors still
#' uses up its slot, as it does for an API.
#'
#' Call `rate_limit(calls, period)` to build a decorator, then apply it with `%@%`
#' or by calling it on a function. Each decorated function keeps its own record of
#' calls, so two functions decorated separately have separate limits.
#'
#' Stack it inside [retry()] so that every attempt is throttled, including
#' retries. Stacking it outside would only throttle whole calls, and retries
#' could still exceed the limit.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param calls Maximum number of calls in one window. A whole number of at least 1.
#' @param period Length of the window in seconds. Defaults to 1.
#' @return A decorator.
#' @examples
#' f <- rate_limit(calls = 3, period = 1) %@% function(x) x
#' vapply(1:3, f, numeric(1)) # immediate
#' system.time(f(4)) # waits for the window to clear
#'
#' # Throttle every attempt, retries included
#' fetch <- retry(stop = stop_after_attempt(3)) %@%
#'   rate_limit(calls = 5, period = 1) %@%
#'   function(url) url
#' @rdname rate_limit
#' @usage rate_limit(f, calls, period = 1)
#' @export
rate_limit := decorator(
  function(f, calls, period = 1) {
    check_number(calls, ge = 1, whole = TRUE)
    check_number(period, gt = 0)
    # Start times of calls still inside the window, oldest first.
    starts <- numeric()
    function(...) {
      repeat {
        now <- proc.time()[["elapsed"]]
        starts <<- starts[starts > now - period]
        if (length(starts) < calls) {
          break
        }
        Sys.sleep(starts[[1L]] + period - now)
      }
      starts <<- c(starts, proc.time()[["elapsed"]])
      f(...)
    }
  }
)
