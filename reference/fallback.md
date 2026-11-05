# Return a default when a function fails

Decorator that catches a failure and returns `value`, or the result of
`handler(cnd)`, instead of signalling it. Only errors are caught by
default. A caught condition ends the call, as with
[`tryCatch()`](https://rdrr.io/r/base/conditions.html).

## Usage

``` r
fallback(f, value = NULL, handler = NULL, class = "error")
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

- value:

  Value to return on failure. Ignored if `handler` is given.

- handler:

  Optional function taking the condition and returning the result.

- class:

  Condition classes to catch. Defaults to `"error"`.

## Value

A decorator.

## Details

Stack it outside
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) and
[`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md)
so the default is used only once retries are spent or the circuit is
open.

## Examples

``` r
f := fallback(value = NA_real_) %@% function(x) {
  if (x < 0) stop("negative") else sqrt(x)
}
f(4)
#> [1] 2
f(-1)
#> [1] NA

g := fallback(handler = function(cnd) conditionMessage(cnd)) %@%
  function() stop("boom")
g()
#> [1] "boom"

# Use the default only after retries and the circuit breaker give up
fetch := fallback(value = NULL) %@%
  circuit_breaker(failures = 3) %@%
  retry(stop = stop_after_attempt(3)) %@%
  function(url) stop("down")
fetch("x")
#> NULL
```
