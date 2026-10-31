#' @importFrom adorn := decorator
#' @importFrom withr defer
NULL

#' Write setup and teardown once
#'
#' Port of Python's `contextlib.contextmanager`. R has no `yield`, so instead of
#' suspending the function the body calls `teardown()` right after acquiring each
#' resource and returns the resource. From that one definition you get:
#'
#' * a `local_` form: the function itself. Cleanup runs when the *calling*
#'   function exits, like `withr::local_*()`.
#' * a `with_` form: [with_context()] runs a block, then cleans up.
#' * a decorator: [as_decorator()] runs a function inside the context.
#'
#' The decorated function takes `...`, passed on to the setup function, and a
#' `.local_envir` argument naming the frame whose exit triggers cleanup. It
#' defaults to the caller, or, when called from another context manager's setup,
#' to that context's `.local_envir`, so composed contexts last as long as the
#' outer one.
#'
#' `teardown(expr)` registers `expr` with [withr::defer()] on that frame. Cleanups
#' run last in, first out, and the ones already registered still run if the rest
#' of the setup fails. `teardown()` finds the frame by searching the call stack
#' for the nearest running context manager and reading its `.local_envir`.
#'
#' @param expr Code that releases the resource. Evaluated in the setup function's
#'   environment when the context ends, so it can use the setup's local variables.
#' @return `contextmanager` is a decorator. `teardown()` is called for its side
#'   effect.
#' @seealso [with_context()], [as_decorator()]
#' @examples
#' local_tempdir := contextmanager %@% function(pattern = "tmp") {
#'   path <- tempfile(pattern)
#'   dir.create(path)
#'   teardown(unlink(path, recursive = TRUE))
#'   path
#' }
#'
#' f <- function() {
#'   d <- local_tempdir()
#'   writeLines("hi", file.path(d, "x.txt"))
#'   d
#' }
#' d <- f()
#' dir.exists(d) # cleaned up when f() exited
#' @rdname contextmanager
#' @usage NULL
#' @export
contextmanager := decorator(
  function(f) {
    wrapper <- function(..., .local_envir) {
      # The default is lazy: evaluate now, while parent.frame() is the caller.
      force(.local_envir)
      f(...)
    }
    # adorn evaluates replaced formals in the decorated function's environment,
    # which cannot see this package's internals, so embed the function itself.
    formals(wrapper)$.local_envir <- substitute(fn(parent.frame()), list(fn = context_envir))
    wrapper
  },
  formals = "replace"
)

#' @rdname contextmanager
#' @export
teardown <- function(expr) {
  envir <- enclosing_context(parent.frame())
  if (is.null(envir)) {
    abort("`teardown()` must be called from a `contextmanager()` function.", call = NULL)
  }
  defer(expr, envir = envir)
}

# Default for `.local_envir`: the caller, unless the caller is itself running a
# context manager's setup. Then the new context belongs to whoever owns that
# setup, so composed contexts live as long as the outer one.
context_envir <- function(caller) {
  enclosing_context(caller) %||% caller
}

# Walks the call stack outwards from `from` to the nearest context manager call
# and returns the frame that owns its cleanup, or NULL if there is none. The
# call stack is the context stack, so there is no global state to keep in sync.
enclosing_context <- function(from) {
  frames <- sys.frames()
  # `from` is not on the stack at top level, so nothing encloses it.
  at <- Position(function(frame) identical(frame, from), frames, right = TRUE,
                 nomatch = 0L)
  for (frame in rev(frames[seq_len(at)])) {
    if (exists(".local_envir", frame, inherits = FALSE)) {
      return(get(".local_envir", frame, inherits = FALSE))
    }
  }
  NULL
}

#' Run code inside a context
#'
#' The scoped form of a [contextmanager()]. Evaluates `ctx` with cleanup tied to
#' this call, passes the value it returns to `code`, and cleans up when `code`
#' finishes, even if it errors.
#'
#' @param ctx A call to a context manager, e.g. `local_tempdir()`. It is not
#'   evaluated in your frame: `.local_envir` is set to this function's frame.
#' @param code A function taking the context's value.
#' @return The value of `code`.
#' @examples
#' local_tempdir := contextmanager %@% function() {
#'   path <- tempfile()
#'   dir.create(path)
#'   teardown(unlink(path, recursive = TRUE))
#'   path
#' }
#' with_context(local_tempdir(), function(d) dir.exists(d))
#' @export
with_context <- function(ctx, code) {
  call <- substitute(ctx)
  call$.local_envir <- environment()
  value <- eval(call, parent.frame())
  code(value)
}

#' Use a context manager as a decorator
#'
#' Decorator form of a [contextmanager()]: the decorated function runs inside the
#' context, and cleanup runs when it returns or errors. As in Python's
#' `ContextDecorator`, the context's value is not passed to the function.
#'
#' @param ctx A context manager.
#' @param ... Arguments for `ctx`.
#' @return A decorator.
#' @examples
#' local_tempdir := contextmanager %@% function() {
#'   path <- tempfile()
#'   dir.create(path)
#'   teardown(unlink(path, recursive = TRUE))
#'   path
#' }
#' g := as_decorator(local_tempdir) %@% function() "ran inside context"
#' g()
#' @export
as_decorator <- function(ctx, ...) {
  args <- list(...)
  decorator(
    function(f, ...) {
      do.call(ctx, c(args, list(.local_envir = environment())))
      f(...)
    },
    name = "as_decorator"
  )
}
