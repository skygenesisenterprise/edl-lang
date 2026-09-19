## Parser tests.
##
## Positive cases assert the shape of the tree node by node. Negative cases
## assert that a specific diagnostic code is produced *and* that parsing resumed:
## a parser that reports an error and then loses the rest of the file is as
## broken as one that reports nothing.

import edl/source
import edl/lexer
import edl/ast
import edl/parser
import edl/diagnostics

import ../framework

type
  ParseRun = object
    module: Node
    nodeCount: int
    diags: Diagnostics

proc parseSrc(src: string): ParseRun =
  let file = newSourceFile("test.edl", src)
  var diags = newDiagnostics()
  let toks = tokenize(file, diags)
  let r = parseModule(file, toks, diags)
  result.module = r.module
  result.nodeCount = r.nodeCount
  result.diags = r.diags

proc fnBody(r: ParseRun, index: int): Node =
  result = r.module.children[index].body

proc run*() =
  beginSuite("parser")

  # ---- the hello world program, node by node ----
  block:
    let r = parseSrc("fn main() { print(\"Hello World\") }")
    checkEqInt(r.module.children.len, 1, "one top-level declaration")
    let f = r.module.children[0]
    check(f.kind == nkFnDecl, "it is a function declaration")
    checkEqStr(f.name, "main", "named main")
    checkEqInt(f.children.len, 0, "no parameters")
    check(f.typeAnn == nil, "no return annotation means void")
    check(f.body != nil and f.body.kind == nkBlock, "has a block body")
    checkEqInt(f.body.children.len, 1, "one statement in the body")
    let stmt = f.body.children[0]
    check(stmt.kind == nkExprStmt, "the call is an expression statement")
    let call = stmt.children[0]
    check(call.kind == nkCall, "the expression is a call")
    checkEqInt(call.children.len, 2, "a call has a callee and one argument")
    checkEqStr(call.children[0].name, "print", "callee is print")
    checkEqStr(call.children[1].strVal, "Hello World", "argument is the string literal")
    check(not r.diags.hasErrors(), "a valid program produces no errors")

  # ---- functions: parameters and return type ----
  block:
    let r = parseSrc("fn greet(name: string) -> string { return \"Hello \" + name }")
    let f = r.module.children[0]
    checkEqInt(f.children.len, 1, "one parameter")
    checkEqStr(f.children[0].name, "name", "parameter name")
    checkEqStr(f.children[0].typeAnn.name, "string", "parameter type")
    checkEqStr(f.typeAnn.name, "string", "return type")
    let ret = f.body.children[0]
    check(ret.kind == nkReturn, "return statement")
    checkEqInt(ret.children.len, 1, "return carries a value")
    let concat = ret.children[0]
    check(concat.kind == nkBinary, "concatenation is a binary expression")
    checkEqStr(concat.name, "+", "operator is +")
    checkEqStr(concat.children[1].name, "name", "right operand is the parameter")

  block:
    let r = parseSrc("fn f(a: i32, b: i32, c: bool) -> bool { return c }")
    let f = r.module.children[0]
    checkEqInt(f.children.len, 3, "three parameters")
    checkEqStr(f.children[2].name, "c", "third parameter name")
    checkEqStr(f.children[2].typeAnn.name, "bool", "third parameter type")

  block:
    let r = parseSrc("fn f() { return }")
    let ret = fnBody(r, 0).children[0]
    check(ret.kind == nkReturn, "bare return is a return statement")
    checkEqInt(ret.children.len, 0, "bare return carries no value")

  # ---- structs and enums ----
  block:
    let r = parseSrc("struct User { id: u64 name: string email: string }")
    let s = r.module.children[0]
    check(s.kind == nkStructDecl, "struct declaration")
    checkEqStr(s.name, "User", "struct name")
    checkEqInt(s.children.len, 3, "three fields")
    checkEqStr(s.children[0].name, "id", "first field name")
    checkEqStr(s.children[0].typeAnn.name, "u64", "first field type")
    checkEqStr(s.children[2].name, "email", "last field name")

  block:
    let r = parseSrc("enum Color { Red, Green = 3, Blue, }")
    let e = r.module.children[0]
    check(e.kind == nkEnumDecl, "enum declaration")
    checkEqStr(e.name, "Color", "enum name")
    checkEqInt(e.children.len, 3, "three values")
    checkEqStr(e.children[0].name, "Red", "first value name")
    checkEqInt64(e.children[0].intVal, -1'i64, "no explicit value for Red")
    checkEqInt64(e.children[1].intVal, 3'i64, "explicit value for Green")
    checkEqStr(e.children[2].name, "Blue", "trailing comma is allowed")

  # ---- imports ----
  block:
    let r = parseSrc("import net")
    let imp = r.module.children[0]
    check(imp.kind == nkImportDecl, "import declaration")
    checkEqStr(imp.path, "net", "simple import path")
    checkEqInt(imp.children.len, 0, "no named imports")

  block:
    let r = parseSrc("import { User, Account } from app.models")
    let imp = r.module.children[0]
    checkEqStr(imp.path, "app.models", "dotted import path")
    checkEqInt(imp.children.len, 2, "two imported names")
    checkEqStr(imp.children[0].name, "User", "first imported name")
    checkEqStr(imp.children[1].name, "Account", "second imported name")

  # ---- let and var, with and without annotation ----
  block:
    let r = parseSrc("fn f() { let age: i32 = 21 let name = \"Liam\" }")
    let body = fnBody(r, 0)
    check(body.children[0].kind == nkLetDecl, "let declaration")
    checkEqStr(body.children[0].name, "age", "declared name")
    checkEqStr(body.children[0].typeAnn.name, "i32", "explicit type annotation")
    checkEqInt64(body.children[0].children[0].intVal, 21'i64, "initialiser value")
    check(body.children[1].typeAnn == nil, "no annotation: type is inferred later")
    checkEqStr(body.children[1].children[0].strVal, "Liam", "inferred initialiser")

  block:
    let r = parseSrc("fn f() { var total = 0 }")
    check(fnBody(r, 0).children[0].kind == nkVarDecl, "var declaration is distinct from let")

  # ---- control flow ----
  block:
    let r = parseSrc("fn f() { if a { } else if b { } else { } }")
    let s = fnBody(r, 0).children[0]
    check(s.kind == nkIf, "if statement")
    checkEqInt(s.children.len, 1, "if has one condition")
    check(s.elseBody != nil, "has an else branch")
    check(s.elseBody.kind == nkIf, "'else if' nests an if")
    check(s.elseBody.elseBody.kind == nkBlock, "the final else is a block")

  block:
    let r = parseSrc("fn f() { while x < 10 { } }")
    let w = fnBody(r, 0).children[0]
    check(w.kind == nkWhile, "while statement")
    check(w.children[0].kind == nkBinary, "while condition is an expression")
    checkEqStr(w.children[0].name, "<", "condition uses the '<' operator")
    check(w.body.kind == nkBlock, "while body is a block")

  block:
    let r = parseSrc("fn f() { for user in users { print(user.name) } }")
    let fo = fnBody(r, 0).children[0]
    check(fo.kind == nkFor, "for statement")
    checkEqStr(fo.name, "user", "loop variable")
    checkEqStr(fo.children[0].name, "users", "iterable expression")
    let call = fo.body.children[0].children[0]
    check(call.kind == nkCall, "call inside the loop body")
    let access = call.children[1]
    check(access.kind == nkFieldAccess, "argument is a field access")
    checkEqStr(access.name, "name", "field access names the field")
    checkEqStr(access.children[0].name, "user", "field access receiver")

  # ---- expressions ----
  block:
    let r = parseSrc("fn f() { let x = 1 + 2 * 3 }")
    let init = fnBody(r, 0).children[0].children[0]
    checkEqStr(init.name, "+", "'*' binds tighter than '+'")
    checkEqInt64(init.children[0].intVal, 1'i64, "left operand")
    checkEqStr(init.children[1].name, "*", "right operand is the multiplication")

  block:
    let r = parseSrc("fn f() { let x = -1 }")
    let init = fnBody(r, 0).children[0].children[0]
    check(init.kind == nkUnary, "unary minus")
    checkEqStr(init.name, "-", "unary operator text")
    checkEqInt64(init.children[0].intVal, 1'i64, "operand is the literal")

  block:
    let r = parseSrc("fn f() { print(greet(name)) }")
    let outer = fnBody(r, 0).children[0].children[0]
    check(outer.kind == nkCall, "outer call")
    check(outer.children[1].kind == nkCall, "the argument is itself a call")
    checkEqStr(outer.children[1].children[0].name, "greet", "inner callee")

  block:
    let r = parseSrc("fn f() { x = 1 }")
    let a = fnBody(r, 0).children[0]
    check(a.kind == nkAssign, "assignment statement")
    checkEqInt(a.children.len, 2, "assignment has a target and a value")
    checkEqStr(a.children[0].name, "x", "assignment target")

  block:
    let r = parseSrc("fn f() { let t = true let u = false let n = nil }")
    let body = fnBody(r, 0)
    check(body.children[0].children[0].kind == nkBoolLit, "true is a bool literal")
    check(body.children[0].children[0].boolVal, "true carries its value")
    check(not body.children[1].children[0].boolVal, "false carries its value")
    check(body.children[2].children[0].kind == nkNilLit, "nil is its own literal")

  # ---- node identity, used by the semantic side tables ----
  block:
    let r = parseSrc("fn main() { print(\"hi\") }")
    checkEqInt(r.module.id, 0, "the module is node 0")
    check(r.nodeCount > 5, "dense ids were assigned to every node")

  # ---- several declarations, and structure dump ----
  block:
    let r = parseSrc("fn a() { } struct S { } fn b() { }")
    checkEqInt(r.module.children.len, 3, "three top-level declarations")
    check(r.module.children[1].kind == nkStructDecl, "the struct is second")

  block:
    let dump = dumpTree(parseSrc("fn main() { print(\"hi\") }").module)
    checkContains(dump, "fn main", "structure dump names the function")
    checkContains(dump, "call", "structure dump shows the call")
    checkContains(dump, "string \"hi\"", "structure dump shows the literal")

  # ---- negative cases: reported, then recovered from ----
  block:
    let r = parseSrc("fn a() { let x = } fn b() { }")
    check(r.diags.hasCode(edlParseExpectedExpression), "missing initialiser is reported")
    checkEqInt(r.module.children.len, 2, "parsing resumed after the error")

  block:
    let r = parseSrc("fn f(a: i32 { }")
    check(r.diags.hasCode(edlParseExpectedToken), "missing ')' is reported")

  block:
    let r = parseSrc("let x = 1")
    check(r.diags.hasCode(edlParseExpectedTopLevel), "a statement at top level is reported")

  block:
    let r = parseSrc("fn f() -> { }")
    check(r.diags.hasCode(edlParseExpectedType), "a missing return type is reported")

  block:
    let r = parseSrc("fn f() { }")
    checkEqStr(r.module.children[0].name, "f", "an empty body is valid")

  block:
    let r = parseSrc("struct S { 42 }")
    check(r.diags.hasCode(edlParseExpectedName), "a non-name in a struct body is reported")

  block:
    let r = parseSrc("import { A, B app.models")
    check(r.diags.hasCode(edlParseExpectedToken),
          "a missing '}' in an import list is reported")

  # ---- specified but not implemented yet: reported, grammar still parsed ----
  block:
    let r = parseSrc("fn identity<T>(value: T) -> T { return value }")
    check(r.diags.hasCode(edlParseNotImplemented), "generics are reported as not implemented yet")
    checkEqInt(r.module.children.len, 1, "the declaration still parses")
    checkEqStr(r.module.children[0].name, "identity", "the function name survives")
    checkEqInt(r.module.children[0].children.len, 1, "its parameter survives")

  block:
    let r = parseSrc("fn f() { unsafe { } }")
    check(r.diags.hasCode(edlParseNotImplemented), "'unsafe' is reported as not implemented yet")

  block:
    let r = parseSrc("fn f() { let x = load()? }")
    check(r.diags.hasCode(edlParseNotImplemented), "'?' is reported as not implemented yet")

  # ---- robustness: garbage must not hang or crash ----
  block:
    let r = parseSrc("}}}} @@@ fn")
    check(r.diags.hasErrors(), "garbage produces errors")
    check(r.module != nil, "a module node is still returned")
    check(r.nodeCount > 0, "ids are still assigned")
