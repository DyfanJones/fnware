counted <- function(fn) {
  calls <- 0L
  list(
    f = function(...) {
      calls <<- calls + 1L
      fn(...)
    },
    calls = function() calls
  )
}

test_that("lru_cache returns cached results without calling again", {
  ct <- counted(function(x) x^2)
  g <- lru_cache() %@% ct$f
  expect_equal(g(4), 16)
  expect_equal(g(4), 16)
  expect_equal(ct$calls(), 1L)
  expect_equal(g(5), 25)
  expect_equal(ct$calls(), 2L)
})

test_that("positional, named and default arguments share a cache entry", {
  calls <- 0L
  g <- lru_cache() %@% function(x, y = 2) {
    calls <<- calls + 1L
    x * y
  }
  g(3)
  g(x = 3)
  g(3, 2)
  g(y = 2, x = 3)
  expect_equal(calls, 1L)
  g(3, 5)
  expect_equal(calls, 2L)
})

test_that("each decorated function has its own cache", {
  a <- lru_cache() %@% function(x) x + 1
  b <- lru_cache() %@% function(x) x + 100
  expect_equal(a(1), 2)
  expect_equal(b(1), 101)
})

test_that("invisible results stay invisible on hits and misses", {
  g <- lru_cache() %@% function() invisible("quiet")
  expect_invisible(g())
  expect_invisible(g())
  h <- lru_cache() %@% function() "loud"
  expect_visible(h())
  expect_visible(h())
})

test_that("errors are not cached", {
  calls <- 0L
  g <- lru_cache() %@% function() {
    calls <<- calls + 1L
    if (calls < 2L) stop("boom")
    "ok"
  }
  expect_error(g(), "boom")
  expect_equal(g(), "ok")
  expect_equal(g(), "ok")
  expect_equal(calls, 2L)
})

test_that("NULL results are cached", {
  calls <- 0L
  g <- lru_cache() %@% function() {
    calls <<- calls + 1L
    NULL
  }
  g()
  g()
  expect_equal(calls, 1L)
})

test_that("a default that depends on another argument is part of the key", {
  g <- lru_cache() %@% function(x, y = x * 2) x + y
  expect_equal(g(1), 3)
  expect_equal(g(1, 10), 11)
  expect_equal(g(2), 6)
})

test_that("a small maxsize evicts the least recently used entry", {
  calls <- 0L
  g <- lru_cache(maxsize = 7000) %@% function(i) {
    calls <<- calls + 1L
    numeric(200) + i # about 2 KB per entry, so three fit
  }
  g(1); g(2); g(3)
  g(1) # refresh 1 so 2 is the least recently used
  g(4)
  before <- calls
  g(1)
  expect_equal(calls, before) # still cached
  g(2)
  expect_equal(calls, before + 1L) # evicted
})

test_that("cache never evicts", {
  calls <- 0L
  g <- cache %@% function(i) {
    calls <<- calls + 1L
    numeric(200000) + i # 1.6 MB per entry
  }
  for (i in 1:20) g(i)
  for (i in 1:20) g(i)
  expect_equal(calls, 20L)
})

test_that("cache shares entries across argument spellings and keeps visibility", {
  calls <- 0L
  g <- cache %@% function(x, y = 2) {
    calls <<- calls + 1L
    invisible(x * y)
  }
  expect_invisible(g(3))
  g(x = 3, y = 2)
  expect_equal(calls, 1L)
})

test_that("cache is applied bare and keeps separate caches per function", {
  a <- cache %@% function(x) x + 1
  b <- cache %@% function(x) x + 100
  expect_equal(c(a(1), b(1)), c(2, 101))
})

test_that("disk_cache returns cached results and writes files to dir", {
  dir <- withr::local_tempdir()
  calls <- 0L
  g <- disk_cache(dir) %@% function(x) {
    calls <<- calls + 1L
    x^2
  }
  expect_equal(g(4), 16)
  expect_equal(g(4), 16)
  expect_equal(calls, 1L)
  expect_length(list.files(dir), 1L)
})

test_that("disk_cache entries are reused by a fresh decoration of the same function", {
  dir <- withr::local_tempdir()
  calls <- 0L
  make <- function() {
    disk_cache(dir) %@% function(x) {
      calls <<- calls + 1L
      x + 1
    }
  }
  make()(1)
  make()(1) # new decorator, same dir: a hit, as from a new session
  expect_equal(calls, 1L)
})

test_that("changing the function body invalidates disk_cache entries", {
  dir <- withr::local_tempdir()
  a <- disk_cache(dir) %@% function(x) x + 1
  b <- disk_cache(dir) %@% function(x) x + 2
  expect_equal(a(1), 2)
  expect_equal(b(1), 3)
})

test_that("disk_cache keeps invisibility and defaults", {
  dir <- withr::local_tempdir()
  calls <- 0L
  g <- disk_cache(dir) %@% function(x, y = 2) {
    calls <<- calls + 1L
    invisible(x * y)
  }
  expect_invisible(g(3))
  expect_invisible(g(x = 3, y = 2))
  expect_equal(calls, 1L)
})

test_that("disk_cache needs a dir", {
  expect_error(disk_cache() %@% function() 1)
  expect_error(disk_cache(dir = 1) %@% function() 1)
})

test_that("the function body is part of the key", {
  # A stand-in with an unchanging body is what a factory sees as `f`, so this
  # guards against hashing it instead of the real function.
  dir <- withr::local_tempdir()
  a <- disk_cache(dir) %@% function(x) x + 1
  b <- disk_cache(dir) %@% function(x) x + 2
  expect_equal(c(a(1), b(1)), c(2, 3))
})

test_that("disk_cache can store results with qs2", {
  skip_if_not_installed("qs2")
  dir <- withr::local_tempdir()
  calls <- 0L
  g <- disk_cache(dir, format = "qs2") %@% function(x) {
    calls <<- calls + 1L
    data.frame(x = x, y = x^2)
  }
  expect_equal(g(3), data.frame(x = 3, y = 9))
  expect_equal(g(3), data.frame(x = 3, y = 9))
  expect_equal(calls, 1L)
  expect_match(list.files(dir), "\\.qs2$")
})

test_that("rds and qs2 caches in one directory do not collide", {
  skip_if_not_installed("qs2")
  dir <- withr::local_tempdir()
  calls <- 0L
  make <- function(format) {
    disk_cache(dir, format = format) %@% function(x) {
      calls <<- calls + 1L
      x
    }
  }
  make("rds")(1)
  make("qs2")(1)
  expect_equal(calls, 2L)
})

test_that("disk_cache rejects an unknown format", {
  expect_error(disk_cache(tempfile(), format = "csv") %@% function() 1)
})
