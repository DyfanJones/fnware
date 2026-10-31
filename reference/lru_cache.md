# Cache function results

Decorators that remember a function's results, keyed on the matched
arguments (including defaults).

## Arguments

- maxsize:

  Maximum cache size in bytes. Defaults to 1 GiB.

- format:

  File format for `disk_cache()`: `"rds"` (the default) or `"qs2"`,
  which needs the qs2 package.

- dir:

  Directory for `disk_cache()` to keep its files in. It is created if
  needed. There is no default, so persistence is always a choice.

## Value

A decorator.

## Details

- `lru_cache()` evicts the least recently used entries when the cache is
  full. Port of Python's `functools.lru_cache`.

- `cache()` never evicts. Port of Python's `functools.cache`.

- `disk_cache()` stores results as files in `dir`, so they survive the R
  session and can be shared between sessions. Like
  `joblib.Memory.cache`.

Entries are keyed on the function's formals and body as well as its
arguments, so editing the function invalidates them. Changes to anything
it calls do not. `disk_cache()` saves results with
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html), or with the qs2
package when `format = "qs2"`, which is usually faster and smaller for
large objects. Neither round-trips environments or external pointers.
Files from the two formats are not shared, so changing `format` for an
existing `dir` starts with an empty cache.

Call `lru_cache(maxsize)` to build a decorator, then apply it with `%@%`
or by calling it on a function. `cache` takes no parameters, so it is
applied directly.

## Examples

``` r
slow_square <- lru_cache() %@% function(x) {
  Sys.sleep(0.1)
  x^2
}
slow_square(4) # slow
#> [1] 16
slow_square(4) # cached
#> [1] 16

slow_cube <- cache %@% function(x) {
  Sys.sleep(0.1)
  x^3
}
slow_cube(2) # slow
#> [1] 8
slow_cube(2) # cached
#> [1] 8

dir <- tempfile("cache")
slow_cube <- disk_cache(dir) %@% function(x) {
  Sys.sleep(0.1)
  x^3
}
slow_cube(2) # slow, and saved to `dir`
#> [1] 8
slow_cube(2) # cached
#> [1] 8
```
