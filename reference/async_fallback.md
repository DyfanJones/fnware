# Return a default when an asynchronous function fails

Asynchronous version of
[`fallback()`](https://dyfanjones.github.io/fnware/reference/fallback.md).
The decorated function returns a
[promise](https://rstudio.github.io/promises/reference/promise.html)
that resolves to `value` (or the result of `handler`) if the wrapped
function rejects or throws with a condition in `class`. Other rejections
carry on unchanged. Needs the promises package.

## Usage

``` r
async_fallback(f, value = NULL, handler = NULL, class = "error",
  logger = NULL, level = "warn")
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

- value:

  Value to return on failure. Ignored if `handler` is given.

- handler:

  Optional function taking the condition and returning the result.

- class:

  Condition classes to catch. Defaults to `"error"`.

- logger:

  A [logger](https://dyfanjones.github.io/fnware/reference/loggers.md),
  such as
  [`logger_message()`](https://dyfanjones.github.io/fnware/reference/loggers.md),
  that logs each time the fallback is used, see
  [extending_log](https://dyfanjones.github.io/fnware/reference/extending_log.md)
  to use a logging package. `NULL`, the default, logs nothing.

- level:

  The level of that event: one of `"trace"`, `"debug"`, `"info"`,
  `"warn"`, `"error"` or `"fatal"`. Defaults to `"warn"`.

## Value

A decorator. The decorated function returns a promise.

## Examples

``` r
if (FALSE) { # \dontrun{
f := async_fallback(value = "default") %@% function() stop("boom")
promises::then(f(), print)
while (!later::loop_empty()) later::run_now(0.05)
} # }
```
