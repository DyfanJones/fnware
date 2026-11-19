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

    ## [1] 3

Arguments are named by the formals they matched, so `add(b = 2, a = 1)`
logs the same as above. Long values are cut. A failure is logged and
then signalled again unchanged:

``` r

boom := log_call() %@% function(x) stop("boom")
boom(1)
```

    ## Error:
    ## ! boom

## Levels

Each event has a level. By default the start and the finish are `info`
and a failure is `error`. Change them with
[`log_levels()`](https://dyfanjones.github.io/fnware/reference/log_levels.md):

``` r

quiet := log_call(
  logger = logger_message(),
  level = log_levels(start = "debug", finish = "debug", error = "warn")
) %@% function(x) stop("boom")
try(quiet(1), silent = TRUE)
```

    ## WARN [2026-11-19T12:41:44.795Z]: quiet(x=1) 
    ## Error in `quiet(x = x)`:
    ## boom

The start and finish are `debug` here, below the loggers’ default
`threshold` of `"info"`, so only the failure is written.

Set `elapsed = FALSE` to leave the time out of the finish message.

## Traces

When a call fails, the calls from the decorated function down to the
failure are logged as a separate `trace` event straight after the error.
The built-in loggers only write events at or above their `threshold`,
which is `"info"` by default, so the trace stays hidden until you lower
it:

``` r

inner <- function(x) stop("boom")
outer := log_call(logger = logger_message(threshold = "trace")) %@%
  function(x) inner(x)
try(outer(1), silent = TRUE)
```

    ## INFO [2026-11-19T12:41:44.850Z]: Start outer(x=1)

    ## ERROR [2026-11-19T12:41:44.851Z]: outer(x=1) 
    ## Error in `inner(x)`:
    ## boom

    ## TRACE [2026-11-19T12:41:44.851Z]: outer(x=1) 
    ##   1. outer(x = x)
    ##   2. inner(x)
    ##   3. stop("boom")

## Loggers

A logger decides where a message goes.
[`logger_base()`](https://dyfanjones.github.io/fnware/reference/loggers.md),
the default, prints `LEVEL [timestamp]: message`.
[`logger_message()`](https://dyfanjones.github.io/fnware/reference/loggers.md)
writes the same line with
[`message()`](https://rdrr.io/r/base/message.html) instead, so
[`suppressMessages()`](https://rdrr.io/r/base/message.html) silences it.
Both take a `threshold`, one of `"trace"`, `"debug"`, `"info"`,
`"warn"`, `"error"` or `"fatal"`, and leave out anything below it.

``` r

hello := log_call(logger = logger_message()) %@% function() "hi"
hello()
```

    ## INFO [2026-11-19T12:41:44.905Z]: Start hello()

    ## INFO [2026-11-19T12:41:44.906Z]: Finished hello() Elapsed=00:00:00.000

    ## [1] "hi"

## The default logger

[`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md),
[`async_log_call()`](https://dyfanjones.github.io/fnware/reference/async_log_call.md)
and the retry hooks
[`before_sleep_log()`](https://dyfanjones.github.io/fnware/reference/before_sleep.md)
and
[`after_sleep_log()`](https://dyfanjones.github.io/fnware/reference/after_sleep.md)
all take a `logger`. When you give none they use
[`logger_base()`](https://dyfanjones.github.io/fnware/reference/loggers.md).

The hooks log one event each, so they take a single `level` such as
`"warn"` in place of a
[`log_levels()`](https://dyfanjones.github.io/fnware/reference/log_levels.md).
[`before_sleep_log()`](https://dyfanjones.github.io/fnware/reference/before_sleep.md)
defaults to `"warn"` and
[`after_sleep_log()`](https://dyfanjones.github.io/fnware/reference/after_sleep.md)
to `"info"`.

## Circuit breakers and fallbacks

[`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md)
and
[`fallback()`](https://dyfanjones.github.io/fnware/reference/fallback.md),
and their async versions, are silent unless you give them a `logger`. A
circuit breaker logs when the circuit opens (`"warn"`) and when it
closes again (`"info"`), not each rejected call.
[`fallback()`](https://dyfanjones.github.io/fnware/reference/fallback.md)
logs each time it returns the default (`"warn"`). Change the levels with
`level`:

``` r

flaky := circuit_breaker(
  failures = 1,
  logger = logger_message(),
  level = c(open = "error")
) %@% function() stop("service down")
try(flaky(), silent = TRUE)
```

    ## ERROR [2026-11-19T12:41:44.965Z]: Circuit opened for flaky, rejecting calls for 30 seconds
    ## Error in `flaky()`:
    ## service down

``` r

safe := fallback(value = 0, logger = logger_message()) %@%
  function() stop("boom")
safe()
```

    ## WARN [2026-11-19T12:41:44.968Z]: Fallback used for safe
    ## Error in `safe()`:
    ## boom

    ## [1] 0

## Using a logging package

To log with another package, inherit from `logger_base` and add a method
for
[`logger_fn()`](https://dyfanjones.github.io/fnware/reference/loggers.md).
The package then owns thresholds, layouts and appenders. The method
receives the level label (`"INFO"`, `"DEBUG"` and so on) and the
message, and decides for itself whether to show it, so `threshold` is
not used.

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

    ## 20 Start f() 
    ## 20 Finished f() Elapsed=00:00:00.000

    ## [1] 1

## Promises

[`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)
logs the finish as soon as the function returns, which for a function
that returns a promise is before the work is done. Use
[`async_log_call()`](https://dyfanjones.github.io/fnware/reference/async_log_call.md)
instead. It logs the start when the function is called, and the finish
or the failure when the promise settles. A rejection is logged then
passed on unchanged. It logs no `trace` event, because the calls that
led to a rejection are gone by the time it settles.

``` r

f := async_log_call(logger = logger_message()) %@%
  function(x) promises::promise_resolve(x)
promises::then(f(1), print)
```
