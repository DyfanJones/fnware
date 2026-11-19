# Shared by `circuit_breaker()` and `async_circuit_breaker()`.

# The levels of the two events a circuit breaker logs, `open` and `close`.
circuit_levels <- function(level, call = caller_env()) {
  defaults <- c(open = "warn", close = "info")
  if (
    !is.character(level) ||
    (length(level) > 0L && is.null(names(level))) ||
    !all(names(level) %in% names(defaults))
  ) {
    abort(
      "`level` must be a named character vector with `open` and/or `close`.",
      call = call
    )
  }
  levels <- replace(defaults, names(level), level)
  check_level(levels, n = 2L, arg = "level", call = call)
  levels
}

# Log a change of state reported by `circuit_state()`.
log_circuit <- function(logger, levels, fn, changed, reset_after, err) {
  if (is.null(changed)) {
    return(invisible())
  }
  if (changed == "opened") {
    msg <- sprintf(
      "Circuit opened for %s, rejecting calls for %s seconds%s",
      fn,
      format(reset_after),
      if (is.null(err)) "" else sprintf("\n%s", fmt_error(err, fn))
    )
    log_event(logger, levels[["open"]], msg)
  } else {
    log_event(logger, levels[["close"]], sprintf("Circuit closed for %s", fn))
  }
}

circuit_open_cnd <- function() {
  rlang::error_cnd(
    "fnware_circuit_open",
    message = paste(
      "Circuit is open: the function failed repeatedly and is not being",
      "called."
    ),
    call = NULL
  )
}

# The closed / open / half-open state machine, shared by `circuit_breaker()` and
# `async_circuit_breaker()`. `enter()` returns a token when a call may go ahead
# and `NULL` when the circuit rejects it; the call then reports back with
# `succeed(token)` or `fail(token)`. They return `"closed"` or `"opened"` when
# the call changed the state, so the caller can log it, and `NULL` otherwise.
#
# A token records which "epoch" the call started in. The epoch moves on each time
# the circuit opens, so an asynchronous call that started before it opened and
# settles after it cannot close the circuit or be counted again. With
# `exclusive`, only one trial call runs while half-open, as concurrent calls are
# possible in async code. A trial that has not settled after `reset_after` is
# abandoned, so a promise that never settles cannot hold the circuit shut.
circuit_state <- function(failures, reset_after) {
  status <- "closed"
  count <- 0L
  opened_at <- NA_real_
  trial_at <- NA_real_
  epoch <- 0L
  now <- function() proc.time()[["elapsed"]]
  list(
    enter = function(exclusive = FALSE) {
      if (status == "open") {
        if (now() - opened_at < reset_after) {
          return(NULL)
        }
        status <<- "half_open"
        trial_at <<- NA_real_
      }
      if (status == "half_open" && exclusive) {
        if (!is.na(trial_at) && now() - trial_at < reset_after) {
          return(NULL)
        }
        trial_at <<- now()
      }
      epoch
    },
    succeed = function(token) {
      changed <- NULL
      if (token == epoch) {
        if (status != "closed") {
          changed <- "closed"
        }
        status <<- "closed"
        count <<- 0L
        trial_at <<- NA_real_
      }
      invisible(changed)
    },
    fail = function(token) {
      changed <- NULL
      if (token == epoch) {
        count <<- count + 1L
        if (status == "half_open" || count >= failures) {
          status <<- "open"
          opened_at <<- now()
          count <<- 0L
          trial_at <<- NA_real_
          epoch <<- epoch + 1L
          changed <- "opened"
        }
      }
      invisible(changed)
    }
  )
}
