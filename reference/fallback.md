# Return a default when a function fails

Decorator that catches a failure and returns `value`, or the result of
`handler(cnd)`, instead of signalling it. Only errors are caught by
default. A caught condition ends the call, as with
[`tryCatch()`](https://rdrr.io/r/base/conditions.html).

## Usage

``` r
fallback(f, value = NULL, handler = NULL, class = "error",
  logger = NULL, level = "warn")
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

- logger:

  A [logger](https://dyfanjones.github.io/fnware/reference/loggers.md),
  such as
  [`logger_message()`](https://dyfanjones.github.io/fnware/reference/loggers.md),
  that logs each time the fallback is used, see
  [extending_log](https://dyfanjones.github.io/fnware/reference/extending_log.md)
  to use a logging package. `NULL`, the default, logs nothing.

- level:

  The level of that event: one of `"trace"`, `"debug"`, `"info"`,
  `"warn"`, `"error"` or `"fatal"`. Defaults to `"warn"`.

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

# Log each time the default is used
h := fallback(value = 0, logger = logger_message()) %@%
  function() stop("boom")
h()
#> WARN [2026-11-19T12:41:25.095Z]: Fallback used for h
#> Error in `h()`:
#> boom
#> [1] 0

# Use the default only after retries and the circuit breaker give up
fetch := fallback(value = NULL) %@%
  circuit_breaker(failures = 3) %@%
  retry(stop = stop_after_attempt(3)) %@%
  function(url) stop("down")
fetch("x")
#> NULL
```
