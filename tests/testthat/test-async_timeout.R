skip_if_not_installed("promises")
skip_if_not_installed("later")

# A promise that resolves with `value` after `delay` seconds.
delayed <- function(value, delay) {
  promises::promise(function(resolve, reject) {
    later::later(function() resolve(value), delay)
  })
}

test_that("a fast promise resolves normally", {
  f <- async_timeout(5) %@% function(x) delayed(x * 2, 0.01)
  p <- f(21)
  expect_true(promises::is.promise(p))
  expect_equal(settle_promise(p)$value, 42)
})

test_that("a plain value resolves at once", {
  f <- async_timeout(5) %@% function(x) x + 1
  expect_equal(settle_promise(f(1))$value, 2)
})

test_that("a slow promise rejects with a garnish_timeout_error", {
  slow := async_timeout(0.1) %@% function() delayed("late", 1)
  t0 <- proc.time()[["elapsed"]]
  res <- settle_promise(slow())
  expect_s3_class(res$error, "garnish_timeout_error")
  expect_s3_class(res$error, "error")
  expect_equal(res$error$limit, 0.1)
  expect_equal(res$error$fn, "slow")
  expect_match(conditionMessage(res$error), "slow")
  expect_match(conditionMessage(res$error), "0.1 seconds")
  expect_lt(proc.time()[["elapsed"]] - t0, 0.8)
})

test_that("it returns without waiting", {
  f <- async_timeout(5) %@% function() delayed(1, 0.3)
  t0 <- proc.time()[["elapsed"]]
  p <- f()
  expect_lt(proc.time()[["elapsed"]] - t0, 0.2)
  settle_promise(p)
})

test_that("the timer is cancelled once the promise settles", {
  # Let timers left by earlier tests run out first.
  drain_loop()
  f <- async_timeout(30) %@% function() delayed(1, 0.01)
  settle_promise(f())
  # A cancelled timer is dropped on the next pass of the loop. A live 30 second
  # timer would still be there after a second.
  expect_true(drain_loop(timeout = 1))
})

test_that("rejections and thrown errors pass through unchanged", {
  rejects <- async_timeout(5) %@%
    function() promises::promise_reject(simpleError("rejected"))
  throws <- async_timeout(5) %@% function() stop("thrown")
  r1 <- settle_promise(rejects())
  r2 <- settle_promise(throws())
  expect_false(inherits(r1$error, "garnish_timeout_error"))
  expect_match(conditionMessage(r1$error), "rejected")
  expect_match(conditionMessage(r2$error), "thrown")
})

test_that("a non-condition rejection is not mistaken for a timeout", {
  f <- async_timeout(5) %@% function() promises::promise_reject("plain")
  err <- settle_promise(f())$error
  expect_false(inherits(err, "garnish_timeout_error"))
  expect_match(conditionMessage(err), "plain")
})

test_that("nested timeouts: the soonest rejects, naming that decorator", {
  inner := async_timeout(5) %@% function() delayed(1, 1)
  outer := async_timeout(0.1) %@% function() inner()
  res <- settle_promise(outer())
  expect_s3_class(res$error, "garnish_timeout_error")
  expect_equal(res$error$limit, 0.1)
  expect_equal(res$error$fn, "outer")
})

test_that("an inner timeout error passes through the outer unchanged", {
  inner := async_timeout(0.1) %@% function() delayed(1, 1)
  outer := async_timeout(5) %@% function() inner()
  res <- settle_promise(outer())
  expect_equal(res$error$fn, "inner")
})

test_that("async_retry() retries timeouts and counts attempts", {
  n <- 0L
  f <- async_retry(stop = stop_after_attempt(3)) %@%
    async_timeout(0.1) %@%
    function() {
      n <<- n + 1L
      if (n < 3L) delayed("late", 1) else delayed("worked", 0.01)
    }
  expect_equal(settle_promise(f())$value, "worked")
  expect_equal(n, 3L)
})

test_that("async_retry() gives up after repeated timeouts", {
  n <- 0L
  f <- async_retry(stop = stop_after_attempt(2)) %@%
    async_timeout(0.05) %@%
    function() {
      n <<- n + 1L
      delayed("late", 1)
    }
  res <- settle_promise(f())
  expect_s3_class(res$error, "retry_error")
  expect_s3_class(res$error$error, "garnish_timeout_error")
  expect_equal(n, 2L)
})

make_async_method <- function(fn) {
  cls <- S7::new_class(
    paste0("async_timeout_test_", sample.int(1e9, 1)),
    parent = async_timeout_base
  )
  S7::method(async_timeout_fn, cls) <- function(class, call, seconds, ...) {
    fn(call, seconds)
  }
  cls()
}

test_that("a custom method is used and given the limit", {
  seen <- NULL
  m <- make_async_method(function(call, seconds) {
    seen <<- seconds
    call()
  })
  f <- async_timeout(3, method = m) %@% function() delayed("ok", 0.01)
  expect_equal(settle_promise(f())$value, "ok")
  expect_equal(seen, 3)
})

test_that("a custom method can reject with a garnish_timeout_error", {
  m <- make_async_method(function(call, seconds) {
    promises::promise_reject(
      rlang::error_cnd("garnish_timeout_error", message = "too slow")
    )
  })
  g := async_timeout(3, method = m) %@% function() 1
  res <- settle_promise(g())
  expect_s3_class(res$error, "garnish_timeout_error")
  expect_equal(res$error$fn, "g")
  expect_equal(res$error$limit, 3)
})

test_that("a method that does not return a promise errors clearly", {
  m <- make_async_method(function(call, seconds) "not a promise")
  f <- async_timeout(3, method = m) %@% function() 1
  expect_error(f(), class = "garnish_timeout_method_error")
})

test_that("arguments are validated", {
  expect_error(async_timeout(0) %@% function() 1, "seconds")
  expect_error(async_timeout("a") %@% function() 1, "seconds")
  expect_error(async_timeout(1, method = "x") %@% function() 1, "method")
  expect_error(async_timeout(1, method = timeout_r()) %@% function() 1, "method")
})

test_that("a mirai task that runs too long is rejected", {
  skip_if_not_installed("mirai")
  skip_on_cran()
  mirai::daemons(1)
  withr::defer(mirai::daemons(0))
  hang := async_timeout(0.3) %@% function() mirai::mirai(Sys.sleep(10))
  quick <- async_timeout(10) %@% function() mirai::mirai(1 + 1)
  expect_s3_class(
    settle_promise(hang(), timeout = 15)$error,
    "garnish_timeout_error"
  )
  expect_equal(settle_promise(quick(), timeout = 15)$value, 2)
})
