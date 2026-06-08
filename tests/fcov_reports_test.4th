\ tests/fcov_reports_test.4th — in-process reporter smoke (no fixture cd).

: fcov.test-setup
    s" FCOV_HOME" getenv 2dup nip 0= IF
        2drop 0 ( bye ) THEN
    fpath also-path ;
fcov.test-setup

s" forth-packages/ttester/1.2.1/ttester.4th" included

require fcov/bootstrap.4th

0 #ERRORS !

: fcov.test-write-shard
    s" /tmp/fcov-rep.log" w/o create-file throw { fid }
    s" covered-a\n" fid write-file throw
    fid close-file throw ;

: fcov.test-write-file { content-a content-u fname-a fname-u -- }
    fname-a fname-u w/o create-file throw { fid }
    content-a content-u fid write-file throw
    fid close-file throw ;

: fcov.test-seed-recs
    fcov.recs-clear fcov.hits-clear
    s" : covered-a ; : uncovered-b ;" s" /tmp/rep.4th" fcov.test-write-file
    s" /tmp/rep.4th" 1 s" colon" s" covered-a" fcov.recs-append
    s" /tmp/rep.4th" 2 s" colon" s" uncovered-b" fcov.recs-append
    fcov.test-write-shard
    s" /tmp/fcov-rep.log" fcov.ingest-shard ;

: fcov.test-all-reports
    fcov.test-seed-recs
    fcov.report-console
    fcov.report-lcov
    fcov.report-json
    fcov.report-html ;

T{ fcov.test-all-reports -> }T

: report
    s" /tmp/fcov-rep.log" delete-file drop
    s" /tmp/rep.4th" delete-file drop
    #ERRORS @ 0= IF cr ." fcov_reports_test ok" cr
    ELSE cr ." fcov_reports_test FAILED: " #ERRORS @ . cr 1 ( bye ) THEN ;
report
bye
