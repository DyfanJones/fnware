# Context managers

``` r

library(garnish)
```

Many resources come as a pair: something you acquire, and something you
must release even if the code in between fails. Temporary directories,
database connections, locks, changed options, open sinks. Python has
`with` and `@contextlib.contextmanager` for this. `contextmanager` is
the R version, and this vignette explains what it gives you over
[`on.exit()`](https://rdrr.io/r/base/on.exit.html) and
[withr](https://withr.r-lib.org), because the honest answer is “less
than you might hope, and more than it first looks”.

## The problem with `on.exit()`

[`on.exit()`](https://rdrr.io/r/base/on.exit.html) runs when the
function it is written in returns. That is exactly wrong for a helper
that acquires a resource for its caller:

``` r

make_tempdir <- function() {
  d <- tempfile()
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))
  d
}
dir.exists(make_tempdir())
```

    ## [1] FALSE

The directory is gone before the caller sees it. So the acquire and
release lines get copied into every function that needs the resource,
and forgetting the second one leaks.

## What withr already does

withr solves this with `defer()`, which attaches cleanup to another
function’s frame. The pattern is a `local_` function, whose cleanup runs
when the *calling* function exits, and often a `with_` twin for a scoped
block:

``` r

local_tempdir_withr <- function(.local_envir = parent.frame()) {
  d <- tempfile()
  dir.create(d)
  withr::defer(unlink(d, recursive = TRUE), envir = .local_envir)
  d
}

f <- function() {
  d <- local_tempdir_withr()
  dir.exists(d)
}
c(inside = f())
```

    ## inside 
    ##   TRUE

`.local_envir = parent.frame()` is the whole trick. A default argument
is evaluated in the function it belongs to, so
[`parent.frame()`](https://rdrr.io/r/base/sys.parent.html) there means
“the function that called me”. Pass that frame to `defer()` and the
cleanup waits for the caller.

If this is all you need, use withr. `contextmanager` is built on
`defer()`.

## What `contextmanager` adds

You write the setup once, calling
[`teardown()`](https://dyfanjones.github.io/garnish/reference/contextmanager.md)
straight after each acquire, and return the resource. R has no `yield`,
so this is the closest equivalent:

``` r

local_tempdir := contextmanager %@% function(pattern = "tmp") {
  path <- tempfile(pattern)
  dir.create(path)
  teardown(unlink(path, recursive = TRUE))
  path
}
```

That single definition works three ways. Called inside a function, it
cleans up when that function exits:

``` r

f <- function() {
  d <- local_tempdir()
  writeLines("hi", file.path(d, "x.txt"))
  d
}
d <- f()
dir.exists(d)
```

    ## [1] FALSE

[`with_context()`](https://dyfanjones.github.io/garnish/reference/with_context.md)
scopes it to a block and hands the value to a function:

``` r

with_context(local_tempdir(), function(d) list.files(d))
```

    ## character(0)

[`as_decorator()`](https://dyfanjones.github.io/garnish/reference/as_decorator.md)
runs a whole function inside the context:

``` r

g := as_decorator(local_tempdir) %@% function() "ran inside the context"
g()
```

    ## [1] "ran inside the context"

None of those is hard to write by hand for one resource. The advantage
appears when there are several.

## A worked comparison

Take a fake database API with a connection, and a scratch table that
only makes sense on a connection. We want to be able to use the scratch
table in all three ways.

``` r

connect <- function(name) {
  cat("  connect", name, "\n")
  list(name = name)
}
disconnect <- function(con) cat("  disconnect", con$name, "\n")
create_table <- function(con, t) cat("  create", t, "\n")
drop_table <- function(con, t) cat("  drop", t, "\n")
```

### With withr, by hand

``` r

local_con <- function(name, .local_envir = parent.frame()) {
  con <- connect(name)
  withr::defer(disconnect(con), envir = .local_envir)
  con
}

local_scratch <- function(name, .local_envir = parent.frame()) {
  con <- local_con(name, .local_envir)
  create_table(con, "scratch")
  withr::defer(drop_table(con, "scratch"), envir = .local_envir)
  con
}

# The scoped form is a second copy of the same logic.
with_scratch <- function(name, code) {
  con <- connect(name)
  on.exit(disconnect(con))
  create_table(con, "scratch")
  on.exit(drop_table(con, "scratch"), add = TRUE, after = FALSE)
  code(con)
}
```

Things to get right: pass `.local_envir` on to the inner helper, or the
connection closes as soon as `local_scratch()` returns. Write
`after = FALSE`, or the connection closes before the table is dropped.
And keep the `local_` and `with_` versions in step as the setup changes.

``` r

f <- function() {
  con <- local_scratch("db")
  cat("  using", con$name, "\n")
}
f()
```

    ##   connect db 
    ##   create scratch 
    ##   using db 
    ##   drop scratch 
    ##   disconnect db

### With `contextmanager`

``` r

local_con2 := contextmanager %@% function(name) {
  con <- connect(name)
  teardown(disconnect(con))
  con
}

local_scratch2 := contextmanager %@% function(name) {
  con <- local_con2(name)
  create_table(con, "scratch")
  teardown(drop_table(con, "scratch"))
  con
}
```

The same output, from half the code:

``` r

f2 <- function() {
  con <- local_scratch2("db")
  cat("  using", con$name, "\n")
}
f2()
```

    ##   connect db 
    ##   create scratch 
    ##   using db 
    ##   drop scratch 
    ##   disconnect db

And the other two forms come from the same definition:

``` r

with_context(local_scratch2("db"), function(con) cat("  using", con$name, "\n"))
```

    ##   connect db 
    ##   create scratch 
    ##   using db 
    ##   drop scratch 
    ##   disconnect db

``` r

job := as_decorator(local_scratch2, "db") %@% function() cat("  running job\n")
job()
```

    ##   connect db 
    ##   create scratch 
    ##   running job
    ##   drop scratch 
    ##   disconnect db

What did the work:

- **Cleanups run last in, first out.** You never write `after = FALSE`.
- **Nesting is handled.** `local_con2()` called from inside another
  context’s setup is cleaned up with the outer context, not when the
  outer setup returns. You don’t pass `.local_envir` along.
- **Setup and teardown are one function.** `con` is an ordinary local
  variable that
  [`teardown()`](https://dyfanjones.github.io/garnish/reference/contextmanager.md)
  can see. withr’s own generators,
  [`withr::with_()`](https://withr.r-lib.org/reference/with_.html) and
  [`withr::local_()`](https://withr.r-lib.org/reference/with_.html),
  take `set` and `reset` as two separate functions, so anything shared
  between them has to be passed through the old value.
- **One definition, three forms.** There is nothing to drift apart.

## When not to use it

- **A single [`on.exit()`](https://rdrr.io/r/base/on.exit.html) in a
  single function.** Keep
  [`on.exit()`](https://rdrr.io/r/base/on.exit.html).
- **You only need the `local_` form.** Writing
  `defer(..., envir = .local_envir)` yourself is about as short, and
  depends on one fewer thing.
- **You want the code to be lazy.** `withr::with_x(value, code)` takes
  the code itself.
  [`with_context()`](https://dyfanjones.github.io/garnish/reference/with_context.md)
  takes a function, which is a little clumsier.

The best fit is a package with several acquire/release helpers, some
built on others, where callers want more than one style.

## Behaviour worth knowing

**If setup fails halfway, what was registered still runs.**

``` r

local_partial := contextmanager %@% function() {
  teardown(cat("  released the first thing\n"))
  stop("second step failed")
}
try(with_context(local_partial(), identity), silent = TRUE)
```

    ##   released the first thing

The cleanup runs when the caller exits. If the caller catches the error
itself with [`tryCatch()`](https://rdrr.io/r/base/conditions.html) and
carries on, cleanup waits until that function returns.

**There is no way to see the error in a teardown.** Python’s generator
can catch an exception at the `yield`. `defer()` cannot, so a context
cannot choose to commit on success and roll back on failure. Handle that
in the code that calls the context, with
[`tryCatch()`](https://rdrr.io/r/base/conditions.html).

**Why not a generator?** `coro::generator()` has a real `yield`, which
makes it tempting. But `coro` does not support `tryCatch(finally = )`
around a `yield`, so a generator cannot guarantee its teardown runs.
[`teardown()`](https://dyfanjones.github.io/garnish/reference/contextmanager.md)
needs nothing but `defer()`.

**Top level.** Calling a context at the console works. Cleanup is run by
withr when the session ends.

## How it works

`contextmanager` replaces the function’s signature with
`function(..., .local_envir = <caller>)` and forwards `...` to your
setup. When you call `teardown(expr)`, it searches the call stack for
the nearest running context manager, reads that call’s `.local_envir`,
and hands the expression to
[`withr::defer()`](https://withr.r-lib.org/reference/defer.html) for
that frame. Because the call stack is the record of which contexts are
running, there is no global state to keep in step.
