# fcov

**Coverage collector for Forth source trees.** Runs your tests under
instrumentation and reports which `:`-defined words were actually
exercised. Console table, JSON, LCOV trace data and a self-contained
HTML site — pick your output format.

> **0.3.0** ships real instrumentation (definition + call coverage) plus
> all four reporter formats. Branch coverage (`IF`/`ELSE`/`?DO`/…) is the
> next major target — see [doc/ROADMAP.md](doc/ROADMAP.md).

Part of the **VitaSound Forth tooling family** —
[fmix](https://github.com/VitaSound/fmix) (build/test runner),
[flint](https://github.com/VitaSound/flint) (linter),
[fsemver](https://github.com/VitaSound/fsemver) (shared version-pinning
engine), [fenum](https://github.com/VitaSound/fenum),
[ttester](https://github.com/VitaSound/ttester).

## Install

```bash
cd ~ && git clone git@github.com:VitaSound/fcov.git
cd fcov && fmix packages.get
```

Add to `~/.bashrc` — one line per tool so each can move/be removed
independently:

```bash
export FCOV_HOME="$HOME/fcov"
export PATH="$FCOV_HOME/bin:$PATH"
```

Smoke-test:

```
$ fcov version
** (fcov) v0.3.0
```

## Quick start

```bash
cd /path/to/your/forth/project

fcov run                    # default test command: `fmix test`
fcov run lein test          # or any other shell command

fcov report                 # console summary (same as the run tail)
fcov report --format html   # static site under .fcov/html/
fcov report --format json   # canonical JSON to stdout
fcov report --format lcov   # LCOV trace data to stdout
```

`fcov run` walks the project tree, records every `:`-defined word and
its source location, generates a per-process instrumentation prelude,
runs your test command with that prelude pre-loaded, and merges the
per-process call shards into `./.fcov/coverage.json`. `fcov report`
re-reads that data and renders it.

## CLI

```
fcov run [<test-cmd>]                  Run tests under instrumentation
                                       (default: `fmix test`).
fcov report [--format <fmt>]           Render the report (default:
                                       --format console).
fcov clean                             Remove the .fcov/ working dir.
fcov version                           Print fcov version.
fcov help                              CLI help.
```

## Report formats

| `--format` | What you get | Where it goes |
|------------|--------------|---------------|
| `console`  | colour-friendly text table, one line per file, with a truncated list of uncovered words | stdout (also auto-printed at end of `run`) |
| `json`     | canonical `coverage.json` — definitions, per-word hit counts, summary stats. Stable schema, easy to consume from `jq`, dashboards, CI gates. | stdout |
| `lcov`     | [LCOV](#what-is-lcov) trace data — `TN`/`SF`/`FN`/`FNDA`/`DA`/`LF`/`LH`/`end_of_record`. Feed into `genhtml`, GitLab/GitHub LCOV viewers, IntelliJ, sonar, etc. | stdout |
| `html`     | self-contained static site under `.fcov/html/` — `index.html` with per-file table + per-file pages with the full source code, covered/uncovered word highlighting, hit counts and link anchors per line. No JS, no external fonts; works offline. | `.fcov/html/` directory |

### What is LCOV?

[LCOV](https://github.com/linux-test-project/lcov) is the *de facto*
plain-text format the C/C++ world has used for line and function
coverage since the early 2000s. A trace file looks like this:

```
TN:fcov
SF:./fcov/util.4th
FN:12,fcov.str-dup
FN:18,fcov.str-concat
FNDA:14,fcov.str-dup
FNDA:6,fcov.str-concat
DA:12,14
DA:18,6
LF:2
LH:2
end_of_record
```

Records are file-scoped. `FN:<line>,<name>` declares a function/word at
a given line, `FNDA:<count>,<name>` reports how many times it ran,
`DA:<line>,<count>` is the per-line counter, `LF`/`LH` are the line
totals. fcov maps each `:`-defined word's source line into a
`DA`/`FNDA` pair so any LCOV-aware tooling — most importantly
[`genhtml`](https://manpages.debian.org/testing/lcov/genhtml.1.en.html),
which renders a multi-page HTML site — gets a coherent picture even
though we measure word coverage rather than line coverage.

```bash
fcov report --format lcov > coverage.info
genhtml coverage.info -o coverage-html/
```

The native `--format html` reporter is preferable when you want
fcov-native colours, links and per-bucket tables; `lcov` is the right
choice when an existing toolchain (CI dashboard, JetBrains coverage
gutter, SonarQube) already speaks it.

## What «coverage» means here

| Level | What | 0.2.0 / 0.3.0 | 1.0.0 (target) |
|-------|------|---------------|----------------|
| **Definition** | every `:`/`defer`/`variable`/`constant`… in the project is defined & loaded | ✅ | ✅ |
| **Call** | every `:`-defined word is exercised by at least one test | ✅ | ✅ |
| **Call counts** | how many times each word ran | ✅ | ✅ |
| **Branch** | both arms of `IF`/`ELSE`, body of `WHILE`/`UNTIL`/`?DO` etc. exercised | — | ✅ |

Coverage percentages count only `:`-defined words (variables and
constants live in the catalogue with `calls = 0` but don't drag the
metric down).

## Excluding paths

Add `key-list fcov-exclude <prefix>` lines to your `package.4th` —
matching paths are dropped from the walker:

```forth
forth-package
    key-value name myproj
    key-value version 0.1.0
    key-value main src/myproj.4th
    key-value fcov ~> 0.3

    key-list fcov-exclude tests/fixtures
    key-list fcov-exclude src/legacy
end-forth-package
```

`build/`, `forth-packages/`, `.fcov/` and any `.`-prefixed entries are
skipped unconditionally — the exclude list is for project-specific
conventions on top of that.

## Version pinning (`key-value fcov ~> X.Y`)

Same Elixir/Hex grammar as fmix and flint use — delegated to
[fsemver](https://github.com/VitaSound/fsemver) under the hood, so all
three tools speak the exact same operator set:

```forth
forth-package
    key-value name myproj
    key-value version 0.1.0
    key-value main myproj.4th
    key-value fcov ~> 0.3
end-forth-package
```

| Form | Means |
|------|-------|
| `key-value fcov ~> 0.3` | `>= 0.3.0` and `< 1.0.0` (MAJOR pinned — Hex pessimistic) |
| `key-value fcov ~> 0.3.1` | `>= 0.3.1` and `< 0.4.0` (MAJOR+MINOR pinned) |
| `key-value fcov >= 0.3.0` | minimum, no upper bound |
| `key-value fcov == 0.3.0` | exact match |
| `key-value fcov >  0.3.0` | strictly greater |
| `key-value fcov <  1.0.0` | strictly less |
| `key-value fcov <= 0.3.5` | less-or-equal |
| `key-value fcov 0.3.0`    | bare = `>= 0.3.0` |

Like flint (and unlike fmix), **mismatch is warn-only**: fcov reports
the situation but doesn't refuse to run. Coverage data is useful even
from the «wrong» version, and a hard gate would block CI for cosmetic
reasons.

Legacy `key-list dependencies fcov <ver>` is detected and surfaced as
a WARN with a migration hint.

## Tests

```bash
bash tests/fcov_integration_test.sh
```

The integration script covers:
- `help`, `version`, `run`, `report`, `clean`, unknown-command paths
- version-check warn-only behaviour (future req, legacy form)
- `tests/fcov_smoke_test.4th` (util/wiring assertions)
- `tests/fcov_aggregator_test.4th` (shard merge, lookup, external-filter)
- `tests/fcov_prelude_gen_test.4th` (round-trip emitted prelude through
  a fresh gforth subprocess)
- `tests/fixtures/partial_cov/` end-to-end fixture (golden covered/uncovered split)
- `--format lcov` emits genhtml-compatible trace data
- `--format html` produces a usable index + per-file pages
- `--format json` emits valid coverage JSON

## Layout

| Path | What |
|------|------|
| `bin/fcov` | bash launcher (TTY reset, env-var passing, `fpath` extension) |
| `fcov.4th` | entry point: arg parsing, command dispatch, run/report orchestration |
| `fcov/util.4th` | string and filesystem helpers |
| `fcov/walk.4th` | recursive `.4th` directory walker |
| `fcov/scan.4th` | per-file tokeniser; emits `(file, line, type, name)` events |
| `fcov/collect.4th` | in-memory definition list + `defs.json` writer |
| `fcov/exclude.4th` | path-prefix filter driven by `key-list fcov-exclude` |
| `fcov/prelude.4th` | generator for the per-process `:`-instrumentation prelude |
| `fcov/aggregate.4th` | merges call-shard logs into `coverage.json` |
| `fcov/report-console.4th` | console table reporter |
| `fcov/report-lcov.4th` | LCOV trace-file reporter |
| `fcov/report-json.4th` | stdout JSON reporter |
| `fcov/report-html.4th` | static HTML site reporter |
| `fcov/version-check.4th` | read `key-value fcov <req>` from `./package.4th` and warn if installed fcov doesn't match (parsing/matching delegated to [fsemver](https://github.com/VitaSound/fsemver)). |
| `doc/ROADMAP.md` | full implementation plan for 1.0.0 (branch coverage) |
| `tests/fcov_*_test.4th` | gforth-direct unit tests |
| `tests/fcov_integration_test.sh` | black-box CLI integration tests |
| `tests/fixtures/partial_cov/` | end-to-end fixture project |
| `package.4th` | theforth.net metadata + deps |

## Russian docs

[README.ru.md](README.ru.md).

## License

[COPL](LICENSE) — Communist Public License. Use freely, share with
others.
