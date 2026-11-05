flaky <- function(fail_times, value = "ok") {
  calls <- 0L
  list(
    f = function() {
      calls <<- calls + 1L
      if (calls <= fail_times) {
        base::stop("boom ", calls)
      }
      value
    },
    calls = function() calls
  )
}

test_that("retry returns the value once the call succeeds", {
  fl <- flaky(2)
  g <- retry(stop = stop_after_attempt(5))(fl$f)
  expect_equal(g(), "ok")
  expect_equal(fl$calls(), 3L)
})

test_that("retry does not swallow a successful first call", {
  fl <- flaky(0)
  expect_equal(retry()(fl$f)(), "ok")
  expect_equal(fl$calls(), 1L)
})

test_that("stop_after_attempt(n) makes exactly n attempts", {
  fl <- flaky(Inf)
  g <- retry(stop = stop_after_attempt(3))(fl$f)
  expect_error(g(), "boom 3")
  expect_equal(fl$calls(), 3L)
})

test_that("retry_never re-raises immediately", {
  fl <- flaky(Inf)
  g <- retry(retry = retry_never())(fl$f)
  expect_error(g(), "boom 1")
  expect_equal(fl$calls(), 1L)
})

test_that("retry_if_error only retries matching conditions", {
  calls <- 0L
  f <- function() {
    calls <<- calls + 1L
    rlang::abort("nope", class = "other_error")
  }
  g <- retry(retry = retry_if_error("my_error"))(f)
  expect_error(g(), "nope")
  expect_equal(calls, 1L)
})

test_that("a function returning a condition is not treated as failure", {
  e <- simpleError("returned, not thrown")
  expect_identical(retry()(function() e)(), e)
})

test_that("logging hooks fire", {
  fl <- flaky(1)
  msgs <- character()
  log <- function(x) msgs <<- c(msgs, x)
  g <- retry(
    stop = stop_after_attempt(3),
    before_sleep = before_sleep_log(log),
    after_sleep = after_sleep_log(log)
  )(fl$f)
  g()
  expect_length(msgs, 2L)
  expect_match(msgs[[1]], "Attempt 1 failed")
})

test_that("stop_any / stop_all combine conditions", {
  state <- list(attempt = 2, wait = 0, elapsed = 0, error = NULL)
  a <- stop_after_attempt(2)
  b <- stop_after_attempt(5)
  expect_true(stop_fn(stop_any(a, b), state))
  expect_false(stop_fn(stop_all(a, b), state))
  expect_error(stop_any(1), "stop conditions")
})

test_that("stop_*_delay use elapsed time", {
  state <- list(attempt = 1, wait = 2, elapsed = 9, error = NULL)
  expect_false(stop_fn(stop_after_delay(10), state))
  expect_true(stop_fn(stop_before_delay(10), state))
})

test_that("validators reject bad input", {
  expect_error(stop_after_attempt(-1), "greater than or equal to 0")
  expect_error(stop_after_delay(-1), "greater than or equal to 0")
  expect_error(wait_exp_jitter(base = -1), "greater than or equal to 0")
  expect_error(wait_rand(min = 2, max = 1))
  expect_error(wait_exp_jitter(jitter = "bogus"), "must be one of")
  expect_error(wait_chain(), "at least one wait strategy")
  expect_error(wait_chain(1), "only contain wait strategies")
  expect_error(stop_any(1), "only contain stop conditions")
  expect_no_error(wait_exp())
  expect_no_error(wait_rand())
})

test_that("wait strategies", {
  expect_equal(wait_fn(wait_none(), 1), 0)
  expect_equal(wait_fn(wait_fixed(2), 4), 2)
  w <- wait_exp(multiplier = 1, min = 1, max = 10)
  expect_equal(vapply(1:5, \(i) wait_fn(w, i), numeric(1)), c(1, 2, 4, 8, 10))
  r <- wait_fn(wait_rand(1, 2), 1)
  expect_gte(r, 1)
  expect_lte(r, 2)
  j <- wait_exp_jitter(base = 1, max_delay = 4, jitter = "none")
  expect_equal(vapply(1:4, \(i) wait_fn(j, i), numeric(1)), c(1, 2, 4, 4))
  d <- wait_exp_jitter(base = 1, max_delay = 4, jitter = "decorrelated")
  expect_lte(wait_fn(d, 2, prev_wait = 1), 3)
})

test_that("waiting actually sleeps", {
  fl <- flaky(1)
  g <- retry(stop = stop_after_attempt(3), wait = wait_fixed(0.2))(fl$f)
  t <- system.time(g())[["elapsed"]]
  # Sys.sleep() and system.time() have coarse timers on Windows, so allow slack.
  expect_gte(t, 0.15)
})

test_that("retry_if_result retries until the predicate is satisfied", {
  calls <- 0L
  f <- function() {
    calls <<- calls + 1L
    calls
  }
  g <- retry(
    retry = retry_if_result(function(x) x < 3),
    stop = stop_after_attempt(10)
  )(f)
  expect_equal(g(), 3L)
  expect_equal(calls, 3L)
})

test_that("retry_if_result does not retry errors", {
  f <- function() base::stop("bang")
  g <- retry(retry = retry_if_result(isTRUE), stop = stop_after_attempt(3))(f)
  expect_error(g(), "bang")
})

test_that("retry_if_error_message matches exactly or by regex", {
  mk <- function(r) {
    calls <- 0L
    f <- function() {
      calls <<- calls + 1L
      if (calls < 3L) base::stop("temporary failure ", calls) else "ok"
    }
    retry(retry = r, stop = stop_after_attempt(5))(f)
  }
  expect_equal(mk(retry_if_error_message(match = "^temporary"))(), "ok")
  expect_error(mk(retry_if_error_message(message = "temporary"))(), "failure 1")
  expect_error(mk(retry_if_error_message(match = "nothing"))(), "failure 1")
  expect_error(retry_if_error_message(), "Exactly one")
  expect_error(retry_if_error_message("a", "b"), "Exactly one")
})

test_that("stop signals a retry_error unless reraise is set", {
  f <- function() base::stop("always")
  g <- retry(stop = stop_after_attempt(2))(f)
  cnd <- tryCatch(g(), retry_error = identity)
  expect_s3_class(cnd, "retry_error")
  expect_equal(cnd$attempt, 2L)
  expect_match(conditionMessage(cnd$error), "always")

  h <- retry(stop = stop_after_attempt(2), reraise = TRUE)(f)
  cnd <- tryCatch(h(), error = identity)
  expect_false(inherits(cnd, "retry_error"))
  expect_equal(conditionMessage(cnd), "always")
})

test_that("a rejected final result signals retry_error with the value", {
  g <- retry(
    retry = retry_if_result(\(x) TRUE),
    stop = stop_after_attempt(2)
  )(function() 42)
  cnd <- tryCatch(g(), retry_error = identity)
  expect_equal(cnd$value, 42)
  expect_null(cnd$error)
  expect_match(conditionMessage(cnd), "unacceptable result")
})

test_that("retry_error_callback supplies the fallback value", {
  f <- function() base::stop("always")
  g <- retry(
    stop = stop_after_attempt(2),
    retry_error_callback = function(state) paste("gave up after", state$attempt)
  )(f)
  expect_equal(g(), "gave up after 2")
  expect_error(
    retry(retry_error_callback = "nope")(function() 1),
    "`retry_error_callback` must be a function or `NULL`"
  )
})

test_that("log hooks cope with result based retries", {
  msgs <- character()
  g <- retry(
    retry = retry_if_result(\(x) x < 2),
    stop = stop_after_attempt(3),
    before_sleep = before_sleep_log(\(x) msgs <<- c(msgs, x))
  )(local({
    n <- 0
    function() (n <<- n + 1)
  }))
  g()
  expect_match(msgs, "unacceptable result")
})

test_that("wait_chain walks the strategies then repeats the last", {
  w <- wait_chain(wait_fixed(1), wait_fixed(2), wait_fixed(5))
  expect_equal(vapply(1:5, \(i) wait_fn(w, i), numeric(1)), c(1, 2, 5, 5, 5))
  expect_error(wait_chain(), "at least one")
  expect_error(wait_chain(1), "wait strategies")
})

test_that("wait_combine and + sum strategies", {
  w <- wait_fixed(1) + wait_exp(min = 0)
  expect_s3_class(w, "fnware::wait_combine")
  expect_equal(wait_fn(w, 3), 1 + 4)
  w3 <- wait_fixed(1) + wait_fixed(2) + wait_fixed(3)
  expect_equal(wait_fn(w3, 1), 6)
  expect_equal(
    wait_fn(wait_combine(wait_fixed(1), wait_chain(wait_fixed(2))), 1),
    3
  )
})

test_that("zero is a valid wait_exp and wait_exp_jitter setting", {
  expect_no_error(wait_exp(min = 0))
  expect_equal(wait_fn(wait_exp(min = 0, max = 0), 3), 0)

  for (jitter in c("full", "equal", "decorrelated", "none")) {
    for (w in list(
      wait_exp_jitter(base = 0, jitter = jitter),
      wait_exp_jitter(max_delay = 0, jitter = jitter),
      wait_exp_jitter(base = 0, max_delay = 0, jitter = jitter)
    )) {
      expect_equal(wait_fn(w, 1), 0)
      expect_equal(wait_fn(w, 5, prev_wait = 0), 0)
    }
  }
})

test_that("decorrelated jitter handles a zero previous wait", {
  w <- wait_exp_jitter(base = 0.1, max_delay = 20, jitter = "decorrelated")
  waits <- vapply(
    1:50,
    function(i) wait_fn(w, 2, prev_wait = 0),
    numeric(1)
  )
  expect_false(anyNA(waits))
  expect_equal(waits, rep(0.1, 50))

  # a larger previous wait still widens the range, capped at max_delay
  waits <- vapply(
    1:50,
    function(i) wait_fn(w, 2, prev_wait = 1),
    numeric(1)
  )
  expect_true(all(waits >= 0.1 & waits <= 3))
  expect_equal(
    wait_fn(
      wait_exp_jitter(base = 5, max_delay = 1, jitter = "decorrelated"),
      2,
      prev_wait = 10
    ),
    1
  )
})
