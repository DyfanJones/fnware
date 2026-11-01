#' @importFrom adorn := decorator
#' @include retry_stop.R retry_wait.R retry_retry.R retry_before.R retry_after.R retry_utils.R
NULL

#' Retry a function without blocking
#'
#' Asynchronous version of [retry()]. It makes the same decisions with the same
#' [stop][stop_never], [wait][wait_fixed] and [retry][retry_all] strategies and
#' hooks, so any strategy, including your own ([extending_retry]), works with
#' both. The difference is how it waits: instead of sleeping, it schedules the
#' next attempt with [later::later()], so the R session can do other work
#' between attempts.
#'
#' The decorated function always returns a [promise][promises::promise]. It
#' resolves with the first acceptable result, and rejects with the last error,
#' or a `retry_error` condition, once `stop` fires, as [retry()] would signal.
#' The wrapped function may return a promise, such as from
#' `httr2::req_perform_promise()` or a [mirai][mirai::mirai] task, or a plain
#' value. A rejected promise counts as an error. An error thrown directly by the
#' function is treated the same way.
#'
#' The promise only settles while an event loop runs, which Shiny and plumber do
#' for you. In a script, run it with `later::run_now()`.
#'
#' Decorators that call a function synchronously do not wait for a promise.
#' Stack `async_retry()` as the outermost decorator, and put only decorators
#' that expect a promise inside it. [timeout()], for instance, cannot bound a
#' promise, so a `timeout()` beneath `async_retry()` would only bound the
#' moment the call is started.
#'
#' The `before_sleep` and `after_sleep` hooks and `retry_error_callback` run in
#' the event loop, so keep them quick.
#'
#' Needs the promises and later packages.
#'
#' @inheritParams retry
#' @return A decorator. The decorated function returns a promise.
#' @examples
#' if (
#'   requireNamespace("promises", quietly = TRUE) &&
#'     requireNamespace("later", quietly = TRUE)
#' ) {
#'   n <- 0
#'   flaky <- function() {
#'     n <<- n + 1
#'     if (n < 3) stop("not yet")
#'     n
#'   }
#'   f <- async_retry(stop = stop_after_attempt(5), wait = wait_fixed(0.05)) %@%
#'     flaky
#'   promises::then(f(), function(value) cat("worked on attempt", value, "\n"))
#'
#'   # The promise settles while the event loop runs, which Shiny does for you
#'   while (!later::loop_empty()) later::run_now(0.1)
#' }
#' @rdname async_retry
#' @usage async_retry(
#'   f,
#'   stop = stop_never(),
#'   wait = wait_none(),
#'   retry = retry_all(),
#'   before_sleep = before_sleep_none(),
#'   after_sleep = after_sleep_none(),
#'   reraise = FALSE,
#'   retry_error_callback = NULL
#' )
#' @export
async_retry := decorator(
  function(
    f,
    stop = stop_never(),
    wait = wait_none(),
    retry = retry_all(),
    before_sleep = before_sleep_none(),
    after_sleep = after_sleep_none(),
    reraise = FALSE,
    retry_error_callback = NULL
  ) {
    rlang::check_installed(
      c("promises", "later"),
      "to use `async_retry()`."
    )
    check_function(retry_error_callback, null = TRUE)
    cfg <- list(
      stop = stop,
      wait = wait,
      retry = retry,
      reraise = reraise,
      retry_error_callback = retry_error_callback
    )
    function(...) {
      start <- proc.time()[["elapsed"]]
      attempt <- 0L
      prev_wait <- NULL
      promises::promise(function(resolve, reject) {
        # An error in a strategy or hook rejects the promise rather than being
        # lost in the event loop.
        guard <- function(expr) tryCatch(expr, error = reject)

        run_attempt <- function() {
          attempt <<- attempt + 1L
          p <- tryCatch(
            promises::promise_resolve(f(...)),
            error = promises::promise_reject
          )
          promises::then(
            p,
            onFulfilled = function(value) {
              settle(list(value = value, error = NULL))
            },
            onRejected = function(err) {
              settle(list(value = NULL, error = as_condition(err)))
            }
          )
          invisible()
        }

        settle <- function(outcome) {
          guard({
            step <- retry_decide(outcome, attempt, prev_wait, start, cfg)
            if (step$action == "return") {
              resolve(step$value)
            } else if (step$action == "signal") {
              reject(step$error)
            } else {
              before_sleep_fn(before_sleep, step$state)
              later::later(
                function() {
                  guard({
                    after_sleep_fn(after_sleep, step$state)
                    prev_wait <<- step$wait
                    run_attempt()
                  })
                },
                delay = step$wait
              )
            }
          })
          invisible()
        }

        run_attempt()
      })
    }
  }
)

# A promise can reject with any value; strategies expect a condition.
as_condition <- function(x) {
  if (inherits(x, "condition")) {
    x
  } else {
    structure(
      class = c("simpleError", "error", "condition"),
      list(message = paste(format(x), collapse = " "), call = NULL)
    )
  }
}
