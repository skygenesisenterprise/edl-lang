# ADR-0002 — Scope of the EDL identity rebrand

* Status: accepted
* Date: 2026-09-19
* Supersedes: none

## Context

The repository was a pristine clone of the Nim compiler. The project wants it to
*be* EDL — a developer cloning it should see an EDL project, not a Nim fork — and
there was a request to "replace every mention of nim with edl".

The audit measured that request's surface: **~19 600 occurrences of "nim" across
~1 850 files**, almost all of them load-bearing.

| Layer | Occurrences | Nature |
|-------|-------------|--------|
| `compiler/` | 3 307 | `NimMajor`, `nimvm`, `defined(nimHasUsed)`, module names |
| `lib/` | 4 555 | standard library identifiers and module paths |
| `tests/` | 4 399 | test names and expected outputs, `testament` configuration |
| `doc/`, `changelogs/` | 4 707 | prose |
| `tools/`, `config/`, `ci/`, `.github/` | 1 008 | executed scripts and CI references |
| `testament/`, `nimsuggest/`, `nimpretty/`, `drnim/` | 995 | tooling source |
| root files | 711 | `koch.nim`, `readme.md`, `nim.nimble`, build scripts |

A textual replacement across the first, second, third and seventh rows does not
rename a project: it deletes the identities the compiler is built out of, and the
repository stops compiling — including the EDL compiler that is being written on top
of it. It also contradicts the project's own migration rule that a component is
removed only after its replacement exists and passes tests.

There is a further constraint that is not negotiable: this repository is a derived
work of Nim under the MIT license. The upstream copyright notice must remain.

## Decision

The rebrand covers the **identity layer** only: what the repository says it is.
It does not cover code, build logic or test expectations, which are rebranded as a
*consequence* of being replaced, never before.

**Rebranded now**

* `readme.md` — rewritten as the EDL README: what EDL is, the repository layout, the
  explicit separation between the EDL tree and the Nim substrate, the build and test
  commands, the phase-by-phase roadmap, and the license position.
* `copying.txt` — an EDL MIT notice added, followed by a derived-work notice, with
  the upstream Nim notice preserved **verbatim** (upstream copyright still at its
  original text and position).
* New: `specs/` — the EDL specification, architecture map and decision records.
* New: `edl/` — the EDL toolchain tree.

**Deliberately not rebranded, with reasons**

| Path | Why it keeps the Nim name |
|------|---------------------------|
| `compiler/` | It is the Nim compiler, and it builds the EDL toolchain today. Its identifiers are executable. Replaced by the EDL compiler, phase by phase. |
| `lib/` | The standard library EDL programs link against until the EDL runtime exists. Renaming module paths breaks every `import`. |
| `tests/`, `testament/` | Kept as the non-regression harness for the migration. Test names and expected outputs are verified content. |
| `koch.nim`, `build_all.sh`, `build_all.bat`, `nim.nimble`, `config/nim.cfg`, `config/build_config.txt` | Build logic. `build_all.sh` is what produces `bin/nim`; renaming inside it breaks bootstrapping. Replaced when `edl build` covers bootstrapping. |
| `ci/`, `azure-pipelines.yml`, `.github/` | CI references upstream actions, toolchain suffixes and repository URLs that are executed, not displayed. Re-cibled on EDL CI in a later phase. |
| `doc/`, `changelogs/` | Historical Nim documentation. Superseded by `specs/`, then removed — not renamed into misleading EDL documentation. |
| `nimsuggest/`, `nimpretty/`, `drnim/` | Tools that are *for* the Nim bootstrap compiler. They become `edl lsp`, `edl fmt`, `edl check` when those are written. |

**Rule going forward**

> A Nim reference is renamed when, and only when, the component containing it has
> been replaced by an EDL implementation that passes the tests it inherited.
> Renaming is an outcome of replacement, not a preliminary to it.

The substrate's presence is not hidden: `readme.md` and `specs/architecture.md`
state plainly that `compiler/` and `lib/` are a temporary bootstrap substrate. That
is more honest, and more useful to a reader, than a tree that claims to be EDL while
containing transplanted Nim.

## Consequences

**Positive**

* The repository presents itself as EDL to anyone who clones or opens it.
* Nothing is broken: the bootstrap still builds, `bin/nim` still works, the EDL
  frontend still compiles.
* The change is one commit over four files plus new directories, and is trivially
  revertible.
* Upstream attribution and license obligations are satisfied in full.

**Negative**

* `compiler/`, `lib/`, `tests/` and the tooling still contain the word Nim, so the
  rebrand is visibly incomplete. This is temporary by construction: the completion of
  the rebrand *is* the migration, and it is tracked as phases 4-10 of
  `specs/architecture.md`.
* Anyone expecting a fully renamed tree must read `specs/architecture.md` to
  understand why it is not one.
