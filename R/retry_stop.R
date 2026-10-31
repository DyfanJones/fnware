#' @include retry_utils.R

#' @rdname extending_retry
#' @export
stop_base := new_class(abstract = TRUE)

# `state` is a list(attempt, wait, elapsed, error, value) built by `retry()`:
#   attempt: 1-based number of the attempt that just failed
#   wait:    seconds `retry()` is about to sleep
#   elapsed: seconds since the first attempt started
#   error:   the condition that was caught, or NULL if the result was rejected
#   value:   the value returned, or NULL if the call errored
#' @rdname extending_retry
#' @export
stop_fn := new_generic("class", function(class, state, ...) {
  S7_dispatch()
})

#' Stop conditions
#'
#' Decide when [retry()] gives up. A condition is checked after each failed attempt.
#'
#' * `stop_never()` never stops.
#' * `stop_after_attempt()` stops after a number of attempts.
#' * `stop_after_delay()` stops once that many seconds have passed since the first attempt.
#' * `stop_before_delay()` stops if sleeping again would reach that many seconds.
#' * `stop_any()` stops when any of the given conditions is met.
#' * `stop_all()` stops when all of the given conditions are met.
#'
#' @param max_attempt_number Number of attempts to allow.
#' @param max_delay Seconds since the first attempt.
#' @param ... Stop conditions to combine.
#' @return A stop condition to pass to [retry()].
#' @examples
#' stop_after_attempt(3)
#' stop_any(stop_after_attempt(5), stop_after_delay(10))
#' @rdname stop_conditions
#' @export
stop_never := new_class(parent = stop_base)

#' @rdname stop_conditions
#' @export
stop_after_attempt := new_class(
  parent = stop_base,
  properties = list(
    max_attempt_number = new_property(
      class_numeric,
      default = 1,
      validator = validator_non_negative
    )
  )
)

#' @rdname stop_conditions
#' @export
stop_after_delay := new_class(
  parent = stop_base,
  properties = list(
    max_delay = new_property(
      class_numeric,
      default = 1,
      validator = validator_non_negative
    )
  )
)

#' @rdname stop_conditions
#' @export
stop_before_delay := new_class(
  parent = stop_base,
  properties = list(
    max_delay = new_property(
      class_numeric,
      default = 1,
      validator = validator_non_negative
    )
  )
)

#' @rdname stop_conditions
#' @export
stop_any := new_class(
  parent = stop_base,
  properties = list(
    stops = new_property(class_list, validator = validator_stop_combinator)
  ),
  constructor = function(...) new_object(stop_base(), stops = list(...))
)

#' @rdname stop_conditions
#' @export
stop_all := new_class(
  parent = stop_base,
  properties = list(
    stops = new_property(class_list, validator = validator_stop_combinator)
  ),
  constructor = function(...) new_object(stop_base(), stops = list(...))
)

method(stop_fn, stop_never) <- function(class, state, ...) {
  FALSE
}

method(stop_fn, stop_after_attempt) <- function(class, state, ...) {
  state$attempt >= class@max_attempt_number
}

method(stop_fn, stop_after_delay) <- function(class, state, ...) {
  state$elapsed >= class@max_delay
}

method(stop_fn, stop_before_delay) <- function(class, state, ...) {
  (state$elapsed + state$wait) >= class@max_delay
}

method(stop_fn, stop_any) <- function(class, state, ...) {
  any(vapply(class@stops, stop_fn, logical(1), state = state))
}

method(stop_fn, stop_all) <- function(class, state, ...) {
  all(vapply(class@stops, stop_fn, logical(1), state = state))
}
