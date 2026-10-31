# Run a hook after [`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md) sleeps

- `after_sleep_none()` does nothing.

- `after_sleep_log()` passes a message describing the attempt to
  `logger`.

## Usage

``` r
after_sleep_none()

after_sleep_log(logger = message)
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
after_sleep_log(function(msg) cat(msg, "\n"))
#> <garnish::after_sleep_log>
#>  @ logger: function (msg)  
```
