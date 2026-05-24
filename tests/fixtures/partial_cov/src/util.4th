\ src/util.4th — fixture source #2.
\ Two more colon-defs, only one of which is exercised. Combined with
\ src/thing.4th this gives 2/4 covered / 4 total = 50% project coverage.

: util.helper ( -- )
    bl drop ;

: util.dead-code ( -- )
    13 13 + drop ;
