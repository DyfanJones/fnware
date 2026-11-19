#' @include retry_utils.R log_logger.R

#' @rdname extending_retry
#' @export
after_sleep_base := new_class(abstract = TRUE)

#' @rdname extending_retry
#' @export
after_sleep_fn := new_generic("class", function(class, state, ...) {
  S7_dispatch()
})

#' Run a hook after [retry()] sleeps
#'
#' * `after_sleep_none()` does nothing.
#' * `after_sleep_log()` logs a message describing the attempt with `logger`.
#'
#' @param logger A [logger][logger_base], such as [logger_message()]. Defaults
#'   to `logger_base()`. See [extending_log] to use a logging package.
#' @param level The level the message is logged at: one of `"trace"`,
#'   `"debug"`, `"info"`, `"warn"`, `"error"` or `"fatal"`. A hook logs a single
#'   event, so this is one string, unlike the [log_levels()] of [log_call()].
#' @return A hook to pass to [retry()].
#' @examples
#' after_sleep_log(logger_message(), level = "info")
#' @rdname after_sleep
#' @export
after_sleep_none := new_class(parent = after_sleep_base)

#' @rdname after_sleep
#' @export
after_sleep_log := new_class(
  parent = after_sleep_base,
  properties = list(
    logger = logger_property(),
    level = level_property("level", "info")
  )
)

method(after_sleep_fn, after_sleep_none) <- function(class, state, ...) {
  invisible(NULL)
}

method(after_sleep_fn, after_sleep_log) <- function(class, state, ...) {
  logger_fn(
    class@logger,
    prop(class@logger, class@level),
    sprintf(
      "Slept %.2f seconds after attempt %d. Retrying.",
      state$wait,
      state$attempt
    )
  )
  invisible(NULL)
}
