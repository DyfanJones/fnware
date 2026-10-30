#' @importFrom adorn := decorator

#' @include wait.R

#' @export
retry := decorator(
  function(
    f,
    stop = stop_never(),
    wait = wait_none(),
    retry = retry_all(),
    before = before_sleep_log(),
    after_sleep = after_sleep_log()
  ) {
    function(...) {
      while (TRUE) {
        tryCatch(return(f(...)), error = function(err) {
          stop_fn(stop, error)
          wait_fn(wait, attempt)
        })
      }
    }
  }
)

# Pseudo code to understand tenacity logic.
stop	stop_never	Retries forever
wait	wait_none()	No delay between attempts (a tight loop)
retry	retry_if_exception_type()	Retries on any Exception (not BaseException, so Ctrl-C still works)
reraise	False	On final failure, raises RetryError wrapping the last exception, not the original
retry_error_cls	RetryError	The class used for that wrapper
retry_error_callback	None	Nothing is called instead of raising when retries run out
before / after	before_nothing / after_nothing	No hooks before or after an attempt
before_sleep	None	No logging between attempts
sleep	time.sleep	Swap this out for tests



@retry(
    stop=stop_after_attempt(5) | stop_after_delay(60),   # whichever comes first
    wait=wait_exponential_jitter(initial=1, max=30),      # 1s, 2s, 4s… with jitter
    retry=retry_if_exception_type((TimeoutError, ConnectionError)),
    before_sleep=before_sleep_log(log, logging.WARNING),                                # surface the real exception
)





import time, random, logging

log = logging.getLogger(__name__)

def call_with_retry(func):
    attempt = 0
    start = time.monotonic()

    while True:
        attempt += 1
        try:
            return func()                                   # exit 1: success

        except (TimeoutError, ConnectionError) as err:      # retry filter
            elapsed = time.monotonic() - start
            if attempt >= 5 or elapsed >= 60:               # stop rule
                raise                                       # exit 2: real error

            delay = min(1 * 2 ** (attempt - 1) + random.uniform(0, 1), 30)
            log.warning("Retrying in %.1fs after %r", delay, err)
            time.sleep(delay)
        # any other exception isn't caught, so it escapes immediately

