\ fcov/report-lcov.4th — emit LCOV trace data on stdout.
\
\ Format reference:
\   https://manpages.debian.org/testing/lcov/geninfo.1.en.html
\
\ The LCOV reader-of-record is `genhtml` from the `lcov` Debian package.
\ Even though our underlying granularity is *word*-coverage rather than
\ line-coverage, we map each tracked word to the source line it was
\ defined on; genhtml renders «hit / not hit» per line which is exactly
\ what users expect to see in coverage HTML.
\
\ Per-file record shape:
\
\   TN:fcov
\   SF:<absolute or relative source path>
\   FN:<line>,<word-name>
\   FNDA:<count>,<word-name>
\   ...
\   FNF:<functions found>
\   FNH:<functions hit>
\   DA:<line>,<count>
\   ...
\   LF:<lines found>
\   LH:<lines hit>
\   end_of_record
\
\ We emit FN/FNDA/DA only for `colon` records (the only type for which
\ the prelude actually compiles a hit-bump). Non-colon defs would
\ always read as «hit» which is technically true but adds no signal.
\
\ Storage: per-file buckets and per-bucket record-pointer lists are
\ both fenum ulists.

require fcov/util.4th
require fcov/collect.4th
require fcov/aggregate.4th
require ../forth-packages/fenum/0.1.1/fenum-bs.4th

\ --- Per-file LCOV bucket -------------------------------------------------

begin-structure fcov-lk%
    field: fcov.lk-file-a
    field: fcov.lk-file-u
    field: fcov.lk-recs       \ ulist of fcov-rec pointers
end-structure

variable fcov.lcov-buckets    ulist-new fcov.lcov-buckets !

\ --- Cleanup --------------------------------------------------------------

\ Records in lk-recs are *aliases* of the canonical defs list — do NOT
\ free them here, only dispose the local ulist that tracked them.
: fcov.free-lcov-bucket ( bk -- )
    dup fcov.lk-recs @ ?dup IF ulist-dispose THEN
    dup fcov.lk-file-a @ free throw
    free throw ;

: fcov.lcov-clear
    ['] fcov.free-lcov-bucket fcov.lcov-buckets @ ulist-each
    fcov.lcov-buckets @ ulist-clear ;

\ --- Bucket lookup --------------------------------------------------------

variable fcov.lk-target-a
variable fcov.lk-target-u
variable fcov.lk-found

: fcov.lk-match-step ( bk -- )
    fcov.lk-found @ IF drop EXIT THEN
    dup fcov.lk-file-a @ over fcov.lk-file-u @
    fcov.lk-target-a @ fcov.lk-target-u @
    compare 0= IF fcov.lk-found ! ELSE drop THEN ;

: fcov.lcov-find-bucket { f-a f-u -- bk|0 }
    f-a fcov.lk-target-a !
    f-u fcov.lk-target-u !
    0 fcov.lk-found !
    ['] fcov.lk-match-step fcov.lcov-buckets @ ulist-each
    fcov.lk-found @ ;

: fcov.lcov-find-or-create-bucket { f-a f-u -- bk }
    f-a f-u fcov.lcov-find-bucket ?dup IF EXIT THEN
    fcov-lk% allocate throw { bk }
    f-a f-u fcov.str-dup
    bk fcov.lk-file-u !
    bk fcov.lk-file-a !
    ulist-new bk fcov.lk-recs !
    bk fcov.lcov-buckets @ ulist-add
    bk ;

: fcov.lcov-ingest ( rec -- )
    dup fcov.rec-type@ s" colon" compare 0= IF
        dup fcov.rec-file@ fcov.lcov-find-or-create-bucket
        fcov.lk-recs @ ulist-add
    ELSE
        drop
    THEN ;

\ --- Emit -----------------------------------------------------------------

: fcov.lcov-emit-rec-fn ( rec -- )
    s" FN:" type
    dup fcov.rec-line@ fcov.u>str type
    s" ," type
    fcov.rec-name@ type cr ;

: fcov.lcov-emit-rec-fnda ( rec -- )
    s" FNDA:" type
    dup fcov.rec-name@ fcov.hit-count@ fcov.u>str type
    s" ," type
    fcov.rec-name@ type cr ;

: fcov.lcov-emit-rec-da ( rec -- )
    s" DA:" type
    dup fcov.rec-line@ fcov.u>str type
    s" ," type
    fcov.rec-name@ fcov.hit-count@ fcov.u>str type cr ;

variable fcov.lcov-fn-found
variable fcov.lcov-fn-hit
variable fcov.lcov-line-found
variable fcov.lcov-line-hit

: fcov.lcov-tally ( rec -- )
    1 fcov.lcov-fn-found +!
    1 fcov.lcov-line-found +!
    fcov.rec-name@ fcov.hit-count@ 0> IF
        1 fcov.lcov-fn-hit +!
        1 fcov.lcov-line-hit +!
    THEN ;

: fcov.lcov-emit-bucket ( bk -- )
    s" TN:fcov" type cr
    s" SF:" type
    dup fcov.lk-file-a @ over fcov.lk-file-u @ type cr
    0 fcov.lcov-fn-found !
    0 fcov.lcov-fn-hit !
    0 fcov.lcov-line-found !
    0 fcov.lcov-line-hit !

    dup fcov.lk-recs @ { recs }
    ['] fcov.lcov-emit-rec-fn  recs ulist-each
    ['] fcov.lcov-tally        recs ulist-each
    ['] fcov.lcov-emit-rec-fnda recs ulist-each

    s" FNF:" type fcov.lcov-fn-found @ fcov.u>str type cr
    s" FNH:" type fcov.lcov-fn-hit   @ fcov.u>str type cr

    ['] fcov.lcov-emit-rec-da  recs ulist-each

    s" LF:" type fcov.lcov-line-found @ fcov.u>str type cr
    s" LH:" type fcov.lcov-line-hit   @ fcov.u>str type cr
    s" end_of_record" type cr
    drop ;

: fcov.lcov-each-bucket ( xt -- )
    fcov.lcov-buckets @ ulist-each ;

: fcov.lcov-reverse-bucket-recs ( bk -- )
    fcov.lk-recs @ ulist-reverse ;

: fcov.report-lcov
    fcov.lcov-clear
    ['] fcov.lcov-ingest fcov.recs-each
    \ ulist-add prepended both the bucket list and each bucket's
    \ record list. Reverse buckets so files print in walk order, and
    \ reverse each bucket's record list so words inside print in
    \ source-line order.
    fcov.lcov-buckets @ ulist-reverse
    ['] fcov.lcov-reverse-bucket-recs fcov.lcov-each-bucket
    ['] fcov.lcov-emit-bucket fcov.lcov-each-bucket ;
