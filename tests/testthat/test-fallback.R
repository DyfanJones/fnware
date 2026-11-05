test_that("returns the value when the function errors", {
  f <- fallback(value = "default") %@% function() stop("boom")
  expect_equal(f(), "default")
})

test_that("passes results through when nothing fails", {
  f <- fallback(value = "default") %@% function(x) x + 1
  expect_equal(f(1), 2)
})

test_that("value defaults to NULL", {
  f <- fallback() %@% function() stop("boom")
  expect_null(f())
})

test_that("handler receives the condition and builds the result", {
  f <- fallback(handler = function(cnd) conditionMessage(cnd)) %@%
    function() stop("boom")
  expect_equal(f(), "boom")
})

test_that("handler wins over value", {
  f <- fallback(value = "v", handler = function(cnd) "h") %@%
    function() stop("boom")
  expect_equal(f(), "h")
})

test_that("only the requested classes are caught", {
  f <- fallback(value = "caught", class = "custom_error") %@%
    function(x) {
      if (x) rlang::abort("a", class = "custom_error") else stop("b")
    }
  expect_equal(f(TRUE), "caught")
  expect_error(f(FALSE), "b")
})

test_that("warnings can be caught", {
  f <- fallback(value = "warned", class = "warning") %@%
    function() warning("careful")
  expect_equal(f(), "warned")
})

test_that("warnings pass through when only errors are caught", {
  f <- fallback(value = "x") %@%
    function() {
      warning("careful")
      "done"
    }
  expect_warning(res <- f(), "careful")
  expect_equal(res, "done")
})

test_that("checks its arguments", {
  expect_error(fallback(handler = 1)(identity), "`handler` must be a function")
  expect_error(fallback(class = 1)(identity), "`class` must be a character")
  expect_error(fallback(class = character())(identity), "`class` must be")
})

test_that("works around circuit_breaker", {
  f <- fallback(value = "open") %@%
    circuit_breaker(failures = 1, reset_after = 60) %@%
    function() stop("down")
  expect_equal(f(), "open")
  expect_equal(f(), "open")
})
