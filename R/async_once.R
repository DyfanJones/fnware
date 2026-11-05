#' @importFrom adorn := decorator
#' @include once.R async_utils.R
NULL

#' Run an asynchronous function only once
#'
#' Asynchronous version of [once()], for functions that return a
#' [promise][promises::promise]. The first call's resolved value is kept and
#' every later call returns a promise of it, ignoring its arguments. Calls made
#' while the first is still running share its promise. A rejection stores
#' nothing, so the next call tries again. Needs the promises package.
#'
#' @inheritParams once
#' @return A decorator. The decorated function returns a promise.
#' @examples
#' \dontrun{
#' setup := async_once %@% function() {
#'   cat("setting up\n")
#'   promises::promise_resolve(42)
#' }
#' promises::then(setup(), print)
#' promises::then(setup(), print) # no second "setting up"
#' while (!later::loop_empty()) later::run_now(0.05)
#' }
#' @rdname async_once
#' @usage async_once(f)
#' @export
async_once := decorator(
  function(f) {
    check_async("async_once", later = FALSE)
    done <- FALSE
    result <- NULL
    running <- NULL
    function(...) {
      if (done) {
        return(promises::promise_resolve(result))
      }
      if (!is.null(running)) {
        return(running)
      }
      running <<- promises::then(
        call_as_promise(f, ...),
        onFulfilled = function(value) {
          result <<- value
          done <<- TRUE
          running <<- NULL
          value
        },
        onRejected = function(err) {
          running <<- NULL
          promises::promise_reject(err)
        }
      )
      running
    }
  }
)
