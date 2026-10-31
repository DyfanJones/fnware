test_that("validate_args passes valid arguments through", {
  f <- validate_args(x = is.numeric, n = ~ .x > 0) %@% function(x, n = 1) x * n
  expect_equal(f(2, 3), 6)
  expect_equal(f(x = 2), 2)
  expect_equal(f(n = 2, x = 4), 8)
})

test_that("validate_args fails on FALSE with a generic message", {
  f <- validate_args(x = is.numeric) %@% function(x) x
  expect_error(
    f("a"),
    "`x`: failed validation",
    class = "garnish_validation_error"
  )
})

test_that("string results are used as the message", {
  chk <- function(x) if (is.character(x)) TRUE else "must be character"
  f <- validate_args(x = chk) %@% function(x) x
  expect_error(f(1), "must be character", class = "garnish_validation_error")
  expect_equal(f("a"), "a")
})

test_that("only TRUE passes", {
  f <- validate_args(x = function(x) 1) %@% function(x) x
  expect_error(f(1), class = "garnish_validation_error")
})

test_that("all failures are reported together", {
  f <- validate_args(x = is.numeric, y = is.character) %@% function(x, y) NULL
  err <- expect_error(f("a", 1), class = "garnish_validation_error")
  expect_match(conditionMessage(err), "`x`")
  expect_match(conditionMessage(err), "`y`")
})

test_that("errors from validators propagate", {
  assert_pos <- function(x) if (x > 0) invisible(x) else stop("not positive")
  f <- validate_args(x = assert_pos) %@% function(x) x
  expect_error(f(-1), "not positive")
})

test_that("defaults are validated and positional matching works", {
  f <- validate_args(n = ~ .x > 0) %@% function(x, n = 1) n
  expect_equal(f(1), 1)
  expect_error(f(1, -5), class = "garnish_validation_error")
  g <- validate_args(n = ~ .x > 0) %@% function(x, n = -1) n
  expect_error(g(1), class = "garnish_validation_error")
})

test_that("missing arguments without defaults are left to R", {
  f <- validate_args(x = is.numeric) %@% function(x, y) 1
  expect_equal(f(1), 1)
  expect_error(f(y = 1), "missing")
})

test_that("bad specs fail early", {
  expect_error(validate_args(is.numeric), "named")
  expect_error(validate_args(x = is.numeric, x = is.character), "unique")
  expect_error(
    validate_args(z = is.numeric) %@% function(x) x,
    "not in the function's arguments"
  )
})

test_that("validate_return checks the result and keeps visibility", {
  f <- validate_return(is.character) %@% function(x) x
  expect_equal(f("a"), "a")
  expect_error(f(1), "Invalid return value", class = "garnish_validation_error")
  g <- validate_return(is.numeric) %@% function() invisible(1)
  expect_invisible(g())
})
