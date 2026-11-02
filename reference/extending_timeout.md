# Write your own timeout method

[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
hands the work of enforcing a limit to a *method*.
[`timeout_r()`](https://dyfanjones.github.io/garnish/reference/timeout.md),
which uses [`setTimeLimit()`](https://rdrr.io/r/base/setTimeLimit.html),
is the built-in. To add another, for example one that runs the call in a
separate process and kills it, make an S7 class that inherits from
`timeout_base` and register a method for `timeout_fn()` with
[`S7::method<-()`](https://rconsortium.github.io/S7/reference/method-set.html).

## Usage

``` r
timeout_base()

timeout_fn(class, call, seconds, ...)
```

## Arguments

- class:

  A timeout method object. Methods are dispatched on this argument.

- call:

  A function of no arguments that runs the decorated function.

- seconds:

  Seconds left before the effective deadline.

- ...:

  Passed to methods.

## Value

`timeout_fn()` returns the value of
[`call()`](https://rdrr.io/r/base/call.html).

## Details

`timeout_fn(class, call, seconds)` gets `call`, a function of no
arguments that runs the decorated function, and `seconds`, the time left
before the effective deadline. It must return the value of
[`call()`](https://rdrr.io/r/base/call.html) unchanged, or signal a
`garnish_timeout_error` when `seconds` run out.
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
adds the function name and limit to the message, and signals a
`garnish_timeout_method_error` if
[`call()`](https://rdrr.io/r/base/call.html) ran but the method returned
something else or swallowed its error. Other errors should propagate.

A method that runs [`call()`](https://rdrr.io/r/base/call.html) in
another process cannot be checked for this, and
[`timeout_remaining()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
does not see the parent's deadline there. Set the environment variable
`GARNISH_TIMEOUT_DEADLINE` in the child to
`as.numeric(Sys.time()) + seconds` to pass it on. The retry vignette
shows a callr method that does. Packages that register methods need
[`S7::methods_register()`](https://rconsortium.github.io/S7/reference/S7_on_load.html)
in `.onLoad()`.

## Examples

``` r
library(S7)

# Report the time allowed, then run the call without enforcing anything
timeout_log <- new_class("timeout_log", parent = timeout_base)

method(timeout_fn, timeout_log) <- function(class, call, seconds, ...) {
  message("allowing ", format(seconds), " seconds")
  call()
}

f := timeout(3, method = timeout_log()) %@% function() "ok"
f()
#> allowing 3 seconds
#> [1] "ok"
```
