# ADR-0001 — The Nim bootstrap dialect

* Status: accepted
* Date: 2026-09-19
* Supersedes: none

## Context

The EDL compiler is bootstrapped in Nim: EDL cannot compile itself before an EDL
compiler exists, and an EDL compiler cannot be written before a compiler exists.
Nim is therefore the temporary implementation language of the EDL toolchain.

That creates a specific hazard. The Nim code we write today will eventually have to
become EDL code. If it uses Nim freely, migrating it requires either a full rewrite
or — worse — copying Nim's metaprogramming semantics into EDL through the back door,
which is exactly what the project must not do.

Two facts constrain the solution:

* EDL will have no macros, no templates and no pragmas. That is a design decision,
  not an omission: EDL's priority is simplicity and predictability.
* The migration of `edl/` to EDL should be **mechanical**. A machine should be able
  to translate a file, not rediscover its meaning.

Nothing forces the bootstrap code to exploit Nim's full power. It is a compiler
frontend over plain data structures: the whole toolchain fits comfortably in a small
subset of the language.

## Decision

All Nim code under `edl/` is written in the **bootstrap dialect**: the intersection
of Nim and the EDL language that EDL is specified to have.

**Allowed**

* `proc`, `func`-like pure procs, `result`, explicit return types.
* `object`, `ref object`, `enum`, `tuple`, `seq`, `array`, `string`, `char`, `bool`.
* `int`, `int8`..`int64`, `uint8`..`uint64`, `float32`, `float64`.
* `if`/`elif`/`else`, `while`, `for` over `seq`/ranges, `case`, `block`, `break`,
  `continue`, early `return`.
* `import` and `from ... import ...`, with relative imports inside the package.
* `nil` for reference types, `let`/`var`, named fields.
* String interpolation and concatenation, comparisons, arithmetic.
* Simple generics without constraints (`proc f[T](x: T): T`).
* Default parameter values whose default is a literal (`help = ""`, `ahead = 0`).
  These map directly onto EDL optional parameters and keep call sites readable.
* `$` as the string-conversion operator, and `==` where structural equality is meant.
* `{.base.}`-free dispatch: an `enum` plus a `case` instead of methods.
* `{.raises: [].}` on procs that cannot raise — the only pragma permitted, because
  it documents a real invariant and EDL will have explicit error handling.
* Standard library modules that are themselves written in the dialect:
  `os` (paths only), `osproc` (for invoking the substrate), `parseutils`,
  `strutils` where needed.

**Forbidden**

* `macro`, `template`, custom pragmas (beyond `{.raises: [].}`).
* Compile-time evaluation: `static`, `const` computed by code execution, `ast`,
  `macros`, `quote do`, `compileTime`, `nimvm`.
* `when` beyond plain `when defined(windows)`-style platform selection.
* `distinct`, custom converters, `concept`, operator overloading other than `$`,
  `==` and `<`.
* User-defined iterators, `closure` types, closures capturing environment.
* `sink`, `lent`, `lent var`, `move`, destructors, custom `=destroy`/`=copy`.
* `Table`, `HashSet`, `OrderedTable` and other hashing containers. Use `seq` and
  linear search: the collections a lexer or parser needs are small, and this removes
  hashing semantics from the future translation entirely.
* `varargs`, overloading by anything other than parameter count and types,
  `method`.
* Inferred types on declarations: every parameter, field, `let`, `var` and return
  type is written out explicitly. Inference in the bootstrap code would make the
  migrator guess, and guessing is how semantics get lost.

## Consequences

**Positive**

* Every file in `edl/` is a candidate for mechanical migration to EDL.
* Nim semantics cannot leak into EDL through the implementation: the constructs that
  would carry such semantics are not available.
* The compiler stays readable to anyone who knows EDL, which matters for a project
  whose long-term goal is self-hosting.
* No hidden compile-time behaviour means what you read is what executes — a useful
  property for the tool that will later define EDL's own semantics.

**Negative**

* More verbose than idiomatic Nim.
* Some conveniences must be hand-written: the test framework (`edl/tests/framework.nim`)
  is plain procs and counters rather than `unittest`, and command-line parsing is
  written by hand rather than using a library.
* Hashing containers have to be avoided, which occasionally means a linear scan where
  a table would be nicer.

These costs are paid once, on maybe a few thousand lines, and they buy a migration
path for the entire toolchain. That trade is worth taking.

## Compliance

New modules in `edl/` are checked against this list when reviewed. A construct from
the forbidden list that turns out to be genuinely necessary must be justified by a
new ADR rather than introduced quietly.
