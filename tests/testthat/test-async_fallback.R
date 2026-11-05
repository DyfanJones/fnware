skip_if_not_installed("later")

test_that("resolves to the value when the promise rejects", {
  skip_if_not_installed("promises")
  f <- async_fallback(value = "default") %@%
    function() promises::promise_reject(simpleError("boom"))
  expect_equal(settle_value(f()), "default")
})

test_that("resolves to the value when the function throws", {
  skip_if_not_installed("promises")
  f <- async_fallback(value = "default") %@% function() stop("boom")
  expect_equal(settle_value(f()), "default")
})

test_that("passes results through", {
  skip_if_not_installed("promises")
  f <- async_fallback(value = "default") %@% function(x) x
  expect_equal(settle_value(f(5)), 5)
})

test_that("handler builds the result from the condition", {
  skip_if_not_installed("promises")
  f <- async_fallback(handler = function(cnd) conditionMessage(cnd)) %@%
    function() stop("boom")
  expect_equal(settle_value(f()), "boom")
})

test_that("conditions outside `class` stay rejected", {
  skip_if_not_installed("promises")
  f <- async_fallback(value = "x", class = "custom") %@% function() stop("boom")
  expect_error(settle_value(f()), "boom")
})
