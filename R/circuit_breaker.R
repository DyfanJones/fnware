#' @importFrom adorn := decorator
#' @importFrom rlang cnd_signal
#' @include circuit_breaker_utils.R
NULL

#' Stop calling a function that keeps failing
#'
#' Decorator that stops calling a function after it fails repeatedly, so callers
#' fail fast instead of waiting on something that is down. It has three states:
#'
#' * **closed**: calls go through. Consecutive errors are counted.
#' * **open**: after `failures` consecutive errors, calls fail immediately with
#'   a `fnware_circuit_open` error, without running the function, for
#'   `reset_after` seconds.
#' * **half-open**: once the cooldown has passed, the next call runs as a trial.
#'   If it succeeds the circuit closes. If it fails the circuit opens again for
#'   another cooldown.
#'
#' Only errors count as failures. A call that returns normally, whatever its
#' value, resets the count. Each decorated function keeps its own state.
#'
#' Stack it outside [retry()] so an open circuit rejects a call before any
#' retries happen.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param failures Number of consecutive errors that open the circuit. A whole
#'   number of at least 1. Defaults to 5.
#' @param reset_after Seconds the circuit stays open before a trial call. A number
#'   greater than 0. Defaults to 30.
#' @return A decorator.
#' @examples
#' n <- 0
#' flaky <- function() {
#'   n <<- n + 1
#'   stop("service down")
#' }
#' f := circuit_breaker(failures = 2, reset_after = 60) %@% flaky
#' try(f())
#' try(f())
#' try(f()) # rejected without calling flaky()
#' n # still 2
#'
#' # Reject before any retries happen
#' fetch := circuit_breaker(failures = 3, reset_after = 30) %@%
#'   retry(stop = stop_after_attempt(3)) %@%
#'   function(url) url
#' @rdname circuit_breaker
#' @usage circuit_breaker(f, failures = 5, reset_after = 30)
#' @export
circuit_breaker := decorator(
  function(f, failures = 5, reset_after = 30) {
    check_number(failures, ge = 1, whole = TRUE)
    check_number(reset_after, gt = 0)
    circuit <- circuit_state(failures, reset_after)
    function(...) {
      token <- circuit$enter()
      if (is.null(token)) {
        cnd_signal(circuit_open_cnd())
      }
      outcome <- tryCatch(
        list(res = withVisible(f(...)), error = NULL),
        error = function(err) list(res = NULL, error = err)
      )
      if (!is.null(outcome$error)) {
        circuit$fail(token)
        stop(outcome$error)
      }
      circuit$succeed(token)
      if (outcome$res$visible) {
        outcome$res$value
      } else {
        invisible(outcome$res$value)
      }
    }
  }
)
