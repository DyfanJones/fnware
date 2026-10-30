#' @importFrom S7 := new_class new_object new_property new_generic S7_dispatch
#' @importFrom S7 method<- class_any class_numeric class_character class_list
#' @importFrom S7 class_function S7_inherits
#' @importFrom stats runif

MAX_TIME <- 2^63 / 2

non_negative_validator <- function(value) {
  if (length(value) != 1L || is.na(value) || value < 0) {
    "must be a single number greater than or equal to 0"
  }
}

above_zero_validator <- function(value) {
  if (length(value) != 1L || is.na(value) || value <= 0) {
    "must be a single number greater than 0"
  }
}

# Human readable reason for a failed attempt, used by the logging hooks and
# the `retry_error` condition. `state$error` is NULL when the attempt returned
# a value that `retry_if_result()` rejected.
describe_failure <- function(state) {
  if (is.null(state$error)) {
    "unacceptable result"
  } else {
    conditionMessage(state$error)
  }
}

# Condition signalled once `stop` fires and the caller asked neither to
# `reraise` nor supplied a `retry_error_callback`. Mirrors tenacity's
# `RetryError`: catch it with `tryCatch(..., retry_error = )`; the final
# attempt is available as `$error` / `$value`.
retry_error <- function(state) {
  structure(
    class = c("retry_error", "error", "condition"),
    list(
      message = sprintf(
        "Retry failed after %d attempt(s): %s",
        state$attempt,
        describe_failure(state)
      ),
      call = NULL,
      attempt = state$attempt,
      error = state$error,
      value = state$value
    )
  )
}


stop_combinator_validator <- function(value) {
  if (!all(vapply(value, S7_inherits, logical(1), class = stop_base))) {
    "must only contain stop conditions"
  }
}
