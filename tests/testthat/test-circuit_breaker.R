test_that("successful calls pass through unchanged", {
  f <- circuit_breaker(failures = 2) %@% function(x) x * 2
  expect_equal(f(2), 4)
  expect_equal(f(3), 6)
})

test_that("opens after consecutive failures and stops calling the function", {
  n <- 0L
  g <- function() {
    n <<- n + 1L
    stop("down")
  }
  f <- circuit_breaker(failures = 2, reset_after = 60) %@% g
  expect_error(f(), "down")
  expect_error(f(), "down")
  expect_error(f(), class = "fnware_circuit_open")
  expect_equal(n, 2L)
})

test_that("a success resets the failure count", {
  i <- 0L
  g <- function() {
    i <<- i + 1L
    if (i %in% c(1L, 3L)) stop("fail") else "ok"
  }
  f <- circuit_breaker(failures = 2, reset_after = 60) %@% g
  expect_error(f(), "fail")
  expect_equal(f(), "ok")
  expect_error(f(), "fail")
  # One failure since the success: still closed, so the call runs.
  expect_equal(f(), "ok")
})

test_that("a trial call after the cooldown closes the circuit on success", {
  i <- 0L
  g <- function() {
    i <<- i + 1L
    if (i == 1L) stop("fail") else "recovered"
  }
  f <- circuit_breaker(failures = 1, reset_after = 0.2) %@% g
  expect_error(f(), "fail")
  expect_error(f(), class = "fnware_circuit_open")
  Sys.sleep(0.3)
  expect_equal(f(), "recovered")
  expect_equal(f(), "recovered")
})

test_that("a failed trial call reopens the circuit", {
  n <- 0L
  g <- function() {
    n <<- n + 1L
    stop("still down")
  }
  f <- circuit_breaker(failures = 1, reset_after = 0.2) %@% g
  expect_error(f(), "still down")
  Sys.sleep(0.3)
  expect_error(f(), "still down")
  expect_error(f(), class = "fnware_circuit_open")
  expect_equal(n, 2L)
})

test_that("return visibility is preserved", {
  f <- circuit_breaker() %@% function() invisible(7)
  expect_invisible(f())
  g <- circuit_breaker() %@% function() 7
  expect_equal(g(), 7)
})

test_that("separately decorated functions have separate state", {
  bad <- circuit_breaker(failures = 1, reset_after = 60) %@%
    function() stop("x")
  good <- circuit_breaker(failures = 1, reset_after = 60) %@% function() "ok"
  expect_error(bad(), "x")
  expect_error(bad(), class = "fnware_circuit_open")
  expect_equal(good(), "ok")
})

test_that("bad arguments are rejected when applied", {
  f <- function() 1
  expect_error(circuit_breaker(failures = 0)(f), "`failures`")
  expect_error(circuit_breaker(failures = 1.5)(f), "`failures`")
  expect_error(circuit_breaker(failures = NA)(f), "`failures`")
  expect_error(circuit_breaker(reset_after = 0)(f), "`reset_after`")
  expect_error(circuit_breaker(reset_after = c(1, 2))(f), "`reset_after`")
})

test_that("logs when the circuit opens and closes, and nothing by default", {
  cap <- capture_logger()
  ok <- FALSE
  g <- function() if (!ok) stop("down") else "up"
  f := circuit_breaker(failures = 1, reset_after = 0.1, logger = cap$logger) %@%
    g
  try(f(), silent = TRUE)
  try(f(), silent = TRUE) # rejected, not logged
  seen <- cap$get()
  expect_length(seen, 1L)
  expect_equal(seen[[1]]$level, "WARN")
  expect_match(seen[[1]]$msg, "Circuit opened for f.*down")
  Sys.sleep(0.15)
  ok <- TRUE
  f()
  seen <- cap$get()
  expect_length(seen, 2L)
  expect_equal(seen[[2]]$level, "INFO")
  expect_match(seen[[2]]$msg, "Circuit closed for f")
  f()
  expect_length(cap$get(), 2L) # already closed

  quiet <- circuit_breaker(failures = 1) %@% function() stop("down")
  expect_no_message(try(quiet(), silent = TRUE))
})

test_that("circuit_breaker validates logger and level", {
  cap <- capture_logger()
  f <- function() 1
  expect_error(circuit_breaker(logger = "x") %@% f, "logger. must be a logger")
  expect_error(circuit_breaker(level = "warn") %@% f, "named character")
  expect_error(circuit_breaker(level = c(open = "loud")) %@% f, "one of")
  g <- circuit_breaker(failures = 1, logger = cap$logger, level = c(open = "error")) %@%
    function() stop("down")
  try(g(), silent = TRUE)
  expect_equal(cap$get()[[1]]$level, "ERROR")
})
