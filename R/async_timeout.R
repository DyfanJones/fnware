#' @importFrom adorn := decorator decorator_context
#' @importFrom rlang abort
#' @include timeout_utils.R timeout_method.R async_utils.R
NULL

#' Bound how long an asynchronous call can take
#'
#' Asynchronous version of [timeout()], for functions that return a
#' [promise][promises::promise]. If the promise has not settled after `seconds`,
#' the promise returned by the decorated function rejects with a
#' `fnware_timeout_error`, so [async_retry()] retries it.
#'
#' The wrapped function may return a promise or a plain value. A thrown error
#' rejects the promise. Limits:
#'
#' * It does not stop the work. The caller is told, but the underlying request
#'   or task keeps running. A custom method can cancel it.
#' * It cannot bound a function that blocks the session before returning its
#'   promise, as the timer needs the event loop. Use [timeout()] for that.
#' * Nested `async_timeout()`s each run their own timer, so the soonest rejects
#'   first. There is no shared deadline like [timeout_remaining()].
#'
#' Needs the promises and later packages, and an event loop.
#'
#' @section Timeout methods:
#' `method` decides how the limit is enforced. `async_timeout_later()`, the only
#' built-in, races the promise against a [later::later()] timer. To write your
#' own, make an S7 class inheriting from `async_timeout_base` and register a
#' method for `async_timeout_fn(class, call, seconds)`. `call()` starts the work
#' and returns a promise. The method must return a promise that settles with
#' its result, or rejects with a `fnware_timeout_error` once `seconds` pass.
#' `async_timeout()` adds the function name and limit, and signals a
#' `fnware_timeout_method_error` if the method does not return a promise.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param seconds Time limit for one call, in seconds. A number greater than 0.
#' @param method How to enforce the limit, e.g. `async_timeout_later()`.
#' @param class An async timeout method object, which methods dispatch on.
#' @param call A function of no arguments that starts the work and returns a
#'   promise.
#' @param ... Passed to methods.
#' @return `async_timeout()` returns a decorator whose decorated function returns
#'   a promise. `async_timeout_later()` returns a method, and
#'   `async_timeout_fn()` returns a promise.
#' @examples
#' \dontrun{
#' # A stand-in for a slow request: resolves after `delay` seconds
#' slow_request <- function(delay) {
#'   promises::promise(function(resolve, reject) {
#'     later::later(function() resolve("response"), delay)
#'   })
#' }
#'
#' f := async_timeout(0.1) %@% slow_request
#' promises::then(
#'   f(1),
#'   onFulfilled = function(value) cat("got", value, "\n"),
#'   onRejected = function(err) cat("failed:", conditionMessage(err), "\n")
#' )
#' while (!later::loop_empty()) later::run_now(0.1)
#'
#' # Cap each attempt of an async_retry()
#' fetch := async_retry(stop = stop_after_attempt(3), wait = wait_exp()) %@%
#'   async_timeout(5) %@%
#'   function(url) slow_request(1)
#' }
#' @rdname async_timeout
#' @usage async_timeout(f, seconds, method = async_timeout_later())
#' @export
async_timeout := decorator(
  function(f, seconds, method = async_timeout_later()) {
    check_async("async_timeout")
    check_number(seconds, gt = 0)
    check_s7(
      method,
      async_timeout_base,
      "an async timeout method, e.g. `async_timeout_later()`"
    )
    name <- decorator_context()$name
    function(...) {
      call <- function() call_as_promise(f, ...)
      p <- tryCatch(
        async_timeout_fn(method, call, seconds),
        error = promises::promise_reject
      )
      if (!promises::is.promise(p)) {
        abort(
          c(
            "The `method` of `async_timeout()` broke its contract.",
            i = "It must return a promise."
          ),
          class = "fnware_timeout_method_error",
          call = NULL
        )
      }
      promises::catch(p, function(err) {
        if (inherits(err, "fnware_timeout_error") && !isTRUE(err$finalised)) {
          err <- timeout_cnd(name, seconds)
        }
        promises::promise_reject(err)
      })
    }
  }
)

#' @rdname async_timeout
#' @export
async_timeout_base := new_class(abstract = TRUE)

#' @rdname async_timeout
#' @export
async_timeout_fn := new_generic("class", function(class, call, seconds, ...) {
  S7_dispatch()
})

#' @rdname async_timeout
#' @export
async_timeout_later := new_class(parent = async_timeout_base)

method(async_timeout_fn, async_timeout_later) <- function(
  class,
  call,
  seconds,
  ...
) {
  promises::promise(function(resolve, reject) {
    cancel <- later::later(
      function() {
        reject(rlang::error_cnd(
          "fnware_timeout_error",
          message = "Reached the time limit.",
          call = NULL
        ))
      },
      delay = seconds
    )
    promises::then(
      call(),
      onFulfilled = function(value) {
        cancel()
        resolve(value)
      },
      onRejected = function(err) {
        cancel()
        reject(err)
      }
    )
  })
}
