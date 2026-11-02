# Validating arguments and results

``` r

library(garnish)
```

Checking inputs is the same few lines at the top of every function: test
the type, test the range, build an error message.
[`validate_args()`](https://dyfanjones.github.io/garnish/reference/validate_args.md)
moves those checks out of the body and into a decorator, and
[`validate_return()`](https://dyfanjones.github.io/garnish/reference/validate_args.md)
does the same for the value a function hands back.

``` r

scale_by := validate_args(x = is.numeric, n = ~ .x > 0) %@% function(x, n = 1) {
  x * n
}
scale_by(2, 3)
```

    ## [1] 6

``` r

scale_by("a", -1)
```

    ## Error:
    ## ! Invalid arguments.
    ## ✖ `x`: failed validation.
    ## ✖ `n`: failed validation.

Both problems are reported in one error, so the caller fixes everything
in one pass instead of one failure at a time.

## What counts as a validator

A validator is any function that takes the value. garnish does not know
about any particular checking package, so base predicates, your own
functions and packages like checkmate all go in the same way. A
validator passes only when it returns exactly `TRUE`. Anything else
fails:

| It returns               | Result                               |
|--------------------------|--------------------------------------|
| `TRUE`                   | passes                               |
| a string                 | fails, and the string is the message |
| `FALSE` or anything else | fails with a generic message         |
| (it signals an error)    | the error propagates unchanged       |

A formula is turned into a function with
[`rlang::as_function()`](https://rlang.r-lib.org/reference/as_function.html),
so `~ .x > 0` is shorthand for `\(.x) .x > 0`.

### Messages

Returning a string is the convention used by checkmate’s `check_*()`
functions, and it is easy to follow in your own code:

``` r

check_string <- function(x) {
  if (is.character(x) && length(x) == 1L) TRUE else "must be a single string"
}

greet := validate_args(name = check_string) %@% function(name) {
  paste("Hello", name)
}
greet("Ada")
```

    ## [1] "Hello Ada"

``` r

greet(1)
```

    ## Error:
    ## ! Invalid arguments.
    ## ✖ `name`: must be a single string

With checkmate installed, `validate_args(x = checkmate::check_numeric)`
works the same way, and so does a validator that throws, such as
`checkmate::assert_numeric`. A thrown error is not collected with the
others: it stops validation and reaches the caller as it is.

## Which arguments are checked

[`validate_args()`](https://dyfanjones.github.io/garnish/reference/validate_args.md)
checks the value each named argument has when the function runs, so
**defaults are validated too**. A default that breaks its own rule is
caught on the first call:

``` r

bad_default := validate_args(n = ~ .x > 0) %@% function(x, n = -1) x * n
bad_default(2)
```

    ## Error:
    ## ! Invalid arguments.
    ## ✖ `n`: failed validation.

Arguments you do not name are never touched, so an unvalidated argument
can still be missing or lazy. A validated argument is forced when the
call starts rather than when the body first uses it.

Names are checked against the function’s arguments when it is decorated,
so a typo fails straight away rather than silently validating nothing:

``` r

validate_args(z = is.numeric) %@% function(x) x
```

    ## Error in `validate_args()`:
    ## ! `validate_args()` names not in the function's arguments: `z`.

## Validating the result

[`validate_return()`](https://dyfanjones.github.io/garnish/reference/validate_args.md)
takes one validator for the returned value. It is a post-condition: it
catches a function that returns the wrong thing, which is a bug in the
function rather than in the caller.

``` r

parse_port := validate_return(~ is.integer(.x) && .x > 0) %@% function(s) {
  as.integer(s)
}
parse_port("8080")
```

    ## [1] 8080

``` r

parse_port("-1")
```

    ## Error:
    ## ! Invalid return value.
    ## ✖ failed validation.

Visibility is preserved, so an
[`invisible()`](https://rdrr.io/r/base/invisible.html) result stays
invisible.

## Handling failures

Failures have class `garnish_validation_error`, so callers can handle
them apart from other errors:

``` r

tryCatch(
  scale_by("a"),
  garnish_validation_error = function(e) "bad input"
)
```

    ## [1] "bad input"

## Combining with other decorators

Decorators stack, and order matters. Validation usually goes outermost
so bad input is rejected before any work is done:

``` r

lookup := validate_args(id = is.numeric) %@%
  cache %@%
  function(id) {
    cat("  looking up", id, "\n")
    id * 2
  }
lookup(1)
```

    ##   looking up 1

    ## [1] 2

``` r

lookup(1)
```

    ## [1] 2

Putting it outside
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
matters for the same reason: a validation error is the caller’s mistake,
and retrying it only repeats the mistake.
