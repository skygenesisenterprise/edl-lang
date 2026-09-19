# EDL — Migration from Nim

> **Status: implemented and measured.** `edl migrate` exists, is covered by tests
> (`edl/tests/migrate/`), and has been run over the whole EDL compiler source.

The migration from the Nim bootstrap substrate to EDL is a **command**, not a
manual rewrite and not a textual rename:

```sh
edl migrate <file.edl>              # writes <file>.edl next to it
edl migrate <file.edl> -o out.edl   # writes elsewhere
edl migrate <file.edl> --stdout     # prints the translation, writes nothing
```

Exit status is `0` when the whole file was translated, `1` when at least one
construct had no EDL equivalent (`2` for usage errors). A migration that needs a
human decision is therefore visible to a script.

## The rule

> The migrator translates what EDL defines, and **names** what it does not.

It never guesses. A `seq[T]` becomes a report, not a renamed type. A pragma is
dropped and logged, never silently obeyed. A construct with no equivalent is
commented out so the output still parses. Two invariants follow, and both are
tested:

1. **The output always parses.** Nothing the migrator emits can be a syntax error
   in EDL. Anything it cannot express is either commented out (`// ...`) or
   emitted in a form the EDL parser accepts, with a blocking report attached.
2. **Behaviour is never silently changed.** Where a faithful translation is not
   possible — `result` in the middle of a routine, a `for` loop containing
   `continue`, a `case` branch that is a range — the migrator leaves the code
   visible and reports it, rather than emitting something that compiles and
   means something else.

## Scope: the bootstrap dialect

The input is the **Nim bootstrap dialect** of [ADR-0001](decisions/ADR-0001-bootstrap-dialect.md),
which is the subset the EDL toolchain itself is written in. The migrator is not a
general-purpose Nim translator and does not try to be: unsupported input is
reported, never misread.

The input language is recognised by its own tokenizer (`edl/src/edl/migrate/bootstrap_lex.edl`),
not by the EDL lexer.

## What is translated

| Nim | EDL | Notes |
|-----|-----|-------|
| `int`, `uint`, `intN`, `uintN`, `float` | `isize`, `usize`, `iN`, `uN`, `f64` | architecture-sized types stay architecture-sized |
| `proc` / `func` | `fn` | headers split over several lines are handled |
| `let` / `var` | `let` / `var` | type annotations are mapped |
| `if` / `elif` / `else` | same, with braces | including branches that share a line (`if n < 0: 0 else: n`) |
| `while` | `while` | |
| `for i in a ..< b` | `{ var i = a while i < b { ... i = i + 1 } }` | the block keeps the loop variable scoped as Nim's does |
| `case` | `if` / `else if` chain | `of 1, 2:` becomes a disjunction |
| `case` as an `=` body | chain whose branches `return` | the case's value is the routine's result |
| enum values | `Type.Value` | Nim writes them unqualified; the migrator qualifies them |
| `object` | `struct` | `ref object` is reported (see `memory.md`) |
| `result = x` in tail position | `return x` | tail position is computed, not assumed |
| `echo` | `print` | EDL's `print` is still a compiler builtin |
| `inc` / `dec` | `x = x + 1` / `x = x - 1` | |
| `and`, `or`, `not` | same | |
| `div`, `mod` | `/`, `%` | |
| `a & b` | `a + b` | string concatenation |
| `0'i64` | `0` | the literal suffix is dropped; EDL takes the type from context |
| `{.pragma.}` | *(dropped)* | reported as a note: EDL has no pragmas |
| `name*` | `name` | the export marker is dropped: EDL has no visibility modifiers yet |
| `proc `+`(...)` | *(commented out)* | reported: EDL has no operator overloading |

## What is refused, and what would unblock it

Every entry below is **reported**, with the spec that tracks it. The list is the
migration roadmap, in the order its absence costs the most.

| Construct | Why | Tracked by |
|-----------|-----|------------|
| `seq[T]`, `array`, `Table`, `HashSet`, `set` | no collections yet | [types.md](types.md) |
| `len`, `add`, `ord`, `new`, `default`, `high`, `low` | no collection or string operations yet | [types.md](types.md) |
| `@[...]`, `@[]` | no sequence literal | [types.md](types.md) |
| `nil` | EDL has no null; `Option<T>` is specified but not implemented | [errors.md](errors.md) |
| `import` / `from` | the module system is specified, not implemented | [modules.md](modules.md) |
| `const` | no compile-time evaluation surface yet | [language.md](language.md) |
| `try` / `except` / `raise` / `defer` | errors are `Result`, not exceptions | [errors.md](errors.md) |
| generics (`Foo[T]`) | specified, not implemented | [generics.md](generics.md) |
| `ref` / `ptr` | the memory model is a separate, deliberate decision | [memory.md](memory.md) |
| tuples, `let (a, b) = ...` | not implemented | [types.md](types.md) |
| `$x` | stringification is not implemented | [types.md](types.md) |
| ranges outside a `for` | only `for` bounds are specified for now | [syntax.md](syntax.md) |
| `if` as an expression (`a & (if c: "" else: "s")`) | EDL has no if-expressions | [language.md](language.md) |
| top-level statements, module-level `let`/`var` | every EDL statement lives inside a function | [modules.md](modules.md) |
| `var` parameters, default parameter values | not part of the EDL parameter model | [memory.md](memory.md), ADR-0001 |
| type aliases, `distinct` | not implemented | [types.md](types.md) |
| operator definitions (`` proc `+` ``) | EDL has no operator overloading | [language.md](language.md) |
| `result` outside tail position | EDL has no `result` variable | [language.md](language.md) |
| `else`/`of` inside a single-line body, nested inline statements | one statement per line, by design | [syntax.md](syntax.md) |

Everything the migrator refuses is refused for one of exactly two reasons: the
feature is specified but not implemented yet, or the language has decided not to
have it. There is no third category.

## The measured gap

Running `edl migrate` over the EDL compiler itself — the honest measure of how far
the migration has come — gives the following. The compiler is written in the
bootstrap dialect precisely so that this run is possible at any point.

| File | Lines | Not translated | Notes |
|------|-------|----------------|-------|
| `edl/src/edl/ast.edl` | 210 | 43 | 21 |
| `edl/src/edl/diagnostics.edl` | 207 | 69 | 24 |
| `edl/src/edl/driver.edl` | 200 | 54 | 12 |
| `edl/src/edl/ir.edl` | 198 | 44 | 17 |
| `edl/src/edl/lexer.edl` | 341 | 55 | 79 |
| `edl/src/edl/lowering.edl` | 215 | 103 | 15 |
| `edl/src/edl/parser.edl` | 593 | 118 | 33 |
| `edl/src/edl/resolve.edl` | 283 | 64 | 13 |
| `edl/src/edl/scopes.edl` | 104 | 25 | 21 |
| `edl/src/edl/source.edl` | 115 | 30 | 15 |
| `edl/src/edl/tokens.edl` | 184 | 9 | 15 |
| `edl/src/edl/typecheck.edl` | 619 | 85 | 41 |
| `edl/src/edl/types.edl` | 220 | 30 | 65 |
| `edl/src/edl/backends/backend.edl` | 47 | 4 | 18 |
| `edl/src/edl/backends/bootstrapbackend.edl` | 311 | 91 | 50 |
| `edl/src/edl/migrate/bootstrap_lex.edl` | 241 | 49 | 24 |
| `edl/src/edl/migrate/translate.edl` | 1365 | 310 | 103 |
| `edl/src/edlc.edl` | 229 | 25 | 51 |
| **Total** | **5682** | **1200** | **598** |

Roughly **one in five lines** depends on a language feature EDL does not have
yet. Ranked by how many of those lines each missing feature accounts for:

| Missing feature | Occurrences | What implementing it unblocks |
|-----------------|-------------|-------------------------------|
| collection/string builtins (`len`, `add`, `ord`, …) | 437 | string handling and every `seq`-based pass |
| collections themselves (`seq[T]`, `Table`, `HashSet`) | 280 | the symbol tables, token buffers, and the AST's child lists |
| `nil` / `Option<T>` | 81 | every optional field and lookup result |
| `result` outside tail position | 100 | the common "assign early, return late" routine shape |
| `for` over a collection | 71 | iteration, which is currently only possible over integer ranges |
| `import` | 54 | splitting the compiler into modules at all |
| sequence literals | 53 | constructing those collections |
| `if` expressions | 46 | compact value selection |
| `$` | 21 | diagnostics and any textual output |
| tuple destructuring | 19 | the many `let (a, b) = ...` call sites |
| `ref object` | 17 | the AST, the symbol tables, the scope chain |
| `type` aliases | 12 | naming types like `TypeId` |
| `const` | 7 | named limits and tables |

The two entries at the top are the same feature seen twice: **EDL needs
collections and the operations over them** before anything else. The third,
`Option<T>`, is what removes `nil` — and it is already specified in
[errors.md](errors.md).

## Using the report

The report has two sections, and the distinction matters:

```
edl/src/edl/source.edl: 30 construct(s) not translated, 16 note(s)
not translated (the output does not compile until these are resolved)
  line 16: the type `seq[isize]` -- collections are not implemented yet (specs/types.md)
  ...
notes (translated, but check the result)
  line 33: an assignment to `result` -- rewritten as `return`, which is what it means in tail position
  ...
```

- **not translated** — the output does not compile until a human resolves it.
  Each entry names the construct, the source line, and the spec that tracks it.
- **notes** — the translation is faithful but lossy or worth reviewing: a dropped
  `*` marker, an `echo` rewritten as `print`, an enum value qualified.

Notes are not failures. They are the list of things a reviewer should confirm.

## What the migrator deliberately does not do

- **No renaming beyond the type map.** Identifiers are preserved exactly.
- **No reformatting.** It is not `edl fmt`; it does not own layout.
- **No guessing.** An unknown type name stays as written and is reported.
- **No stubs.** It never invents a function, a type, or a default value to make
  the output compile.
- **No deletion.** Constructs it cannot translate are commented out, never
  removed.

## Next steps

1. **Collections and `Option<T>`**, because they account for over half the gap.
2. **The module system**, without which the compiler cannot be split into files.
3. **A `result`-like construct** or a documented restructuring pattern, to close
   the 100 non-tail assignments.
4. **String operations** — `len`, `add`, concatenation indexing — which is what
   turns diagnostics and code generation into EDL.
5. Then re-run `edl migrate` on this file and watch the number fall. The number
   in the table above is the metric for the migration.
