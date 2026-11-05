#' @importFrom adorn := decorator
#' @include fallback.R async_utils.R
NULL

#' Return a default when an asynchronous function fails
#'
#' Asynchronous version of [fallback()]. The decorated function returns a
#' [promise][promises::promise] that resolves to `value` (or the result of
#' `handler`) if the wrapped function rejects or throws with a condition in
#' `class`. Other rejections carry on unchanged. Needs the promises package.
#'
#' @inheritParams fallback
#' @return A decorator. The decorated function returns a promise.
#' @examples
#' \dontrun{
#' f := async_fallback(value = "default") %@% function() stop("boom")
#' promises::then(f(), print)
#' while (!later::loop_empty()) later::run_now(0.05)
#' }
#' @rdname async_fallback
#' @usage async_fallback(f, value = NULL, handler = NULL, class = "error")
#' @export
async_fallback := decorator(
  function(f, value = NULL, handler = NULL, class = "error") {
    check_async("async_fallback", later = FALSE)
    check_function(handler, null = TRUE)
    check_classes(class)
    function(...) {
      promises::then(
        call_as_promise(f, ...),
        onRejected = function(cnd) {
          if (!inherits(cnd, class)) {
            stop(cnd)
          }
          if (is.null(handler)) value else handler(cnd)
        }
      )
    }
  }
)
