# Run a function only once

Decorator that runs the function on its first successful call and
returns that result on every call after it, ignoring later arguments. An
error stores nothing, so the next call tries again. Unlike
[cache](https://dyfanjones.github.io/fnware/reference/lru_cache.md), it
keeps one result whatever the arguments.

## Usage

``` r
once(f)
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

## Value

A decorator.

## Examples

``` r
setup := once %@% function() {
  cat("setting up\n")
  42
}
setup()
#> setting up
#> [1] 42
setup() # no output, same result
#> [1] 42
```
