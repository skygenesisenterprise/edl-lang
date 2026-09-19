# Contributing to EDL

Thank you for contributing to **EDL**, a statically typed, natively compiled
systems programming language. This document complements the
[contributing section of the README](README.md#contributing); please read it
first, especially the two rules that matter most:

1. **Nothing enters the language by accident.** A behaviour must be defined in
   [`specs/`](specs/) before other parts of the language are allowed to depend
   on it.
2. **Understand before you delete.** The Nim bootstrap substrate is load-bearing
   until the corresponding EDL component exists and passes the tests it
   inherits. Replace, verify, then remove — never the other way round.

## Where to start

- **The language specification** lives in [`specs/`](specs/) — syntax, types,
  memory model, errors, modules, generics, concurrency, FFI, ABI, runtime and
  compiler architecture. It is the source of truth.
- **The EDL compiler and toolchain** live in [`edl/`](edl/): frontend, IR,
  backends, interpreter, migrator, examples and tests.
- **The VS Code extension** lives in [`packages/vscode/`](packages/vscode/).
- **The website** lives in [`website/`](website/).
- **The GitHub Linguist contribution** lives in
  [`integrations/github/linguist/`](integrations/github/linguist/).

## Rules

- **Follow the bootstrap dialect** ([ADR-0001](specs/decisions/ADR-0001-bootstrap-dialect.md))
  when writing code that is compiled by the substrate: plain procs, objects,
  enums, `seq`, `case` and `for` loops — no macros, templates, custom pragmas or
  compile-time evaluation. Only the dialect can be migrated to EDL mechanically.
- **Every remaining reference to the substrate** must be justified. The register
  in [`specs/bootstrap-references.md`](specs/bootstrap-references.md) accounts
  for each one; a new reference needs a matching entry and a removal strategy.
- **Every change to the grammar** must match the normative syntax in
  [`specs/syntax.md`](specs/syntax.md) and come with a test.
- **Do not pretend features exist.** A command or language feature that is not
  implemented reports itself as "not implemented yet"; it does not silently do
  nothing and is not presented as working.
- **Do not rename the substrate.** The bootstrap is migrated, not renamed;
  global `Nim → EDL` replacements break the build and are never an acceptable
  change.

## Building and testing

```sh
./build_all.sh          # once: builds the Nim bootstrap substrate into bin/
edl/scripts/build.sh    # builds the EDL compiler into build/edl/edlc
edl/scripts/test.sh     # runs the EDL test suite (330 checks)
```

The substrate build is a temporary step that disappears when `edl build` can
compile the compiler itself. See [`README.md`](README.md#building).

## Submitting changes

- Target the `master` branch (the substrate's `devel` is not used for EDL
  development).
- Keep changes small, coherent and revertible; each phase must be verified
  before the next.
- Run the test suite and, when relevant, the VS Code (`packages/vscode`) and
  website (`website`) checks.
- Update the specification and this documentation when behaviour changes.

## Reporting bugs

See the issue templates in `.github/ISSUE_TEMPLATE/` and the
[security policy](SECURITY.md) for vulnerabilities.