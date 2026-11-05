#' @importFrom adorn decorator
#' @importFrom rlang abort as_function
#' @include validate.R async_utils.R
NULL

#' Validate the value an asynchronous function resolves to
#'
#' Asynchronous version of [validate_return()], for functions that return a
#' [promise][promises::promise]. The validator checks the resolved value, not
#' the promise. If it fails, the promise returned by the decorated function
#' rejects with a `fnware_validation_error`. Rejections from the wrapped
#' function carry on unchanged. Needs the promises package.
#'
#' Arguments are available at call time, so [validate_args()] works for
#' asynchronous functions as it is.
#'
#' @inheritParams validate_args
#' @return A decorator. The decorated function returns a promise.
#' @examples
#' \dontrun{
#' f := async_validate_return(is.character) %@%
#'   function() promises::promise_resolve(1)
#' promises::catch(f(), function(err) cat(conditionMessage(err), "\n"))
#' while (!later::loop_empty()) later::run_now(0.05)
#' }
#' @export
async_validate_return <- function(validator) {
  validator <- as_function(validator, arg = "validator")
  decorator(
    function(f) {
      check_async("async_validate_return", later = FALSE)
      function(...) {
        promises::then(
          call_as_promise(f, ...),
          onFulfilled = function(value) {
            msg <- validation_failure(validator, value)
            if (!is.null(msg)) {
              abort(
                c("Invalid return value.", x = msg),
                class = "fnware_validation_error",
                call = NULL
              )
            }
            value
          }
        )
      }
    },
    name = "async_validate_return"
  )
}
