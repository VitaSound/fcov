\ fcov/exclude.4th — opt-out path filter for the walker.
\
\ Resolves ROADMAP open-question §3 («What's a project file?») by
\ letting users declare path prefixes to exclude from coverage in
\ their `./package.4th`:
\
\     forth-package
\         …
\         key-list fcov-exclude tests/fixtures
\         key-list fcov-exclude src/legacy
\     end-forth-package
\
\ Each entry is a *directory prefix*, matched against the relative
\ path the walker hands to the scan callback (e.g.
\ `./tests/fixtures/partial_cov/src/thing.4th`). For convenience the
\ pattern is normalised with a leading `./` and a trailing `/` so
\ `tests/fixtures` doesn't accidentally match `tests/fixtures-foo/…`.
\
\ Use cases:
\   - exclude integration-test fixtures (data, not project code);
\   - exclude vendored copies that don't ride the project's release;
\   - exclude generated code under `src/legacy` etc.
\
\ The `forth-packages/`, `build/`, `.fcov/` and `.<anything>` paths
\ are still excluded unconditionally by the walker itself.

require fcov/util.4th
require ../forth-packages/fenum/0.1.1/fenum-bs.4th

\ --- Storage --------------------------------------------------------------

begin-structure fcov-excl%
    field: fcov.excl-pat-a
    field: fcov.excl-pat-u
end-structure

variable fcov.excludes    ulist-new fcov.excludes !

: fcov.free-excl ( e -- )
    dup fcov.excl-pat-a @ free throw
    free throw ;

: fcov.excludes-clear
    ['] fcov.free-excl fcov.excludes @ ulist-each
    fcov.excludes @ ulist-clear ;

: fcov.excludes-count ( -- n )
    fcov.excludes @ ulist-len ;

\ Normalise a pattern: prepend "./" if it's not absolute, append "/"
\ if it isn't there yet. Returns a heap-allocated string the caller
\ owns (the record below takes ownership).

: fcov.normalize-pattern { p-a p-u -- a u }
    p-u 4 + allocate throw { dst }
    0 { off }
    p-a c@ [char] / <> IF
        [char] . dst         c!
        [char] / dst 1 +     c!
        2 to off
    THEN
    p-a dst off + p-u move
    off p-u + to off
    dst off + 1 - c@ [char] / <> IF
        [char] / dst off + c!
        off 1+ to off
    THEN
    dst off ;

: fcov.exclude-add { p-a p-u -- }
    p-u 0= IF EXIT THEN
    p-a p-u fcov.normalize-pattern { n-a n-u }
    fcov-excl% allocate throw { e }
    n-u e fcov.excl-pat-u !
    n-a e fcov.excl-pat-a !
    e fcov.excludes @ ulist-add ;

\ --- Match ---------------------------------------------------------------

variable fcov.excl-target-a
variable fcov.excl-target-u
variable fcov.excl-match?

: fcov.excl-step { e -- }
    fcov.excl-match? @ IF EXIT THEN
    fcov.excl-target-a @ fcov.excl-target-u @
    e fcov.excl-pat-a @ e fcov.excl-pat-u @
    fcov.starts-with? IF -1 fcov.excl-match? ! THEN ;

: fcov.path-excluded? { a u -- f }
    a fcov.excl-target-a !
    u fcov.excl-target-u !
    0 fcov.excl-match? !
    ['] fcov.excl-step fcov.excludes @ ulist-each
    fcov.excl-match? @ ;

\ --- Throwaway parser for ./package.4th ----------------------------------
\
\ Same MARKER pattern fcov uses elsewhere: define forth-package /
\ end-forth-package / key-value / key-list as throwaways that survive
\ only long enough to capture our keys, then expire.

MARKER fcov.discard-excl-parser

: forth-package ;
: end-forth-package ;
: key-value parse-name 2drop 0 parse 2drop ;

: key-list
    parse-name 2dup s" fcov-exclude" compare 0= IF
        2drop
        parse-name dup IF fcov.exclude-add ELSE 2drop THEN
        \ Drop any extra tokens on the same line — one path per line is
        \ the canonical form. Keeps the parser tiny and predictable.
        0 parse 2drop
    ELSE
        2drop 0 parse 2drop
    THEN ;

: fcov.cwd-package-path { -- a u }
    pad 4096 get-dir { pa pu }
    pa pu s" /package.4th" fcov.str-concat ;

: fcov.maybe-scan-excludes
    fcov.cwd-package-path 2dup file-status nip 0= IF
        2dup included
    THEN
    drop free throw ;

fcov.maybe-scan-excludes

fcov.discard-excl-parser
