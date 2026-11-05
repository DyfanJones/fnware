# Package index

## Retrying

Call a function again when it fails.

- [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md) :
  Retry a function when it fails

- [`stop_never()`](https://dyfanjones.github.io/fnware/reference/stop_conditions.md)
  [`stop_after_attempt()`](https://dyfanjones.github.io/fnware/reference/stop_conditions.md)
  [`stop_after_delay()`](https://dyfanjones.github.io/fnware/reference/stop_conditions.md)
  [`stop_before_delay()`](https://dyfanjones.github.io/fnware/reference/stop_conditions.md)
  [`stop_any()`](https://dyfanjones.github.io/fnware/reference/stop_conditions.md)
  [`stop_all()`](https://dyfanjones.github.io/fnware/reference/stop_conditions.md)
  : Stop conditions

- [`wait_fixed()`](https://dyfanjones.github.io/fnware/reference/wait_strategies.md)
  [`wait_none()`](https://dyfanjones.github.io/fnware/reference/wait_strategies.md)
  [`wait_exp()`](https://dyfanjones.github.io/fnware/reference/wait_strategies.md)
  [`wait_exp_jitter()`](https://dyfanjones.github.io/fnware/reference/wait_strategies.md)
  [`wait_rand()`](https://dyfanjones.github.io/fnware/reference/wait_strategies.md)
  [`wait_chain()`](https://dyfanjones.github.io/fnware/reference/wait_strategies.md)
  [`wait_combine()`](https://dyfanjones.github.io/fnware/reference/wait_strategies.md)
  : Wait strategies

- [`retry_all()`](https://dyfanjones.github.io/fnware/reference/retry_conditions.md)
  [`retry_never()`](https://dyfanjones.github.io/fnware/reference/retry_conditions.md)
  [`retry_if_error()`](https://dyfanjones.github.io/fnware/reference/retry_conditions.md)
  [`retry_if_error_message()`](https://dyfanjones.github.io/fnware/reference/retry_conditions.md)
  [`retry_if_result()`](https://dyfanjones.github.io/fnware/reference/retry_conditions.md)
  : Retry conditions

- [`before_sleep_none()`](https://dyfanjones.github.io/fnware/reference/before_sleep.md)
  [`before_sleep_log()`](https://dyfanjones.github.io/fnware/reference/before_sleep.md)
  :

  Run a hook before
  [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md)
  sleeps

- [`after_sleep_none()`](https://dyfanjones.github.io/fnware/reference/after_sleep.md)
  [`after_sleep_log()`](https://dyfanjones.github.io/fnware/reference/after_sleep.md)
  :

  Run a hook after
  [`retry()`](https://dyfanjones.github.io/fnware/reference/retry.md)
  sleeps

- [`after_sleep_base()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  [`after_sleep_fn()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  [`before_sleep_base()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  [`before_sleep_fn()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  [`retry_base()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  [`retry_fn()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  [`wait_base()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  [`wait_fn()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  [`stop_base()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  [`stop_fn()`](https://dyfanjones.github.io/fnware/reference/extending_retry.md)
  : Write your own stop, wait, retry and hook strategies

- [`async_retry()`](https://dyfanjones.github.io/fnware/reference/async_retry.md)
  : Retry a function without blocking

## Caching

Remember a function’s results.

- [`lru_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md)
  [`cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md)
  [`disk_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md)
  : Cache function results
- [`async_lru_cache()`](https://dyfanjones.github.io/fnware/reference/async_lru_cache.md)
  [`async_cache()`](https://dyfanjones.github.io/fnware/reference/async_lru_cache.md)
  [`async_disk_cache()`](https://dyfanjones.github.io/fnware/reference/async_lru_cache.md)
  : Cache the results of asynchronous functions

## Circuit breaking

Stop calling a function that keeps failing.

- [`circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/circuit_breaker.md)
  : Stop calling a function that keeps failing
- [`async_circuit_breaker()`](https://dyfanjones.github.io/fnware/reference/async_circuit_breaker.md)
  : Stop calling an asynchronous function that keeps failing

## Timeouts

Bound how long a single call can run.

- [`timeout_r()`](https://dyfanjones.github.io/fnware/reference/timeout.md)
  [`timeout()`](https://dyfanjones.github.io/fnware/reference/timeout.md)
  [`timeout_remaining()`](https://dyfanjones.github.io/fnware/reference/timeout.md)
  : Bound how long a call can run
- [`timeout_base()`](https://dyfanjones.github.io/fnware/reference/extending_timeout.md)
  [`timeout_fn()`](https://dyfanjones.github.io/fnware/reference/extending_timeout.md)
  : Write your own timeout method
- [`async_timeout()`](https://dyfanjones.github.io/fnware/reference/async_timeout.md)
  [`async_timeout_base()`](https://dyfanjones.github.io/fnware/reference/async_timeout.md)
  [`async_timeout_fn()`](https://dyfanjones.github.io/fnware/reference/async_timeout.md)
  [`async_timeout_later()`](https://dyfanjones.github.io/fnware/reference/async_timeout.md)
  : Bound how long an asynchronous call can take

## Rate limiting

Limit how often a function can be called.

- [`rate_limit()`](https://dyfanjones.github.io/fnware/reference/rate_limit.md)
  : Limit how often a function can be called
- [`async_rate_limit()`](https://dyfanjones.github.io/fnware/reference/async_rate_limit.md)
  : Limit how often an asynchronous function can be called

## Fallbacks

Return a default instead of failing.

- [`fallback()`](https://dyfanjones.github.io/fnware/reference/fallback.md)
  : Return a default when a function fails
- [`async_fallback()`](https://dyfanjones.github.io/fnware/reference/async_fallback.md)
  : Return a default when an asynchronous function fails

## Observability

Log calls and run a function once.

- [`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)
  : Log the calls to a function

- [`log_levels()`](https://dyfanjones.github.io/fnware/reference/log_levels.md)
  :

  The level of each event
  [`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)
  logs

- [`logger_base()`](https://dyfanjones.github.io/fnware/reference/loggers.md)
  [`logger_fn()`](https://dyfanjones.github.io/fnware/reference/loggers.md)
  [`logger_message()`](https://dyfanjones.github.io/fnware/reference/loggers.md)
  : Loggers

- [`extending_log`](https://dyfanjones.github.io/fnware/reference/extending_log.md)
  :

  Use a logging package with
  [`log_call()`](https://dyfanjones.github.io/fnware/reference/log_call.md)

- [`once()`](https://dyfanjones.github.io/fnware/reference/once.md) :
  Run a function only once

## Validation

Check arguments and return values.

- [`validate_args()`](https://dyfanjones.github.io/fnware/reference/validate_args.md)
  [`validate_return()`](https://dyfanjones.github.io/fnware/reference/validate_args.md)
  : Validate arguments and return values

## Context managers

Write setup and teardown once.

- [`contextmanager()`](https://dyfanjones.github.io/fnware/reference/contextmanager.md)
  [`teardown()`](https://dyfanjones.github.io/fnware/reference/contextmanager.md)
  : Write setup and teardown once
- [`with_context()`](https://dyfanjones.github.io/fnware/reference/with_context.md)
  : Run code inside a context
- [`as_decorator()`](https://dyfanjones.github.io/fnware/reference/as_decorator.md)
  : Use a context manager as a decorator

## Re-exports

- [`reexports`](https://dyfanjones.github.io/fnware/reference/reexports.md)
  [`:=`](https://dyfanjones.github.io/fnware/reference/reexports.md)
  [`%@%`](https://dyfanjones.github.io/fnware/reference/reexports.md) :
  Objects exported from other packages
