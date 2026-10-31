#' @include retry_utils.R

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
#' * `before_sleep_log()` passes a message describing the attempt to `logger`.
#'
#' @param logger Function taking a single message string. Defaults to [message()].
#' @return A hook to pass to [retry()].
#' @examples
#' before_sleep_log(function(msg) cat(msg, "\n"))
#' @rdname before_sleep
#' @export
before_sleep_none := new_class(parent = before_sleep_base)

#' @rdname before_sleep
#' @export
before_sleep_log := new_class(
  parent = before_sleep_base,
  properties = list(logger = class_function),
  constructor = function(logger = message) {
    new_object(before_sleep_base(), logger = logger)
  }
)

method(before_sleep_fn, before_sleep_none) <- function(class, state, ...) {
  invisible(NULL)
}

method(before_sleep_fn, before_sleep_log) <- function(class, state, ...) {
  class@logger(sprintf(
    "Attempt %d failed: %s. Retrying in %.2f seconds.",
    state$attempt,
    describe_failure(state),
    state$wait
  ))
  invisible(NULL)
}
