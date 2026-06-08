\ tests/fcov_commands_test.4th — CLI command words in an isolated temp tree.

: fcov.test-setup
    s" FCOV_HOME" getenv 2dup nip 0= IF
        2drop 0 ( bye ) THEN
    fpath also-path ;
fcov.test-setup

s" forth-packages/ttester/1.2.1/ttester.4th" included

require fcov/bootstrap.4th
require fcov/commands.4th

0 #ERRORS !

: fcov.test-sh system $? ;

: fcov.test-set-cmd ( arg-a arg-u rest-a rest-u -- )
    fcov.str-dup fcov.rest 2!
    fcov.str-dup fcov.arg 2! ;

: fcov.test-write-file { content-a content-u fname-a fname-u -- }
    fname-a fname-u w/o create-file throw { fid }
    content-a content-u fid write-file throw
    fid close-file throw ;

: fcov.test-use-tmp
    s" rm -rf /tmp/fcov-cmd-test && mkdir -p /tmp/fcov-cmd-test/src" fcov.test-sh drop
    s" cd /tmp/fcov-cmd-test" fcov.test-sh drop
    pad 4096 get-dir fcov.str-dup fcov.cwd 2! ;

: fcov.test-under-instrumentation?
    s" FCOV_CALLS_LOG" getenv nip 0<> ;

: fcov.test-run-words
    fcov.help
    fcov.version
    fcov.test-under-instrumentation? IF exit THEN
    fcov.test-use-tmp
    s" : word-a ;" s" /tmp/fcov-cmd-test/src/a.4th" fcov.test-write-file
    s" gforth" s" no-such-test.4th" fcov.test-set-cmd
    fcov.test-cmd drop free throw
    fcov.run-prepare-tree
    fcov.collect-defs
    s" --format" fcov.str-dup fcov.arg 2!
    s" lcov" fcov.str-dup fcov.rest 2!
    fcov.report-format 2drop
    fcov.report ;

T{ fcov.test-run-words -> }T

: report
    s" rm -rf /tmp/fcov-cmd-test" fcov.test-sh drop
    #ERRORS @ 0= IF cr ." fcov_commands_test ok" cr
    ELSE cr ." fcov_commands_test FAILED: " #ERRORS @ . cr 1 ( bye ) THEN ;
report
bye
