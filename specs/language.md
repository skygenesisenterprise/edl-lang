# EDL — The language

> **Status: partially implemented.** This file defines what EDL *is*. Where a
> feature is not implemented yet, that is stated here rather than discovered by a
> user. A construct is only allowed into the language once it is written down on
> this page or in a spec it points to.

## What EDL is

EDL is a statically typed, natively compiled programming language. It aims to be
readable like TypeScript, productive like Python, and suitable for the kind of
work Go is used for — with direct access to the machine when the job requires it.

The design priority, in order, is normative. When two goals conflict, the earlier
one wins:

> **Simplicity → Productivity → Safety → Performance → Low-level control**

EDL hides complexity when it is not needed, but never prevents the developer from
reaching the level of control a job requires. That sentence is the tie-breaker for
every design question in this directory.

## The rules

1. **One obvious way.** If two syntaxes express the same operation, one of them is
   wrong. See [syntax.md](syntax.md).
2. **Nothing enters the language by accident.** A behaviour is specified before
   another part of the language is allowed to depend on it.
3. **Static by default.** Types are checked before the program runs. There are no
   implicit numeric conversions; see [types.md](types.md).
4. **Errors are values.** `Result<T, E>` and `Option<T>`, not exceptions; see
   [errors.md](errors.md).
5. **Explicit about the machine.** Memory, FFI and unsafe operations are marked as
   such in the source; see [memory.md](memory.md).
6. **The compiler explains itself.** Diagnostics are a language feature: every
   error carries a code and names the spec that defines the rule it is enforcing;
   see [errors.md](errors.md).

## Shape of a program

```edl
fn greet(name: string) -> string {
    return "Hello " + name
}

fn main() {
    let name = "Liam"
    print(greet(name))
}
```

A program is a sequence of declarations. `main` is the entry point. Every
statement lives inside a function: EDL has no module-level statements, and module
initialisation is deliberately not part of the language yet (see
[modules.md](modules.md) for what a module is).

The pipeline that turns that source into a running program is defined in
[compiler.md](compiler.md).

## Deliberately not in the language

These are decisions, not gaps. Each is recorded so that "EDL doesn't have X" has
an answer better than "not yet":

| Not in EDL | Because |
|------------|---------|
| Macros, templates, compile-time code execution | they make a language unpredictable to read; a library should not be able to rewrite its callers |
| Pragmas, attributes, annotations | same reason: behaviour should be visible in the code that has it |
| Exceptions, `try`/`catch`, `raise` | errors are values; see [errors.md](errors.md) |
| `null`, `nil`, nullable references | the absence of a value is `Option<T>`; see [errors.md](errors.md) |
| Implicit numeric conversions | narrowing surprises are a safety bug; see [types.md](types.md) |
| Operator overloading | `+` means one thing; see [syntax.md](syntax.md) |
| A `result` variable, implicit function results | a routine says `return`, so control flow is visible |
| Module-level mutable statements | initialisation order is a class of bug, not a feature |
| Multiple inheritance, mixins, aspect weaving | composition is structural |
| Undefined behaviour in safe code | `unsafe` is where the contract changes; see [memory.md](memory.md) |
| Garbage collection as a language guarantee | the memory model is specified separately and does not promise a specific collector; see [memory.md](memory.md) |

Note what this table is *not*: it is not a list of things EDL lacks. Most of them
are features of other languages that EDL is choosing not to have, and the
migration report in [migration.md](migration.md) exists precisely so that the cost
of each choice is measured rather than assumed.

## What is specified but not implemented

The following are defined in this directory, and the compiler currently rejects
them with a diagnostic that names the spec:

`Seq` and other collections ([types.md](types.md)) · `Option`/`Result` and `?`
([errors.md](errors.md)) · generics ([generics.md](generics.md)) · `import`
([modules.md](modules.md)) · `unsafe` and the memory operators
([memory.md](memory.md)) · concurrency · FFI.

A user who writes one of these gets a program that will not compile *and* a
message that says when it will. A user who writes something EDL has decided not to
have gets a message saying so.
