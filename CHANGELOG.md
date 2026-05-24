# Change Log

All notable changes to fcov are documented here.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and
this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

Nothing yet. See [doc/ROADMAP.md](doc/ROADMAP.md) for the planned
1.0.0 (branch coverage) work.

## [0.3.0] - 2026-05-24

JSON and HTML reporters land, completing the four output formats
sketched in the ROADMAP. The new `fcov/exclude.4th` lets projects
opt paths out of the coverage walk via `package.4th`. Two real bugs
in the 0.2.0 sub-process fan-out are fixed.

### Added
- `fcov/report-json.4th` (`fcov report --format json`) — emits the
  canonical `coverage.json` schema to stdout. Slurps `.fcov/coverage.json`
  when it exists (preserves `test_cmd` from the latest run); falls
  back to a fresh in-memory render with `test_cmd: "(report)"` when
  invoked on an empty checkout, so consumers (`jq`, dashboards, CI
  gates) never see a missing-file edge case.
- `fcov/report-html.4th` (`fcov report --format html`) — generates a
  self-contained static site under `.fcov/html/`:
  - `index.html` with per-file table, progress bars, totals;
  - per-file pages mirroring the project's directory structure
    (`.fcov/html/fcov/util.4th.html`, etc.) with the entire source as
    a numbered table;
  - covered / uncovered / non-colon definition lines highlighted
    green / red / yellow with hit-count badges;
  - whole-line `\` comments rendered in a muted italic colour;
  - `style.css` shipped alongside (no JS, no fonts — works offline,
    drops onto GitHub Pages or any static host as-is).
- `fcov/exclude.4th` — opt-out path filter wired to `package.4th`.
  Add `key-list fcov-exclude <prefix>` (one path per line) inside your
  `forth-package … end-forth-package` block to keep specific
  directories out of the coverage walk. The walker still skips
  `build/`, `forth-packages/`, `.fcov/` and dotfiles unconditionally —
  the exclude list is for project-level conventions like
  `tests/fixtures/` (data, not code) or `src/legacy/` (vendored).
- `package.4th` opts fcov's own `tests/fixtures/` out of self-coverage
  runs so `fcov run fmix test` reports only fcov's actual modules.
- `fcov.emit-coverage-json ( fid tc-a tc-u v-a v-u -- )` extracted
  from the on-disk writer in `fcov/aggregate.4th`. Both `fcov run`
  (writes `.fcov/coverage.json`) and `fcov report --format json`
  (writes to stdout) now share the same emitter.
- `fcov/util.4th` gains shared `fcov.shell-1`, `fcov.mkdir-p`,
  `fcov.chmod+x` so reporters loaded *before* `fcov.4th` finishes
  defining its own helpers can still call them.
- `fcov help` lists all four `--format` values with one-line
  descriptions of each output shape.

### Changed
- README.md and README.ru.md updated for 0.3.0: quick-start, full
  format table, dedicated «What is LCOV?» section, exclude-list docs.
- `fcov.4th`'s docstring now describes the four-format reporter
  surface and points at the new `fcov/report-{json,html}.4th` modules.

### Fixed
- `bin/fcov`'s auto-generated `gforth` shim no longer leaks
  `FCOV_CALLS_LOG` to child processes. Previously the first shim
  invocation exported a per-PID log path that every nested gforth
  inherited, and each child's `w/o create-file` then *truncated* the
  parent's hit log — leaving only the last process's shard intact.
  Each gforth subprocess now derives its own
  `${FCOV_CALLS_DIR}/calls.$$.log`, and the aggregator merges all of
  them. Self-coverage (`fcov run fmix test` on the fcov repo itself)
  now reports the correct hit counts for `fmix --isolated` test
  subprocesses.
- `tests/fcov_prelude_gen_test.4th` invokes `$FCOV_REAL_GFORTH`
  directly when running under `fcov run`, bypassing the `PATH`-shadowed
  shim so the test's own `FCOV_CALLS_LOG` setting is honoured.

## [0.2.0] - 2026-05-24

First real coverage release. `fcov run` no longer prints a placeholder —
it walks your project, instruments every `:`-defined word, runs your
test command and writes a canonical `coverage.json` plus a console
summary. `fcov report` re-renders that data into either a human-readable
table or LCOV trace data.

### Added
- `fcov/walk.4th` — pure-Forth recursive directory walker (vendored &
  adapted from flint/walk.4th). Skips `build/`, `forth-packages/`,
  `.fcov/` and any `.`-prefixed names.
- `fcov/scan.4th` — single-file tokeniser that recognises `:`, `defer`,
  `variable`, `2variable`, `fvariable`, `constant`, `2constant`,
  `fconstant`, `value`, `2value`, `fvalue`, `create`, `marker`,
  `field`, `field:`, `cfield:`, `nfield:`, `ufield:`, `code` and
  `synonym` and emits `(file, line, type, name)` events. Adds line
  tracking and definition-type tagging on top of the flint scanner.
- `fcov/collect.4th` — definition list (backed by fenum's `ulist`),
  lookup-by-name, and a JSON writer for `.fcov/defs.json`.
- `fcov/prelude.4th` — generator for `.fcov/_prelude.4th`. The
  generated prelude redefines `:` to compile a `fcov.hit` call into
  every freshly-defined word's body. Per-process append-only logs
  land in `.fcov/calls/<pid>.log` (PID provided by the bash shim).
- `fcov/aggregate.4th` — merges per-process call shards into one
  hit-count map (also a `ulist`) and writes the canonical
  `.fcov/coverage.json` (definitions, calls, summary). Implements all
  three rules from the ROADMAP: sum duplicate hits; «def-without-call
  → uncovered»; «call-without-def → external dep, ignored from
  summary».
- `fcov/report-console.4th` — per-file table with uncovered-name list
  (truncated to 6 names + «…+N more»). Only colon-defs drive the
  percentage so the metric stays meaningful.
- `fcov/report-lcov.4th` — emit standard LCOV trace data
  (`TN/SF/FN/FNDA/FNF/FNH/DA/LF/LH/end_of_record`) for `genhtml`
  and other LCOV consumers.
- `fcov.4th` — real `fcov.run` and `fcov.report`. `run` writes a
  `.fcov/bin/gforth` shim that prepends prelude-loading to every
  `gforth` call from the user's test command (option C from the
  ROADMAP — works without modifying fmix). `report --format
  console|lcov` re-walks the source tree and re-ingests
  `.fcov/calls/` shards.
- `tests/fcov_aggregator_test.4th` — unit-test for the call-shard
  merge: duplicate counts sum, missing-from-defs words are
  «uncovered», external words don't inflate the denominator.
- `tests/fcov_prelude_gen_test.4th` — round-trip test: the emitted
  prelude is loadable Forth, and a fresh gforth subprocess that
  loads it actually logs the names of words it defines and runs.
- `tests/fixtures/partial_cov/` — a fixture project with two
  source files, a `tests/run.4th` exercising one word per file, and
  golden coverage of 2/4 (50%). Drives the end-to-end integration
  case.
- Two more cases in `tests/fcov_integration_test.sh`: end-to-end
  `fcov run` on the fixture (asserting the covered/uncovered
  split) and `fcov report --format lcov` (asserting genhtml-shaped
  output).

### Changed
- `fcov.4th` — `fcov run` now does real work; `fcov report` reads
  `.fcov/calls/` and renders. `fcov clean` and `fcov version` are
  unchanged.
- `bin/fcov` — captures `FCOV_REAL_GFORTH` and `FCOV_CWD` *before*
  `fcov run` rewrites `PATH`, so the auto-generated shim can find
  the real gforth binary regardless of where it ends up later.
- Console / LCOV / JSON summaries treat only `colon`-typed defs as
  «coverable». Variables, constants, fields and friends remain in
  `defs.json` for the catalogue but don't drive the percentage.

### Fixed
- `fcov.str-concat` was reading `r@` after pushing `a2` rather than
  `u2` (effectively computing `u1+a2` instead of `u1+u2` and then
  `allocate`-ing a wildly wrong size). Rewritten cleanly with
  locals; the smoke test now exercises the path explicitly.

### Dependencies
- New runtime dependency on
  [fenum](https://github.com/VitaSound/fenum) `~> 0.1.1` for
  `ulist` (linked-list container). Vendored under
  `forth-packages/fenum/0.1.1/`. Same package flint already uses, so
  fmix/flint/fcov projects share one dependency rather than three
  hand-rolled list implementations.

### Notes
- Subprocess fan-out follows option C from the ROADMAP: a `.fcov/bin/`
  shim shadows `gforth` on `PATH`. Works with `fmix test`, `gforth
  myproj.4th`, custom test harnesses — anything that finds gforth via
  `PATH`.
- `:noname` words are *not* tracked in 0.2.0 (no name to log against);
  they remain a known limitation called out in the ROADMAP.
- LCOV output is word-coverage projected onto line numbers — each word
  maps to its definition line. `genhtml` renders this faithfully but
  the result is not «branch» coverage; that ships in 1.0.0.

## [0.1.0] - 2026-05-24

Initial scaffold release. No actual coverage is collected yet — this
release establishes the project structure, CLI shape, packaging,
version-pinning wiring, tests, docs and release process so that real
instrumentation work in 0.2.0 can land as content rather than
infrastructure.

### Added
- `bin/fcov` — bash launcher with TTY hygiene (no escape leakage when
  stdout is piped), `fpath` extension and env-var passing
  (`FCOV_HOME`, `FCOV_CMD`, `FCOV_ARG`, `FCOV_REST`).
- `fcov.4th` — entry point with CLI dispatch for `run`, `report`,
  `clean`, `version`, `help`. `run` and `report` print a scaffold
  message; `clean`, `version`, `help` are fully functional.
- `fcov/util.4th` — string and filesystem helpers mirroring the
  fmix/flint API for consistency.
- `fcov/version-check.4th` — read `key-value fcov <req>` from the
  project's `./package.4th` and warn (don't fail) when the installed
  fcov doesn't satisfy it. Same Elixir/Hex grammar as fmix and flint;
  parsing & matching delegated to the shared
  [fsemver](https://github.com/VitaSound/fsemver) 0.1.0 engine. Legacy
  `key-list dependencies fcov <ver>` is also detected with a migration
  hint.
- `package.4th` — theforth.net-compliant metadata.
  Pins `key-value fmix ~> 0.7` and `key-value flint ~> 0.2` (fcov is
  built and linted with those tools). Declares git-dependencies on
  `fsemver 0.1.0` and `ttester 1.2.0`.
- `tests/fcov_smoke_test.4th` — wiring smoke (9 assertions): confirms
  the fsemver chain loads cleanly through fcov's load context and
  fcov-owned state is initialised.
- `tests/fcov_integration_test.sh` — black-box CLI tests (9 cases):
  help / version / run / report / clean / unknown-command paths,
  warn-only version-check for future requirement and legacy form,
  smoke-test execution via gforth.
- `doc/ROADMAP.md` — full implementation plan for 0.2.0
  (instrumentation: definition + call counts via redefined `:`) and
  1.0.0 (branch coverage via redefined IF/ELSE/WHILE/?DO). Includes
  trade-offs, open questions and data-format specs (LCOV / JSON /
  HTML).
- `README.md` and `README.ru.md` — full bilingual documentation with
  install, CLI surface, coverage-level table, version-pinning grammar
  table, tests section, layout map, theforth.net publication
  instructions (ru).
- `LICENSE` — COPL (Communist Public License), matching fmix / flint /
  fsemver.
- `.gitignore` — `build/`, `forth-packages/`, `.fcov/` (runtime
  artefacts), editor swap files.

### Notes
- 0.1.0 deliberately ships **no** coverage logic. The scaffold itself
  is the deliverable: it establishes the contract (CLI surface,
  version-pinning, file layout, release flow) so that 0.2.0 can be
  pure feature work.
- Existing tools that produce coverage in some form (Gforth's profile
  builds, ad-hoc `~~` tracing, manual `see`-grepping) are not
  replaced by 0.1.0 — they remain the only option until 0.2.0 ships.
