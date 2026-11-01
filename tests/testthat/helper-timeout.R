# Wrap `fn(call, seconds)` in a throwaway timeout method class. Each class gets
# a unique name so S7 does not report an overwritten method.
make_timeout_method <- local({
  n <- 0L
  function(fn) {
    n <<- n + 1L
    cls <- S7::new_class(paste0("timeout_test_", n), parent = timeout_base)
    S7::method(timeout_fn, cls) <- function(class, call, seconds, ...) {
      fn(call, seconds)
    }
    cls()
  }
})
