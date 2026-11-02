# Bound how long an asynchronous call can take

Asynchronous version of
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md),
for functions that return a
[promise](https://rstudio.github.io/promises/reference/promise.html). If
the promise has not settled after `seconds`, the promise returned by the
decorated function rejects with a `garnish_timeout_error`, so
[`async_retry()`](https://dyfanjones.github.io/garnish/reference/async_retry.md)
retries it.

## Usage

``` r
async_timeout(f, seconds, method = async_timeout_later())

async_timeout_base()

async_timeout_fn(class, call, seconds, ...)

async_timeout_later()
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

- seconds:

  Time limit for one call, in seconds. A number greater than 0.

- method:

  How to enforce the limit, e.g. `async_timeout_later()`.

- class:

  An async timeout method object, which methods dispatch on.

- call:

  A function of no arguments that starts the work and returns a promise.

- ...:

  Passed to methods.

## Value

`async_timeout()` returns a decorator whose decorated function returns a
promise. `async_timeout_later()` returns a method, and
`async_timeout_fn()` returns a promise.

## Details

The wrapped function may return a promise or a plain value. A thrown
error rejects the promise. Limits:

- It does not stop the work. The caller is told, but the underlying
  request or task keeps running. A custom method can cancel it.

- It cannot bound a function that blocks the session before returning
  its promise, as the timer needs the event loop. Use
  [`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
  for that.

- Nested `async_timeout()`s each run their own timer, so the soonest
  rejects first. There is no shared deadline like
  [`timeout_remaining()`](https://dyfanjones.github.io/garnish/reference/timeout.md).

Needs the promises and later packages, and an event loop.

## Timeout methods

`method` decides how the limit is enforced. `async_timeout_later()`, the
only built-in, races the promise against a
[`later::later()`](https://later.r-lib.org/reference/later.html) timer.
To write your own, make an S7 class inheriting from `async_timeout_base`
and register a method for `async_timeout_fn(class, call, seconds)`.
[`call()`](https://rdrr.io/r/base/call.html) starts the work and returns
a promise. The method must return a promise that settles with its
result, or rejects with a `garnish_timeout_error` once `seconds` pass.
`async_timeout()` adds the function name and limit, and signals a
`garnish_timeout_method_error` if the method does not return a promise.

## Examples

``` r
if (FALSE) { # \dontrun{
# A stand-in for a slow request: resolves after `delay` seconds
slow_request <- function(delay) {
  promises::promise(function(resolve, reject) {
    later::later(function() resolve("response"), delay)
  })
}

f <- async_timeout(0.1) %@% slow_request
promises::then(
  f(1),
  onFulfilled = function(value) cat("got", value, "\n"),
  onRejected = function(err) cat("failed:", conditionMessage(err), "\n")
)
while (!later::loop_empty()) later::run_now(0.1)

# Cap each attempt of an async_retry()
fetch <- async_retry(stop = stop_after_attempt(3), wait = wait_exp()) %@%
  async_timeout(5) %@%
  function(url) slow_request(1)
} # }
```
