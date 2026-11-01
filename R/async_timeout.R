#' @importFrom adorn := decorator decorator_context
#' @importFrom rlang abort
#' @include retry_utils.R timeout.R
NULL

#' Bound how long an asynchronous call can take
#'
#' Asynchronous version of [timeout()], for functions that return a
#' [promise][promises::promise], such as `httr2::req_perform_promise()` or a
#' [mirai][mirai::mirai] task. If the promise has not settled after `seconds`,
#' the promise returned by the decorated function rejects with a
#' `garnish_timeout_error`, the same condition [timeout()] signals. It records
#' the limit in `$limit` and the function name in `$fn`, so [async_retry()]
#' retries it like any other failure.
#'
#' ```r
#' fetch := async_retry(stop = stop_after_attempt(3), wait = wait_exp()) %@%
#'   async_timeout(5) %@%
#'   function(url) { ... } # returns a promise
#' ```
#'
#' The decorated function always returns a promise. The wrapped function may
#' return a plain value, which resolves at once, or a promise. An error thrown
#' directly by the function rejects the promise.
#'
#' Unlike [timeout()] it does not need to interrupt R, so it works however the
#' promise is produced, but it has limits of its own:
#'
#' * It does not stop the work. When the limit passes the caller is told, but
#'   the underlying request or task keeps running. Use a method that cancels it
#'   if that matters, see below.
#' * It cannot bound a function that blocks the session before returning the
#'   promise. The timer needs the event loop, which a blocked session is not
#'   running. Use [timeout()] for synchronous code.
#' * Nested `async_timeout()`s each run their own timer, so the soonest one
#'   rejects first, but there is no shared deadline to read like
#'   [timeout_remaining()].
#'
#' Like [async_retry()], the promise only settles while an event loop runs.
#' Needs the promises and later packages.
#'
#' @section Timeout methods:
#' `method` decides how the limit is enforced. `async_timeout_later()` is the
#' only built-in method. It races the promise against a [later::later()] timer
#' and cancels the timer once the promise settles.
#'
#' To write your own, for example one that also cancels a mirai task, make an S7
#' class that inherits from `async_timeout_base` and register a method for
#' `async_timeout_fn(class, call, seconds)` with [S7::method<-()]. `call()`
#' starts the work and returns a promise, and `seconds` is the limit. The method
#' must return a promise that settles with the result of `call()`, or rejects
#' with a condition of class `garnish_timeout_error` once `seconds` pass.
#' `async_timeout()` adds the function name and limit to the error, and signals
#' a `garnish_timeout_method_error` if the method does not return a promise.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param seconds Time limit for one call, in seconds. A number greater than 0.
#' @param method How to enforce the limit: a method such as
#'   `async_timeout_later()`. See "Timeout methods".
#' @param class An async timeout method object. Methods are dispatched on this
#'   argument.
#' @param call A function of no arguments that starts the work and returns a
#'   promise.
#' @param ... Passed to methods.
#' @return `async_timeout()` returns a decorator, whose decorated function
#'   returns a promise. `async_timeout_later()` returns a method.
#'   `async_timeout_fn()` returns a promise.
#' @examples
#' if (
#'   requireNamespace("promises", quietly = TRUE) &&
#'     requireNamespace("later", quietly = TRUE)
#' ) {
#'   # A stand-in for a slow request: resolves after `delay` seconds
#'   slow_request <- function(delay) {
#'     promises::promise(function(resolve, reject) {
#'       later::later(function() resolve("response"), delay)
#'     })
#'   }
#'
#'   f <- async_timeout(0.1) %@% slow_request
#'   promises::then(
#'     f(1),
#'     onFulfilled = function(value) cat("got", value, "\n"),
#'     onRejected = function(err) cat("failed:", conditionMessage(err), "\n")
#'   )
#'   while (!later::loop_empty()) later::run_now(0.1)
#' }
#' @rdname async_timeout
#' @usage async_timeout(f, seconds, method = async_timeout_later())
#' @export
async_timeout := decorator(
  function(f, seconds, method = async_timeout_later()) {
    rlang::check_installed(
      c("promises", "later"),
      "to use `async_timeout()`."
    )
    check_number(seconds, gt = 0)
    check_s7(
      method,
      async_timeout_base,
      "an async timeout method, e.g. `async_timeout_later()`"
    )
    name <- decorator_context()$name
    function(...) {
      call <- function() {
        tryCatch(
          promises::promise_resolve(f(...)),
          error = promises::promise_reject
        )
      }
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
          class = "garnish_timeout_method_error",
          call = NULL
        )
      }
      promises::catch(p, function(err) {
        if (inherits(err, "garnish_timeout_error") && !isTRUE(err$finalised)) {
          err <- rlang::error_cnd(
            "garnish_timeout_error",
            message = timeout_message(name, seconds),
            limit = seconds,
            fn = name,
            finalised = TRUE,
            call = NULL
          )
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
          "garnish_timeout_error",
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
