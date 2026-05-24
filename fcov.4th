\ fcov.4th — entry point for the fcov coverage tool.
\
\ fcov is a coverage collector for Forth source trees. It runs your
\ tests under instrumentation, then reports which `:`-defined words
\ were actually exercised (and, in a future release, which IF/ELSE
\ branches inside them).
\
\ 0.1.0 is a SCAFFOLD release: the CLI surface, package.4th /
\ fsemver-pinning wiring, launcher, tests, docs and release process
\ are all in place; the coverage logic itself is a placeholder.
\ See doc/ROADMAP.md for the full implementation plan (branch coverage
\ via redefined `:` + control-flow words, multi-format reports).
\
\ Usage (post-0.1.0 target shape):
\   fcov run [<test-cmd>]   — run tests under instrumentation
\                             (default: `fmix test`)
\   fcov report [--format console|lcov|json|html]
\                           — print coverage report from last run
\   fcov clean              — remove .fcov/ artefacts
\   fcov version            — print fcov version
\   fcov help               — this help
\
\ All commands are command-line only; no interactive mode.

require fcov/util.4th

\ --- Self-version (read from package.4th) ---------------------------------

2variable fcov-ver-data
s" unknown" fcov-ver-data 2!

[UNDEFINED] fcov-home-path [IF]
: fcov-home-path ( -- a u )
    s" FCOV_HOME" getenv 2dup nip IF EXIT THEN
    2drop s" HOME" getenv s" /fcov" fcov.str-concat ;
[THEN]

\ Throwaway parser for package.4th — captures `key-value version <X>`.
MARKER fcov.discard-ver-parser

: forth-package ;
: end-forth-package ;
: key-list 0 parse 2drop ;
: key-value
    parse-name s" version" compare 0= IF
        parse-name fcov.str-dup fcov-ver-data 2!
    ELSE
        0 parse 2drop
    THEN ;

: fcov.read-self-version
    fcov-home-path s" /package.4th" fcov.str-concat { buf bu }
    buf bu 2dup file-status nip 0= IF
        included
    ELSE
        2drop
    THEN
    buf free throw ;

fcov.read-self-version

fcov.discard-ver-parser

\ Version-check parser uses its own throwaway scope; load *after* the
\ self-version parser is gone to avoid colliding key-value/key-list defs.
require fcov/version-check.4th

\ --- Argument parsing -----------------------------------------------------

2variable fcov.cmd
2variable fcov.arg
2variable fcov.rest
s" " fcov.cmd 2!
s" " fcov.arg 2!
s" " fcov.rest 2!

: fcov.read-args
    s" FCOV_CMD" getenv 2dup nip IF
        fcov.str-dup fcov.cmd 2!
    ELSE
        2drop s" help" fcov.cmd 2!
    THEN
    s" FCOV_ARG" getenv 2dup nip IF
        fcov.str-dup fcov.arg 2!
    ELSE
        2drop s" " fcov.arg 2!
    THEN
    s" FCOV_REST" getenv 2dup nip IF
        fcov.str-dup fcov.rest 2!
    ELSE
        2drop s" " fcov.rest 2!
    THEN ;

\ --- Commands -------------------------------------------------------------

: fcov.help
    cr s" fcov v" type fcov-ver-data 2@ type
    s"  — coverage collector for Forth source trees" type cr
    s" Usage: fcov <command> [args]" type cr
    s" Commands:" type cr
    s"    run [<test-cmd>]                          - Run tests under instrumentation" type cr
    s"                                                (default: `fmix test`)." type cr
    s"    report [--format console|lcov|json|html]  - Show coverage report from last run." type cr
    s"    clean                                     - Remove .fcov/ artefacts." type cr
    s"    version                                   - Show fcov version." type cr
    s"    help                                      - Show this help." type cr cr
    s" Notes:" type cr
    s"    - 0.1.0 is a scaffold release: `run` and `report` print a" type cr
    s"      placeholder message. See doc/ROADMAP.md for the implementation plan." type cr
    s"    - build/ and forth-packages/ subdirectories are excluded from coverage." type cr cr ;

: fcov.version
    cr s" ** (fcov) v" type fcov-ver-data 2@ type cr cr ;

\ --- run: stub ------------------------------------------------------------
\
\ The real `fcov.run` will:
\   1. Walk the project tree (skipping build/ and forth-packages/) and
\      collect every `:`/`Defer`/`Variable` definition with its source
\      location.
\   2. Generate an instrumentation prelude that redefines `:` (and, for
\      0.2.0, `IF`/`ELSE`/`THEN`/`BEGIN`/`WHILE`/`?DO`/`LOOP`) to bump
\      a per-word (per-branch) counter on entry.
\   3. Spawn the user-provided test command (default `fmix test`) with
\      the prelude pre-loaded into each gforth process and per-test
\      counter streams routed to .fcov/calls.log.
\   4. Aggregate streams into .fcov/coverage.json (canonical form for
\      the reporter).

: fcov.run-stub
    fcov.rest 2@ nip 0= IF
        fcov.arg 2@ nip 0= IF s" fmix test" ELSE fcov.arg 2@ THEN
    ELSE
        fcov.arg 2@ s"  " fcov.str-concat fcov.rest 2@ fcov.str-concat
    THEN { ca cu }
    cr s" [INFO] fcov 0.1.0 is a scaffold release." type cr
    s"        `fcov run` would execute: " type ca cu type cr
    s"        and collect coverage into .fcov/." type cr
    s"        Real instrumentation lands in 0.2.0 — see doc/ROADMAP.md." type cr cr
    ca cu drop free throw ;

\ --- report: stub ---------------------------------------------------------

: fcov.report-stub
    cr s" [INFO] fcov 0.1.0 is a scaffold release." type cr
    s"        `fcov report` would print the coverage summary from .fcov/." type cr
    s"        Real reporter (console / lcov / json / html) lands in 0.2.0+." type cr cr ;

\ --- clean: actually works ------------------------------------------------
\
\ rm -rf .fcov/ in the current directory. Uses `system` because
\ recursive-rm in pure Forth would be unnecessary surface area for a
\ tool whose target audience already has rm(1).

: fcov.clean
    s" rm -rf .fcov/" pad place pad count system
    cr s" * fcov: removed .fcov/ (if it existed)." type cr ;

: fcov-dispatch
    fcov.read-args
    fcov.check-required-version
    fcov.cmd 2@ s" run"     compare 0= IF fcov.run-stub    EXIT THEN
    fcov.cmd 2@ s" report"  compare 0= IF fcov.report-stub EXIT THEN
    fcov.cmd 2@ s" clean"   compare 0= IF fcov.clean       EXIT THEN
    fcov.cmd 2@ s" version" compare 0= IF fcov.version     EXIT THEN
    fcov.cmd 2@ s" help"    compare 0= IF fcov.help        EXIT THEN
    cr s" Unknown command: " type fcov.cmd 2@ type cr
    fcov.help
    1 (bye) ;

fcov-dispatch
0 (bye)
