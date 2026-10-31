# Write setup and teardown once

Port of Python's `contextlib.contextmanager`. R has no `yield`, so
instead of suspending the function the body calls `teardown()` right
after acquiring each resource and returns the resource. From that one
definition you get:

## Usage

``` r
contextmanager(f)

teardown(expr)
```

## Arguments

- expr:

  Code that releases the resource. Evaluated in the setup function's
  environment when the context ends, so it can use the setup's local
  variables.

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

## Value

`contextmanager` is a decorator. `teardown()` is called for its side
effect.

## Details

- a `local_` form: the function itself. Cleanup runs when the *calling*
  function exits, like `withr::local_*()`.

- a `with_` form:
  [`with_context()`](https://dyfanjones.github.io/garnish/reference/with_context.md)
  runs a block, then cleans up.

- a decorator:
  [`as_decorator()`](https://dyfanjones.github.io/garnish/reference/as_decorator.md)
  runs a function inside the context.

The decorated function takes `...`, passed on to the setup function, and
a `.local_envir` argument naming the frame whose exit triggers cleanup.
It defaults to the caller, or, when called from another context
manager's setup, to that context's `.local_envir`, so composed contexts
last as long as the outer one.

`teardown(expr)` registers `expr` with
[`withr::defer()`](https://withr.r-lib.org/reference/defer.html) on that
frame. Cleanups run last in, first out, and the ones already registered
still run if the rest of the setup fails. `teardown()` finds the frame
by searching the call stack for the nearest running context manager and
reading its `.local_envir`.

## See also

[`with_context()`](https://dyfanjones.github.io/garnish/reference/with_context.md),
[`as_decorator()`](https://dyfanjones.github.io/garnish/reference/as_decorator.md)

## Examples

``` r
local_tempdir := contextmanager %@% function(pattern = "tmp") {
  path <- tempfile(pattern)
  dir.create(path)
  teardown(unlink(path, recursive = TRUE))
  path
}

f <- function() {
  d <- local_tempdir()
  writeLines("hi", file.path(d, "x.txt"))
  d
}
d <- f()
dir.exists(d) # cleaned up when f() exited
#> [1] FALSE
```
