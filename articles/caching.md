# Caching results

``` r

library(garnish)
```

A cache remembers what a function returned for a given set of arguments,
so the second call is a lookup instead of the work. garnish has three
caching decorators, and the difference between them is what happens to
old entries:

| Decorator | Keeps results | When full |
|----|----|----|
| [`lru_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md) | in memory | drops the least recently used entry |
| `cache` | in memory | never drops anything |
| [`disk_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md) | in files, so they outlive the session | drops the least recently used file |

[`lru_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md)
and `cache` are ports of Python’s `functools.lru_cache` and
`functools.cache`.
[`disk_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md)
is closer to `joblib.Memory.cache`.

The examples use a function that reports when it actually does the work:

``` r

slow_square <- function(x) {
  cat("  computing", x, "\n")
  x^2
}
```

## In memory

``` r

square <- lru_cache() %@% slow_square
square(4)
```

    ##   computing 4

    ## [1] 16

``` r

square(4)
```

    ## [1] 16

``` r

square(5)
```

    ##   computing 5

    ## [1] 25

The second call printed nothing, because the function did not run.
`cache` is the same but has no size limit, and takes no parameters, so
apply it directly:

``` r

square <- cache %@% slow_square
square(4)
```

    ##   computing 4

    ## [1] 16

``` r

square(4)
```

    ## [1] 16

Use
[`lru_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md)
when the number of distinct inputs is unbounded and memory matters. Use
`cache` when you know it is small.

### What counts as the same call

The key is the *matched* arguments including defaults, so spelling a
call differently does not miss the cache:

``` r

area <- lru_cache() %@% function(w, h = 2) {
  cat("  computing\n")
  w * h
}
area(3)
```

    ##   computing

    ## [1] 6

``` r

area(w = 3)
```

    ## [1] 6

``` r

area(3, 2)
```

    ## [1] 6

``` r

area(h = 2, w = 3)
```

    ## [1] 6

Those four calls ran the function once. Changing an argument that
matters does run it again:

``` r

area(3, 5)
```

    ##   computing

    ## [1] 15

### What is and is not cached

- A **result** is cached, including `NULL` and including
  [`invisible()`](https://rdrr.io/r/base/invisible.html) results, which
  stay invisible on a hit.
- An **error is not cached**, so a call that failed is tried again next
  time.

``` r

attempts <- 0
f <- lru_cache() %@% function() {
  attempts <<- attempts + 1
  if (attempts < 2) stop("first call fails")
  "ok"
}
try(f(), silent = TRUE)
f()
```

    ## [1] "ok"

``` r

f()
```

    ## [1] "ok"

``` r

attempts
```

    ## [1] 2

### Limiting size

For
[`lru_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md),
`maxsize` is a size in **bytes** (default 1 GiB), not a number of
entries as in Python. When the cache is over that, the entry used least
recently goes first.

``` r

g <- lru_cache(maxsize = 7000) %@% function(i) {
  cat("  computing", i, "\n")
  numeric(200) + i # roughly 2 KB per entry, so three fit
}
invisible(g(1)); invisible(g(2)); invisible(g(3))
```

    ##   computing 1

    ##   computing 2

    ##   computing 3

``` r

invisible(g(1)) # a hit, so 2 is now the least recently used
invisible(g(4)) # over the limit, so 2 is evicted
```

    ##   computing 4

``` r

invisible(g(2)) # recomputed
```

    ##   computing 2

## On disk

[`disk_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md)
stores each result as a file in `dir`. Close R, start again, and the
results are still there. There is no default for `dir`: a temporary
directory would disappear with the session and defeat the point.

``` r

dir <- tempfile("garnish-cache")
square <- disk_cache(dir) %@% slow_square
square(7)
```

    ##   computing 7

    ## [1] 49

``` r

square(7)
```

    ## [1] 49

``` r

length(list.files(dir))
```

    ## [1] 1

A second decoration of the same function, such as in a new session,
reuses the files:

``` r

square_again <- disk_cache(dir) %@% slow_square
square_again(7)
```

    ## [1] 49

### Changing the function

The key includes the function’s formals and body, so editing it starts a
fresh cache for that function. Entries from the old version stay in
`dir` until they are evicted:

``` r

v1 <- disk_cache(dir) %@% function(x) x + 1
v2 <- disk_cache(dir) %@% function(x) x + 2
c(v1(1), v2(1))
```

    ## [1] 2 3

What it does **not** notice is a change to something the function
*calls*. If `f` calls `helper()` and you change `helper()`, the cached
results of `f` are stale. Point `dir` somewhere new, or delete the
files, when that happens.

### Choosing a file format

By default results are saved with
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html). With the
[qs2](https://github.com/qsbase/qs2) package installed, `format = "qs2"`
is faster and a little smaller. On a data frame of one million rows, qs2
was about seven times faster to write and three and a half times faster
to read back on one machine, so measure your own data.

``` r

fast <- disk_cache(tempfile("garnish-cache"), format = "qs2") %@% slow_square
fast(3)
```

    ##   computing 3

    ## [1] 9

``` r

fast(3)
```

    ## [1] 9

The two formats do not share files. Changing `format` for an existing
`dir` starts with an empty cache.

## When not to cache

Caching assumes that the same arguments give the same answer, and that
the function has no effects you need to happen every time.

- **Not pure.** A function that reads the clock, a random number
  generator, a file, or a database can return a different answer next
  time. The cache will keep returning the first one.
- **Side effects.** A cached call skips them. `cat("computing")` above
  ran once. If the function also writes a file, a hit will not write it
  again.
- **Large or unstable arguments.** Each call hashes its arguments, so
  hashing a huge data frame can cost more than the function it saves.
- **Objects that do not serialise.** Environments, external pointers and
  R6 objects do not round-trip through
  [`disk_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md).

## Choosing

- Same session, small set of inputs: `cache`.
- Same session, many inputs, memory matters:
  [`lru_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md).
- You want results to survive a restart, or share between sessions:
  [`disk_cache()`](https://dyfanjones.github.io/garnish/reference/lru_cache.md).
