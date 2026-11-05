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
    elapsed = TRUE
  ) {
    check_s7(logger, logger_base, "a logger")
    check_s7(level, log_levels, "a `log_levels()`")
    function(...) {
      fn <- decorator_context()$name
      args <- match_args(f, list(...))
      start <- proc.time()[["elapsed"]]
      log_event(logger, level@start, "Started", fn, args)
      outcome <- tryCatch(
        list(res = withVisible(f(...)), error = NULL),
        error = function(err) list(res = NULL, error = err)
      )
      if (!is.null(outcome$error)) {
        log_event(
          logger,
          level@error,
          "Failed",
          fn,
          args,
          start = if (elapsed) start,
          error = outcome$error
        )
        stop(outcome$error)
      }
      log_event(
        logger,
        level@finish,
        "Finished",
        fn,
        args,
        start = if (elapsed) start
      )
      if (outcome$res$visible) {
        outcome$res$value
      } else {
        invisible(outcome$res$value)
      }
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
  error = NULL
) {
  parts <- c(stage, fn_args(fn, args))
  if (!is.null(start)) {
    parts <- c(
      parts,
      sprintf("Elapsed=%s", fmt_duration(proc.time()[["elapsed"]] - start))
    )
  }
  if (!is.null(error)) {
    parts <- c(parts, sprintf("Error=%s", conditionMessage(error)))
  }
  logger_fn(logger, prop(logger, level), paste(parts, collapse = " "))
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
