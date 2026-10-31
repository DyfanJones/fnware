#' @importFrom adorn decorator
#' @importFrom rlang abort as_function
NULL

#' Validate arguments and return values
#'
#' Decorators that check a function's inputs or output against validators you
#' supply. A validator is any function (or [rlang::as_function()] formula) that
#' takes the value, so base predicates, lambdas and the `check_*()` functions of
#' packages like checkmate all work, with no dependency on any of them.
#'
#' A validator passes if it returns exactly `TRUE`. It fails if it returns
#' anything else:
#'
#' * a string, which becomes the failure message (the `check_*()` convention),
#' * `FALSE` or any other value, which gives a generic message.
#'
#' If a validator signals an error, that error propagates unchanged, so
#' `assert_*()` style functions work too.
#'
#' `validate_args()` checks the effective value of each named argument, so
#' defaults are validated too. Checking forces the argument, so a validated
#' argument is evaluated at call time rather than lazily. All failures are reported in one error of
#' class `garnish_validation_error`. Validator names are checked against the
#' function's formals when it is decorated, so a typo fails early.
#'
#' @param ... For `validate_args()`, named validators, one per argument.
#' @param validator For `validate_return()`, a validator for the returned value.
#' @return A decorator.
#' @examples
#' f <- validate_args(x = is.numeric, n = ~ .x > 0) %@% function(x, n = 1) x * n
#' f(2, 3)
#' try(f("a", -1))
#'
#' # check_*() style validators return a message on failure
#' check_string <- function(x) if (is.character(x) && length(x) == 1) TRUE else "must be a string"
#' g <- validate_args(name = check_string) %@% function(name) name
#' try(g(1))
#'
#' h <- validate_return(is.character) %@% function() 1
#' try(h())
#' @export
validate_args <- function(...) {
  validators <- list(...)
  nms <- names(validators)
  if (length(validators) && (is.null(nms) || anyNA(nms) || !all(nzchar(nms)))) {
    abort("All validators passed to `validate_args()` must be named.")
  }
  if (anyDuplicated(nms)) {
    abort("Validator names passed to `validate_args()` must be unique.")
  }
  validators <- lapply(validators, as_function, arg = "validator")

  decorator(
    function(f) {
      unknown <- setdiff(nms, names(formals(f)))
      if (length(unknown)) {
        abort(sprintf(
          "`validate_args()` names not in the function's arguments: %s.",
          paste0("`", unknown, "`", collapse = ", ")
        ))
      }
      function(...) {
        # Match on positions in `...` so only validated arguments are forced.
        idx <- as.list(match.call(f, as.call(c(quote(f), as.list(seq_len(...length()))))))[-1L]
        failures <- character()
        for (nm in intersect(nms, names(idx))) {
          msg <- validation_failure(validators[[nm]], ...elt(idx[[nm]]))
          if (!is.null(msg)) {
            failures <- c(failures, sprintf("`%s`: %s", nm, msg))
          }
        }
        if (length(failures)) {
          abort(
            c("Invalid arguments.", stats::setNames(failures, rep("x", length(failures)))),
            class = "garnish_validation_error",
            call = NULL
          )
        }
        f(...)
      }
    },
    name = "validate_args"
  )
}

#' @rdname validate_args
#' @export
validate_return <- function(validator) {
  validator <- as_function(validator, arg = "validator")
  decorator(
    function(f) {
      function(...) {
        res <- withVisible(f(...))
        msg <- validation_failure(validator, res$value)
        if (!is.null(msg)) {
          abort(
            c("Invalid return value.", x = msg),
            class = "garnish_validation_error",
            call = NULL
          )
        }
        if (res$visible) res$value else invisible(res$value)
      }
    },
    name = "validate_return"
  )
}

# NULL if `value` passes `validator`, otherwise the failure message.
validation_failure <- function(validator, value) {
  res <- validator(value)
  if (isTRUE(res)) {
    return(NULL)
  }
  if (is.character(res) && length(res) >= 1L) {
    return(paste(res, collapse = "; "))
  }
  "failed validation."
}
