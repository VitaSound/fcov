\ tests/fcov_smoke_test.4th — wiring smoke-test for fcov 0.1.0.
\
\ Mirrors the strategy used by flint_version_check_test.4th: confirm
\ the version-check chain (fcov/util → fsemver → fcov/version-check)
\ loads cleanly and that fsemver's public words are reachable from
\ fcov's load context. The full operator truth-table (71 cases) lives
\ upstream in forth-packages/fsemver/0.1.0/tests/fsemver_test.4th, so
\ we don't duplicate it here.

: fcov.test-setup-fpath
    s" FCOV_HOME" getenv 2dup nip 0= IF
        cr ." [SKIP] fcov_smoke_test needs FCOV_HOME env var set." cr
        2drop 0 (bye)
    THEN
    fpath also-path ;
fcov.test-setup-fpath

s" forth-packages/ttester/1.2.1/ttester.4th" included
s" forth-packages/ttester/1.2.1/ttester-ext.4th" included

require fcov/util.4th

\ Provide a dummy installed-version variable; version-check.4th expects
\ fcov-ver-data to be defined by fcov.4th in production.
2variable fcov-ver-data
s" 0.1.0" fcov-ver-data 2!

require fcov/version-check.4th

0 #ERRORS !

\ --- Wiring: fsemver public API visible through fcov's load chain --------

T{ s" 0.1.0"   fsemver.parse-version-parts -> 0 1 0 3 }T
T{ s" ~> 0.1"  fsemver.parse-req           -> 0 0 1 0 true }T
T{ s" >= 0.1"  fsemver.parse-req           -> 2 0 1 0 true }T
T{ s" garbage" fsemver.parse-req           -> 0 0 0 0 false }T

\ --- Wiring: matcher gives the expected verdict --------------------------

\ self=0.1.5 satisfies ~> 0.1
T{  0 1 0 0   0 1 5  fsemver.req-matches? -> true  }T
\ self=1.0.0 does NOT satisfy ~> 0.1
T{  0 1 0 0   1 0 0  fsemver.req-matches? -> false }T

\ --- Wiring: fcov-owned state is initialised -----------------------------

T{ fcov.legacy-self-dep? @ -> 0 }T
T{ fcov.required-req 2@ nip 0>= -> true }T

\ --- Wiring: fcov util helpers behave -------------------------------------

\ str-dup gives a fresh buffer (caller frees). Use a colon-def around the
\ check because gforth's locals (`{ … }`) are valid only inside a
\ definition, and ttester's `T{ … }T` doesn't establish one.
: fcov.test-str-dup
    s" hello" fcov.str-dup { dup-a dup-u }
    dup-a dup-u s" hello" compare
    dup-a free throw ;
T{ fcov.test-str-dup -> 0 }T

\ str-concat must concatenate cleanly.
: fcov.test-str-concat
    s" foo" s" bar" fcov.str-concat { c-a c-u }
    c-a c-u s" foobar" compare
    c-a free throw ;
T{ fcov.test-str-concat -> 0 }T

\ ends-with? / starts-with? are used by walk + scan and report-format parsing.
T{ s" foo.4th" s" .4th" fcov.ends-with?   -> true  }T
T{ s" foo.txt" s" .4th" fcov.ends-with?   -> false }T
T{ s" --format=lcov" s" --format=" fcov.starts-with? -> true  }T
T{ s" --foo"        s" --format=" fcov.starts-with? -> false }T

: report
    #ERRORS @ 0= IF
        cr ." fcov_smoke_test ok" cr
    ELSE
        cr ." fcov_smoke_test FAILED: " #ERRORS @ . ." errors" cr
        1 (bye)
    THEN ;
report
bye
