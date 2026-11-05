# Run the event loop until `p` settles, then return how it settled. Fails the
# test instead of hanging if it never does.
settle_promise <- function(p, timeout = 5) {
  out <- new.env()
  out$done <- FALSE
  promises::then(
    p,
    onFulfilled = function(value) {
      out$value <- value
      out$done <- TRUE
    },
    onRejected = function(error) {
      out$error <- error
      out$done <- TRUE
    }
  )
  t0 <- proc.time()[["elapsed"]]
  while (!out$done && proc.time()[["elapsed"]] - t0 < timeout) {
    later::run_now(0.01)
  }
  if (!out$done) {
    stop("promise did not settle within ", timeout, " seconds", call. = FALSE)
  }
  as.list(out)
}

# Run the event loop until nothing is scheduled, or `timeout` seconds pass.
drain_loop <- function(timeout = 5) {
  t0 <- proc.time()[["elapsed"]]
  while (!later::loop_empty() && proc.time()[["elapsed"]] - t0 < timeout) {
    later::run_now(0.05)
  }
  later::loop_empty()
}

# A promise that resolves with `value` after `delay` seconds.
delayed <- function(value, delay) {
  promises::promise(function(resolve, reject) {
    later::later(function() resolve(value), delay)
  })
}

# A promise that rejects with an error after `delay` seconds.
delayed_error <- function(message, delay = 0) {
  promises::promise(function(resolve, reject) {
    later::later(function() reject(simpleError(message)), delay)
  })
}

# Settle `p` and return its value, or signal its rejection as an error.
settle_value <- function(p) {
  out <- settle_promise(p)
  if (!is.null(out$error)) {
    stop(out$error)
  }
  out$value
}
