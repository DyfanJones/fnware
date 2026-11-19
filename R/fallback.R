#' @importFrom adorn := decorator decorator_context
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
#' @param logger A [logger][logger_base], such as [logger_message()], that logs
#'   each time the fallback is used, see [extending_log] to use a logging
#'   package. `NULL`, the default, logs nothing.
#' @param level The level of that event: one of `"trace"`, `"debug"`, `"info"`,
#'   `"warn"`, `"error"` or `"fatal"`. Defaults to `"warn"`.
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
#' # Log each time the default is used
#' h := fallback(value = 0, logger = logger_message()) %@%
#'   function() stop("boom")
#' h()
#'
#' # Use the default only after retries and the circuit breaker give up
#' fetch := fallback(value = NULL) %@%
#'   circuit_breaker(failures = 3) %@%
#'   retry(stop = stop_after_attempt(3)) %@%
#'   function(url) stop("down")
#' fetch("x")
#' @rdname fallback
#' @usage fallback(f, value = NULL, handler = NULL, class = "error",
#'   logger = NULL, level = "warn")
#' @export
fallback := decorator(
  function(
    f,
    value = NULL,
    handler = NULL,
    class = "error",
    logger = NULL,
    level = "warn"
  ) {
    check_function(handler, null = TRUE)
    check_classes(class)
    check_logger(logger)
    check_level(level)
    fn <- decorator_context()$name
    on_cnd <- function(cnd) {
      log_fallback(logger, level, fn, cnd)
      if (is.null(handler)) value else handler(cnd)
    }
    handlers <- rep(list(on_cnd), length(class))
    names(handlers) <- class
    function(...) {
      try_fetch(f(...), !!!handlers)
    }
  }
)

# Shared by `fallback()` and `async_fallback()`.
log_fallback <- function(logger, level, fn, cnd) {
  log_event(
    logger,
    level,
    sprintf("Fallback used for %s\n%s", fn, fmt_error(cnd, fn))
  )
}
