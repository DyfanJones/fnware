# Retry a function without blocking

Asynchronous version of
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md),
for functions that return a
[promise](https://rstudio.github.io/promises/reference/promise.html). It
uses the same strategies and hooks, but schedules the next attempt with
[`later::later()`](https://later.r-lib.org/reference/later.html) instead
of sleeping, so the session is free between attempts.

## Usage

``` r
async_retry(
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
  [`stop_after_attempt()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md).
  Defaults to never stopping.

- wait:

  A [wait
  strategy](https://dyfanjones.github.io/garnish/reference/wait_strategies.md).
  Defaults to no waiting.

- retry:

  A [retry
  condition](https://dyfanjones.github.io/garnish/reference/retry_conditions.md).
  Defaults to retrying every error.

- before_sleep, after_sleep:

  Hooks run before and after each sleep, see
  [`before_sleep_log()`](https://dyfanjones.github.io/garnish/reference/before_sleep.md)
  and
  [`after_sleep_log()`](https://dyfanjones.github.io/garnish/reference/after_sleep.md).

- reraise:

  If `TRUE`, re-throw the last error when `stop` fires instead of
  throwing a `retry_error`.

- retry_error_callback:

  Optional function called with the final state when `stop` fires. Its
  return value is returned instead of throwing. The state is a list with
  `attempt`, `wait`, `elapsed`, `error` and `value`.

## Value

A decorator. The decorated function returns a promise.

## Details

The decorated function returns a promise. It resolves with the first
acceptable result, and rejects with the last error, or a `retry_error`
once `stop` fires. The wrapped function may return a promise or a plain
value, and a rejection or a thrown error counts as a failure.

Use it as the outermost decorator.
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
cannot bound a promise, so cap each attempt with
[`async_timeout()`](https://dyfanjones.github.io/garnish/reference/async_timeout.md).
The hooks and `retry_error_callback` run in the event loop, so keep them
quick. Needs the promises and later packages, and an event loop for the
promise to settle.

## Examples

``` r
if (FALSE) { # \dontrun{
n <- 0
flaky <- function() {
  n <<- n + 1
  if (n < 3) stop("not yet")
  n
}
f <- async_retry(stop = stop_after_attempt(5), wait = wait_fixed(0.05)) %@%
  flaky
promises::then(f(), function(value) cat("worked on attempt", value, "\n"))

# Shiny and plumber run the event loop for you. In a script, run it yourself.
while (!later::loop_empty()) later::run_now(0.1)
} # }
```
