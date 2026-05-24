\ tests/run.4th — fixture's «test» entry point.
\ Loads the project sources and exercises a subset of their words. The
\ integration test asserts that fcov reports the *exercised* set as
\ covered and the rest as uncovered.
\
\ NOTE: paths are relative to *this* file, per gforth's `require`
\ search rules. Equivalent to running «gforth tests/run.4th» from the
\ project root.

require ../src/thing.4th
require ../src/util.4th

thing.covered
util.helper

bye
