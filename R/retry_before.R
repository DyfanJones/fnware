#' @include retry_utils.R log_logger.R

#' @rdname extending_retry
#' @export
before_sleep_base := new_class(abstract = TRUE)

#' @rdname extending_retry
#' @export
before_sleep_fn := new_generic("class", function(class, state, ...) {
  S7_dispatch()
})

#' Run a hook before [retry()] sleeps
#'
#' * `before_sleep_none()` does nothing.
#' * `before_sleep_log()` logs a message describing the attempt with `logger`.
#'
#' @param logger A [logger][logger_base], such as [logger_message()]. Defaults
#'   to `logger_base()`. See [extending_log] to use a logging package.
#' @param level The level the message is logged at: one of `"trace"`,
#'   `"debug"`, `"info"`, `"warn"`, `"error"` or `"fatal"`. A hook logs a single
#'   event, so this is one string, unlike the [log_levels()] of [log_call()].
#' @return A hook to pass to [retry()].
#' @examples
#' before_sleep_log(logger_message(), level = "info")
#' @rdname before_sleep
#' @export
before_sleep_none := new_class(parent = before_sleep_base)

#' @rdname before_sleep
#' @export
before_sleep_log := new_class(
  parent = before_sleep_base,
  properties = list(
    logger = logger_property(),
    level = level_property("level", "warn")
  )
)

method(before_sleep_fn, before_sleep_none) <- function(class, state, ...) {
  invisible(NULL)
}

method(before_sleep_fn, before_sleep_log) <- function(class, state, ...) {
  logger_fn(
    class@logger,
    prop(class@logger, class@level),
    sprintf(
      "Attempt %d failed: %s. Retrying in %.2f seconds.",
      state$attempt,
      describe_failure(state),
      state$wait
    )
  )
  invisible(NULL)
}
