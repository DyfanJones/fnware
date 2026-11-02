#' @importFrom adorn := decorator decorator_context
#' @importFrom cachem cache_mem
#' @include cache_utils.R async_utils.R
NULL

# Shared body of the asynchronous caching decorators. Only settled values are
# cached, never promises, so a rejection is not remembered and the cache can be
# written to disk. Calls with the same arguments made while one is still
# running share its promise instead of starting another. Entries use the same
# shape as `memoised()`, so both kinds of cache can read each other's files.
memoised_async <- function(f, fn, cache) {
  key_of <- memo_key(f, fn)
  running <- new.env(parent = emptyenv())
  function(...) {
    key <- key_of(...)
    res <- cache$get(key)
    if (!inherits(res, "key_missing")) {
      return(promises::promise_resolve(res$value))
    }
    if (!is.null(running[[key]])) {
      return(running[[key]])
    }
    p <- promises::then(
      call_as_promise(f, ...),
      onFulfilled = function(value) {
        rm(list = key, envir = running)
        cache$set(key, list(value = value, visible = TRUE))
        value
      },
      onRejected = function(err) {
        rm(list = key, envir = running)
        promises::promise_reject(err)
      }
    )
    running[[key]] <- p
    p
  }
}

#' Cache the results of asynchronous functions
#'
#' Asynchronous versions of [lru_cache()], [cache()] and [disk_cache()], for
#' functions that return a [promise][promises::promise]. They take the same
#' arguments and keys, and the decorated function always returns a promise. The
#' wrapped function may return a promise or a plain value.
#'
#' * The resolved value is cached, not the promise, so a rejection is not cached
#'   and the next call tries again.
#' * Identical calls made while one is running share its promise, so a burst of
#'   the same request makes one call.
#' * Because only values are stored, `async_disk_cache()` works, and it shares
#'   files with [disk_cache()] for the same function.
#'
#' Needs the promises package and an event loop.
#'
#' @inheritParams lru_cache
#' @return A decorator. The decorated function returns a promise.
#' @examples
#' \dontrun{
#' calls <- 0
#' request := async_lru_cache() %@% function(id) {
#'   calls <<- calls + 1
#'   promises::promise(function(resolve, reject) {
#'     later::later(function() resolve(id * 2), 0.05)
#'   })
#' }
#' # Three identical calls at once make one request
#' for (i in 1:3) promises::then(request(21), function(value) cat(value, "\n"))
#' while (!later::loop_empty()) later::run_now(0.05)
#' calls
#'
#' # Results survive the session on disk
#' f := async_disk_cache(tempfile()) %@% function(x) x^2
#' }
#' @rdname async_lru_cache
#' @usage async_lru_cache(f, maxsize = 1024 * 1024^2, TTL = Inf)
#' @export
async_lru_cache := decorator(
  function(f, maxsize = 1024 * 1024^2, TTL = Inf) {
    check_async("async_lru_cache", later = FALSE)
    fn <- decorator_context()$fn
    memoised_async(
      f,
      fn,
      cache_mem(max_size = maxsize, evict = "lru", max_age = TTL)
    )
  }
)

#' @rdname async_lru_cache
#' @usage async_cache(f)
#' @export
async_cache := decorator(
  function(f) {
    check_async("async_cache", later = FALSE)
    fn <- decorator_context()$fn
    memoised_async(f, fn, cache_mem(max_size = Inf))
  }
)

#' @rdname async_lru_cache
#' @usage async_disk_cache(f, dir, maxsize = 1024 * 1024^2, TTL = Inf, format = c("rds", "qs2"))
#' @export
async_disk_cache := decorator(
  function(
    f,
    dir,
    maxsize = 1024 * 1024^2,
    TTL = Inf,
    format = c("rds", "qs2")
  ) {
    check_async("async_disk_cache", later = FALSE)
    check_string(dir)
    format <- rlang::arg_match(format, c("rds", "qs2"))
    fn <- decorator_context()$fn
    memoised_async(f, fn, new_disk_cache(dir, maxsize, TTL, format))
  }
)
