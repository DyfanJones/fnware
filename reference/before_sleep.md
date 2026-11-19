# Run a hook before [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) sleeps

- `before_sleep_none()` does nothing.

- `before_sleep_log()` logs a message describing the attempt with
  `logger`.

## Usage

``` r
before_sleep_none()

before_sleep_log(logger = logger_base(), level = "warn")
```

## Arguments

- logger:

  A [logger](https://dyfanjones.github.io/fnware/reference/loggers.md),
  such as
  [`logger_message()`](https://dyfanjones.github.io/fnware/reference/loggers.md).
  Defaults to
  [`logger_base()`](https://dyfanjones.github.io/fnware/reference/loggers.md).
  See
  [extending_log](https://dyfanjones.github.io/fnware/reference/extending_log.md)
  to use a logging package.

- level:

  The level the message is logged at: one of `"trace"`, `"debug"`,
  `"info"`, `"warn"`, `"error"` or `"fatal"`. A hook logs a single
  event, so this is one string, unlike the
  [`log_levels()`](https://dyfanjones.github.io/fnware/reference/log_levels.md)
  of
  [`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md).

## Value

A hook to pass to
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md).

## Examples

``` r
before_sleep_log(logger_message(), level = "info")
#> <fnware::before_sleep_log>
#>  @ logger: <fnware::logger_message>
#>  .. @ trace    : chr "TRACE"
#>  .. @ debug    : chr "DEBUG"
#>  .. @ info     : chr "INFO"
#>  .. @ warn     : chr "WARN"
#>  .. @ error    : chr "ERROR"
#>  .. @ fatal    : chr "FATAL"
#>  .. @ threshold: chr "info"
#>  .. @ logger   : NULL
#>  @ level : chr "info"
```
