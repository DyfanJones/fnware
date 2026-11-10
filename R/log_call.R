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
#' When a call fails, the calls from `f` down to the failure are logged as a
#' separate `trace` event after the error. Whether it is shown is up to the
#' logger: the built-in loggers hide it until `threshold = "trace"`, see
#' [logger_base].
#'
#' For a function that returns a promise, use [async_log_call()]. Here the finish
#' would be logged when the promise is returned, not when it settles.
#'
#' @param f The function to decorate. Usually supplied by `%@%` rather than directly.
#' @param logger A [logger][logger_base], such as [logger_message()]. See
#'   [extending_log] to use a logging package.
#' @param level A [log_levels()] giving the level of the start, finish and error
#'   events.
#' @param elapsed Include the time taken in the finish message?
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
      args <- match_args(f, dots_present(...))
      call_text <- fn_args(fn, args)
      wrapper <- sys.nframe()
      start <- proc.time()[["elapsed"]]
      logger_fn(
        logger,
        prop(logger, level@start),
        paste(c("Start", call_text), collapse = " ")
      )
      res <- withVisible(
        withCallingHandlers(
          f(...),
          error = function(err) {
            handler <- sys.nframe()
            parts <- c(call_text, sprintf("\n%s", fmt_error(err, fn)))
            logger_fn(
              logger,
              prop(logger, level@error),
              paste(parts, collapse = " ")
            )
            trace <- trace_calls(fn, wrapper, handler)
            if (length(trace)) {
              logger_fn(
                logger,
                prop(logger, "trace"),
                paste(
                  c(
                    call_text,
                    paste0("\n", paste(trace, collapse = "\n"))
                  ),
                  collapse = " "
                )
              )
            }
          }
        )
      )
      parts <- c("Finished", call_text, elapse_msg(elapsed, start))
      logger_fn(
        logger,
        prop(logger, level@finish),
        paste(parts, collapse = " ")
      )
      if (res$visible) res$value else invisible(res$value)
    }
  }
)

elapse_msg <- function(elapsed, start) {
  if (elapsed) {
    sprintf("Elapsed=%s", fmt_duration(proc.time()[["elapsed"]] - start))
  }
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

# The arguments in `...` as a list, leaving out any that are missing. A wrapper
# that mirrors the formals of `f` forwards an unsupplied argument as a promise to
# a missing one, and forcing it with `list(...)` would fail.
dots_present <- function(...) {
  n <- ...length()
  keep <- logical(n)
  for (i in seq_len(n)) {
    keep[i] <- !eval(substitute(missing(x), list(x = as.name(paste0("..", i)))))
  }
  args <- list()
  nms <- ...names() %||% rep("", n)
  for (i in which(keep)) {
    args[[length(args) + 1L]] <- ...elt(i)
    names(args)[length(args)] <- nms[i]
  }
  args
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
