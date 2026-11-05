#' @importFrom rlang abort caller_arg caller_env
NULL

# Argument checks shared by the decorators. They run when the decorator is
# built, so a bad argument fails there rather than on the first call. `arg` and
# `call` default to the argument name and function the check was called from.

# `x` must be a single non-missing number, above `gt` or at least `ge`, and a
# whole number if `whole`. `Inf` is a number.
check_number <- function(
  x,
  gt = NULL,
  ge = NULL,
  whole = FALSE,
  arg = caller_arg(x),
  call = caller_env()
) {
  ok <- is.numeric(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    (is.null(gt) || x > gt) &&
    (is.null(ge) || x >= ge) &&
    (!whole || x == round(x))
  if (!ok) {
    what <- if (whole) "whole number" else "number"
    bound <- if (!is.null(gt)) {
      paste("greater than", gt)
    } else if (!is.null(ge)) {
      paste("of at least", ge)
    }
    abort(
      paste0(
        sprintf("`%s` must be a single %s", arg, what),
        if (!is.null(bound)) paste("", bound),
        "."
      ),
      call = call
    )
  }
  invisible(x)
}

# `x` must be a single non-missing string.
check_string <- function(x, arg = caller_arg(x), call = caller_env()) {
  if (!(is.character(x) && length(x) == 1L && !is.na(x))) {
    abort(sprintf("`%s` must be a single string.", arg), call = call)
  }
  invisible(x)
}

# `x` must be a function, or `NULL` if `null`.
check_function <- function(
  x,
  null = FALSE,
  arg = caller_arg(x),
  call = caller_env()
) {
  if (!(is.function(x) || (null && is.null(x)))) {
    abort(
      sprintf(
        "`%s` must be a function%s.",
        arg,
        if (null) " or `NULL`" else ""
      ),
      call = call
    )
  }
  invisible(x)
}

# `x` must be an S7 object that inherits from `class`; `what` names it in the
# message.
check_s7 <- function(
  x,
  class,
  what,
  arg = caller_arg(x),
  call = caller_env()
) {
  if (!S7_inherits(x, class)) {
    abort(sprintf("`%s` must be %s.", arg, what), call = call)
  }
  invisible(x)
}

# `x` must be a character vector of at least one non-missing string.
check_classes <- function(x, arg = caller_arg(x), call = caller_env()) {
  if (!(is.character(x) && length(x) >= 1L && !anyNA(x))) {
    abort(
      sprintf("`%s` must be a character vector of condition classes.", arg),
      call = call
    )
  }
  invisible(x)
}

# Whether `call` was written with a function name, as in `f(1)` or `pkg::f(1)`,
# rather than a function object.
is_named_call <- function(call) {
  if (!is.call(call)) {
    return(FALSE)
  }
  head <- call[[1L]]
  is.symbol(head) ||
    (is.call(head) &&
      is.symbol(head[[1L]]) &&
      as.character(head[[1L]]) %in% c("::", ":::"))
}


firstup <- function(x) {
  substr(x, 1, 1) <- toupper(substr(x, 1, 1))
  return(x)
}

fmt_duration <- function(secs) {
  h <- secs %/% 3600
  m <- (secs %% 3600) %/% 60
  s <- secs %% 60
  sprintf("%02d:%02d:%06.3f", h, m, s)
}
