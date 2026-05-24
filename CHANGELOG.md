# Change Log

All notable changes to fcov are documented here.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and
this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

Nothing yet. See [doc/ROADMAP.md](doc/ROADMAP.md) for the planned
0.2.0 (instrumentation) and 1.0.0 (branch coverage) work.

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
