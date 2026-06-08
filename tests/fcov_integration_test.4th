\ tests/fcov_integration_test.4th
\
\ fcov-visible integration: in-process pipeline + version-check warns.
\ Heavy CLI end-to-end is covered by fcov_integration_test.sh.

: fcov.test-setup
    s" FCOV_HOME" getenv 2dup nip 0= IF
        cr ." [SKIP] fcov_integration_test needs FCOV_HOME" cr
        2drop 0 ( bye )
    THEN
    fpath also-path ;
fcov.test-setup

s" forth-packages/ttester/1.2.1/ttester.4th" included

require fcov/bootstrap.4th
require fcov/commands.4th

0 #ERRORS !

2variable fcov.test-fixture-path
2variable fcov.test-cd-fixture-cmd
2variable fcov.test-cd-home-cmd
2variable fcov.test-seed-calls-cmd

: fcov.test-sh ( cmd-a cmd-u -- status ) system $? ;

: fcov.test-init-paths
    s" FCOV_HOME" getenv { ha hu }
    ha hu s" /tests/fixtures/partial_cov" fcov.str-concat
    fcov.str-dup fcov.test-fixture-path 2!
    fcov.test-fixture-path 2@ s" cd '" 2swap fcov.str-concat
    s" '" fcov.str-concat fcov.str-dup fcov.test-cd-fixture-cmd 2!
    ha hu s" cd '" 2swap fcov.str-concat
    s" '" fcov.str-concat fcov.str-dup fcov.test-cd-home-cmd 2!
    ha hu s" /tests/fixtures/partial_cov/.fcov/calls" fcov.str-concat { sa su }
    sa su s" cp '" 2swap fcov.str-concat s" '" fcov.str-concat
    s" /" fcov.str-concat s" *.log .fcov/calls/" fcov.str-concat
    fcov.str-dup fcov.test-seed-calls-cmd 2!
    sa free throw ;

fcov.test-init-paths

: fcov.test-use-fixture
    fcov.test-cd-fixture-cmd 2@ fcov.test-sh abort" cd fixture failed"
    pad 4096 get-dir fcov.str-dup fcov.cwd 2! ;

: fcov.test-set-cmd ( arg-a arg-u rest-a rest-u -- )
    fcov.str-dup fcov.rest 2!
    fcov.str-dup fcov.arg 2! ;

: fcov.test-seed-fixture-calls
    fcov.test-seed-calls-cmd 2@ fcov.test-sh drop ;

: fcov.test-pipeline-no-exec
    fcov.test-use-fixture
    s" rm -rf .fcov" fcov.test-sh drop
    fcov.run-prepare-tree
    fcov.test-seed-fixture-calls
    fcov.collect-defs
    s" .fcov/defs.json" fcov.write-defs-json
    s" .fcov/_prelude.4th" fcov.write-prelude
    s" .fcov/bin/gforth" w/o create-file throw { fid }
    fid fcov.write-shim
    fid close-file throw
    s" .fcov/bin/gforth" fcov.chmod+x
    fcov.hits-clear
    s" .fcov/calls" fcov.ingest-calls-dir
    s" .fcov/coverage.json" s" gforth tests/run.4th" fcov-ver-data 2@ fcov.write-coverage-json
    fcov.report-console ;

: fcov.test-under-instrumentation?
    s" FCOV_CALLS_LOG" getenv nip 0<> ;

: fcov.test-report ( fmt-a fmt-u -- )
    fcov.test-use-fixture
    fcov.str-dup fcov.rest 2!
    s" --format" fcov.str-dup fcov.arg 2!
    fcov.report ;

: fcov.test-report-bad-fmt
    fcov.test-use-fixture
    s" wibble" fcov.str-dup fcov.rest 2!
    s" --format" fcov.str-dup fcov.arg 2!
    fcov.report ;

: fcov.test-run-fixture-word
    fcov.test-under-instrumentation? 0= IF
        fcov.test-pipeline-no-exec
    THEN ;

: fcov.test-report-word-skip ( fmt-a fmt-u -- )
    fcov.test-under-instrumentation? 0= IF fcov.test-report THEN ;

: fcov.test-report-bad-fmt-word
    fcov.test-under-instrumentation? 0= IF fcov.test-report-bad-fmt THEN ;

: fcov.test-clean-word
    fcov.test-under-instrumentation? 0= IF
        fcov.test-use-fixture fcov.clean
    THEN ;

: fcov.test-warn-future
    0 fcov.legacy-self-dep? !
    s" ~> 99.0" fcov.set-required-req
    fcov.check-required-version ;

: fcov.test-warn-legacy
    s" " fcov.set-required-req
    true fcov.legacy-self-dep? !
    fcov.check-required-version ;

: fcov.test-warn-invalid
    0 fcov.legacy-self-dep? !
    s" garbage" fcov.set-required-req
    fcov.check-required-version ;

: fcov.test-warn-future-word fcov.test-warn-future ;
: fcov.test-warn-legacy-word fcov.test-warn-legacy ;
: fcov.test-warn-invalid-word fcov.test-warn-invalid ;

T{ fcov.help -> }T
T{ fcov.version -> }T
T{ fcov.test-run-fixture-word -> }T
T{ s" lcov" fcov.test-report-word-skip -> }T
T{ s" json" fcov.test-report-word-skip -> }T
T{ s" html" fcov.test-report-word-skip -> }T
T{ s" console" fcov.test-report-word-skip -> }T
T{ fcov.test-report-bad-fmt-word -> }T
T{ fcov.test-clean-word -> }T
T{ fcov.test-warn-future-word -> }T
T{ fcov.test-warn-legacy-word -> }T
T{ fcov.test-warn-invalid-word -> }T

: report
    fcov.test-cd-home-cmd 2@ fcov.test-sh drop
    #ERRORS @ 0= IF
        cr ." fcov_integration_test ok" cr
    ELSE
        cr ." fcov_integration_test FAILED: " #ERRORS @ . ." errors" cr
        1 ( bye )
    THEN ;
report
bye
