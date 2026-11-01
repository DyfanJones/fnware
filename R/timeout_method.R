#' @include retry_utils.R
NULL

#' Write your own timeout method
#'
#' [timeout()] hands the work of enforcing a limit to a *method*. The built-in
#' method is `timeout_r()`, which uses [setTimeLimit()]. To add another, for
#' example one that runs the call in a separate process and kills it, make an S7
#' class that inherits from `timeout_base` and register a method for the
#' `timeout_fn()` generic with [S7::method<-()]. Load S7 with `library(S7)` to
#' get `new_class()` and `method<-`.
#'
#' `timeout_fn(class, call, seconds)` is called with `call`, a function of no
#' arguments that runs the decorated function, and `seconds`, the time left
#' before the effective deadline (the soonest of all enclosing [timeout()]s). It
#' must either return the value of `call()` unchanged, or signal a condition of
#' class `garnish_timeout_error` when `seconds` run out. [timeout()] adds the
#' function name and limit to the message, and signals a
#' `garnish_timeout_method_error` if `call()` ran but the method returned a
#' different value or swallowed its error. Other errors from `call()` should be
#' left to propagate.
#'
#' A method that runs `call()` in another process cannot be checked for the
#' contract, and [timeout_remaining()] only sees deadlines in the process that
#' called [timeout()]. To make it work in the child, set the environment
#' variable `GARNISH_TIMEOUT_DEADLINE` there to the deadline as seconds since
#' the epoch, `as.numeric(Sys.time()) + seconds`. The retry vignette shows a
#' callr method that does this.
#'
#' If you register methods from another package, call [S7::methods_register()]
#' in its `.onLoad()`.
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
#' f <- timeout(3, method = timeout_log()) %@% function() "ok"
#' f()
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
          class = "garnish_timeout_error",
          call = NULL
        )
      }
    }
  )
}
