test_that("calls within the limit run without waiting", {
  f <- rate_limit(calls = 3, period = 0.5) %@% function(x) x
  t <- system.time(res <- vapply(1:3, f, numeric(1)))[["elapsed"]]
  expect_equal(res, 1:3)
  expect_lt(t, 0.15)
})

test_that("a call over the limit waits for the window to clear", {
  f <- rate_limit(calls = 2, period = 0.3) %@% function(x) x
  t <- system.time(vapply(1:3, f, numeric(1)))[["elapsed"]]
  # Sys.sleep() and system.time() have coarse timers on Windows, so allow slack.
  expect_gte(t, 0.2)
})

test_that("the window slides rather than resetting", {
  starts <- numeric()
  f <- rate_limit(calls = 2, period = 0.3) %@%
    function() {
      starts <<- c(starts, proc.time()[["elapsed"]])
      NULL
    }
  f()
  Sys.sleep(0.2)
  f()
  f()
  # The third call can only start once the first call has aged out of the window.
  # Sys.sleep() and proc.time() have coarse timers on Windows, so allow slack.
  expect_gte(starts[[3]] - starts[[1]], 0.25)
})

test_that("errors still count against the limit", {
  n <- 0L
  g <- function() {
    n <<- n + 1L
    stop("boom")
  }
  f <- rate_limit(calls = 1, period = 0.3) %@% g
  expect_error(f(), "boom")
  t <- system.time(expect_error(f(), "boom"))[["elapsed"]]
  expect_gte(t, 0.15)
  expect_equal(n, 2L)
})

test_that("separately decorated functions have separate limits", {
  make <- function() rate_limit(calls = 1, period = 0.5) %@% function() "ok"
  a <- make()
  b <- make()
  a()
  t <- system.time(b())[["elapsed"]]
  expect_lt(t, 0.15)
})

test_that("return values and visibility are preserved", {
  f <- rate_limit(calls = 5) %@% function() invisible(7)
  expect_invisible(f())
  g <- rate_limit(calls = 5) %@% function() 7
  expect_equal(g(), 7)
})

test_that("bad arguments are rejected", {
  # Checks run when the decorator is applied to a function.
  f <- function() 1
  expect_error(rate_limit(calls = 0)(f))
  expect_error(rate_limit(calls = 1.5)(f))
  expect_error(rate_limit(calls = NA)(f))
  expect_error(rate_limit(calls = 1, period = 0)(f))
  expect_error(rate_limit(calls = c(1, 2))(f))
})
