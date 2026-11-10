#' @importFrom adorn := decorator decorator_context
#' @include log_call.R async_utils.R
NULL

#' Log the calls to an asynchronous function
#'
#' Asynchronous version of [log_call()], for functions that return a
#' [promise][promises::promise]. It logs the start when the function is called,
#' and the finish or the failure when the promise settles, with the time taken
#' up to that point. A rejection is logged then passed on unchanged. Needs the
#' promises package.
#'
#' It logs no `trace` event, as the calls that led to a rejection are no longer
#' on the stack by the time it settles.
#'
#' @inheritParams log_call
#' @return A decorator. The decorated function returns a promise.
#' @examples
#' \dontrun{
#' fn := async_log_call(logger = logger_message()) %@%
#'   function(x) promises::promise_resolve(x)
#' promises::then(fn(1), print)
#' while (!later::loop_empty()) later::run_now(0.05)
#' }
#' @rdname async_log_call
#' @usage async_log_call(f, logger = logger_base(), level = log_levels(), elapsed = TRUE)
#' @export
async_log_call := decorator(
  function(
    f,
    logger = logger_base(),
    level = log_levels(),
    elapsed = TRUE
  ) {
    check_async("async_log_call", later = FALSE)
    check_s7(logger, logger_base, "a logger")
    check_s7(level, log_levels, "a `log_levels()`")
    function(...) {
      fn <- decorator_context()$name
      args <- match_args(f, dots_present(...))
      call_text <- fn_args(fn, args)
      start <- proc.time()[["elapsed"]]
      logger_fn(
        logger,
        prop(logger, level@start),
        paste(c("Start", call_text), collapse = " ")
      )
      promises::then(
        call_as_promise(f, ...),
        onFulfilled = function(value) {
          logger_fn(
            logger,
            prop(logger, level@finish),
            paste(
              c("Finished", call_text, elapse_msg(elapsed, start)),
              collapse = " "
            )
          )
          value
        },
        onRejected = function(err) {
          logger_fn(
            logger,
            prop(logger, level@error),
            paste(
              c(
                "Error",
                call_text,
                sprintf("\n%s", fmt_error(as_condition(err), fn))
              ),
              collapse = " "
            )
          )
          promises::promise_reject(err)
        }
      )
    }
  }
)
