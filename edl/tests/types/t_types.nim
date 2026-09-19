## Type system and type checker tests.
##
## Three kinds of check:
##   * invariants of the type table itself (ids, identity, literal ranges);
##   * inferred types of expressions, asserted by name ("i32", "string", ...);
##   * diagnostics, asserted by code, for every rule the checker enforces.

import edl/source
import edl/lexer
import edl/parser
import edl/ast
import edl/diagnostics
import edl/types
import edl/scopes
import edl/resolve
import edl/typecheck

import ../framework

type
  SemRun = object
    module: Node
    table: TypeTable
    bindings: Bindings
    checked: TypeCheckResult
    diags: Diagnostics

proc analyze(src: string): SemRun =
  let file = newSourceFile("test.edl", src)
  var diags = newDiagnostics()
  let toks = tokenize(file, diags)
  let parsed = parseModule(file, toks, diags)
  let bindings = resolveModule(parsed.module, parsed.nodeCount, diags)
  let table = newTypeTable()
  let checked = typeCheck(parsed.module, parsed.nodeCount, bindings, table, diags)
  result.module = parsed.module
  result.table = table
  result.bindings = bindings
  result.checked = checked
  result.diags = diags

proc typeText(r: SemRun, n: Node): string =
  result = typeName(r.table, r.checked.nodeTypes[n.id])

proc initOf(r: SemRun, fnIndex, stmtIndex: int): Node =
  ## The initialiser expression of the stmtIndex-th statement of a function.
  result = r.module.children[fnIndex].body.children[stmtIndex].children[0]

proc declTypeText(r: SemRun, fnIndex, stmtIndex: int): string =
  ## The type of the *binding* introduced by a statement. This differs from the
  ## type of the initialiser expression: `let a: i64 = 1` has an i32 literal and
  ## an i64 binding.
  let declNode = r.module.children[fnIndex].body.children[stmtIndex]
  let sym = symbolOf(r.bindings, declNode)
  if sym == nil:
    return "<no symbol>"
  result = typeName(r.table, sym.ty)

proc run*() =
  beginSuite("types")

  # ---- invariants of the type table ----
  block:
    let t = newTypeTable()
    checkEqInt(tid(tyI32), ord(tyI32), "a builtin's id is its kind ordinal")
    checkEqInt(tid(tyString), ord(tyString), "ids are stable for every builtin")
    check(kindOf(t, tid(tyBool)) == tyBool, "kindOf returns the builtin kind")
    check(sameType(t, tid(tyI64), tid(tyI64)), "a type is identical to itself")
    check(not sameType(t, tid(tyI32), tid(tyI64)), "distinct builtins are distinct")
    checkEqStr(typeName(t, tid(tyU64)), "u64", "builtin type names")

  block:
    let t = newTypeTable()
    let a = addNamedType(t, "User", 0)
    let b = addNamedType(t, "Account", 1)
    check(sameType(t, a, a), "a named type is identical to itself")
    check(not sameType(t, a, b), "two named types are never the same")
    checkEqStr(typeName(t, a), "User", "named types keep their name")
    check(kindOf(t, a) == tyNamed, "named types have kind tyNamed")

  block:
    let bounds = intBounds(tyU8)
    check(bounds[0] == 0'i64 and bounds[1] == 255'i64, "u8 range")
    check(litFits(tyU8, 255'i64), "255 fits in u8")
    check(not litFits(tyU8, 256'i64), "256 does not fit in u8")
    check(not litFits(tyU8, -1'i64), "a negative value does not fit in u8")
    check(litFits(tyI8, -128'i64), "the i8 minimum fits")
    check(not litFits(tyI8, -129'i64), "one below the i8 minimum does not fit")

  block:
    check(defaultIntType(21'i64) == tyI32, "a small literal defaults to i32")
    check(defaultIntType(3000000000'i64) == tyI64,
          "a literal above i32 defaults to i64")
    check(builtinKindByName("string") == tyString, "builtin lookup by name")
    check(builtinKindByName("User") == tyError,
          "a non-builtin name is not a builtin type")
    check(isSpecifiedButUnimplemented(tyI128), "i128 is specified but not implemented")
    check(isSpecifiedButUnimplemented(tyBytes), "bytes is specified but not implemented")
    check(not isSpecifiedButUnimplemented(tyI64), "i64 is implemented")

  # ---- literals and inference ----
  block:
    let r = analyze("fn f() { let a = 1 let b = 1.5 let c = \"x\" let d = true let e = 'c' }")
    check(not r.diags.hasErrors(), "the program is well typed")
    checkEqStr(r.typeText(r.initOf(0, 0)), "i32", "an integer literal is i32")
    checkEqStr(r.typeText(r.initOf(0, 1)), "f64", "a float literal is f64")
    checkEqStr(r.typeText(r.initOf(0, 2)), "string", "a string literal is string")
    checkEqStr(r.typeText(r.initOf(0, 3)), "bool", "a bool literal is bool")
    checkEqStr(r.typeText(r.initOf(0, 4)), "char", "a char literal is char")

  block:
    let r = analyze("fn f() { let big = 3000000000 }")
    checkEqStr(r.typeText(r.initOf(0, 0)), "i64",
               "a literal too large for i32 becomes i64")

  block:
    let r = analyze("fn f() { let a: i64 = 1 }")
    checkEqStr(r.declTypeText(0, 0), "i64",
               "an int literal takes the annotated type")
    checkEqStr(r.typeText(r.initOf(0, 0)), "i32",
               "the literal expression itself keeps its natural type")

  block:
    let r = analyze("fn f() { let a = 1 \n let b: i64 = a }")
    check(r.diags.hasCode(edlTypeNotAssignable),
          "there is no implicit integer widening")

  block:
    let r = analyze("fn f() { let a: i8 = 300 }")
    check(r.diags.hasCode(edlTypeNotAssignable),
          "an out-of-range literal is rejected")

  # ---- functions ----
  block:
    let r = analyze("fn g() -> i32 { return 1 } fn f() { let x = g() }")
    check(not r.diags.hasErrors(), "a call to a well-typed function is fine")
    checkEqStr(r.typeText(r.initOf(1, 0)), "i32", "a call has the return type")

  block:
    let r = analyze("fn g(x: i32) { } fn f() { g(\"s\") }")
    check(r.diags.hasCode(edlTypeMismatch), "a wrong argument type is rejected")

  block:
    let r = analyze("fn g(x: i32) { } fn f() { g(1, 2) }")
    check(r.diags.hasCode(edlTypeArgCount), "a wrong argument count is rejected")

  block:
    let r = analyze("fn g() { } fn f() { g(1) }")
    check(r.diags.hasCode(edlTypeArgCount), "an argument to a 0-arity function is rejected")

  block:
    let r = analyze("fn g(x: u8) { } fn f() { g(200) }")
    check(not r.diags.hasErrors(), "an in-range literal is accepted for u8")

  block:
    let r = analyze("fn g(x: u8) { } fn f() { g(300) }")
    check(r.diags.hasCode(edlTypeMismatch), "an out-of-range argument is rejected")

  block:
    let r = analyze("fn f() -> i32 { return \"x\" }")
    check(r.diags.hasCode(edlTypeReturnMismatch), "a wrong return type is rejected")

  block:
    let r = analyze("fn f() -> i32 { }")
    check(r.diags.hasCode(edlTypeMissingReturn), "a missing return is rejected")

  block:
    let r = analyze("fn f() { return 1 }")
    check(r.diags.hasCode(edlTypeReturnMismatch),
          "returning a value from a void function is rejected")

  block:
    let r = analyze("fn f() -> i32 { if 1 < 2 { return 1 } else { return 2 } }")
    check(not r.diags.hasErrors(), "a function returning on every path is accepted")
    check(not r.diags.hasCode(edlTypeMissingReturn),
          "an if/else where both branches return is terminating")

  # ---- operators ----
  block:
    let r = analyze("fn f() { let s = \"a\" + \"b\" }")
    checkEqStr(r.typeText(r.initOf(0, 0)), "string", "string concatenation yields string")

  block:
    let r = analyze("fn f() { let x = 1 + 2 }")
    checkEqStr(r.typeText(r.initOf(0, 0)), "i32", "integer addition keeps the type")

  block:
    let r = analyze("fn f() { let x = 1 + \"a\" }")
    check(r.diags.hasCode(edlTypeUnsupportedOp), "adding an int and a string is rejected")

  block:
    let r = analyze("fn f() { let x = 1.5 % 2.0 }")
    check(r.diags.hasCode(edlTypeUnsupportedOp), "'%' on floats is rejected")

  block:
    let r = analyze("fn f() { let x = 1 == \"a\" }")
    check(r.diags.hasCode(edlTypeMismatch), "comparing different types is rejected")

  block:
    let r = analyze("fn f() { let x = 1 < 2 }")
    checkEqStr(r.typeText(r.initOf(0, 0)), "bool", "a comparison yields bool")

  block:
    let r = analyze("fn f() { let x = -3 }")
    checkEqStr(r.typeText(r.initOf(0, 0)), "i32", "unary minus keeps the numeric type")

  # ---- structs and enums ----
  block:
    let r = analyze("struct U { id: u64 name: string } fn f(u: U) -> u64 { return u.id }")
    check(not r.diags.hasErrors(), "field access on a struct is well typed")

  block:
    let r = analyze("struct U { id: u64 } fn f(u: U) -> string { return u.id }")
    check(r.diags.hasCode(edlTypeReturnMismatch),
          "a field's type is taken into account")

  block:
    let r = analyze("struct U { id: u64 } fn f(u: U) -> u64 { return u.nope }")
    check(r.diags.hasCode(edlTypeUnknownField), "an unknown field is rejected")

  block:
    let r = analyze("fn f() { let x = 1 let y = x.nope }")
    check(r.diags.hasCode(edlTypeUnknownField),
          "field access on a non-struct is rejected")

  block:
    let r = analyze("enum Color { Red, Green, Blue } fn f() -> Color { return Color.Green }")
    check(not r.diags.hasErrors(), "an enum value is well typed")
    checkEqStr(r.typeText(r.module.children[1].body.children[0].children[0]), "Color",
               "an enum value has the enum's type")

  block:
    let r = analyze("enum Color { Red } fn f() -> Color { return Color.Blue }")
    check(r.diags.hasCode(edlTypeUnknownField), "an unknown enum value is rejected")

  block:
    let r = analyze("enum Color { Red, Red }")
    check(r.diags.hasCode(edlTypeDuplicateField), "a duplicate enum value is rejected")

  block:
    let r = analyze("struct U { id: u64 id: string }")
    check(r.diags.hasCode(edlTypeDuplicateField), "a duplicate field is rejected")

  block:
    let r = analyze("enum Color { }")
    check(r.diags.hasCode(edlTypeEmptyEnum), "an empty enum is rejected")

  block:
    let r = analyze("enum Color { A = 5, B = 2 }")
    check(r.diags.hasCode(edlTypeEnumOrder),
          "enum values must be strictly increasing during the bootstrap phase")

  block:
    let r = analyze("struct U { id: u64 } fn f(u: U) -> u64 { return u.id }")
    checkEqStr(r.typeText(r.module.children[1].body.children[0].children[0]), "u64",
               "the type of a field access is the field's type")

  # ---- statements ----
  block:
    let r = analyze("fn f() { if 1 { } }")
    check(r.diags.hasCode(edlTypeCondNotBool), "a non-bool 'if' condition is rejected")

  block:
    let r = analyze("fn f() { while \"x\" { } }")
    check(r.diags.hasCode(edlTypeCondNotBool), "a non-bool 'while' condition is rejected")

  block:
    let r = analyze("fn f() { var x = 1 x = 2 }")
    check(not r.diags.hasErrors(), "a var can be reassigned")

  block:
    let r = analyze("fn f() { let x = 1 x = 2 }")
    check(r.diags.hasCode(edlTypeNotAssignable), "a let binding cannot be reassigned")

  block:
    let r = analyze("fn f() { var x: i32 = 1 x = \"s\" }")
    check(r.diags.hasCode(edlTypeNotAssignable), "an assignment type mismatch is rejected")

  block:
    let r = analyze("fn f() { print(\"ok\") }")
    check(not r.diags.hasErrors(), "print accepts a string")

  block:
    let r = analyze("fn f() { print(true) }")
    check(not r.diags.hasErrors(), "print accepts a bool")

  block:
    let r = analyze("fn f() { print() }")
    check(r.diags.hasCode(edlTypeArgCount), "print requires an argument")

  block:
    let r = analyze("fn f() { print(\"a\", \"b\") }")
    check(r.diags.hasCode(edlTypeArgCount), "print takes exactly one argument")

  # ---- error checking of names ----
  block:
    let r = analyze("fn f() { print(nope) }")
    check(r.diags.hasCode(edlResolveUnknownIdent), "an unknown identifier is rejected")

  block:
    let r = analyze("fn f() { print(x) let x = 1 }")
    check(r.diags.hasCode(edlResolveUsedBeforeDecl),
          "using a local before its declaration is reported precisely")

  block:
    let r = analyze("fn f() { } fn f() { }")
    check(r.diags.hasCode(edlResolveDuplicateDecl), "a duplicate declaration is rejected")

  block:
    let r = analyze("fn f() { let x = 1 x() }")
    check(r.diags.hasCode(edlResolveNotCallable), "calling a value is rejected")

  block:
    let r = analyze("fn f() { let x = nope }")
    check(r.diags.hasCode(edlResolveUnknownIdent),
          "an unknown identifier in an initialiser is rejected")

  # ---- types that do not exist yet ----
  block:
    let r = analyze("fn f(x: Nope) { }")
    check(r.diags.hasCode(edlTypeUnknownType), "an unknown type is rejected")

  block:
    let r = analyze("fn f(x: i128) { }")
    check(r.diags.hasCode(edlTypeNotImplemented),
          "a specified but unimplemented type is reported as such")

  # ---- specified but not implemented features ----
  block:
    let r = analyze("import net fn f() { }")
    check(r.diags.hasCode(edlSemNotImplemented), "imports are reported as not implemented")

  block:
    let r = analyze("fn f() { for x in y { } }")
    check(r.diags.hasCode(edlSemNotImplemented), "'for' is reported as not implemented")

  block:
    let r = analyze("fn f() { let x = nil }")
    check(r.diags.hasCode(edlSemNotImplemented), "'nil' is reported as not implemented")

  block:
    let r = analyze("fn f() { let x = a[0] }")
    check(r.diags.hasCode(edlSemNotImplemented), "indexing is reported as not implemented")
