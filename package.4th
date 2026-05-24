\ Follows theforth.net publishing guidelines:
\   https://theforth.net/guidelines
\ Order: mandatory meta keys first (name, version, license, main),
\ optional metadata (description, tags), runtime tool requirements,
\ library dependencies last.
forth-package
    key-value name fcov
    key-value version 0.1.0
    key-value description Coverage collector for Forth source trees (scaffold release; full instrumentation in 0.2.0)
    key-value license COPL
    key-value main fcov.4th
    key-value fmix  ~> 0.7
    key-value flint ~> 0.2
    key-list tags coverage
    key-list tags testing
    key-list tags instrumentation
    key-list tags gforth
    key-list dependencies fsemver git https://github.com/VitaSound/fsemver tag 0.1.0
    key-list dependencies ttester git https://github.com/VitaSound/ttester tag 1.2.0
end-forth-package
