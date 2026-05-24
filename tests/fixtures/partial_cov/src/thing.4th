\ src/thing.4th — fixture source #1.
\ Defines two colon-words and one variable so the integration test can
\ assert «partial coverage»: thing.covered runs, thing.uncovered does not.

variable thing.tmp-buf

: thing.covered ( -- )
    1 2 + drop ;

: thing.uncovered ( -- )
    \ deliberately never called by tests/run.4th — drives the
    \ «uncovered» assertion in the integration test.
    99 99 + drop ;
