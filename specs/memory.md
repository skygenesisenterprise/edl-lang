# EDL memory model

**Status: not defined yet, deliberately, and not inherited from Nim.**

This document records what has to be decided, what the current pragmatic position
is, and what EDL will *not* do by default. The mission is explicit that the memory
model is a critical point and that Nim's must not be inherited blindly.

## Current pragmatic position

The EDL toolchain's own code is compiled by the Nim substrate, so today:

* EDL programs are compiled to Nim and inherit whatever the substrate's runtime
  does for allocation and deallocation;
* `string` and struct values are managed by the substrate's memory management.

That is a **temporary implementation detail**, not EDL's specification, and it is
confined to `backends/nimbackend.nim`. No EDL source-level construct currently
promises anything about allocation, ownership or lifetime, which is what makes it
safe to choose the model later.

## What must be decided before `specs/memory.md` becomes normative

The following dimensions are exactly the ones the mission requires to be documented
explicitly. None of them is decided yet:

| Dimension | Question |
|-----------|----------|
| Allocation | Is there a default allocator? Is it per module, per thread, per program? Is `new` explicit? |
| Deallocation | Automatic, manual, or both? |
| Ownership | Is there an ownership rule, or is aliasing unrestricted? |
| Lifetime | How is the lifetime of a value expressed, and who guarantees it? |
| References | What is a reference, syntactically and semantically? |
| Pointers | Do raw pointers exist at the language level, or only behind `unsafe`? |
| Values | When is a value copied implicitly? |
| Move | Is a move observable in the language, or an optimization? |
| Mutability | Is `let`/`var` the whole story, or is there immutability of *referents* too? |
| Thread safety | What does the language guarantee about sharing across threads? |
| FFI | What do C and other ABI's see, and what may cross the boundary? |
| `unsafe` | What exactly does `unsafe { ... }` permit, and how is it audited? |

## Constraints that are already decided

These come from the language's stated priorities (simplicity, then productivity,
then safety, then performance, then low-level control) and are binding on whatever
model is chosen:

1. **The common case must not mention memory.** A program that allocates nothing
   explicitly must be the normal EDL program.
2. **Nothing unsafe is implicit.** A construct with no safety guarantee must be
   marked, and readable at a glance.
3. **`unsafe { ... }` is the escape hatch, and it is a block**, so its extent is
   visible in the source. It is specified already and parses today, reporting
   `EDL0207`.
4. **`nil` is not a default.** Nullability must be explicit; `Option<T>` is the
   intended mechanism ([errors.md](errors.md)). `nil` parses and is reported as not
   implemented precisely so that the language does not accidentally acquire
   nullable-by-default references.
5. **No GC semantics leak into the language's surface.** Whether the implementation
   uses reference counting, tracing, regions or nothing is an *implementation*
   choice; the language specifies observable behaviour, not the mechanism.
6. **FFI boundaries are explicit about ownership.** What the other side owns, and
   what it may do with it, must be statable.

## Why this is not being rushed

Ownership and lifetime rules are the hardest part of a language to change later:
they are visible in every generic signature, every standard library API, and every
FFI declaration. Choosing them before the type system, the standard library and
the module system are settled would force a redesign of all three.

The order is recorded in [architecture.md](architecture.md): types, then modules,
then runtime, then the native backend, with the memory model specified as part of
the runtime phase.
