## EDL type checking.
##
## Consumes the AST and the name-resolution bindings, produces a type for every
## expression node plus a set of diagnostics. Like every other pass it does not
## stop at the first error: it reports, marks the node as a type error, and keeps
## going. A node whose type is `tyError` or `tyUnknown` suppresses further
## diagnostics, so one real mistake yields one message instead of a cascade.
##
## Deliberate rules, so they are not rediscovered as bugs:
##   * no implicit numeric conversions at all; an integer *literal* is assignable
##     to any integer type that can hold it, and to a float type;
##   * `let` bindings cannot be reassigned;
##   * `/` on integers is integer division, `/` on floats is float division;
##   * `%` is defined on integers only;
##   * comparisons require identical operand types and yield `bool`.
##
## Bootstrap dialect: see specs/decisions/ADR-0001.

import ./ast
import ./diagnostics
import ./scopes
import ./types
import ./resolve

type
  CheckContext = ref object
    t: TypeTable
    b: Bindings
    diags: Diagnostics
    nodeTypes: seq[TypeId]
    currentFn: Symbol
    loopDepth: int
    typeDecls: seq[Symbol]   ## indexed by Symbol.typeIndex

  TypeCheckResult* = object
    nodeTypes*: seq[TypeId]  ## indexed by Node.id
    diags*: Diagnostics

# ---- small helpers ---------------------------------------------------------

proc hasDot(s: string): bool =
  for ch in s:
    if ch == '.':
      return true
  result = false

proc joinNames(syms: seq[Symbol]): string =
  result = ""
  for i in 0 ..< syms.len:
    if i > 0:
      result.add(", ")
    result.add(syms[i].name)

proc setType(c: CheckContext, n: Node, id: TypeId) =
  if n != nil and n.id >= 0 and n.id < c.nodeTypes.len:
    c.nodeTypes[n.id] = id

proc typeOf*(c: CheckContext, n: Node): TypeId =
  if n != nil and n.id >= 0 and n.id < c.nodeTypes.len:
    result = c.nodeTypes[n.id]
  else:
    result = tid(tyUnknown)

proc isSuppressed(c: CheckContext, id: TypeId): bool =
  ## A type error already reported upstream: do not report anything on top of it.
  let k = kindOf(c.t, id)
  result = k == tyError or k == tyUnknown

proc typeNameOf(c: CheckContext, id: TypeId): string =
  result = typeName(c.t, id)

proc ownerSymbol(c: CheckContext, id: TypeId): Symbol =
  let info = infoOf(c.t, id)
  if info.kind != tyNamed or info.sym < 0 or info.sym >= c.typeDecls.len:
    result = nil
  else:
    result = c.typeDecls[info.sym]

proc terminates(n: Node): bool =
  ## Conservative "every path leaves the function" analysis, used only to report
  ## a missing return.
  if n == nil:
    return false
  case n.kind
  of nkReturn:
    result = true
  of nkBlock:
    if n.children.len == 0:
      result = false
    else:
      result = terminates(n.children[n.children.len - 1])
  of nkIf:
    result = n.elseBody != nil and terminates(n.body) and
             terminates(n.elseBody)
  else:
    result = false

# ---- types of type expressions ---------------------------------------------

proc resolveTypeExpr(c: CheckContext, typeNode: Node): TypeId =
  if typeNode == nil:
    return tid(tyVoid)
  let name = typeNode.name
  let builtin = builtinKindByName(name)
  if builtin != tyError:
    if isSpecifiedButUnimplemented(builtin):
      discard c.diags.reportError(edlTypeNotImplemented,
        "type '" & name & "' is not implemented yet", typeNode.span,
        "see specs/types.md for the status of each EDL type")
      return tid(tyError)
    return tid(builtin)
  let sym = lookupType(c.b.moduleScope, name)
  if sym != nil:
    return sym.ty
  var help = ""
  if hasDot(name):
    help = "qualified type names are not implemented yet"
  discard c.diags.reportError(edlTypeUnknownType,
    "unknown type '" & name & "'", typeNode.span, help)
  result = tid(tyError)

# ---- signatures ------------------------------------------------------------

proc checkSignatures(c: CheckContext, module: Node) =
  # Named types first, so a struct may refer to a type declared later.
  var nextIndex = 0
  for sym in c.b.structs:
    sym.typeIndex = nextIndex
    sym.ty = addNamedType(c.t, sym.name, nextIndex)
    c.typeDecls.add(sym)
    inc nextIndex
  for sym in c.b.enums:
    sym.typeIndex = nextIndex
    sym.ty = addNamedType(c.t, sym.name, nextIndex)
    c.typeDecls.add(sym)
    inc nextIndex

  # Enum values: each one takes the enum's type, and an explicit value resets
  # the implicit counter.
  for sym in c.b.enums:
    if sym.fields.len == 0:
      discard c.diags.reportError(edlTypeEmptyEnum,
        "enum '" & sym.name & "' must declare at least one value",
        sym.decl.span, "")
    var next: int64 = 0
    var previous: int64 = 0
    var havePrevious = false
    for value in sym.fields:
      var resolved = next
      if value.decl != nil and value.decl.intVal >= 0:
        resolved = value.decl.intVal
      if havePrevious and resolved <= previous:
        discard c.diags.reportError(edlTypeEnumOrder,
          "enum values must be strictly increasing: '" & value.name & "' is " &
          $resolved & " after " & $previous, value.decl.span,
          "implicit values continue from the previous one, so an explicit " &
          "value must be larger than its predecessor")
      value.enumVal = resolved
      value.ty = sym.ty
      value.ownerName = sym.name
      previous = resolved
      havePrevious = true
      next = resolved + 1

  # Struct fields.
  for sym in c.b.structs:
    for field in sym.fields:
      let fieldTy = resolveTypeExpr(c, field.decl.typeAnn)
      field.ty = fieldTy
      if kindOf(c.t, fieldTy) == tyVoid:
        discard c.diags.reportError(edlTypeUnknownType,
          "field '" & field.name & "' cannot have type 'void'",
          field.decl.span, "")

  # Function signatures. Parameter symbols were bound during name resolution.
  for sym in c.b.fns:
    for paramNode in sym.decl.children:
      let paramTy = resolveTypeExpr(c, paramNode.typeAnn)
      if kindOf(c.t, paramTy) == tyVoid:
        discard c.diags.reportError(edlTypeUnknownType,
          "parameter '" & paramNode.name & "' cannot have type 'void'",
          paramNode.span, "")
      sym.paramTypes.add(paramTy)
      let paramSym = symbolOf(c.b, paramNode)
      if paramSym != nil:
        paramSym.ty = paramTy
    sym.fnReturn = resolveTypeExpr(c, sym.decl.typeAnn)

# ---- assignability ---------------------------------------------------------

proc isAssignable(c: CheckContext, target, value: TypeId,
                  valueNode: Node): bool =
  if isSuppressed(c, target) or isSuppressed(c, value):
    return true
  if sameType(c.t, target, value):
    return true
  let targetKind = kindOf(c.t, target)
  if valueNode != nil and valueNode.kind == nkIntLit:
    if isIntegerKind(targetKind) and litFits(targetKind, valueNode.intVal):
      return true
    if isFloatKind(targetKind):
      return true
  # No implicit numeric conversions: same type or an in-range literal, nothing else.
  result = false

# ---- expressions -----------------------------------------------------------

proc checkExpr(c: CheckContext, n: Node): TypeId

proc checkIdent(c: CheckContext, n: Node): TypeId =
  let sym = symbolOf(c.b, n)
  if sym == nil:
    return tid(tyError)
  case sym.kind
  of skLocal, skParam, skField, skEnumValue:
    if kindOf(c.t, sym.ty) == tyUnknown:
      return tid(tyError)
    result = sym.ty
  of skFn, skBuiltin:
    discard c.diags.reportError(edlSemNotImplemented,
      "a function cannot be used as a value yet", n.span,
      "first-class functions are planned; see specs/types.md")
    result = tid(tyError)
  of skStruct, skEnum:
    discard c.diags.reportError(edlSemNotImplemented,
      "'" & n.name & "' is a type, not a value", n.span,
      "enum values are written qualified, for example Color.Red")
    result = tid(tyError)
  else:
    result = tid(tyError)

proc checkBuiltinCall(c: CheckContext, n: Node, sym: Symbol,
                      argc: int): TypeId =
  if sym.name == "print":
    if argc != 1:
      discard c.diags.reportError(edlTypeArgCount,
        "'print' takes exactly one argument but got " & $argc, n.span, "")
      var i = 1
      while i < n.children.len:
        discard checkExpr(c, n.children[i])
        inc i
      return tid(tyVoid)
    let argNode = n.children[1]
    let argTy = checkExpr(c, argNode)
    if not isSuppressed(c, argTy) and not isPrintableKind(kindOf(c.t, argTy)):
      discard c.diags.reportError(edlTypeMismatch,
        "cannot print a value of type " & typeNameOf(c, argTy), argNode.span,
        "print accepts strings, numbers, chars and bools")
    return tid(tyVoid)
  discard c.diags.reportError(edlSemNotImplemented,
    "builtin '" & sym.name & "' is not implemented yet", n.span, "")
  result = tid(tyError)

proc checkCall(c: CheckContext, n: Node): TypeId =
  if n.children.len == 0:
    return tid(tyError)
  let callee = n.children[0]
  let argc = n.children.len - 1
  if callee.kind != nkIdent:
    discard c.diags.reportError(edlSemNotImplemented,
      "only direct calls to named functions are supported yet", callee.span, "")
    var i = 1
    while i < n.children.len:
      discard checkExpr(c, n.children[i])
      inc i
    return tid(tyError)
  let sym = symbolOf(c.b, callee)
  if sym == nil:
    var i = 1
    while i < n.children.len:
      discard checkExpr(c, n.children[i])
      inc i
    return tid(tyError)
  if sym.kind == skBuiltin:
    return checkBuiltinCall(c, n, sym, argc)
  if sym.kind != skFn:
    # Name resolution already reported that this name is not callable.
    return tid(tyError)

  if argc != sym.paramTypes.len:
    discard c.diags.reportError(edlTypeArgCount,
      "function '" & sym.name & "' takes " & $sym.paramTypes.len &
      " argument(s) but got " & $argc, n.span, "")
  var i = 0
  while i < argc:
    let argNode = n.children[i + 1]
    let argTy = checkExpr(c, argNode)
    if i < sym.paramTypes.len:
      let expected = sym.paramTypes[i]
      if not isAssignable(c, expected, argTy, argNode):
        discard c.diags.reportError(edlTypeMismatch,
          "argument " & $(i + 1) & " of '" & sym.name & "' expects " &
          typeNameOf(c, expected) & " but got " & typeNameOf(c, argTy),
          argNode.span, "")
    inc i
  result = sym.fnReturn

proc checkFieldAccess(c: CheckContext, n: Node): TypeId =
  if n.children.len == 0:
    return tid(tyError)
  let receiver = n.children[0]
  # `Color.Red`: the receiver denotes a type, not a value.
  if receiver.kind == nkIdent:
    let receiverSym = symbolOf(c.b, receiver)
    if receiverSym != nil and receiverSym.kind == skEnum:
      for value in receiverSym.fields:
        if value.name == n.name:
          return value.ty
      discard c.diags.reportError(edlTypeUnknownField,
        "enum '" & receiverSym.name & "' has no value named '" & n.name & "'",
        n.span, "known values: " & joinNames(receiverSym.fields))
      return tid(tyError)
  let receiverTy = checkExpr(c, receiver)
  if isSuppressed(c, receiverTy):
    return tid(tyError)
  if kindOf(c.t, receiverTy) != tyNamed:
    discard c.diags.reportError(edlTypeUnknownField,
      "type " & typeNameOf(c, receiverTy) & " has no fields", n.span, "")
    return tid(tyError)
  let owner = ownerSymbol(c, receiverTy)
  if owner == nil or owner.kind != skStruct:
    discard c.diags.reportError(edlTypeUnknownField,
      "type " & typeNameOf(c, receiverTy) & " has no fields", n.span, "")
    return tid(tyError)
  for field in owner.fields:
    if field.name == n.name:
      return field.ty
  discard c.diags.reportError(edlTypeUnknownField,
    "struct '" & owner.name & "' has no field named '" & n.name & "'",
    n.span, "known fields: " & joinNames(owner.fields))
  result = tid(tyError)

proc checkBinary(c: CheckContext, n: Node): TypeId =
  if n.children.len != 2:
    return tid(tyError)
  let leftNode = n.children[0]
  let rightNode = n.children[1]
  let leftTy = checkExpr(c, leftNode)
  let rightTy = checkExpr(c, rightNode)
  if isSuppressed(c, leftTy) or isSuppressed(c, rightTy):
    return tid(tyError)
  let leftKind = kindOf(c.t, leftTy)
  let rightKind = kindOf(c.t, rightTy)
  let op = n.name

  if op == "and" or op == "or":
    if leftKind == tyBool and rightKind == tyBool:
      return tid(tyBool)
    discard c.diags.reportError(edlTypeUnsupportedOp,
      "'" & op & "' requires bool operands, but got " &
      typeNameOf(c, leftTy) & " and " & typeNameOf(c, rightTy), n.span, "")
    return tid(tyError)

  if op == "==" or op == "!=":
    if not isAssignable(c, leftTy, rightTy, rightNode):
      discard c.diags.reportError(edlTypeMismatch,
        "'" & op & "' compares values of the same type, but got " &
        typeNameOf(c, leftTy) & " and " & typeNameOf(c, rightTy), n.span, "")
      return tid(tyError)
    return tid(tyBool)

  if op == "<" or op == "<=" or op == ">" or op == ">=":
    let comparable = (isNumericKind(leftKind) and leftKind == rightKind) or
                     (leftKind == tyString and rightKind == tyString) or
                     (leftKind == tyChar and rightKind == tyChar)
    if not comparable:
      discard c.diags.reportError(edlTypeUnsupportedOp,
        "'" & op & "' cannot compare " & typeNameOf(c, leftTy) & " and " &
        typeNameOf(c, rightTy), n.span, "")
      return tid(tyError)
    return tid(tyBool)

  if op == "+" and leftKind == tyString and rightKind == tyString:
    return tid(tyString)

  if op == "+" or op == "-" or op == "*" or op == "/" or op == "%":
    if op == "%" and (isFloatKind(leftKind) or isFloatKind(rightKind)):
      discard c.diags.reportError(edlTypeUnsupportedOp,
        "'%' is defined for integers only", n.span,
        "use a library function for floating-point remainder")
      return tid(tyError)
    if not (isNumericKind(leftKind) and leftKind == rightKind):
      discard c.diags.reportError(edlTypeUnsupportedOp,
        "'" & op & "' cannot be applied to " & typeNameOf(c, leftTy) & " and " &
        typeNameOf(c, rightTy), n.span, "")
      return tid(tyError)
    return leftTy

  discard c.diags.reportError(edlTypeUnsupportedOp,
    "operator '" & op & "' is not implemented yet", n.span, "")
  result = tid(tyError)

proc checkUnary(c: CheckContext, n: Node): TypeId =
  if n.children.len != 1:
    return tid(tyError)
  let operandTy = checkExpr(c, n.children[0])
  if isSuppressed(c, operandTy):
    return tid(tyError)
  if n.name == "not":
    if kindOf(c.t, operandTy) == tyBool:
      return tid(tyBool)
    discard c.diags.reportError(edlTypeUnsupportedOp,
      "'not' requires a bool, but got " & typeNameOf(c, operandTy), n.span, "")
    return tid(tyError)
  if isNumericKind(kindOf(c.t, operandTy)):
    return operandTy
  discard c.diags.reportError(edlTypeUnsupportedOp,
    "'" & n.name & "' cannot be applied to " & typeNameOf(c, operandTy),
    n.span, "")
  result = tid(tyError)

proc checkExpr(c: CheckContext, n: Node): TypeId =
  if n == nil:
    return tid(tyVoid)
  var id = tid(tyError)
  case n.kind
  of nkIntLit:
    id = tid(defaultIntType(n.intVal))
  of nkFloatLit:
    id = tid(tyF64)
  of nkStringLit:
    id = tid(tyString)
  of nkCharLit:
    id = tid(tyChar)
  of nkBoolLit:
    id = tid(tyBool)
  of nkNilLit:
    discard c.diags.reportError(edlSemNotImplemented,
      "'nil' is not implemented yet", n.span,
      "nullable references are planned; see specs/memory.md")
    id = tid(tyError)
  of nkIdent:
    id = checkIdent(c, n)
  of nkCall:
    id = checkCall(c, n)
  of nkFieldAccess:
    id = checkFieldAccess(c, n)
  of nkIndex:
    if n.children.len > 0:
      discard checkExpr(c, n.children[0])
    discard c.diags.reportError(edlSemNotImplemented,
      "indexing is not implemented yet", n.span,
      "array, slice and map types are planned; see specs/types.md")
    id = tid(tyError)
  of nkBinary:
    id = checkBinary(c, n)
  of nkUnary:
    id = checkUnary(c, n)
  else:
    id = tid(tyError)
  setType(c, n, id)
  result = id

# ---- statements ------------------------------------------------------------

proc checkBlock(c: CheckContext, body: Node)

proc checkStmt(c: CheckContext, n: Node) =
  if n == nil:
    return
  case n.kind
  of nkLetDecl, nkVarDecl:
    var declared = tid(tyUnknown)
    if n.children.len > 0:
      let initNode = n.children[0]
      let initTy = checkExpr(c, initNode)
      if n.typeAnn != nil:
        declared = resolveTypeExpr(c, n.typeAnn)
        if not isAssignable(c, declared, initTy, initNode):
          discard c.diags.reportError(edlTypeNotAssignable,
            "cannot initialise '" & n.name & "' of type " &
            typeNameOf(c, declared) & " with a value of type " &
            typeNameOf(c, initTy), n.span,
            "EDL has no implicit conversions: make the declared type and " &
            "the type of the value match")
      elif isSuppressed(c, initTy):
        declared = tid(tyError)
      else:
        declared = initTy
    elif n.typeAnn != nil:
      declared = resolveTypeExpr(c, n.typeAnn)
    let sym = symbolOf(c.b, n)
    if sym != nil:
      sym.ty = declared
    setType(c, n, declared)

  of nkAssign:
    if n.children.len != 2:
      return
    let target = n.children[0]
    let value = n.children[1]
    if target.kind == nkIdent:
      let targetSym = symbolOf(c.b, target)
      if targetSym != nil and targetSym.kind == skLocal and
         targetSym.decl != nil and targetSym.decl.kind == nkLetDecl:
        discard c.diags.reportError(edlTypeNotAssignable,
          "cannot assign to '" & targetSym.name & "' because it is a 'let' binding",
          target.span, "declare it with 'var' instead")
    let targetTy = checkExpr(c, target)
    let valueTy = checkExpr(c, value)
    if not isAssignable(c, targetTy, valueTy, value):
      var targetName = "the target"
      if target.kind == nkIdent:
        targetName = "'" & target.name & "'"
      discard c.diags.reportError(edlTypeNotAssignable,
        "cannot assign a value of type " & typeNameOf(c, valueTy) & " to " &
        targetName & " of type " & typeNameOf(c, targetTy), n.span, "")

  of nkReturn:
    if c.currentFn == nil:
      return
    let fnReturn = c.currentFn.fnReturn
    let fnIsVoid = kindOf(c.t, fnReturn) == tyVoid
    if n.children.len == 0:
      if not fnIsVoid:
        discard c.diags.reportError(edlTypeReturnMismatch,
          "function '" & c.currentFn.name & "' must return a value of type " &
          typeNameOf(c, fnReturn), n.span, "")
    else:
      let valueNode = n.children[0]
      let valueTy = checkExpr(c, valueNode)
      if fnIsVoid:
        discard c.diags.reportError(edlTypeReturnMismatch,
          "function '" & c.currentFn.name & "' does not return a value",
          n.span, "")
      elif not isAssignable(c, fnReturn, valueTy, valueNode):
        discard c.diags.reportError(edlTypeReturnMismatch,
          "function '" & c.currentFn.name & "' returns " &
          typeNameOf(c, fnReturn) & " but this returns " &
          typeNameOf(c, valueTy), n.span, "")

  of nkIf:
    if n.children.len > 0:
      let condTy = checkExpr(c, n.children[0])
      if not isSuppressed(c, condTy) and kindOf(c.t, condTy) != tyBool:
        discard c.diags.reportError(edlTypeCondNotBool,
          "the condition of 'if' must be a bool but is " &
          typeNameOf(c, condTy), n.children[0].span, "")
    checkBlock(c, n.body)
    if n.elseBody != nil:
      if n.elseBody.kind == nkIf:
        checkStmt(c, n.elseBody)
      else:
        checkBlock(c, n.elseBody)

  of nkWhile:
    if n.children.len > 0:
      let condTy = checkExpr(c, n.children[0])
      if not isSuppressed(c, condTy) and kindOf(c.t, condTy) != tyBool:
        discard c.diags.reportError(edlTypeCondNotBool,
          "the condition of 'while' must be a bool but is " &
          typeNameOf(c, condTy), n.children[0].span, "")
    inc c.loopDepth
    checkBlock(c, n.body)
    dec c.loopDepth

  of nkFor:
    if n.children.len > 0:
      discard checkExpr(c, n.children[0])
    let loopVar = symbolOf(c.b, n)
    if loopVar != nil:
      # No type can be given to a loop variable before collections exist; mark it
      # so that uses inside the body do not produce cascading diagnostics.
      loopVar.ty = tid(tyError)
    discard c.diags.reportError(edlSemNotImplemented,
      "'for' loops need a collection to iterate over, which is not implemented yet",
      n.span, "array, slice, map and set are planned; see specs/types.md")
    inc c.loopDepth
    checkBlock(c, n.body)
    dec c.loopDepth

  of nkBreak, nkContinue:
    if c.loopDepth == 0:
      var keyword = "break"
      if n.kind == nkContinue:
        keyword = "continue"
      discard c.diags.reportError(edlTypeLoopControl,
        "'" & keyword & "' is only allowed inside a loop", n.span,
        "move it into a 'while' loop, or remove it")

  of nkExprStmt:
    if n.children.len > 0:
      discard checkExpr(c, n.children[0])

  of nkBlock:
    checkBlock(c, n)

  else:
    discard

proc checkBlock(c: CheckContext, body: Node) =
  if body == nil:
    return
  for stmt in body.children:
    checkStmt(c, stmt)

# ---- entry point -----------------------------------------------------------

proc typeCheck*(module: Node, nodeCount: int, b: Bindings, t: TypeTable,
                diags: Diagnostics): TypeCheckResult =
  let c = CheckContext(t: t, b: b, diags: diags, nodeTypes: @[],
                       currentFn: nil, loopDepth: 0, typeDecls: @[])
  var i = 0
  while i < nodeCount:
    c.nodeTypes.add(tid(tyUnknown))
    inc i
  checkSignatures(c, module)
  for fnSym in b.fns:
    c.currentFn = fnSym
    checkBlock(c, fnSym.decl.body)
    if kindOf(c.t, fnSym.fnReturn) != tyVoid and
       not isSuppressed(c, fnSym.fnReturn) and
       not terminates(fnSym.decl.body):
      discard c.diags.reportError(edlTypeMissingReturn,
        "function '" & fnSym.name & "' must return a value of type " &
        typeNameOf(c, fnSym.fnReturn) & " on every path", fnSym.decl.span, "")
  c.currentFn = nil
  result.nodeTypes = c.nodeTypes
  result.diags = diags
