#' @importFrom adorn := decorator
NULL

#' Run a function only once
#'
#' Decorator that runs the function on its first successful call and returns
#' that result on every call after it, ignoring later arguments. An error stores
#' nothing, so the next call tries again. Unlike [cache], it keeps one result
#' whatever the arguments.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @return A decorator.
#' @examples
#' setup := once %@% function() {
#'   cat("setting up\n")
#'   42
#' }
#' setup()
#' setup() # no output, same result
#' @rdname once
#' @usage once(f)
#' @export
once := decorator(
  function(f) {
    done <- FALSE
    result <- NULL
    function(...) {
      if (!done) {
        result <<- f(...)
        done <<- TRUE
      }
      result
    }
  }
)
