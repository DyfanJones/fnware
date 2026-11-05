skip_if_not_installed("later")
skip_if_not_installed("promises")

test_that("passes a valid resolved value through", {
  f <- async_validate_return(is.numeric) %@% function() delayed(1, 0)
  expect_equal(settle_value(f()), 1)
})

test_that("validates the value, not the promise", {
  f <- async_validate_return(is.numeric) %@%
    function() promises::promise_resolve(1)
  expect_equal(settle_value(f()), 1)
})

test_that("an invalid value rejects with a validation error", {
  f <- async_validate_return(is.character) %@% function() delayed(1, 0)
  res <- settle_promise(f())
  expect_s3_class(res$error, "fnware_validation_error")
})

test_that("validator messages are reported", {
  f <- async_validate_return(function(x) "must be a string") %@%
    function() delayed(1, 0)
  res <- settle_promise(f())
  expect_match(conditionMessage(res$error), "Invalid return value")
  expect_match(conditionMessage(res$error), "must be a string", fixed = TRUE)
})

test_that("rejections from the function carry on unchanged", {
  f <- async_validate_return(is.numeric) %@% function() delayed_error("boom")
  expect_error(settle_value(f()), "boom")
})

test_that("formulas work as validators", {
  f <- async_validate_return(~ .x > 0) %@% function() delayed(-1, 0)
  expect_s3_class(settle_promise(f())$error, "fnware_validation_error")
})
