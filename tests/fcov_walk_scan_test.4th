\ tests/fcov_walk_scan_test.4th — unit tests for fcov/walk.4th and fcov/scan.4th.

: fcov.test-setup
    s" FCOV_HOME" getenv 2dup nip 0= IF
        cr ." [SKIP] fcov_walk_scan_test needs FCOV_HOME" cr
        2drop 0 ( bye )
    THEN
    fpath also-path ;
fcov.test-setup

s" forth-packages/ttester/1.2.1/ttester.4th" included

require fcov/util.4th
require fcov/walk.4th
require fcov/scan.4th
require fcov/exclude.4th
require fcov/collect.4th

0 #ERRORS !


: fcov.test-write-file { content-a content-u fname-a fname-u -- }
    fname-a fname-u w/o create-file throw { fid }
    content-a content-u fid write-file throw
    fid close-file throw ;

: fcov.test-init-tree
    s" rm -rf /tmp/fcov-walk-scan && mkdir -p /tmp/fcov-walk-scan/sub" system $? drop
    s" : hello ;" s" /tmp/fcov-walk-scan/colon.4th" fcov.test-write-file
    s" variable x" s" /tmp/fcov-walk-scan/var.4th" fcov.test-write-file
    s" : subword ;" s" /tmp/fcov-walk-scan/sub/nested.4th" fcov.test-write-file ;

: fcov.test-walk-drop ( a u -- ) 2drop ;

: fcov.test-run
    fcov.test-init-tree
    fcov.recs-clear
    s" /tmp/fcov-walk-scan/colon.4th" fcov.scan-file
    s" /tmp/fcov-walk-scan/var.4th" fcov.scan-file
    s" /tmp/fcov-walk-scan" fcov.walk-collect
    ['] fcov.test-walk-drop fcov.walk-foreach ;

T{ fcov.test-run -> }T
T{ fcov.recs-count 2 >= -> true }T

: report
    s" rm -rf /tmp/fcov-walk-scan" system $? drop
    #ERRORS @ 0= IF
        cr ." fcov_walk_scan_test ok" cr
    ELSE
        cr ." fcov_walk_scan_test FAILED: " #ERRORS @ . ." errors" cr
        1 ( bye )
    THEN ;
report
bye
