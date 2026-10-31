# Package index

## Retrying

Call a function again when it fails.

- [`retry`](https://dyfanjones.github.io/garnish/reference/retry.md) :
  Retry a function when it fails

- [`stop_never()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md)
  [`stop_after_attempt()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md)
  [`stop_after_delay()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md)
  [`stop_before_delay()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md)
  [`stop_any()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md)
  [`stop_all()`](https://dyfanjones.github.io/garnish/reference/stop_conditions.md)
  : Stop conditions

- [`wait_fixed()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md)
  [`wait_none()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md)
  [`wait_exp()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md)
  [`wait_exp_jitter()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md)
  [`wait_rand()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md)
  [`wait_chain()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md)
  [`wait_combine()`](https://dyfanjones.github.io/garnish/reference/wait_strategies.md)
  : Wait strategies

- [`retry_all()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
  [`retry_never()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
  [`retry_if_error()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
  [`retry_if_error_message()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
  [`retry_if_result()`](https://dyfanjones.github.io/garnish/reference/retry_conditions.md)
  : Retry conditions

- [`before_sleep_none()`](https://dyfanjones.github.io/garnish/reference/before_sleep.md)
  [`before_sleep_log()`](https://dyfanjones.github.io/garnish/reference/before_sleep.md)
  :

  Run a hook before
  [`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
  sleeps

- [`after_sleep_none()`](https://dyfanjones.github.io/garnish/reference/after_sleep.md)
  [`after_sleep_log()`](https://dyfanjones.github.io/garnish/reference/after_sleep.md)
  :

  Run a hook after
  [`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
  sleeps

## Caching

Remember a function’s results.

- [`lru_cache`](https://dyfanjones.github.io/garnish/reference/lru_cache.md)
  [`cache`](https://dyfanjones.github.io/garnish/reference/lru_cache.md)
  [`disk_cache`](https://dyfanjones.github.io/garnish/reference/lru_cache.md)
  : Cache function results

## Context managers

Write setup and teardown once.

- [`teardown()`](https://dyfanjones.github.io/garnish/reference/contextmanager.md)
  : Write setup and teardown once
- [`with_context()`](https://dyfanjones.github.io/garnish/reference/with_context.md)
  : Run code inside a context
- [`as_decorator()`](https://dyfanjones.github.io/garnish/reference/as_decorator.md)
  : Use a context manager as a decorator

## Re-exports

- [`reexports`](https://dyfanjones.github.io/garnish/reference/reexports.md)
  [`:=`](https://dyfanjones.github.io/garnish/reference/reexports.md)
  [`%@%`](https://dyfanjones.github.io/garnish/reference/reexports.md) :
  Objects exported from other packages
