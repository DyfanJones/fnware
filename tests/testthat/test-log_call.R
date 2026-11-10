
test_that("logs the start and the finish", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function(a, b) a + b
  expect_equal(f(1, 2), 3)
  out <- cap$get()
  expect_length(out, 2L)
  expect_equal(out[[1]]$level, "INFO")
  expect_equal(out[[1]]$msg, "Start f(a=1,b=2)")
  expect_equal(out[[2]]$level, "INFO")
  expect_match(
    out[[2]]$msg,
    "^Finished f\\(a=1,b=2\\) Elapsed=\\d{2}:\\d{2}:[0-9.]+$"
  )
})

test_that("arguments are named by the formals they matched", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function(a, b, c) a + b + c
  f(1, c = 3, b = 2)
  expect_equal(cap$get()[[1]]$msg, "Start f(a=1,b=2,c=3)")
})

test_that("long argument values are cut", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function(x) x
  f(1:100 + 0)
  expect_lte(nchar(cap$get()[[1]]$msg), 80L)
  expect_match(cap$get()[[1]]$msg, "\\.\\.\\.\\)$")
})

test_that("logs a failure and signals it again", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function() stop("boom")
  expect_error(f(), "boom")
  out <- cap$get()
  expect_equal(out[[2]]$level, "ERROR")
  expect_match(
    out[[2]]$msg,
    "^Error f\\(\\) \nError in `f\\(\\)`:\nboom$"
  )
})

test_that("each event has its own level", {
  cap <- capture_logger()
  f <- log_call(
    logger = cap$logger,
    level = log_levels(start = "trace", finish = "WARN")
  ) %@%
    function() 1
  f()
  expect_equal(vapply(cap$get(), `[[`, "", "level"), c("TRACE", "WARN"))
})

test_that("a logger's level labels are used", {
  seen <- NULL
  logger_num := S7::new_class(
    parent = logger_base,
    properties = list(
      info = S7::new_property(S7::class_any, default = 20L),
      debug = S7::new_property(S7::class_any, default = 10L)
    )
  )
  S7::method(logger_fn, logger_num) <- function(class, level, msg, ...) {
    seen <<- c(seen, level)
  }
  f <- log_call(
    logger = logger_num(),
    level = log_levels(finish = "debug")
  ) %@%
    function() 1
  f()
  expect_equal(seen, c(20L, 10L))
})

test_that("elapsed = FALSE drops the time", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger, elapsed = FALSE) %@% function() 1
  f()
  expect_equal(cap$get()[[2]]$msg, "Finished f()")
})

test_that("names the function even when stacked under another decorator", {
  cap <- capture_logger()
  g <- rate_limit(calls = 5) %@% log_call(logger = cap$logger) %@% function() 1
  g()
  expect_match(cap$get()[[1]]$msg, "^Start g\\(\\)")
})

test_that("invisible results stay invisible", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function() invisible(1)
  expect_invisible(f())
})

test_that("the default logger prints level, time and message", {
  f <- log_call() %@% function() 1
  expect_output(f(), "INFO \\[\\d{4}-.*Z\\]: Start f\\(\\)")
})

test_that("logger_message uses message()", {
  f <- log_call(logger = logger_message()) %@% function() 1
  msgs <- testthat::capture_messages(f())
  expect_match(msgs[[1]], "^INFO \\[.*Z\\]: Start f\\(\\)")
  expect_match(msgs[[2]], "^INFO \\[.*Z\\]: Finished f\\(\\)")
})

test_that("a method for the logger package is enough to use it", {
  skip_if_not_installed("logger")
  seen <- character()
  logger_logger := S7::new_class(parent = logger_base)
  S7::method(logger_fn, logger_logger) <- function(class, level, msg, ...) {
    logger::log_level(
      level,
      logger::skip_formatter(msg),
      namespace = "fnware_test"
    )
  }
  logger::log_threshold(logger::DEBUG, namespace = "fnware_test")
  old <- logger::log_appender(
    function(lines) seen <<- c(seen, lines),
    namespace = "fnware_test"
  )
  withr::defer(logger::log_appender(old, namespace = "fnware_test"))
  f <- log_call(logger = logger_logger()) %@% function(x) x
  f("{not glue}")
  expect_match(seen[[1]], "INFO.*Start f\\(x=\"\\{not glue\\}\"\\)")
})

test_that("checks its arguments", {
  expect_error(log_call(logger = "x")(identity), "`logger` must be a logger")
  expect_error(log_call(level = "loud")(identity), "`level` must be")
  expect_error(log_levels(start = "loud"), "must be one of")
})

test_that("a failure logs the calls from f to the failure as a trace event", {
  cap <- capture_logger()
  inner <- function(x) stop("boom")
  f <- log_call(logger = cap$logger) %@% function() inner(1)
  expect_error(f(), "boom")
  out <- cap$get()
  expect_length(out, 3L)
  expect_equal(out[[3]]$level, "TRACE")
  msg <- out[[3]]$msg
  expect_match(msg, "^Trace f\\(\\)")
  expect_match(msg, "inner(1)", fixed = TRUE)
  expect_match(msg, "1. f()", fixed = TRUE)
  expect_no_match(
    msg,
    "handleSimpleError|log_event|<environment>|f\\(\\.\\.\\.\\)"
  )
})

test_that("a level event is hidden below the logger's threshold", {
  f <- log_call(logger = logger_message()) %@% function() stop("boom")
  msgs <- testthat::capture_messages(try(f(), silent = TRUE))
  expect_length(msgs, 2L)
  expect_no_match(msgs, "Trace")

  f <- log_call(logger = logger_message(threshold = "trace")) %@%
    function() stop("boom")
  msgs <- testthat::capture_messages(try(f(), silent = TRUE))
  expect_length(msgs, 3L)
  expect_match(msgs[[3]], "^TRACE \\[.*Z\\]: Trace f\\(\\)")
})

test_that("the default logger honours the threshold", {
  f <- log_call(logger = logger_base(threshold = "error")) %@% function() 1
  expect_silent(f())
  g <- log_call(logger = logger_base(threshold = "trace")) %@%
    function() stop("boom")
  expect_output(try(g(), silent = TRUE), "TRACE \\[.*\\]: Trace g\\(\\)")
})

test_that("threshold is checked", {
  expect_error(logger_base(threshold = "loud"), "must be one of")
  expect_error(logger_message(threshold = c("info", "warn")), "must be one of")
  expect_equal(logger_message(threshold = "WARN")@threshold, "warn")
})

test_that("a failure without a call is logged as the bare message", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function() stop("boom", call. = FALSE)
  expect_error(f(), "boom")
  expect_match(cap$get()[[2]]$msg, " \nboom$")
})

test_that("a failure names the call that failed", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function(a) a + "x"
  expect_error(f(1))
  expect_match(
    cap$get()[[2]]$msg,
    "Error in `a + \"x\"`:\nnon-numeric",
    fixed = TRUE
  )
})
