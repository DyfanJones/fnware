skip_if_not_installed("promises")
skip_if_not_installed("later")

make_flaky <- function(fail_times) {
  calls <- 0L
  function() {
    calls <<- calls + 1L
    if (calls <= fail_times) stop("not yet (", calls, ")")
    calls
  }
}

test_that("returns a promise that resolves with the value", {
  f <- async_retry(stop = stop_after_attempt(3)) %@% function(x) x * 2
  p <- f(21)
  expect_true(promises::is.promise(p))
  expect_equal(settle_promise(p)$value, 42)
})

test_that("retries errors until one succeeds", {
  f <- async_retry(stop = stop_after_attempt(5)) %@% make_flaky(2)
  expect_equal(settle_promise(f())$value, 3L)
})

test_that("rejects with a retry_error once stop fires", {
  g <- make_flaky(Inf)
  f <- async_retry(stop = stop_after_attempt(3)) %@% g
  res <- settle_promise(f())
  expect_s3_class(res$error, "retry_error")
  expect_equal(res$error$attempt, 3L)
  expect_match(conditionMessage(res$error$error), "not yet")
})

test_that("reraise rejects with the last error", {
  f <- async_retry(stop = stop_after_attempt(2), reraise = TRUE) %@%
    make_flaky(Inf)
  res <- settle_promise(f())
  expect_false(inherits(res$error, "retry_error"))
  expect_match(conditionMessage(res$error), "not yet")
})

test_that("retry_error_callback supplies the value", {
  f <- async_retry(
    stop = stop_after_attempt(2),
    retry_error_callback = function(state) paste("gave up after", state$attempt)
  ) %@%
    make_flaky(Inf)
  expect_equal(settle_promise(f())$value, "gave up after 2")
})

test_that("a promise returned by the function is awaited and its rejection retried", {
  calls <- 0L
  f <- async_retry(stop = stop_after_attempt(5)) %@%
    function() {
      calls <<- calls + 1L
      if (calls < 3L) {
        promises::promise_reject(simpleError("rejected"))
      } else {
        promises::promise_resolve("ok")
      }
    }
  expect_equal(settle_promise(f())$value, "ok")
  expect_equal(calls, 3L)
})

test_that("retry_if_result retries unacceptable results", {
  n <- 0L
  f <- async_retry(
    stop = stop_after_attempt(5),
    retry = retry_if_result(is.null)
  ) %@%
    function() {
      n <<- n + 1L
      if (n < 3L) NULL else "ready"
    }
  expect_equal(settle_promise(f())$value, "ready")
  expect_equal(n, 3L)
})

test_that("waits between attempts without blocking the session", {
  f <- async_retry(stop = stop_after_attempt(3), wait = wait_fixed(0.2)) %@%
    make_flaky(2)
  t0 <- proc.time()[["elapsed"]]
  p <- f()
  # Returning the promise did not wait for the 0.4 seconds of delays.
  expect_lt(proc.time()[["elapsed"]] - t0, 0.2)
  expect_equal(settle_promise(p)$value, 3L)
  expect_gte(proc.time()[["elapsed"]] - t0, 0.35)
})

test_that("other work runs while an attempt waits", {
  ticks <- 0L
  tick <- function() {
    ticks <<- ticks + 1L
    later::later(tick, 0.02)
  }
  tick()
  f <- async_retry(stop = stop_after_attempt(2), wait = wait_fixed(0.3)) %@%
    make_flaky(1)
  expect_equal(settle_promise(f())$value, 2L)
  expect_gt(ticks, 5L)
})

test_that("hooks run around each wait", {
  log <- character()
  f <- async_retry(
    stop = stop_after_attempt(3),
    before_sleep = before_sleep_log(function(msg) log <<- c(log, "before")),
    after_sleep = after_sleep_log(function(msg) log <<- c(log, "after"))
  ) %@%
    make_flaky(2)
  settle_promise(f())
  expect_equal(log, c("before", "after", "before", "after"))
})

test_that("custom strategies work as they do in retry()", {
  wait_const <- S7::new_class(
    "wait_const_async",
    parent = wait_base,
    constructor = function() S7::new_object(wait_base())
  )
  S7::method(wait_fn, wait_const) <- function(class, attempt, prev_wait = NULL, ...) {
    0
  }
  f <- async_retry(stop = stop_after_attempt(4), wait = wait_const()) %@%
    make_flaky(2)
  expect_equal(settle_promise(f())$value, 3L)
})

test_that("an error in a strategy rejects the promise", {
  bad_stop <- S7::new_class(
    "stop_bad_async",
    parent = stop_base,
    constructor = function() S7::new_object(stop_base())
  )
  S7::method(stop_fn, bad_stop) <- function(class, state, ...) {
    stop("strategy exploded")
  }
  f <- async_retry(stop = bad_stop()) %@% make_flaky(Inf)
  res <- settle_promise(f())
  expect_match(conditionMessage(res$error), "strategy exploded")
})

test_that("a rejection that is not a condition is turned into an error", {
  f <- async_retry(stop = stop_after_attempt(2), reraise = TRUE) %@%
    function() promises::promise_reject("plain string")
  res <- settle_promise(f())
  expect_s3_class(res$error, "error")
  expect_match(conditionMessage(res$error), "plain string")
})

test_that("arguments are validated", {
  expect_error(
    async_retry(retry_error_callback = "nope") %@% function() 1,
    "retry_error_callback"
  )
})

test_that("works with a mirai task", {
  skip_if_not_installed("mirai")
  skip_on_cran()
  mirai::daemons(1)
  withr::defer(mirai::daemons(0))
  f <- async_retry(stop = stop_after_attempt(3)) %@%
    function() mirai::mirai(1 + 1)
  expect_equal(settle_promise(f(), timeout = 15)$value, 2)
})
