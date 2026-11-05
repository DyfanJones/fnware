# Use a logging package with [`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)

[`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)
writes through a logger, see
[logger_base](https://dyfanjones.github.io/fnware/reference/loggers.md).
To log with another package, inherit from `logger_base` and register a
method for
[`logger_fn()`](https://dyfanjones.github.io/fnware/reference/loggers.md).
The package then owns the thresholds, layouts and appenders.

## Details

`level` is the label from the logger's property for the event's level,
so `"INFO"` for an info event. Override the defaults of the `trace`,
`debug`, `info`, `warn`, `error` and `fatal` properties if the package
names levels differently. A package that needs a logger object can have
it passed in through the `logger` property, available as `class@logger`.

The message may contain braces, so with the logger package wrap it in
[`skip_formatter()`](https://daroczig.github.io/logger/reference/skip_formatter.html)
to stop it being treated as a glue template.

## Examples

``` r
library(S7)

# The logger package
if (FALSE) { # \dontrun{
library(logger)
logger_logger := new_class(parent = logger_base)

method(logger_fn, logger_logger) <- function(class, level, msg, ...) {
  log_level(level, skip_formatter(msg))
}
f := log_call(logger = logger_logger()) %@% function(x) x
f(1)
} # }

# log4r, which needs a logger object
if (FALSE) { # \dontrun{
library(log4r)
logger_log4r := new_class(parent = logger_base)

method(logger_fn, logger_log4r) <- function(class, level, msg, ...) {
  log_at(class@logger, level, msg)
}
f := log_call(logger = logger_log4r(logger = logger("INFO"))) %@%
  function(x) x
f(1)
} # }
```
