skip_if_not_installed("promises")
skip_if_not_installed("later")

# Seconds since `t0` at which each call started, in call order.
record_starts <- function(t0) {
  starts <- new.env()
  starts$times <- numeric()
  list(
    f = function(i) {
      starts$times <- c(starts$times, proc.time()[["elapsed"]] - t0)
      i
    },
    times = function() starts$times
  )
}

test_that("calls inside the limit start at once and resolve", {
  f <- async_rate_limit(calls = 3, period = 1) %@% function(x) x
  ps <- lapply(1:3, f)
  expect_true(all(vapply(ps, promises::is.promise, logical(1))))
  expect_equal(vapply(ps, function(p) settle_promise(p)$value, numeric(1)), 1:3)
})

test_that("a call over the limit is delayed without blocking", {
  r <- record_starts(proc.time()[["elapsed"]])
  f <- async_rate_limit(calls = 2, period = 0.3) %@% r$f
  t0 <- proc.time()[["elapsed"]]
  ps <- lapply(1:3, f)
  # Making the calls did not wait for the window.
  expect_lt(proc.time()[["elapsed"]] - t0, 0.15)
  vals <- vapply(ps, function(p) settle_promise(p)$value, numeric(1))
  expect_equal(vals, 1:3)
  times <- r$times()
  expect_lt(times[[2]], 0.15)
  expect_gte(times[[3]], 0.25)
})

test_that("queued calls keep their order and respect every window", {
  r <- record_starts(proc.time()[["elapsed"]])
  f <- async_rate_limit(calls = 2, period = 0.2) %@% r$f
  ps <- lapply(1:6, f)
  vals <- vapply(ps, function(p) settle_promise(p)$value, numeric(1))
  expect_equal(vals, 1:6)
  times <- r$times()
  expect_equal(order(times), 1:6)
  # No window of `period` seconds ever holds more than `calls` starts.
  for (i in seq_along(times)) {
    expect_lte(
      sum(times >= times[[i]] - 1e-6 & times < times[[i]] + 0.2 - 0.03),
      2
    )
  }
  expect_gte(times[[5]], 0.35)
})

test_that("a call after the window has passed is not delayed", {
  r <- record_starts(proc.time()[["elapsed"]])
  f <- async_rate_limit(calls = 1, period = 0.2) %@% r$f
  settle_promise(f(1))
  Sys.sleep(0.25)
  t0 <- proc.time()[["elapsed"]]
  settle_promise(f(2))
  expect_lt(proc.time()[["elapsed"]] - t0, 0.1)
})

test_that("it follows a promise returned by the function", {
  f <- async_rate_limit(calls = 1, period = 0.1) %@%
    function(x) delayed(x, 0.05)
  expect_equal(settle_promise(f(1))$value, 1)
  expect_equal(settle_promise(f(2))$value, 2)
})

test_that("errors reject the promise and still use a slot", {
  r <- record_starts(proc.time()[["elapsed"]])
  f <- async_rate_limit(calls = 1, period = 0.3) %@%
    function(i) {
      r$f(i)
      stop("boom")
    }
  p1 <- f(1)
  p2 <- f(2)
  res <- settle_promise(p1)
  expect_match(conditionMessage(res$error), "boom")
  res <- settle_promise(p2)
  expect_match(conditionMessage(res$error), "boom")
  expect_gte(diff(r$times()), 0.25)
})

test_that("separately decorated functions have separate limits", {
  a <- async_rate_limit(calls = 1, period = 5) %@% function() "a"
  b <- async_rate_limit(calls = 1, period = 5) %@% function() "b"
  t0 <- proc.time()[["elapsed"]]
  expect_equal(settle_promise(a())$value, "a")
  expect_equal(settle_promise(b())$value, "b")
  expect_lt(proc.time()[["elapsed"]] - t0, 1)
})

test_that("arguments are validated", {
  f <- function() 1
  expect_error(async_rate_limit(calls = 0)(f), "`calls`")
  expect_error(async_rate_limit(calls = 1.5)(f), "`calls`")
  expect_error(async_rate_limit(calls = NA)(f), "`calls`")
  expect_error(async_rate_limit(calls = 1, period = 0)(f), "`period`")
  expect_error(async_rate_limit(calls = c(1, 2))(f), "`calls`")
})
