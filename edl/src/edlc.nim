## `edlc` -- the EDL compiler.
##
## Command surface:
##
##   edlc check     <file.edl>          parse and type check, build nothing
##   edlc build     <file.edl>          compile to a native executable
##   edlc run       <file.edl>          build, then run
##   edlc emit-nim  <file.edl>          stop after emitting backend source
##   edlc emit-ast  <file.edl>          print the parsed syntax tree
##   edlc migrate   <file.nim>          translate bootstrap-dialect source to EDL, with a report
##   edlc version
##   edlc help
##
## `init`, `fmt`, `test`, `doc`, `add` and `remove` are part of the toolchain
## contract and report themselves as not implemented yet rather than pretending
## to work or silently doing nothing.
##
## Exit codes: 0 success, 1 compilation error, 2 usage error or unimplemented
## command, otherwise the exit code of the program that was run.
##
## Bootstrap dialect: see specs/decisions/ADR-0001.

import std/os

import edl/diagnostics
import edl/driver
import edl/migrate/translate

const edlVersion = "0.1.0"

proc printUsage() =
  echo "edl " & edlVersion & " - the EDL compiler"
  echo ""
  echo "usage: edl <command> [options] <file.edl>"
  echo ""
  echo "commands"
  echo "  check     parse and type check a program, build nothing"
  echo "  build     compile a program to a native executable"
  echo "  run       build a program and run it"
  echo "  emit-nim  stop after emitting the bootstrap backend source"
  echo "  emit-ast  print the parsed syntax tree"
  echo "  migrate   translate a bootstrap-dialect source file to EDL and report what could not be"
  echo "  version   print the compiler version"
  echo "  help      print this message"
  echo "  init, fmt, test, doc, add, remove   not implemented yet"
  echo ""
  echo "options"
  echo "  -o <path>        output executable path"
  echo "  --out-dir <dir>  where generated files go (default: .edlout)"
  echo "  --nim <path>     bootstrap compiler to use (default: bin/nim)"
  echo "  --print          print the generated source (emit-nim)"
  echo "  --dump-ir        print the EDL intermediate representation"
  echo "  --stdout         print the translation instead of writing a file (migrate)"

proc usageError(message: string): int =
  echo "edl: " & message
  echo "run 'edl help' for usage."
  result = 2

proc showDiagnostics(diags: Diagnostics) =
  if diags != nil and diags.items.len > 0:
    echo render(diags)

proc runCompileCommand(command: string, args: seq[string]): int =
  var opts = CompileOptions()
  var inputPath = ""
  var printSource = false
  var i = 1
  while i < args.len:
    let arg = args[i]
    case arg
    of "-o", "--output":
      if i + 1 >= args.len:
        return usageError("'" & arg & "' needs a path")
      inc i
      opts.outputPath = args[i]
    of "--out-dir":
      if i + 1 >= args.len:
        return usageError("'" & arg & "' needs a directory")
      inc i
      opts.outDir = args[i]
    of "--nim":
      if i + 1 >= args.len:
        return usageError("'" & arg & "' needs a path")
      inc i
      opts.bootstrapExe = args[i]
    of "--print":
      printSource = true
    of "--dump-ir":
      opts.dumpIr = true
    of "--emit-only":
      opts.emitOnly = true
    else:
      if arg.len > 0 and arg[0] == '-':
        return usageError("unknown option '" & arg & "'")
      elif inputPath.len == 0:
        inputPath = arg
      else:
        return usageError("only one input file is supported")
    inc i

  if inputPath.len == 0:
    return usageError("'" & command & "' needs an input file")

  opts.inputPath = inputPath
  if command == "check" or command == "emit-nim" or command == "emit-ast":
    opts.emitOnly = true
  if command == "emit-ast":
    opts.dumpAst = true

  let r = compileFile(opts)

  if command == "emit-ast":
    if r.astDump.len > 0:
      echo r.astDump
    showDiagnostics(r.diags)
    if r.ok: 0 else: 1

  elif command == "check":
    showDiagnostics(r.diags)
    if r.ok:
      echo inputPath & ": ok"
      0
    else:
      1

  elif command == "emit-nim":
    showDiagnostics(r.diags)
    if r.ok:
      if printSource:
        echo r.generatedSource
      else:
        echo r.generatedPath
      0
    else:
      1

  else:
    # build, and run
    if opts.dumpIr:
      echo r.irDump
    showDiagnostics(r.diags)
    if not r.ok:
      if r.toolOutput.len > 0:
        echo r.toolOutput
      1
    elif command == "run":
      runProgram(r.exePath, "")
    else:
      echo r.exePath
      0

proc runMigrateCommand(args: seq[string]): int =
  ## `edl migrate` reads bootstrap-dialect source and writes EDL. The report is
  ## the point: it names
  ## every construct that has no EDL equivalent yet.
  var inputPath = ""
  var outputPath = ""
  var toStdout = false
  var i = 1
  while i < args.len:
    let arg = args[i]
    case arg
    of "-o", "--output":
      if i + 1 >= args.len:
        return usageError("'" & arg & "' needs a path")
      inc i
      outputPath = args[i]
    of "--stdout":
      toStdout = true
    else:
      if arg.len > 0 and arg[0] == '-':
        return usageError("unknown option '" & arg & "'")
      elif inputPath.len == 0:
        inputPath = arg
      else:
        return usageError("only one input file is supported")
    inc i

  if inputPath.len == 0:
    return usageError("'migrate' needs an input file")
  if not fileExists(inputPath):
    return usageError("no such file: " & inputPath)

  let migrated = migrateSource(readFile(inputPath), inputPath)

  if toStdout:
    echo migrated.edlSource
  else:
    if outputPath.len == 0:
      let parts = splitFile(inputPath)
      outputPath = parts.dir / parts.name & ".edl"
    writeFile(outputPath, migrated.edlSource)
    echo "edl migrate: wrote " & outputPath
    echo ""

  echo renderMigrationReport(migrated)
  if countNotes(migrated.notes, mnBlocking) > 0:
    1
  else:
    0

proc main(): int =
  let args = commandLineParams()
  if args.len == 0:
    printUsage()
    return 0
  let command = args[0]
  case command
  of "help", "--help", "-h":
    printUsage()
    0
  of "version", "--version":
    echo "edl " & edlVersion
    0
  of "check", "build", "run", "emit-nim", "emit-ast":
    runCompileCommand(command, args)
  of "migrate":
    runMigrateCommand(args)
  of "init", "fmt", "test", "doc", "add", "remove":
    echo "edl: '" & command & "' is not implemented yet."
    echo "     The toolchain contract is defined in specs/compiler.md;"
    echo "     this command arrives with the toolchain phase."
    2
  else:
    echo "edl: unknown command '" & command & "'"
    printUsage()
    2

quit(main())
