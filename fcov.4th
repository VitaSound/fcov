\ fcov.4th — entry point for the fcov coverage tool.
\
\ fcov is a coverage collector for Forth source trees. It runs your
\ tests under instrumentation, then reports which `:`-defined words
\ were actually exercised (and, in a future release, which IF/ELSE
\ branches inside them).
\
\ As of 0.2.0, the run/report pipeline is real:
\
\   1. `fcov run [<test-cmd>]` walks the project tree (via fcov/walk),
\      tokenises every .4th file (fcov/scan), generates a per-process
\      instrumentation prelude (fcov/prelude) and a `.fcov/bin/gforth`
\      shim, then executes the user-supplied test command with
\      `.fcov/bin/` first on PATH so any subprocess that calls `gforth`
\      gets pre-loaded with the prelude. Per-process call shards land
\      in `.fcov/calls/<pid>.log`.
\
\   2. After the test command exits, fcov ingests the call shards,
\      writes `.fcov/coverage.json` (canonical) and prints a console
\      summary.
\
\   3. `fcov report [--format console|lcov]` re-walks the source tree,
\      re-ingests `.fcov/calls/`, and renders the requested format.
\
\ See doc/ROADMAP.md for branch-coverage plans (1.0.0+) and design
\ notes on the subprocess fan-out and prelude design.

require fcov/bootstrap.4th
require fcov/commands.4th

fcov-dispatch
0 (bye)
