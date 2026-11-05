# Choosing and stacking decorators

``` r

library(fnware)
```

## Which decorator do I want?

| The problem | Decorator | Guide |
|----|----|----|
| A call fails now and then | [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) | [`vignette("retry")`](https://dyfanjones.github.io/fnware/articles/retry.md) |
| A call hangs | [`timeout()`](https://dyfanjones.github.io/fnware/reference/timeout.md) | [`vignette("retry")`](https://dyfanjones.github.io/fnware/articles/retry.md) |
| A service is down and callers keep waiting on it | [`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md) | [`vignette("circuitbreaker")`](https://dyfanjones.github.io/fnware/articles/circuitbreaker.md) |
| An API allows only so many calls | [`rate_limit()`](https://dyfanjones.github.io/fnware/reference/rate_limit.md) | [`?rate_limit`](https://dyfanjones.github.io/fnware/reference/rate_limit.md) |
| A failure should become a default value | [`fallback()`](https://dyfanjones.github.io/fnware/reference/fallback.md) | [`vignette("fallback")`](https://dyfanjones.github.io/fnware/articles/fallback.md) |
| A result is slow to compute and gets asked for again | [`lru_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md), `cache`, [`disk_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md) | [`vignette("caching")`](https://dyfanjones.github.io/fnware/articles/caching.md) |
| Setup should happen a single time | `once` | [`vignette("fallback")`](https://dyfanjones.github.io/fnware/articles/fallback.md) |
| You want to see what is being called | [`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md) | [`vignette("logging")`](https://dyfanjones.github.io/fnware/articles/logging.md) |
| Bad input or output should be caught early | [`validate_args()`](https://dyfanjones.github.io/fnware/reference/validate_args.md), [`validate_return()`](https://dyfanjones.github.io/fnware/reference/validate_args.md) | [`vignette("validation")`](https://dyfanjones.github.io/fnware/articles/validation.md) |
| Setup and teardown around a resource | `contextmanager` | [`vignette("contextmanager")`](https://dyfanjones.github.io/fnware/articles/contextmanager.md) |

For a function that returns a promise, every decorator above except
`contextmanager` has an `async_` version. See
[`vignette("async")`](https://dyfanjones.github.io/fnware/articles/async.md).

## Stacking order

Decorators stack, and in `a %@% b %@% f`, `a` is outermost. The order
changes what each one sees. This is the order that works for the common
cases, from outside to inside:

    validate_args()      reject bad input before doing any work
    fallback()           use a default only once everything below has given up
    circuit_breaker()    fail fast when the service is clearly down
    cache / lru_cache()  skip the work for a repeated call
    retry()              try again when a call fails
    rate_limit()         throttle every attempt, retries included
    timeout()            cap each attempt
    log_call()           log the call itself

You will rarely need all of them. Skip the ones you do not need and keep
the rest in this order.

``` r

n <- 0
fetch := validate_args(url = is.character) %@%
  fallback(value = NA_character_) %@%
  retry(stop = stop_after_attempt(3)) %@%
  function(url) {
    n <<- n + 1
    if (n < 3) stop("not yet")
    paste("response from", url)
  }
fetch("example.com")
```

    ## [1] "response from example.com"

The reasons behind the order:

- **[`validate_args()`](https://dyfanjones.github.io/fnware/reference/validate_args.md)
  outermost.** A bad argument is the caller’s mistake. Retrying or
  caching it only repeats the mistake.
- **[`fallback()`](https://dyfanjones.github.io/fnware/reference/fallback.md)
  outside
  [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md)
  and
  [`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md).**
  The default is used once retries are spent or the circuit is open, not
  after the first failure.
- **[`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md)
  outside
  [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md).**
  An open circuit rejects the call before any retries happen.
- **[`rate_limit()`](https://dyfanjones.github.io/fnware/reference/rate_limit.md)
  and
  [`timeout()`](https://dyfanjones.github.io/fnware/reference/timeout.md)
  inside
  [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md).**
  Each attempt is then throttled and capped. Outside it, only whole
  calls would be, and retries could still exceed the limit or run
  without one.

Put the caches where you want them to sit. Outside
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md), a
successful result is cached once. Because only a returned value is
stored, an error is never cached.
