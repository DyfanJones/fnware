# Run code inside a context

The scoped form of a
[`contextmanager()`](https://dyfanjones.github.io/fnware/reference/contextmanager.md).
Evaluates `ctx` with cleanup tied to this call, passes the value it
returns to `code`, and cleans up when `code` finishes, even if it
errors.

## Usage

``` r
with_context(ctx, code)
```

## Arguments

- ctx:

  A call to a context manager, e.g. `local_tempdir()`. It is not
  evaluated in your frame: `.local_envir` is set to this function's
  frame.

- code:

  A function taking the context's value.

## Value

The value of `code`.

## Examples

``` r
local_tempdir := contextmanager %@% function() {
  path <- tempfile()
  dir.create(path)
  teardown(unlink(path, recursive = TRUE))
  path
}
with_context(local_tempdir(), function(d) dir.exists(d))
#> [1] TRUE
```
