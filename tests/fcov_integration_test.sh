#!/usr/bin/env bash
# tests/fcov_integration_test.sh — black-box integration tests for the
# fcov 0.1.0 scaffold release. Exercises the CLI commands end-to-end
# through bin/fcov, in the same style as flint_integration_test.sh.
#
# Scaffold-era assertions (will tighten as 0.2.0 lands):
#   - fcov help / version always work
#   - fcov run prints a scaffold message and exits 0
#   - fcov report prints a scaffold message and exits 0
#   - fcov clean nukes .fcov/ and exits 0
#   - unknown command prints help and exits non-zero
#   - version-check warn-only behaviour (legacy form, future req, invalid req)
#   - smoke-test passes when invoked via gforth directly

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
if ! grep -qE "\\(fcov\\) v0\\.1\\.0" <<<"$out"; then
    fail "version: missing version string; got:\n$out"
fi
pass "fcov version works"

# --- Case 3: run prints scaffold message ----------------------------------
out=$(bash "$fcov_bin" run echo hello 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
    fail "fcov run exited non-zero (status=$status):\n$out"
fi
if ! grep -q "scaffold release" <<<"$out"; then
    fail "fcov run: missing scaffold message; got:\n$out"
fi
pass "fcov run prints scaffold message (will run real instrumentation in 0.2.0)"

# --- Case 4: report prints scaffold message -------------------------------
out=$(bash "$fcov_bin" report 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
    fail "fcov report exited non-zero (status=$status):\n$out"
fi
if ! grep -q "scaffold release" <<<"$out"; then
    fail "fcov report: missing scaffold message; got:\n$out"
fi
pass "fcov report prints scaffold message"

# --- Case 5: clean removes .fcov/ ----------------------------------------
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

# --- Case 6: unknown command --------------------------------------------
out=$(bash "$fcov_bin" wibble 2>&1)
status=$?
if [ "$status" -eq 0 ]; then
    fail "unknown command should exit non-zero (got status=$status)"
fi
if ! grep -q "Unknown command: wibble" <<<"$out"; then
    fail "unknown command: missing diagnostic; got:\n$out"
fi
pass "unknown command exits non-zero with diagnostic"

# --- Case 7: version-check is warn-only when project pins future fcov ---
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

# --- Case 8: legacy form triggers migration WARN -------------------------
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

# --- Case 9: smoke test via gforth directly -----------------------------
out=$(FCOV_HOME="$repo_root" gforth "$repo_root/tests/fcov_smoke_test.4th" 2>&1)
status=$?
if [ "$status" -ne 0 ] || ! grep -q "fcov_smoke_test ok" <<<"$out"; then
    fail "fcov_smoke_test failed (status=$status):\n$out"
fi
pass "fcov_smoke_test: wiring ok (fsemver carries the 71-case truth-table)"

# --- Summary -------------------------------------------------------------
echo
if [ "$fail_count" -eq 0 ]; then
    echo "fcov_integration_test ok"
    exit 0
else
    echo "fcov_integration_test FAILED: $fail_count assertion(s)"
    exit 1
fi
