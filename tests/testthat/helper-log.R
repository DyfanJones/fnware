logger_capture := S7::new_class(
  parent = logger_base,
  properties = list(env = S7::new_property(S7::class_any))
)
S7::method(logger_fn, logger_capture) <- function(class, level, msg, ...) {
  class@env$seen[[length(class@env$seen) + 1L]] <- list(
    level = level,
    msg = msg
  )
}
capture_logger <- function() {
  env <- new.env()
  env$seen <- list()
  list(logger = logger_capture(env = env), get = function() env$seen)
}
