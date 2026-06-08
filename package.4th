\ Follows theforth.net publishing guidelines:
\   https://theforth.net/guidelines
\ Order: mandatory meta keys first (name, version, license, main),
\ optional metadata (description, tags), runtime tool requirements,
\ library dependencies last.
forth-package
    key-value name fcov
    key-value version 0.3.1
    key-value description Coverage collector for Forth source trees (definition + call coverage; console, JSON, LCOV and static HTML reports)
    key-value license COPL
    key-value main fcov.4th
    key-value fmix  ~> 0.7
    key-value flint ~> 0.2
    key-list tags coverage
    key-list tags testing
    key-list tags instrumentation
    key-list tags gforth
    \ Integration-test fixtures live under tests/fixtures/ and aren't
    \ exercised by `fmix test` itself — exclude them so self-coverage
    \ runs (`fcov run`) report only fcov's own code.
    key-list fcov-exclude tests/fixtures
    key-list dependencies fsemver git https://github.com/VitaSound/fsemver tag 0.1.0
    key-list dependencies fenum   git https://github.com/VitaSound/fenum   tag 0.1.1
    key-list dependencies ttester git https://github.com/VitaSound/ttester tag 1.2.1
end-forth-package
