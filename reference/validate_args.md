# Validate arguments and return values

Decorators that check a function's inputs or output against validators
you supply. A validator is any function (or
[`rlang::as_function()`](https://rlang.r-lib.org/reference/as_function.html)
formula) that takes the value, so base predicates, lambdas and the
`check_*()` functions of packages like checkmate all work, with no
dependency on any of them.

## Usage

``` r
validate_args(...)

validate_return(validator)
```

## Arguments

- ...:

  For `validate_args()`, named validators, one per argument.

- validator:

  For `validate_return()`, a validator for the returned value.

## Value

A decorator.

## Details

A validator passes if it returns exactly `TRUE`. It fails if it returns
anything else:

- a string, which becomes the failure message (the `check_*()`
  convention),

- `FALSE` or any other value, which gives a generic message.

If a validator signals an error, that error propagates unchanged, so
`assert_*()` style functions work too.

`validate_args()` checks the effective value of each named argument, so
defaults are validated too. Checking forces the argument, so a validated
argument is evaluated at call time rather than lazily. All failures are
reported in one error of class `garnish_validation_error`. Validator
names are checked against the function's formals when it is decorated,
so a typo fails early.

## Examples

``` r
f <- validate_args(x = is.numeric, n = ~ .x > 0) %@% function(x, n = 1) x * n
f(2, 3)
#> [1] 6
try(f("a", -1))
#> Error : Invalid arguments.
#> ✖ `x`: failed validation.
#> ✖ `n`: failed validation.

# check_*() style validators return a message on failure
check_string <- function(x) if (is.character(x) && length(x) == 1) TRUE else "must be a string"
g <- validate_args(name = check_string) %@% function(name) name
try(g(1))
#> Error : Invalid arguments.
#> ✖ `name`: must be a string

h <- validate_return(is.character) %@% function() 1
try(h())
#> Error : Invalid return value.
#> ✖ failed validation.
```
