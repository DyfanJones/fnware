#' @include retry_utils.R
NULL

#' Write your own timeout method
#'
#' [timeout()] hands the work of enforcing a limit to a *method*. `timeout_r()`,
#' which uses [setTimeLimit()], is the built-in. To add another, for example one
#' that runs the call in a separate process and kills it, make an S7 class that
#' inherits from `timeout_base` and register a method for `timeout_fn()` with
#' [S7::method<-()].
#'
#' `timeout_fn(class, call, seconds)` gets `call`, a function of no arguments
#' that runs the decorated function, and `seconds`, the time left before the
#' effective deadline. It must return the value of `call()` unchanged, or signal
#' a `fnware_timeout_error` when `seconds` run out. [timeout()] adds the
#' function name and limit to the message, and signals a
#' `fnware_timeout_method_error` if `call()` ran but the method returned
#' something else or swallowed its error. Other errors should propagate.
#'
#' A method that runs `call()` in another process cannot be checked for this,
#' and [timeout_remaining()] does not see the parent's deadline there. Set the
#' environment variable `GARNISH_TIMEOUT_DEADLINE` in the child to
#' `as.numeric(Sys.time()) + seconds` to pass it on. The retry vignette shows a
#' callr method that does. Packages that register methods need
#' [S7::methods_register()] in `.onLoad()`.
#'
#' @param class A timeout method object. Methods are dispatched on this argument.
#' @param call A function of no arguments that runs the decorated function.
#' @param seconds Seconds left before the effective deadline.
#' @param ... Passed to methods.
#' @return `timeout_fn()` returns the value of `call()`.
#' @examples
#' library(S7)
#'
#' # Report the time allowed, then run the call without enforcing anything
#' timeout_log <- new_class("timeout_log", parent = timeout_base)
#'
#' method(timeout_fn, timeout_log) <- function(class, call, seconds, ...) {
#'   message("allowing ", format(seconds), " seconds")
#'   call()
#' }
#'
#' f := timeout(3, method = timeout_log()) %@% function() "ok"
#' f()
#' @name extending_timeout
#' @aliases timeout_base timeout_fn
NULL

#' @rdname extending_timeout
#' @export
timeout_base := new_class(abstract = TRUE)

#' @rdname extending_timeout
#' @export
timeout_fn := new_generic("class", function(class, call, seconds, ...) {
  S7_dispatch()
})

#' @rdname timeout
#' @export
timeout_r := new_class(parent = timeout_base)

method(timeout_fn, timeout_r) <- function(class, call, seconds, ...) {
  setTimeLimit(elapsed = seconds, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf, transient = TRUE))
  withCallingHandlers(
    call(),
    error = function(err) {
      if (is_time_limit_error(err)) {
        rlang::abort(
          "Reached the time limit.",
          class = "fnware_timeout_error",
          call = NULL
        )
      }
    }
  )
}
