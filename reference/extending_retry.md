# Write your own stop, wait, retry and hook strategies

[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md) is
built from five kinds of strategy. Each has an abstract base class and a
generic function, both exported, so you can add your own the same way
the built-in ones are written with S7:

## Usage

``` r
after_sleep_base()

after_sleep_fn(class, state, ...)

before_sleep_base()

before_sleep_fn(class, state, ...)

retry_base()

retry_fn(class, outcome, ...)

wait_base()

wait_fn(class, attempt, prev_wait = NULL, ...)

stop_base()

stop_fn(class, state, ...)
```

## Arguments

- class:

  A strategy object. Methods are dispatched on this argument.

- state, outcome, attempt, prev_wait:

  Described above.

- ...:

  Passed to methods.

## Value

`stop_fn()` and `retry_fn()` return a single `TRUE` or `FALSE`,
`wait_fn()` returns a number of seconds, and the hook generics return
nothing useful.

## Details

|  |  |  |  |
|----|----|----|----|
| [`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md) argument | Base class | Generic | The method returns |
| `stop` | `stop_base` | `stop_fn(class, state)` | `TRUE` to give up |
| `wait` | `wait_base` | `wait_fn(class, attempt, prev_wait)` | seconds to sleep |
| `retry` | `retry_base` | `retry_fn(class, outcome)` | `TRUE` to try again |
| `before_sleep` | `before_sleep_base` | `before_sleep_fn(class, state)` | nothing |
| `after_sleep` | `after_sleep_base` | `after_sleep_fn(class, state)` | nothing |

To add a strategy, make a class that inherits from the base class, then
register a method for the generic with
[`S7::method<-()`](https://rconsortium.github.io/S7/reference/method-set.html).
Create the object with
[`new_object()`](https://rconsortium.github.io/S7/reference/new_class.html)
on an instance of the base class, as the built-in strategies do. Load S7
with [`library(S7)`](https://rconsortium.github.io/S7/) to get
[`new_class()`](https://rconsortium.github.io/S7/reference/new_class.html),
[`new_object()`](https://rconsortium.github.io/S7/reference/new_class.html)
and `method<-`.

Strategies of the same kind compose with the built-in ones. A new wait
works in
[`wait_chain()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md)
and with `+`, and a new stop works in
[`stop_any()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md)
and
[`stop_all()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md).

If you register methods from another package, call
[`S7::methods_register()`](https://rconsortium.github.io/S7/reference/S7_on_load.html)
in its `.onLoad()`.

## Arguments passed to methods

- `state`, for `stop_fn()`, `before_sleep_fn()` and `after_sleep_fn()`,
  is a list describing the attempt that just failed: `attempt`
  (1-based), `wait` (seconds
  [`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
  is about to sleep), `elapsed` (seconds since the first attempt),
  `error` (the condition caught, or `NULL` if
  [`retry_if_result()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
  rejected a returned value) and `value` (the value returned, or `NULL`
  if the call errored).

- `attempt` and `prev_wait`, for `wait_fn()`, are the 1-based attempt
  number and the previous sleep in seconds (`NULL` on the first retry).

- `outcome`, for `retry_fn()`, is `list(value, error)` for the attempt
  that just finished. `error` is `NULL` when the call returned normally,
  and `value` is `NULL` when it errored.

## Examples

``` r
library(S7)

# Wait `step` seconds longer after each failure
wait_linear := new_class(
  parent = wait_base,
  properties = list(step = new_property(class_numeric, default = 1))
)

method(wait_fn, wait_linear) <- function(class, attempt, prev_wait = NULL, ...) {
  class@step * attempt
}

f <- retry(
  stop = stop_after_attempt(3),
  wait = wait_linear(0.01) + wait_fixed(0.01)
) %@% function() stop("flaky")
try(f(), silent = TRUE)
```
