skip_if_not_installed("promises")
skip_if_not_installed("later")

# A function that counts its calls and resolves after `delay` seconds.
counting <- function(counter, delay = 0.02) {
  function(x, y = 2) {
    counter$n <- counter$n + 1L
    delayed(x * y, delay)
  }
}

new_counter <- function() {
  e <- new.env()
  e$n <- 0L
  e
}

test_that("results are cached and returned as promises", {
  counter <- new_counter()
  f <- async_lru_cache() %@% counting(counter)
  p <- f(2)
  expect_true(promises::is.promise(p))
  expect_equal(settle_promise(p)$value, 4)
  expect_equal(settle_promise(f(2))$value, 4)
  expect_equal(counter$n, 1L)
})

test_that("different arguments are cached separately", {
  counter <- new_counter()
  f <- async_lru_cache() %@% counting(counter)
  expect_equal(settle_promise(f(2))$value, 4)
  expect_equal(settle_promise(f(3))$value, 6)
  expect_equal(settle_promise(f(2))$value, 4)
  expect_equal(counter$n, 2L)
})

test_that("default arguments share a cache entry with explicit ones", {
  counter <- new_counter()
  f <- async_cache %@% counting(counter)
  expect_equal(settle_promise(f(2))$value, 4)
  expect_equal(settle_promise(f(2, y = 2))$value, 4)
  expect_equal(counter$n, 1L)
})

test_that("identical calls made at once share one run", {
  counter <- new_counter()
  f <- async_cache %@% counting(counter, delay = 0.1)
  ps <- list(f(5), f(5), f(5))
  vals <- vapply(ps, function(p) settle_promise(p)$value, numeric(1))
  expect_equal(vals, c(10, 10, 10))
  expect_equal(counter$n, 1L)
})

test_that("a rejection is not cached", {
  n <- 0L
  f <- async_cache %@%
    function(x) {
      n <<- n + 1L
      if (n == 1L) delayed_error("fail") else delayed("ok", 0.01)
    }
  res <- settle_promise(f(1))
  expect_match(conditionMessage(res$error), "fail")
  expect_equal(settle_promise(f(1))$value, "ok")
  expect_equal(settle_promise(f(1))$value, "ok")
  expect_equal(n, 2L)
})

test_that("concurrent calls share a rejection, then the next call tries again", {
  n <- 0L
  f <- async_cache %@%
    function(x) {
      n <<- n + 1L
      if (n == 1L) delayed_error("fail", 0.05) else delayed("ok", 0.01)
    }
  p1 <- f(1)
  p2 <- f(1)
  r1 <- settle_promise(p1)
  r2 <- settle_promise(p2)
  expect_match(conditionMessage(r1$error), "fail")
  expect_match(conditionMessage(r2$error), "fail")
  expect_equal(n, 1L)
  expect_equal(settle_promise(f(1))$value, "ok")
})

test_that("a thrown error is a rejection and is not cached", {
  n <- 0L
  f <- async_cache %@%
    function(x) {
      n <<- n + 1L
      if (n == 1L) stop("thrown") else x
    }
  res <- settle_promise(f(1))
  expect_match(conditionMessage(res$error), "thrown")
  expect_equal(settle_promise(f(1))$value, 1)
})

test_that("a plain value is cached too", {
  n <- 0L
  f <- async_cache %@%
    function(x) {
      n <<- n + 1L
      x + 1
    }
  expect_equal(settle_promise(f(1))$value, 2)
  expect_equal(settle_promise(f(1))$value, 2)
  expect_equal(n, 1L)
})

test_that("NULL results are cached", {
  n <- 0L
  f <- async_cache %@%
    function() {
      n <<- n + 1L
      delayed(NULL, 0.01)
    }
  expect_null(settle_promise(f())$value)
  expect_null(settle_promise(f())$value)
  expect_equal(n, 1L)
})

test_that("editing the function invalidates the entry", {
  counter <- new_counter()
  g1 <- async_cache %@% function(x) {
    counter$n <- counter$n + 1L
    delayed(x, 0.01)
  }
  g2 <- async_cache %@% function(x) {
    counter$n <- counter$n + 10L
    delayed(x, 0.01)
  }
  settle_promise(g1(1))
  settle_promise(g2(1))
  expect_equal(counter$n, 11L)
})

test_that("TTL expires entries", {
  counter <- new_counter()
  f <- async_lru_cache(TTL = 0.2) %@% counting(counter)
  settle_promise(f(1))
  settle_promise(f(1))
  expect_equal(counter$n, 1L)
  Sys.sleep(0.3)
  settle_promise(f(1))
  expect_equal(counter$n, 2L)
})

test_that("async_disk_cache() persists between decorators", {
  dir <- withr::local_tempdir()
  c1 <- new_counter()
  c2 <- new_counter()
  make <- function(counter) {
    async_disk_cache(dir) %@% function(x) {
      counter$n <- counter$n + 1L
      delayed(x * 3, 0.01)
    }
  }
  expect_equal(settle_promise(make(c1)(2))$value, 6)
  expect_equal(settle_promise(make(c2)(2))$value, 6)
  expect_equal(c1$n, 1L)
  expect_equal(c2$n, 0L)
})

test_that("async_disk_cache() and disk_cache() read each other's files", {
  dir <- withr::local_tempdir()
  c1 <- new_counter()
  c2 <- new_counter()
  # The function bodies must match, as the cache key includes the body.
  make_sync <- function(counter) {
    disk_cache(dir) %@% function(x) {
      counter$n <- counter$n + 1L
      x * 3
    }
  }
  make_async <- function(counter) {
    async_disk_cache(dir) %@% function(x) {
      counter$n <- counter$n + 1L
      x * 3
    }
  }
  expect_equal(make_sync(c1)(2), 6)
  expect_equal(settle_promise(make_async(c2)(2))$value, 6)
  expect_equal(c1$n, 1L)
  expect_equal(c2$n, 0L)
})

test_that("arguments are validated", {
  f <- function(x) x
  expect_error(async_disk_cache(1)(f), "`dir`")
  expect_error(async_disk_cache(c("a", "b"))(f), "`dir`")
  expect_error(async_disk_cache(tempfile(), format = "bogus")(f))
})
