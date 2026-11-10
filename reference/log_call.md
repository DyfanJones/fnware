# Log the calls to a function

Decorator that logs when a call starts, and when it finishes or fails.
Each event is written by `logger`, see
[logger_base](https://dyfanjones.github.io/fnware/reference/loggers.md).
A failure is logged then signalled again unchanged.

## Usage

``` r
log_call(f, logger = logger_base(), level = log_levels(), elapsed = TRUE)
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

- logger:

  A [logger](https://dyfanjones.github.io/fnware/reference/loggers.md),
  such as
  [`logger_message()`](https://dyfanjones.github.io/fnware/reference/loggers.md).
  See
  [extending_log](https://dyfanjones.github.io/fnware/reference/extending_log.md)
  to use a logging package.

- level:

  A
  [`log_levels()`](https://dyfanjones.github.io/fnware/reference/log_levels.md)
  giving the level of the start, finish and error events.

- elapsed:

  Include the time taken in the finish message?

## Value

A decorator.

## Details

The message holds the function's name, its arguments matched to the
formals and, once finished, the time taken. Arguments are evaluated
before the start is logged.

When a call fails, the calls from `f` down to the failure are logged as
a separate `trace` event after the error. Whether it is shown is up to
the logger: the built-in loggers hide it until `threshold = "trace"`,
see
[logger_base](https://dyfanjones.github.io/fnware/reference/loggers.md).

For a function that returns a promise, use
[`async_log_call()`](https://dyfanjones.github.io/fnware/reference/async_log_call.md).
Here the finish would be logged when the promise is returned, not when
it settles.

## Examples

``` r
fn := log_call(logger = logger_message()) %@% function(a, b, c) a + b + c
fn(1, 2, 3)
#> INFO [2026-11-10T20:39:40.759Z]: Start fn(a=1,b=2,c=3)
#> INFO [2026-11-10T20:39:40.760Z]: Finished fn(a=1,b=2,c=3) Elapsed=00:00:00.001
#> [1] 6

# Log failures as warnings
g := log_call(
  logger = logger_message(),
  level = log_levels(error = "warn")
) %@% function(x) stop("boom")
try(g(1), silent = TRUE)
#> INFO [2026-11-10T20:39:40.762Z]: Start g(x=1)
#> WARN [2026-11-10T20:39:40.763Z]: g(x=1) 
#> Error in `g(x = x)`:
#> boom
```
