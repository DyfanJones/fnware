skip_if_not_installed("later")
skip_if_not_installed("promises")

test_that("runs once and reuses the resolved value", {
  n <- 0L
  f <- async_once %@%
    function(x) {
      n <<- n + 1L
      x
    }
  expect_equal(settle_value(f(1)), 1)
  expect_equal(settle_value(f(2)), 1)
  expect_equal(n, 1L)
})

test_that("calls made while running share one promise", {
  n <- 0L
  f <- async_once %@%
    function() {
      n <<- n + 1L
      delayed("ok", 0.05)
    }
  p1 <- f()
  p2 <- f()
  expect_equal(settle_value(p1), "ok")
  expect_equal(settle_value(p2), "ok")
  expect_equal(n, 1L)
})

test_that("a rejection does not use up the call", {
  n <- 0L
  f <- async_once %@%
    function() {
      n <<- n + 1L
      if (n == 1L) delayed_error("first fails") else delayed("ok", 0)
    }
  expect_error(settle_value(f()), "first fails")
  expect_equal(settle_value(f()), "ok")
  expect_equal(settle_value(f()), "ok")
  expect_equal(n, 2L)
})

test_that("a thrown error does not use up the call", {
  n <- 0L
  f <- async_once %@%
    function() {
      n <<- n + 1L
      if (n == 1L) stop("first fails")
      "ok"
    }
  expect_error(settle_value(f()), "first fails")
  expect_equal(settle_value(f()), "ok")
})
