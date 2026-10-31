#' @importFrom adorn := decorator
#' @importFrom rlang abort
NULL

#' Stop calling a function that keeps failing
#'
#' Decorator that stops calling a function after it fails repeatedly, so callers
#' fail fast instead of waiting on something that is down. It has three states:
#'
#' * **closed**: calls go through. Consecutive errors are counted.
#' * **open**: after `failures` consecutive errors, calls fail immediately with
#'   a `garnish_circuit_open` error, without running the function, for
#'   `reset_after` seconds.
#' * **half-open**: once the cooldown has passed, the next call runs as a trial.
#'   If it succeeds the circuit closes. If it fails the circuit opens again for
#'   another cooldown.
#'
#' Only errors count as failures. A call that returns normally, whatever its
#' value, resets the count. Each decorated function keeps its own state.
#'
#' Stack it outside [retry()] so an open circuit rejects a call before any
#' retries happen:
#'
#' ```r
#' fetch := circuit_breaker(failures = 3, reset_after = 30) %@%
#'   retry(stop = stop_after_attempt(3)) %@%
#'   function(url) { ... }
#' ```
#'
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
#' @rdname circuit_breaker
#' @usage NULL
#' @export
circuit_breaker := decorator(
  function(f, failures = 5, reset_after = 30) {
    stopifnot(
      "`failures` must be a single whole number of at least 1" =
        is.numeric(failures) && length(failures) == 1L && !is.na(failures) &&
          failures >= 1 && failures == round(failures),
      "`reset_after` must be a single number greater than 0" =
        is.numeric(reset_after) && length(reset_after) == 1L &&
          !is.na(reset_after) && reset_after > 0
    )
    status <- "closed"
    count <- 0L
    opened_at <- NA_real_
    function(...) {
      if (status == "open") {
        if (proc.time()[["elapsed"]] - opened_at < reset_after) {
          abort(
            "Circuit is open: the function failed repeatedly and is not being called.",
            class = "garnish_circuit_open",
            call = NULL
          )
        }
        status <<- "half_open"
      }
      outcome <- tryCatch(
        list(res = withVisible(f(...)), error = NULL),
        error = function(err) list(res = NULL, error = err)
      )
      if (!is.null(outcome$error)) {
        count <<- count + 1L
        if (status == "half_open" || count >= failures) {
          status <<- "open"
          opened_at <<- proc.time()[["elapsed"]]
          count <<- 0L
        }
        stop(outcome$error)
      }
      status <<- "closed"
      count <<- 0L
      if (outcome$res$visible) {
        outcome$res$value
      } else {
        invisible(outcome$res$value)
      }
    }
  }
)
