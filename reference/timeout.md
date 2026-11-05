# Bound how long a call can run

Decorator that stops a single call after `seconds` and signals a
`fnware_timeout_error`. Unlike
[`stop_after_delay()`](https://dyfanjones.github.io/fnware/reference/stop_conditions.md),
which only checks between attempts, it bounds the call itself.

## Usage

``` r
timeout_r()

timeout(f, seconds, method = timeout_r())

timeout_remaining()
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

- seconds:

  Time limit for one call, in seconds. A number greater than 0.

- method:

  How to enforce the limit: a timeout method such as `timeout_r()`. See
  [`timeout_fn()`](https://dyfanjones.github.io/fnware/reference/extending_timeout.md)
  to write your own.

## Value

`timeout()` returns a decorator, `timeout_r()` a timeout method and
`timeout_remaining()` a number of seconds.

## Details

The condition inherits from `error`, so
[`retry_if_error()`](https://dyfanjones.github.io/fnware/reference/retry_conditions.md)
retries it and
[`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md)
counts it as a failure. It records the limit in `$limit` and the
function name in `$fn`. Stack `timeout()` inside
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) so
each attempt is capped. Outside
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) the
limit is already spent when the error is caught, so later attempts run
unbounded.

Timeouts can nest. The soonest active deadline always applies, so an
inner timeout never outlasts an outer one. `timeout_remaining()` returns
the seconds left before that deadline, or `Inf` outside any `timeout()`,
so you can pass the budget to a library with its own timeout. It does
not see deadlines in other R processes unless a method passes one on,
see
[`timeout_fn()`](https://dyfanjones.github.io/fnware/reference/extending_timeout.md).

For functions that return a promise, use
[`async_timeout()`](https://dyfanjones.github.io/fnware/reference/async_timeout.md).

## Limitations

`timeout_r()` uses
[`setTimeLimit()`](https://rdrr.io/r/base/setTimeLimit.html), which R
only checks between R expressions. It cannot interrupt compiled code
that never checks for interrupts (many blocking network and database
calls), or a single long
[`Sys.sleep()`](https://rdrr.io/r/base/Sys.sleep.html). For those, pass
`timeout_remaining()` to a native timeout or use a process-based method.
Code that catches every error around the slow part will also catch the
time limit error.

## Timeout methods

`method` decides how the limit is enforced. `timeout_r()` is the only
built-in method. To write your own, see
[`timeout_fn()`](https://dyfanjones.github.io/fnware/reference/extending_timeout.md).

## Examples

``` r
# A loop of short steps is interrupted between steps
slow <- function() {
  for (i in 1:100) Sys.sleep(0.05)
  "done"
}
f := timeout(0.2) %@% slow
try(f())
#> Error : `f` timed out: it did not finish within 0.2 seconds.

# Each attempt is capped, and a timeout is retried
attempts <- 0
flaky := retry(stop = stop_after_attempt(3)) %@%
  timeout(0.2) %@%
  function() {
    attempts <<- attempts + 1
    if (attempts < 3) slow() else "worked"
  }
flaky()
#> [1] "worked"

# Pass the remaining budget on
budget := timeout(10) %@% function() timeout_remaining()
budget()
#> [1] 9.999
```
