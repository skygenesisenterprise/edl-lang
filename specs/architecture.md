# EDL architecture

This document is the technical map of the project: what the repository contained
when the EDL work started, what each part is worth, and how the Nim substrate is
progressively replaced by EDL. It is the output of the mandatory audit performed
before any code was changed.

## 1. Starting point

`skygenesisenterprise/edl-lang` began as a pristine clone of the Nim compiler
repository (`devel`, 23 171 commits, ~110 000 lines of compiler code and ~130 000
lines of standard library). There was **no EDL code at all**: no lexer, no parser,
no type system, no EDL-specific tooling. The only modifications were the git
remote and the absence of Nim's original README.

Everything below is therefore a description of the *Nim* codebase, sorted by what
EDL should do with it.

## 2. Audit: what the repository is made of

### Compiler (`compiler/`, ~170 modules, 110 392 lines)

| Layer | Modules | Volume | Role |
|-------|---------|--------|------|
| Frontend | `nimlexbase`, `lexer`, `parser`, `ast`, `astdef`, `nodekinds`, `renderer` | ~9 k | Nim tokens, parsing, AST |
| Semantics | `sem*`, `sigmatch`, `lookups`, `concepts`, `guards`, `typeallowed`, `pragmas` | ~35 k | name resolution, type checking, overloading, generics, pragmas |
| Types | `types`, `typekeys`, `deps` | ~3.5 k | Nim type representation |
| Middle-end | `transf`, `injectdestructors`, `liftdestructors`, `closureiters`, `lambdalifting`, `nilcheck`, `varpartitions`, `optimizer`, `lowerings` | ~12 k | lowering, ARC/ORC injection, closures |
| Backends | `cgen` + `ccg*`, `jsgen`, `vm`/`vmgen`/`vmops`, `nifgen`/`nifbackend`, `docgen` | ~22 k | C, JS, compile-time VM, NIF, docs |
| Memory | `system/alloc`, `system/arc`, `system/gc_*`, `cyclebreaker`, `deepcopy` | — | refc / ARC / ORC / boehm |
| Driver | `main`, `commands`, `options`, `msgs`, `lineinfos`, `modulegraphs`, `modules`, `importer`, `extccomp`, `ic/` | ~8 k | pipeline, module graph, diagnostics, C invocation |
| Packages | `nimblecmd`, `packagehandling`, `packages` | ~2 k | package management |

### Everything else

| Area | Content | Volume |
|------|---------|--------|
| `lib/` | standard library: `system` (19.3 k), `pure` (68.9 k), `std` (14.8 k), `posix` (8.2 k), `core`, `js`, `windows`, `packages`, `wrappers` | 316 files, ~130 k lines |
| `tests/` | 132 test categories + `testament` runner | 1 122 files referencing Nim |
| Tooling | `koch` (build), `nimble` (packages), `nimpretty` (formatter), `nimsuggest` (IDE), `drnim` (static analysis), `nimdoc` (docs) | ~40 k lines |
| Build/config | `build_all.sh`, `koch.nim`, `config/`, `nim.cfg`, `azure-pipelines.yml`, `.github/` | — |
| Docs | `doc/` (51 files), `changelogs/` (14 files) | — |

### Coupling to Nim

Measured across `compiler/`: 6 459 `proc`, 1 002 `template`/`macro`, 503 `pragma`,
875 `when`, 5 887 `var`, 5 045 `let`, 891 `type`, 592 `import`. Across the tracked
tree, roughly **19 600 occurrences of "nim" in ~1 850 files**.

This number matters: it is the reason a textual rename is not a migration. Most of
those occurrences are load-bearing identifiers — `NimMajor`, `nimvm`,
`defined(nimHasUsed)`, `import system/...`, `.nim` module names, test expectations,
CI action references. Renaming them does not produce an EDL project; it produces a
repository that no longer compiles.

## 3. Disposition of each component

The five buckets required before any large change.

### Kept as-is (bootstrap substrate, temporarily load-bearing)

* `compiler/` in full — it *is* the toolchain that compiles the EDL frontend today.
* `lib/` — the runtime EDL programs link against while the EDL runtime is built.
* `testament/`, `tests/` — reused as the **non-regression harness** for the migration.
* `csources_v3` + `build_all.sh` — the bootstrap chain producing `bin/nim`.

### Renamed / redefined (EDL-facing identity, no logic change)

* Repository identity: `readme.md`, `copying.txt` (EDL notice added, upstream MIT
  notice preserved verbatim).
* Toolchain commands: `koch build/test` → `edl build/test`; `nimpretty` → `edl fmt`;
  `nimsuggest` → `edl lsp`; `nimble` → `edl add/remove`.
* The package format (`nimble` manifests) → an EDL project manifest.

Deliberately *not* renamed at this stage, and why, is recorded in
[ADR-0002](decisions/ADR-0002-identity-rebrand-scope.md).

### Encapsulated (frozen behind an EDL interface, replaced later)

* Code generation: `cgen`/`ccg*` and `jsgen` sit behind the EDL backend interface.
* The C toolchain invocation (`extccomp`) sits behind the driver's build step.
* Module loading and the module graph (`modules`, `modulegraphs`, `importer`).
* Diagnostics (`msgs`, `lineinfos`) — EDL has its own from day one
  (`edl/src/edl/diagnostics.edl`); the Nim ones are only used by the substrate.

### Replaced progressively (EDL implementation required)

Order chosen so that each step is verifiable and revertible:

1. Lexer, tokens, diagnostics — **EDL implementation written**.
2. AST, parser — in progress.
3. Name resolution, type system, type checker.
4. IR and lowering.
5. Native backend (replacing the temporary Nim-lowering backend).
6. Standard library core (`string`, collections, IO), then the rest.
7. The `edl` toolchain: build, run, test, fmt, check, doc, lsp.
8. Self-hosting.

### Removed (eventually, and only after replacement is verified)

* `koch` and the Nim build scripts, once `edl build` covers bootstrapping.
* The Nim frontend and semantic layers, once EDL compiles itself.
* Test categories that are about Nim-the-language rather than the substrate.
* Nim documentation and changelogs, once EDL specification and history exist.

**Nothing in this bucket is deleted in this phase.** Per rule 19 of the mission:
understand, identify dependencies, build the equivalent, move the tests, verify
compilation, and only then remove.

## 4. Target architecture

```
EDL source (.edl)
      │
      ▼
   Lexer ──────────── tokens ────────┐
      │                              │
      ▼                              │
   Parser ──────────── EDL AST ──────┤   edl/src/edl/{lexer,parser,ast}.edl
      │                              │
      ▼                              │
Name resolution ───── bindings ──────┤   resolve.edl, scopes.edl
      │                              │
      ▼                              │
 Type checking ─────── typed AST ────┤   types.edl, typecheck.edl
      │                              │
      ▼                              │
   Lowering ─────────── EDL IR ──────┘   ir.edl, lowering.edl
      │
      ▼
  Backend interface ──┬── interpreter (edl run, direct, no external compiler)
                      ├── bootstrap backend (transitional, edl build)
                      ├── Native backend (target)
                      └── WASM backend (future)
```

Invariants that keep this honest:

* **The EDL AST is not the Nim AST.** They are similar because both are trees; they
  are not the same because the languages are not the same. Sharing the Nim AST
  would silently import Nim's semantics into EDL.
* **Every stage has one job.** Name resolution does not check types; type checking
  does not lower; lowering does not generate code.
* **Diagnostics are produced by every stage**, with stable codes (`EDL0101`…`EDL09xx`)
  documented in [`errors.md`](errors.md), and are treated as a feature, not as
  collateral output.
* **Backends are behind an interface.** Swapping the Nim backend for the native one
  must not touch the frontend or the IR.

## 5. Migration strategy

The dependency that shapes everything: EDL is written *in* the language it is
building, so EDL cannot be compiled until an EDL compiler exists, which cannot be
written without a compiler. The escape is to keep the substrate alive while the
EDL toolchain grows, and to make the two meet in the middle:

```
   Nim substrate  ──builds──▶  EDL toolchain (frontend in Nim, bootstrap dialect)
        ▲                              │
        │                              ▼
        └────────emits Nim───────  EDL IR  ──▶ native binary
```

Phases, each one shippable:

| Phase | Goal | State |
|-------|------|-------|
| 1 | Audit and architecture | **done** (this document) |
| 2 | Isolation: EDL tree, diagnostics, ADRs, identity | **done** |
| 3 | Bootstrap: compile a minimal EDL program end to end | in progress |
| 4 | Type system: primitives, structs, enums, functions, generics, `Option`, `Result` | next |
| 5 | Modules and imports | planned |
| 6 | EDL runtime | planned |
| 7 | Native backend | planned |
| 8 | Toolchain: `edl build/run/test/fmt/check` | planned |
| 9 | Web, networking, database capabilities | planned |
| 10 | Self-hosting | long-term |

## 6. Risks and how they are handled

| Risk | Handling |
|------|----------|
| The bootstrap dialect drifts into general Nim | ADR-0001 rules; new modules in `edl/` are reviewed against it |
| Nim semantics leak into EDL through the AST or the backend | separate AST; backend isolated and explicitly temporary |
| The migration stalls half-way with two half-languages | phases are additive and revertible; the Nim substrate is never deleted before its replacement passes tests |
| A gigantic unreviewable commit makes the project impossible to bisect | small, coherent, revertible changes; each phase verified before the next |
| The language grows by accumulation instead of design | each behaviour is specified in `specs/` before becoming a dependency |
| Licence/attribution damage | upstream MIT notice preserved verbatim; derived-work notice added |

## 7. Decisions recorded

* [ADR-0001](decisions/ADR-0001-bootstrap-dialect.md) — the bootstrap dialect.
* [ADR-0002](decisions/ADR-0002-identity-rebrand-scope.md) — scope of the identity rebrand.
* [ADR-0003](decisions/ADR-0003-edl-syntax-surface.md) — the EDL surface syntax.
