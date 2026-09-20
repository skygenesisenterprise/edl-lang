# The `edl/` tree

This directory holds the **EDL toolchain** — everything that belongs to the EDL
language rather than to the Nim bootstrap substrate.

It is the boundary described in [`../specs/architecture.md`](../specs/architecture.md):
code in here is EDL's own, owned by this project, and grows to eventually replace
the Nim components in `../compiler`, `../lib`, `../tools` and `../testament`.

## Layout

```
edl/
├── src/
│   ├── edl/                 the EDL compiler frontend
│   │   ├── source.edl       source files, positions, spans
│   │   ├── diagnostics.edl  diagnostics, codes, rendering (first-class feature)
│   │   ├── tokens.edl       token kinds and keyword table
│   │   ├── lexer.edl        lexical analysis
│   │   ├── ast.edl          the EDL abstract syntax tree
│   │   ├── parser.edl       recursive-descent parser
│   │   ├── types.edl        the EDL type system model
│   │   ├── scopes.edl       symbols and scopes
│   │   ├── resolve.edl      name resolution
│   │   ├── typecheck.edl    type checking
│   │   ├── ir.edl           the EDL intermediate representation
│   │   ├── lowering.edl     typed AST -> IR
│   │   ├── driver.edl       pipeline orchestration
│   │   ├── project.edl      the edl.toml project layer: manifests, discovery, scaffold
│   │   ├── backends/
│   │   │   ├── backend.edl      backend interface (the replacement seam)
│   │   │   └── bootstrapbackend.edl  bootstrap backend: EDL -> bootstrap -> C -> native
│   │   └── migrate/         the bootstrap -> EDL migrator
│   │       ├── bootstrap_lex.edl  tokeniser for the bootstrap dialect
│   │       └── translate.edl  translation, with the report
│   └── edlc.edl             the EDL compiler executable
├── examples/                small EDL programs
├── scripts/                 build.sh, test.sh
└── tests/
    ├── framework.edl        tiny assertion framework (no macros)
    ├── runner.edl           runs every category
    ├── lexer/ parser/ types/ packages/
    ├── migrate/             bootstrap -> EDL, including round trips
    └── compiler/            end-to-end: EDL source -> native binary, projects
```

Artifacts (generated Nim, object files, executables) never land in the tree: the
driver writes into `.edlout/`, which is hidden and therefore ignored by git.

## The bootstrap dialect

All Nim code in this tree must follow
[ADR-0001](../specs/decisions/ADR-0001-bootstrap-dialect.md): plain procs,
objects, enums, `seq`, `case` and `for` loops — **no macros, no templates, no
custom pragmas, no compile-time evaluation**. Each module imports only what it
needs and every declaration carries an explicit type.

The reason is not austerity: it is that this code is going to be **migrated to EDL**
by a mechanical source-to-source translation. Nim features with no EDL equivalent
cannot be translated, and would quietly anchor Nim semantics into the new language.
Staying inside the dialect keeps every file in this tree a candidate for automated
migration instead of a rewrite.

The dialect is enforced by tooling, not convention: `edl migrate <file.edl>`
understands exactly this subset and reports anything outside it instead of
misreading it. Run it on any file in this tree to see what that file is still
waiting for.

## Building

The EDL compiler is currently implemented in Nim and compiled by the bootstrap
substrate. Build the substrate first (once):

```sh
./build_all.sh          # produces the gitignored bin/nim
```

Then build and test the EDL toolchain:

```sh
edl/scripts/build.sh    # -> build/edl/edlc
edl/scripts/test.sh
```

## Using it

```sh
build/edl/edlc check     edl/examples/hello.edl
build/edl/edlc build     edl/examples/hello.edl -o hello
build/edl/edlc run       edl/examples/hello.edl
build/edl/edlc emit-nim  edl/examples/hello.edl     # inspect the bootstrap output
build/edl/edlc migrate   edl/src/edl/source.edl    # translate the bootstrap dialect to EDL, with a report
build/edl/edlc init my-project             # scaffold a project (edl.toml + src/main.edl)
build/edl/edlc run                         # project mode: the manifest's entry point
build/edl/edlc test                        # run the project's test programs
```

`edl migrate` is how this tree stops being Nim. It reads the bootstrap dialect and
writes EDL, and it reports every construct EDL has no equivalent for — so the
state of the migration is a number rather than an impression. See
[`../specs/migration.md`](../specs/migration.md), which also lists what each
missing feature would unblock.`edl fmt`, `edl doc`, `edl add` and `edl remove` are still part of the toolchain
contract and report themselves as not implemented yet rather than silently
doing nothing. The project layer — `edl.toml`, `edl init`, project mode and
`edl test` — is implemented; its design is in
[../specs/packages.md](../specs/packages.md).

## Why a Nim backend exists

`EDL source -> EDL IR -> Nim source -> C -> native` is a **transitional** path. It
lets the EDL language be tested end to end — real programs, real native binaries,
real output — long before the EDL backend is written.

It is isolated behind `backends/backend.edl`. Replacing it with a direct native
backend is a change to one backend implementation, not to the language, the
frontend, or the IR.
