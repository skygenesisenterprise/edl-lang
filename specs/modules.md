# EDL modules and imports

**Status: specified, not implemented.** `import` parses correctly and is then
reported as `EDL0501`, so the grammar is already stable.

## Target syntax

```edl
import net
import http
import database
```

```edl
import { User, Account } from app.models
```

Both forms are already parsed. A file is a module; there is no module declaration
statement.

## Design constraints

These are decided now because they constrain everything downstream.

1. **A reader must be able to tell where a symbol comes from without leaving the
   file.** No wildcard imports that silently add names, no implicit re-export
   chains, no implicit path magic beyond the declared search roots.
2. **Only what is imported is visible.** A module that is imported but not used
   contributes nothing to the importer's namespace.
3. **Resolution must be simple enough to explain in one paragraph.** If the
   algorithm needs a diagram, it is too complex for a language whose first
   priority is simplicity.
4. **Cycles are an error**, reported clearly, rather than a puzzle about
   initialization order.
5. **Imports are resolved statically.** No conditional or computed imports, so the
   module graph is knowable without running anything.

## Open questions

1. **Qualified or unqualified by default?** `import { User } from app.models`
   brings `User` in unqualified. `import net` — does it require `net.TcpStream`,
   or does it add names directly? A namespace-qualified default (Rust-like) is
   probably safer for readability; TS-like named imports are probably nicer for
   the common case. Not decided.
2. **File extension and directory mapping:** `app.models` means `app/models.edl`?
   Is there a per-project search root (a manifest), or only relative paths?
3. **What is a package versus a module?** The toolchain has `edl add`/`edl remove`
   in its contract; that implies a manifest format that does not exist yet.
4. **Visibility control:** does EDL need `export`/`private`, or is everything
   exported by default with names being the only interface? One of the two must be
   chosen before the standard library is written, because it determines the public
   surface of every module.
5. **The standard library's layout** (`net`, `http`, `database` as top-level
   imports, versus a structured namespace).

## Interaction with the migration

`compiler/modules.nim` and `compiler/modulegraphs.nim` in the Nim substrate do
this job today for Nim. They are **not** a design to be copied: EDL's module
system is specified above, and the substrate's implementation is replaced rather
than inherited. The substrate's module graph is only reused, temporarily, as the
frontend's *input* mechanism (reading files), not as the language's semantics.
