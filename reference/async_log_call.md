# Log the calls to an asynchronous function

Asynchronous version of
[`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md),
for functions that return a
[promise](https://rstudio.github.io/promises/reference/promise.html). It
logs the start when the function is called, and the finish or the
failure when the promise settles, with the time taken up to that point.
A rejection is logged then passed on unchanged. Needs the promises
package.

## Usage

``` r
async_log_call(f, logger = logger_base(), level = log_levels(), elapsed = TRUE)
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

  Include the time taken in the finish and error messages?

## Value

A decorator. The decorated function returns a promise.

## Details

There is no `trace` argument, as the calls that led to a rejection are
no longer on the stack by the time it settles.

## Examples

``` r
if (FALSE) { # \dontrun{
fn := async_log_call(logger = logger_message()) %@%
  function(x) promises::promise_resolve(x)
promises::then(fn(1), print)
while (!later::loop_empty()) later::run_now(0.05)
} # }
```
