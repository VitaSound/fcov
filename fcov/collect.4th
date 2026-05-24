\ fcov/collect.4th — in-memory accumulator for definitions found by
\ fcov/scan.4th, plus a JSON serialiser for `.fcov/defs.json` and a
\ lookup primitive used by the aggregator.
\
\ Storage: fenum's `ulist` (linked-list container with a stable
\ head/iterator API). Each record is its own heap-allocated
\ begin-structure block holding two heap-allocated strings (file,
\ name) and a static reference to the type-literal owned by scan.4th.
\
\ Note on iteration order: `ulist-add` prepends to head, so a fresh
\ traversal yields newest-first. We don't depend on order for
\ correctness (defs.json, console table and lcov reporter all group
\ by their own keys), and we explicitly reverse the catalogue once
\ after the scan so JSON output is roughly file-by-file in walk
\ order — the human-readable shape one would expect.

require fcov/util.4th
require fcov/scan.4th
require ../forth-packages/fenum/0.1.1/fenum-bs.4th

\ --- Record layout --------------------------------------------------------

begin-structure fcov-rec%
    field: fcov.rec-file-a
    field: fcov.rec-file-u
    field: fcov.rec-line
    field: fcov.rec-type-a   \ static — owned by scan.4th, do not free
    field: fcov.rec-type-u
    field: fcov.rec-name-a
    field: fcov.rec-name-u
end-structure

\ --- The list -------------------------------------------------------------

variable fcov.recs    ulist-new fcov.recs !

: fcov.recs-count ( -- n )  fcov.recs @ ulist-len ;

: fcov.free-rec ( rec -- )
    dup fcov.rec-file-a @ free throw
    dup fcov.rec-name-a @ free throw
    free throw ;

: fcov.recs-clear
    ['] fcov.free-rec fcov.recs @ ulist-each
    fcov.recs @ ulist-clear ;

: fcov.recs-reverse
    fcov.recs @ ulist-reverse ;

\ --- Append ---------------------------------------------------------------

: fcov.recs-append
        ( file-a file-u line type-a type-u name-a name-u -- )
    fcov-rec% allocate throw { rec }
    fcov.str-dup rec fcov.rec-name-u !
                 rec fcov.rec-name-a !
    rec fcov.rec-type-u !
    rec fcov.rec-type-a !
    rec fcov.rec-line !
    fcov.str-dup rec fcov.rec-file-u !
                 rec fcov.rec-file-a !
    rec fcov.recs @ ulist-add ;

\ Wire scanner → collector.
:noname fcov.recs-append ; is fcov.on-defined-word

\ --- Iteration ------------------------------------------------------------

: fcov.recs-each ( xt -- )
    fcov.recs @ ulist-each ;

\ --- Accessors ------------------------------------------------------------

: fcov.rec-file@ ( rec -- a u )  dup fcov.rec-file-a @ swap fcov.rec-file-u @ ;
: fcov.rec-name@ ( rec -- a u )  dup fcov.rec-name-a @ swap fcov.rec-name-u @ ;
: fcov.rec-type@ ( rec -- a u )  dup fcov.rec-type-a @ swap fcov.rec-type-u @ ;
: fcov.rec-line@ ( rec -- n   )  fcov.rec-line @ ;

\ --- Lookup ---------------------------------------------------------------
\
\ ulist-each has no early-exit, so we walk the whole list and stash the
\ first match in a module-local cell. The volume is small enough that
\ O(N) lookup doesn't show up in profiles for typical project sizes.

variable fcov.lookup-target-a
variable fcov.lookup-target-u
variable fcov.lookup-result    \ rec or 0

: fcov.lookup-step ( rec -- )
    fcov.lookup-result @ IF drop EXIT THEN
    dup fcov.rec-name@
    fcov.lookup-target-a @
    fcov.lookup-target-u @
    compare 0= IF fcov.lookup-result ! ELSE drop THEN ;

: fcov.recs-find { name-a name-u -- rec true | false }
    name-a fcov.lookup-target-a !
    name-u fcov.lookup-target-u !
    0 fcov.lookup-result !
    ['] fcov.lookup-step fcov.recs-each
    fcov.lookup-result @ ?dup IF true ELSE false THEN ;

\ --- JSON writer ----------------------------------------------------------
\
\ Schema:
\   {
\     "words": [
\       { "name": "...", "file": "...", "line": NN, "type": "..." },
\       …
\     ]
\   }
\
\ String-escape: backslash and quote get backslash-escaped, control chars
\ < 0x20 are emitted as \uXXXX, everything else passes through. Forth
\ source rarely contains control chars in identifiers so the slow path
\ is mostly cold.

variable fcov.json-fid

: fcov.json-emit ( a u -- )
    fcov.json-fid @ write-file throw ;

: fcov.json-emit-c ( c -- )
    pad c! pad 1 fcov.json-emit ;

: fcov.json-hex-digit ( n -- c )
    dup 10 < IF [char] 0 + ELSE 10 - [char] a + THEN ;

: fcov.json-escape-char ( c -- )
    dup [char] " = IF drop s\" \\\"" fcov.json-emit EXIT THEN
    dup [char] \ = IF drop s\" \\\\" fcov.json-emit EXIT THEN
    dup 8     = IF drop s\" \\b"  fcov.json-emit EXIT THEN
    dup 9     = IF drop s\" \\t"  fcov.json-emit EXIT THEN
    dup 10    = IF drop s\" \\n"  fcov.json-emit EXIT THEN
    dup 12    = IF drop s\" \\f"  fcov.json-emit EXIT THEN
    dup 13    = IF drop s\" \\r"  fcov.json-emit EXIT THEN
    dup 32 < IF
        s\" \\u00" fcov.json-emit
        dup 16 / fcov.json-hex-digit fcov.json-emit-c
        16 mod   fcov.json-hex-digit fcov.json-emit-c
        EXIT
    THEN
    fcov.json-emit-c ;

: fcov.json-escape ( a u -- )
    0 ?do
        dup c@ fcov.json-escape-char
        1+
    loop
    drop ;

: fcov.json-quoted ( a u -- )
    s\" \"" fcov.json-emit
    fcov.json-escape
    s\" \"" fcov.json-emit ;

: fcov.json-uint ( u -- )
    fcov.u>str fcov.json-emit ;

variable fcov.json-first?

: fcov.json-write-rec ( rec -- )
    fcov.json-first? @ IF
        s\" ,\n" fcov.json-emit
    THEN
    -1 fcov.json-first? !
    s\"     {\"name\": " fcov.json-emit
    dup fcov.rec-name@ fcov.json-quoted
    s\" , \"file\": "    fcov.json-emit
    dup fcov.rec-file@ fcov.json-quoted
    s\" , \"line\": "    fcov.json-emit
    dup fcov.rec-line@ fcov.json-uint
    s\" , \"type\": "    fcov.json-emit
        fcov.rec-type@ fcov.json-quoted
    s" }" fcov.json-emit ;

: fcov.write-defs-json { fname-a fname-u -- }
    fname-a fname-u w/o create-file throw fcov.json-fid !
    s\" {\"words\": [\n" fcov.json-emit
    0 fcov.json-first? !
    ['] fcov.json-write-rec fcov.recs-each
    s\" \n]}\n" fcov.json-emit
    fcov.json-fid @ close-file throw
    0 fcov.json-fid ! ;
