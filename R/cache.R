#' @importFrom adorn := decorator decorator_context
#' @importFrom rlang hash
#' @importFrom cachem cache_mem cache_disk
#' @include cache_utils.R
NULL

# Shared body of the caching decorators: `cache` is any cachem-style cache.
# `fn` is the function being decorated: inside a factory `f` is a stand-in whose
# body never changes, so hashing `f` would ignore edits to the real body. Get it
# from `decorator_context()$fn` in the factory itself, as it reads the call stack.
memoised <- function(f, fn, cache) {
  key_of <- memo_key(f, fn)
  function(...) {
    key <- key_of(...)
    res <- cache$get(key)
    if (inherits(res, "key_missing")) {
      res <- withVisible(f(...))
      cache$set(key, res)
    }
    if (res$visible) res$value else invisible(res$value)
  }
}

#' Cache function results
#'
#' Decorators that remember a function's results, keyed on the matched arguments
#' (including defaults).
#'
#' * `lru_cache()` evicts the least recently used entries when the cache is full.
#'   Port of Python's `functools.lru_cache`.
#' * `cache()` never evicts. Port of Python's `functools.cache`.
#' * `disk_cache()` stores results as files in `dir`, so they survive the R
#'   session and can be shared between sessions. Like `joblib.Memory.cache`.
#'
#' Entries are keyed on the function's formals and body as well as its arguments,
#' so editing the function invalidates them. Changes to anything it calls do not.
#' `disk_cache()` saves results with [saveRDS()], or with the qs2 package when
#' `format = "qs2"`, which is usually faster and smaller for large objects.
#' Neither round-trips environments or external pointers. Files from the two
#' formats are not shared, so changing `format` for an existing `dir` starts with
#' an empty cache.
#'
#' Set `TTL` on `lru_cache()` or `disk_cache()` to expire entries after a number
#' of seconds, for results that go stale (for example, data fetched from an API).
#'
#' Call `lru_cache(maxsize)` to build a decorator, then apply it with `%@%` or by
#' calling it on a function. `cache` takes no parameters, so it is applied
#' directly.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param maxsize Maximum cache size in bytes. Defaults to 1 GiB.
#' @param TTL Time to live in seconds. Entries older than this are treated as
#'   missing and recomputed on the next call. Defaults to `Inf`, so entries never
#'   expire. Not available for `cache()`, which never evicts.
#' @param format File format for `disk_cache()`: `"rds"` (the default) or `"qs2"`,
#'   which needs the qs2 package.
#' @param dir Directory for `disk_cache()` to keep its files in. It is created if
#'   needed. There is no default, so persistence is always a choice.
#' @return A decorator.
#' @examples
#' slow_square := lru_cache() %@% function(x) {
#'   Sys.sleep(0.1)
#'   x^2
#' }
#' slow_square(4) # slow
#' slow_square(4) # cached
#'
#' # Entries expire after 60 seconds
#' fresh_square := lru_cache(TTL = 60) %@% function(x) x^2
#'
#' slow_cube := cache %@% function(x) {
#'   Sys.sleep(0.1)
#'   x^3
#' }
#' slow_cube(2) # slow
#' slow_cube(2) # cached
#'
#' dir <- tempfile("cache")
#' slow_cube := disk_cache(dir) %@% function(x) {
#'   Sys.sleep(0.1)
#'   x^3
#' }
#' slow_cube(2) # slow, and saved to `dir`
#' slow_cube(2) # cached
#' @rdname lru_cache
#' @usage lru_cache(f, maxsize = 1024 * 1024^2, TTL = Inf)
#' @export
lru_cache := decorator(
  function(f, maxsize = 1024 * 1024^2, TTL = Inf) {
    fn <- decorator_context()$fn
    memoised(f, fn, cache_mem(max_size = maxsize, evict = "lru", max_age = TTL))
  }
)

#' @rdname lru_cache
#' @usage cache(f)
#' @export
cache := decorator(
  function(f) {
    fn <- decorator_context()$fn
    memoised(f, fn, cache_mem(max_size = Inf))
  }
)

#' @rdname lru_cache
#' @usage disk_cache(f, dir, maxsize = 1024 * 1024^2, TTL = Inf, format = c("rds", "qs2"))
#' @export
disk_cache := decorator(
  function(
    f,
    dir,
    maxsize = 1024 * 1024^2,
    TTL = Inf,
    format = c("rds", "qs2")
  ) {
    check_string(dir)
    format <- rlang::arg_match(format, c("rds", "qs2"))
    fn <- decorator_context()$fn
    cache <- new_disk_cache(dir, maxsize, TTL, format)
    memoised(f, fn, cache)
  }
)
