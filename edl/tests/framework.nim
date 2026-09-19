## Minimal assertion framework for the EDL test suite.
##
## Deliberately hand-written: the substrate's `unittest` module is template- and
## macro-based, and ADR-0001 forbids that in EDL code. A test framework is
## exactly the kind of code that should be migratable to EDL mechanically, so it
## is plain procs and counters.

import std/strutils

type
  TestStats* = ref object
    checks*: int
    failures*: int
    suite*: string

var gStats = TestStats(checks: 0, failures: 0, suite: "")

proc beginSuite*(name: string) =
  gStats.suite = name
  echo ""
  echo "== " & name

proc failLine(what, detail: string) =
  inc gStats.failures
  echo "FAIL [" & gStats.suite & "] " & what
  if detail.len > 0:
    echo "     " & detail

proc check*(cond: bool, what: string) =
  inc gStats.checks
  if cond:
    echo "ok   [" & gStats.suite & "] " & what
  else:
    failLine(what, "")

proc checkEqStr*(actual, expected, what: string) =
  inc gStats.checks
  if actual == expected:
    echo "ok   [" & gStats.suite & "] " & what
  else:
    failLine(what, "expected \"" & expected & "\" but got \"" & actual & "\"")

proc checkEqInt*(actual, expected: int, what: string) =
  inc gStats.checks
  if actual == expected:
    echo "ok   [" & gStats.suite & "] " & what
  else:
    failLine(what, "expected " & $expected & " but got " & $actual)

proc checkEqInt64*(actual, expected: int64, what: string) =
  inc gStats.checks
  if actual == expected:
    echo "ok   [" & gStats.suite & "] " & what
  else:
    failLine(what, "expected " & $expected & " but got " & $actual)

proc checkContains*(haystack, needle, what: string) =
  inc gStats.checks
  if haystack.find(needle) >= 0:
    echo "ok   [" & gStats.suite & "] " & what
  else:
    failLine(what, "expected the text to contain \"" & needle & "\"")

proc report*(): int =
  ## Prints the summary and returns the process exit code.
  echo ""
  if gStats.failures == 0:
    echo "PASS: " & $gStats.checks & " checks"
    result = 0
  else:
    echo "FAIL: " & $gStats.failures & " of " & $gStats.checks & " checks failed"
    result = 1
