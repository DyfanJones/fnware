#' Write your own stop, wait, retry and hook strategies
#'
#' [retry()] is built from five kinds of strategy. Each has an abstract base
#' class and a generic function, both exported, so you can add your own the same
#' way the built-in ones are written with S7:
#'
#' | `retry()` argument | Base class | Generic | The method returns |
#' |---|---|---|---|
#' | `stop` | `stop_base` | `stop_fn(class, state)` | `TRUE` to give up |
#' | `wait` | `wait_base` | `wait_fn(class, attempt, prev_wait)` | seconds to sleep |
#' | `retry` | `retry_base` | `retry_fn(class, outcome)` | `TRUE` to try again |
#' | `before_sleep` | `before_sleep_base` | `before_sleep_fn(class, state)` | nothing |
#' | `after_sleep` | `after_sleep_base` | `after_sleep_fn(class, state)` | nothing |
#'
#' To add a strategy, make a class that inherits from the base class, then
#' register a method for the generic with [S7::method<-()]. Create the object
#' with `new_object()` on an instance of the base class, as the built-in
#' strategies do. Load S7 with `library(S7)` to get `new_class()`,
#' `new_object()` and `method<-`.
#'
#' Strategies of the same kind compose with the built-in ones. A new wait works
#' in [wait_chain()] and with `+`, and a new stop works in [stop_any()] and
#' [stop_all()].
#'
#' If you register methods from another package, call [S7::methods_register()]
#' in its `.onLoad()`.
#'
#' @section Arguments passed to methods:
#' * `state`, for `stop_fn()`, `before_sleep_fn()` and `after_sleep_fn()`, is a
#'   list describing the attempt that just failed: `attempt` (1-based), `wait`
#'   (seconds `retry()` is about to sleep), `elapsed` (seconds since the first
#'   attempt), `error` (the condition caught, or `NULL` if `retry_if_result()`
#'   rejected a returned value) and `value` (the value returned, or `NULL` if
#'   the call errored).
#' * `attempt` and `prev_wait`, for `wait_fn()`, are the 1-based attempt number
#'   and the previous sleep in seconds (`NULL` on the first retry).
#' * `outcome`, for `retry_fn()`, is `list(value, error)` for the attempt that
#'   just finished. `error` is `NULL` when the call returned normally, and
#'   `value` is `NULL` when it errored.
#'
#' @param class A strategy object. Methods are dispatched on this argument.
#' @param state,outcome,attempt,prev_wait Described above.
#' @param ... Passed to methods.
#' @return `stop_fn()` and `retry_fn()` return a single `TRUE` or `FALSE`,
#'   `wait_fn()` returns a number of seconds, and the hook generics return
#'   nothing useful.
#' @examples
#' library(S7)
#'
#' # Wait `step` seconds longer after each failure
#' wait_linear <- new_class(
#'   "wait_linear",
#'   parent = wait_base,
#'   properties = list(step = class_numeric),
#'   constructor = function(step = 1) new_object(wait_base(), step = step)
#' )
#'
#' method(wait_fn, wait_linear) <- function(class, attempt, prev_wait = NULL, ...) {
#'   class@step * attempt
#' }
#'
#' f <- retry(
#'   stop = stop_after_attempt(3),
#'   wait = wait_linear(0.01) + wait_fixed(0.01)
#' ) %@% function() stop("flaky")
#' try(f(), silent = TRUE)
#' @name extending_retry
#' @aliases stop_base wait_base retry_base before_sleep_base after_sleep_base
#' @aliases stop_fn wait_fn retry_fn before_sleep_fn after_sleep_fn
NULL
