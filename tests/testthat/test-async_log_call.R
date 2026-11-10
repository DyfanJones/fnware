skip_if_not_installed("later")
skip_if_not_installed("promises")

test_that("logs the start at call time and the finish when it resolves", {
  cap <- capture_logger()
  f <- async_log_call(logger = cap$logger) %@% function(a) delayed(a, 0.05)
  p <- f(1)
  expect_length(cap$get(), 1L)
  expect_equal(cap$get()[[1]]$msg, "Start f(a=1)")
  expect_equal(settle_value(p), 1)
  out <- cap$get()
  expect_length(out, 2L)
  expect_match(out[[2]]$msg, "^Finished f\\(a=1\\) Elapsed=")
})

test_that("a rejection is logged as a failure and passed on", {
  cap <- capture_logger()
  f <- async_log_call(logger = cap$logger) %@% function() delayed_error("boom")
  expect_error(settle_value(f()), "boom")
  out <- cap$get()
  expect_length(out, 2L)
  expect_equal(out[[2]]$level, "ERROR")
  expect_match(out[[2]]$msg, "^Error f\\(\\)")
  expect_match(out[[2]]$msg, "boom")
})

test_that("a thrown error is logged as a failure", {
  cap <- capture_logger()
  f <- async_log_call(logger = cap$logger) %@% function() stop("boom")
  expect_error(settle_value(f()), "boom")
  expect_match(cap$get()[[2]]$msg, "^Error")
})

test_that("levels and elapsed are respected", {
  cap <- capture_logger()
  f <- async_log_call(
    logger = cap$logger,
    level = log_levels(finish = "debug"),
    elapsed = FALSE
  ) %@% function() delayed(1, 0)
  settle_value(f())
  out <- cap$get()
  expect_equal(out[[2]]$level, "DEBUG")
  expect_false(grepl("Elapsed", out[[2]]$msg))
})

test_that("bad arguments fail when decorating", {
  expect_error(async_log_call(logger = 1)(function() 1), "logger")
})
