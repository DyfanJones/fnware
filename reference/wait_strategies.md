# Wait strategies

Decide how many seconds
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md)
sleeps after a failed attempt.

## Usage

``` r
wait_fixed(wait = integer(0))

wait_none()

wait_exp(multiplier = 1, min = 0, max = 4611686018427387904, exp_base = 2)

wait_exp_jitter(base = 0.1, max_delay = 20, jitter = "full")

wait_rand(min = 0, max = 1)

wait_chain(...)

wait_combine(...)
```

## Arguments

- wait:

  Seconds to wait.

- multiplier, exp_base:

  Scale and base of the exponential.

- min, max:

  Lower and upper bound in seconds.

- base:

  Seconds to wait on the first attempt.

- max_delay:

  Longest wait in seconds.

- jitter:

  Jitter type, one of `"full"`, `"equal"`, `"decorrelated"` or `"none"`.

- ...:

  Wait strategies to chain or combine.

## Value

A wait strategy to pass to
[`retry()`](https://dyfanjones.github.io/garnish/reference/retry.md).

## Details

- `wait_none()` does not wait.

- `wait_fixed()` waits a fixed time.

- `wait_rand()` waits a random time between `min` and `max`.

- `wait_exp()` waits `multiplier * exp_base^(attempt - 1)`, kept between
  `min` and `max`.

- `wait_exp_jitter()` waits `base * 2^(attempt - 1)`, capped at
  `max_delay`, then applies `jitter`: `"none"`, `"full"` (uniform from
  0), `"equal"` (half fixed, half random) or `"decorrelated"` (random
  between `base` and 3 times the previous wait).

- `wait_chain()` uses the n-th strategy for the n-th attempt, then
  repeats the last.

- `wait_combine()` adds strategies together. `a + b` is the same as
  `wait_combine(a, b)`.

## Examples

``` r
wait_fixed(2)
#> <garnish::wait_fixed>
#>  @ wait: num 2
wait_exp(multiplier = 0.5, max = 30)
#> <garnish::wait_exp>
#>  @ multiplier: num 0.5
#>  @ min       : num 0
#>  @ max       : num 30
#>  @ exp_base  : num 2
wait_chain(wait_fixed(1), wait_fixed(5))
#> <garnish::wait_chain>
#>  @ waits:List of 2
#>  .. $ : <garnish::wait_fixed>
#>  ..  ..@ wait: num 1
#>  .. $ : <garnish::wait_fixed>
#>  ..  ..@ wait: num 5
wait_fixed(1) + wait_rand(0, 2)
#> <garnish::wait_combine>
#>  @ waits:List of 2
#>  .. $ : <garnish::wait_fixed>
#>  ..  ..@ wait: num 1
#>  .. $ : <garnish::wait_rand>
#>  ..  ..@ min: num 0
#>  ..  ..@ max: num 2
```
