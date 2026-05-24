# fcov ROADMAP

This document is the source of truth for fcov's implementation plan,
trade-offs and open questions. It's deliberately verbose so a future
session — possibly with a fresh context window — can pick up exactly
where the previous one stopped.

> **Audience:** an AI coding agent (or human contributor) starting from
> the 0.1.0 scaffold and building toward 0.2.0 / 1.0.0.

## Status as of 0.1.0

**Scaffold only.** CLI exists, package wiring works, version pinning
through fsemver works, tests pass. The `run` and `report` commands
print a placeholder message — there is no real instrumentation and no
report generation yet.

```
0.1.0  scaffold + CLI surface + fsemver wiring             ← we are here
0.2.0  real instrumentation (definition + call coverage, console + LCOV)
0.3.0  JSON + HTML report formats
1.0.0  branch coverage (IF/ELSE/WHILE/?DO etc.)
```

## Design goals (carry forward)

1. **One coherent UX with fmix / flint.** Same bash launcher pattern,
   same env-var naming, same `key-value <tool> <req>` grammar, same
   COPL license, same RU+EN docs. A contributor moving between the
   tools should never have to re-learn conventions.
2. **No global gforth state mutation between projects.** Coverage
   collection MUST be opt-in per `fcov run`, never pollute a normal
   `gforth myproj.4th` session. The instrumentation prelude is
   per-process.
3. **Pure Forth wherever possible.** Like flint dropped its `find`
   shell-out in 0.2.0, fcov avoids OS-specific tooling for the core
   collector. `clean` is the only place `system` is acceptable — it's
   a deliberate convenience, not a dependency on POSIX semantics.
4. **Data and presentation are separated.** `fcov run` writes
   `./.fcov/coverage.json` (canonical, machine-readable). All
   reporters read from that file. This is what lets us add formats
   without re-running tests.
5. **Forth-style measure: words, not lines.** Forth code is organised
   by definitions, not by line numbers. A "covered" word is more
   meaningful than a "covered" line. LCOV and HTML reports translate
   to lines-of-source as a best-effort presentation step.

## 0.2.0 — Real instrumentation (definition + call coverage)

### Architecture

```
                     ┌────────────────────────────────┐
   fcov run          │  flint-style walker (re-use!)  │
   (per project)     │  collects every : / Defer /    │
                     │  Variable / 2variable /        │
                     │  Constant with (file, line)    │
                     └────────────────┬───────────────┘
                                      │  defs.json
                                      ▼
                     ┌────────────────────────────────┐
                     │  instrumentation prelude       │
                     │  ./.fcov/_prelude.4th          │
                     │  - redefines : to wrap body    │
                     │    in   ['] <name> fcov-hit ;  │
                     │  - opens .fcov/calls.log       │
                     └────────────────┬───────────────┘
                                      │  pre-loaded
                                      ▼
                     ┌────────────────────────────────┐
                     │  user test cmd (default        │
                     │  `fmix test`) runs N gforth    │
                     │  subprocesses, each emits to   │
                     │  .fcov/calls/$pid.log          │
                     └────────────────┬───────────────┘
                                      │  log shards
                                      ▼
                     ┌────────────────────────────────┐
                     │  aggregator merges shards into │
                     │  .fcov/coverage.json           │
                     │  (canonical form)              │
                     └────────────────────────────────┘
```

### Word collection (re-use flint)

flint already walks `.4th` trees and tokenises content. Either:
- **Vendor flint's walk + scan into fcov** (probably better — fcov can
  evolve its scanner without coupling to flint), or
- **Declare flint as a runtime dep** and call its public scanner
  (cleaner, but flint's scanner is currently focused on duplicate
  detection — the API isn't structured for re-use yet).

Either way, the output is a JSON like:

```json
{
  "words": [
    {"name": "myproj.do-thing", "file": "src/thing.4th", "line": 17, "type": "colon"},
    {"name": "tmp-buf",         "file": "src/util.4th",  "line":  4, "type": "variable"}
  ]
}
```

The interesting word types for 0.2.0 are `colon` and `defer`. Variables
and constants are technically "defined" but don't "execute" — counting
them as covered if loaded suffices (they go in the report under a
separate axis).

### Instrumentation prelude

Generated per `fcov run` into `./.fcov/_prelude.4th`. Conceptually:

```forth
\ Open a per-process log (sharded by PID to survive --isolated mode).
s" .fcov/calls/" pad place
\ ... append PID to pad ... append ".log" ...
pad count w/o create-file throw value fcov.log-fh

: fcov.hit ( name-a name-u -- )
    fcov.log-fh write-line throw ;

\ Save & replace `:` so every new colon-def starts with a fcov.hit call.
' : value fcov.orig-colon
: : ( "name" -- )
    fcov.orig-colon execute
    last @ name>string ( a u )
    postpone literal postpone literal postpone fcov.hit ;
```

Three real-world gotchas to handle in the implementation:

1. **`last @ name>string`** is Gforth-specific. Document & test on
   Gforth 0.7.x baseline; revisit for other Forths later.
2. **`:noname … ;`** doesn't have a name — needs a separate hook
   (`:noname` redefined to assign synthetic `__noname_N` and route to a
   parallel counter).
3. **Words defined inside `MARKER` scopes** (we use this pattern
   ourselves in fmix / flint / fcov!) MUST NOT be counted as
   project-coverage: they're throw-away DSL words. The walker already
   sees them; the prelude shouldn't double-count via a separate
   mechanism. Easiest: the aggregator filters by `(file, line)` against
   the walker's known set.

### Subprocess fan-out (works with fmix test --isolated)

fmix's default `--isolated` mode forks one gforth per test file. The
prelude needs to be loaded into each forked process. Two options:

- **A. `fmix test --isolated --preload .fcov/_prelude.4th`** — add a
  flag to fmix. Cleanest, but couples fmix and fcov releases.
- **B. Environment variable.** `FMIX_PRELOAD_FILES=".fcov/_prelude.4th"`
  recognised by fmix's per-process gforth invocation. Adds one line to
  fmix; fcov sets the env-var before spawning `fmix test`.
- **C. Wrapper script.** fcov writes its own `bin/_fcov-gforth` shim
  that does `exec gforth ... -e 'require .fcov/_prelude.4th' "$@"` and
  sets `FMIX_GFORTH=$FCOV_HOME/bin/_fcov-gforth` (assuming fmix
  respects such an env-var). Most independent but most plumbing.

**Decision needed for 0.2.0:** likely B, with a fallback to C if the
fmix change is rejected.

### Aggregator

Merges per-PID log shards into one canonical `coverage.json`:

```json
{
  "fcov_version": "0.2.0",
  "generated_at": "2026-05-24T12:34:56Z",
  "project_root": "/home/sea/myproj",
  "test_cmd": "fmix test",
  "definitions": [...same shape as walker output...],
  "calls": {
    "myproj.do-thing": 42,
    "myproj.helper":    3
  },
  "summary": {
    "words_total":   12,
    "words_covered":  8,
    "coverage_pct":  66.7
  }
}
```

Aggregation rules:
- Multiple log lines for the same word → sum counts.
- A word in `definitions[]` but not in `calls{}` → coverage = 0,
  counted as "uncovered".
- A word in `calls{}` but not in `definitions[]` → external dep,
  ignored (don't inflate the denominator).

### Reporter formats

For 0.2.0:

- **console** — coloured table, one line per file:
  ```
  src/thing.4th     8/12 (66%)   uncovered: foo, bar, baz
  src/util.4th      4/4  (100%)
  -----------------------------------------
  TOTAL            12/16 (75%)
  ```
- **lcov** — standard LCOV trace format. Tested against `genhtml`
  (genhtml will render decent HTML even though we're word-coverage, not
  line-coverage — each word maps to its source line via the walker
  output).

JSON and HTML reporters slip to 0.3.0 unless 0.2.0 ships fast.

### Tests for 0.2.0

- Unit: aggregator merges shards correctly (handles duplicates,
  missing words, external words).
- Unit: prelude generator emits compileable Forth (round-trip test:
  generated prelude must `included` cleanly into a fresh gforth).
- Integration: a fixture project with known coverage holes
  (`tests/fixtures/partial_cov/`) — assert specific words appear as
  uncovered and others as covered.
- Integration: end-to-end via `fcov run` + `fcov report` on the
  fixture, assert console output matches a golden file.

## 1.0.0 — Branch coverage

The hard part. `IF`, `ELSE`, `THEN`, `BEGIN`, `WHILE`, `UNTIL`, `REPEAT`,
`?DO`, `LOOP`, `+LOOP` are all immediate compile-time words. To
instrument them, we redefine each one to emit counter-bump code into
the compiled body **at compile time**.

### Per-construct strategy

| Construct | Counters | Notes |
|-----------|----------|-------|
| `IF` ... `THEN` | 2: taken / not-taken | wrap with `<bump-A> IF <bump-B> THEN` semantics |
| `IF` ... `ELSE` ... `THEN` | 2: then-branch / else-branch | as above, else-side gets its own bump |
| `BEGIN` ... `UNTIL` | 2: iterated / fell-through | bump on each iteration + bump on exit |
| `BEGIN` ... `WHILE` ... `REPEAT` | 3: entered / continued / exited | bump on entry to body, exit on while-false |
| `?DO` / `DO` ... `LOOP` | 2: body-entered / never-entered (?DO only) | bump on body entry |
| `?DO` / `DO` ... `+LOOP` | same as LOOP | identical to LOOP |
| `CASE` / `OF` / `ENDOF` / `ENDCASE` | N: per-OF arm + default | tricky; defer to 1.1.0? |
| `[IF]` / `[ELSE]` / `[THEN]` (conditional compilation) | special: a `[IF]` arm not compiled in this build is "not coverable" — exclude from denominator, don't count as uncovered |

**Open question:** Gforth's `CASE` is a complex compile-time construct.
First-pass 1.0.0 may exclude it and document the limitation; 1.1.0
adds it after we have field experience.

### Source mapping

A bump-counter on its own says "branch #17 in src/thing.4th hit 42
times". The reporter needs to translate `branch #17` to a source
location (line + column). Approach: at compile time, the redefined
control-flow words capture `parse-position` (or equivalent) and emit
the captured pair into a side-table along with the counter address.

### Tests for 1.0.0

- Per-construct unit tests: a single function with one `IF`, asserting
  both arms are tracked independently.
- Integration: a fixture with mixed `IF`/`BEGIN-WHILE`/`?DO` whose
  branch coverage is known by construction.
- Regression: existing 0.2.0 fixtures still report the same definition
  coverage with branch tracking turned on.

## Open questions (decide before 0.2.0)

1. **fmix integration:** A/B/C from the subprocess fan-out section.
   Need a one-line conversation with fmix maintainer (us) about a
   `FMIX_PRELOAD_FILES` env-var.
2. **flint scanner re-use vs vendoring:** vendor for now (independence),
   move toward shared `fscan` package later if both tools converge on
   the same API.
3. **What's a "project file"?** Probably "every `.4th` under the
   project root, excluding `forth-packages/`, `build/`, `.fcov/`, and
   anything matched by `key-list fcov-exclude` in `package.4th`".
4. **`include`-graph vs. file-tree.** A word defined in
   `forth-packages/...` and used from project code: covered or not?
   Default: don't count external defs in the denominator (only own
   project code counts). User can `key-list fcov-include` to opt
   external paths in.
5. **Threshold gates** — `fcov run --fail-under 80` to exit non-zero
   when total coverage drops below 80%. Useful for CI; cheap to add.
   Goal for 0.2.0.
6. **Coverage diff against a baseline** — `fcov report --baseline
   coverage-main.json --against HEAD` to show «coverage delta». Likely
   1.0.0+, after we have stable JSON schemas.

## Non-goals

- **Real-time coverage display** (live dashboard during `fcov run`).
  Too much engineering for too little upside vs. `fcov report` after
  the fact.
- **Coverage of Gforth's own runtime words.** Out of scope — fcov
  measures *your* code, not the platform.
- **Per-input-data branch coverage** (e.g. "this `IF` was taken with x=3
  here, with x=5 there"). That's value-tracking, not coverage.
- **Inlined instrumentation in the source files.** Coverage is a
  read-only operation on the user's tree; `_prelude.4th` lives in
  `.fcov/`, never in user code.

## References worth re-checking before 0.2.0

- Gforth manual chapter on profiling: `info gforth → Profiling`.
- `last @ name>string` documented in Gforth manual under «User-defined
  words» / «Defining words».
- LCOV format spec:
  <https://manpages.debian.org/testing/lcov/geninfo.1.en.html> —
  needed for the reporter.
- `coverage.py`'s `coverage.json` schema as inspiration for our
  `.fcov/coverage.json` (we want similar field names where they
  translate cleanly).

---

*Update this file as decisions land and the unknowns shrink. The point
isn't to be a fortune-teller — it's to keep the rationale visible so a
fresh contributor (human or AI) understands not just **what** to build
but **why** these particular shapes were chosen.*
