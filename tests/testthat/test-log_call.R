logger_capture := S7::new_class(
  parent = logger_base,
  properties = list(env = S7::new_property(S7::class_any))
)
S7::method(logger_fn, logger_capture) <- function(class, level, msg, ...) {
  class@env$seen[[length(class@env$seen) + 1L]] <- list(level = level, msg = msg)
}
capture_logger <- function() {
  env <- new.env()
  env$seen <- list()
  list(logger = logger_capture(env = env), get = function() env$seen)
}

test_that("logs the start and the finish", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function(a, b) a + b
  expect_equal(f(1, 2), 3)
  out <- cap$get()
  expect_length(out, 2L)
  expect_equal(out[[1]]$level, "INFO")
  expect_equal(out[[1]]$msg, "Started f(a=1,b=2)")
  expect_equal(out[[2]]$level, "DEBUG")
  expect_match(out[[2]]$msg, "^Finished f\\(a=1,b=2\\) Elapsed=\\d{2}:\\d{2}:[0-9.]+$")
})

test_that("arguments are named by the formals they matched", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function(a, b, c) a + b + c
  f(1, c = 3, b = 2)
  expect_equal(cap$get()[[1]]$msg, "Started f(a=1,b=2,c=3)")
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
  expect_match(out[[2]]$msg, "^Failed f\\(\\) Elapsed=.* Error=boom$")
})

test_that("each event has its own level", {
  cap <- capture_logger()
  f <- log_call(
    logger = cap$logger,
    level = log_levels(start = "trace", finish = "WARN")
  ) %@% function() 1
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
  f <- log_call(logger = logger_num()) %@% function() 1
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
  expect_match(cap$get()[[1]]$msg, "^Started g\\(\\)")
})

test_that("invisible results stay invisible", {
  cap <- capture_logger()
  f <- log_call(logger = cap$logger) %@% function() invisible(1)
  expect_invisible(f())
})

test_that("the default logger prints level, time and message", {
  f <- log_call() %@% function() 1
  expect_output(f(), "INFO \\[\\d{4}-.*Z\\]: Started f\\(\\)")
})

test_that("logger_message uses message()", {
  f <- log_call(logger = logger_message()) %@% function() 1
  msgs <- testthat::capture_messages(f())
  expect_match(msgs[[1]], "^\\[INFO\\] Started f\\(\\)")
  expect_match(msgs[[2]], "^\\[DEBUG\\] Finished f\\(\\)")
})

test_that("a method for the logger package is enough to use it", {
  skip_if_not_installed("logger")
  seen <- character()
  logger_logger := S7::new_class(parent = logger_base)
  S7::method(logger_fn, logger_logger) <- function(class, level, msg, ...) {
    logger::log_level(level, logger::skip_formatter(msg), namespace = "fnware_test")
  }
  logger::log_threshold(logger::DEBUG, namespace = "fnware_test")
  old <- logger::log_appender(function(lines) seen <<- c(seen, lines), namespace = "fnware_test")
  withr::defer(logger::log_appender(old, namespace = "fnware_test"))
  f <- log_call(logger = logger_logger()) %@% function(x) x
  f("{not glue}")
  expect_match(seen[[1]], "INFO.*Started f\\(x=\"\\{not glue\\}\"\\)")
})

test_that("checks its arguments", {
  expect_error(log_call(logger = "x")(identity), "`logger` must be a logger")
  expect_error(log_call(level = "loud")(identity), "`level` must be")
  expect_error(log_levels(start = "loud"), "must be one of")
})
