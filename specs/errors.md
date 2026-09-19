# EDL errors and diagnostics

Error reporting is a feature of the language, not an afterthought. This document
is normative for two things: what a diagnostic contains, and what each code means.

## What a diagnostic contains

Every diagnostic EDL produces carries:

| Field | Purpose |
|-------|---------|
| severity | `error`, `warning` or `note` |
| code | a stable identifier, `EDL0101`; never reused, never renumbered |
| message | one sentence, stating what is wrong, not what to do about it |
| span | a precise source range: file, start line/column and end |
| help | optional, actionable: what to write instead |

Rendering includes the offending source line and a caret underline:

```
test.edl:3:17: error: cannot initialise 'x' of type i32 with a value of type string [EDL0403]
3 |     let x: i32 = "s"
  |                 ^^^
  help: EDL has no implicit conversions: make the declared type and the type of the value match
```

Guidelines the compiler follows:

* **The code is part of the contract.** Tests assert codes, not message text, so
  messages can improve without breaking the suite. Codes are grouped by stage so
  that `EDL04xx` immediately tells a reader "this is a type question".
* **One mistake, one message.** A node whose type is already a type error
  suppresses every diagnostic downstream of it. A cascade of twelve errors for
  one typo is a bug, not thoroughness.
* **Never stop early.** Every pass reports, marks, recovers and continues, so a
  single run reports every problem in the file.
* **Say what is not implemented, and where it is specified.** Generics, `unsafe`,
  `?`, `for`, indexing and `nil` are *parsed* and then reported as not implemented
  yet, pointing at the relevant specification. A user gets a roadmap, not
  "unexpected token".
* **Point at the fix.** Where a suggestion is mechanical (`let` vs `var`, a
  missing entry point, an out-of-range literal), `help` says what to write.

## Code registry

### `EDL01xx` — lexical

| Code | Meaning |
|------|---------|
| EDL0101 | unexpected character |
| EDL0102 | unterminated string literal |
| EDL0103 | unterminated block comment |
| EDL0104 | malformed number |
| EDL0105 | invalid escape sequence |
| EDL0106 | malformed character literal |

### `EDL02xx` — syntax

| Code | Meaning |
|------|---------|
| EDL0201 | unexpected token |
| EDL0202 | expected token |
| EDL0203 | expected expression |
| EDL0204 | expected type |
| EDL0205 | expected top-level declaration |
| EDL0206 | expected a name |
| EDL0207 | specified but not implemented, syntax still parsed |

### `EDL03xx` — names

| Code | Meaning |
|------|---------|
| EDL0301 | unknown identifier |
| EDL0302 | duplicate declaration in the same scope |
| EDL0303 | used before its declaration |
| EDL0304 | this name is not a function |
| EDL0305 | the program has no `main` (required to build an executable) |

### `EDL04xx` — types

| Code | Meaning |
|------|---------|
| EDL0401 | unknown type |
| EDL0402 | argument type mismatch |
| EDL0403 | not assignable (initialisation, assignment, `let` reassignment) |
| EDL0404 | type specified but not implemented |
| EDL0405 | wrong number of arguments |
| EDL0406 | a condition must be `bool` |
| EDL0407 | return type mismatch, or missing return value |
| EDL0408 | operator not applicable to these types |
| EDL0409 | unknown field or enum value |
| EDL0410 | a non-void function must return on every path |
| EDL0411 | duplicate struct field or enum value |
| EDL0412 | an enum must declare at least one value |
| EDL0413 | enum values must be strictly increasing (bootstrap backend limit) |

### `EDL05xx` — semantics

| Code | Meaning |
|------|---------|
| EDL0501 | specified but not implemented, semantics not yet defined |

### `EDL09xx` — toolchain

| Code | Meaning |
|------|---------|
| EDL0901 | input file cannot be read |
| EDL0902 | the bootstrap compiler was not found |
| EDL0903 | generated source cannot be written |
| EDL0904 | the backend failed to build the program |

## Status of error handling *in* the language

Explicit error handling is a language design goal:

```edl
fn loadUser(id: u64) -> Result<User, DatabaseError> {
    ...
}

let user = loadUser(42)?
```

`Result<T, E>`, `Option<T>` and the `?` propagation operator are **specified but
not implemented**. Today `?` parses and is reported as `EDL0207`. The design
constraint, decided now so that it is not retrofitted later:

* exceptions are not the universal mechanism of error control;
* fallibility is visible in a function's type;
* `?` propagates a failure without an implicit panic;
* no language construct may be introduced that makes an unchecked failure the
  path of least resistance.
