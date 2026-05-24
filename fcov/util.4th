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
: fcov.str-concat ( a1 u1 a2 u2 -- a3 u3 )
    >r >r 2dup r@ + dup allocate throw { dst }
    dst swap move
    2drop dst dup over swap drop
    over r> + r> move ;
[THEN]

[UNDEFINED] fcov.fs-join [IF]
\ ( dir-a dir-u name-a name-u -- joined-a joined-u )
\ Glue two path fragments with a single "/" between them. Caller frees.
: fcov.fs-join ( dir-a dir-u name-a name-u -- joined-a joined-u )
    2>r 2dup + 1+ allocate throw { dst }
    dst swap dup { dlen } move
    [char] / dst dlen + c!
    dlen 1+ { off }
    2r> dst off + swap dup { nlen } move
    dst dlen 1+ nlen + ;
[THEN]
