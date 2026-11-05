#' @importFrom adorn := decorator decorator_context
#' @include log_logger.R
NULL

#' Log the calls to a function
#'
#' Decorator that logs when a call starts, and when it finishes or fails. Each
#' event is written by `logger`, see [logger_base]. A failure is logged then
#' signalled again unchanged.
#'
#' The message holds the function's name, its arguments matched to the formals
#' and, once finished, the time taken. Arguments are evaluated before the start
#' is logged.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param logger A [logger][logger_base], such as [logger_message()]. See
#'   [extending_log] to use a logging package.
#' @param level A [log_levels()] giving the level of the start, finish and error
#'   events.
#' @param elapsed Include the time taken in the finish and error messages?
#' @param trace Include the calls leading to an error in the error message?
#'   Only the calls from `f` down to the failure are shown.
#' @return A decorator.
#' @examples
#' fn := log_call(logger = logger_message()) %@% function(a, b, c) a + b + c
#' fn(1, 2, 3)
#'
#' # Log failures as warnings
#' g := log_call(
#'   logger = logger_message(),
#'   level = log_levels(error = "warn")
#' ) %@% function(x) stop("boom")
#' try(g(1), silent = TRUE)
#' @export
log_call := decorator(
  function(
    f,
    logger = logger_base(),
    level = log_levels(),
    elapsed = TRUE,
    trace = FALSE
  ) {
    check_s7(logger, logger_base, "a logger")
    check_s7(level, log_levels, "a `log_levels()`")
    function(...) {
      fn <- decorator_context()$name
      args <- match_args(f, list(...))
      wrapper <- sys.nframe()
      start <- proc.time()[["elapsed"]]
      log_event(logger, level@start, "Started", fn, args)
      res <- withVisible(
        withCallingHandlers(
          f(...),
          error = function(err) {
            handler <- sys.nframe()
            log_event(
              logger,
              level@error,
              "Failed",
              fn,
              args,
              start = if (elapsed) start,
              error = err,
              trace = if (trace) trace_calls(fn, wrapper, handler)
            )
          }
        )
      )
      log_event(
        logger,
        level@finish,
        "Finished",
        fn,
        args,
        start = if (elapsed) start
      )
      if (res$visible) res$value else invisible(res$value)
    }
  }
)

# Build the message for an event and hand it to the logger, with the level
# translated to the logger's own label.
log_event <- function(
  logger,
  level,
  stage,
  fn,
  args,
  start = NULL,
  error = NULL,
  trace = NULL
) {
  parts <- c(stage, fn_args(fn, args))
  if (!is.null(start)) {
    parts <- c(
      parts,
      sprintf("Elapsed=%s", fmt_duration(proc.time()[["elapsed"]] - start))
    )
  }
  if (!is.null(error)) {
    parts <- c(parts, sprintf("\n%s", fmt_error(error, fn)))
  }
  if (length(trace)) {
    parts <- c(parts, paste0("\nTrace:\n", paste(trace, collapse = "\n")))
  }
  logger_fn(logger, prop(logger, level), paste(parts, collapse = " "))
}

# The calls from `f` down to the failure, one per line. Called from the error
# handler, `wrapper` and `handler` are the frames of the decorated function and the handler. Frames above `f`
# belong to the caller, and the trailing handler frames are dropped.
trace_calls <- function(fn, wrapper, handler) {
  calls <- sys.calls()
  end <- handler - 1L
  if (end > 0L && identical(calls[[end]][[1L]], quote(.handleSimpleError))) {
    end <- end - 1L
  }
  is_f <- vapply(calls, identical, logical(1), quote(f(...)))
  start <- which(is_f & seq_along(calls) > wrapper)[1L]
  if (is.na(start) || start > end) {
    return(character())
  }
  # adorn calls the original through `<holder>$fn(...)`, which deparses as
  # `<environment>$fn(...)`. Show it as `fn(...)` in place of the `f(...)` above it.
  if (start < end && is_holder_call(calls[[start + 1L]])) {
    start <- start + 1L
  }
  calls <- lapply(calls[start:end], name_holder_call, fn)
  shown <- vapply(calls, fmt_arg, character(1), width = 80L)
  sprintf("  %d. %s", seq_along(shown), shown)
}

# The error message, led by the call that failed as R does: "Error in `a + b`: ".
fmt_error <- function(error, fn) {
  msg <- conditionMessage(error)
  call <- conditionCall(error)
  if (is.null(call)) {
    return(msg)
  }
  sprintf("Error in `%s`:\n%s", fmt_arg(name_holder_call(call, fn)), msg)
}

name_holder_call <- function(cl, fn) {
  if (is_holder_call(cl)) {
    cl[[1L]] <- as.name(fn)
  }
  cl
}

is_holder_call <- function(cl) {
  is.call(cl) &&
    is.call(cl[[1L]]) &&
    identical(cl[[1L]][[1L]], quote(`$`)) &&
    is.environment(cl[[1L]][[2L]])
}

# Name the arguments by the formals they matched, where `f` allows it.
match_args <- function(f, args) {
  tryCatch(
    as.list(match.call(f, as.call(c(quote(f), args)), expand.dots = FALSE))[
      -1L
    ],
    error = function(e) args
  )
}

# The call as text, `fn(a=1,b=2)`.
fn_args <- function(fn, args) {
  values <- vapply(args, fmt_arg, character(1))
  names <- names(args) %||% rep("", length(args))
  shown <- ifelse(nzchar(names), paste0(names, "=", values), values)
  sprintf("%s(%s)", fn, paste(shown, collapse = ","))
}

fmt_arg <- function(x, width = 60L) {
  txt <- paste(deparse(x, width.cutoff = 500L), collapse = "")
  if (nchar(txt) > width) {
    txt <- paste0(substr(txt, 1L, width - 3L), "...")
  }
  txt
}
