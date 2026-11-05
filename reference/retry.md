# Retry a function when it fails

Decorator that calls a function again until it succeeds or a [stop
condition](https://dyfanjones.github.io/fnware/reference/stop_conditions.md)
condition is met, sleeping between attempts. Port of Python's tenacity.

## Usage

``` r
retry(
  f,
  stop = stop_never(),
  wait = wait_none(),
  retry = retry_all(),
  before_sleep = before_sleep_none(),
  after_sleep = after_sleep_none(),
  reraise = FALSE,
  retry_error_callback = NULL
)
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

- stop:

  A stop condition, e.g.
  [`stop_after_attempt()`](https://dyfanjones.github.io/fnware/reference/stop_conditions.md).
  Defaults to never stopping.

- wait:

  A [wait
  strategy](https://dyfanjones.github.io/fnware/reference/wait_strategies.md).
  Defaults to no waiting.

- retry:

  A [retry
  condition](https://dyfanjones.github.io/fnware/reference/retry_conditions.md).
  Defaults to retrying every error.

- before_sleep, after_sleep:

  Hooks run before and after each sleep, see
  [`before_sleep_log()`](https://dyfanjones.github.io/fnware/reference/before_sleep.md)
  and
  [`after_sleep_log()`](https://dyfanjones.github.io/fnware/reference/after_sleep.md).

- reraise:

  If `TRUE`, re-throw the last error when `stop` fires instead of
  throwing a `retry_error`.

- retry_error_callback:

  Optional function called with the final state when `stop` fires. Its
  return value is returned instead of throwing. The state is a list with
  `attempt`, `wait`, `elapsed`, `error` and `value`.

## Value

A decorator. The decorated function returns the first acceptable result,
or signals a `retry_error` condition (with `$attempt`, `$error` and
`$value`) once `stop` fires.

## Details

Call
`retry(stop, wait, retry, before_sleep, after_sleep, reraise, retry_error_callback)`
to build a decorator, then apply it with `%@%` or by calling it on a
function.

## Examples

``` r
n <- 0
flaky <- function() {
  n <<- n + 1
  if (n < 3) stop("not yet")
  n
}
retry(stop = stop_after_attempt(5))(flaky)()
#> [1] 3

# Back off exponentially between attempts
f := retry(stop = stop_after_attempt(3), wait = wait_exp(min = 0.1)) %@% function() 1
f()
#> [1] 1
```
