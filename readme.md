# EDL

**EDL** is a statically typed, natively compiled programming language designed to be
simple to learn and fast to write: readable like TypeScript, productive like Python,
suitable for backend and systems work like Go, with first-class support for web
development, SQL/databases, and low-level memory, system and FFI access when you need it.

The language priority is:

> **Simplicity → Productivity → Safety → Performance → Low-level control**

EDL hides complexity when it is not needed, but never prevents the developer from
reaching the level of control a job requires.

> **Status: early bootstrap.** This repository is at the very beginning of the EDL
> project. The EDL compiler frontend is being written now, on top of a Nim-based
> bootstrap toolchain. See [Project status](#project-status) for exactly what works
> today and what does not.

## The language

```edl
fn greet(name: string) -> string {
    return "Hello " + name
}

fn main() {
    let name = "Liam"
    let message = greet(name)
    print(message)
}
```

```edl
// types are explicit when you want them, inferred when you don't
let age: i32 = 21
let active = true

struct User {
    id: u64
    name: string
    email: string
}

fn getUser(id: u64) -> User {
    ...
}

if user.active {
    print(user.name)
} else {
    print("Inactive")
}

for user in users {
    print(user.name)
}
```

EDL is deliberately predictable: one obvious way to express each operation. The
normative definition lives in [`specs/`](specs/) — syntax, types, memory model,
errors, modules, generics, concurrency, FFI, ABI, runtime and compiler architecture.

## Try it now

```sh
./build_all.sh          # once: builds the Nim bootstrap substrate into bin/
edl/scripts/build.sh    # builds the EDL compiler into build/edl/edlc

build/edl/edlc run test.edl
```

`build/edl/edlc run` is a **direct interpreter**: it lowers EDL to the typed IR
and executes it in-process. It does not generate Nim and does not invoke the
bootstrap compiler, so running a program needs no substrate. (`build` still
produces a native binary through the transitional bootstrap backend; `emit-nim`
shows that backend's output.)

`test.edl` at the repository root is a real program: functions, type inference,
a `while` loop, `if`/`else if`/`else`, string concatenation and every scalar
type. It prints:

```
Hello Liam
55
positive
3.14
E
edl works
```

Also useful:

```sh
build/edl/edlc check    test.edl           # type check only
build/edl/edlc emit-nim test.edl --print   # show the backend's output
build/edl/edlc emit-ast test.edl           # show the parsed tree
edl/scripts/test.sh                        # the whole test suite
```

## Coming from Nim

The Nim substrate is not going to be rewritten by hand, and it is not going to be
renamed. It is being **migrated**:

```sh
build/edl/edlc migrate edl/src/edl/source.edl    # bootstrap dialect -> EDL, with a report
```

`edl migrate` translates what EDL defines and **names** what it does not, pointing
at the spec that tracks each missing feature. Constructs with no equivalent are
commented out rather than invented, and a translation that would silently change
behaviour is reported instead of emitted.

Running it over the EDL compiler itself — 5 682 lines — currently reports about
1 200 constructs, roughly one line in five, and the ranked list of causes is the
implementation order for the language: collections and `Option<T>` account for
more than half. The full measurement, and what each missing feature would unblock,
is in [`specs/migration.md`](specs/migration.md); the decision behind it is
[ADR-0004](specs/decisions/ADR-0004-bootstrap-to-edl-migrator.md).

## Repository layout

| Path | What it is | Ownership |
|------|------------|-----------|
| `edl/` | The EDL toolchain: frontend, IR, backends, tests. | **EDL** — grows |
| `specs/` | The EDL language specification and architecture decisions. | **EDL** — grows |
| `compiler/` | The Nim compiler. Used as the *bootstrap substrate* that builds the EDL toolchain. | Nim — frozen, progressively replaced |
| `lib/` | The Nim standard library (the substrate runtime). | Nim — progressively replaced |
| `koch.nim`, `build_all.sh` | The Nim build system. | Nim — replaced by the `edl` toolchain |
| `tools/`, `testament/`, `lsp/`, `formatter/`, `analyzer/` | Nim tooling: build, tests, IDE, formatter, analyzer. | Nim — redefined as EDL tools |
| `tests/` | The Nim test suite. Kept as a **non-regression harness** for the migration. | Nim — drives EDL correctness |
| `doc/`, `changelogs/` | Nim documentation and history. | Nim — reference |

The relationship between the two is intentional and one-directional:

```
Nim implementation foundation          (bootstrap substrate, temporary)
            │
            ▼
     EDL compiler                       (what this project is building)
            │
            ▼
      EDL language                      (the target: one language, self-hosted)
```

It is explicitly **not**:

```
Nim
 └── Nim with renamed keywords
       └── EDL
```

Nim is a bootstrap technology, never the specification of EDL. No Nim semantic
(macros, templates, pragmas, memory model, naming conventions) is inherited by the
language by default; anything EDL adopts is a deliberate, documented decision in
`specs/`.

The arrow between the two is a command: `edl migrate` translates Nim to EDL and
reports every construct it cannot translate, so the distance between the substrate
and the language is a measured number rather than an assumption. See
[`specs/migration.md`](specs/migration.md).

Every remaining reference to the substrate — and the reason it stays — is
registered in [`specs/bootstrap-references.md`](specs/bootstrap-references.md).

## Project status

| Milestone | State |
|-----------|-------|
| Repository audit and architecture mapping | **done** — see [`specs/architecture.md`](specs/architecture.md) |
| Nim bootstrap toolchain (`bin/nim`) | **working** — built from `csources_v3` |
| Source tracking and diagnostics | **working** — `edl/src/edl/source.edl`, `diagnostics.edl` |
| Lexical analysis | **working** — `tokens.edl`, `lexer.edl` |
| AST and parser | **working** — `ast.edl`, `parser.edl` |
| Name resolution | **working** — `scopes.edl`, `resolve.edl` |
| Type system and type checking | **working** — `types.edl`, `typecheck.edl` |
| EDL IR and lowering | **working** — `ir.edl`, `lowering.edl` |
| Interpreter | **working** — `edl run` executes the IR directly, no external compiler (`interp.edl`) |
| Native backend | **working, transitional** — `edl build` lowers to Nim, then C, then a native binary |
| Programs that run | **working** — see [Try it now](#try-it-now) |
| Toolchain | **partial** — `check`, `build`, `run`, `emit-nim`, `emit-ast`, `migrate` work; `init`, `fmt`, `test`, `doc`, `add`, `remove` are declared but not implemented |
| Test suite | **working** — 330 checks, `edl/scripts/test.sh` |
| Nim → EDL migration | **working and measured** — `edl migrate`, see [`specs/migration.md`](specs/migration.md) |
| Standard library in EDL | planned — `print` is temporarily a compiler builtin |
| Generics, collections, modules, `Option`/`Result`, `unsafe`, concurrency | planned — specified in `specs/`, rejected with a roadmap-shaped diagnostic today |
| Web / SQL / networking capabilities | planned |
| Self-hosted EDL compiler | long-term goal, keeps the architecture honest |

The bootstrap backend is *temporary by design*: EDL sources are lowered to Nim so
that the existing compiler can produce native binaries while the EDL backend is
built. Replacing it with a direct native backend is a planned, isolated change
behind the backend interface.

## Building

You need a C compiler (`gcc`/`clang`), `make` and `git`.

**1. Build the bootstrap substrate** (the Nim compiler, into the gitignored `bin/`):

```sh
./build_all.sh
```

**2. Build the EDL compiler** (needs `bin/nim` from step 1):

```sh
edl/scripts/build.sh
```

**3. Run the EDL test suite:**

```sh
edl/scripts/test.sh
```

## Contributing

Contributions to the language, the specification and the toolchain are welcome.

Two rules matter more than any other in this repository:

1. **Nothing enters the language by accident.** A behaviour must be defined in
   `specs/` before other parts of the language are allowed to depend on it.
2. **Understand before you delete.** The Nim substrate is load-bearing until the
   corresponding EDL component exists and passes the tests it inherits. Replace,
   verify, then remove — never the other way round.

Code written in the Nim bootstrap dialect must follow
[ADR-0001](specs/decisions/ADR-0001-bootstrap-dialect.md) so it can be migrated to
EDL mechanically.

## License

The EDL compiler and toolchain are licensed under the MIT license.

This repository is derived from the [Nim](https://nim-lang.org) compiler and
standard library, which remain under their original MIT license,
Copyright © 2006-2026 Andreas Rumpf. That attribution is preserved in full — see
[copying.txt](copying.txt). Programs written in EDL may be released under any
compatible license, including commercial ones.
