## Lowering: typed AST -> EDL IR.
##
## This pass resolves the last pieces of structure that the frontend kept
## implicit: which binding an identifier referred to (local or parameter), how an
## enum value is named, and how statements nest. What comes out has no scopes and
## no names left to look up.
##
## It runs only on programs with no diagnostics, so it never has to invent a
## recovery value for a malformed node.
##
## Bootstrap dialect: see specs/decisions/ADR-0001.

import ./ast
import ./types
import ./scopes
import ./resolve
import ./typecheck
import ./ir

type
  LowerContext = ref object
    b: Bindings
    nodeTypes: seq[TypeId]

proc typeOfNode(c: LowerContext, n: Node): TypeId =
  if n != nil and n.id >= 0 and n.id < c.nodeTypes.len:
    result = c.nodeTypes[n.id]
  else:
    result = tid(tyVoid)

proc lowerExpr(c: LowerContext, n: Node): IrNode

proc lowerArgs(c: LowerContext, n: Node, firstIndex: int): seq[IrNode] =
  result = @[]
  var i = firstIndex
  while i < n.children.len:
    result.add(lowerExpr(c, n.children[i]))
    inc i

proc lowerIdent(c: LowerContext, n: Node): IrNode =
  let ty = typeOfNode(c, n)
  let sym = symbolOf(c.b, n)
  if sym == nil:
    return newIr(irError, ty)
  case sym.kind
  of skParam:
    result = newIr(irParam, ty)
    result.name = sym.name
  of skLocal:
    result = newIr(irLocal, ty)
    result.name = sym.name
  of skEnumValue:
    result = newIr(irEnumValue, ty)
    result.name = sym.name
    result.ownerName = sym.ownerName
  else:
    result = newIr(irError, ty)

proc lowerFieldAccess(c: LowerContext, n: Node): IrNode =
  let ty = typeOfNode(c, n)
  if n.children.len == 0:
    return newIr(irError, ty)
  let receiver = n.children[0]
  # `Color.Red` is an enum value, not a field access.
  if receiver.kind == nkIdent:
    let receiverSym = symbolOf(c.b, receiver)
    if receiverSym != nil and receiverSym.kind == skEnum:
      result = newIr(irEnumValue, ty)
      result.name = n.name
      result.ownerName = receiverSym.name
      return
  result = newIr(irFieldAccess, ty)
  result.name = n.name
  result.args.add(lowerExpr(c, receiver))

proc lowerCall(c: LowerContext, n: Node): IrNode =
  let ty = typeOfNode(c, n)
  if n.children.len == 0:
    return newIr(irError, ty)
  let callee = n.children[0]
  var sym: Symbol = nil
  if callee.kind == nkIdent:
    sym = symbolOf(c.b, callee)
  let args = lowerArgs(c, n, 1)
  if sym != nil and sym.kind == skBuiltin:
    result = newIr(irBuiltinCall, ty)
    result.name = sym.name
  else:
    result = newIr(irCall, ty)
    result.name = callee.name
  result.args = args

proc lowerExpr(c: LowerContext, n: Node): IrNode =
  if n == nil:
    return newIr(irError, tid(tyVoid))
  let ty = typeOfNode(c, n)
  case n.kind
  of nkIntLit:
    result = newIr(irIntLit, ty)
    result.intVal = n.intVal
  of nkFloatLit:
    result = newIr(irFloatLit, ty)
    result.floatVal = n.floatVal
  of nkStringLit:
    result = newIr(irStringLit, ty)
    result.strVal = n.strVal
  of nkCharLit:
    result = newIr(irCharLit, ty)
    result.strVal = n.strVal
  of nkBoolLit:
    result = newIr(irBoolLit, ty)
    result.boolVal = n.boolVal
  of nkIdent:
    result = lowerIdent(c, n)
  of nkCall:
    result = lowerCall(c, n)
  of nkFieldAccess:
    result = lowerFieldAccess(c, n)
  of nkBinary:
    result = newIr(irBinary, ty)
    result.name = n.name
    for child in n.children:
      result.args.add(lowerExpr(c, child))
  of nkUnary:
    result = newIr(irUnary, ty)
    result.name = n.name
    for child in n.children:
      result.args.add(lowerExpr(c, child))
  else:
    result = newIr(irError, ty)

proc lowerBlock(c: LowerContext, body: Node): seq[IrNode]

proc lowerStmt(c: LowerContext, n: Node): IrNode =
  if n == nil:
    return newIr(irError, tid(tyVoid))
  case n.kind
  of nkLetDecl, nkVarDecl:
    let kind = if n.kind == nkLetDecl: irLet else: irVar
    result = newIr(kind, typeOfNode(c, n))
    result.name = n.name
    if n.children.len > 0:
      result.args.add(lowerExpr(c, n.children[0]))
  of nkAssign:
    result = newIr(irAssign, tid(tyVoid))
    for child in n.children:
      result.args.add(lowerExpr(c, child))
  of nkReturn:
    result = newIr(irReturn, tid(tyVoid))
    for child in n.children:
      result.args.add(lowerExpr(c, child))
  of nkExprStmt:
    result = newIr(irExprStmt, tid(tyVoid))
    for child in n.children:
      result.args.add(lowerExpr(c, child))
  of nkIf:
    result = newIr(irIf, tid(tyVoid))
    if n.children.len > 0:
      result.args.add(lowerExpr(c, n.children[0]))
    result.thenBody = lowerBlock(c, n.body)
    if n.elseBody != nil:
      if n.elseBody.kind == nkIf:
        result.elseBody = @[lowerStmt(c, n.elseBody)]
      else:
        result.elseBody = lowerBlock(c, n.elseBody)
  of nkWhile:
    result = newIr(irWhile, tid(tyVoid))
    if n.children.len > 0:
      result.args.add(lowerExpr(c, n.children[0]))
    result.thenBody = lowerBlock(c, n.body)
  of nkBlock:
    result = newIr(irBlock, tid(tyVoid))
    result.thenBody = lowerBlock(c, n)
  of nkBreak:
    result = newIr(irBreak, tid(tyVoid))
  of nkContinue:
    result = newIr(irContinue, tid(tyVoid))
  else:
    result = newIr(irError, tid(tyVoid))

proc lowerBlock(c: LowerContext, body: Node): seq[IrNode] =
  result = @[]
  if body == nil:
    return
  for stmt in body.children:
    result.add(lowerStmt(c, stmt))

proc lowerModule*(module: Node, b: Bindings, checked: TypeCheckResult,
                  t: TypeTable, name: string,
                  sourcePath: string): IrModule =
  let c = LowerContext(b: b, nodeTypes: checked.nodeTypes)
  result = IrModule(name: name, sourcePath: sourcePath, fns: @[],
                    structs: @[], enums: @[], hasMain: hasMain(b) != nil)
  for sym in b.structs:
    var s = IrStruct(name: sym.name, fields: @[])
    for field in sym.fields:
      s.fields.add(IrField(name: field.name, ty: field.ty))
    result.structs.add(s)
  for sym in b.enums:
    var e = IrEnum(name: sym.name, values: @[])
    for value in sym.fields:
      e.values.add(IrEnumValue(name: value.name, value: value.enumVal))
    result.enums.add(e)
  for sym in b.fns:
    var fn = IrFn(name: sym.name, params: @[], returnType: sym.fnReturn,
                  body: @[])
    var i = 0
    for paramNode in sym.decl.children:
      var paramTy = tid(tyError)
      if i < sym.paramTypes.len:
        paramTy = sym.paramTypes[i]
      fn.params.add(IrParam(name: paramNode.name, ty: paramTy))
      inc i
    fn.body = lowerBlock(c, sym.decl.body)
    result.fns.add(fn)
