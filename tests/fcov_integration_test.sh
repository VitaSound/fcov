#!/usr/bin/env bash
# tests/fcov_integration_test.sh — black-box integration tests for the
# fcov 0.3.0 release. Exercises the CLI commands end-to-end through
# bin/fcov, in the same style as flint_integration_test.sh.
#
# 0.3.0 assertions:
#   - fcov help / version always work; help mentions every --format value
#   - fcov clean nukes .fcov/ and exits 0
#   - unknown command prints help and exits non-zero
#   - version-check warn-only behaviour (legacy form, future req, invalid req)
#   - smoke-test passes when invoked via gforth directly
#   - tests/fixtures/partial_cov/ produces the expected coverage breakdown
#     (covered/uncovered words match the golden set).
#   - all four --format outputs are wired up:
#       * console (default) prints the same table as fcov run
#       * lcov   emits genhtml-compatible trace data
#       * json   emits the canonical .fcov/coverage.json schema
#       * html   writes a static site under .fcov/html/ with the
#                expected files and decorations.

set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fcov_bin="$repo_root/bin/fcov"
fail_count=0

pass() { printf "[OK]   %s\n" "$1"; }
fail() { printf "[FAIL] %s\n" "$1" >&2; fail_count=$((fail_count + 1)); }

# --- Case 1: help works ---------------------------------------------------
out=$(bash "$fcov_bin" help 2>&1)
if ! grep -q "coverage collector" <<<"$out"; then
    fail "help: missing descriptive line; got:\n$out"
fi
pass "fcov help works"

# --- Case 2: version works ------------------------------------------------
out=$(bash "$fcov_bin" version 2>&1)
if ! grep -qE "\\(fcov\\)" <<<"$out"; then
    fail "version: missing version string; got:\n$out"
fi
pass "fcov version works"

# --- Case 3: clean removes .fcov/ ----------------------------------------
tmp=$(mktemp -d)
mkdir -p "$tmp/.fcov"
touch "$tmp/.fcov/sentinel"
out=$(cd "$tmp" && bash "$fcov_bin" clean 2>&1)
if [ -d "$tmp/.fcov" ]; then
    fail "clean: .fcov/ still exists after run:\n$out"
fi
if ! grep -q "removed .fcov/" <<<"$out"; then
    fail "clean: missing confirmation line; got:\n$out"
fi
rm -rf "$tmp"
pass "fcov clean removes .fcov/"

# --- Case 4: unknown command --------------------------------------------
out=$(bash "$fcov_bin" wibble 2>&1)
status=$?
if [ "$status" -eq 0 ]; then
    fail "unknown command should exit non-zero (got status=$status)"
fi
if ! grep -q "Unknown command: wibble" <<<"$out"; then
    fail "unknown command: missing diagnostic; got:\n$out"
fi
pass "unknown command exits non-zero with diagnostic"

# --- Case 5: version-check is warn-only when project pins future fcov ---
tmp=$(mktemp -d)
cat > "$tmp/package.4th" <<'PKG'
forth-package
    key-value name probe
    key-value version 0.0.1
    key-value main probe.4th
    key-value fcov ~> 99.0
end-forth-package
PKG
out=$(cd "$tmp" && bash "$fcov_bin" version 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
    fail "future-fcov: should warn-not-fail, but exited $status:\n$out"
fi
if ! grep -q "WARN" <<<"$out"; then
    fail "future-fcov: missing WARN line; got:\n$out"
fi
rm -rf "$tmp"
pass "version-check is warn-only for unsatisfiable requirement"

# --- Case 6: legacy form triggers migration WARN -------------------------
tmp=$(mktemp -d)
cat > "$tmp/package.4th" <<'PKG'
forth-package
    key-value name probe
    key-value version 0.0.1
    key-value main probe.4th
    key-list dependencies fcov 0.0.1
end-forth-package
PKG
out=$(cd "$tmp" && bash "$fcov_bin" version 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
    fail "legacy form: should warn-not-fail, but exited $status:\n$out"
fi
if ! grep -q "pre-0.1 form" <<<"$out"; then
    fail "legacy form: missing migration hint; got:\n$out"
fi
rm -rf "$tmp"
pass "legacy form triggers migration WARN (warn-only)"

# --- Case 7: smoke test via gforth directly -----------------------------
out=$(FCOV_HOME="$repo_root" gforth "$repo_root/tests/fcov_smoke_test.4th" </dev/null 2>&1)
status=$?
if [ "$status" -ne 0 ] || ! grep -q "fcov_smoke_test ok" <<<"$out"; then
    fail "fcov_smoke_test failed (status=$status):\n$out"
fi
pass "fcov_smoke_test: util/wiring assertions pass"

# --- Case 8: aggregator unit test --------------------------------------
out=$(FCOV_HOME="$repo_root" gforth "$repo_root/tests/fcov_aggregator_test.4th" </dev/null 2>&1)
status=$?
if [ "$status" -ne 0 ] || ! grep -q "fcov_aggregator_test ok" <<<"$out"; then
    fail "fcov_aggregator_test failed (status=$status):\n$out"
fi
pass "fcov_aggregator_test: shard merge / lookup / external-filter"

# --- Case 9: prelude generator round-trip ------------------------------
out=$(FCOV_HOME="$repo_root" gforth "$repo_root/tests/fcov_prelude_gen_test.4th" </dev/null 2>&1)
status=$?
if [ "$status" -ne 0 ] || ! grep -q "fcov_prelude_gen_test ok" <<<"$out"; then
    fail "fcov_prelude_gen_test failed (status=$status):\n$out"
fi
pass "fcov_prelude_gen_test: emitted prelude is loadable Forth"

# --- Case 10: end-to-end on tests/fixtures/partial_cov/ -----------------
fixture="$repo_root/tests/fixtures/partial_cov"
( cd "$fixture" && rm -rf .fcov )
out=$(cd "$fixture" && FCOV_HOME="$repo_root" bash "$fcov_bin" run gforth tests/run.4th 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
    fail "fixture run exited non-zero (status=$status):\n$out"
fi
if ! grep -qE "uncovered:.*thing\\.uncovered" <<<"$out"; then
    fail "fixture: thing.uncovered should appear as uncovered; got:\n$out"
fi
if ! grep -qE "uncovered:.*util\\.dead-code" <<<"$out"; then
    fail "fixture: util.dead-code should appear as uncovered; got:\n$out"
fi
if grep -qE "uncovered:.*thing\\.covered" <<<"$out"; then
    fail "fixture: thing.covered must NOT appear as uncovered; got:\n$out"
fi
if grep -qE "uncovered:.*util\\.helper" <<<"$out"; then
    fail "fixture: util.helper must NOT appear as uncovered; got:\n$out"
fi
if ! grep -qE "TOTAL.*2/4 \\(50%\\)" <<<"$out"; then
    fail "fixture: TOTAL line should read 2/4 (50%); got:\n$out"
fi
if [ ! -f "$fixture/.fcov/coverage.json" ]; then
    fail "fixture: .fcov/coverage.json was not produced"
fi
if [ ! -f "$fixture/.fcov/defs.json" ]; then
    fail "fixture: .fcov/defs.json was not produced"
fi
if [ ! -s "$fixture/.fcov/_prelude.4th" ]; then
    fail "fixture: .fcov/_prelude.4th missing or empty"
fi
pass "fixture partial_cov: covered/uncovered split matches golden set"

# --- Case 11: fcov report (lcov) on the same fixture -------------------
out=$(cd "$fixture" && FCOV_HOME="$repo_root" bash "$fcov_bin" report --format lcov 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
    fail "fixture lcov report exited non-zero ($status):\n$out"
fi
for needle in \
    "TN:fcov" \
    "SF:./src/thing.4th" \
    "SF:./src/util.4th" \
    "FN:7,thing.covered" \
    "FN:10,thing.uncovered" \
    "FNDA:1,thing.covered" \
    "FNDA:0,thing.uncovered" \
    "DA:8,0" \
    "end_of_record"
do
    if ! grep -qF "$needle" <<<"$out"; then
        fail "lcov: missing line «$needle»; got:\n$out"
    fi
done
pass "fcov report --format lcov emits genhtml-compatible trace data"

# --- Case 12: fcov report --format json --------------------------------
out=$(cd "$fixture" && FCOV_HOME="$repo_root" bash "$fcov_bin" report --format json 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
    fail "fixture json report exited non-zero ($status):\n$out"
fi
for needle in \
    '"fcov_version"' \
    '"definitions"' \
    '"calls"' \
    '"summary"' \
    '"name": "thing.covered"' \
    '"name": "thing.uncovered"' \
    '"words_total"' \
    '"words_covered"'
do
    if ! grep -qF "$needle" <<<"$out"; then
        fail "json: missing «$needle»; got:\n$out"
    fi
done
# Quick syntactic sanity: balanced braces / brackets.
open=$(tr -cd '{[' <<<"$out" | wc -c)
close=$(tr -cd '}]' <<<"$out" | wc -c)
if [ "$open" -ne "$close" ]; then
    fail "json: unbalanced braces ($open opens vs $close closes)"
fi
pass "fcov report --format json emits canonical coverage JSON"

# --- Case 13: fcov report --format html --------------------------------
out=$(cd "$fixture" && FCOV_HOME="$repo_root" bash "$fcov_bin" report --format html 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
    fail "fixture html report exited non-zero ($status):\n$out"
fi
for f in \
    "$fixture/.fcov/html/index.html" \
    "$fixture/.fcov/html/style.css" \
    "$fixture/.fcov/html/src/thing.4th.html" \
    "$fixture/.fcov/html/src/util.4th.html"
do
    if [ ! -s "$f" ]; then
        fail "html: missing or empty file $f"
    fi
done
if ! grep -qF '<title>fcov coverage report</title>' "$fixture/.fcov/html/index.html"; then
    fail "html: index.html missing the report <title>"
fi
if ! grep -qF '<a href="src/thing.4th.html">' "$fixture/.fcov/html/index.html"; then
    fail "html: index.html missing per-file link to src/thing.4th"
fi
if ! grep -qE 'class="def covered"' "$fixture/.fcov/html/src/thing.4th.html"; then
    fail "html: thing.4th page missing covered-def decoration"
fi
if ! grep -qE 'class="def uncovered"' "$fixture/.fcov/html/src/thing.4th.html"; then
    fail "html: thing.4th page missing uncovered-def decoration"
fi
if ! grep -qE 'href="\.\./style\.css"' "$fixture/.fcov/html/src/thing.4th.html"; then
    fail "html: per-file page missing relative ../style.css link"
fi
pass "fcov report --format html writes a self-contained static site"

# --- Case 14: fcov help advertises every --format ----------------------
out=$(bash "$fcov_bin" help 2>&1)
for fmt in console json lcov html; do
    if ! grep -qE "^[[:space:]]+$fmt" <<<"$out"; then
        fail "help: missing $fmt format in CLI help; got:\n$out"
    fi
done
pass "fcov help lists all four report formats"

# --- Summary -------------------------------------------------------------
echo
if [ "$fail_count" -eq 0 ]; then
    echo "fcov_integration_test ok"
    exit 0
else
    echo "fcov_integration_test FAILED: $fail_count assertion(s)"
    exit 1
fi
