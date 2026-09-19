# Remaining historical and bootstrap references

This document is the authoritative register of every place in the repository that
still refers to the Nim bootstrap substrate or to the historical Nim code it
inherits from.

The rule of the migration is not "zero occurrences of `nim`". It is:

> Zero unjustified occurrences in EDL's public identity, and every remaining
> occurrence isolated, named, and accounted for.

Every entry below is intentional. A reference that exists only because a rename
was forgotten is a bug; a reference that is the substrate is not.

## 1. The bootstrap substrate source

The Nim compiler, standard library, tooling and test suite that the EDL toolchain
is currently built with. These are upstream Nim components, kept frozen and used
as the *bootstrap substrate*. They are vendored out of GitHub's language
statistics by `.gitattributes`.

| Path | What it is | Why it remains |
|------|-----------|----------------|
| `compiler/` | The Nim compiler. | Builds the EDL toolchain; replaced progressively by `edl/`. |
| `lib/` | The Nim standard library. | The substrate runtime until the EDL standard library exists. |
| `tools/` | Nim tooling (build, install, helpers). | Substrate build/tooling. |
| `testament/` | Nim test runner. | Substrate test harness. |
| `nimsuggest/`, `nimpretty/`, `drnim/`, `nimdoc/` → `lsp/`, `formatter/`, `analyzer/`, `docgen/` | Nim IDE, formatter, analyzer, docgen (renamed directories). | Substrate tooling. |
| `tests/`, `tests_disabled/` | Nim test suite. | Non-regression harness for the migration (drives EDL correctness). |
| `doc/`, `changelogs/`, `changelog.md` | Nim documentation and history. | Historical reference; **permanent** for history and attribution. |
| `config/`, `ci/`, `icons/`, `csources_v3/` | Substrate config, CI helpers, icons, bootstrap C sources. | Required to build the substrate (`build_all.sh`). |
| `koch.nim`, `koch.nim.cfg`, `nim.nimble`, `build_all.sh`, `build_all.bat`, `azure-pipelines.yml` | Substrate build system and manifests. | Root-level bootstrap entry points. |
| `bin/nim-gdb`, `bin/nim-gdb.bat`, `bin/empty.txt`, `build/empty.txt` | Substrate debug scripts and directory placeholders. | Minor substrate helpers. `bin/nim` itself is a gitignored build artifact, never committed. |

**Future removal strategy:** each component is removed once the corresponding EDL
component exists and passes the tests it inherits (see `edl/`, `specs/`, and the
"Understand before you delete" rule in the root `readme.md`). The substrate is a
transition, not the identity of the project.

## 2. The EDL toolchain bootstrap implementation

The EDL compiler frontend itself is currently written in the Nim bootstrap dialect
so it can be compiled by the substrate and migrated to EDL mechanically
([ADR-0001](decisions/ADR-0001-bootstrap-dialect.md)). The sources carry the
`.edl` extension; the substrate build derives transient `.nim` copies into
`build/edl/src-gen/` (`edl/scripts/build.sh`).

| Path | What it is | Why it remains |
|------|-----------|----------------|
| `edl/src/**/*.edl` (25 tracked files) | The EDL compiler, lexer, parser, AST, type checker, IR, driver, backends, migrator. | Written in the bootstrap dialect so the substrate can build it; the target is that each file stops being dialect via `edl migrate`. |
| `edl/tests/**/*.edl` | The EDL test suite (325 checks). | Written in the bootstrap dialect for the same reason. |

**Future removal strategy:** `edl migrate` translates each file to EDL; the state
of the migration is measured and tracked in `specs/migration.md`. The bootstrap
dialect disappears as the migration progresses. This is EDL-owned code that
*currently* uses the substrate language — it is not the substrate itself.

## 3. The bootstrap backend

| Path | What it is | Why it remains |
|------|-----------|----------------|
| `edl/src/edl/backends/backend.edl` | Backend interface (the replacement seam). | Kept so a native backend can replace the bootstrap one without touching the frontend or IR. |
| `edl/src/edl/backends/bootstrapbackend.edl` | The transitional backend: EDL IR → bootstrap source → C → native (`edl build`). | Produces a standalone native binary. `edl run` no longer needs it: `edl/src/edl/interp.edl` executes the IR directly, with no external compiler. **Temporary by design.** |

**Future removal strategy:** replace the single backend implementation behind
`backend.edl` with a direct native (and later WASM) backend; the bootstrap backend
is then deleted.

## 4. Runtime references inside the EDL driver

| Path | Reference | Why it remains |
|------|-----------|----------------|
| `edl/src/edl/driver.edl` | `bootstrapExe`, `EDL_BOOTSTRAP`, `bin/nim`, `nim` from PATH (`findBootstrapExe`). | The driver must locate the substrate compiler to build generated output. |
| `edl/src/edl/driver.edl` | `outDir / "bootstrap-cache"` | Where the backend caches generated output. |
| `edl/src/edl/backends/bootstrapbackend.edl` | Header `"Generated by the EDL compiler (bootstrap backend). Do not edit."` | Marks generated source as an artifact, not source. |
| `edl/scripts/build.sh`, `edl/scripts/test.sh` | `$root/bin/nim`, `EDL_BOOTSTRAP`, `EDL_BIN` | Locate the substrate and the built compiler. |

**Future removal strategy:** `findBootstrapExe` and `EDL_BOOTSTRAP` disappear when
`edl build` can compile the compiler itself (self-host). The cache naming becomes
backend-neutral.

## 5. Substrate CI workflows

| Path | Why it remains |
|------|----------------|
| `.github/workflows/ci_packages.yml`, `ci_publish.yml`, `ci_docs.yml`, `bisects.yml`, `stale.yml` | CI that builds, tests, and publishes the **substrate** (`nim c koch`, `./koch boot`, `ci/funs.sh` Nim helpers). They exist to keep the bootstrap substrate reliable while the EDL toolchain depends on it. |

The EDL-owned workflows (`release.yml`, `vscode.yml`, `vscode-release.yml`,
`website.yml`) are EDL-identity and are the ones that ship EDL artifacts. The
substrate workflows above are isolated, named bootstrap-build CI, not EDL
publishing.

**Future removal strategy:** deleted as the substrate's build/test responsibilities
move to the EDL toolchain (`edl/scripts/`, `release.yml`).

## 6. Historical and attribution references

These must **not** be rewritten; they are legitimate history and licensing.

| Path | Reference | Why it remains |
|------|-----------|----------------|
| `copying.txt` | Full Nim upstream MIT license, "Derived work notice", Copyright © Andreas Rumpf. | Required attribution for inherited code. **Permanent.** |
| `doc/`, `changelogs/`, `changelog.md` | Nim documentation and changelogs. | Historical record. **Permanent.** |
| `specs/decisions/ADR-0001`, `ADR-0002`, `ADR-0003`, `ADR-0004` | Nim bootstrap dialect, rebrand scope, syntax surface, migrator decisions. | The migration decisions that define the transition. **Permanent as design record.** |
| `specs/migration.md`, `specs/architecture.md`, `specs/compiler.md` | Measured migration state, substrate role, toolchain contract. | Track and define the bootstrap. **Permanent as living documents.** |

## 7. Verification

This register is the result of the exhaustive post-migration search mandated by
the project rules. Every remaining occurrence of `Nim` / `nim` / `NIM` /
`Nimble` / `nimble` / `koch` / `nimcache` / `nimdoc` / `nimscript` in the
repository is accounted for by one of the sections above.

To re-run the audit:

```sh
grep -rli --exclude-dir=.git --exclude-dir=node_modules \
  --exclude-dir=csources_v3 --exclude-dir=.edlout -E \
  'nim|nimble|koch|nimcache|nimdoc|nimscript' . | grep -v -E 'node_modules|csources_v3|\.edlout|\.git/'
```