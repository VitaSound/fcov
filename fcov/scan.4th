\ fcov/scan.4th — tokenise a single .4th file and emit defining-word events
\ with their source location (file, line) and definition type.
\
\ Vendored & adapted from flint/scan.4th. Two extensions over the flint
\ version:
\
\   1. We track 1-based line numbers as the scanner advances, and report
\      the line on which each defining-word's *name* begins.
\   2. We tag each event with the defining word's spelling (lower-cased
\      string: "colon", "defer", "variable", "constant", "value", …) so
\      downstream consumers (aggregator, prelude generator) can filter
\      by definition type without re-doing the lex.
\
\ Recognised defining words (case-insensitive):
\
\   :  variable 2variable fvariable
\   constant 2constant fconstant
\   value 2value fvalue
\   create defer marker
\   field field: cfield: nfield: ufield:
\   code synonym
\
\ When such a word is seen, the *next* code token is treated as the name
\ being defined and reported via the deferred `fcov.on-defined-word` hook.
\
\ `:noname` is explicitly skipped (no name → nothing to report).
\
\ Comments, strings and conditional-compilation directives are treated
\ uniformly: skipped over so we don't mistake their contents for
\ definitions. We deliberately do *not* honour `[IF]/[ELSE]/[THEN]`
\ branches — a definition inside a `[IF] 0 [THEN]` block still appears
\ in the static catalogue. This matches flint's «pessimistic» approach
\ and keeps the scanner side-effect-free.

require fcov/util.4th

\ --- Scan-time mutable buffer ----------------------------------------------

2variable fcov.scan-buf
variable  fcov.scan-pos
variable  fcov.scan-line       \ 1-based line counter
variable  fcov.scan-token-line \ line on which the most recent token started

: fcov.scan-set ( a u -- )
    fcov.scan-buf 2!
    0 fcov.scan-pos !
    1 fcov.scan-line !
    1 fcov.scan-token-line ! ;

: fcov.scan-end? ( -- f )
    fcov.scan-pos @ fcov.scan-buf 2@ nip >= ;

: fcov.scan-peek ( -- c|0 )
    fcov.scan-end? IF 0 EXIT THEN
    fcov.scan-buf 2@ drop fcov.scan-pos @ + c@ ;

: fcov.scan-advance ( -- )
    fcov.scan-end? IF EXIT THEN
    fcov.scan-peek 10 = IF 1 fcov.scan-line +! THEN
    1 fcov.scan-pos +! ;

: fcov.scan-skip-ws
    begin
        fcov.scan-end? IF EXIT THEN
        fcov.scan-peek bl > IF EXIT THEN
        fcov.scan-advance
    again ;

\ Consume up to and including a newline.
: fcov.scan-skip-line
    begin
        fcov.scan-end? IF EXIT THEN
        fcov.scan-peek 10 = IF fcov.scan-advance EXIT THEN
        fcov.scan-advance
    again ;

\ Consume up to (and including) the given delimiter char.
: fcov.scan-skip-to-char { c -- }
    begin
        fcov.scan-end? IF EXIT THEN
        fcov.scan-peek c = IF fcov.scan-advance EXIT THEN
        fcov.scan-advance
    again ;

\ Read the next whitespace-separated token into addr-in-buffer + length.
\ Side effect: stamps `fcov.scan-token-line` with the line on which the
\ token's first character lives — this is the value reported as «line»
\ for the defining-word event.
: fcov.scan-next-token ( -- a u )
    fcov.scan-skip-ws
    fcov.scan-line @ fcov.scan-token-line !
    fcov.scan-end? IF 0 0 EXIT THEN
    fcov.scan-buf 2@ drop fcov.scan-pos @ +     ( tok-a )
    0                                            ( tok-a tok-u )
    begin
        fcov.scan-end? IF EXIT THEN
        fcov.scan-peek bl <= IF EXIT THEN
        1+
        fcov.scan-advance
    again ;

\ --- Defining-word recognition --------------------------------------------
\
\ Returns ( type-a type-u true ) on match, ( false ) on miss. The
\ type string is a static literal owned by this module, so callers may
\ safely keep the (a, u) pair without copying.

: fcov.def-kind { tok-a tok-u -- type-a type-u true | false }
    tok-a tok-u s" :"          fcov.ci-compare 0= IF s" colon"      true EXIT THEN
    tok-a tok-u s" defer"      fcov.ci-compare 0= IF s" defer"      true EXIT THEN
    tok-a tok-u s" variable"   fcov.ci-compare 0= IF s" variable"   true EXIT THEN
    tok-a tok-u s" 2variable"  fcov.ci-compare 0= IF s" 2variable"  true EXIT THEN
    tok-a tok-u s" fvariable"  fcov.ci-compare 0= IF s" fvariable"  true EXIT THEN
    tok-a tok-u s" constant"   fcov.ci-compare 0= IF s" constant"   true EXIT THEN
    tok-a tok-u s" 2constant"  fcov.ci-compare 0= IF s" 2constant"  true EXIT THEN
    tok-a tok-u s" fconstant"  fcov.ci-compare 0= IF s" fconstant"  true EXIT THEN
    tok-a tok-u s" value"      fcov.ci-compare 0= IF s" value"      true EXIT THEN
    tok-a tok-u s" 2value"     fcov.ci-compare 0= IF s" 2value"     true EXIT THEN
    tok-a tok-u s" fvalue"     fcov.ci-compare 0= IF s" fvalue"     true EXIT THEN
    tok-a tok-u s" create"     fcov.ci-compare 0= IF s" create"     true EXIT THEN
    tok-a tok-u s" marker"     fcov.ci-compare 0= IF s" marker"     true EXIT THEN
    tok-a tok-u s" field"      fcov.ci-compare 0= IF s" field"      true EXIT THEN
    tok-a tok-u s" field:"     fcov.ci-compare 0= IF s" field"      true EXIT THEN
    tok-a tok-u s" cfield:"    fcov.ci-compare 0= IF s" field"      true EXIT THEN
    tok-a tok-u s" nfield:"    fcov.ci-compare 0= IF s" field"      true EXIT THEN
    tok-a tok-u s" ufield:"    fcov.ci-compare 0= IF s" field"      true EXIT THEN
    tok-a tok-u s" code"       fcov.ci-compare 0= IF s" code"       true EXIT THEN
    tok-a tok-u s" synonym"    fcov.ci-compare 0= IF s" synonym"    true EXIT THEN
    false ;

\ String-literal openers (consume up to the matching ")
: fcov.string-opener? { tok-a tok-u -- f }
    tok-a tok-u s\" s\""        compare 0= IF true EXIT THEN
    tok-a tok-u s\" .\""        compare 0= IF true EXIT THEN
    tok-a tok-u s\" c\""        compare 0= IF true EXIT THEN
    tok-a tok-u s\" s\\\""      compare 0= IF true EXIT THEN
    tok-a tok-u s\" abort\""    compare 0= IF true EXIT THEN
    false ;

\ --- Event hook -----------------------------------------------------------
\
\ Bound by collect.4th (or by tests). Default is a no-op so scan.4th can
\ be loaded and exercised in isolation.

defer fcov.on-defined-word
\ ( file-a file-u line type-a type-u name-a name-u -- )

:noname 2drop 2drop drop 2drop ; is fcov.on-defined-word

\ --- Whole-file scan ------------------------------------------------------

\ Like scan-next-token but skips line comments, paren comments and string
\ literals — i.e. returns the next *code* token. Used to read the name
\ slot after a defining word so that `: ( foo ) bar ;` correctly skips
\ the paren comment and registers `bar` rather than `(`.
: fcov.scan-next-code-token ( -- a u )
    begin
        fcov.scan-next-token dup 0= IF EXIT THEN
        { ta tu }
        ta tu s" \" compare 0= IF
            fcov.scan-skip-line
        ELSE ta tu s" (" compare 0= IF
            [char] ) fcov.scan-skip-to-char
        ELSE ta tu fcov.string-opener? IF
            [char] " fcov.scan-skip-to-char
        ELSE
            ta tu EXIT
        THEN THEN THEN
    again ;

\ slurp the file, walk tokens, free.
: fcov.scan-file { fname-a fname-u -- }
    fname-a fname-u slurp-file fcov.scan-set
    begin
        fcov.scan-next-token { tok-a tok-u }
        tok-u 0= IF
            fcov.scan-buf 2@ drop free throw
            EXIT
        THEN
        tok-a tok-u s" \" compare 0= IF
            fcov.scan-skip-line
        ELSE tok-a tok-u s" (" compare 0= IF
            [char] ) fcov.scan-skip-to-char
        ELSE tok-a tok-u fcov.string-opener? IF
            [char] " fcov.scan-skip-to-char
        ELSE tok-a tok-u s" :noname" fcov.ci-compare 0= IF
            \ :noname has no name to report — keep scanning the body.
            \ The matching ; is just another token; no-op.
        ELSE tok-a tok-u fcov.def-kind IF        ( type-a type-u )
            { ty-a ty-u }
            \ scan-token-line currently points at the defining word.
            \ scan-next-code-token will overwrite it with the *name*'s
            \ line; that's the value we report — humans scanning the
            \ source would point at the name, not the `:`.
            fcov.scan-next-code-token { name-a name-u }
            name-u 0= IF
                fcov.scan-buf 2@ drop free throw
                EXIT
            THEN
            fname-a fname-u
            fcov.scan-token-line @
            ty-a ty-u
            name-a name-u
            fcov.on-defined-word
        THEN THEN THEN THEN THEN
    again ;
