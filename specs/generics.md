# EDL generics

**Status: specified, not implemented.** `fn identity<T>(value: T) -> T` and
`struct Box<T>` parse; the generic parameter list is then reported as `EDL0207`
and the rest of the declaration still parses normally.

## Target syntax

```edl
struct Box<T> {
    value: T
}
```

```edl
fn identity<T>(value: T) -> T {
    return value
}
```

## What EDL will not do

The single most important decision here is negative: **EDL will not reproduce
Nim's generic system.** Nim's generics are inseparable from its compile-time
metaprogramming — `when`, `static`, `concept`, `mixin`, `bind`, macro-generated
instantiations, and code that is only type-correct after substitution. Copying
them would import:

* a compile-time evaluation model EDL does not want;
* error messages that describe the *instantiation site* rather than what the user
  wrote;
* a specification that cannot be documented in a page.

EDL generics are meant to be one feature, not a family of features.

## Design constraints

1. **Documentable in a page.** If a generic feature needs more than that to
   explain, it does not belong in EDL.
2. **Errors at the declaration, when possible.** A generic function should be
   checkable on its own, at its declaration, not only when instantiated. This is
   what the constraint system is for.
3. **No metaprogramming.** No generic programming technique may require executing
   code at compile time. EDL has no macro system and will not grow one by accident
   through generics.
4. **Predictable code generation.** Any instantiation strategy must be describable
   in one paragraph, because it determines binary size and compile time.

## Open questions

1. **Instantiation strategy:** monomorphization (specialise per concrete type, so
   no runtime cost but code growth) or a uniform representation (one
   implementation, indirect calls, smaller code)? Monomorphization is the likely
   choice for a language that targets systems work, but it must be decided before
   the type checker is extended, because it constrains what constraints are
   expressible.
2. **Constraints:** none at all (duck-typed at instantiation, like early C++), or
   a trait/interface mechanism? The mission's priority list puts simplicity first,
   which argues against a full trait system; it also puts safety before
   performance, which argues against unbounded duck typing.
3. **Whether `Box<T>` is enough** — associated types, defaults, variadic type
   parameters — or whether the answer is "no, deliberately".
4. **Interaction with `Result<T, E>` and `Option<T>`**, which are the first
   intended users of generics and are specified in [errors.md](errors.md).

## Why not just do it now

Generics sit on top of a settled type system, a decided memory model and a
decided module system. Implementing them first would mean implementing them twice.
The order of [architecture.md](architecture.md) is deliberate.
