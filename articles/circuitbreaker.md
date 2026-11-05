# Failing fast with a circuit breaker

``` r

library(fnware)
```

[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md)
helps when a failure is brief. It does not help when a service is down
for minutes: every caller keeps waiting on it, retrying it, and adding
load to something that is already struggling.
[`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md)
handles that case. After a run of failures it stops calling the function
and fails immediately, then tries again after a cooldown. It is a port
of Python’s [pybreaker](https://github.com/danielfm/pybreaker).

It takes two settings:

- `failures`: how many errors in a row open the circuit (default 5).
- `reset_after`: how many seconds the circuit stays open before a trial
  call (default 30).

## A service that is down

The examples use a function that always fails, and count how many times
it actually runs:

``` r

calls <- 0
service <- function() {
  calls <<- calls + 1
  stop("service down")
}

guarded := circuit_breaker(failures = 2, reset_after = 1) %@% service
```

The first two calls reach `service()` and fail with its own error:

``` r

guarded()
```

    ## Error:
    ## ! service down

``` r

guarded()
```

    ## Error:
    ## ! service down

That was the second failure in a row, so the circuit is now open. The
next call is rejected without running `service()` at all:

``` r

guarded()
```

    ## Error:
    ## ! Circuit is open: the function failed repeatedly and is not being called.

``` r

calls
```

    ## [1] 2

`calls` is still 2. The caller got an answer straight away instead of
waiting on a service that is known to be down.

## The three states

The circuit is always in one of three states:

- **closed**: calls go through, and consecutive errors are counted. This
  is the normal state.
- **open**: after `failures` errors in a row, calls fail immediately for
  `reset_after` seconds.
- **half-open**: once the cooldown has passed, the next call runs as a
  trial. If it succeeds, the circuit closes. If it fails, the circuit
  opens again for another cooldown.

Waiting out the cooldown shows the trial call. Here the service comes
back while the circuit is open, so the trial succeeds and the circuit
closes:

``` r

healthy <- FALSE
fn <- function() if (healthy) "back up" else stop("service down")
guarded := circuit_breaker(failures = 2, reset_after = 0.5) %@% fn

try(guarded(), silent = TRUE)
try(guarded(), silent = TRUE)
guarded() # open: rejected
```

    ## Error:
    ## ! Circuit is open: the function failed repeatedly and is not being called.

``` r

healthy <- TRUE
Sys.sleep(0.6) # wait out the cooldown
guarded() # half-open: the trial call succeeds and closes the circuit
```

    ## [1] "back up"

``` r

guarded() # closed again
```

    ## [1] "back up"

If the service had still been down, the trial would have failed and the
circuit would have opened for another full cooldown.

## What counts as a failure

Only errors count. A call that returns normally, whatever its value, is
a success and resets the count. So the circuit opens on `failures`
errors *in a row*, not `failures` errors in total:

``` r

outcomes <- c("error", "ok", "error", "ok")
i <- 0
fn <- function() {
  i <<- i + 1
  if (outcomes[[i]] == "error") stop("failed") else "ok"
}
guarded := circuit_breaker(failures = 2) %@% fn

try(guarded(), silent = TRUE)
guarded() # the success resets the count
```

    ## [1] "ok"

``` r

try(guarded(), silent = TRUE)
guarded() # still closed: the errors were never consecutive
```

    ## [1] "ok"

## Handling an open circuit

A rejected call signals an error of class `fnware_circuit_open`. Catch
it separately from the function’s own errors to fall back to something
else, such as a cached value, instead of failing:

``` r

fn <- function() stop("service down")
guarded := circuit_breaker(failures = 1, reset_after = 60) %@% fn
try(guarded(), silent = TRUE) # opens the circuit

fetch_or_default <- function() {
  tryCatch(
    guarded(),
    fnware_circuit_open = function(cnd) "default value"
  )
}
fetch_or_default()
```

    ## [1] "default value"

Errors the function raises itself still reach you unchanged, so you can
tell “the service failed” apart from “we did not try”.

## Using it with retry

The two decorators answer different questions, and they work well
together.
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md)
covers a brief failure.
[`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md)
covers a long one.

Put
[`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md)
**outside**
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md):

``` r

fetch := circuit_breaker(failures = 3, reset_after = 30) %@%
  retry(stop = stop_after_attempt(3), wait = wait_exp(min = 0.1)) %@%
  function(url) {
    # ...
  }
```

In `a %@% b %@% f`, `a` is outermost. With the breaker outside, an open
circuit rejects the call before any retries happen. Each call to
`fetch()` that exhausts its three attempts counts as **one** failure, so
three failed calls (nine attempts) open the circuit.

With the breaker inside, it would count every individual attempt.
Retries would trip it quickly, and an open circuit would then be retried
against, which defeats the point.

If you also use
[`rate_limit()`](https://dyfanjones.github.io/fnware/reference/rate_limit.md),
it goes inside
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md), so
the order from outside to inside is
[`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md),
[`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md),
[`rate_limit()`](https://dyfanjones.github.io/fnware/reference/rate_limit.md).

## With promises

[`async_circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/async_circuit_breaker.md)
is the version for functions that return a promise, such as
[`httr2::req_perform_promise()`](https://httr2.r-lib.org/reference/req_perform_promise.html)
or a `mirai` task. It takes the same arguments and keeps the same three
states, and a call fails when its promise rejects. An open circuit
returns a promise that is already rejected with a `fnware_circuit_open`
error, without calling the function.

``` r

down <- function() promises::promise_reject(simpleError("service down"))
fetch := async_circuit_breaker(failures = 2, reset_after = 60) %@% down

# Failures are counted when a promise settles, so let each call settle
try_once <- function() {
  promises::then(
    fetch(),
    onRejected = function(err) cat(class(err)[[1]], "\n")
  )
  while (!later::loop_empty()) later::run_now(0.1)
}
try_once()
```

    ## simpleError

``` r

try_once()
```

    ## simpleError

``` r

try_once() # the circuit is open: down() is not called
```

    ## fnware_circuit_open

Asynchronous calls overlap, which adds a few rules. A failure is counted
when its promise rejects, so calls made before earlier ones have settled
all go through. While the circuit is half-open only one trial call runs,
and other calls are refused until it settles. A call that started before
the circuit opened and finishes after it does not close the circuit. A
trial that never settles is abandoned after `reset_after` seconds, so
put
[`async_timeout()`](https://dyfanjones.github.io/fnware/reference/async_timeout.md)
inside to bound it sooner.

Stack it outside
[`async_retry()`](https://dyfanjones.github.io/fnware/reference/async_retry.md)
in the same way as above, and see the retry vignette for
[`async_timeout()`](https://dyfanjones.github.io/fnware/reference/async_timeout.md).

## Notes

- **State belongs to the decorated function.** Two functions decorated
  separately have separate circuits, and a circuit is not shared between
  R sessions or workers.
- **Choose `reset_after` to match recovery time.** Too short and the
  circuit keeps sending trial calls to a service that has not recovered.
  Too long and callers are refused after it has.
- **Every error counts.** The breaker cannot tell a service outage from
  a bad argument. If some errors should not open the circuit, handle
  them inside the decorated function so they do not escape as errors.
