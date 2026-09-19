# EDL types

The EDL type system is defined independently of any implementation language. This
document defines the universe of types, which of them exist today, and the rules
the checker enforces.

## Type universe

### Primitive types

| Type | Status | Notes |
|------|--------|-------|
| `bool` | implemented | |
| `i8` `i16` `i32` `i64` | implemented | `i32` is the default for integer literals that fit |
| `i128` | specified | reported as `EDL0404` |
| `u8` `u16` `u32` `u64` | implemented | `u64` is the default for literals above `high(i64)` |
| `u128` | specified | reported as `EDL0404` |
| `f32` `f64` | implemented | `f64` is the default for float literals |
| `char` | implemented | one character |
| `string` | implemented | |
| `bytes` | specified | reported as `EDL0404` |
| `isize` `usize` | implemented | architecture-sized, currently 64-bit |
| `void` | implemented | the absence of a value; not usable as a parameter or field type |

Two things stay deliberately unimplemented rather than half-done: `i128`/`u128`
(they need literal and arithmetic support that the bootstrap backend cannot yet
provide honestly) and `bytes` (it needs a memory model).

### Composed types

| Type | Status |
|------|--------|
| `struct` | implemented: declaration, fields, field access, use as parameter and return type |
| `enum` | implemented: declaration, explicit or implicit values, qualified access |
| `array` `slice` `tuple` `map` `set` | specified, not implemented |
| generics (`struct Box<T>`, `fn identity<T>`) | specified, not implemented — see [generics.md](generics.md) |
| function types | specified, not implemented: a function name cannot yet be used as a value |

**Struct values cannot be constructed yet.** A struct can be declared, passed to
and returned from a function, and its fields can be read; there is no literal
syntax to build one. That is the next milestone, not an oversight, and it is why
the struct tests only go as far as `fn get(u: U) -> u64 { return u.id }`.

## Typing rules

These are enforced by `edl/src/edl/typecheck.nim` and asserted by
`edl/tests/types/`.

### Literals

* An integer literal whose value fits in `i32` is an `i32`; otherwise `i64`;
  otherwise `u64`.
* A float literal is an `f64`. A string literal is a `string`, a char literal a
  `char`, `true`/`false` a `bool`.
* An integer literal is assignable to **any** integer type that can hold its
  value, and to any float type. This is the only conversion that happens
  implicitly.

### No implicit conversions

Nothing else converts. `i32` does not widen to `i64`; `f32` does not widen to
`f64`. Widening is not an error in most languages, which is exactly why EDL makes
it one: a conversion that is invisible at the call site is a conversion nobody
reviewed. Explicit conversion syntax is not defined yet, and will be.

### Operators

| Operator | Operands | Result |
|----------|----------|--------|
| `+` | `string`, `string` | `string` (concatenation) |
| `+` `-` `*` | numeric, same type | that type |
| `/` | numeric, same type | that type — **integer division when the type is an integer**, as in Go and Rust |
| `%` | integers, same type | that type — not defined for floats |
| `==` `!=` | same type | `bool` |
| `<` `<=` `>` `>=` | numeric same type, or `string`, or `char` | `bool` |
| unary `-` | numeric | that type |

A comparison requires identical operand types: comparing an `i32` with an `i64`
is `EDL0402`, not a silent promotion.

### Statements and bindings

* `let` bindings cannot be reassigned; reassigning one is `EDL0403` with a `help`
  line suggesting `var`.
* A `let`/`var` without an annotation takes the initialiser's type.
* A non-void function must return a value on every path, where "every path" is
  determined conservatively: a `return`, or an `if`/`else` where both branches
  return (`EDL0410`).
* A `bool` is required for `if` and `while` conditions; there is no truthiness
  (`EDL0406`).

### Enums

* Values are integers, implicit ones continue from the previous value.
* Values must be **strictly increasing** in declaration order (`EDL0413`). This is
  a bootstrap-phase constraint: the transitional backend maps EDL enums onto
  ordered enum types. It is expected to be lifted once EDL has a native backend.
* Access is qualified: `Status.Done`.

### Temporary builtin: `print`

`print(x)` accepts `string`, `char`, `bool` and any numeric type, and returns
`void`. It exists so that a program can produce output before the standard library
does, and it is the only compiler-provided function. It becomes a library
function, in EDL, once the standard library exists.

## Open questions

These are not decided yet, and are listed so they are decided deliberately rather
than by accident:

1. **Explicit conversion syntax.** `as`? `T(x)`? A method? Needed before the
   "no implicit conversions" rule becomes inconvenient rather than protective.
2. **`array`/`slice` design**, and whether `for` iterates over an `Iterator`
   protocol or is builtin. This blocks `for` and indexing.
3. **Struct construction syntax**, and whether it includes defaults.
4. **Function types and first-class functions**, which determine how callbacks and
   generic algorithms are expressed.
5. **Trait/constraint system for generics**, or structural constraints only.
