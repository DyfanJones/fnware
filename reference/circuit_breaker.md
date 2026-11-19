# Stop calling a function that keeps failing

Decorator that stops calling a function after it fails repeatedly, so
callers fail fast instead of waiting on something that is down. It has
three states:

## Usage

``` r
circuit_breaker(f, failures = 5, reset_after = 30, logger = NULL,
  level = c(open = "warn", close = "info"))
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

- failures:

  Number of consecutive errors that open the circuit. A whole number of
  at least 1. Defaults to 5.

- reset_after:

  Seconds the circuit stays open before a trial call. A number greater
  than 0. Defaults to 30.

- logger:

  A [logger](https://dyfanjones.github.io/fnware/reference/loggers.md),
  such as
  [`logger_message()`](https://dyfanjones.github.io/fnware/reference/loggers.md),
  that logs when the circuit opens and closes, see
  [extending_log](https://dyfanjones.github.io/fnware/reference/extending_log.md)
  to use a logging package. `NULL`, the default, logs nothing. Calls
  rejected while the circuit is open are not logged.

- level:

  The levels of those two events: a named character vector with `open`
  and `close`, each one of `"trace"`, `"debug"`, `"info"`, `"warn"`,
  `"error"` or `"fatal"`. Defaults to
  `c(open = "warn", close = "info")`. Name only one to change just that
  event.

## Value

A decorator.

## Details

- **closed**: calls go through. Consecutive errors are counted.

- **open**: after `failures` consecutive errors, calls fail immediately
  with a `fnware_circuit_open` error, without running the function, for
  `reset_after` seconds.

- **half-open**: once the cooldown has passed, the next call runs as a
  trial. If it succeeds the circuit closes. If it fails the circuit
  opens again for another cooldown.

Only errors count as failures. A call that returns normally, whatever
its value, resets the count. Each decorated function keeps its own
state.

Stack it outside
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) so
an open circuit rejects a call before any retries happen.

## Examples

``` r
n <- 0
flaky <- function() {
  n <<- n + 1
  stop("service down")
}
f := circuit_breaker(failures = 2, reset_after = 60) %@% flaky
try(f())
#> Error in <environment>$fn() : service down
try(f())
#> Error in <environment>$fn() : service down
try(f()) # rejected without calling flaky()
#> Error : Circuit is open: the function failed repeatedly and is not being called.
n # still 2
#> [1] 2

# Log when the circuit opens
g := circuit_breaker(failures = 1, logger = logger_message()) %@%
  function() stop("service down")
try(g(), silent = TRUE)
#> WARN [2026-11-19T12:41:21.214Z]: Circuit opened for g, rejecting calls for 30 seconds
#> Error in `g()`:
#> service down

# Reject before any retries happen
fetch := circuit_breaker(failures = 3, reset_after = 30) %@%
  retry(stop = stop_after_attempt(3)) %@%
  function(url) url
```
