# Run a hook after [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) sleeps

- `after_sleep_none()` does nothing.

- `after_sleep_log()` logs a message describing the attempt with
  `logger`.

## Usage

``` r
after_sleep_none()

after_sleep_log(logger = logger_base(), level = "info")
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
after_sleep_log(logger_message(), level = "info")
#> <fnware::after_sleep_log>
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
