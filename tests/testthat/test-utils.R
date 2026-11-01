test_that("check_number() accepts valid numbers and returns them invisibly", {
  expect_invisible(check_number(1))
  expect_equal(check_number(2.5, gt = 0), 2.5)
  expect_equal(check_number(Inf, gt = 0), Inf)
  expect_equal(check_number(3, ge = 1, whole = TRUE), 3)
})

test_that("check_number() rejects bad values with a clear message", {
  x <- 0
  expect_error(
    check_number(x, gt = 0),
    "`x` must be a single number greater than 0"
  )
  expect_error(
    check_number(0.5, ge = 1, whole = TRUE, arg = "n"),
    "`n` must be a single whole number of at least 1"
  )
  expect_error(
    check_number(1.5, ge = 1, whole = TRUE, arg = "n"),
    "whole number"
  )
  expect_error(check_number(NA_real_, arg = "n"), "`n` must be a single number")
  expect_error(check_number("a", arg = "n"), "single number")
  expect_error(check_number(c(1, 2), arg = "n"), "single number")
})

test_that("check_string(), check_function() and check_s7() validate", {
  expect_equal(check_string("a"), "a")
  expect_error(check_string(1, arg = "dir"), "`dir` must be a single string")
  expect_error(check_string(c("a", "b")), "single string")
  expect_error(check_string(NA_character_), "single string")

  expect_equal(check_function(mean), mean)
  expect_null(check_function(NULL, null = TRUE))
  expect_error(check_function(NULL), "must be a function")
  expect_error(
    check_function(1, null = TRUE, arg = "cb"),
    "`cb` must be a function or `NULL`"
  )

  expect_s7_ok <- check_s7(timeout_r(), timeout_base, "a timeout method")
  expect_error(
    check_s7(1, timeout_base, "a timeout method", arg = "method"),
    "`method` must be a timeout method"
  )
})
