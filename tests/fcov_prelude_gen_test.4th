\ tests/fcov_prelude_gen_test.4th — round-trip the auto-generated
\ prelude through gforth and assert it loads cleanly.
\
\ Strategy:
\   1. Call fcov.write-prelude into /tmp/fcov-test-prelude.4th.
\   2. Spawn a fresh gforth subprocess and `include` the prelude
\      with a handful of follow-on `:` defs and assertions baked
\      into the same -e expression.
\   3. The subprocess writes a per-PID hits log to a controlled
\      directory (FCOV_CALLS_LOG); we slurp it back and verify
\      both `: foo` and `: bar` show up after being executed.
\
\ This is the «smoke» end of unit testing — full prelude semantics
\ are exercised by the partial_cov fixture in fcov_integration_test.sh.

: fcov.test-setup-fpath
    s" FCOV_HOME" getenv 2dup nip 0= IF
        cr ." [SKIP] fcov_prelude_gen_test needs FCOV_HOME env var set." cr
        2drop 0 (bye)
    THEN
    fpath also-path ;
fcov.test-setup-fpath

s" forth-packages/ttester/1.2.0/ttester.4th" included
s" forth-packages/ttester/1.2.0/ttester-ext.4th" included

require fcov/util.4th
2variable fcov-ver-data    s" 0.2.0" fcov-ver-data 2!
require fcov/version-check.4th
require fcov/prelude.4th

0 #ERRORS !

\ --- Step 1: emit prelude -------------------------------------------------

s" /tmp/fcov-test-prelude.4th" fcov.write-prelude

\ --- Step 2: confirm prelude file is non-empty + has expected hooks ------

2variable fcov.t-pbuf
s" /tmp/fcov-test-prelude.4th" slurp-file fcov.t-pbuf 2!

: fcov.t-prelude-has? ( s su -- f )
    fcov.t-pbuf 2@ 2swap fcov.contains? ;

T{ fcov.t-pbuf 2@ nip 0> -> true }T
T{ s" fcov.hit"             fcov.t-prelude-has? -> true }T
T{ s" fcov.orig-colon"      fcov.t-prelude-has? -> true }T
T{ s" latestxt >name name>string" fcov.t-prelude-has? -> true }T
T{ s" [UNDEFINED] fcov.hit" fcov.t-prelude-has? -> true }T
T{ s" [THEN]"               fcov.t-prelude-has? -> true }T

\ --- Step 3: round-trip — load prelude into a fresh gforth, run it -------

s" rm -f /tmp/fcov-test-prelude-hits.log" system

\ Build a shell command that:
\   - sets FCOV_CALLS_LOG so the prelude logs to a known path,
\   - includes the prelude,
\   - defines two colon-words and runs both,
\   - exits cleanly.
\
\ The test passes if the resulting log contains both names exactly once.
\
\ When this test runs inside `fcov run fmix test`, plain `gforth` on
\ PATH resolves to fcov's shim — which forces FCOV_CALLS_LOG to its
\ own per-PID shard and ignores ours. So we deliberately bypass the
\ shim by invoking $FCOV_REAL_GFORTH (set by `fcov run`) when it's
\ available; standalone runs fall back to `gforth` on PATH.

: fcov.t-gforth-bin ( -- a u )
    s" FCOV_REAL_GFORTH" getenv 2dup nip 0= IF
        2drop s" gforth"
    THEN ;

: fcov.t-build-and-run
    s" FCOV_CALLS_LOG=/tmp/fcov-test-prelude-hits.log " { sa su }
    sa su fcov.t-gforth-bin fcov.str-concat { p1a p1u }
    p1a p1u s\"  -e 'include /tmp/fcov-test-prelude.4th : tp.foo 1 drop ; : tp.bar 2 drop ; tp.foo tp.bar bye'"
    fcov.str-concat { ca cu }
    p1a free throw
    ca cu system
    ca free throw ;

fcov.t-build-and-run

\ Slurp the hit log and check both names appear (any number of times).
2variable fcov.t-hbuf
s" /tmp/fcov-test-prelude-hits.log" slurp-file fcov.t-hbuf 2!

: fcov.t-hits-has? ( s su -- f )
    fcov.t-hbuf 2@ 2swap fcov.contains? ;

T{ s" tp.foo" fcov.t-hits-has? -> true }T
T{ s" tp.bar" fcov.t-hits-has? -> true }T

\ Sanity: an unrelated word that was never defined must NOT appear.
T{ s" tp.never-defined" fcov.t-hits-has? -> false }T

fcov.t-pbuf 2@ drop free throw
fcov.t-hbuf 2@ drop free throw

\ --- Cleanup --------------------------------------------------------------

s" rm -f /tmp/fcov-test-prelude.4th /tmp/fcov-test-prelude-hits.log" system

: report
    #ERRORS @ 0= IF
        cr ." fcov_prelude_gen_test ok" cr
    ELSE
        cr ." fcov_prelude_gen_test FAILED: " #ERRORS @ . ." errors" cr
        1 (bye)
    THEN ;
report
bye
