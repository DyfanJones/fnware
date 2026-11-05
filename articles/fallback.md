# Fallbacks and running once

``` r

library(fnware)
```

## Returning a default

[`fallback()`](https://dyfanjones.github.io/fnware/reference/fallback.md)
catches a failure and returns a default instead of signalling it.

``` r

safe_sqrt := fallback(value = NA_real_) %@% function(x) {
  if (x < 0) stop("negative") else sqrt(x)
}
safe_sqrt(4)
```

    ## [1] 2

``` r

safe_sqrt(-1)
```

    ## [1] NA

To compute the result from the failure, pass a `handler`. It receives
the condition:

``` r

describe := fallback(handler = function(cnd) conditionMessage(cnd)) %@%
  function() stop("boom")
describe()
```

    ## [1] "boom"

Only errors are caught by default. Set `class` to catch other
conditions, such as `class = "warning"`. A caught condition ends the
call, as with [`tryCatch()`](https://rdrr.io/r/base/conditions.html).

## Stacking with retry and the circuit breaker

Put
[`fallback()`](https://dyfanjones.github.io/fnware/reference/fallback.md)
outermost. The default is then used only once
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) has
given up, or once
[`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md)
has opened:

``` r

calls <- 0
fetch := fallback(value = "cached") %@%
  circuit_breaker(failures = 3) %@%
  retry(stop = stop_after_attempt(2)) %@%
  function(url) {
    calls <<- calls + 1
    stop("down")
  }

fetch("x")
```

    ## [1] "cached"

``` r

calls
```

    ## [1] 2

## Promises

[`async_fallback()`](https://dyfanjones.github.io/fnware/reference/async_fallback.md)
does the same for functions that return a promise. The promise resolves
to the default if the function rejects with a matching condition, and
other rejections carry on unchanged. It needs the promises package.

``` r

f := async_fallback(value = "default") %@% function() stop("boom")
promises::then(f(), print)
```

## Running once

[`once()`](https://dyfanjones.github.io/fnware/reference/once.md) runs a
function on its first successful call and returns that result every time
after, ignoring later arguments. It suits setup that should happen a
single time.

``` r

setup := once %@% function() {
  cat("setting up\n")
  42
}
setup()
```

    ## setting up

    ## [1] 42

``` r

setup()
```

    ## [1] 42

An error stores nothing, so the next call tries again. Unlike
[`cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md),
which keeps a result per set of arguments,
[`once()`](https://dyfanjones.github.io/fnware/reference/once.md) keeps
one result whatever the arguments.
