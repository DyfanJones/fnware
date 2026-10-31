# Limit how often a function can be called

Decorator that allows at most `calls` calls in any window of `period`
seconds. A call that would exceed the limit sleeps until the oldest call
in the window has aged out. Calls are counted when they start, so a call
that errors still uses up its slot, as it does for an API.

## Usage

``` r
rate_limit(f, calls, period = 1)
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

- calls:

  Maximum number of calls in one window. A whole number of at least 1.

- period:

  Length of the window in seconds. Defaults to 1.

## Value

A decorator.

## Details

Call `rate_limit(calls, period)` to build a decorator, then apply it
with `%@%` or by calling it on a function. Each decorated function keeps
its own record of calls, so two functions decorated separately have
separate limits.

Stack it inside
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md) so
that every attempt is throttled, including retries. Stacking it outside
would only throttle whole calls, and retries could still exceed the
limit.

## Examples

``` r
f <- rate_limit(calls = 3, period = 1) %@% function(x) x
vapply(1:3, f, numeric(1)) # immediate
#> [1] 1 2 3
system.time(f(4)) # waits for the window to clear
#>    user  system elapsed 
#>   0.001   0.000   0.897 

# Throttle every attempt, retries included
fetch <- retry(stop = stop_after_attempt(3)) %@%
  rate_limit(calls = 5, period = 1) %@%
  function(url) url
```
