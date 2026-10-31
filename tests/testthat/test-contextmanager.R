# Records acquire/release events so tests can check order and timing.
tracker <- function() {
  log <- character()
  list(
    add = function(x) log <<- c(log, x),
    get = function() log
  )
}

test_that("local form cleans up when the calling function exits", {
  tr <- tracker()
  local_res := contextmanager %@%
    function(name = "a") {
      tr$add(paste("open", name))
      teardown(tr$add(paste("close", name)))
      name
    }
  f <- function() {
    x <- local_res("x")
    tr$add("body")
    x
  }
  expect_equal(f(), "x")
  expect_equal(tr$get(), c("open x", "body", "close x"))
})

test_that("local form cleans up when the caller errors", {
  tr <- tracker()
  local_res := contextmanager %@%
    function() {
      teardown(tr$add("close"))
      1
    }
  f <- function() {
    local_res()
    stop("boom")
  }
  expect_error(f(), "boom")
  expect_equal(tr$get(), "close")
})

test_that("arguments pass through, by position or name", {
  local_echo := contextmanager %@% function(a, b = 2) c(a, b)
  f <- function() list(local_echo(1), local_echo(b = 5, a = 3))
  expect_equal(f(), list(c(1, 2), c(3, 5)))
})

test_that("with_context passes the value and cleans up afterwards", {
  tr <- tracker()
  local_res := contextmanager %@%
    function() {
      tr$add("open")
      teardown(tr$add("close"))
      "val"
    }
  out <- with_context(local_res(), function(v) {
    tr$add(paste("body", v))
    "result"
  })
  expect_equal(out, "result")
  expect_equal(tr$get(), c("open", "body val", "close"))
})

test_that("with_context cleans up when the code errors", {
  tr <- tracker()
  local_res := contextmanager %@%
    function() {
      teardown(tr$add("close"))
      1
    }
  expect_error(with_context(local_res(), function(v) stop("boom")), "boom")
  expect_equal(tr$get(), "close")
})

test_that("as_decorator runs the function inside the context", {
  tr <- tracker()
  local_res := contextmanager %@%
    function() {
      tr$add("open")
      teardown(tr$add("close"))
    }
  g := as_decorator(local_res) %@%
    function(x) {
      tr$add("body")
      x * 2
    }
  expect_equal(g(4), 8)
  expect_equal(tr$get(), c("open", "body", "close"))
})

test_that("as_decorator cleans up on error and forwards context arguments", {
  tr <- tracker()
  local_res := contextmanager %@%
    function(name) {
      teardown(tr$add(paste("close", name)))
    }
  g := as_decorator(local_res, "r") %@% function() stop("boom")
  expect_error(g(), "boom")
  expect_equal(tr$get(), "close r")
})

test_that("teardowns run last in, first out", {
  tr <- tracker()
  local_two := contextmanager %@%
    function() {
      teardown(tr$add("first"))
      teardown(tr$add("second"))
      teardown(tr$add("third"))
    }
  f <- function() local_two()
  f()
  expect_equal(tr$get(), c("third", "second", "first"))
})

test_that("teardowns registered before a setup failure still run", {
  tr <- tracker()
  local_partial := contextmanager %@%
    function() {
      teardown(tr$add("close a"))
      stop("setup failed")
      teardown(tr$add("close b"))
    }
  f <- function() local_partial()
  expect_error(f(), "setup failed")
  expect_equal(tr$get(), "close a")

  tr2 <- tracker()
  local_partial2 := contextmanager %@%
    function() {
      teardown(tr2$add("close a"))
      stop("setup failed")
    }
  expect_error(with_context(local_partial2(), identity), "setup failed")
  expect_equal(tr2$get(), "close a")
})

test_that("teardown can use the setup function's local variables", {
  seen <- NULL
  local_res := contextmanager %@%
    function() {
      path <- "secret"
      teardown(seen <<- path)
    }
  f <- function() local_res()
  f()
  expect_equal(seen, "secret")
})

test_that("nested contexts register on the right frames", {
  tr <- tracker()
  local_inner := contextmanager %@%
    function() {
      tr$add("open inner")
      teardown(tr$add("close inner"))
    }
  local_outer := contextmanager %@%
    function() {
      tr$add("open outer")
      teardown(tr$add("close outer"))
      local_inner()
      tr$add("outer setup done")
    }
  f <- function() {
    local_outer()
    tr$add("body")
  }
  f()
  expect_equal(
    tr$get(),
    c(
      "open outer",
      "open inner",
      "outer setup done",
      "body",
      "close inner",
      "close outer"
    )
  )
})

test_that("an inner context ends with its own caller, not the outer one", {
  tr <- tracker()
  local_res := contextmanager %@%
    function(name) {
      teardown(tr$add(paste("close", name)))
    }
  outer <- function() {
    local_res("outer")
    inner <- function() {
      local_res("inner")
      tr$add("inner body")
    }
    inner()
    tr$add("outer body")
  }
  outer()
  expect_equal(
    tr$get(),
    c("inner body", "close inner", "outer body", "close outer")
  )
})

test_that("local() blocks clean up at the end of the block", {
  tr <- tracker()
  local_res := contextmanager %@%
    function() {
      teardown(tr$add("close"))
    }
  local({
    local_res()
    tr$add("in local")
  })
  tr$add("after local")
  expect_equal(tr$get(), c("in local", "close", "after local"))
})

test_that("teardown outside a context manager is an error", {
  expect_error(teardown(1), "contextmanager")
})

test_that("a caller that is not on the call stack owns the context", {
  expect_identical(context_envir(globalenv()), globalenv())
})

test_that("works when defined outside the package namespace", {
  env <- new.env(parent = globalenv())
  local_res <- eval(quote(contextmanager %@% function() 1), env)
  expect_equal(
    local({
      local_res()
    }),
    1
  )
})
