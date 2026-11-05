# Many short sleeps: `setTimeLimit()` is only checked between R expressions, so
# a single long `Sys.sleep()` would not be interrupted.
slow_loop <- function(n = 200) {
  for (i in seq_len(n)) {
    Sys.sleep(0.02)
  }
  "done"
}

test_that("a fast function returns normally", {
  f <- timeout(5) %@% function(x) x * 2
  expect_equal(f(21), 42)
})

test_that("visibility and arguments are preserved", {
  f <- timeout(5) %@% function(x, y = 2) invisible(x + y)
  expect_invisible(f(1))
  expect_equal(f(1, y = 3), 4)
})

test_that("a slow R loop times out with a fnware_timeout_error", {
  f <- timeout(0.2) %@% slow_loop
  t0 <- proc.time()[["elapsed"]]
  expect_error(f(), class = "fnware_timeout_error")
  expect_lt(proc.time()[["elapsed"]] - t0, 2)
})

test_that("a busy loop times out", {
  f <- timeout(0.2) %@%
    function() {
      x <- 0
      while (TRUE) {
        x <- x + 1
      }
    }
  expect_error(f(), class = "fnware_timeout_error")
})

test_that("the condition is an error with the limit and function name", {
  slow := timeout(0.2) %@% slow_loop
  err <- tryCatch(slow(), error = identity)
  expect_s3_class(err, "error")
  expect_s3_class(err, "fnware_timeout_error")
  expect_equal(err$limit, 0.2)
  expect_equal(err$fn, "slow")
  expect_match(conditionMessage(err), "slow")
  expect_match(conditionMessage(err), "0.2 seconds")
})

test_that("other errors pass through and are not turned into timeouts", {
  f <- timeout(5) %@% function() stop("boom")
  err <- tryCatch(f(), error = identity)
  expect_false(inherits(err, "fnware_timeout_error"))
  expect_match(conditionMessage(err), "boom")
})

test_that("the time limit is cleared after success and after error", {
  ok <- timeout(0.3) %@% function() "ok"
  bad <- timeout(0.3) %@% function() stop("boom")
  slow <- timeout(0.2) %@% slow_loop

  # A limit left armed would fire during the wait, so measure within one call.
  run <- function(g) {
    try(g(), silent = TRUE)
    t0 <- proc.time()[["elapsed"]]
    while (proc.time()[["elapsed"]] - t0 < 0.5) {
      Sys.sleep(0.02)
    }
    "survived"
  }
  expect_equal(run(ok), "survived")
  expect_equal(run(bad), "survived")
  expect_equal(run(slow), "survived")
  expect_equal(timeout_remaining(), Inf)
})

test_that("timeout_remaining() is Inf outside and decreases inside", {
  expect_equal(timeout_remaining(), Inf)
  f <- timeout(10) %@%
    function() {
      a <- timeout_remaining()
      Sys.sleep(0.1)
      c(a, timeout_remaining())
    }
  r <- f()
  expect_lte(r[[1]], 10 + 1e-6)
  expect_gt(r[[1]], 9)
  expect_lt(r[[2]], r[[1]])
  expect_equal(timeout_remaining(), Inf)
})

test_that("nested timeouts use the smaller deadline", {
  inner_longer <- timeout(10) %@% function() timeout_remaining()
  outer <- timeout(1) %@% function() inner_longer()
  expect_lte(outer(), 1 + 1e-6)

  inner_shorter <- timeout(0.5) %@% function() timeout_remaining()
  outer2 <- timeout(10) %@% function() inner_shorter()
  expect_lte(outer2(), 0.5 + 1e-6)
  expect_gt(outer2(), 0.4)
})

test_that("an inner timeout cannot outlast an outer one", {
  inner := timeout(10) %@% slow_loop
  outer := timeout(0.3) %@% function() inner()
  t0 <- proc.time()[["elapsed"]]
  err <- tryCatch(outer(), error = identity)
  expect_s3_class(err, "fnware_timeout_error")
  expect_lt(proc.time()[["elapsed"]] - t0, 2)
  expect_match(conditionMessage(err), "enclosing")
  expect_equal(timeout_remaining(), Inf)
})

test_that("the outer limit is restored after an inner timeout finishes", {
  inner <- timeout(5) %@% function() "inner"
  outer <- timeout(0.3) %@%
    function() {
      inner()
      slow_loop()
    }
  expect_error(outer(), class = "fnware_timeout_error")
})

test_that("an inner timeout error is passed through the outer unchanged", {
  inner := timeout(0.1) %@% slow_loop
  outer := timeout(5) %@% function() inner()
  err <- tryCatch(outer(), error = identity)
  expect_equal(err$fn, "inner")
})

test_that("retry() retries timeouts and counts attempts", {
  n <- 0L
  f <- retry(stop = stop_after_attempt(3)) %@%
    timeout(0.15) %@%
    function() {
      n <<- n + 1L
      if (n < 3L) slow_loop() else "worked"
    }
  expect_equal(f(), "worked")
  expect_equal(n, 3L)
})

test_that("retry() gives up after repeated timeouts", {
  n <- 0L
  f <- retry(stop = stop_after_attempt(2)) %@%
    timeout(0.1) %@%
    function() {
      n <<- n + 1L
      slow_loop()
    }
  err <- tryCatch(f(), error = identity)
  expect_s3_class(err, "fnware_retry_error")
  expect_s3_class(err$error, "fnware_timeout_error")
  expect_equal(n, 2L)
})

test_that("retry_if_error() can target timeouts", {
  n <- 0L
  f <- retry(
    stop = stop_after_attempt(3),
    retry = retry_if_error()
  ) %@%
    timeout(0.1) %@%
    function() {
      n <<- n + 1L
      slow_loop()
    }
  expect_error(f(), class = "fnware_retry_error")
  expect_equal(n, 3L)
})

test_that("circuit_breaker() counts timeouts as failures", {
  n <- 0L
  f <- circuit_breaker(failures = 2, reset_after = 60) %@%
    timeout(0.1) %@%
    function() {
      n <<- n + 1L
      slow_loop()
    }
  expect_error(f(), class = "fnware_timeout_error")
  expect_error(f(), class = "fnware_timeout_error")
  expect_error(f(), class = "fnware_circuit_open")
  expect_equal(n, 2L)
})

test_that("a custom method following the contract is used", {
  seen <- NULL
  m <- function(call, seconds) {
    seen <<- seconds
    call()
  }
  f <- timeout(3, method = make_timeout_method(m)) %@% function(x) x + 1
  expect_equal(f(1), 2)
  expect_lte(seen, 3)
  expect_gt(seen, 2)
})

test_that("a custom method can signal a fnware_timeout_error", {
  m <- function(call, seconds) {
    rlang::abort("too slow", class = "fnware_timeout_error")
  }
  g := timeout(3, method = make_timeout_method(m)) %@% function() 1
  err <- tryCatch(g(), error = identity)
  expect_s3_class(err, "fnware_timeout_error")
  expect_equal(err$fn, "g")
  expect_equal(err$limit, 3)
})

test_that("a method that returns the wrong value errors clearly", {
  m <- function(call, seconds) {
    call()
    "something else"
  }
  f <- timeout(3, method = make_timeout_method(m)) %@% function() 1
  expect_error(f(), class = "fnware_timeout_method_error")
  expect_error(f(), "contract")
})

test_that("a method that swallows the error errors clearly", {
  m <- function(call, seconds) {
    tryCatch(call(), error = function(e) NULL)
  }
  f <- timeout(3, method = make_timeout_method(m)) %@% function() stop("boom")
  expect_error(f(), class = "fnware_timeout_method_error")
})

test_that("timeout_r() is a timeout method", {
  expect_true(S7::S7_inherits(timeout_r(), timeout_base))
})

test_that("timeout_remaining() reads a deadline passed in from a parent process", {
  withr::local_envvar(
    FNWARE_TIMEOUT_DEADLINE = format(as.numeric(Sys.time()) + 5, digits = 17)
  )
  r <- timeout_remaining()
  expect_lte(r, 5)
  expect_gt(r, 4)
  # A timeout in the child cannot outlast the inherited deadline.
  f <- timeout(60) %@% function() timeout_remaining()
  expect_lte(f(), 5)
  # A passed deadline reports zero rather than a negative number.
  withr::local_envvar(FNWARE_TIMEOUT_DEADLINE = "1")
  expect_equal(timeout_remaining(), 0)
})

test_that("an unset or invalid inherited deadline is ignored", {
  withr::local_envvar(FNWARE_TIMEOUT_DEADLINE = NA)
  expect_equal(timeout_remaining(), Inf)
  withr::local_envvar(FNWARE_TIMEOUT_DEADLINE = "soon")
  expect_equal(timeout_remaining(), Inf)
})

test_that("arguments are validated", {
  expect_error(timeout(0) %@% function() 1, "seconds")
  expect_error(timeout("a") %@% function() 1, "seconds")
  expect_error(timeout(c(1, 2)) %@% function() 1, "seconds")
  expect_error(timeout(1, method = "x") %@% function() 1, "method")
  expect_error(
    timeout(1, method = function(call, seconds) call()) %@% function() 1,
    "method"
  )
})

test_that("a callr-based method kills the process and passes the deadline on", {
  skip_if_not_installed("callr")
  skip_on_cran()
  timeout_callr <- S7::new_class("timeout_callr", parent = timeout_base)
  S7::method(timeout_fn, timeout_callr) <- function(class, call, seconds, ...) {
    deadline <- format(as.numeric(Sys.time()) + seconds, digits = 17)
    env <- c(callr::rcmd_safe_env(), FNWARE_TIMEOUT_DEADLINE = deadline)
    tryCatch(
      callr::r(
        function(call) call(),
        args = list(call),
        timeout = seconds,
        env = env
      ),
      callr_timeout_error = function(e) {
        rlang::abort("Timed out.", class = "fnware_timeout_error")
      }
    )
  }
  hang <- timeout(0.5, method = timeout_callr()) %@%
    function() {
      Sys.sleep(10)
      1
    }
  fast <- timeout(10, method = timeout_callr()) %@% function(x) x + 1
  deadline <- timeout(10, method = timeout_callr()) %@%
    function() {
      as.numeric(Sys.getenv("FNWARE_TIMEOUT_DEADLINE")) -
        as.numeric(Sys.time())
    }
  expect_error(hang(), class = "fnware_timeout_error")
  expect_equal(fast(1), 2)
  expect_lte(deadline(), 10)
  expect_gt(deadline(), 8)
})
