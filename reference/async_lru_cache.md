# Cache the results of asynchronous functions

Asynchronous versions of
[`lru_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md),
[`cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md)
and
[`disk_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md),
for functions that return a
[promise](https://rstudio.github.io/promises/reference/promise.html).
They take the same arguments and keys, and the decorated function always
returns a promise. The wrapped function may return a promise or a plain
value.

## Usage

``` r
async_lru_cache(f, maxsize = 1024 * 1024^2, TTL = Inf)

async_cache(f)

async_disk_cache(f, dir, maxsize = 1024 * 1024^2, TTL = Inf, format = c("rds", "qs2"))
```

## Arguments

- f:

  The function to decorate. Usually supplied by `%@%` rather than
  directly.

- maxsize:

  Maximum cache size in bytes. Defaults to 1 GiB.

- TTL:

  Time to live in seconds. Entries older than this are treated as
  missing and recomputed on the next call. Defaults to `Inf`, so entries
  never expire. Not available for
  [`cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md),
  which never evicts.

- dir:

  Directory for
  [`disk_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md)
  to keep its files in. It is created if needed. There is no default, so
  persistence is always a choice.

- format:

  File format for
  [`disk_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md):
  `"rds"` (the default) or `"qs2"`, which needs the qs2 package.

## Value

A decorator. The decorated function returns a promise.

## Details

- The resolved value is cached, not the promise, so a rejection is not
  cached and the next call tries again.

- Identical calls made while one is running share its promise, so a
  burst of the same request makes one call.

- Because only values are stored, `async_disk_cache()` works, and it
  shares files with
  [`disk_cache()`](https://dyfanjones.github.io/fnware/reference/lru_cache.md)
  for the same function.

Needs the promises package and an event loop.

## Examples

``` r
if (FALSE) { # \dontrun{
calls <- 0
request := async_lru_cache() %@% function(id) {
  calls <<- calls + 1
  promises::promise(function(resolve, reject) {
    later::later(function() resolve(id * 2), 0.05)
  })
}
# Three identical calls at once make one request
for (i in 1:3) promises::then(request(21), function(value) cat(value, "\n"))
while (!later::loop_empty()) later::run_now(0.05)
calls

# Results survive the session on disk
f := async_disk_cache(tempfile()) %@% function(x) x^2
} # }
```
