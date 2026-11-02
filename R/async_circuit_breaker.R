#' @importFrom adorn := decorator
#' @importFrom rlang abort
#' @include circuit_breaker_utils.R async_utils.R
NULL

#' Stop calling an asynchronous function that keeps failing
#'
#' Asynchronous version of [circuit_breaker()], for functions that return a
#' [promise][promises::promise]. It has the same states and arguments. A call
#' fails when its promise rejects, or the function throws. Once the circuit is
#' open, calls return a promise already rejected with `garnish_circuit_open`,
#' without running the function.
#'
#' Calls overlap, so a failure is counted when its promise rejects, and calls
#' made before earlier ones settle all go through. Two more rules:
#'
#' * While half-open, only one trial call runs and others are rejected. A trial
#'   not settled after `reset_after` seconds is abandoned, so a promise that
#'   never settles cannot hold the circuit shut. Put [async_timeout()] inside to
#'   bound it sooner.
#' * A call that started before the circuit opened cannot close it, or be
#'   counted again, when it settles.
#'
#' Stack it outside [async_retry()]. Needs the promises package and an event
#' loop.
#'
#' @inheritParams circuit_breaker
#' @return A decorator. The decorated function returns a promise.
#' @examples
#' \dontrun{
#' down <- function() promises::promise_reject(simpleError("service down"))
#' f := async_circuit_breaker(failures = 2, reset_after = 60) %@% down
#'
#' # Failures are counted when a promise settles, so let each call settle
#' try_once <- function() {
#'   promises::then(f(), onRejected = function(err) cat(class(err)[[1]], "\n"))
#'   while (!later::loop_empty()) later::run_now(0.1)
#' }
#' try_once() # simpleError
#' try_once() # simpleError, and the circuit opens
#' try_once() # garnish_circuit_open, down() was not called
#'
#' fetch := async_circuit_breaker(failures = 3, reset_after = 30) %@%
#'   async_retry(stop = stop_after_attempt(3)) %@%
#'   function(url) down()
#' }
#' @rdname async_circuit_breaker
#' @usage async_circuit_breaker(f, failures = 5, reset_after = 30)
#' @export
async_circuit_breaker := decorator(
  function(f, failures = 5, reset_after = 30) {
    check_async("async_circuit_breaker", later = FALSE)
    check_number(failures, ge = 1, whole = TRUE)
    check_number(reset_after, gt = 0)
    circuit <- circuit_state(failures, reset_after)
    function(...) {
      token <- circuit$enter(exclusive = TRUE)
      if (is.null(token)) {
        return(promises::promise_reject(circuit_open_cnd()))
      }
      promises::then(
        call_as_promise(f, ...),
        onFulfilled = function(value) {
          circuit$succeed(token)
          value
        },
        onRejected = function(err) {
          circuit$fail(token)
          promises::promise_reject(err)
        }
      )
    }
  }
)
