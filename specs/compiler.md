# The EDL compiler

## Pipeline

```
EDL source (.edl)
      │
      ▼
   Lexer          edl/src/edl/lexer.edl        text -> tokens
      │
      ▼
   Parser         edl/src/edl/parser.edl       tokens -> AST
      │
      ▼
 Name resolution  edl/src/edl/resolve.edl      identifiers -> symbols
      │
      ▼
 Type checking    edl/src/edl/typecheck.edl    nodes -> types
      │
      ▼
   Lowering       edl/src/edl/lowering.edl     typed AST -> IR
      │
      ▼
   Backend        edl/src/edl/backends/*.edl   IR -> source
      │
      ▼
  Native binary
```

Orchestration is `edl/src/edl/driver.edl`; the command line is `edl/src/edlc.edl`.

### One job per stage

| Stage | Owns | Never does |
|-------|------|------------|
| Lexer | tokens, positions, literal values | interpret structure |
| Parser | tree structure, grammar errors | resolve names, compute types |
| Resolution | symbols, scopes, forward references, callability | compute types |
| Type checking | types of every expression, all typing rules | lower, emit |
| Lowering | removing scopes and implicit naming | report errors |
| Backend | mapping IR to a target | know about source syntax |

Two structural rules make this hold:

* **The EDL AST is not Nim's AST.** They are similar because both are trees over a
  similar problem. Sharing would import Nim's node kinds and semantics into EDL.
* **The AST stays syntactic.** Resolved symbols and inferred types live in side
  tables indexed by `Node.id` (`Bindings`, `TypeCheckResult`), not in the tree.

### Diagnostics

Every stage takes the same `Diagnostics` collector and appends to it. Rendering,
codes and the rules are in [errors.md](errors.md). The pipeline **stops at the
first stage that reported an error**, so a broken program never reaches lowering,
and lowering therefore never has to invent a recovery value.

### Ids

`parseModule` calls `assignIds` and returns the node count; resolution and type
checking size their side tables with it. Ids are dense and assigned in
depth-first order, so they are stable for a given source text.

## The transitional backend

```
EDL source -> EDL IR -> Nim source -> C -> native
```

`backends/bootstrapbackend.edl` emits bootstrap source, and `backends/backend.edl` is the only
module the rest of the compiler talks to about code generation. Dispatch is an
enum and a `case`, not an object hierarchy: virtual dispatch has no EDL
equivalent, and would be an untranslatable construct in a toolchain meant to be
migrated mechanically.

The backend is transitional, and two mappings in it are EDL rules that happen to
be implemented there:

* `/` on integers becomes Nim's `div`;
* `+` on strings becomes Nim's `&`.

Both are documented in [types.md](types.md). Replacing this backend with a native
one is expected to be a change to one `case` branch.

## Toolchain contract

```
edl check     <file.edl>    lex, parse, resolve, type check. Builds nothing.
edl build     <file.edl>    compile to a native executable.
edl run       <file.edl>    build, then run.
edl emit-nim  <file.edl>    stop after the backend source is written.
edl emit-ast  <file.edl>    print the parsed tree.
edl migrate   <file.edl>    translate a bootstrap-dialect source file to EDL, with a report.
edl version
edl help
edl init | fmt | test | doc | add | remove    declared, not implemented yet
```

`edl migrate` is not part of the language: it is the tool that brings the
bootstrap toolchain over to EDL, file by file. It reads the Nim bootstrap dialect
([ADR-0001](decisions/ADR-0001-bootstrap-dialect.md)) and writes EDL, reporting
every construct it has no equivalent for — naming the spec that tracks it. Its
contract and the measured state of the migration are in
[migration.md](migration.md).

| Stage | Owns | Never does |
|-------|------|------------|
| Tokenising Nim | positions, comments, literals, Nim's type suffixes | understand structure |
| Grouping | logical lines: brackets, and Nim's statement-continuation rule | translate |
| Translating | the mapping, the report, the tail rule | invent a construct EDL does not have |

Exit codes: `0` success, `1` compilation error, `2` usage error or a command that
is not implemented yet, otherwise the exit code of the program that was run.

An executable build requires `fn main()` taking no parameters; `check` does not,
so a library can be checked.

### Artifacts

Generated source, object files and executables go to `.edlout/` (override with
`--out-dir`). The directory is hidden, and therefore ignored by version control:
compiler output never appears in `git status`.

`edl run` passes the program's own terminal through to it, so an interactive
program behaves normally.

### Locating the bootstrap compiler

In order: `--bootstrap <path>`, then `EDL_BOOTSTRAP`, then `bin/nim` in the working directory,
then `nim` from `PATH`.

### Editor and GitHub integration (roadmap)

`.edl` files are already classified as EDL by the VS Code extension (language id
`edl`, scope `source.edl`, extension `.edl`; see `packages/vscode/`). The following
are tracked as tooling work, not faked in advance of real implementations:

* **GitHub Linguist** — `.gitattributes` carries `*.edl linguist-language=EDL`.
  GitHub's Linguist only recognises languages registered upstream, so full
  `.edl → EDL` classification requires contributing an EDL language definition to
  the `github-linguist/linguist` project. Until then `.edl` is not mislabelled as
  Nim: it is simply reported as an unknown language. TODO: upstream language
  definition, then remove the `.gitattributes` override if it becomes redundant.
* **Tree-sitter** — no EDL grammar exists yet. A grammar would be a concrete
  by-product of a stabilised syntax and is not created before the parser is
  settled. TODO: contribute a `tree-sitter-edl` grammar and mirror the VS Code
  language identity (scope `source.edl`) so editors share one parse tree.

### Formatter, linter and language server (roadmap)

`edl fmt`, a linter and a language server (`edl lsp`) are declared in the
toolchain contract but are **not implemented yet**; this is status, not a fake
behaviour. When they arrive they must reuse the compiler's own components rather
than maintain a second, independent parse tree:

```text
EDL compiler
   ├── lexer ──┐
   ├── parser ─┤
   ├── AST   ──┼──→ formatter / linter / language server (one parse tree)
   ├── resolve ─┤
   ├── typecheck─┤
   └── diagnostics┘
```

A formatter, linter or LSP that parses source again with its own parser would
drift from the compiler the moment the language changes. The tools ship in the
EDL tree (`edl/tools/`) once the compiler components they depend on are stable.
Nothing is scaffolded ahead of the implementation it needs.

## Testing

`edl/scripts/test.sh` builds the compiler, builds the test runner and runs every
category in `edl/tests/`:

| Category | Covers |
|----------|--------|
| `lexer/` | tokens, literals, positions, lexical diagnostics |
| `parser/` | tree shape for every construct, error recovery, negative cases |
| `types/` | type table invariants, inference, every typing rule by code |
| `compiler/` | end to end: write a program, build it, run it, compare its output |
| `migrate/` | Nim -> EDL translation, the report, and round trips through the compiler |

End-to-end tests are the ones that matter most: they are what makes "EDL compiles"
a fact rather than a claim. `edl/scripts/test.sh` passes the compiler binary to
them through `EDL_BIN`, so the command line interface is covered too.

## Coding standard for the bootstrap

All Nim in `edl/` follows [ADR-0001](decisions/ADR-0001-bootstrap-dialect.md):
plain procs, objects, enums and `seq`, with no macros, templates, custom pragmas
or compile-time evaluation. The reason is migration, not austerity: this code is
meant to be translated to EDL by a machine, and constructs with no EDL equivalent
cannot be translated and would quietly anchor Nim semantics into the new language.

The dialect is not merely a style rule: `edl migrate` understands exactly this
subset, and reports anything outside it instead of misreading it. Writing outside
the dialect is therefore writing code that cannot be migrated mechanically, and
the report will say so.
