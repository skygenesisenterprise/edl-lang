## The bootstrap backend: EDL IR -> Nim source.
##
## This backend exists so that EDL programs can be built and executed as real
## native binaries while EDL has no native backend of its own. It is a
## *transition* device, not a design decision: EDL semantics are defined by EDL,
## and this module is the only place allowed to know that a Nim compiler is
## involved.
##
## Two mappings are worth knowing, because they are EDL rules that happen to be
## implemented here:
##
##   * `/` on integers is integer division -> Nim `div`
##     (`/` on floats is float division -> Nim `/`)
##   * `print(x)` -> `echo x`, a temporary builtin (see resolve.nim)
##
## Every generated identifier is quoted with backticks when it collides with a
## Nim keyword, so an EDL name can never change the meaning of the generated code.
##
## Bootstrap dialect: see specs/decisions/ADR-0001.

import std/osproc
import std/streams

import ../ir
import ../types

# ---- naming ----------------------------------------------------------------

proc isNimKeyword(name: string): bool =
  case name
  of "addr", "and", "as", "asm", "bind", "block", "break", "case", "cast",
     "concept", "const", "continue", "converter", "defer", "discard", "distinct",
     "div", "do", "elif", "else", "end", "enum", "except", "export", "finally",
     "for", "from", "func", "if", "import", "in", "include", "interface", "is",
     "isnot", "iterator", "let", "macro", "method", "mixin", "mod", "nil", "not",
     "notin", "object", "of", "or", "out", "proc", "ptr", "raise", "ref",
     "return", "shl", "shr", "static", "template", "try", "tuple", "type",
     "using", "var", "when", "while", "xor", "yield":
    true
  else:
    false

proc nimIdent*(name: string): string =
  ## Quotes a name that would otherwise be read as a Nim keyword.
  if isNimKeyword(name):
    result = "`" & name & "`"
  else:
    result = name

proc nimTypeName*(t: TypeTable, id: TypeId): string =
  let k = kindOf(t, id)
  case k
  of tyBool: result = "bool"
  of tyI8: result = "int8"
  of tyI16: result = "int16"
  of tyI32: result = "int32"
  of tyI64: result = "int64"
  of tyU8: result = "uint8"
  of tyU16: result = "uint16"
  of tyU32: result = "uint32"
  of tyU64: result = "uint64"
  of tyIsize: result = "int"
  of tyUsize: result = "uint"
  of tyF32: result = "float32"
  of tyF64: result = "float64"
  of tyChar: result = "char"
  of tyString: result = "string"
  of tyVoid: result = "void"
  of tyNamed: result = nimIdent(typeName(t, id))
  else: result = "void"

# ---- literals --------------------------------------------------------------

proc escapeString(s: string): string =
  result = "\""
  for ch in s:
    case ch
    of '\\': result.add("\\\\")
    of '"': result.add("\\\"")
    of '\n': result.add("\\n")
    of '\r': result.add("\\r")
    of '\t': result.add("\\t")
    of '\0': result.add("\\0")
    else: result.add(ch)
  result.add("\"")

proc escapeChar(s: string): string =
  if s.len == 0:
    return "'\\0'"
  let ch = s[0]
  var body = ""
  case ch
  of '\\': body = "\\\\"
  of '\'': body = "\\'"
  of '\n': body = "\\n"
  of '\r': body = "\\r"
  of '\t': body = "\\t"
  of '\0': body = "\\0"
  else: body = $ch
  result = "'" & body & "'"

# ---- expressions -----------------------------------------------------------

proc emitExpr(e: IrNode, t: TypeTable): string

proc joinArgs(args: seq[IrNode], t: TypeTable): string =
  result = ""
  for i in 0 ..< args.len:
    if i > 0:
      result.add(", ")
    result.add(emitExpr(args[i], t))

proc emitExpr(e: IrNode, t: TypeTable): string =
  if e == nil:
    return "nil"
  case e.kind
  of irIntLit:
    result = $e.intVal
  of irFloatLit:
    result = $e.floatVal
  of irStringLit:
    result = escapeString(e.strVal)
  of irCharLit:
    result = escapeChar(e.strVal)
  of irBoolLit:
    if e.boolVal: result = "true" else: result = "false"
  of irLocal, irParam:
    result = nimIdent(e.name)
  of irEnumValue:
    result = nimIdent(e.ownerName) & "." & nimIdent(e.name)
  of irCall:
    result = nimIdent(e.name) & "(" & joinArgs(e.args, t) & ")"
  of irBuiltinCall:
    if e.name == "print" and e.args.len == 1:
      result = "echo " & emitExpr(e.args[0], t)
    else:
      result = nimIdent(e.name) & "(" & joinArgs(e.args, t) & ")"
  of irBinary:
    var op = e.name
    if op == "/" and isIntegerKind(kindOf(t, e.ty)):
      # EDL: '/' on integers is integer division, as in Go and Rust.
      op = "div"
    elif op == "+" and kindOf(t, e.ty) == tyString:
      # EDL uses '+' for string concatenation; Nim uses '&'.
      op = "&"
    if e.args.len == 2:
      result = "(" & emitExpr(e.args[0], t) & " " & op & " " &
               emitExpr(e.args[1], t) & ")"
    else:
      result = "0"
  of irUnary:
    if e.args.len == 1:
      var op = "-"
      if e.name == "not":
        op = "not "
      result = "(" & op & emitExpr(e.args[0], t) & ")"
    else:
      result = "0"
  of irFieldAccess:
    if e.args.len == 1:
      result = emitExpr(e.args[0], t) & "." & nimIdent(e.name)
    else:
      result = "nil"
  else:
    result = "default(" & nimTypeName(t, e.ty) & ")"

# ---- instructions ----------------------------------------------------------

proc indentTo(level: int, dest: var string) =
  var i = 0
  while i < level:
    dest.add("  ")
    inc i

proc emitBody(nodes: seq[IrNode], level: int, t: TypeTable, dest: var string)

proc emitStmt(e: IrNode, level: int, t: TypeTable, dest: var string) =
  if e == nil:
    return
  case e.kind
  of irLet, irVar:
    indentTo(level, dest)
    if e.kind == irLet:
      dest.add("let ")
    else:
      dest.add("var ")
    dest.add(nimIdent(e.name) & ": " & nimTypeName(t, e.ty) & " = ")
    if e.args.len > 0:
      dest.add(emitExpr(e.args[0], t))
    else:
      dest.add("default(" & nimTypeName(t, e.ty) & ")")
    dest.add("\n")
  of irAssign:
    if e.args.len == 2:
      indentTo(level, dest)
      dest.add(emitExpr(e.args[0], t) & " = " & emitExpr(e.args[1], t) & "\n")
  of irReturn:
    indentTo(level, dest)
    if e.args.len > 0:
      dest.add("return " & emitExpr(e.args[0], t) & "\n")
    else:
      dest.add("return\n")
  of irExprStmt:
    if e.args.len > 0:
      let arg = e.args[0]
      indentTo(level, dest)
      if kindOf(t, arg.ty) == tyVoid:
        dest.add(emitExpr(arg, t) & "\n")
      else:
        # Nim requires an unused value to be discarded explicitly.
        dest.add("discard " & emitExpr(arg, t) & "\n")
  of irIf:
    if e.args.len > 0:
      indentTo(level, dest)
      dest.add("if " & emitExpr(e.args[0], t) & ":\n")
      emitBody(e.thenBody, level + 1, t, dest)
      if e.elseBody.len > 0:
        indentTo(level, dest)
        dest.add("else:\n")
        emitBody(e.elseBody, level + 1, t, dest)
  of irWhile:
    if e.args.len > 0:
      indentTo(level, dest)
      dest.add("while " & emitExpr(e.args[0], t) & ":\n")
      emitBody(e.thenBody, level + 1, t, dest)
  of irBlock:
    indentTo(level, dest)
    dest.add("block:\n")
    emitBody(e.thenBody, level + 1, t, dest)
  of irBreak:
    indentTo(level, dest)
    dest.add("break\n")
  of irContinue:
    indentTo(level, dest)
    dest.add("continue\n")
  else:
    discard

proc emitBody(nodes: seq[IrNode], level: int, t: TypeTable, dest: var string) =
  if nodes.len == 0:
    # Nim has no empty block: an explicit discard keeps it syntactically valid.
    indentTo(level, dest)
    dest.add("discard\n")
    return
  for n in nodes:
    emitStmt(n, level, t, dest)

# ---- module ----------------------------------------------------------------

proc emitNimModule*(m: IrModule, t: TypeTable): string =
  result = ""
  result.add("# Generated by the EDL compiler (bootstrap Nim backend). Do not edit.\n")
  result.add("#   source: " & m.sourcePath & "\n")
  result.add("#   EDL lowers to Nim only while it has no native backend of its own.\n\n")

  if m.structs.len > 0 or m.enums.len > 0:
    result.add("type\n")
    for s in m.structs:
      result.add("  " & nimIdent(s.name) & " = object\n")
      if s.fields.len == 0:
        result.add("    discard\n")
      for f in s.fields:
        result.add("    " & nimIdent(f.name) & ": " & nimTypeName(t, f.ty) & "\n")
    for e in m.enums:
      result.add("  " & nimIdent(e.name) & " = enum\n")
      for v in e.values:
        result.add("    " & nimIdent(v.name) & " = " & $v.value & "\n")
    result.add("\n")

  for fn in m.fns:
    result.add("proc " & nimIdent(fn.name) & "(")
    for i in 0 ..< fn.params.len:
      if i > 0:
        result.add("; ")
      result.add(nimIdent(fn.params[i].name) & ": " & nimTypeName(t, fn.params[i].ty))
    result.add(")")
    if kindOf(t, fn.returnType) != tyVoid:
      result.add(": " & nimTypeName(t, fn.returnType))
    result.add(" =\n")
    emitBody(fn.body, 1, t, result)
    result.add("\n")

  if m.hasMain:
    result.add("when isMainModule:\n  main()\n")

# ---- driving the substrate compiler ----------------------------------------

proc compileNimSource*(nimExe, srcPath, outPath, workDir, cacheDir: string,
                       output: var string): bool =
  ## Invokes the Nim bootstrap compiler on the generated source. Only this
  ## module is allowed to know that step exists.
  var args: seq[string] = @[]
  args.add("c")
  args.add("--hints:off")
  args.add("--skipUserCfg")
  args.add("--skipParentCfg")
  if cacheDir.len > 0:
    args.add("--nimcache:" & cacheDir)
  args.add("-o:" & outPath)
  args.add(srcPath)
  try:
    let process = startProcess(nimExe, workingDir = workDir, args = args,
                               options = {poStdErrToStdOut, poUsePath})
    let captured = process.outputStream.readAll()
    let exitCode = process.waitForExit()
    process.close()
    output = captured
    result = exitCode == 0
  except OSError:
    output = "could not run '" & nimExe & "'"
    result = false
