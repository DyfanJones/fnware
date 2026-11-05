# Run an asynchronous function only once

Asynchronous version of
[`once()`](https://dyfanjones.github.io/fnware/reference/once.md), for
functions that return a
[promise](https://rstudio.github.io/promises/reference/promise.html).
The first call's resolved value is kept and every later call returns a
promise of it, ignoring its arguments. Calls made while the first is
still running share its promise. A rejection stores nothing, so the next
call tries again. Needs the promises package.

## Usage

``` r
async_once(f)
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

## Value

A decorator. The decorated function returns a promise.

## Examples

``` r
if (FALSE) { # \dontrun{
setup := async_once %@% function() {
  cat("setting up\n")
  promises::promise_resolve(42)
}
promises::then(setup(), print)
promises::then(setup(), print) # no second "setting up"
while (!later::loop_empty()) later::run_now(0.05)
} # }
```
