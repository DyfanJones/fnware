#' @include retry_utils.R

#' @rdname extending_retry
#' @export
retry_base := new_class(abstract = TRUE)

# `outcome` is list(value, error) for the attempt that just finished: `error`
# is NULL when the call succeeded, otherwise `value` is NULL.
#' @rdname extending_retry
#' @export
retry_fn := new_generic("class", function(class, outcome, ...) {
  S7_dispatch()
})

#' Retry conditions
#'
#' Decide whether [retry()] tries again after an attempt.
#'
#' * `retry_all()` retries on any error.
#' * `retry_never()` never retries, so the first error is re-thrown.
#' * `retry_if_error()` retries on errors inheriting from any of `classes`.
#' * `retry_if_error_message()` retries when the error message equals `message`, or
#'   matches the regular expression `match`. Supply exactly one.
#' * `retry_if_result()` retries when the call succeeds but `predicate(value)` is `TRUE`.
#'
#' @param classes Condition classes to retry on.
#' @param message Error message to match exactly.
#' @param match Regular expression to match against the error message.
#' @param predicate Function taking the returned value and returning `TRUE` to retry.
#' @return A retry condition to pass to [retry()].
#' @examples
#' retry_if_error("http_error")
#' retry_if_error_message(match = "timed? ?out")
#' retry_if_result(is.null)
#' @rdname retry_conditions
#' @export
retry_all := new_class(parent = retry_base)

#' @rdname retry_conditions
#' @export
retry_never := new_class(parent = retry_base)

#' @rdname retry_conditions
#' @export
retry_if_error := new_class(
  parent = retry_base,
  properties = list(classes = class_character),
  constructor = function(classes = "error") {
    new_object(retry_base(), classes = classes)
  }
)

#' @rdname retry_conditions
#' @export
retry_if_error_message := new_class(
  parent = retry_base,
  properties = list(
    message = NULL | class_character,
    match = NULL | class_character
  ),
  constructor = function(message = NULL, match = NULL) {
    if (is.null(message) == is.null(match)) {
      base::stop("Exactly one of `message` or `match` must be supplied.")
    }
    new_object(retry_base(), message = message, match = match)
  }
)

#' @rdname retry_conditions
#' @export
retry_if_result := new_class(
  parent = retry_base,
  properties = list(predicate = class_function),
  constructor = function(predicate) {
    new_object(retry_base(), predicate = predicate)
  }
)

method(retry_fn, retry_all) <- function(class, outcome, ...) {
  !is.null(outcome$error)
}

method(retry_fn, retry_never) <- function(class, outcome, ...) {
  FALSE
}

method(retry_fn, retry_if_error) <- function(class, outcome, ...) {
  !is.null(outcome$error) && inherits(outcome$error, class@classes)
}

method(retry_fn, retry_if_error_message) <- function(class, outcome, ...) {
  if (is.null(outcome$error)) {
    return(FALSE)
  }
  msg <- conditionMessage(outcome$error)
  if (!is.null(class@message)) {
    msg %in% class@message
  } else {
    any(vapply(class@match, grepl, logical(1), x = msg))
  }
}

method(retry_fn, retry_if_result) <- function(class, outcome, ...) {
  is.null(outcome$error) && isTRUE(class@predicate(outcome$value))
}
