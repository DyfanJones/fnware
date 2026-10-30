#' @importFrom S7 := new_class new_generic S7_dispatch class_integer new_property

MAX_TIME <- 2^63 / 2

above_zero_validator <- function(value) {
  if (value <= 0) {
    "@value must be greater than 0"
  }
}

wait_base := new_class(abstract = T)

#' @export
wait_fixed := new_class(
  parent = wait_base,
  properties = list(wait = class_integer)
)

#' @export
wait_none := new_class(
  parent = wait_fixed,
  constructor = function() {
    parent_obj <- wait_fixed(0L)
    new_object(parent_obj)
  }
)

#' @export
wait_exp := new_class(
  parent = wait_base,
  properties = list(
    multiplier = 1,
    min = new_property(
      class_numeric,
      default = 0,
      validator = above_zero_validator
    ),
    max = new_property(class_numeric, default = MAX_TIME),
    exp_base = new_property(class_numeric, default = 2)
  )
)

#' @export
wait_exp_jitter := new_class(
  parent = wait_base,
  properties = list(
    base = new_property(class_numeric, default = 0.1),
    max_delay = new_property(default = 20),
    jitter = c("full", "equal", "decorrelated", "none"),
    prev_delay = base,
  )
)

#' @export
wait_rand := new_class(
  parent = wait_base,
  properties = list(
    min = new_property(
      class_integer,
      default = 0L,
      validator = above_zero_validator
    ),
    max = new_property(class_integer, default = 1L)
  )
)

wait_fn := new_generic(c("class", "attempt"), function(class, attempt, ...) {
  S7_dispatch()
})

method(wait_fn, wait_fixed) <- function(class, attempt, ...) {
  Sys.sleep(class@wait)
}

method(wait_fn, wait_exp) <- function(x, attempt, ...) {
  wait <- x@multiplier * x@exp_base^(attempt - 1)
  Sys.time(max(x@min, min(wait, x@max)))
}


method(wait_fn, wait_exp_jitter) <- function(
  class,
  attempt,
  ...
) {
  exp <- min(class@max_delay, class@base * 2^attempt)
  wait <- switch(
    class@jitter,
    none = exp,
    full = runif(1, 0, exp),
    equal = exp / 2 + runif(1, 0, exp / 2),
    decorrelated = min(
      class@max_delay,
      runif(1, class@base, class@prev_delay * 3)
    )
  )
  Sys.sleep(wait)
}

method(wait_fn, wait_rand) <- function(class, attempt, ...) {
  wait <- runif(1, min = class@min, class@max)
  Sys.sleep(wait)
}
