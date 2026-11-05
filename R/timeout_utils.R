# Shared by `timeout()` and `async_timeout()`.

timeout_message <- function(name, limit, enclosing = FALSE) {
  msg <- sprintf(
    "`%s` timed out: it did not finish within %s second%s.",
    name,
    format(limit),
    if (identical(limit, 1)) "" else "s"
  )
  if (enclosing) {
    msg <- paste(msg, "(cut short by an enclosing timeout)")
  }
  msg
}

# The finished `fnware_timeout_error`, marked so an enclosing `timeout()` passes
# it on unchanged instead of rebuilding it.
timeout_cnd <- function(name, limit, enclosing = FALSE) {
  rlang::error_cnd(
    "fnware_timeout_error",
    message = timeout_message(name, limit, enclosing),
    limit = limit,
    fn = name,
    finalised = TRUE,
    call = NULL
  )
}
