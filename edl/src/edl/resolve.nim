## EDL name resolution.
##
## Two passes over the tree:
##   1. every top-level declaration (function, struct, enum) and every member is
##      declared, so forward references and mutual recursion work;
##   2. every function body is walked, declaring parameters and locals as they
##      are reached and binding each identifier to the symbol it denotes.
##
## Name resolution binds identifiers only. It never computes a type; it does
## check *callability*, because "this name is not a function" is a question about
## what the name denotes, not about types.
##
## Results are stored as side tables indexed by `Node.id` (`Bindings`), so the
## AST stays purely syntactic -- see specs/compiler.md.
##
## Bootstrap dialect: see specs/decisions/ADR-0001.

import ./ast
import ./diagnostics
import ./scopes
import ./types

type
  Bindings* = ref object
    nodeSym*: seq[Symbol]   ## indexed by Node.id
    fns*: seq[Symbol]
    structs*: seq[Symbol]
    enums*: seq[Symbol]
    moduleScope*: Scope
    diags*: Diagnostics

  ResolveContext = ref object
    b: Bindings
    scope: Scope
    pending: seq[string]    ## declared in the current block, not reached yet

proc bindNode(b: Bindings, n: Node, sym: Symbol) =
  if n != nil and n.id >= 0 and n.id < b.nodeSym.len:
    b.nodeSym[n.id] = sym

proc symbolOf*(b: Bindings, n: Node): Symbol =
  ## The symbol an identifier or declaration node was bound to, or nil.
  if n != nil and n.id >= 0 and n.id < b.nodeSym.len:
    result = b.nodeSym[n.id]
  else:
    result = nil

proc reportDuplicate(c: ResolveContext, decl: Node, previous: Symbol) =
  var help = ""
  if previous != nil and previous.decl != nil:
    help = "the previous declaration is on line " &
           $previous.decl.span.start.line
  discard c.b.diags.reportError(edlResolveDuplicateDecl,
    "identifier '" & decl.name & "' is already declared", decl.span, help)

# ---- "declared later in this block" tracking -------------------------------

proc isPending(c: ResolveContext, name: string): bool =
  for pending in c.pending:
    if pending == name:
      return true
  result = false

proc removePending(c: ResolveContext, name: string) =
  var kept: seq[string] = @[]
  for pending in c.pending:
    if pending != name:
      kept.add(pending)
  c.pending = kept

# ---- expressions -----------------------------------------------------------

proc resolveExpr(c: ResolveContext, n: Node)

proc resolveIdent(c: ResolveContext, n: Node) =
  let sym = lookup(c.scope, n.name)
  if sym != nil:
    bindNode(c.b, n, sym)
  elif isPending(c, n.name):
    discard c.b.diags.reportError(edlResolveUsedBeforeDecl,
      "'" & n.name & "' is used before it is declared", n.span,
      "move its declaration above this line")
  else:
    discard c.b.diags.reportError(edlResolveUnknownIdent,
      "unknown identifier '" & n.name & "'", n.span, "")

proc resolveCall(c: ResolveContext, n: Node) =
  if n.children.len == 0:
    return
  let callee = n.children[0]
  resolveExpr(c, callee)
  if callee.kind == nkIdent:
    let sym = lookup(c.scope, callee.name)
    if sym != nil and sym.kind != skFn and sym.kind != skBuiltin:
      discard c.b.diags.reportError(edlResolveNotCallable,
        "'" & callee.name & "' is a " & symbolKindName(sym.kind) &
        ", not a function", callee.span, "")
  var i = 1
  while i < n.children.len:
    resolveExpr(c, n.children[i])
    inc i

proc resolveExpr(c: ResolveContext, n: Node) =
  if n == nil:
    return
  case n.kind
  of nkIdent:
    resolveIdent(c, n)
  of nkCall:
    resolveCall(c, n)
  of nkFieldAccess:
    # only the receiver is an identifier; the field name is not resolved here
    if n.children.len > 0:
      resolveExpr(c, n.children[0])
  of nkIndex, nkBinary, nkUnary:
    for child in n.children:
      resolveExpr(c, child)
  else:
    # literals and error nodes carry no names
    discard

# ---- statements ------------------------------------------------------------

proc resolveStmt(c: ResolveContext, n: Node)

proc resolveBlock(c: ResolveContext, body: Node) =
  if body == nil:
    return
  let outerScope = c.scope
  let outerPending = c.pending
  c.scope = newScope(outerScope)
  c.pending = @[]
  for s in body.children:
    if s.kind == nkLetDecl or s.kind == nkVarDecl:
      c.pending.add(s.name)
  for s in body.children:
    resolveStmt(c, s)
  c.scope = outerScope
  c.pending = outerPending

proc declareLocal(c: ResolveContext, decl: Node) =
  removePending(c, decl.name)
  let sym = newSymbol(skLocal, decl.name)
  sym.decl = decl
  if declare(c.scope, sym):
    bindNode(c.b, decl, sym)
  else:
    reportDuplicate(c, decl, lookupLocal(c.scope, decl.name))

proc resolveStmt(c: ResolveContext, n: Node) =
  if n == nil:
    return
  case n.kind
  of nkLetDecl, nkVarDecl:
    if n.children.len > 0:
      resolveExpr(c, n.children[0])
    declareLocal(c, n)
  of nkAssign, nkReturn, nkExprStmt:
    for child in n.children:
      resolveExpr(c, child)
  of nkIf:
    if n.children.len > 0:
      resolveExpr(c, n.children[0])
    resolveBlock(c, n.body)
    if n.elseBody != nil:
      if n.elseBody.kind == nkIf:
        resolveStmt(c, n.elseBody)
      else:
        resolveBlock(c, n.elseBody)
  of nkWhile:
    if n.children.len > 0:
      resolveExpr(c, n.children[0])
    resolveBlock(c, n.body)
  of nkFor:
    # the iterable is evaluated outside the loop variable's scope
    if n.children.len > 0:
      resolveExpr(c, n.children[0])
    let outerScope = c.scope
    let outerPending = c.pending
    c.scope = newScope(outerScope)
    c.pending = @[]
    let sym = newSymbol(skLocal, n.name)
    sym.decl = n
    if declare(c.scope, sym):
      bindNode(c.b, n, sym)
    else:
      reportDuplicate(c, n, lookupLocal(c.scope, n.name))
    resolveBlock(c, n.body)
    c.scope = outerScope
    c.pending = outerPending
  of nkBlock:
    resolveBlock(c, n)
  else:
    discard

# ---- top level -------------------------------------------------------------

proc registerBuiltins(scope: Scope) =
  ## `print` is temporary: it exists so that a program can produce output before
  ## the standard library does. It becomes a real library function later.
  let printSym = newSymbol(skBuiltin, "print")
  printSym.fnReturn = tid(tyVoid)
  discard declare(scope, printSym)

proc declareTopLevel(c: ResolveContext, decl: Node) =
  case decl.kind
  of nkFnDecl:
    let sym = newSymbol(skFn, decl.name)
    sym.decl = decl
    if declare(c.scope, sym):
      c.b.fns.add(sym)
      bindNode(c.b, decl, sym)
    else:
      reportDuplicate(c, decl, lookupLocal(c.scope, decl.name))
  of nkStructDecl, nkEnumDecl:
    let kind = if decl.kind == nkStructDecl: skStruct else: skEnum
    let sym = newSymbol(kind, decl.name)
    sym.decl = decl
    if not declare(c.scope, sym):
      reportDuplicate(c, decl, lookupLocal(c.scope, decl.name))
      return
    if kind == skStruct:
      c.b.structs.add(sym)
    else:
      c.b.enums.add(sym)
    bindNode(c.b, decl, sym)
    for memberNode in decl.children:
      let memberKind = if kind == skStruct: skField else: skEnumValue
      let member = newSymbol(memberKind, memberNode.name)
      member.decl = memberNode
      if declareMember(sym, member):
        bindNode(c.b, memberNode, member)
      else:
        discard c.b.diags.reportError(edlTypeDuplicateField,
          "'" & sym.name & "' already has a member named '" &
          memberNode.name & "'", memberNode.span, "")
  of nkImportDecl:
    discard c.b.diags.reportError(edlSemNotImplemented,
      "imports are not implemented yet", decl.span,
      "the module system is planned; see specs/modules.md")
  else:
    discard

proc resolveFunctionBodies(c: ResolveContext) =
  for fnSym in c.b.fns:
    let decl = fnSym.decl
    let outerScope = c.scope
    let outerPending = c.pending
    c.scope = newScope(outerScope)
    c.pending = @[]
    for paramNode in decl.children:
      let param = newSymbol(skParam, paramNode.name)
      param.decl = paramNode
      if declare(c.scope, param):
        bindNode(c.b, paramNode, param)
      else:
        reportDuplicate(c, paramNode, lookupLocal(c.scope, paramNode.name))
    resolveBlock(c, decl.body)
    c.scope = outerScope
    c.pending = outerPending

proc resolveModule*(module: Node, nodeCount: int, diags: Diagnostics): Bindings =
  ## Resolves a whole module. `nodeCount` comes from `parseModule` and sizes the
  ## binding table.
  result = Bindings(nodeSym: @[], fns: @[], structs: @[], enums: @[],
                    moduleScope: newScope(nil), diags: diags)
  var i = 0
  while i < nodeCount:
    result.nodeSym.add(nil)
    inc i
  let c = ResolveContext(b: result, scope: result.moduleScope, pending: @[])
  registerBuiltins(c.scope)
  for decl in module.children:
    declareTopLevel(c, decl)
  resolveFunctionBodies(c)

proc hasMain*(b: Bindings): Symbol =
  ## The entry point required to build an executable: a function named `main`
  ## that takes no parameters.
  for sym in b.fns:
    if sym.name == "main" and sym.decl != nil and sym.decl.children.len == 0:
      return sym
  result = nil
