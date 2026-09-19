## Migration tests.
##
## The last test is the one that matters: a bootstrap-dialect source file is
## translated, and the translated EDL is then compiled *and run* by the EDL
## compiler, with its output compared against what the original program prints.
## Passing means the migrator produces real EDL -- not text that merely
## resembles it.
##
## The earlier tests pin down individual translations and, just as importantly,
## the report: a construct with no EDL equivalent must be *named*, never
## silently reinvented.
##
## Generated files go to build/edl/migrate/, which is ignored.

import std/os
import std/osproc

import edl/migrate/translate
import edl/diagnostics
import edl/driver

import ../framework

const outRoot = "build/edl/migrate"

proc translated(src: string): MigrateResult =
  result = migrateSource(src, "unit.nim")

proc blockingCount(r: MigrateResult): int =
  result = countNotes(r.notes, mnBlocking)

proc advisoryCount(r: MigrateResult): int =
  result = countNotes(r.notes, mnAdvisory)

proc roundTrip(name, bootstrapSource: string): tuple[ok: bool, output: string,
                                                       detail: string] =
  ## Translate, compile the translation, run it.
  createDir(outRoot)
  let r = migrateSource(bootstrapSource, name & ".nim")
  let edlPath = outRoot / (name & ".edl")
  writeFile(edlPath, r.edlSource)
  var opts = CompileOptions()
  opts.inputPath = edlPath
  opts.outDir = outRoot
  let compiled = compileFile(opts)
  if not compiled.ok:
    return (false, "", render(compiled.diags) & "\n--- translated ---\n" &
      r.edlSource & "\n--- report ---\n" & renderMigrationReport(r))
  let run = execCmdEx(compiled.exePath)
  result = (true, run.output, renderMigrationReport(r))

proc run*() =
  beginSuite("migrate")

  # ---- primitive types are renamed, not guessed at ----
  block:
    let r = translated("proc f(a: int): uint8 =\n  result = 0\n")
    checkContains(r.edlSource, "fn f(a: isize) -> u8 {",
      "int becomes isize and uint8 becomes u8")
    checkContains(r.edlSource, "return 0", "result is rewritten as return")
    checkEqInt(blockingCount(r), 0,
      "a routine using only supported constructs is fully translated")

  # ---- parameters: `;` groups, `,` names, defaults ----
  block:
    let r = translated("proc f(a, b: int; c: string) =\n  discard\n")
    checkContains(r.edlSource, "fn f(a: isize, b: isize, c: string) {",
      "one annotation covers every name in its group")

  block:
    let r = translated("proc f(x: int = 3) =\n  discard\n")
    checkContains(r.edlSource, "fn f(x: isize) {",
      "a default value is dropped from the parameter list")
    checkEqInt(blockingCount(r), 1, "the dropped default is reported as blocking")

  # ---- statements ----
  block:
    let r = translated("proc f() =\n  echo \"hi\"\n")
    checkContains(r.edlSource, "print(\"hi\")", "echo becomes print")

  block:
    let r = translated("proc f() =\n  var n = 1\n  inc n\n  dec n\n")
    checkContains(r.edlSource, "n = n + 1", "inc becomes an assignment")
    checkContains(r.edlSource, "n = n - 1", "dec becomes an assignment")

  block:
    let r = translated("proc f(a: bool) =\n  if a:\n    discard\n")
    checkContains(r.edlSource, "if a {", "if gains braces")
    checkEqInt(blockingCount(r), 0, "a plain if needs no report")

  block:
    let r = translated("proc f(a: bool) =\n  if a: return\n")
    checkContains(r.edlSource, "if a {", "an inline body opens a block")
    checkContains(r.edlSource, "return", "the inline body is translated")

  # ---- the range loop, which EDL does not have yet ----
  block:
    let r = translated("proc f() =\n  for i in 0 ..< 3:\n    discard\n")
    checkContains(r.edlSource, "while i < 3 {",
      "an exclusive range for becomes a while loop")
    checkContains(r.edlSource, "i = i + 1", "the loop variable is advanced")

  block:
    let r = translated("proc f() =\n  for i in 0 .. 3:\n    discard\n")
    checkContains(r.edlSource, "while i <= 3 {",
      "an inclusive range for becomes a while loop")

  block:
    let r = translated("proc f() =\n  for x in 0 ..< 3:\n    continue\n")
    checkEqInt(blockingCount(r), 1,
      "a continue inside a desugared for is reported: the increment would be skipped")

  block:
    let r = translated("proc f(items: int) =\n  for x in items:\n    discard\n")
    checkEqInt(blockingCount(r), 1,
      "a for over a collection is reported rather than invented")

  # ---- enum values are qualified, the way EDL requires ----
  block:
    let r = translated("type\n  Color = enum\n    Red, Green\n\n" &
      "proc f(c: Color): bool =\n  if c == Red:\n    return true\n  else:\n    return false\n")
    checkContains(r.edlSource, "c == Color.Red",
      "a bare enum value is qualified with its type")
    checkContains(r.edlSource, "enum Color {", "the enum is translated")

  # ---- structs ----
  block:
    let r = translated("type\n  Point = object\n    x: int\n    y: int\n")
    checkContains(r.edlSource, "struct Point {", "an object becomes a struct")
    checkContains(r.edlSource, "x: isize", "fields keep their types")

  # ---- constructs with no EDL equivalent are reported, not invented ----
  block:
    let r = translated("import std/strutils\n")
    checkEqInt(blockingCount(r), 1, "an import is reported as blocking")

  block:
    let r = translated("proc f() =\n  let xs = @[1, 2]\n")
    check(blockingCount(r) > 0, "a sequence literal is reported")
    checkContains(r.edlSource, "let xs = @[1, 2]",
      "the sequence literal is still emitted, marked by the report")

  block:
    let r = translated("proc f() =\n  raise newError()\n")
    checkEqInt(blockingCount(r), 1, "raise is reported")
    checkContains(r.edlSource, "// raise",
      "a construct with no equivalent is commented out, so the file still parses")

  block:
    let r = translated("type\n  Buf = seq[byte]\n")
    checkContains(r.edlSource, "// type Buf = seq[byte]",
      "an unsupported type alias is commented out")

  block:
    let r = translated("proc f() =\n  discard\n")
    checkEqInt(blockingCount(r), 0, "a bare discard needs no report")
    checkEqInt(advisoryCount(r), 0, "a bare discard is not a note either")

  # ---- line structure: continuations and split headers ----
  block:
    let r = translated("proc f(k: int): bool =\n" &
      "  if k == 1 or k == 2 or\n     k == 3:\n    return true\n  return false\n")
    checkContains(r.edlSource, "if k == 1 or k == 2 or k == 3 {",
      "a condition continued on the next line stays one condition")
    checkEqInt(blockingCount(r), 0, "a continued condition needs no report")

  block:
    let r = translated("proc f(a: int,\n       b: int): int =\n  result = a + b\n")
    checkContains(r.edlSource, "fn f(a: isize, b: isize) -> isize {",
      "a header split over two lines keeps its return type")

  # ---- literal suffixes must not swallow what follows them ----
  block:
    let r = translated("proc f() =\n  let x = 0'i64\n\nproc g() =\n  discard\n")
    checkContains(r.edlSource, "let x = 0", "a literal type suffix is dropped")
    checkContains(r.edlSource, "fn g()",
      "a literal suffix does not swallow the rest of the file")
    checkEqInt(blockingCount(r), 0, "a literal suffix does not block")

  # ---- `result` is a return only where that is what it means ----
  block:
    let r = translated("proc f(a: int): int =\n" &
      "  result = a\n  echo a\n  result = a + 1\n")
    checkContains(r.edlSource, "return a + 1",
      "a tail assignment to result becomes a return")
    checkContains(r.edlSource, "result = a\n",
      "a mid-routine assignment is left visible")
    checkEqInt(blockingCount(r), 1,
      "only the mid-routine assignment is reported, because its meaning differs")

  # ---- an `=` body that is an expression returns its value ----
  block:
    let r = translated("proc f(a: int): int =\n  if a > 0:\n    1\n" &
      "  else:\n    2\n")
    checkContains(r.edlSource, "return 1",
      "a branch of an expression body returns its value")

  # ---- object construction, which EDL cannot express yet ----
  block:
    let r = translated("type\n  Point = object\n    x: int\n\n" &
      "proc f(): Point =\n  result = Point(x: 1)\n")
    checkEqInt(blockingCount(r), 1, "an object construction is reported")

  # ---- the round trip ----
  block:
    let t = roundTrip("roundtrip",
      "proc area(w: int32; h: int32): int32 =\n" &
      "  result = w * h\n" &
      "\n" &
      "proc main() =\n" &
      "  echo area(6, 7)\n" &
      "  var total = 0\n" &
      "  for i in 0 ..< 4:\n" &
      "    total = total + i\n" &
      "  echo total\n" &
      "  var count = 3\n" &
      "  while count > 0:\n" &
      "    count = count - 1\n" &
      "  if count == 0 and not false:\n" &
      "    echo \"done\"\n" &
      "  echo \"ok\"\n")
    check(t.ok, "the translated program compiles")
    if not t.ok:
      echo t.detail
    checkEqStr(t.output, "42\n6\ndone\nok\n",
      "the translated program prints exactly what the original describes")

  block:
    let t = roundTrip("casebody",
      "proc nameOf(n: int32): string =\n" &
      "  case n\n" &
      "  of 1: \"one\"\n" &
      "  of 2, 3: \"few\"\n" &
      "  else: \"many\"\n" &
      "\n" &
      "proc main() =\n" &
      "  echo nameOf(1)\n" &
      "  echo nameOf(3)\n" &
      "  echo nameOf(9)\n")
    check(t.ok, "a translated case-expression body compiles")
    if not t.ok:
      echo t.detail
    checkEqStr(t.output, "one\nfew\nmany\n",
      "every branch of the translated case returns its value")

  block:
    let t = roundTrip("enums",
      "type\n" &
      "  Color = enum\n" &
      "    Red, Green, Blue\n" &
      "\n" &
      "proc isRed(c: Color): bool =\n" &
      "  if c == Red:\n" &
      "    return true\n" &
      "  else:\n" &
      "    return false\n" &
      "\n" &
      "proc main() =\n" &
      "  echo isRed(Green)\n" &
      "  echo isRed(Red)\n")
    check(t.ok, "a translated program using an enum compiles")
    if not t.ok:
      echo t.detail
    checkEqStr(t.output, "false\ntrue\n",
      "qualified enum values keep their meaning")
