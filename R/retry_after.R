#' @include retry_utils.R

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
#' * `after_sleep_log()` passes a message describing the attempt to `logger`.
#'
#' @param logger Function taking a single message string. Defaults to [message()].
#' @return A hook to pass to [retry()].
#' @examples
#' after_sleep_log(function(msg) cat(msg, "\n"))
#' @rdname after_sleep
#' @export
after_sleep_none := new_class(parent = after_sleep_base)

#' @rdname after_sleep
#' @export
after_sleep_log := new_class(
  parent = after_sleep_base,
  properties = list(
    logger = new_property(class_function, default = quote(message))
  )
)

method(after_sleep_fn, after_sleep_none) <- function(class, state, ...) {
  invisible(NULL)
}

method(after_sleep_fn, after_sleep_log) <- function(class, state, ...) {
  class@logger(sprintf(
    "Slept %.2f seconds after attempt %d. Retrying.",
    state$wait,
    state$attempt
  ))
  invisible(NULL)
}
