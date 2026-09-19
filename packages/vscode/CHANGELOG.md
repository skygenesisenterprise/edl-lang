# Change Log

All notable changes to the **EDL — Official Language Support** VS Code extension are
documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The version of the extension is **independent** of the version of the EDL
compiler. See [`package.json`](./package.json) — the `version` field there is the
single source of truth.

## [Unreleased]

### Changed

- Reworked the syntax highlighting grammar around a **TypeScript/Python-mixed
  palette** matching the default VS Code theme (Dark+): `entity.name.type`
  (turquoise) for custom types and `storage.type` (blue) for primitives, Python
  logical keywords (`and`/`or`/`not`/`in`) as `keyword.operator.logical`,
  builtins (`print`, `echo`, `defined`, `quit`, `sleep`) as
  `support.function.builtin`, `true`/`false`/`nil` as `constant.language`,
  parameters as `variable.parameter` and field access as
  `variable.other.property`.
- Extended the grammar to the **bootstrap-dialect surface** found in substrate
  `.edl` files: `proc`/`method`/`iterator` declarations, `when`/`defined`,
  `try`/`except`/`raise`/`discard`, `result`, Nim primitive types, `#` comments,
  pragmas `{. ... .}` and numeric type suffixes (`'i32`, `'u64`, ...). Every
  `.edl` file is now colorized.

## [0.1.0] - 2026-09-19

First release. Provides official, non-LSP language support for EDL in Visual
Studio Code.

### Added

- Language identification for `*.edl` files (language id `edl`).
- TextMate syntax highlighting for the EDL surface syntax as specified in
  [`specs/syntax.md`](../../specs/syntax.md) — keywords, types, literals,
  operators, `//` and nested `/* ... */` comments, `fn`/`struct`/`enum`
  declarations and the temporary `print` builtin.
- Language configuration: indentation, bracket auto-closing and surrounding
  pairs, comment toggling, word patterns and folding markers.
- A starter set of snippets for `fn`, `let`, `var`, `if`/`else`, `while`, `for`,
  `struct`, `enum`, `import`, `return`, `print` and `main`.
- An EDL example (`examples/hello.edl`).
- Packaging with `@vscode/vsce`, a `.vscodeignore`, CI workflows, and a
  GitHub Actions artifact containing the `.vsix`.
- A minimal, maintainable test harness (manifest + grammar + packaging checks).

### Notes

- `for` loops, indexing, `import`, `nil` and `unsafe` parse in the language but
  are reported by the compiler as "specified but not implemented". The grammar
  highlights them today; they are not semantically validated by this extension.
- Language Server features (completion, hover, diagnostics, go-to-definition,
  etc.) are **not** included in this release. They are planned for a future
  version.

[Unreleased]: https://github.com/skygenesisenterprise/edl-lang
[0.1.0]: https://github.com/skygenesisenterprise/edl-lang