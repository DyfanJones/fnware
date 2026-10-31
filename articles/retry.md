# Retrying failing calls

``` r

library(garnish)
```

Some failures are temporary: a network blip, a rate limit, a lock held
by someone else.
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
calls the function again until it works or you tell it to give up. It is
a port of Python’s [tenacity](https://github.com/jd/tenacity), and is
built from three questions:

- **When do we stop?** (`stop`)
- **How long do we wait between attempts?** (`wait`)
- **Which outcomes count as a failure?** (`retry`)

Each has a default, so
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md) on
its own retries any error, immediately, forever. That is rarely what you
want, so you will usually set `stop`.

## A function that fails at first

The examples use a function that fails twice and then succeeds:

``` r

make_flaky <- function(fail_times) {
  calls <- 0
  function() {
    calls <<- calls + 1
    if (calls <= fail_times) stop("not yet (call ", calls, ")")
    paste("worked on call", calls)
  }
}
```

Apply
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
with `%@%`, or by calling it on the function:

``` r

flaky <- retry(stop = stop_after_attempt(5)) %@% make_flaky(2)
flaky()
```

    ## [1] "worked on call 3"

## Deciding when to stop

`stop_after_attempt(n)` makes at most `n` attempts. When it fires, a
`retry_error` condition is signalled:

``` r

never_works <- retry(stop = stop_after_attempt(3)) %@% make_flaky(Inf)
never_works()
```

    ## Error:
    ## ! Retry failed after 3 attempt(s): not yet (call 3)

The condition records what happened, so you can catch it and look:

``` r

fresh <- retry(stop = stop_after_attempt(3)) %@% make_flaky(Inf)
err <- tryCatch(fresh(), retry_error = identity)
err$attempt
```

    ## [1] 3

``` r

conditionMessage(err$error)
```

    ## [1] "not yet (call 3)"

If you would rather see the original error, set `reraise = TRUE`:

``` r

loud <- retry(stop = stop_after_attempt(2), reraise = TRUE) %@% make_flaky(Inf)
tryCatch(loud(), retry_error = function(e) "retry_error", error = conditionMessage)
```

    ## [1] "not yet (call 2)"

Or return a fallback instead of throwing. `retry_error_callback`
receives the final state, a list with `attempt`, `wait`, `elapsed`,
`error` and `value`:

``` r

safe <- retry(
  stop = stop_after_attempt(2),
  retry_error_callback = function(state) "fallback"
) %@% make_flaky(Inf)
safe()
```

    ## [1] "fallback"

| Stop condition | Gives up when |
|----|----|
| [`stop_never()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md) | never (the default) |
| `stop_after_attempt(n)` | `n` attempts have been made |
| `stop_after_delay(s)` | `s` seconds have passed since the first attempt |
| `stop_before_delay(s)` | the next wait would pass `s` seconds in total |
| `stop_any(a, b)` | either `a` or `b` fires |
| `stop_all(a, b)` | both fire |

Combine them to say “try up to 10 times, but never for more than 30
seconds”:

``` r

stop_any(stop_after_attempt(10), stop_after_delay(30))
```

    ## <garnish::stop_any>
    ##  @ stops:List of 2
    ##  .. $ : <garnish::stop_after_attempt>
    ##  ..  ..@ max_attempt_number: num 10
    ##  .. $ : <garnish::stop_after_delay>
    ##  ..  ..@ max_delay: num 30

## Deciding how long to wait

By default
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
does not wait. For anything talking to a server you want a pause, and
usually one that grows.
[`wait_exp()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md)
doubles the wait each time:

``` r

patient <- retry(
  stop = stop_after_attempt(4),
  wait = wait_exp(multiplier = 0.01)
) %@% make_flaky(3)
system.time(res <- patient())[["elapsed"]] > 0.05
```

    ## [1] TRUE

``` r

res
```

    ## [1] "worked on call 4"

Waiting the same length of time means many clients that failed together
retry together. Adding randomness spreads them out, and `+` combines
strategies:

``` r

wait_exp(multiplier = 0.1) + wait_rand(0, 0.1)
```

    ## <garnish::wait_combine>
    ##  @ waits:List of 2
    ##  .. $ : <garnish::wait_exp>
    ##  ..  ..@ multiplier: num 0.1
    ##  ..  ..@ min       : num 0
    ##  ..  ..@ max       : num 4.61e+18
    ##  ..  ..@ exp_base  : num 2
    ##  .. $ : <garnish::wait_rand>
    ##  ..  ..@ min: num 0
    ##  ..  ..@ max: num 0.1

| Wait strategy | Waits |
|----|----|
| [`wait_none()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md) | no time (the default) |
| `wait_fixed(s)` | `s` seconds |
| `wait_rand(min, max)` | a random time between `min` and `max` |
| [`wait_exp()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md) | `multiplier * exp_base^(attempt - 1)`, between `min` and `max` |
| [`wait_exp_jitter()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md) | exponential, with `"full"`, `"equal"` or `"decorrelated"` jitter |
| `wait_chain(a, b, ...)` | the n-th strategy for the n-th attempt |
| `wait_combine(a, b)` or `a + b` | the sum of the strategies |

## Deciding what to retry

By default every error is retried. A bad password will not fix itself on
the fifth attempt, so retry only what is temporary.

[`retry_if_error()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
matches condition classes:

``` r

calls <- 0
fetch <- retry(
  stop = stop_after_attempt(3),
  retry = retry_if_error("http_error")
) %@% function() {
  calls <<- calls + 1
  rlang::abort("bad request", class = "client_error")
}
try(fetch(), silent = TRUE)
calls
```

    ## [1] 1

It made one attempt, because `client_error` is not an `http_error`.
[`retry_if_error_message()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
matches the text instead, either exactly or by regular expression:

``` r

retry_if_error_message(match = "timed? ?out")
```

    ## <garnish::retry_if_error_message>
    ##  @ message: NULL
    ##  @ match  : chr "timed? ?out"

A function can also fail without erroring, by returning something
unusable.
[`retry_if_result()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
retries when a predicate on the value is `TRUE`:

``` r

polls <- 0
poll <- retry(
  stop = stop_after_attempt(5),
  retry = retry_if_result(is.null)
) %@% function() {
  polls <<- polls + 1
  if (polls < 3) NULL else "ready"
}
poll()
```

    ## [1] "ready"

[`retry_never()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
turns retrying off, which is useful for switching it off from a setting
without removing the decorator.

## Seeing what is happening

Silent retries are hard to debug. The hooks run around each sleep:

``` r

logged <- retry(
  stop = stop_after_attempt(4),
  wait = wait_fixed(0.01),
  before_sleep = before_sleep_log(function(msg) cat(msg, "\n")),
  after_sleep = after_sleep_log(function(msg) cat(msg, "\n"))
) %@% make_flaky(2)
logged()
```

    ## Attempt 1 failed: not yet (call 1). Retrying in 0.01 seconds. 
    ## Slept 0.01 seconds after attempt 1. Retrying. 
    ## Attempt 2 failed: not yet (call 2). Retrying in 0.01 seconds. 
    ## Slept 0.01 seconds after attempt 2. Retrying.

    ## [1] "worked on call 3"

The defaults are
[`before_sleep_none()`](https://dyfanjones.github.io/garnish/reference/before_sleep.md)
and
[`after_sleep_none()`](https://dyfanjones.github.io/garnish/reference/after_sleep.md).
The loggers take any function that accepts one string, so you can send
the message to whatever logging package you use.

## Putting it together

``` r

fetch := retry(
  stop = stop_any(stop_after_attempt(5), stop_after_delay(30)),
  wait = wait_exp_jitter(base = 0.5, jitter = "full"),
  retry = retry_if_error_message(match = "timeout|503"),
  before_sleep = before_sleep_log(),
  reraise = TRUE
) %@% function(url) {
  # ...
}
```

## Notes

- **Only retry things that are safe to repeat.** Retrying a call that
  charges a card or sends an email can do it twice. Put the retry around
  the part that is safe.
- **Retrying hides failures.** Use a stop condition, and a hook that
  logs, so a service that is down for an hour does not look like a slow
  one.
- **Decorators stack.** In `a %@% b %@% f`, `a` is outermost. Put
  [`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
  outside a timing decorator to time all attempts, or inside it to time
  each one.
