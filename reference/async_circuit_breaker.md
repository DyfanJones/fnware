# Stop calling an asynchronous function that keeps failing

Asynchronous version of
[`circuit_breaker()`](https://dyfanjones.github.io/garnish/reference/circuit_breaker.md),
for functions that return a
[promise](https://rstudio.github.io/promises/reference/promise.html). It
has the same states and arguments. A call fails when its promise
rejects, or the function throws. Once the circuit is open, calls return
a promise already rejected with `garnish_circuit_open`, without running
the function.

## Usage

``` r
async_circuit_breaker(f, failures = 5, reset_after = 30)
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

## Value

A decorator. The decorated function returns a promise.

## Details

Calls overlap, so a failure is counted when its promise rejects, and
calls made before earlier ones settle all go through. Two more rules:

- While half-open, only one trial call runs and others are rejected. A
  trial not settled after `reset_after` seconds is abandoned, so a
  promise that never settles cannot hold the circuit shut. Put
  [`async_timeout()`](https://dyfanjones.github.io/garnish/reference/async_timeout.md)
  inside to bound it sooner.

- A call that started before the circuit opened cannot close it, or be
  counted again, when it settles.

Stack it outside
[`async_retry()`](https://dyfanjones.github.io/garnish/reference/async_retry.md).
Needs the promises package and an event loop.

## Examples

``` r
if (FALSE) { # \dontrun{
down <- function() promises::promise_reject(simpleError("service down"))
f := async_circuit_breaker(failures = 2, reset_after = 60) %@% down

# Failures are counted when a promise settles, so let each call settle
try_once <- function() {
  promises::then(f(), onRejected = function(err) cat(class(err)[[1]], "\n"))
  while (!later::loop_empty()) later::run_now(0.1)
}
try_once() # simpleError
try_once() # simpleError, and the circuit opens
try_once() # garnish_circuit_open, down() was not called

fetch := async_circuit_breaker(failures = 3, reset_after = 30) %@%
  async_retry(stop = stop_after_attempt(3)) %@%
  function(url) down()
} # }
```
