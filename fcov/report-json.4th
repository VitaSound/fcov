\ fcov/report-json.4th — emit canonical coverage JSON to stdout.
\
\ The JSON shape matches `.fcov/coverage.json` exactly; this reporter
\ is what you reach for when piping fcov into another tool (`jq`, a
\ CI dashboard, a custom report). Two paths:
\
\   1. Preferred — slurp `.fcov/coverage.json` and `type` it. This
\      preserves the exact `test_cmd`, `generated_at` and any future
\      run-only metadata the reporter doesn't have access to.
\
\   2. Fallback — `.fcov/coverage.json` is missing (someone called
\      `fcov report --format json` on a fresh checkout, or after
\      `fcov clean`). Emit a freshly-rendered JSON from the in-memory
\      collect/aggregate state with `test_cmd: "(report)"`. This way
\      the schema is stable and consumers don't need a special case
\      for the «no run yet» state.
\
\ The schema itself is documented inside fcov/aggregate.4th — keep them
\ in sync.

require fcov/util.4th
require fcov/aggregate.4th

\ outfile-id is gforth's standard handle for the current output sink
\ (initially stdout). Using it lets `fcov.emit-coverage-json` write
\ via `write-file` exactly the same way as the on-disk path — no
\ buffering surprises from mixing `type` and `write-file`.

: fcov.report-json
    s" .fcov/coverage.json" 2dup file-status nip 0= IF
        slurp-file 2dup type drop free throw
    ELSE
        2drop
        outfile-id
        s" (report)"
        fcov-ver-data 2@
        fcov.emit-coverage-json
    THEN ;
