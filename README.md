# fcov

**Coverage collector for Forth source trees.** Runs your tests under
instrumentation and reports which `:`-defined words (and, in 0.2.0+,
which `IF`/`ELSE` branches) were actually exercised.

> **0.1.0 is a scaffold release.** The CLI surface, version pinning,
> launcher, tests, docs and release process are all in place; the
> instrumentation and reporter are placeholders. See
> [doc/ROADMAP.md](doc/ROADMAP.md) for the full implementation plan.
> 1.0.0 is the «coverage actually works» target.

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
** (fcov) v0.1.0
```

## CLI surface (target shape, post-0.1.0)

```
fcov run [<test-cmd>]                      Run tests under instrumentation
                                           (default: `fmix test`).
fcov report [--format console|lcov|json|html]
                                           Print coverage report from
                                           last run.
fcov clean                                 Remove .fcov/ artefacts.
fcov version                               Print fcov version.
fcov help                                  This help.
```

In 0.1.0, `run` and `report` print a scaffold message instead of doing
work; `clean`, `version` and `help` are fully functional.

## What «coverage» means here

| Level | What | 0.1.0 | 0.2.0 (target) | 1.0.0 |
|-------|------|-------|----------------|-------|
| **Definition** | every `:`/`Defer`/`Variable` in the project is defined & loaded | scaffold | ✅ | ✅ |
| **Call** | every defined word is exercised by at least one test | scaffold | ✅ | ✅ |
| **Call counts** | how many times each word ran | scaffold | ✅ | ✅ |
| **Branch** | both arms of `IF`/`ELSE`, body of `WHILE`/`UNTIL`/`?DO` etc. are exercised | scaffold | — | ✅ |

Coverage is collected during `fcov run` and aggregated into
`./.fcov/coverage.json`. The reporter reads that file — `run` and
`report` are separate steps so you can re-format the same data multiple
ways without re-running tests.

## Version pinning (`key-value fcov ~> X.Y`)

Same Elixir/Hex grammar as fmix and flint use — delegated to
[fsemver](https://github.com/VitaSound/fsemver) under the hood, so all
three tools speak the exact same operator set:

```forth
forth-package
    key-value name myproj
    key-value version 0.1.0
    key-value main myproj.4th
    key-value fcov ~> 0.1
end-forth-package
```

| Form | Means |
|------|-------|
| `key-value fcov ~> 0.1` | `>= 0.1.0` and `< 1.0.0` (MAJOR pinned — Hex pessimistic) |
| `key-value fcov ~> 0.1.3` | `>= 0.1.3` and `< 0.2.0` (MAJOR+MINOR pinned) |
| `key-value fcov >= 0.1.0` | minimum, no upper bound |
| `key-value fcov == 0.1.0` | exact match |
| `key-value fcov >  0.1.0` | strictly greater |
| `key-value fcov <  1.0.0` | strictly less |
| `key-value fcov <= 0.1.5` | less-or-equal |
| `key-value fcov 0.1.0`    | bare = `>= 0.1.0` |

Like flint (and unlike fmix), **mismatch is warn-only**: fcov reports
the situation but doesn't refuse to run. Coverage data is useful even
from the "wrong" version, and a hard gate would block CI for cosmetic
reasons. This may tighten in a future major bump.

Legacy `key-list dependencies fcov <ver>` is detected and surfaced as
a WARN with a migration hint.

## Tests

```bash
bash tests/fcov_integration_test.sh
```

The integration script covers:
- `help`, `version`, `run`, `report`, `clean`, unknown-command paths
- version-check warn-only behaviour (future req, legacy form)
- `tests/fcov_smoke_test.4th` (gforth-direct wiring smoke for the
  fsemver-via-version-check chain)

The full 71-case operator truth-table lives upstream in
`forth-packages/fsemver/0.1.0/tests/fsemver_test.4th` — we don't
duplicate it.

## Layout

| Path | What |
|------|------|
| `bin/fcov` | bash launcher (TTY reset, env-var passing, `fpath` extension) |
| `fcov.4th` | entry point: arg parsing, command dispatch, CLI stubs |
| `fcov/util.4th` | string + filesystem helpers |
| `fcov/version-check.4th` | read `key-value fcov <req>` from `./package.4th` and warn (don't fail) if installed fcov doesn't match. Parsing / matching delegated to [fsemver](https://github.com/VitaSound/fsemver). |
| `doc/ROADMAP.md` | full implementation plan for 0.2.0 (instrumentation) and 1.0.0 (branch coverage) |
| `tests/fcov_smoke_test.4th` | gforth-direct wiring smoke |
| `tests/fcov_integration_test.sh` | black-box CLI integration tests |
| `package.4th` | theforth.net metadata + deps |

## Russian docs

[README.ru.md](README.ru.md).

## License

[COPL](LICENSE) — Communist Public License. Use freely, share with
others.
