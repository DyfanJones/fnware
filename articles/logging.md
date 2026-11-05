# Logging calls

``` r

library(fnware)
library(S7)
```

[`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)
logs when a call starts, and when it finishes or fails. Each message
holds the function’s name, its arguments and, once the call is over, the
time it took.

``` r

add := log_call() %@% function(a, b) a + b
add(1, b = 2)
```

    ## INFO [2026-11-05T19:25:46.609Z]: Started add(a=1,b=2)
    ## INFO [2026-11-05T19:25:46.610Z]: Finished add(a=1,b=2) Elapsed=00:00:00.001

    ## [1] 3

Arguments are named by the formals they matched, so `add(b = 2, a = 1)`
logs the same as above. Long values are cut. A failure is logged and
then signalled again unchanged:

``` r

boom := log_call() %@% function(x) stop("boom")
boom(1)
```

    ## INFO [2026-11-05T19:25:46.698Z]: Started boom(x=1)
    ## ERROR [2026-11-05T19:25:46.698Z]: Failed boom(x=1) Elapsed=00:00:00.000 
    ## Error in `boom(x = x)`:
    ## boom

    ## Error:
    ## ! boom

## Levels

Each event has a level. By default the start is `info`, the finish is
`debug` and a failure is `error`. Change them with
[`log_levels()`](https://dyfanjones.github.io/fnware/reference/log_levels.md):

``` r

quiet := log_call(
  logger = logger_message(),
  level = log_levels(start = "debug", finish = "debug", error = "warn")
) %@% function(x) stop("boom")
try(quiet(1), silent = TRUE)
```

    ## [DEBUG] Started quiet(x=1)

    ## [WARN] Failed quiet(x=1) Elapsed=00:00:00.001 
    ## Error in `quiet(x = x)`:
    ## boom

Set `elapsed = FALSE` to leave the time out of the messages.

## Loggers

A logger decides where a message goes.
[`logger_base()`](https://dyfanjones.github.io/fnware/reference/loggers.md),
the default, prints `LEVEL [timestamp]: message`.
[`logger_message()`](https://dyfanjones.github.io/fnware/reference/loggers.md)
writes with [`message()`](https://rdrr.io/r/base/message.html) instead,
so [`suppressMessages()`](https://rdrr.io/r/base/message.html) silences
it.

``` r

hello := log_call(logger = logger_message()) %@% function() "hi"
hello()
```

    ## [INFO] Started hello()

    ## [INFO] Finished hello() Elapsed=00:00:00.001

    ## [1] "hi"

## Using a logging package

To log with another package, inherit from `logger_base` and add a method
for
[`logger_fn()`](https://dyfanjones.github.io/fnware/reference/loggers.md).
The package then owns thresholds, layouts and appenders. The method
receives the level label (`"INFO"`, `"DEBUG"` and so on) and the
message.

For the logger package:

``` r

library(logger)
logger_logger := new_class(parent = logger_base)

method(logger_fn, logger_logger) <- function(class, level, msg, ...) {
  log_level(level, skip_formatter(msg))
}

f := log_call(logger = logger_logger()) %@% function(x) x
f(1)
```

[`skip_formatter()`](https://daroczig.github.io/logger/reference/skip_formatter.html)
stops the logger package treating braces in the message as a glue
template.

Some packages need a logger object passed in. Give it to the logger
through the `logger` property and read it back as `class@logger`. For
log4r:

``` r

library(log4r)
logger_log4r := new_class(parent = logger_base)

method(logger_fn, logger_log4r) <- function(class, level, msg, ...) {
  log_at(class@logger, level, msg)
}

f := log_call(logger = logger_log4r(logger = logger("INFO"))) %@%
  function(x) x
f(1)
```

If a package names its levels differently, override the defaults of the
`trace`, `debug`, `info`, `warn`, `error` and `fatal` properties. A
label can be any object, for example a number.

``` r

logger_num := new_class(
  parent = logger_base,
  properties = list(
    info = new_property(class_any, default = 20L),
    debug = new_property(class_any, default = 10L)
  )
)

method(logger_fn, logger_num) <- function(class, level, msg, ...) {
  cat(level, msg, "\n")
}

f := log_call(logger = logger_num()) %@% function() 1
f()
```

    ## 20 Started f() 
    ## 20 Finished f() Elapsed=00:00:00.000

    ## [1] 1

## Promises

[`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)
logs the finish as soon as the function returns, which for a function
that returns a promise is before the work is done. Use
[`async_log_call()`](https://dyfanjones.github.io/fnware/reference/async_log_call.md)
instead. It logs the start when the function is called, and the finish
or the failure when the promise settles. A rejection is logged then
passed on unchanged. There is no `trace` argument, because the calls
that led to a rejection are gone by the time it settles.

``` r

f := async_log_call(logger = logger_message()) %@%
  function(x) promises::promise_resolve(x)
promises::then(f(1), print)
```
