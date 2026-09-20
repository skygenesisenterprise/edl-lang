# Change Log

All notable changes to the **EDL** language, compiler and toolchain are
documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The VS Code extension has its own independent versioning; see
[`packages/vscode/CHANGELOG.md`](packages/vscode/CHANGELOG.md).

This changelog tracks the EDL project since it became an independent language
repository. The historical changes of the Nim bootstrap substrate it is derived
from are recorded in [`changelog.md`](changelog.md) and
[`changelogs/`](changelogs/) and are kept for attribution.

## [Unreleased]

### Added

- The project layer: an `edl.toml` manifest parsed with a strict TOML subset
  (`[project]`, `[dependencies]`, quoted strings, comments), with file and
  line on every error (`edl/src/edl/project.edl`).
- `edl init` scaffolds a project (`edl.toml` + `src/main.edl`) and refuses to
  overwrite an existing one.
- Project mode: `edl check`, `build`, `run`, `emit-nim` and `emit-ast` compile
  the entry point of the nearest `edl.toml` when no file argument is given.
- `edl test` runs the project's test programs (`.edl` files under `tests/`)
  with the direct interpreter and reports a pass/fail summary.
- The package-manager design — resolution, `edl.lock`, the global `~/.edl/`
  cache, no `node_modules` duplication — in [`specs/packages.md`](specs/packages.md),
  decided in [ADR-0005](specs/decisions/ADR-0005-package-manifest.md).
- Test categories: `packages/` (manifest unit tests) and end-to-end project
  tests in `compiler/`. The suite now runs 386 checks (was 330).

### Changed

- The repository now presents EDL as its official identity: renamed the root
  `readme.md` to `README.md` and updated every reference to it.
- Moved the GitHub Linguist language contribution to
  [`integrations/github/linguist/`](integrations/github/linguist/).

## [0.1.0] - 2026-09-19

First release of the EDL project as an independent language. EDL is a statically
typed, natively compiled systems programming language whose compiler is
developed on top of a temporary Nim bootstrap substrate.

### Added

- The EDL compiler frontend under `edl/src/edl/`: source handling, diagnostics
  with stable codes, tokenization, lexing, AST, parsing, scopes, name
  resolution, types and type checking.
- The EDL intermediate representation and lowering, plus a direct interpreter
  (`edl run`, no external compiler needed).
- A transitional bootstrap backend (`edl build`): EDL → Nim → C → native.
- `edl migrate`: a mechanical bootstrap-dialect → EDL translator with a measured
  report of what EDL does not define yet.
- The `edl` command-line interface: `check`, `build`, `run`, `emit-nim`,
  `emit-ast`, `migrate`, `version`, `help`.
- The language specification in `specs/`, with architecture decisions (ADRs).
- The official static website (`website/`).
- The official VS Code extension, **EDL — Official Language Support**
  (`packages/vscode`), released under the `vX.Y.Z-vscode` tag convention.
- GitHub Actions workflows for EDL releases, the website and the VS Code
  extension, plus the substrate build/test workflows required by the bootstrap.

### Notes

- The compiler is **not** self-hosted yet. It is written in a restricted Nim
  bootstrap dialect and compiled by the substrate until `edl build` can compile
  it. See [`specs/architecture.md`](specs/architecture.md) and
  [`specs/bootstrap-references.md`](specs/bootstrap-references.md).
- `for` loops, indexing, `import`, collections, `Option`/`Result`, generics,
  `unsafe`, concurrency and the standard library are specified but not
  implemented; the compiler reports them with a roadmap-shaped diagnostic.

[Unreleased]: https://github.com/skygenesisenterprise/edl-lang
[0.1.0]: https://github.com/skygenesisenterprise/edl-lang