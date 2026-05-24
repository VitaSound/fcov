\ fcov/walk.4th — pure-Forth recursive directory walker.
\
\ Vendored & adapted from flint/walk.4th. Same shape, different prefix.
\ Walks the project tree once per `fcov run`, calling a user-supplied
\ xt for every regular `.4th` file it finds. Callers (collect.4th)
\ stack the scanner on top of this to slurp every project source file.
\
\ Public API:
\
\   fcov.walk-collect ( root-a root-u -- )
\       Remember the root we will walk. Just stores the path; the actual
\       traversal happens lazily inside walk-foreach.
\
\   fcov.walk-foreach { xt -- }
\       Walk the remembered root recursively and call
\       `xt ( path-a path-u -- )` for every regular file whose name ends
\       in `.4th`. Path strings handed to xt live on the heap and are
\       freed immediately after xt returns — xt must dup what it wants
\       to keep.
\
\ Skipped entries:
\   - empty names (defensive),
\   - any name starting with '.'  (covers `.`, `..`, `.git`, `.fcov`, hidden …),
\   - directories named exactly `build`           (project build output),
\   - directories named exactly `forth-packages`  (vendored deps; not own code).

require fcov/util.4th

2variable fcov.walk-root      0 0 fcov.walk-root 2!
variable  fcov.walk-xt        0 fcov.walk-xt !

256 constant fcov.walk-name-max
create fcov.walk-name-buf fcov.walk-name-max allot

: fcov.walk-skip? { a u -- f }
    u 0= IF true EXIT THEN
    a c@ [char] . = IF true EXIT THEN
    a u s" build"          compare 0= IF true EXIT THEN
    a u s" forth-packages" compare 0= IF true EXIT THEN
    false ;

\ Probe a path: try to open it as a directory. On success we leave the
\ dir handle on the stack; on failure we leave just `false`.
: fcov.walk-try-dir ( a u -- dirid true | false )
    open-dir IF drop false EXIT THEN
    true ;

\ Allocate root + "/" + name and return the new string.
: fcov.walk-join { root-a root-u name-a name-u -- p-a p-u }
    root-u name-u + 1+ allocate throw { buf }
    root-a buf root-u move
    [char] / buf root-u + c!
    name-a buf root-u 1+ + name-u move
    buf root-u name-u + 1+ ;

\ Forward declaration so the implementation can recurse without
\ relying on `recurse` (which interacts awkwardly with mid-definition
\ local frames).
defer fcov.walk-dir-rec

: fcov.walk-dir-impl { path-a path-u -- }
    path-a path-u open-dir throw { dirid }
    begin
        fcov.walk-name-buf fcov.walk-name-max dirid read-dir throw
    while                                          ( u-read )
        fcov.walk-name-buf swap                    ( n-a n-u )
        2dup fcov.walk-skip? IF
            2drop
        ELSE
            { n-a n-u }
            path-a path-u n-a n-u fcov.walk-join { c-a c-u }
            c-a c-u fcov.walk-try-dir IF           ( dirid )
                close-dir throw
                c-a c-u fcov.walk-dir-rec
            ELSE
                c-a c-u s" .4th" fcov.ends-with? IF
                    c-a c-u fcov.walk-xt @ execute
                THEN
            THEN
            c-a free throw
        THEN
    repeat
    drop                                           \ trailing u-read
    dirid close-dir throw ;

' fcov.walk-dir-impl is fcov.walk-dir-rec

: fcov.walk-collect ( root-a root-u -- )
    fcov.walk-root 2@ drop ?dup IF free throw THEN
    fcov.str-dup fcov.walk-root 2! ;

: fcov.walk-foreach { xt -- }
    xt fcov.walk-xt !
    fcov.walk-root 2@ fcov.walk-dir-rec ;
