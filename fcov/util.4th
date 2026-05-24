\ fcov/util.4th — string and filesystem helpers shared across fcov modules.
\
\ Mirrors the same minimal API that fmix/util and flint/util provide so
\ a contributor moving between tools sees the same words. If we ever
\ want to share these, futils micro-lib would be the obvious extraction
\ target — until then, three identical 30-line files is cheaper than
\ another package dependency for everyone.

[UNDEFINED] fcov.str-dup [IF]
\ ( a u -- a' u ) Allocate a fresh u-byte buffer and copy a→a'.
\ Caller frees with `free throw`.
: fcov.str-dup ( a u -- a' u )
    dup allocate throw swap 2dup >r >r move r> r> ;
[THEN]

[UNDEFINED] fcov.str-concat [IF]
\ ( a1 u1 a2 u2 -- a3 u3 ) Allocate a fresh (u1+u2) buffer holding a1‖a2.
: fcov.str-concat { a1 u1 a2 u2 -- a3 u3 }
    u1 u2 + allocate throw { mem }
    a1 mem u1 move
    a2 mem u1 + u2 move
    mem u1 u2 + ;
[THEN]

[UNDEFINED] fcov.fs-join [IF]
\ ( dir-a dir-u name-a name-u -- joined-a joined-u )
\ Glue two path fragments with a single "/" between them. Caller frees.
: fcov.fs-join { d-a d-u n-a n-u -- a u }
    d-u n-u + 1+ allocate throw { dst }
    d-a dst d-u move
    [char] / dst d-u + c!
    n-a dst d-u 1+ + n-u move
    dst d-u 1+ n-u + ;
[THEN]

[UNDEFINED] fcov.ends-with? [IF]
\ ( a u s su -- f ) — true iff a/u ends with the s/su suffix.
: fcov.ends-with? { a u s su -- f }
    u su < IF false EXIT THEN
    a u su - + su s su compare 0= ;
[THEN]

[UNDEFINED] fcov.to-lower [IF]
: fcov.to-lower ( c -- c' )
    dup [char] A [char] Z 1+ within IF
        [char] a [char] A - +
    THEN ;
[THEN]

[UNDEFINED] fcov.ci-compare [IF]
\ ( a1 u1 a2 u2 -- n ) — case-insensitive compare; 0 = equal.
: fcov.ci-compare { a1 u1 a2 u2 -- n }
    u1 u2 <> IF u1 u2 - EXIT THEN
    u1 0 ?do
        a1 i + c@ fcov.to-lower
        a2 i + c@ fcov.to-lower
        <> IF 1 unloop EXIT THEN
    loop
    0 ;
[THEN]

[UNDEFINED] fcov.starts-with? [IF]
\ ( a u s su -- f ) — true iff a/u starts with the s/su prefix.
: fcov.starts-with? { a u s su -- f }
    u su < IF false EXIT THEN
    a su s su compare 0= ;
[THEN]

[UNDEFINED] fcov.contains? [IF]
\ ( a u s su -- f ) — true iff substring s/su occurs anywhere in a/u.
: fcov.contains? { a u s su -- f }
    su 0= IF true EXIT THEN
    u su < IF false EXIT THEN
    u su - 1+ 0 ?do
        a i + su s su compare 0= IF true unloop EXIT THEN
    loop
    false ;
[THEN]

[UNDEFINED] fcov.u>str [IF]
\ ( u -- a u ) — render unsigned integer via pictured numeric output.
\ Buffer is system-managed and reused on next conversion; caller must
\ either type/copy immediately or allocate.
: fcov.u>str ( u -- a u )
    0 <# #s #> ;
[THEN]

[UNDEFINED] fcov.percent>str [IF]
\ ( hits total -- a u ) — render integer percentage "NN" (or "100") into
\ pictured-output buffer. total=0 returns "0".
: fcov.percent>str ( hits total -- a u )
    dup 0= IF 2drop 0 fcov.u>str EXIT THEN
    swap 100 * swap / fcov.u>str ;
[THEN]

[UNDEFINED] fcov.shell-1 [IF]
\ ( a u -- ) — run a single shell line via `system`, freeing the buffer
\ afterwards. Convenience wrapper to keep the call sites tidy.
: fcov.shell-1 ( a u -- )
    2dup system
    drop free throw ;
[THEN]

[UNDEFINED] fcov.mkdir-p [IF]
\ ( a u -- ) — create directory (and any missing parents) via shell.
: fcov.mkdir-p ( a u -- )
    s" mkdir -p '" 2swap fcov.str-concat
    s" '" fcov.str-concat
    fcov.shell-1 ;
[THEN]

[UNDEFINED] fcov.chmod+x [IF]
\ ( a u -- ) — chmod +x a path via shell.
: fcov.chmod+x ( a u -- )
    s" chmod +x '" 2swap fcov.str-concat
    s" '" fcov.str-concat
    fcov.shell-1 ;
[THEN]
