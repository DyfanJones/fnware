# Run a hook before [`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md) sleeps

- `before_sleep_none()` does nothing.

- `before_sleep_log()` passes a message describing the attempt to
  `logger`.

## Usage

``` r
before_sleep_none()

before_sleep_log(logger = message)
```

## Arguments

- logger:

  Function taking a single message string. Defaults to
  [`message()`](https://rdrr.io/r/base/message.html).

## Value

A hook to pass to
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md).

## Examples

``` r
before_sleep_log(function(msg) cat(msg, "\n"))
#> <garnish::before_sleep_log>
#>  @ logger: function (msg)  
```
