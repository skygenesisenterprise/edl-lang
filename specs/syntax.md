# EDL syntax

This is the normative description of EDL's surface syntax as implemented by
`edl/src/edl/lexer.nim` and `edl/src/edl/parser.nim`. It is deliberately
TypeScript-inspired, and deliberately not a copy of TypeScript: EDL has one
obvious way to write each operation.

The design decision behind the syntax, and the migration consequences that follow
from it, are recorded in [ADR-0003](decisions/ADR-0003-edl-syntax-surface.md).

## Lexical structure

* **Whitespace** — spaces, tabs, carriage returns and newlines are all
  insignificant. There is no significant indentation: blocks are delimited by
  braces.
* **Comments** — `//` to end of line, and `/* ... */` which **nest**.
* **Identifiers** — ASCII letters, digits and `_`, not starting with a digit.
  The lexer is byte-oriented; full Unicode identifiers are a separate, later
  decision.
* **Integer literals** — decimal, `0x` hexadecimal, `0b` binary. `_` may be used
  as a digit separator and is not part of the value. Literals must fit in 64 bits.
* **Float literals** — `1.5`, `2e3`, `1.5e-3`. A leading digit is required:
  `.5` is not a literal.
* **Strings** — `"..."`, escapes `\n \r \t \0 \\ \" \'`. An unterminated string
  is reported at the end of the line, not the file.
* **Chars** — `'a'`, `'\n'`, exactly one character.
* **Case** — keywords are lowercase and reserved.

## Grammar

```
module      := { topDecl }

topDecl     := importDecl | fnDecl | structDecl | enumDecl

importDecl  := 'import' dottedPath
             | 'import' '{' name { ',' name } '}' 'from' dottedPath

fnDecl      := 'fn' name '(' [ params ] ')' [ '->' type ] block
params      := param { ',' param }
param       := name ':' type

structDecl  := 'struct' name '{' { fieldDecl } '}'
fieldDecl   := name ':' type

enumDecl    := 'enum' name '{' [ enumValue { ',' enumValue } [','] ] '}'
enumValue   := name [ '=' intLit ]

type        := dottedPath

block       := '{' { stmt } '}'
stmt        := letDecl | varDecl | returnStmt | ifStmt | whileStmt
             | forStmt | block | exprStmt

letDecl     := 'let' name [ ':' type ] '=' expr
varDecl     := 'var' name [ ':' type ] '=' expr
returnStmt  := 'return' [ expr ]
ifStmt      := 'if' expr block [ 'else' ( ifStmt | block ) ]
whileStmt   := 'while' expr block
forStmt     := 'for' name 'in' expr block
exprStmt    := expr [ '=' expr ]

expr        := precedence climbing over:
               unary   := '-' postfix
               postfix := primary { '(' args ')' | '.' name | '[' expr ']' | '?' }
               primary := intLit | floatLit | stringLit | charLit
                        | 'true' | 'false' | 'nil' | name | '(' expr ')'
```

Operator precedence, lowest to highest. All operators are left-associative:

| Level | Operators |
|-------|-----------|
| 1 | `==` `!=` |
| 2 | `<` `<=` `>` `>=` |
| 3 | `+` `-` |
| 4 | `*` `/` `%` |

`;` is accepted as a statement separator and is optional, since newlines already
separate statements.

## Examples

```edl
fn greet(name: string) -> string {
    return "Hello " + name
}

fn main() {
    let name = "Liam"
    print(greet(name))
}
```

```edl
let age: i32 = 21          // explicit
let active = true          // inferred

struct User {
    id: u64
    name: string
    email: string
}

enum Status {
    Pending,
    Running,
    Done,
}

if user.active {
    print(user.name)
} else {
    print("Inactive")
}

while count < 10 {
    count = count + 1
}

for user in users {        // parses; reported as not implemented yet
    print(user.name)
}
```

## Decisions worth stating explicitly

* **Enum values are separated by commas.** Newlines are insignificant, so nothing
  else would be unambiguous. A trailing comma is allowed.
* **Enum values are accessed qualified**: `Status.Done`, never a bare `Done`. A
  bare value would be ambiguous with a variable of the same name.
* **Parameters require a type.** There is no parameter inference; a signature is
  self-documenting.
* **The type annotation is optional on `let`/`var`**, and when present it wins
  over the initialiser's natural type: `let a: i64 = 1` is an `i64` binding whose
  initialiser expression is an `i32` literal.
* **`else if` is spelled that way**, not `elif`.
* **Parentheses are required** around every condition and every argument list.

## Reserved for later phases

These parse today and report `EDL0207` ("specified but not implemented"), so the
grammar does not have to change when they arrive:

| Construct | Specified in |
|-----------|--------------|
| `fn identity<T>(value: T) -> T` | [generics.md](generics.md) |
| `unsafe { ... }` | [memory.md](memory.md) |
| `load()?` | [errors.md](errors.md) |
| `import` | [modules.md](modules.md) |
| `for x in collection` | [types.md](types.md) |
| `a[i]` | [types.md](types.md) |
| `nil` | [memory.md](memory.md) |
