#' @importFrom S7 := new_class new_property new_generic S7_dispatch class_any
#' @importFrom S7 class_function class_character prop prop<- method<-
NULL

LOG_LEVELS <- c("trace", "debug", "info", "warn", "error", "fatal")

#' Loggers
#'
#' [log_call()] hands each message to a logger. A logger is an S7 object that
#' inherits from `logger_base`, and `logger_fn()` decides how it is written.
#'
#' * `logger_base` is the base class. The default method prints
#'   `LEVEL [timestamp]: message` to the console.
#' * `logger_message` writes `[LEVEL] message` with [message()], so it can be
#'   silenced with [suppressMessages()].
#' * `logger_fn(class, level, msg, ...)` is the generic. Add a method to support
#'   any logging package, see [extending_log].
#'
#' @param class A logger. Methods are dispatched on this argument.
#' @param level The level label of the event, taken from the property of
#'   `class` named by the event's level, e.g. `class@info`.
#' @param msg The message, a string.
#' @param ... Passed to methods.
#' @param trace,debug,info,warn,error,fatal Labels passed to `logger_fn()` for
#'   each level. They default to `"TRACE"`, `"DEBUG"` and so on. Change them
#'   when the logging package names its levels differently, or uses objects.
#' @param logger An object a logging package needs to be passed, such as a
#'   log4r logger. Available to methods as `class@logger`.
#' @return `logger_fn()` returns nothing useful. The others return a logger.
#' @examples
#' logger_message()
#' f := log_call(logger = logger_message()) %@% function(x) x
#' f(1)
#' @rdname loggers
#' @export
logger_base := new_class(
  properties = list(
    trace = new_property(class_any, default = "TRACE"),
    debug = new_property(class_any, default = "DEBUG"),
    info = new_property(class_any, default = "INFO"),
    warn = new_property(class_any, default = "WARN"),
    error = new_property(class_any, default = "ERROR"),
    fatal = new_property(class_any, default = "FATAL"),
    logger = new_property(class_any, default = NULL)
  )
)

#' @rdname loggers
#' @export
logger_fn := new_generic("class", function(class, level, msg, ...) {
  S7_dispatch()
})

#' @rdname loggers
#' @export
logger_message := new_class(parent = logger_base)

method(logger_fn, logger_base) <- function(class, level, msg, ...) {
  now_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
  cat(sprintf("%s [%s]: %s", level, now_utc, msg), sep = "\n")
}

method(logger_fn, logger_message) <- function(class, level, msg, ...) {
  message(sprintf("[%s] %s", level, msg))
}

level_property <- function(name, default) {
  new_property(
    class_character,
    default = default,
    validator = function(value) {
      if (length(value) != 1L || !tolower(value) %in% LOG_LEVELS) {
        sprintf(
          "must be one of %s",
          paste0("'", LOG_LEVELS, "'", collapse = ", ")
        )
      }
    },
    setter = function(self, value) {
      prop(self, name) <- tolower(value)
      self
    }
  )
}

#' The level of each event [log_call()] logs
#'
#' @param start,finish,error The level of the event: one of `"trace"`,
#'   `"debug"`, `"info"`, `"warn"`, `"error"` or `"fatal"`.
#' @return An object to pass to the `level` argument of [log_call()].
#' @examples
#' log_levels(finish = "trace", error = "warn")
#' @export
log_levels := new_class(
  properties = list(
    start = level_property("start", "info"),
    finish = level_property("finish", "info"),
    error = level_property("error", "error")
  )
)
