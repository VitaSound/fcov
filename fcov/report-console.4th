\ fcov/report-console.4th — pretty-print a coverage summary to stdout.
\
\ Reads from the in-memory definition list (already merged with hit
\ counts via fcov/aggregate.4th) and emits one row per source file
\ followed by a TOTAL line. The exact rendered shape is deliberately
\ stable across releases so users can `grep` it from CI scripts.
\
\ Sample output:
\
\   src/thing.4th     8/12 (66%)   uncovered: foo, bar, baz
\   src/util.4th      4/4  (100%)
\   ----------------------------------------
\   TOTAL            12/16 (75%)
\
\ The uncovered-list is truncated to the first 6 names; the suffix
\ « …+N more » indicates the remainder. Keeps the terminal output
\ readable on small terminals without losing all signal.
\
\ Storage: per-file buckets and per-bucket «uncovered names» are both
\ ulists from fenum, matching the rest of the fcov pipeline.

require fcov/util.4th
require fcov/collect.4th
require fcov/aggregate.4th
require ../forth-packages/fenum/0.1.1/fenum-bs.4th

\ --- Per-file bucket ------------------------------------------------------

begin-structure fcov-bk%
    field: fcov.bk-file-a
    field: fcov.bk-file-u
    field: fcov.bk-total
    field: fcov.bk-covered
    field: fcov.bk-uncov     \ ulist of uncovered-name nodes
end-structure

\ Each uncovered-name node owns a heap-allocated string copy.
begin-structure fcov-un%
    field: fcov.un-name-a
    field: fcov.un-name-u
end-structure

variable fcov.buckets    ulist-new fcov.buckets !

\ --- Cleanup --------------------------------------------------------------

: fcov.free-uncov ( un -- )
    dup fcov.un-name-a @ free throw
    free throw ;

: fcov.free-bucket ( bk -- )
    dup fcov.bk-uncov @
    dup IF
        ['] fcov.free-uncov over ulist-each
        ulist-dispose
    ELSE
        drop
    THEN
    dup fcov.bk-file-a @ free throw
    free throw ;

: fcov.buckets-clear
    ['] fcov.free-bucket fcov.buckets @ ulist-each
    fcov.buckets @ ulist-clear ;

\ --- Bucket lookup --------------------------------------------------------

variable fcov.bk-target-a
variable fcov.bk-target-u
variable fcov.bk-found

: fcov.bk-match-step ( bk -- )
    fcov.bk-found @ IF drop EXIT THEN
    dup fcov.bk-file-a @ over fcov.bk-file-u @
    fcov.bk-target-a @ fcov.bk-target-u @
    compare 0= IF fcov.bk-found ! ELSE drop THEN ;

: fcov.bucket-find { f-a f-u -- bk|0 }
    f-a fcov.bk-target-a !
    f-u fcov.bk-target-u !
    0 fcov.bk-found !
    ['] fcov.bk-match-step fcov.buckets @ ulist-each
    fcov.bk-found @ ;

: fcov.bucket-find-or-create { f-a f-u -- bk }
    f-a f-u fcov.bucket-find ?dup IF EXIT THEN
    fcov-bk% allocate throw { bk }
    f-a f-u fcov.str-dup
    bk fcov.bk-file-u !
    bk fcov.bk-file-a !
    0 bk fcov.bk-total !
    0 bk fcov.bk-covered !
    ulist-new bk fcov.bk-uncov !
    bk fcov.buckets @ ulist-add
    bk ;

: fcov.bucket-add-uncov { bk name-a name-u -- }
    fcov-un% allocate throw { un }
    name-a name-u fcov.str-dup
    un fcov.un-name-u !
    un fcov.un-name-a !
    un bk fcov.bk-uncov @ ulist-add ;

\ Walk the definition list, grouping by file. Only colon-defs
\ contribute to «covered / total» (matches aggregate.4th's summary
\ semantics — keeps the metric meaningful and aligned across reporters).

: fcov.bucket-ingest ( rec -- )
    >r
    r@ fcov.rec-type@ s" colon" compare 0<> IF rdrop EXIT THEN
    r@ fcov.rec-file@ fcov.bucket-find-or-create { bk }
    1 bk fcov.bk-total +!
    r@ fcov.rec-name@ fcov.hit-count@
    ?dup IF
        drop 1 bk fcov.bk-covered +!
    ELSE
        bk r@ fcov.rec-name@ fcov.bucket-add-uncov
    THEN
    rdrop ;

\ --- Emit -----------------------------------------------------------------

\ Emit (target - current) spaces, or none if current >= target.
: fcov.pad-to-width { current target -- }
    target current - dup 0> IF 0 ?do bl emit loop ELSE drop THEN ;

variable fcov.report-uncov-shown

: fcov.print-uncov-name ( un -- )
    fcov.report-uncov-shown @ 6 < IF
        fcov.report-uncov-shown @ 0> IF s" , " type THEN
        dup fcov.un-name-a @ over fcov.un-name-u @ type
    THEN
    1 fcov.report-uncov-shown +!
    drop ;

: fcov.print-bucket ( bk -- )
    cr s" * " type
    dup fcov.bk-file-a @ over fcov.bk-file-u @ type
    dup fcov.bk-file-u @ 28 fcov.pad-to-width
    s"  " type
    dup fcov.bk-covered @ fcov.u>str type
    s" /" type
    dup fcov.bk-total @ fcov.u>str type
    s"  (" type
    dup fcov.bk-covered @ over fcov.bk-total @ fcov.percent>str type
    s" %)" type

    dup fcov.bk-uncov @
    dup ulist-empty? 0= IF
        s"   uncovered: " type
        0 fcov.report-uncov-shown !
        ['] fcov.print-uncov-name swap ulist-each
        fcov.report-uncov-shown @ 6 > IF
            s"  …+" type
            fcov.report-uncov-shown @ 6 - fcov.u>str type
            s"  more" type
        THEN
    ELSE
        drop
    THEN
    drop ;

variable fcov.total-words
variable fcov.total-covered

: fcov.total-from-bucket ( bk -- )
    dup fcov.bk-total   @ fcov.total-words   +!
        fcov.bk-covered @ fcov.total-covered +! ;

: fcov.print-totals
    cr s" ----------------------------------------" type
    cr s" * TOTAL                       " type
    fcov.total-covered @ fcov.u>str type
    s" /" type
    fcov.total-words @ fcov.u>str type
    s"  (" type
    fcov.total-covered @ fcov.total-words @ fcov.percent>str type
    s" %)" type cr ;

: fcov.buckets-each ( xt -- )
    fcov.buckets @ ulist-each ;

: fcov.report-console
    fcov.buckets-clear
    ['] fcov.bucket-ingest fcov.recs-each
    \ ulist-add prepended; reverse so files print in walk order.
    fcov.buckets @ ulist-reverse
    cr s" fcov coverage report" type cr
    s"   (definitions found by walker, calls observed during run)" type cr
    ['] fcov.print-bucket fcov.buckets-each
    0 fcov.total-words !
    0 fcov.total-covered !
    ['] fcov.total-from-bucket fcov.buckets-each
    fcov.print-totals ;
