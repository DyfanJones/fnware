#' @importFrom rlang hash
#' @importFrom cachem cache_disk
NULL

# Shared by the caching decorators and their `async_` versions.

# Builds the cache key from the function's body and the matched arguments,
# including defaults. `fn` is the function being decorated: inside a factory `f`
# is a stand-in whose body never changes, so hashing `f` would ignore edits to
# the real body. Get it from `decorator_context()$fn` in the factory itself, as
# it reads the call stack.
memo_key <- function(f, fn) {
  f_hash <- hash(list(formals(fn), as.character(body(fn))))
  defaults <- Filter(function(x) !identical(x, quote(expr = )), formals(f))
  function(...) {
    matched <- as.list(match.call(f, as.call(c(quote(f), list(...)))))[-1L]
    named <- matched[names(matched) %in% names(formals(f))]
    env <- list2env(named, parent = environment(f))
    missing_defaults <- defaults[setdiff(names(defaults), names(matched))]
    args <- c(matched, lapply(missing_defaults, eval, envir = env))
    hash(c(f_hash, args))
  }
}

# The cachem disk cache behind `disk_cache()` and `async_disk_cache()`.
new_disk_cache <- function(dir, maxsize, TTL, format) {
  switch(
    format,
    rds = cache_disk(dir, max_size = maxsize, max_age = TTL),
    qs2 = {
      rlang::check_installed("qs2", "to use `format = \"qs2\"`.")
      cache_disk(
        dir,
        max_size = maxsize,
        read_fn = qs2::qs_read,
        write_fn = qs2::qs_save,
        extension = ".qs2",
        max_age = TTL
      )
    }
  )
}
