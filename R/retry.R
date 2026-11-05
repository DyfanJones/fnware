#' @importFrom adorn := decorator

#' @include retry_stop.R retry_wait.R retry_retry.R retry_before.R retry_after.R
NULL

#' Retry a function when it fails
#'
#' Decorator that calls a function again until it succeeds or a [stop condition][stop_never]
#' is met, sleeping between attempts. Port of Python's tenacity.
#'
#' Call `retry(stop, wait, retry, before_sleep, after_sleep, reraise,
#' retry_error_callback)` to build a decorator, then apply it with `%@%` or by
#' calling it on a function.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param stop A stop condition, e.g. [stop_after_attempt()]. Defaults to never stopping.
#' @param wait A [wait strategy][wait_fixed]. Defaults to no waiting.
#' @param retry A [retry condition][retry_all]. Defaults to retrying every error.
#' @param before_sleep,after_sleep Hooks run before and after each sleep, see
#'   [before_sleep_log()] and [after_sleep_log()].
#' @param reraise If `TRUE`, re-throw the last error when `stop` fires instead of
#'   throwing a `fnware_retry_error`.
#' @param retry_error_callback Optional function called with the final state when
#'   `stop` fires. Its return value is returned instead of throwing. The state is a list
#'   with `attempt`, `wait`, `elapsed`, `error` and `value`.
#' @return A decorator. The decorated function returns the first acceptable result,
#'   or signals a `fnware_retry_error` condition (with `$attempt`, `$error` and `$value`)
#'   once `stop` fires.
#' @examples
#' n <- 0
#' flaky <- function() {
#'   n <<- n + 1
#'   if (n < 3) stop("not yet")
#'   n
#' }
#' retry(stop = stop_after_attempt(5))(flaky)()
#'
#' # Back off exponentially between attempts
#' f := retry(stop = stop_after_attempt(3), wait = wait_exp(min = 0.1)) %@% function() 1
#' f()
#' @rdname retry
#' @usage retry(
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
retry := decorator(
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
      repeat {
        attempt <- attempt + 1L
        outcome <- tryCatch(
          list(value = f(...), error = NULL),
          error = function(err) list(value = NULL, error = err)
        )
        step <- retry_decide(outcome, attempt, prev_wait, start, cfg)
        if (step$action == "return") {
          return(step$value)
        }
        if (step$action == "signal") {
          cnd_signal(step$error)
        }
        before_sleep_fn(before_sleep, step$state)
        Sys.sleep(step$wait)
        after_sleep_fn(after_sleep, step$state)
        prev_wait <- step$wait
      }
    }
  }
)
