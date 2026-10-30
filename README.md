<!-- badges: start -->
<!-- badges: end -->

# garnish

Popular Python decorators ported to R with the
[adorn](https://dyfanjones.github.io/adorn/) framework.

| Decorator   | What it does                                          | Python equivalent                                      |
|-------------|-------------------------------------------------------|--------------------------------------------------------|
| `retry()`   | Calls a function again when it fails                  | [tenacity](https://github.com/jd/tenacity)             |
| `lru_cache()` | Caches results, evicting the least recently used    | [`functools.lru_cache`](https://docs.python.org/3/library/functools.html#functools.lru_cache) |

## Installation

``` r
# install.packages("pak")
pak::pak("DyfanJones/garnish")
```

## Usage

`retry()` and `lru_cache()` build a decorator, which you apply to a function
with `%@%` or by calling it on the function.

### Retry

``` r
library(garnish)

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

## Learn more

See `?retry` and `?lru_cache`, or the adorn
[documentation](https://dyfanjones.github.io/adorn/) for how decorators are
applied, stacked and removed.
