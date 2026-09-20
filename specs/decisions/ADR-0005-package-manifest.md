# ADR-0005 — The project manifest and the package layer

* Status: accepted
* Date: 2026-09-20
* Supersedes: none

## Context

The toolchain contract declared `edl init`, `edl add` and `edl remove` before
any of them existed. That was honest — the commands reported themselves as not
implemented — but it left the compiler without a project model: every
invocation named a single source file, and there was no place for a program's
identity, entry point or future dependencies.

The architecture directive stages this work: a manifest and lockfile
(`edl.toml` / `edl.lock`) come before a registry, and the package manager is a
subsystem behind the single `edlc` entry point. Four constraints shape the
decision:

* **Projects before dependencies.** A manifest is useful the day it exists
  (identity, entry point, `edl test`); a resolver is only useful when packages
  can be resolved. The two must not be coupled.
* **No `node_modules`.** Per-project dependency trees duplicate everything and
  are rejected up front; the target is a global, content-addressed cache.
* **The bootstrap dialect.** The implementation lives in `edl/`, under
  [ADR-0001](ADR-0001-bootstrap-dialect.md): no third-party TOML library, no
  hashing containers, no metaprogramming. Whatever parses the manifest must be
  small, plain and migratable to EDL mechanically.
* **Honesty.** Commands that are not real must say so and exit 2; nothing may
  pretend to install or resolve.

## Decision

1. **The manifest is `edl.toml`**, TOML, with `[project]` and `[dependencies]`
   tables. It is the developer's intent. `edl.lock`, when resolution exists,
   will be the recorded resolution — two files, two roles, never merged.
2. **The parser implements a strict subset of TOML**, written in the dialect
   (`edl/src/edl/project.edl`), not a general TOML library. The subset — two
   tables, quoted strings, comments — is valid TOML, so manifests stay
   portable if the parser grows. Strictness is deliberate: unknown keys and
   sections are errors with file and line, because a typo in a manifest must
   never be silently ignored.
3. **The entry point is `entry`, default `src/main.edl`.** Every compile
   command (`check`, `build`, `run`, `emit-nim`, `emit-ast`) works in project
   mode: no file argument means the entry point of the nearest `edl.toml`,
   found by walking up from the current directory.
4. **`edl init` scaffolds and never overwrites** an existing manifest or entry
   point, and the scaffolded project runs unmodified (`edl run`).
5. **`edl test` runs ordinary EDL programs** found under `tests/` with the
   direct interpreter; exit code 0 is a pass. No assertions API, no artifacts,
   no bootstrap involvement, until the language has the features a richer
   contract would need.
6. **Resolution, `edl.lock`, the registry and the global cache are deferred**,
   specified in [../packages.md](../packages.md) but not built: there is
   nothing to resolve against yet, and a resolver without packages would be
   decoration. The manifest model already keeps intent and resolution apart so
   the resolver lands as an addition, not a rework.

## Consequences

**Positive**

* Projects work today, with no infrastructure and no network: `edl init`,
  `edl run`, `edl test` are real.
* The toolchain contract shrank from six unimplemented commands to four
  (`fmt`, `doc`, `add`, `remove`).
* The manifest layer is one small, dialect-clean module that migrates to EDL
  mechanically with the rest of the toolchain.
* Strictness surfaces typos at the first `edl` invocation instead of at
  build time.

**Negative**

* A hand-written parser must grow alongside the format (arrays, integers,
  inline tables) as the resolver lands. Kept additive by the subset design.
* Until a registry exists, `edl.toml` records dependencies that nothing can
  fetch; the `[dependencies]` table is accepted and stored, and that is all it
  honestly does today.

## Alternatives considered

* **JSON manifest.** No comments and no trailing commas make it a poor fit for
  a file humans maintain as intent; TOML reads better and edits better.
* **Reusing the substrate's `.nimble` format.** Wrong concepts (backend,
  tasks, bootstrap-specific fields) and it would anchor the substrate's naming
  into the public layer — exactly what the identity migration removed.
* **Building resolution now.** Without a source of packages, version
  resolution resolves against nothing. Deferred explicitly rather than faked.
