# Loggers

[`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)
hands each message to a logger. A logger is an S7 object that inherits
from `logger_base`, and `logger_fn()` decides how it is written.

## Usage

``` r
logger_base(
  trace = "TRACE",
  debug = "DEBUG",
  info = "INFO",
  warn = "WARN",
  error = "ERROR",
  fatal = "FATAL",
  logger = NULL
)

logger_fn(class, level, msg, ...)

logger_message(
  trace = "TRACE",
  debug = "DEBUG",
  info = "INFO",
  warn = "WARN",
  error = "ERROR",
  fatal = "FATAL",
  logger = NULL
)
```

## Arguments

- trace, debug, info, warn, error, fatal:

  Labels passed to `logger_fn()` for each level. They default to
  `"TRACE"`, `"DEBUG"` and so on. Change them when the logging package
  names its levels differently, or uses objects.

- logger:

  An object a logging package needs to be passed, such as a log4r
  logger. Available to methods as `class@logger`.

- class:

  A logger. Methods are dispatched on this argument.

- level:

  The level label of the event, taken from the property of `class` named
  by the event's level, e.g. `class@info`.

- msg:

  The message, a string.

- ...:

  Passed to methods.

## Value

`logger_fn()` returns nothing useful. The others return a logger.

## Details

- `logger_base` is the base class. The default method prints
  `LEVEL [timestamp]: message` to the console.

- `logger_message` writes `[LEVEL] message` with
  [`message()`](https://rdrr.io/r/base/message.html), so it can be
  silenced with
  [`suppressMessages()`](https://rdrr.io/r/base/message.html).

- `logger_fn(class, level, msg, ...)` is the generic. Add a method to
  support any logging package, see
  [extending_log](https://dyfanjones.github.io/fnware/reference/extending_log.md).

## Examples

``` r
logger_message()
#> <fnware::logger_message>
#>  @ trace : chr "TRACE"
#>  @ debug : chr "DEBUG"
#>  @ info  : chr "INFO"
#>  @ warn  : chr "WARN"
#>  @ error : chr "ERROR"
#>  @ fatal : chr "FATAL"
#>  @ logger: NULL
f := log_call(logger = logger_message()) %@% function(x) x
f(1)
#> [INFO] Started f(x=1)
#> [DEBUG] Finished f(x=1) Elapsed=00:00:00.000
#> [1] 1
```
