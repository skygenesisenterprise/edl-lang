# ADR-0004 — The Nim → EDL migrator

**Status:** accepted · **Date:** 2026-09-19

## Context

The EDL compiler is written in the Nim bootstrap dialect
([ADR-0001](ADR-0001-bootstrap-dialect.md)) because there is no EDL compiler
competent enough to compile it yet. That is the correct bootstrap order, but it
creates an obligation: at some point ~110 000 lines of Nim toolchain and ~130 000
lines of Nim standard library have to become EDL, and the plan cannot be "rewrite
it by hand, someday".

Two facts settle what the migration must look like:

1. **The Nim toolchain cannot be the first target.** Its core is macros, templates,
   pragmas, the VM and the ARC/ORC runtime — precisely what EDL is not inheriting —
   so rewriting it first means writing the parts we do not want.
2. **The migration must be incremental and verifiable.** A big-bang rewrite cannot
   be checked; a migration step must produce EDL that compiles and runs *that day*.

A textual replacement of `Nim` → `EDL` is not a migration: it produces a program
that no longer compiles and no longer means anything. It was rejected in
[ADR-0002](ADR-0002-identity-rebrand-scope.md) for the identity layer, and it is
rejected here for code.

## Decision

**The migration is a command: `edl migrate <file.nim>`.**

It translates the bootstrap dialect to EDL, and — this is the load-bearing part —
**reports every construct it cannot translate**, naming the spec that tracks the
missing feature. Its contract:

| Rule | Consequence |
|------|-------------|
| The output always parses | a construct with no equivalent is commented out, never emitted as garbage |
| Behaviour is never silently changed | where a faithful translation is impossible (`result` outside tail position, `continue` in a desugared `for`, an `of` range), the code is left visible and reported |
| The migrator never guesses | an unknown type stays as written; no stubs, no invented defaults, no renames beyond the type map |
| The report is the deliverable | exit status is non-zero when anything was left untranslated, so the state of the migration is measurable by a script |

The migrator is itself written in the dialect it consumes, so the tooling can be
migrated by its own output.

## Consequences

**The migration is measurable.** Running the migrator over the compiler produces a
number — currently about one line in five needs a feature EDL does not have. That
number is the project's migration metric, and the ranked list of causes is the
implementation order for the language itself (see
[../migration.md](../migration.md)).

**The language gets designed by its own requirements.** The order in which EDL
gains features is not taste: collections and `Option<T>` account for more than half
of the gap, so they come first. This is the opposite of "implement what is
interesting".

**Some Nim code will be restructured, not translated.** `result` assigned in the
middle of a routine has no EDL equivalent by design. The migrator reports it
rather than inventing a `result` variable, which means a portion of the migration
is mechanical editing by a human. That is honest, and it is the same information a
reviewer needs.

**The migrator constrains the dialect.** Because it must understand the toolchain,
[ADR-0001](ADR-0001-bootstrap-dialect.md) is not advisory: code written outside the
dialect is code that cannot be migrated mechanically, and the migrator will say so
instead of misreading it.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| Textual rename (`nim` → `edl`) | produces code that does not compile and no longer means anything |
| Hand rewrite of the toolchain, in parallel | unverifiable, unbounded, and two copies to keep working |
| Migrate the compiler only after it is fully capable | leaves the toolchain's own migration with no lead time and no measurement |
| Translate everything, stubbing what is missing | hides exactly the information that decides what to build next, and produces code that lies |
| A general-purpose Nim → EDL translator | unbounded scope, and EDL is not trying to accept all of Nim |
| Migrate the standard library first | the library depends on the same missing features, with more surface area |

## Notes

- Implementation: `edl/src/edl/migrate/` (`nimlex.nim` tokenizer, `translate.nim`).
- Tests: `edl/tests/migrate/t_migrate.nim`, including two round trips where a Nim
  file is translated, then compiled *and run* by the EDL compiler, and its output
  compared with what the original program describes.
- Contract in detail: [../migration.md](../migration.md).
