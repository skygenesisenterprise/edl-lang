# ADR-0003 — The EDL surface syntax

* Status: accepted
* Date: 2026-09-19
* Supersedes: none

## Context

Two viable syntaxes were considered for EDL, with very different consequences for
the migration of an existing Nim codebase of ~240 000 lines.

**Option A — TypeScript-like syntax.** Braces, `fn`, `->`, `let`, no significant
indentation. This is the syntax defined by the EDL mission:

```edl
fn greet(name: string) -> string {
    return "Hello " + name
}
```

**Option B — Nim-derived syntax.** `fn` with a `:` return annotation and
indentation-scoped blocks:

```edl
fn greet(name: string): string =
  return "Hello " & name
```

Option B would have made migrating existing Nim code close to lexical, allowing the
toolchain to self-host much earlier. Option A is a different language from Nim at the
character level, so nothing can be ported textually: every construct has to be
understood, and the EDL compiler has to be able to compile the result.

## Decision

**EDL uses the TypeScript-inspired syntax (Option A)**, as specified in the mission.
Readability for people coming from the mainstream is the point of the language, and a
syntax that is only convenient because it is Nim's would defeat it.

Recorded consequences of that choice, so they are not rediscovered later:

1. **The EDL parser is written from scratch.** It cannot be a fork of Nim's parser.
   `edl/src/edl/parser.nim` is an independent recursive-descent parser over its own
   AST. Nim's `parser.nim` is not reused and its AST is not shared.

2. **A Nim-to-EDL migrator is required, and it operates on structure, not text.**
   Translating `proc greet(name: string): string =` into
   `fn greet(name: string) -> string {` is a syntax-level transformation, but
   `discard`, `template`, `{.pragma.}` bodies, `varargs`, iterators and Nim's
   expression/statement duality are not. The migrator must parse Nim, transform a
   tree, and re-render EDL — producing an explicit report of constructs it could not
   translate rather than guessing.

3. **An EDL-to-Nim backend is required during the transition.** Because the EDL
   toolchain's own sources must remain compilable while they are being migrated, EDL
   lowers to Nim until the native backend exists:

   ```
   EDL source -> EDL IR -> Nim source -> C -> native
   ```

   This backend is transitional and isolated behind `edl/src/edl/backends/backend.nim`.

4. **The migration order is constrained by the bootstrapping dependency.** The Nim
   substrate cannot be the first thing migrated: it needs a mature EDL compiler,
   which needs the substrate. `edl/` is therefore migrated first (it is small, and
   written in the bootstrap dialect precisely so it can be), then the standard
   library, and the compiler last.

## Lexical decisions made concrete in this phase

* Comments: `//` to end of line, and `/* ... */` block comments which **nest**.
* Whitespace and newlines are insignificant; blocks are delimited by braces.
* Statement terminator: newline or `;`, both optional and interchangeable.
* Identifiers: ASCII letters, digits and `_`, not starting with a digit. The lexer is
  byte-oriented; full Unicode identifiers are a later, separate decision.
* Integer literals: decimal, `0x` hexadecimal, `0b` binary, `_` separators allowed.
  Float literals: `1.5`, `1e10`, `1.5e-3`. A leading digit is required (`.5` is not a
  literal).
* Strings: `"..."` with the escapes `\n \r \t \0 \\ \" \'`. Chars: `'c'`.
* Operators in this phase: `+ - * / %`, `== != < <= > >=`, `=`, and `->`.
* Reserved for the next phases: `?` (error propagation, see `errors.md`), generics
  with `<...>`, `unsafe { }`.

These are documented normatively in [`syntax.md`](../syntax.md).

## Consequences

**Positive**

* EDL has its own identity, legible to anyone who knows TypeScript, Go or Rust.
* The frontend is genuinely independent, so no Nim semantic can hide in it.
* Because the parser is new, error messages can be designed rather than inherited —
  a stated priority of the language.

**Negative**

* Considerably more work than a syntax-preserving fork: a new frontend, a migrator
  and a transitional backend, instead of a rename.
* Two syntaxes are live in the repository at once (Nim in the substrate, EDL in
  `edl/` and in user programs) until the substrate is gone. The boundary is kept
  explicit in `specs/architecture.md`.
