# Retry conditions

Decide whether
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
tries again after an attempt.

## Usage

``` r
retry_all()

retry_never()

retry_if_error(classes = "error")

retry_if_error_message(message = NULL, match = NULL)

retry_if_result(predicate)
```

## Arguments

- classes:

  Condition classes to retry on.

- message:

  Error message to match exactly.

- match:

  Regular expression to match against the error message.

- predicate:

  Function taking the returned value and returning `TRUE` to retry.

## Value

A retry condition to pass to
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md).

## Details

- `retry_all()` retries on any error.

- `retry_never()` never retries, so the first error is re-thrown.

- `retry_if_error()` retries on errors inheriting from any of `classes`.

- `retry_if_error_message()` retries when the error message equals
  `message`, or matches the regular expression `match`. Supply exactly
  one.

- `retry_if_result()` retries when the call succeeds but
  `predicate(value)` is `TRUE`.

## Examples

``` r
retry_if_error("http_error")
#> <garnish::retry_if_error>
#>  @ classes: chr "http_error"
retry_if_error_message(match = "timed? ?out")
#> <garnish::retry_if_error_message>
#>  @ message: NULL
#>  @ match  : chr "timed? ?out"
retry_if_result(is.null)
#> <garnish::retry_if_result>
#>  @ predicate: function (x)  
```
