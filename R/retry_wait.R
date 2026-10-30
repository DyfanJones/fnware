#' @include retry_utils.R

wait_base := new_class(abstract = TRUE)

# `prev_wait` is the previous sleep time (NULL on the first retry) and is only
# used by strategies that depend on it, e.g. decorrelated jitter.
wait_fn := new_generic("class", function(class, attempt, prev_wait = NULL, ...) {
  S7_dispatch()
})

#' Wait strategies
#'
#' Decide how many seconds [retry()] sleeps after a failed attempt.
#'
#' * `wait_none()` does not wait.
#' * `wait_fixed()` waits a fixed time.
#' * `wait_rand()` waits a random time between `min` and `max`.
#' * `wait_exp()` waits `multiplier * exp_base^(attempt - 1)`, kept between `min` and `max`.
#' * `wait_exp_jitter()` waits `base * 2^(attempt - 1)`, capped at `max_delay`, then
#'   applies `jitter`: `"none"`, `"full"` (uniform from 0), `"equal"` (half fixed, half
#'   random) or `"decorrelated"` (random between `base` and 3 times the previous wait).
#' * `wait_chain()` uses the n-th strategy for the n-th attempt, then repeats the last.
#' * `wait_combine()` adds strategies together. `a + b` is the same as `wait_combine(a, b)`.
#'
#' @param wait Seconds to wait.
#' @param min,max Lower and upper bound in seconds.
#' @param multiplier,exp_base Scale and base of the exponential.
#' @param base Seconds to wait on the first attempt.
#' @param max_delay Longest wait in seconds.
#' @param jitter Jitter type, one of `"full"`, `"equal"`, `"decorrelated"` or `"none"`.
#' @param ... Wait strategies to chain or combine.
#' @return A wait strategy to pass to [retry()].
#' @examples
#' wait_fixed(2)
#' wait_exp(multiplier = 0.5, max = 30)
#' wait_chain(wait_fixed(1), wait_fixed(5))
#' wait_fixed(1) + wait_rand(0, 2)
#' @rdname wait_strategies
#' @export
wait_fixed := new_class(
  parent = wait_base,
  properties = list(
    wait = new_property(class_numeric, validator = non_negative_validator)
  )
)

#' @rdname wait_strategies
#' @export
wait_none := new_class(
  parent = wait_fixed,
  constructor = function() new_object(wait_fixed(0))
)

#' @rdname wait_strategies
#' @export
wait_exp := new_class(
  parent = wait_base,
  properties = list(
    multiplier = new_property(class_numeric, default = 1),
    min = new_property(
      class_numeric,
      default = 0,
      validator = non_negative_validator
    ),
    max = new_property(class_numeric, default = MAX_TIME),
    exp_base = new_property(class_numeric, default = 2)
  )
)

jitter_validator <- function(value) {
  if (length(value) != 1L || !value %in% c("full", "equal", "decorrelated", "none")) {
    "must be one of 'full', 'equal', 'decorrelated' or 'none'"
  }
}

#' @rdname wait_strategies
#' @export
wait_exp_jitter := new_class(
  parent = wait_base,
  properties = list(
    base = new_property(
      class_numeric,
      default = 0.1,
      validator = above_zero_validator
    ),
    max_delay = new_property(
      class_numeric,
      default = 20,
      validator = above_zero_validator
    ),
    jitter = new_property(
      class_character,
      default = "full",
      validator = jitter_validator
    )
  )
)

#' @rdname wait_strategies
#' @export
wait_rand := new_class(
  parent = wait_base,
  properties = list(
    min = new_property(
      class_numeric,
      default = 0,
      validator = non_negative_validator
    ),
    max = new_property(class_numeric, default = 1)
  ),
  validator = function(self) {
    if (self@max < self@min) "@max must be greater than or equal to @min"
  }
)

method(wait_fn, wait_fixed) <- function(class, attempt, prev_wait = NULL, ...) {
  class@wait
}

method(wait_fn, wait_exp) <- function(class, attempt, prev_wait = NULL, ...) {
  wait <- class@multiplier * class@exp_base^(attempt - 1)
  max(class@min, min(wait, class@max))
}

method(wait_fn, wait_exp_jitter) <- function(
  class,
  attempt,
  prev_wait = NULL,
  ...
) {
  exp <- min(class@max_delay, class@base * 2^(attempt - 1))
  switch(
    class@jitter,
    none = exp,
    full = runif(1, 0, exp),
    equal = exp / 2 + runif(1, 0, exp / 2),
    decorrelated = min(
      class@max_delay,
      runif(1, class@base, (prev_wait %||% class@base) * 3)
    )
  )
}

method(wait_fn, wait_rand) <- function(class, attempt, prev_wait = NULL, ...) {
  runif(1, class@min, class@max)
}

wait_strategies_validator <- function(value) {
  if (length(value) == 0L) {
    "must contain at least one wait strategy"
  } else if (!all(vapply(value, S7_inherits, logical(1), class = wait_base))) {
    "must only contain wait strategies"
  }
}

#' @rdname wait_strategies
#' @export
wait_chain := new_class(
  parent = wait_base,
  properties = list(
    waits = new_property(class_list, validator = wait_strategies_validator)
  ),
  constructor = function(...) new_object(wait_base(), waits = list(...))
)

#' @rdname wait_strategies
#' @export
wait_combine := new_class(
  parent = wait_base,
  properties = list(
    waits = new_property(class_list, validator = wait_strategies_validator)
  ),
  constructor = function(...) new_object(wait_base(), waits = list(...))
)

method(wait_fn, wait_chain) <- function(class, attempt, prev_wait = NULL, ...) {
  idx <- min(max(attempt, 1L), length(class@waits))
  wait_fn(class@waits[[idx]], attempt, prev_wait)
}

method(wait_fn, wait_combine) <- function(class, attempt, prev_wait = NULL, ...) {
  sum(vapply(class@waits, wait_fn, numeric(1), attempt = attempt, prev_wait = prev_wait))
}

method(`+`, list(wait_base, wait_base)) <- function(e1, e2) {
  wait_combine(e1, e2)
}
