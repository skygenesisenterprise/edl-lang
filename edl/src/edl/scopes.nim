## EDL symbols and scopes.
##
## Scopes are small and lookups are linear scans. That is deliberate: it keeps
## the whole mechanism expressible in EDL terms, and a source file never has
## enough declarations in one scope for the difference to matter.
##
## Bootstrap dialect: see specs/decisions/ADR-0001.

import ./ast
import ./types

type
  SymbolKind* = enum
    skError
    skBuiltin    ## a temporary compiler-provided function, such as `print`
    skFn
    skParam
    skLocal      ## a `let`/`var` binding, or a `for` loop variable
    skStruct
    skEnum
    skField      ## a struct field, or -- for enums -- an enum value
    skEnumValue

  Symbol* = ref object
    kind*: SymbolKind
    name*: string          ## declared name
    ownerName*: string     ## for enum values: the owning enum's name
    typeIndex*: int        ## unique id of a struct/enum declaration, -1 otherwise
    ty*: TypeId            ## value type (locals, params, fields, enum values)
    fnReturn*: TypeId      ## return type of a function
    paramTypes*: seq[TypeId]
    fields*: seq[Symbol]   ## struct fields, or enum values
    enumVal*: int64        ## resolved value of an enum value
    decl*: Node            ## declaration node, nil for builtins

  Scope* = ref object
    parent*: Scope
    symbols*: seq[Symbol]

proc newSymbol*(kind: SymbolKind, name: string): Symbol =
  result = Symbol(kind: kind, name: name, ownerName: "", typeIndex: -1,
                  ty: tid(tyUnknown), fnReturn: tid(tyVoid),
                  paramTypes: @[], fields: @[], enumVal: 0'i64, decl: nil)

proc declareMember*(sym: Symbol, member: Symbol): bool =
  ## Adds a field or an enum value to `sym`, rejecting a duplicate name.
  for existing in sym.fields:
    if existing.name == member.name:
      return false
  sym.fields.add(member)
  result = true

proc newScope*(parent: Scope): Scope =
  result = Scope(parent: parent, symbols: @[])

proc declare*(scope: Scope, sym: Symbol): bool =
  ## Declares `sym` in `scope`. Returns false, and declares nothing, when the
  ## name is already taken *in this scope* -- shadowing an outer binding is
  ## allowed, redeclaring in the same scope is an error.
  for existing in scope.symbols:
    if existing.name == sym.name:
      return false
  scope.symbols.add(sym)
  result = true

proc lookupLocal*(scope: Scope, name: string): Symbol =
  if scope == nil:
    return nil
  for sym in scope.symbols:
    if sym.name == name:
      return sym
  result = nil

proc lookup*(scope: Scope, name: string): Symbol =
  ## Walks the scope chain outwards.
  var current = scope
  while current != nil:
    let found = lookupLocal(current, name)
    if found != nil:
      return found
    current = current.parent
  result = nil

proc lookupType*(scope: Scope, name: string): Symbol =
  ## Finds a type declaration, ignoring values that happen to share its name.
  var current = scope
  while current != nil:
    for sym in current.symbols:
      if sym.name == name and (sym.kind == skStruct or sym.kind == skEnum):
        return sym
    current = current.parent
  result = nil

proc symbolKindName*(k: SymbolKind): string =
  case k
  of skError: "error"
  of skBuiltin: "builtin"
  of skFn: "function"
  of skParam: "parameter"
  of skLocal: "variable"
  of skStruct: "struct"
  of skEnum: "enum"
  of skField: "field"
  of skEnumValue: "enum value"
