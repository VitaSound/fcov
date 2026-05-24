\ fcov/version-check.4th — read the project's `./package.4th` and warn
\ (don't fail) if the installed fcov doesn't satisfy
\ `key-value fcov <req>`.
\
\ Same Elixir/Hex grammar as fmix & flint use, delegated to the shared
\ fsemver engine (vendored at forth-packages/fsemver/0.1.0/). See
\ fsemver's README for the full operator table (~>, >=, ==, >, <, <=,
\ bare X.Y.Z).
\
\ Examples:
\
\   key-value fcov ~> 0.1          \ MAJOR pinned
\   key-value fcov ~> 0.1.3        \ MAJOR+MINOR pinned
\   key-value fcov >= 0.1.0        \ minimum, no upper bound
\   key-value fcov 0.1.0           \ bare = >= 0.1.0
\
\ Like flint (and unlike fmix), a mismatch is *warn-only*: fcov reports
\ but doesn't refuse to run. Coverage data is useful even from the
\ "wrong" version, and a hard gate here would block CI for cosmetic
\ reasons. May tighten in a future major bump.
\
\ The legacy form `key-list dependencies fcov <ver>` is detected and
\ surfaced as a WARN with a migration hint.
\
\ Expects `fcov-ver-data` (a 2variable holding the installed fcov
\ version) to be set by fcov.4th before we are loaded.

require fcov/util.4th
require forth-packages/fsemver/0.1.0/fsemver.4th

\ --- Stored state -------------------------------------------------------

2variable fcov.required-req      0 0 fcov.required-req 2!
variable  fcov.legacy-self-dep?  0 fcov.legacy-self-dep? !

: fcov.set-required-req ( a u -- )
    fcov.str-dup fcov.required-req 2! ;

\ --- Throw-away DSL parser for ./package.4th ---------------------------
\
\ MARKER scope: forth-package / end-forth-package / key-value / key-list
\ are throwaway. After MARKER expiration only the captured variables
\ survive — the public API below picks them up.

MARKER fcov.discard-vercheck-parser

: forth-package ;
: end-forth-package ;

: key-value
    parse-name 2dup s" fcov" compare 0= IF
        2drop 0 parse fsemver.strip-ws fcov.set-required-req
    ELSE
        2drop 0 parse 2drop
    THEN ;

: key-list
    parse-name 2dup s" dependencies" compare 0= IF
        2drop
        parse-name 2dup s" fcov" compare 0= IF
            2drop true fcov.legacy-self-dep? !
            0 parse 2drop
        ELSE
            2drop 0 parse 2drop
        THEN
    ELSE
        2drop 0 parse 2drop
    THEN ;

\ Build absolute "$(cwd)/package.4th" so `included` doesn't depend on
\ gforth's "./ is relative to the source file's dir" convention.
: fcov.cwd-package-path { -- a u }
    pad 4096 get-dir { pa pu }
    pa pu s" /package.4th" fcov.str-concat ;

: fcov.maybe-scan-package
    fcov.cwd-package-path 2dup file-status nip 0= IF
        2dup included
    THEN
    drop free throw ;

fcov.maybe-scan-package

fcov.discard-vercheck-parser

\ --- Public API (defined *after* MARKER expiration so they survive) ----

: fcov.warn-legacy
    cr s" [WARN] Project's package.4th uses pre-0.1 form:" type cr
    s"            key-list dependencies fcov <version>" type cr
    s"        fcov is a runtime/tooling requirement, not a library." type cr
    s"        Recommended migration (one-line edit):" type cr
    s"            key-value fcov ~> <X.Y>" type cr ;

: fcov.warn-invalid-req
    cr s" [WARN] Invalid fcov version requirement in package.4th:" type cr
    s"            key-value fcov " type fcov.required-req 2@ type cr
    s"        Expected one of: ~> X.Y, ~> X.Y.Z, >= X.Y.Z, == X.Y.Z," type cr
    s"                         >  X.Y.Z, <  X.Y.Z, <= X.Y.Z, or bare X.Y.Z" type cr ;

: fcov.warn-too-old
    cr s" [WARN] This project requires fcov " type
    fcov.required-req 2@ type
    s" , but you have " type fcov-ver-data 2@ type cr
    s"        Continuing anyway — fcov won't block coverage collection." type cr ;

: fcov.check-required-version
    fcov.legacy-self-dep? @ IF fcov.warn-legacy EXIT THEN
    fcov.required-req 2@ nip 0= IF EXIT THEN

    fcov.required-req 2@ fsemver.parse-req { rop rma rmi rpa rok }
    rok 0= IF fcov.warn-invalid-req EXIT THEN

    fcov-ver-data 2@ fsemver.parse-version-parts drop { sma smi spa }
    rma rmi rpa rop sma smi spa fsemver.req-matches? 0= IF
        fcov.warn-too-old EXIT
    THEN ;
