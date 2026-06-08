\ fcov/aggregate.4th — merge per-process call shards into one
\ canonical `.fcov/coverage.json` and a parallel in-memory hit-count
\ on each definition record (so reporters can iterate without a second
\ JSON parse round-trip).
\
\ Inputs:
\   - `.fcov/calls/*.log` — one word-name per line, written by every
\     gforth process that loaded the prelude during `fcov run`.
\   - the in-memory definitions list (fcov/collect.4th).
\
\ Output:
\   - `.fcov/coverage.json` — canonical merge:
\
\     {
\       "fcov_version": "0.2.0",
\       "test_cmd":     "fmix test",
\       "definitions": [ { name,file,line,type,calls } … ],
\       "calls":       { name: count, … },         (project-scoped)
\       "summary":     { words_total, words_covered, coverage_pct }
\     }
\
\ Aggregation rules (per ROADMAP §0.2.0):
\   - Multiple log lines for the same word → sum counts.
\   - A word in `definitions[]` but not in `calls{}` → coverage = 0,
\     counted as «uncovered».
\   - A word in `calls{}` but not in `definitions[]` → external dep,
\     ignored (don't inflate the denominator). We DO still surface
\     the count in the JSON's `calls{}` map for debugging, but it
\     doesn't drive the summary.
\
\ Storage strategy:
\   - We pack a per-record «calls» counter into one extra cell appended
\     to each fcov record. To avoid changing the on-disk record layout
\     in collect.4th (and to keep that module aggregation-ignorant) we
\     keep a parallel hash-of-name → count built incrementally as we
\     read the log shards. After the merge pass, definitions are
\     decorated by reading from that map.

require fcov/util.4th
require fcov/collect.4th
require fcov/walk.4th
require ../forth-packages/fenum/0.1.1/fenum-bs.4th

\ --- Hit map: ulist of (name, count) entries ------------------------------
\
\ The volume is bounded by «distinct words observed during one test
\ run», typically O(100…10k). A linked-list lookup is O(N) per
\ insertion which dominates aggregation time, but for 0.2.0 this is
\ not a hot path. If profiling shows it matters, swap in a hash table
\ — the public API below stays.

begin-structure fcov-hit%
    field: fcov.hit-name-a
    field: fcov.hit-name-u
    field: fcov.hit-count
end-structure

variable fcov.hits    ulist-new fcov.hits !

: fcov.hits-distinct ( -- n )  fcov.hits @ ulist-len ;

: fcov.free-hit ( hit -- )
    dup fcov.hit-name-a @ free throw
    free throw ;

: fcov.hits-clear
    ['] fcov.free-hit fcov.hits @ ulist-each
    fcov.hits @ ulist-clear ;

\ Linear find: stash result in a module-local cell during ulist-each.

variable fcov.hit-target-a
variable fcov.hit-target-u
variable fcov.hit-found

: fcov.hit-match-step ( hit -- )
    fcov.hit-found @ IF drop EXIT THEN
    dup fcov.hit-name-a @ over fcov.hit-name-u @
    fcov.hit-target-a @ fcov.hit-target-u @
    compare 0= IF fcov.hit-found ! ELSE drop THEN ;

: fcov.hit-find ( name-a name-u -- entry|0 )
    fcov.hit-target-u !
    fcov.hit-target-a !
    0 fcov.hit-found !
    ['] fcov.hit-match-step fcov.hits @ ulist-each
    fcov.hit-found @ ;

\ Find or create a hit entry for (name-a, name-u). Returns the entry.
: fcov.hit-find-or-create { name-a name-u -- entry }
    name-a name-u fcov.hit-find ?dup IF EXIT THEN
    fcov-hit% allocate throw { entry }
    name-a name-u fcov.str-dup
    entry fcov.hit-name-u !
    entry fcov.hit-name-a !
    0 entry fcov.hit-count !
    entry fcov.hits @ ulist-add
    entry ;

: fcov.hit-bump ( name-a name-u -- )
    fcov.hit-find-or-create
    1 swap fcov.hit-count +! ;

\ Lookup count for a name. Returns 0 if not seen.
: fcov.hit-count@ ( name-a name-u -- n )
    fcov.hit-find ?dup IF fcov.hit-count @ ELSE 0 THEN ;

\ --- Read one log shard ---------------------------------------------------
\
\ A log shard is plain text: one word name per line, possibly trailing
\ \n. We split on \n and treat each non-empty line as a hit.

\ Trim a trailing \r off (a u) if present (handles CRLF logs).
: fcov.trim-cr ( a u -- a u' )
    dup 0> IF
        2dup + 1- c@ 13 = IF 1- THEN
    THEN ;

: fcov.ingest-shard { fname-a fname-u -- }
    fname-a fname-u file-status nip 0<> IF EXIT THEN
    fname-a fname-u slurp-file { src su }
    src { line-start }
    su 0 ?do
        src i + c@ 10 = IF
            line-start  src i + line-start -  fcov.trim-cr
            dup 0> IF fcov.hit-bump ELSE 2drop THEN
            src i + 1+ to line-start
        THEN
    loop
    \ trailing partial line (no final \n)
    line-start  src su + line-start -  fcov.trim-cr
    dup 0> IF fcov.hit-bump ELSE 2drop THEN
    src free throw ;

\ --- Walk the calls/ directory and ingest every *.log ---------------------

variable fcov.calls-dir-fid

: fcov.shard-cb ( path-a path-u -- )
    fcov.ingest-shard ;

256 constant fcov.shard-name-max
create  fcov.shard-name-buf  fcov.shard-name-max allot

: fcov.ingest-calls-dir { dir-a dir-u -- }
    dir-a dir-u open-dir IF drop EXIT THEN { dirid }
    begin
        fcov.shard-name-buf fcov.shard-name-max dirid read-dir throw
    while
        fcov.shard-name-buf swap { n-a n-u }
        n-u 0<> IF
            n-a c@ [char] . <> IF
                n-a n-u s" .log" fcov.ends-with? IF
                    dir-a dir-u n-a n-u fcov.fs-join
                    2dup fcov.ingest-shard
                    drop free throw
                THEN
            THEN
        THEN
    repeat drop
    dirid close-dir throw ;

\ --- Decorate definitions with their call count and write JSON -----------

variable fcov.cov-fid
variable fcov.cov-first?
variable fcov.cov-words-total
variable fcov.cov-words-covered

: fcov.cov-emit ( a u -- )
    fcov.cov-fid @ write-file throw ;

\ Re-use the JSON helpers from collect.4th by re-pointing `fcov.json-fid`
\ at our coverage file before each call. That keeps the escape rules
\ in one place; the indirection is cheap.
: fcov.cov-emit-quoted ( a u -- )
    fcov.cov-fid @ fcov.json-fid !
    fcov.json-quoted ;

: fcov.cov-emit-uint ( u -- )
    fcov.cov-fid @ fcov.json-fid !
    fcov.json-uint ;

: fcov.cov-write-def ( rec -- )
    fcov.cov-first? @ IF
        s\" ,\n" fcov.cov-emit
    THEN
    -1 fcov.cov-first? !
    s\"     {\"name\": " fcov.cov-emit
    dup fcov.rec-name@ fcov.cov-emit-quoted
    s\" , \"file\": "    fcov.cov-emit
    dup fcov.rec-file@ fcov.cov-emit-quoted
    s\" , \"line\": "    fcov.cov-emit
    dup fcov.rec-line@ fcov.cov-emit-uint
    s\" , \"type\": "    fcov.cov-emit
    dup fcov.rec-type@ fcov.cov-emit-quoted
    s\" , \"calls\": "   fcov.cov-emit
    dup fcov.rec-name@ fcov.hit-count@ { c }
    \ Summary semantics: only colon-defs are executable, so only they
    \ contribute to «covered / total». Non-colon defs (variables,
    \ constants, fields, …) appear in the catalogue with calls=0 but
    \ don't drag the percentage down. Keeps the metric meaningful.
    dup fcov.rec-type@ s" colon" compare 0= IF
        1 fcov.cov-words-total +!
        c 0> IF 1 fcov.cov-words-covered +! THEN
    THEN
    c fcov.cov-emit-uint
    s" }" fcov.cov-emit
    drop ;

\ Walk the hit map and emit { name: count, … } pairs for every entry.
\ External names (not in definitions) appear here too — useful for
\ debugging. The summary uses only definition records.

variable fcov.calls-first?

: fcov.cov-write-call ( entry -- )
    fcov.calls-first? @ IF
        s\" ,\n" fcov.cov-emit
    THEN
    -1 fcov.calls-first? !
    s\"     " fcov.cov-emit
    dup fcov.hit-name-a @ over fcov.hit-name-u @ fcov.cov-emit-quoted
    s" : " fcov.cov-emit
    fcov.hit-count @ fcov.cov-emit-uint ;

: fcov.calls-each ( xt -- )
    fcov.hits @ ulist-each ;

\ Emit the canonical coverage JSON to an open fid. The caller owns the
\ fid lifetime — useful for both the on-disk writer below and the
\ stdout-bound `--format json` reporter.

: fcov.emit-coverage-json
        ( fid test-cmd-a test-cmd-u version-a version-u -- )
    { fid tc-a tc-u v-a v-u }
    fid fcov.cov-fid !

    s" {" fcov.cov-emit
    s\" \n  \"fcov_version\": " fcov.cov-emit
    v-a v-u fcov.cov-emit-quoted
    s\" ,\n  \"test_cmd\": " fcov.cov-emit
    tc-a tc-u fcov.cov-emit-quoted
    s\" ,\n  \"definitions\": [\n" fcov.cov-emit
    0 fcov.cov-first? !
    0 fcov.cov-words-total !
    0 fcov.cov-words-covered !
    ['] fcov.cov-write-def fcov.recs-each
    s\" \n  ],\n  \"calls\": {\n" fcov.cov-emit
    0 fcov.calls-first? !
    ['] fcov.cov-write-call fcov.calls-each
    s\" \n  },\n  \"summary\": {" fcov.cov-emit
    s\" \n    \"words_total\": " fcov.cov-emit
    fcov.cov-words-total @ fcov.cov-emit-uint
    s\" ,\n    \"words_covered\": " fcov.cov-emit
    fcov.cov-words-covered @ fcov.cov-emit-uint
    s\" ,\n    \"coverage_pct\": " fcov.cov-emit
    fcov.cov-words-covered @ fcov.cov-words-total @ fcov.percent>str
    fcov.cov-emit
    s\" \n  }\n}\n" fcov.cov-emit

    0 fcov.cov-fid ! ;

: fcov.write-coverage-json
        ( fname-a fname-u test-cmd-a test-cmd-u version-a version-u -- )
    { fname-a fname-u tc-a tc-u v-a v-u }
    fname-a fname-u w/o create-file throw { fid }
    fid tc-a tc-u v-a v-u fcov.emit-coverage-json
    fid close-file throw ;

\ Public read-side accessors — used by reporters that need to also
\ surface `summary.words_*` (e.g. the HTML index page) without parsing
\ the JSON we just wrote. Populated as a side-effect of every
\ fcov.emit-coverage-json call.

: fcov.summary-total    ( -- n )  fcov.cov-words-total   @ ;
: fcov.summary-covered  ( -- n )  fcov.cov-words-covered @ ;
: fcov.summary-pct ( -- n )
    fcov.summary-total dup 0= IF drop 0 EXIT THEN
    fcov.summary-covered swap 100 * swap / ;
