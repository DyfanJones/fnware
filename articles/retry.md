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
    if (calls <= fail_times) {
      stop("not yet (call ", calls, ")")
    }
    paste("worked on call", calls)
  }
}
```

Apply
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
with `%@%`, or by calling it on the function:

``` r

flaky := retry(stop = stop_after_attempt(5)) %@% make_flaky(2)
flaky()
```

    ## [1] "worked on call 3"

## Deciding when to stop

`stop_after_attempt(n)` makes at most `n` attempts. When it fires, a
`retry_error` condition is signalled:

``` r

never_works := retry(stop = stop_after_attempt(3)) %@% make_flaky(Inf)
never_works()
```

    ## Error:
    ## ! Retry failed after 3 attempt(s): not yet (call 3)

The condition records what happened, so you can catch it and look:

``` r

fresh := retry(stop = stop_after_attempt(3)) %@% make_flaky(Inf)
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

loud := retry(stop = stop_after_attempt(2), reraise = TRUE) %@% make_flaky(Inf)
tryCatch(
  loud(),
  retry_error = function(e) "retry_error",
  error = conditionMessage
)
```

    ## [1] "not yet (call 2)"

Or return a fallback instead of throwing. `retry_error_callback`
receives the final state, a list with `attempt`, `wait`, `elapsed`,
`error` and `value`:

``` r

safe <- retry(
  stop = stop_after_attempt(2),
  retry_error_callback = function(state) "fallback"
) %@%
  make_flaky(Inf)
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
) %@%
  make_flaky(3)
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
) %@%
  function() {
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
) %@%
  function() {
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
) %@%
  make_flaky(2)
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

## Bounding hung calls

[`stop_after_delay()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md)
only checks the clock *between* attempts. If one attempt hangs, it never
gets the chance.
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
bounds a single call: when the time is up it signals a
`garnish_timeout_error`, which is an ordinary error, so
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
treats it like any other failure.

Stack it inside
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md) so
every attempt is capped and a timeout is retried:

``` r

slow_work <- function() {
  # Many short steps, so R can stop between them (see the notes below)
  for (i in 1:100) {
    Sys.sleep(0.02)
  }
  "finished"
}

attempts <- 0
fetch := retry(stop = stop_after_attempt(3), wait = wait_fixed(0.01)) %@%
  timeout(0.2) %@%
  function() {
    attempts <<- attempts + 1
    if (attempts < 3) slow_work() else "fast enough"
  }
fetch()
```

    ## [1] "fast enough"

``` r

attempts
```

    ## [1] 3

The first two attempts were cut off after 0.2 seconds and the third
finished in time. The error records the limit and the function name:

``` r

slow_call := timeout(0.2) %@% slow_work
err <- tryCatch(slow_call(), error = identity)
class(err)
```

    ## [1] "garnish_timeout_error" "rlang_error"           "error"                
    ## [4] "condition"

``` r

conditionMessage(err)
```

    ## [1] "`slow_call` timed out: it did not finish within 0.2 seconds."

Put
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
*inside*
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md), as
above. Outside it,
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
catches the time limit error and the limit is already spent, so later
attempts would run without one.

### Passing the time on

Some libraries have their own timeouts, which can clean up properly.
[`timeout_remaining()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
returns the seconds left before the current deadline (`Inf` outside any
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)),
so you can hand them the budget:

``` r

budgeted := timeout(10) %@%
  function() {
    # e.g. httr2::req_timeout(req, timeout_remaining())
    round(timeout_remaining())
  }
budgeted()
```

    ## [1] 10

Timeouts can nest. The soonest deadline always wins, so an inner
`timeout(60)` inside an outer `timeout(5)` is cut off after 5 seconds.

### What it cannot stop

The default method,
[`timeout_r()`](https://dyfanjones.github.io/garnish/reference/timeout.md),
uses base R’s
[`setTimeLimit()`](https://rdrr.io/r/base/setTimeLimit.html), which R
only checks at interrupt checkpoints between R expressions. It cannot
interrupt:

- Compiled code (C, C++, Rust) that never calls
  `R_CheckUserInterrupt()`, which includes many blocking network and
  database calls.
- A single long [`Sys.sleep()`](https://rdrr.io/r/base/Sys.sleep.html).
  A loop of short sleeps is fine.

For these, pass
[`timeout_remaining()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
to a native timeout, or use a method that runs the work in another
process and kills it.

### Writing a timeout method

A method is an S7 class that inherits from `timeout_base`, with a method
for the `timeout_fn(class, call, seconds)` generic.
[`call()`](https://rdrr.io/r/base/call.html) runs the decorated function
and `seconds` is the time left. It must return the value of
[`call()`](https://rdrr.io/r/base/call.html) unchanged, or signal a
`garnish_timeout_error`.
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
handles built-in and your own methods the same way, adding the function
name and limit to the message. See
[`?extending_timeout`](https://dyfanjones.github.io/garnish/reference/extending_timeout.md)
for the details.

This one uses the callr package to run the call in a separate R process,
which is killed when the time is up, even if it is stuck in compiled
code. It also sets `GARNISH_TIMEOUT_DEADLINE` in the child, so
[`timeout_remaining()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
works there too:

``` r

library(S7)

timeout_callr := new_class(parent = timeout_base)

method(timeout_fn, timeout_callr) <- function(class, call, seconds, ...) {
  deadline <- format(as.numeric(Sys.time()) + seconds, digits = 17)
  env <- c(callr::rcmd_safe_env(), GARNISH_TIMEOUT_DEADLINE = deadline)
  tryCatch(
    callr::r(
      function(call) call(),
      args = list(call),
      timeout = seconds,
      env = env
    ),
    callr_timeout_error = function(e) {
      rlang::abort("Timed out.", class = "garnish_timeout_error")
    }
  )
}

hang := timeout(0.5, method = timeout_callr()) %@%
  function() {
    Sys.sleep(10)
    "never reached"
  }
tryCatch(hang(), error = function(e) conditionMessage(e))
```

    ## [1] "`hang` timed out: it did not finish within 0.5 seconds."

The function runs in a fresh process, so it cannot change variables in
your session, and its arguments and result must be serialisable. callr
is only suggested by garnish, so install it first if you want to use
this.

## Retrying without blocking

[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
sleeps between attempts, so nothing else can run in your R session while
it waits. When the function already works with
[promises](https://rstudio.github.io/promises/), as in Shiny, plumber or
[`httr2::req_perform_promise()`](https://httr2.r-lib.org/reference/req_perform_promise.html),
use
[`async_retry()`](https://dyfanjones.github.io/garnish/reference/async_retry.md).
It takes the same arguments and the same stop, wait and retry
strategies, including ones you wrote yourself, but schedules the next
attempt with `later` instead of sleeping, and returns a promise.

``` r

flaky <- async_retry(
  stop = stop_after_attempt(5),
  wait = wait_fixed(0.05)
) %@%
  make_flaky(2)

p <- flaky()
promises::then(p, function(value) cat("resolved:", value, "\n"))

# Shiny and plumber run the event loop for you. In a script, run it yourself.
while (!later::loop_empty()) {
  later::run_now(0.1)
}
```

    ## resolved: worked on call 3

The function can return a plain value, as above, or a promise. A
rejected promise counts as a failure, so a `mirai` task or an `httr2`
async request is retried the same way. When `stop` fires, the promise
rejects with the same `retry_error` that
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
would signal.

[`async_retry()`](https://dyfanjones.github.io/garnish/reference/async_retry.md)
needs the promises and later packages. Put it outermost: a decorator
inside it that calls the function synchronously, such as
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md),
cannot wait for or bound a promise.

### Bounding a slow promise

[`async_timeout()`](https://dyfanjones.github.io/garnish/reference/async_timeout.md)
is the promise version of
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md).
If the promise has not settled after the limit, the promise it returns
rejects with the same `garnish_timeout_error`, which
[`async_retry()`](https://dyfanjones.github.io/garnish/reference/async_retry.md)
retries:

``` r

# A stand-in for a request: resolves with `value` after `delay` seconds
request <- function(value, delay) {
  promises::promise(function(resolve, reject) {
    later::later(function() resolve(value), delay)
  })
}

calls <- 0
fetch := async_retry(stop = stop_after_attempt(3)) %@%
  async_timeout(0.1) %@%
  function() {
    calls <<- calls + 1
    if (calls < 3) request("too slow", 1) else request("in time", 0.01)
  }

promises::then(fetch(), function(value) cat("resolved:", value, "\n"))
while (!later::loop_empty()) {
  later::run_now(0.1)
}
```

    ## resolved: in time

``` r

calls
```

    ## [1] 3

It tells the caller to stop waiting but does not stop the work, so the
first two requests above are still running when the third finishes. A
method that also cancels the work, for example a `mirai` task, can be
written with `async_timeout_base` and
[`async_timeout_fn()`](https://dyfanjones.github.io/garnish/reference/async_timeout.md),
the same way as for
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md).
It cannot bound a function that blocks the session before it returns a
promise. Use
[`timeout()`](https://dyfanjones.github.io/garnish/reference/timeout.md)
for that.

## Writing your own strategies

Everything above is built from five kinds of strategy, and you can add
your own to any of them. They are S7 classes, so if you have not used
S7, the idea is small: make a class that inherits from a base class,
then say what it does by registering a method for a generic. The
built-in strategies work the same way, and yours combine with them.

| [`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md) argument | Inherit from | Method of | Return |
|----|----|----|----|
| `stop` | `stop_base` | `stop_fn(class, state)` | `TRUE` to give up |
| `wait` | `wait_base` | `wait_fn(class, attempt, prev_wait)` | seconds to sleep |
| `retry` | `retry_base` | `retry_fn(class, outcome)` | `TRUE` to try again |
| `before_sleep` | `before_sleep_base` | `before_sleep_fn(class, state)` | nothing |
| `after_sleep` | `after_sleep_base` | `after_sleep_fn(class, state)` | nothing |

A wait that grows by a fixed step each attempt:

``` r

library(S7)

wait_linear := new_class(
  parent = wait_base,
  properties = list(step = class_numeric),
  constructor = function(step = 1) new_object(wait_base(), step = step)
)

method(wait_fn, wait_linear) <- function(
  class,
  attempt,
  prev_wait = NULL,
  ...
) {
  class@step * attempt
}

wait_fn(wait_linear(2), attempt = 3)
```

    ## [1] 6

It composes like the built-in waits, with `+` and in
[`wait_chain()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md):

``` r

wait_fn(wait_linear(1) + wait_fixed(2), attempt = 3)
```

    ## [1] 5

A stop condition gets the `state` list described in
[`?extending_retry`](https://dyfanjones.github.io/garnish/reference/extending_retry.md),
which has `attempt`, `wait`, `elapsed`, `error` and `value`. This one
gives up once an attempt fails with a message matching a pattern:

``` r

stop_on_message := new_class(
  parent = stop_base,
  properties = list(pattern = class_character),
  constructor = function(pattern) new_object(stop_base(), pattern = pattern)
)

method(stop_fn, stop_on_message) <- function(class, state, ...) {
  !is.null(state$error) && grepl(class@pattern, conditionMessage(state$error))
}

attempts <- 0
fatal <- retry(
  stop = stop_any(stop_after_attempt(5), stop_on_message("permission denied"))
) %@%
  function() {
    attempts <<- attempts + 1
    stop("permission denied")
  }
try(fatal(), silent = TRUE)
attempts
```

    ## [1] 1

It stopped after one attempt, though `stop_after_attempt(5)` would have
allowed five, because
[`stop_any()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md)
fires when either condition does.

A retry condition gets `outcome`, a list with `value` and `error`, one
of which is `NULL`:

``` r

retry_if_negative := new_class(parent = retry_base)

method(retry_fn, retry_if_negative) <- function(class, outcome, ...) {
  is.null(outcome$error) && outcome$value < 0
}

vals <- c(-1, -1, 5)
i <- 0
next_value := retry(retry = retry_if_negative()) %@%
  function() {
    i <<- i + 1
    vals[[i]]
  }
next_value()
```

    ## [1] 5

``` r

i
```

    ## [1] 3

If you write strategies in a package, call
[`S7::methods_register()`](https://rconsortium.github.io/S7/reference/S7_on_load.html)
in its `.onLoad()` so the methods are registered when it loads.

## Putting it together

``` r

fetch := retry(
  stop = stop_any(stop_after_attempt(5), stop_after_delay(30)),
  wait = wait_exp_jitter(base = 0.5, jitter = "full"),
  retry = retry_if_error_message(match = "timeout|503"),
  before_sleep = before_sleep_log(),
  reraise = TRUE
) %@%
  function(url) {
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
- **Retrying a service that is down is wasteful.** For a failure that
  lasts minutes rather than seconds, stack
  [`circuit_breaker()`](https://dyfanjones.github.io/garnish/articles/circuitbreaker.md)
  outside
  [`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
  so callers fail fast once the service is clearly down.
