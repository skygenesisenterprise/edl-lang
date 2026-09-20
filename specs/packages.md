# Projects and packages

EDL has one entry point for the whole ecosystem: `edlc`. A project is a
directory with an `edl.toml` manifest, and the package manager grows out of
that manifest: projects first, dependencies second, registry last.

This document separates what is **implemented** from what is only **designed**.
Commands that do not exist say so and exit 2; nothing pretends.

## Status

| Piece | State |
|-------|-------|
| `edl.toml` manifest format | **implemented** — strict TOML subset, `edl/src/edl/project.edl` |
| Project mode: `check`, `build`, `run`, `emit-nim`, `emit-ast` without a file argument | **implemented** |
| `edl init` | **implemented** — manifest + `src/main.edl`, never overwrites |
| `edl test` | **implemented** — test programs run by the direct interpreter |
| Dependency resolution | designed, not implemented — no registry exists yet |
| `edl.lock` | designed, not implemented |
| `edl add` / `remove` / `update` / `search` / `list` / `publish` / `info` | declared in the toolchain contract, not implemented |
| Global cache `~/.edl/` | designed, not implemented |

The decision behind the manifest and the staging of the package layer is
[ADR-0005](decisions/ADR-0005-package-manifest.md).

## The manifest: `edl.toml`

```toml
[project]
name = "example"
version = "0.1.0"
edition = "2027"
entry = "src/main.edl"

[dependencies]
http = "1.0"
json = "1.0"
```

`edl.toml` is the **developer's intent**: the project's identity and which
packages it wants, at which versions. The resolution of that intent into exact,
reproducible versions will live in `edl.lock` (not implemented yet).

### Format

The parser implements a strict, documented subset of TOML
(`edl/src/edl/project.edl`):

* two tables: `[project]` and `[dependencies]`;
* `key = "value"` pairs, values in double quotes with `\n`, `\t`, `\"`, `\\`
  escapes;
* comments (`#`, full line or trailing) and blank lines;
* nothing else: no arrays, inline tables, integers or multi-line strings yet.

The subset is valid TOML, so manifests never need rewriting if the parser
grows.

### Keys

| Key | Table | Default | Meaning |
|-----|-------|---------|---------|
| `name` | `[project]` | required | the project's name; also the default output name |
| `version` | `[project]` | `0.0.0` | the project's own version |
| `edition` | `[project]` | `2027` | the language edition the project targets |
| `entry` | `[project]` | `src/main.edl` | the entry point, relative to the project root |
| anything | `[dependencies]` | — | the key is a package name, the value its version requirement |

Requirements are stored verbatim today: nothing resolves them yet, so no
requirement grammar is promised here before a resolver exists.

### Strictness

An unknown key or section is an **error**, not a warning. A typo
(`naem = "..."`) must never be silently ignored, and a dependency spelled wrong
must never turn into a missing module three directories away. Growing the
format is a deliberate change to this document and the parser together.

Errors carry the file and the line: `edl.toml:3: unknown key 'naem' in
[project]`. Manifest errors are configuration errors and stay outside the
compiler's `Diagnostics` pipeline, which is about EDL source.

## Project mode

`check`, `build`, `run`, `emit-nim` and `emit-ast` compile a single file when
given one. Without a file argument they use the **entry point of the nearest
`edl.toml`**, found by walking up from the current directory:

```sh
edl run          # = edl run <root>/<entry>
edl check        # = edl check <root>/<entry>
```

An invalid manifest is an error with its line numbers; an `entry` that does not
exist on disk is an error that shows the expected path; no manifest above the
directory is a usage error that suggests `edl init`.

## `edl init`

```sh
edl init [name]
```

Creates, and never overwrites:

* `<name>/edl.toml` — or `./edl.toml` when `name` is omitted (derived from the
  directory's own name);
* `<name>/src/main.edl` — a one-line `main` that prints, so the first
  `edl run` works with no editing.

Existing `edl.toml` or entry files make the command fail with a refusal;
`edl init` does not touch anything it did not create.

## Tests: `edl test`

```sh
edl test            # every .edl program under <root>/tests/
edl test path/...   # explicit files or directories
```

A test file is an ordinary EDL program: it has a `main`, and exit code 0 means
pass. Files are run with the **direct interpreter**, so testing needs no
bootstrap compiler and produces no artifacts; a failing program's diagnostics
are printed before the summary. Files are collected recursively and sorted, so
runs are deterministic. Output produced by test programs themselves is shown —
tests are programs, and their output is often the failure message.

This is deliberately the simplest possible test model: no assertions API, no
fixtures, no filtering, until the language has the features those need
(collections, modules, a real test contract in the toolchain). The unit tests
of the compiler itself live in `edl/tests/` and run through
`edl/scripts/test.sh`; `edl test` is for EDL *projects*.

## Dependencies (designed, not implemented)

```
edl.toml                the intent
    ↓ resolver          matches requirements against available packages
edl.lock                the resolution: exact versions, sources, checksums
```

* **No `node_modules`.** Dependencies are never duplicated per project. A
  global, content-addressed cache is the target layout:

  ```
  ~/.edl/
  ├── cache/        downloaded and built artifacts, keyed by content hash
  ├── modules/      unpacked package sources, shared across projects
  └── toolchains/   per-edition standard libraries and tool bits
  ```

  A project refers into the cache; a lockfile pins what a project needs.
* **Requirements** start as version strings (`"1.0"`, `">=1.2"`); the exact
  grammar lands with the resolver that implements it.
* **The registry** does not exist. Options (a hosted registry, git sources,
  path dependencies for local development) are open and will be decided in a
  dedicated ADR when the resolver is built — not before, because the choice
  depends on how packages are actually shared by then.
* `edl add` / `remove` / `update` / `search` / `list` / `publish` / `info` are
  the intended user surface on top of this layer. They stay "not implemented"
  until the layer under them is real; a command that only edits text and
  pretends a package was installed would be worse than no command.

## Standard library vs packages

The standard library stays limited to fundamentals (`core`, `collections`,
`string`, `math`, `io`, `fs`, `os`, `process`, `time`, then `net`, `http`,
`json`, `crypto`, `encoding`, `async`, `sync`, `database`). Everything more
specialised is a package. One syntax, one toolchain, and the target chosen by
the backend — never a dialect per domain.
