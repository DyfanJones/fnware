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
