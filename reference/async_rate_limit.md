# Limit how often an asynchronous function can be called

Asynchronous version of
[`rate_limit()`](https://dyfanjones.github.io/fnware/reference/rate_limit.md).
It allows at most `calls` calls to start in any window of `period`
seconds, but a call over the limit is scheduled with
[`later::later()`](https://later.r-lib.org/reference/later.html) instead
of sleeping, so the session carries on. The decorated function returns a
[promise](https://rstudio.github.io/promises/reference/promise.html)
that follows the wrapped function's result, a plain value or a promise.

## Usage

``` r
async_rate_limit(f, calls, period = 1)
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

A decorator. The decorated function returns a promise.

## Details

Each call reserves its slot when it is made, so calls start in order and
queued calls count toward the limit. As with
[`rate_limit()`](https://dyfanjones.github.io/fnware/reference/rate_limit.md),
an error still uses its slot. It limits when calls start, not how many
run, so slow calls can overlap. Stack it inside
[`async_retry()`](https://dyfanjones.github.io/fnware/reference/async_retry.md)
to throttle every attempt.

Needs the promises and later packages, and an event loop.

## Examples

``` r
if (FALSE) { # \dontrun{
f := async_rate_limit(calls = 2, period = 0.2) %@% function(i) i
start <- Sys.time()
for (i in 1:4) {
  local({
    i <- i
    promises::then(f(i), function(value) {
      cat("call", value, "at", round(as.numeric(Sys.time() - start), 1), "s\n")
    })
  })
}
while (!later::loop_empty()) later::run_now(0.05)
} # }
```
