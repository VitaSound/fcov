\ tests/fcov_aggregator_test.4th — unit-tests for the call-shard
\ aggregator (fcov/aggregate.4th).
\
\ Verifies the three rules from doc/ROADMAP.md §«Aggregation rules»:
\   1. Multiple log lines for the same word → sum counts.
\   2. A word in `definitions[]` but not in `calls{}` → coverage = 0.
\   3. A word in `calls{}` but not in `definitions[]` → external dep,
\      ignored from the summary.

: fcov.test-setup-fpath
    s" FCOV_HOME" getenv 2dup nip 0= IF
        cr ." [SKIP] fcov_aggregator_test needs FCOV_HOME env var set." cr
        2drop 0 (bye)
    THEN
    fpath also-path ;
fcov.test-setup-fpath

s" forth-packages/ttester/1.2.1/ttester.4th" included
s" forth-packages/ttester/1.2.1/ttester-ext.4th" included

require fcov/util.4th
2variable fcov-ver-data    s" 0.2.0" fcov-ver-data 2!
require fcov/version-check.4th
require fcov/walk.4th
require fcov/scan.4th
require fcov/collect.4th
require fcov/aggregate.4th

0 #ERRORS !

\ --- Helpers --------------------------------------------------------------

\ Drop any leftover test state.
fcov.recs-clear
fcov.hits-clear

\ Add a synthetic definition record. file is constant; line is incremental.
variable fcov.t-line   1 fcov.t-line !

: fcov.t-add-def { name-a name-u type-a type-u -- }
    s" /tmp/fixture.4th" fcov.t-line @ type-a type-u name-a name-u
    fcov.recs-append
    1 fcov.t-line +! ;

\ Write a string to a file.
: fcov.t-write-file { fname-a fname-u content-a content-u -- }
    fname-a fname-u w/o create-file throw { fid }
    content-a content-u fid write-file throw
    fid close-file throw ;

\ --- Setup: 3 colon-defs, 1 variable --------------------------------------
\
\ Coverage we'll engineer with synthetic shards:
\   colon-a   → 3 hits (across 2 shards)
\   colon-b   → 1 hit
\   colon-c   → 0 hits  (uncovered colon)
\   var-a     → 0 hits  (variable; not part of colon coverage)

s" colon-a" s" colon"    fcov.t-add-def
s" colon-b" s" colon"    fcov.t-add-def
s" colon-c" s" colon"    fcov.t-add-def
s" var-a"   s" variable" fcov.t-add-def

\ ---- Sanity: walker has 4 records, lookup works --------------------------

T{ fcov.recs-count -> 4 }T

T{ s" colon-a" fcov.recs-find nip -> true  }T
T{ s" missing" fcov.recs-find     -> false }T

\ --- Synthesize two shards ------------------------------------------------
\
\ Shard 1: colon-a, colon-b, colon-a, external-x  (CRLF endings on purpose)
\ Shard 2: colon-a, external-y, (blank line), trailing partial line «extra»
\
\ External words must NOT bump the words_total/words_covered summary —
\ they're surfaced in calls{} but ignored from the percentage.

: fcov.t-write-shard1
    s" /tmp/fcov-test-shard-1.log" w/o create-file throw { fid }
    s\" colon-a\r\ncolon-b\r\ncolon-a\r\nexternal-x\r\n"
        fid write-file throw
    fid close-file throw ;

: fcov.t-write-shard2
    s" /tmp/fcov-test-shard-2.log" w/o create-file throw { fid }
    s\" colon-a\nexternal-y\n\nextra"
        fid write-file throw
    fid close-file throw ;

fcov.t-write-shard1
fcov.t-write-shard2

\ --- Ingest both shards ---------------------------------------------------

s" /tmp/fcov-test-shard-1.log" fcov.ingest-shard
s" /tmp/fcov-test-shard-2.log" fcov.ingest-shard

\ --- Rule 1: multiple log lines for the same word are summed -------------

T{ s" colon-a" fcov.hit-count@ -> 3 }T
T{ s" colon-b" fcov.hit-count@ -> 1 }T

\ --- Rule 2: definition-without-calls is uncovered (count = 0) -----------

T{ s" colon-c" fcov.hit-count@ -> 0 }T
T{ s" var-a"   fcov.hit-count@ -> 0 }T

\ --- Rule 3: external word seen in shard but not in defs --------------

T{ s" external-x" fcov.hit-count@ -> 1 }T
T{ s" external-y" fcov.hit-count@ -> 1 }T
T{ s" extra"      fcov.hit-count@ -> 1 }T

\ Lookup on the definitions list (not the hit map) must NOT find them:
T{ s" external-x" fcov.recs-find -> false }T
T{ s" external-y" fcov.recs-find -> false }T
T{ s" extra"      fcov.recs-find -> false }T

\ --- Coverage JSON: summary should ignore external words ----------------

s" /tmp/fcov-test-coverage.json"
s" gforth -e 'bye'"
s" 0.2.0-test"
fcov.write-coverage-json

\ Slurp the produced JSON; expose its bytes via 2variable so the T{ … }T
\ assertions can stay at top level (locals only work inside colon-defs).
2variable fcov.t-jbuf
s" /tmp/fcov-test-coverage.json" slurp-file fcov.t-jbuf 2!

: fcov.t-json-has? ( s su -- f )
    fcov.t-jbuf 2@ 2swap fcov.contains? ;

T{ s\" \"words_total\": 3"    fcov.t-json-has? -> true }T
T{ s\" \"words_covered\": 2"  fcov.t-json-has? -> true }T
T{ s\" \"coverage_pct\": 66"  fcov.t-json-has? -> true }T
T{ s\" \"name\": \"colon-c\"" fcov.t-json-has? -> true }T
T{ s\" \"name\": \"var-a\""   fcov.t-json-has? -> true }T
T{ s\" \"external-x\""        fcov.t-json-has? -> true }T

fcov.t-jbuf 2@ drop free throw

\ --- Cleanup --------------------------------------------------------------

s" rm -f /tmp/fcov-test-shard-1.log /tmp/fcov-test-shard-2.log /tmp/fcov-test-coverage.json"
system

fcov.hits-clear
fcov.recs-clear

: report
    #ERRORS @ 0= IF
        cr ." fcov_aggregator_test ok" cr
    ELSE
        cr ." fcov_aggregator_test FAILED: " #ERRORS @ . ." errors" cr
        1 (bye)
    THEN ;
report
bye
