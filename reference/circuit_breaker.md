# Stop calling a function that keeps failing

Decorator that stops calling a function after it fails repeatedly, so
callers fail fast instead of waiting on something that is down. It has
three states:

## Arguments

- failures:

  Number of consecutive errors that open the circuit. A whole number of
  at least 1. Defaults to 5.

- reset_after:

  Seconds the circuit stays open before a trial call. A number greater
  than 0. Defaults to 30.

## Value

A decorator.

## Details

- **closed**: calls go through. Consecutive errors are counted.

- **open**: after `failures` consecutive errors, calls fail immediately
  with a `garnish_circuit_open` error, without running the function, for
  `reset_after` seconds.

- **half-open**: once the cooldown has passed, the next call runs as a
  trial. If it succeeds the circuit closes. If it fails the circuit
  opens again for another cooldown.

Only errors count as failures. A call that returns normally, whatever
its value, resets the count. Each decorated function keeps its own
state.

Stack it outside
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md) so
an open circuit rejects a call before any retries happen:

    fetch := circuit_breaker(failures = 3, reset_after = 30) %@%
      retry(stop = stop_after_attempt(3)) %@%
      function(url) { ... }

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
```
