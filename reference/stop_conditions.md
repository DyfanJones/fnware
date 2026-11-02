# Stop conditions

Decide when
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
gives up. A condition is checked after each failed attempt.

## Usage

``` r
stop_never()

stop_after_attempt(max_attempt_number = 1)

stop_after_delay(max_delay = 1)

stop_before_delay(max_delay = 1)

stop_any(...)

stop_all(...)
```

## Arguments

- max_attempt_number:

  Number of attempts to allow.

- max_delay:

  Seconds since the first attempt.

- ...:

  Stop conditions to combine.

## Value

A stop condition to pass to
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md).

## Details

- `stop_never()` never stops.

- `stop_after_attempt()` stops after a number of attempts.

- `stop_after_delay()` stops once that many seconds have passed since
  the first attempt.

- `stop_before_delay()` stops if sleeping again would reach that many
  seconds.

- `stop_any()` stops when any of the given conditions is met.

- `stop_all()` stops when all of the given conditions are met.
  `stop_after_delay()` and `stop_before_delay()` only check the clock
  between attempts. They do not interrupt an attempt that is already
  running, so a call that hangs never gets back to them. Use
  [`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
  to bound a single attempt.

## Examples

``` r
stop_after_attempt(3)
#> <garnish::stop_after_attempt>
#>  @ max_attempt_number: num 3
stop_any(stop_after_attempt(5), stop_after_delay(10))
#> <garnish::stop_any>
#>  @ stops:List of 2
#>  .. $ : <garnish::stop_after_attempt>
#>  ..  ..@ max_attempt_number: num 5
#>  .. $ : <garnish::stop_after_delay>
#>  ..  ..@ max_delay: num 10
```
