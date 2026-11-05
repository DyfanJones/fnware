# Validate the value an asynchronous function resolves to

Asynchronous version of
[`validate_return()`](https://dyfanjones.github.io/fnware/reference/validate_args.md),
for functions that return a
[promise](https://rstudio.github.io/promises/reference/promise.html).
The validator checks the resolved value, not the promise. If it fails,
the promise returned by the decorated function rejects with a
`fnware_validation_error`. Rejections from the wrapped function carry on
unchanged. Needs the promises package.

## Usage

``` r
async_validate_return(validator)
```

## Arguments

- validator:

  For
  [`validate_return()`](https://dyfanjones.github.io/fnware/reference/validate_args.md),
  a validator for the returned value.

## Value

A decorator. The decorated function returns a promise.

## Details

Arguments are available at call time, so
[`validate_args()`](https://dyfanjones.github.io/fnware/reference/validate_args.md)
works for asynchronous functions as it is.

## Examples

``` r
if (FALSE) { # \dontrun{
f := async_validate_return(is.character) %@%
  function() promises::promise_resolve(1)
promises::catch(f(), function(err) cat(conditionMessage(err), "\n"))
while (!later::loop_empty()) later::run_now(0.05)
} # }
```
