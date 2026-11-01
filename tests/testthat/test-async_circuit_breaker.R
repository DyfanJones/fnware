skip_if_not_installed("promises")
skip_if_not_installed("later")

test_that("successful calls resolve unchanged", {
  f <- async_circuit_breaker(failures = 2) %@% function(x) delayed(x * 2, 0.01)
  p <- f(2)
  expect_true(promises::is.promise(p))
  expect_equal(settle_promise(p)$value, 4)
  expect_equal(settle_promise(f(3))$value, 6)
})

test_that("a plain value works", {
  f <- async_circuit_breaker() %@% function(x) x
  expect_equal(settle_promise(f(5))$value, 5)
})

test_that("opens after consecutive failures and stops calling the function", {
  n <- 0L
  f <- async_circuit_breaker(failures = 2, reset_after = 60) %@%
    function() {
      n <<- n + 1L
      delayed_error("down", 0.01)
    }
  res <- settle_promise(f())
  expect_match(conditionMessage(res$error), "down")
  res <- settle_promise(f())
  expect_match(conditionMessage(res$error), "down")
  res <- settle_promise(f())
  expect_s3_class(res$error, "garnish_circuit_open")
  expect_s3_class(res$error, "error")
  expect_equal(n, 2L)
})

test_that("a thrown error counts as a failure", {
  n <- 0L
  f <- async_circuit_breaker(failures = 1, reset_after = 60) %@%
    function() {
      n <<- n + 1L
      stop("thrown")
    }
  res <- settle_promise(f())
  expect_match(conditionMessage(res$error), "thrown")
  res <- settle_promise(f())
  expect_s3_class(res$error, "garnish_circuit_open")
  expect_equal(n, 1L)
})

test_that("an open circuit rejects without waiting", {
  f <- async_circuit_breaker(failures = 1, reset_after = 60) %@%
    function() delayed_error("down")
  settle_promise(f())
  t0 <- proc.time()[["elapsed"]]
  p <- f()
  expect_lt(proc.time()[["elapsed"]] - t0, 0.1)
  res <- settle_promise(p)
  expect_s3_class(res$error, "garnish_circuit_open")
})

test_that("a success resets the failure count", {
  i <- 0L
  f <- async_circuit_breaker(failures = 2, reset_after = 60) %@%
    function() {
      i <<- i + 1L
      if (i %in% c(1L, 3L)) delayed_error("fail") else delayed("ok", 0.01)
    }
  res <- settle_promise(f())
  expect_match(conditionMessage(res$error), "fail")
  expect_equal(settle_promise(f())$value, "ok")
  res <- settle_promise(f())
  expect_match(conditionMessage(res$error), "fail")
  # One failure since the success: still closed, so the call runs.
  expect_equal(settle_promise(f())$value, "ok")
})

test_that("a trial call after the cooldown closes the circuit on success", {
  i <- 0L
  f <- async_circuit_breaker(failures = 1, reset_after = 0.2) %@%
    function() {
      i <<- i + 1L
      if (i == 1L) delayed_error("fail") else delayed("recovered", 0.01)
    }
  settle_promise(f())
  res <- settle_promise(f())
  expect_s3_class(res$error, "garnish_circuit_open")
  Sys.sleep(0.3)
  expect_equal(settle_promise(f())$value, "recovered")
  expect_equal(settle_promise(f())$value, "recovered")
})

test_that("a failed trial opens the circuit again", {
  n <- 0L
  f <- async_circuit_breaker(failures = 1, reset_after = 0.2) %@%
    function() {
      n <<- n + 1L
      delayed_error("still down")
    }
  settle_promise(f())
  Sys.sleep(0.3)
  res <- settle_promise(f())
  expect_match(conditionMessage(res$error), "still down")
  res <- settle_promise(f())
  expect_s3_class(res$error, "garnish_circuit_open")
  expect_equal(n, 2L)
})

test_that("only one trial runs while half-open", {
  n <- 0L
  f <- async_circuit_breaker(failures = 1, reset_after = 0.2) %@%
    function() {
      n <<- n + 1L
      if (n == 1L) delayed_error("fail") else delayed("recovered", 0.3)
    }
  settle_promise(f())
  Sys.sleep(0.3)
  trial <- f()
  other <- f()
  res <- settle_promise(other)
  expect_s3_class(res$error, "garnish_circuit_open")
  expect_equal(settle_promise(trial)$value, "recovered")
  expect_equal(n, 2L)
})

test_that("a trial that never settles is abandoned after the cooldown", {
  n <- 0L
  f <- async_circuit_breaker(failures = 1, reset_after = 0.2) %@%
    function() {
      n <<- n + 1L
      if (n == 1L) {
        delayed_error("fail")
      } else if (n == 2L) {
        promises::promise(function(resolve, reject) NULL) # never settles
      } else {
        delayed("recovered", 0.01)
      }
    }
  settle_promise(f())
  Sys.sleep(0.3)
  f() # the trial, which hangs
  res <- settle_promise(f())
  expect_s3_class(res$error, "garnish_circuit_open")
  Sys.sleep(0.3)
  expect_equal(settle_promise(f())$value, "recovered")
})

test_that("a call that started before the circuit opened cannot close it", {
  n <- 0L
  f <- async_circuit_breaker(failures = 1, reset_after = 60) %@%
    function() {
      n <<- n + 1L
      if (n == 1L) delayed("slow success", 0.3) else delayed_error("fail")
    }
  slow <- f() # starts while closed
  settle_promise(f()) # fails and opens the circuit
  expect_equal(settle_promise(slow)$value, "slow success")
  # The late success must not have closed the circuit.
  res <- settle_promise(f())
  expect_s3_class(res$error, "garnish_circuit_open")
})

test_that("separately decorated functions have separate state", {
  bad <- async_circuit_breaker(failures = 1, reset_after = 60) %@%
    function() delayed_error("x")
  good <- async_circuit_breaker(failures = 1, reset_after = 60) %@%
    function() delayed("ok", 0.01)
  settle_promise(bad())
  res <- settle_promise(bad())
  expect_s3_class(res$error, "garnish_circuit_open")
  expect_equal(settle_promise(good())$value, "ok")
})

test_that("it works outside async_retry()", {
  n <- 0L
  f <- async_circuit_breaker(failures = 1, reset_after = 60) %@%
    async_retry(stop = stop_after_attempt(2)) %@%
    function() {
      n <<- n + 1L
      delayed_error("down")
    }
  res <- settle_promise(f())
  expect_s3_class(res$error, "retry_error")
  expect_equal(n, 2L)
  # The circuit opened on the retry's final rejection, so the next call is shut out.
  res <- settle_promise(f())
  expect_s3_class(res$error, "garnish_circuit_open")
  expect_equal(n, 2L)
})

test_that("arguments are validated", {
  f <- function() 1
  expect_error(async_circuit_breaker(failures = 0)(f), "`failures`")
  expect_error(async_circuit_breaker(failures = 1.5)(f), "`failures`")
  expect_error(async_circuit_breaker(failures = NA)(f), "`failures`")
  expect_error(async_circuit_breaker(reset_after = 0)(f), "`reset_after`")
  expect_error(async_circuit_breaker(reset_after = c(1, 2))(f), "`reset_after`")
})
