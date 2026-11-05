<!-- badges: start -->
[![R-CMD-check](https://github.com/DyfanJones/fnware/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/DyfanJones/fnware/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/DyfanJones/fnware/graph/badge.svg)](https://app.codecov.io/gh/DyfanJones/fnware)
[![R-universe version](https://DyfanJones.r-universe.dev/fnware/badges/version)](https://DyfanJones.r-universe.dev/fnware)
<!-- badges: end -->

# fnware

Popular Python decorators ported to R with the
[adorn](https://dyfanjones.github.io/adorn/) framework.

| Decorator   | What it does                                          | Python equivalent                                      |
|-------------|-------------------------------------------------------|--------------------------------------------------------|
| `retry()`   | Calls a function again when it fails                  | [tenacity](https://github.com/jd/tenacity)             |
| `async_retry()` | Like `retry()`, but waits without blocking and returns a promise | [tenacity](https://github.com/jd/tenacity) (async) |
| `timeout()` | Stops a single call that runs too long | [wrapt-timeout-decorator](https://github.com/bitranox/wrapt_timeout_decorator) |
| `async_timeout()` | Like `timeout()`, but for functions that return a promise | [`asyncio.timeout`](https://docs.python.org/3/library/asyncio-task.html#asyncio.timeout) |
| `lru_cache()` | Caches results, evicting the least recently used    | [`functools.lru_cache`](https://docs.python.org/3/library/functools.html#functools.lru_cache) |
| `cache` | Caches results, never evicting | [`functools.cache`](https://docs.python.org/3/library/functools.html#functools.cache) |
| `disk_cache()` | Caches results as files, so they outlive the session | [`joblib.Memory.cache`](https://joblib.readthedocs.io/en/stable/generated/joblib.Memory.html#joblib.Memory) |
| `async_lru_cache()`, `async_cache`, `async_disk_cache()` | Like the caches above, for functions that return a promise | |
| `validate_args()`, `validate_return()` | Checks arguments and return values with any validator function | [pydantic `validate_call`](https://docs.pydantic.dev/latest/concepts/validation_decorator/) |
| `circuit_breaker()` | Stops calling a function after repeated failures, then retries after a cooldown | [pybreaker](https://github.com/danielfm/pybreaker) |
| `async_circuit_breaker()` | Like `circuit_breaker()`, for functions that return a promise | [pybreaker](https://github.com/danielfm/pybreaker) (async) |
| `rate_limit()` | Limits how often a function can be called in a time window | [`ratelimit`](https://pypi.org/project/ratelimit/) |
| `async_rate_limit()` | Like `rate_limit()`, but queues calls instead of blocking | [`ratelimit`](https://pypi.org/project/ratelimit/) (async) |
| `fallback()` | Returns a default value, or a handler's result, when a function fails | [tenacity](https://github.com/jd/tenacity) `retry_error_callback` |
| `async_fallback()` | Like `fallback()`, for functions that return a promise | |
| `once()` | Runs a function the first time and reuses the result | |
| `log_call()` | Logs when a call starts, finishes or fails, with its arguments. Writes with `message()` or any logging package via a `logger_fn()` method | |
| `contextmanager` | Writes setup and teardown once, as `local_`, `with_` and decorator forms | [`contextlib.contextmanager`](https://docs.python.org/3/library/contextlib.html#contextlib.contextmanager) |

## Installation

``` r
# install.packages("pak")
pak::pak("DyfanJones/fnware")
```

## Usage

`retry()` and `lru_cache()` build a decorator, which you apply to a function
with `%@%` or by calling it on the function.

### Retry

``` r
library(fnware)

n <- 0
flaky <- function() {
  n <<- n + 1
  if (n < 3) stop("not yet")
  n
}

retry(stop = stop_after_attempt(5))(flaky)()
#> [1] 3
```

Choose when to give up, how long to wait, and what to retry:

``` r
fetch := retry(
  stop = stop_after_attempt(4),
  wait = wait_exp(multiplier = 0.1) + wait_rand(0, 0.1),
  retry = retry_if_error_message(match = "timeout"),
  before_sleep = before_sleep_log()
) %@% function(url) {
  # ...
}
```

When `stop` fires, a `retry_error` condition is signalled. Set `reraise = TRUE`
to re-throw the last error instead, or give `retry_error_callback` a function
to return a fallback value:

``` r
poll := retry(
  stop = stop_after_attempt(3),
  retry = retry_if_result(is.null),
  retry_error_callback = function(state) "gave up"
) %@% function() NULL

poll()
#> [1] "gave up"
```

| Strategy         | Functions                                                                                                  |
|------------------|------------------------------------------------------------------------------------------------------------|
| Stop (`stop`)    | `stop_never()`, `stop_after_attempt()`, `stop_after_delay()`, `stop_before_delay()`, `stop_any()`, `stop_all()` |
| Wait (`wait`)    | `wait_none()`, `wait_fixed()`, `wait_rand()`, `wait_exp()`, `wait_exp_jitter()`, `wait_chain()`, `wait_combine()` or `a + b` |
| Retry (`retry`)  | `retry_all()`, `retry_never()`, `retry_if_error()`, `retry_if_error_message()`, `retry_if_result()`        |
| Hooks            | `before_sleep_none()`, `before_sleep_log()`, `after_sleep_none()`, `after_sleep_log()`                      |

### LRU cache

``` r
slow_square := lru_cache() %@% function(x) {
  Sys.sleep(0.2)
  x^2
}

slow_square(4) # slow
slow_square(4) # cached
```

`cache` is the same without a size limit. It takes no parameters, so apply it
directly:

``` r
slow_cube := cache %@% function(x) {
  Sys.sleep(0.2)
  x^3
}
```

`disk_cache()` keeps results in files under `dir`, so they survive the session
and can be shared between sessions. `dir` has no default, because a temporary
directory would defeat the point:

``` r
slow_cube := disk_cache("~/.cache/my-analysis") %@% function(x) {
  Sys.sleep(0.2)
  x^3
}
```

Set `format = "qs2"` to use the [qs2](https://github.com/qsbase/qs2) package
instead of `saveRDS()`. On a 1,000,000-row data frame it was about 7x faster to
write and 3.5x faster to read back, and slightly smaller on disk (one machine, so
measure your own). qs2 is optional and must be installed.

Editing a function's body invalidates its entries, but changing something it
calls does not. Results are saved with `saveRDS()`, so environments and external
pointers do not round-trip.

### Context manager

R has no `yield`, so a context manager calls `teardown()` right after acquiring
each resource and returns the resource. Unlike `retry()` and `lru_cache()`,
`contextmanager` takes no parameters, so it is applied without calling it first.

``` r
local_tempdir := contextmanager %@% function(pattern = "tmp") {
  path <- tempfile(pattern)
  dir.create(path)
  teardown(unlink(path, recursive = TRUE))
  path
}
```

That one definition gives three forms. Called inside a function, cleanup runs
when that function exits, like `withr::local_*()`:

``` r
f <- function() {
  d <- local_tempdir()
  writeLines("hi", file.path(d, "x.txt"))
  d
}

d <- f()
dir.exists(d)
#> [1] FALSE
```

`with_context()` scopes it to a block, passing the value to a function:

``` r
with_context(local_tempdir(), function(d) list.files(d))
#> character(0)
```

`as_decorator()` runs a function inside the context:

``` r
g := as_decorator(local_tempdir) %@% function() "ran inside context"
g()
#> [1] "ran inside context"
```

Cleanups run last in, first out, and the ones registered before a failing setup
step still run. A context manager called from another's setup is cleaned up with
the outer one.

### Validation

`validate_args()` takes one validator per argument and `validate_return()` takes
one for the result. A validator is any function (or formula) that returns `TRUE`
to pass. Returning a string fails with that string as the message, which is how
checkmate's `check_*()` functions behave, so they work without fnware depending
on them:

``` r
scale_by := validate_args(x = is.numeric, n = ~ .x > 0) %@% function(x, n = 1) {
  x * n
}

scale_by(2, 3)
#> [1] 6

scale_by("a", -1)
#> Error: Invalid arguments.
#> ✖ `x`: failed validation.
#> ✖ `n`: failed validation.
```

All failures are reported together as a `fnware_validation_error`. Defaults are
validated too.

## Learn more

Vignettes: `vignette("retry")`, `vignette("caching")` and
`vignette("contextmanager")` and `vignette("validation")`. The help pages are
`?retry`, `?lru_cache` (which also covers `cache` and `disk_cache`),
`?contextmanager` and `?validate_args`. See the adorn
[documentation](https://dyfanjones.github.io/adorn/) for how decorators are
applied, stacked and removed.
