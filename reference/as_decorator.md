# Use a context manager as a decorator

Decorator form of a
[`contextmanager()`](https://dyfanjones.github.io/fnware/reference/contextmanager.md):
the decorated function runs inside the context, and cleanup runs when it
returns or errors. As in Python's `ContextDecorator`, the context's
value is not passed to the function.

## Usage

``` r
as_decorator(ctx, ...)
```

## Arguments

- ctx:

  A context manager.

- ...:

  Arguments for `ctx`.

## Value

A decorator.

## Examples

``` r
local_tempdir := contextmanager %@% function() {
  path <- tempfile()
  dir.create(path)
  teardown(unlink(path, recursive = TRUE))
  path
}
g := as_decorator(local_tempdir) %@% function() "ran inside context"
g()
#> [1] "ran inside context"
```
