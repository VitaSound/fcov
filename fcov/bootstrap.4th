\ fcov/bootstrap.4th — shared load chain for fcov CLI and in-process tests.

require fcov/util.4th

\ --- Self-version (read from package.4th) ---------------------------------

2variable fcov-ver-data
s" unknown" fcov-ver-data 2!

[UNDEFINED] fcov-home-path [IF]
: fcov-home-path ( -- a u )
    s" FCOV_HOME" getenv 2dup nip IF EXIT THEN
    2drop s" HOME" getenv s" /fcov" fcov.str-concat ;
[THEN]

\ Throwaway parser for package.4th — captures `key-value version <X>`.
MARKER fcov.discard-ver-parser

: forth-package ;
: end-forth-package ;
: key-list 0 parse 2drop ;
: key-value
    parse-name s" version" compare 0= IF
        parse-name fcov.str-dup fcov-ver-data 2!
    ELSE
        0 parse 2drop
    THEN ;

: fcov.read-self-version
    fcov-home-path s" /package.4th" fcov.str-concat { buf bu }
    buf bu 2dup file-status nip 0= IF
        included
    ELSE
        2drop
    THEN
    buf free throw ;

fcov.read-self-version

fcov.discard-ver-parser

\ Version-check parser uses its own throwaway scope; load *after* the
\ self-version parser is gone to avoid colliding key-value/key-list defs.
require fcov/version-check.4th

\ --- 0.2.0 pipeline modules -----------------------------------------------

require fcov/walk.4th
require fcov/scan.4th
require fcov/collect.4th
require fcov/exclude.4th
require fcov/prelude.4th
require fcov/aggregate.4th
require fcov/report-console.4th
require fcov/report-lcov.4th
require fcov/report-json.4th
require fcov/report-html.4th
