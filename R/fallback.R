#' @importFrom adorn := decorator
#' @importFrom rlang try_fetch
NULL

#' Return a default when a function fails
#'
#' Decorator that catches a failure and returns `value`, or the result of
#' `handler(cnd)`, instead of signalling it. Only errors are caught by default.
#' A caught condition ends the call, as with [tryCatch()].
#'
#' Stack it outside [retry()] and [circuit_breaker()] so the default is used only
#' once retries are spent or the circuit is open.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param value Value to return on failure. Ignored if `handler` is given.
#' @param handler Optional function taking the condition and returning the result.
#' @param class Condition classes to catch. Defaults to `"error"`.
#' @return A decorator.
#' @examples
#' f := fallback(value = NA_real_) %@% function(x) {
#'   if (x < 0) stop("negative") else sqrt(x)
#' }
#' f(4)
#' f(-1)
#'
#' g := fallback(handler = function(cnd) conditionMessage(cnd)) %@%
#'   function() stop("boom")
#' g()
#'
#' # Use the default only after retries and the circuit breaker give up
#' fetch := fallback(value = NULL) %@%
#'   circuit_breaker(failures = 3) %@%
#'   retry(stop = stop_after_attempt(3)) %@%
#'   function(url) stop("down")
#' fetch("x")
#' @rdname fallback
#' @usage fallback(f, value = NULL, handler = NULL, class = "error")
#' @export
fallback := decorator(
  function(f, value = NULL, handler = NULL, class = "error") {
    check_function(handler, null = TRUE)
    check_classes(class)
    on_cnd <- function(cnd) if (is.null(handler)) value else handler(cnd)
    handlers <- rep(list(on_cnd), length(class))
    names(handlers) <- class
    function(...) {
      try_fetch(f(...), !!!handlers)
    }
  }
)
