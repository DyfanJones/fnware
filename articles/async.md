# Asynchronous decorators

``` r

library(fnware)
```

Most decorators wait by blocking:
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md)
sleeps and
[`rate_limit()`](https://dyfanjones.github.io/fnware/reference/rate_limit.md)
sleeps. That is fine in a script, but it freezes a Shiny app or a
plumber API. For functions that return a
[promise](https://rstudio.github.io/promises/), each decorator has an
`async_` version that waits with `later` instead, and always returns a
promise.

| Blocking | Asynchronous |
|----|----|
| [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) | [`async_retry()`](https://dyfanjones.github.io/fnware/reference/async_retry.md) |
| [`timeout()`](https://dyfanjones.github.io/fnware/reference/timeout.md) | [`async_timeout()`](https://dyfanjones.github.io/fnware/reference/async_timeout.md) |
| [`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md) | [`async_circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/async_circuit_breaker.md) |
| [`rate_limit()`](https://dyfanjones.github.io/fnware/reference/rate_limit.md) | [`async_rate_limit()`](https://dyfanjones.github.io/fnware/reference/async_rate_limit.md) |
| [`fallback()`](https://dyfanjones.github.io/fnware/reference/fallback.md) | [`async_fallback()`](https://dyfanjones.github.io/fnware/reference/async_fallback.md) |
| [`lru_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md), `cache`, [`disk_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md) | [`async_lru_cache()`](https://dyfanjones.github.io/fnware/reference/async_lru_cache.md), `async_cache`, [`async_disk_cache()`](https://dyfanjones.github.io/fnware/reference/async_lru_cache.md) |
| `once` | `async_once` |
| [`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md) | [`async_log_call()`](https://dyfanjones.github.io/fnware/reference/async_log_call.md) |
| [`validate_return()`](https://dyfanjones.github.io/fnware/reference/validate_args.md) | [`async_validate_return()`](https://dyfanjones.github.io/fnware/reference/async_validate_return.md) |

[`validate_args()`](https://dyfanjones.github.io/fnware/reference/validate_args.md)
works for both, because arguments are known when the function is called.
`contextmanager` has no async version: its cleanup runs when a function
exits, which for a promise is before the work is done.

## Why not the blocking version?

The blocking versions look at the function, not its promise, so they see
the wrong thing:

- [`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)
  logs the finish when the promise is returned, not when it settles.
- [`validate_return()`](https://dyfanjones.github.io/fnware/reference/validate_args.md)
  checks the promise object, not the value it resolves to.
- [`timeout()`](https://dyfanjones.github.io/fnware/reference/timeout.md)
  cannot bound work that happens after the function has returned.
- `once` stores a rejected promise, so every later call fails.

The `async_` versions follow the promise, so a rejection is a failure,
and the value that is cached, validated or logged is the one it resolves
to.

## Stacking

The stacking order is the same as for the blocking versions, see
[`vignette("decorators")`](https://dyfanjones.github.io/fnware/articles/decorators.md).
Put
[`async_retry()`](https://dyfanjones.github.io/fnware/reference/async_retry.md)
outermost of the ones that wait, and cap each attempt with
[`async_timeout()`](https://dyfanjones.github.io/fnware/reference/async_timeout.md)
inside it.

``` r

n <- 0
fetch := async_fallback(value = "default") %@%
  async_retry(stop = stop_after_attempt(3), wait = wait_fixed(0.05)) %@%
  async_timeout(1) %@%
  function(url) {
    n <<- n + 1
    if (n < 3) stop("not yet")
    paste("response from", url)
  }

promises::then(fetch("example.com"), function(value) cat(value, "\n"))

# Shiny and plumber run the event loop for you. In a script, run it yourself.
while (!later::loop_empty()) {
  later::run_now(0.1)
}
```

    ## response from example.com

All of them need the promises package, and the ones that schedule work
also need later. Both are only suggested by fnware, so you are told
which to install the first time you use an `async_` decorator.
