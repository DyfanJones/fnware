library(S7)

wait_linear <- new_class(
  "wait_linear",
  parent = wait_base,
  properties = list(step = class_numeric),
  constructor = function(step = 1) new_object(wait_base(), step = step)
)
method(wait_fn, wait_linear) <- function(
  class,
  attempt,
  prev_wait = NULL,
  ...
) {
  class@step * attempt
}

stop_on_slow <- new_class(
  "stop_on_slow",
  parent = stop_base,
  properties = list(seconds = class_numeric),
  constructor = function(seconds) new_object(stop_base(), seconds = seconds)
)
method(stop_fn, stop_on_slow) <- function(class, state, ...) {
  state$elapsed >= class@seconds
}

retry_on_negative <- new_class("retry_on_negative", parent = retry_base)
method(retry_fn, retry_on_negative) <- function(class, outcome, ...) {
  is.null(outcome$error) && outcome$value < 0
}

hook_recorder <- new_class(
  "hook_recorder",
  parent = before_sleep_base,
  properties = list(seen = class_any),
  constructor = function(seen) new_object(before_sleep_base(), seen = seen)
)
method(before_sleep_fn, hook_recorder) <- function(class, state, ...) {
  class@seen$fields <- names(state)
  invisible(NULL)
}

test_that("the extension classes and generics are exported", {
  exports <- getNamespaceExports("fnware")
  for (kind in c("stop", "wait", "retry", "before_sleep", "after_sleep")) {
    expect_true(paste0(kind, "_base") %in% exports, info = kind)
    expect_true(paste0(kind, "_fn") %in% exports, info = kind)
  }
})

test_that("a custom wait strategy works and composes", {
  expect_equal(wait_fn(wait_linear(2), 3), 6)
  expect_equal(wait_fn(wait_linear(1) + wait_fixed(2), 3), 5)
  expect_equal(wait_fn(wait_chain(wait_fixed(7), wait_linear(2)), 2), 4)
})

test_that("a custom wait strategy is used by retry()", {
  g <- retry(
    stop = stop_after_attempt(3),
    wait = wait_linear(0.02)
  ) %@%
    function() stop("boom")
  elapsed <- system.time(try(g(), silent = TRUE))[["elapsed"]]
  expect_gte(elapsed, 0.05) # 0.02 + 0.04 between three attempts
})

test_that("a custom stop condition works alone and in a combinator", {
  state <- list(attempt = 2, wait = 0, elapsed = 5, error = NULL, value = NULL)
  expect_true(stop_fn(stop_on_slow(3), state))
  expect_false(stop_fn(stop_on_slow(10), state))
  expect_true(stop_fn(stop_any(stop_after_attempt(9), stop_on_slow(3)), state))
  expect_false(stop_fn(stop_all(stop_after_attempt(9), stop_on_slow(3)), state))
})

test_that("a custom retry condition decides what is retried", {
  vals <- c(-1, -1, 5)
  i <- 0L
  g <- retry(
    stop = stop_after_attempt(5),
    retry = retry_on_negative()
  ) %@%
    function() {
      i <<- i + 1L
      vals[[i]]
    }
  expect_equal(g(), 5)
  expect_equal(i, 3L)
})

test_that("hook methods receive the documented state fields", {
  seen <- new.env()
  fl <- 0L
  g <- retry(
    stop = stop_after_attempt(3),
    before_sleep = hook_recorder(seen)
  ) %@%
    function() {
      fl <<- fl + 1L
      if (fl < 2L) {
        stop("once")
      }
      "ok"
    }
  expect_equal(g(), "ok")
  expect_setequal(
    seen$fields,
    c("attempt", "wait", "elapsed", "error", "value")
  )
})

test_that("the abstract bases cannot be used directly", {
  expect_error(wait_base())
  expect_error(stop_base())
})
