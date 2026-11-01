skip_if_not_installed("promises")
skip_if_not_installed("later")

test_that("call_as_promise() resolves a plain value", {
  p <- call_as_promise(function(x) x + 1, 1)
  expect_true(promises::is.promise(p))
  expect_equal(settle_promise(p)$value, 2)
})

test_that("call_as_promise() follows a promise", {
  expect_equal(
    settle_promise(call_as_promise(function() delayed("later", 0.01)))$value,
    "later"
  )
})

test_that("call_as_promise() turns a thrown error into a rejection", {
  p <- call_as_promise(function() stop("thrown"))
  expect_true(promises::is.promise(p))
  res <- settle_promise(p)
  expect_match(conditionMessage(res$error), "thrown")
})

test_that("call_as_promise() passes arguments through", {
  p <- call_as_promise(function(x, y = 1) x * y, 3, y = 4)
  expect_equal(settle_promise(p)$value, 12)
})

test_that("check_async() passes when the packages are installed", {
  expect_no_error(check_async("async_retry"))
  expect_no_error(check_async("async_cache", later = FALSE))
})

test_that("circuit_open_cnd() is a classed error", {
  cnd <- circuit_open_cnd()
  expect_s3_class(cnd, "garnish_circuit_open")
  expect_s3_class(cnd, "error")
  expect_match(conditionMessage(cnd), "Circuit is open")
})

test_that("timeout_cnd() builds the finished timeout error", {
  cnd <- timeout_cnd("fetch", 2)
  expect_s3_class(cnd, "garnish_timeout_error")
  expect_equal(cnd$fn, "fetch")
  expect_equal(cnd$limit, 2)
  expect_true(cnd$finalised)
  expect_match(conditionMessage(cnd), "`fetch` timed out")
  expect_match(conditionMessage(timeout_cnd("fetch", 1)), "1 second\\.")
  expect_match(conditionMessage(timeout_cnd("f", 2, TRUE)), "enclosing")
})
