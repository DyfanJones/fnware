#' @importFrom S7 := new_class new_object new_property new_generic S7_dispatch
#' @importFrom S7 method<- class_any class_numeric class_character class_list
#' @importFrom S7 class_function S7_inherits
#' @importFrom stats runif

MAX_TIME <- 2^63 / 2

# validator functions
validator_non_negative <- function(value) {
  if (length(value) != 1L || is.na(value) || value < 0) {
    "must be a single number greater than or equal to 0"
  }
}

validator_jitter <- function(value) {
  if (
    length(value) != 1L ||
      !value %in% c("full", "equal", "decorrelated", "none")
  ) {
    "must be one of 'full', 'equal', 'decorrelated' or 'none'"
  }
}


validator_wait_strategies <- function(value) {
  if (length(value) == 0L) {
    "must contain at least one wait strategy"
  } else if (!all(vapply(value, S7_inherits, logical(1), class = wait_base))) {
    "must only contain wait strategies"
  }
}

validator_stop_combinator <- function(value) {
  if (!all(vapply(value, S7_inherits, logical(1), class = stop_base))) {
    "must only contain stop conditions"
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

# Decide what `retry()` and `async_retry()` do after an attempt, so the two
# loops cannot drift apart. `cfg` is `list(stop, wait, retry, reraise,
# retry_error_callback)`. Returns one of:
#   list(action = "return", value = )        finish with this value
#   list(action = "signal", error = )        finish by signalling this condition
#   list(action = "sleep", wait =, state = ) wait, then try again
retry_decide <- function(outcome, attempt, prev_wait, start, cfg) {
  if (!retry_fn(cfg$retry, outcome)) {
    if (!is.null(outcome$error)) {
      return(list(action = "signal", error = outcome$error))
    }
    return(list(action = "return", value = outcome$value))
  }
  wait_time <- wait_fn(cfg$wait, attempt, prev_wait)
  state <- list(
    attempt = attempt,
    wait = wait_time,
    elapsed = proc.time()[["elapsed"]] - start,
    error = outcome$error,
    value = outcome$value
  )
  if (stop_fn(cfg$stop, state)) {
    if (!is.null(cfg$retry_error_callback)) {
      return(list(action = "return", value = cfg$retry_error_callback(state)))
    }
    if (cfg$reraise && !is.null(state$error)) {
      return(list(action = "signal", error = state$error))
    }
    return(list(action = "signal", error = retry_error(state)))
  }
  list(action = "sleep", wait = wait_time, state = state)
}
