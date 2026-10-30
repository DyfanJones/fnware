#' @importFrom adorn := decorator
#' @importFrom rlang hash
#' @importFrom cachem cache_mem
NULL

#' Cache function results
#'
#' Decorator that remembers a function's results, keyed on the matched arguments
#' (including defaults), and evicts the least recently used entries when full.
#'
#' Call `lru_cache(maxsize)` to build a decorator, then apply it with `%@%` or by
#' calling it on a function.
#'
#' @param maxsize Maximum cache size in bytes. Defaults to 1 GiB.
#' @return A decorator.
#' @examples
#' slow_square <- lru_cache() %@% function(x) {
#'   Sys.sleep(0.1)
#'   x^2
#' }
#' slow_square(4) # slow
#' slow_square(4) # cached
#' @rdname lru_cache
#' @usage NULL
#' @export
lru_cache := decorator(
  function(f, maxsize = 1024 * 1024^2) {
    f_hash <- hash(list(formals(f), as.character(body(f))))
    cache <- cache_mem(max_size = maxsize, evict = "lru")
    defaults <- Filter(function(x) !identical(x, quote(expr = )), formals(f))
    function(...) {
      matched <- as.list(match.call(f, as.call(c(quote(f), list(...)))))[-1L]
      named <- matched[names(matched) %in% names(formals(f))]
      env <- list2env(named, parent = environment(f))
      missing_defaults <- defaults[setdiff(names(defaults), names(matched))]
      args <- c(matched, lapply(missing_defaults, eval, envir = env))
      key <- hash(c(f_hash, args))
      res <- cache$get(key)
      if (inherits(res, "key_missing")) {
        res <- withVisible(f(...))
        cache$set(key, res)
      }
      if (res$visible) res$value else invisible(res$value)
    }
  }
)
