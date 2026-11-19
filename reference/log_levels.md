# The level of each event [`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md) logs

[`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)
logs three events, so it takes one level for each. The hooks
[`before_sleep_log()`](https://dyfanjones.github.io/fnware/reference/before_sleep.md)
and
[`after_sleep_log()`](https://dyfanjones.github.io/fnware/reference/after_sleep.md)
log a single event, so they take a plain `level` string instead.

## Usage

``` r
log_levels(start = "info", finish = "info", error = "error")
```

## Arguments

- start, finish, error:

  The level of the event: one of `"trace"`, `"debug"`, `"info"`,
  `"warn"`, `"error"` or `"fatal"`.

## Value

An object to pass to the `level` argument of
[`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md).

## Examples

``` r
log_levels(finish = "trace", error = "warn")
#> <fnware::log_levels>
#>  @ start : chr "info"
#>  @ finish: chr "trace"
#>  @ error : chr "warn"
```
