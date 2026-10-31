#' @importFrom adorn := decorator

#' @include retry_stop.R retry_wait.R retry_retry.R retry_before.R retry_after.R
NULL

#' Retry a function when it fails
#'
#' Decorator that calls a function again until it succeeds or a [stop condition][stop_never]
#' condition is met, sleeping between attempts. Port of Python's tenacity.
#'
#' Call `retry(stop, wait, retry, before_sleep, after_sleep, reraise,
#' retry_error_callback)` to build a decorator, then apply it with `%@%` or by
#' calling it on a function.
#'
#' @param stop A stop condition, e.g. [stop_after_attempt()]. Defaults to never stopping.
#' @param wait A [wait strategy][wait_fixed]. Defaults to no waiting.
#' @param retry A [retry condition][retry_all]. Defaults to retrying every error.
#' @param before_sleep,after_sleep Hooks run before and after each sleep, see
#'   [before_sleep_log()] and [after_sleep_log()].
#' @param reraise If `TRUE`, re-throw the last error when `stop` fires instead of
#'   throwing a `retry_error`.
#' @param retry_error_callback Optional function called with the final state when
#'   `stop` fires. Its return value is returned instead of throwing. The state is a list
#'   with `attempt`, `wait`, `elapsed`, `error` and `value`.
#' @return A decorator. The decorated function returns the first acceptable result,
#'   or signals a `retry_error` condition (with `$attempt`, `$error` and `$value`)
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
#' f <- retry(stop = stop_after_attempt(3), wait = wait_exp(min = 0.1)) %@% function() 1
#' f()
#' @rdname retry
#' @usage NULL
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
    stopifnot(
      is.null(retry_error_callback) || is.function(retry_error_callback)
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
        if (!retry_fn(retry, outcome)) {
          if (!is.null(outcome$error)) {
            cnd_signal(outcome$error)
          }
          return(outcome$value)
        }
        wait_time <- wait_fn(wait, attempt, prev_wait)
        state <- list(
          attempt = attempt,
          wait = wait_time,
          elapsed = proc.time()[["elapsed"]] - start,
          error = outcome$error,
          value = outcome$value
        )
        if (stop_fn(stop, state)) {
          if (!is.null(retry_error_callback)) {
            return(retry_error_callback(state))
          }
          if (reraise && !is.null(state$error)) {
            cnd_signal(state$error)
          }
          cnd_signal(retry_error(state))
        }
        before_sleep_fn(before_sleep, state)
        Sys.sleep(wait_time)
        after_sleep_fn(after_sleep, state)
        prev_wait <- wait_time
      }
    }
  }
)
