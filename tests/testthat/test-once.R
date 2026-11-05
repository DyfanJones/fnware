test_that("runs the function once and reuses the result", {
  n <- 0L
  f <- once %@%
    function(x) {
      n <<- n + 1L
      x
    }
  expect_equal(f(1), 1)
  expect_equal(f(2), 1)
  expect_equal(n, 1L)
})

test_that("an error does not use up the call", {
  n <- 0L
  f <- once %@%
    function() {
      n <<- n + 1L
      if (n == 1L) {
        stop("first fails")
      }
      "ok"
    }
  expect_error(f(), "first fails")
  expect_equal(f(), "ok")
  expect_equal(f(), "ok")
  expect_equal(n, 2L)
})

test_that("separately decorated functions are independent", {
  make <- function(x) once(function() x)
  a <- make("a")
  b <- make("b")
  expect_equal(a(), "a")
  expect_equal(b(), "b")
})

test_that("a NULL result is still remembered", {
  n <- 0L
  f <- once %@%
    function() {
      n <<- n + 1L
      NULL
    }
  f()
  f()
  expect_equal(n, 1L)
})
