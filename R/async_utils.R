# Shared by the `async_` decorators.

# Fail early, with the decorator's name, if the packages a promise needs are
# missing. `later` is only needed by decorators that schedule work.
check_async <- function(name, later = TRUE, call = rlang::caller_env()) {
  rlang::check_installed(
    c("promises", if (later) "later"),
    sprintf("to use `%s()`.", name),
    call = call
  )
}

# Call `f(...)` and return a promise of its result. A plain value resolves, a
# promise is followed, and an error thrown before a promise is returned becomes
# a rejection, so callers only ever deal with promises.
call_as_promise <- function(f, ...) {
  tryCatch(
    promises::promise_resolve(f(...)),
    error = promises::promise_reject
  )
}
