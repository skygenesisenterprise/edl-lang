# EDL — Official Language Support

**EDL — Official Language Support** is the official language extension for
[EDL](https://github.com/skygenesisenterprise/edl-lang) in Visual Studio Code.
EDL is a statically typed, natively compiled language designed to be simple to
learn and fast to write — readable like TypeScript, productive like Python, and
suitable for backend, systems and web development.

This extension is maintained in the EDL repository and is the first brick of the
EDL tooling ecosystem.

## Features

Currently **available**:

- Language recognition for `.edl` files (language id `edl`).
- TextMate **syntax highlighting** covering the EDL surface syntax specified in
  [`specs/syntax.md`](https://github.com/skygenesisenterprise/edl-lang/blob/master/specs/syntax.md):
  keywords, scalar and primitive types, integer/float/string/char literals,
  operators, `//` and nested `/* ... */` comments, and `fn`/`struct`/`enum`
  declarations.
- **Language configuration**: smart indentation, bracket auto-closing and
  surrounding pairs, comment toggling, word pattern and folding markers.
- A starter set of **snippets** for common EDL constructs.
- An **example** program (`examples/hello.edl`).

**Planned** (not in this release):

- Compiler diagnostics integration.
- Language Server Protocol support: completion, hover, go-to-definition,
  references, rename, semantic diagnostics.
- Formatter, refactoring, debugger, integrated build/run.

The extension is a text-oriented language tool and never re-implements the EDL
compiler. Advanced features will build on the compiler, its AST and its semantic
analysis, or on an official EDL Language Server.

## Requirements

- Visual Studio Code 1.75.0 or later.
- No external dependencies at runtime.

## Installation

### From the VS Code Marketplace (once published)

The extension is not yet published to the Visual Studio Code Marketplace. Until
it is, install it from the `.vsix` (below).

### From a `.vsix` file

1. Download or build `edl-language-support-<version>.vsix` (see
   [Building the VSIX](#building-the-vsix)).
2. In VS Code open the **Extensions** view (`Ctrl+Shift+X`), click the `...`
   menu and choose **Install from VSIX...**, then select the file.

### Running in development mode (Extension Development Host)

1. Install the extension's dependencies: `npm install` (run from
   `packages/vscode`).
2. Open the `packages/vscode` folder as a workspace in VS Code.
3. Press `F5` to launch an **Extension Development Host** window. Open an `.edl`
   file there to see highlighting, snippets and configuration in action.

## Usage

Open any `.edl` file. The language is recognised automatically, with syntax
highlighting, snippets and code-folding. Type `fn` or `main` and trigger
IntelliSense to expand a snippet.

## Example

```edl
// The smallest EDL program.
fn main() {
    print("Hello World")
}
```

## Development

The extension lives in [`packages/vscode`](https://github.com/skygenesisenterprise/edl-lang/tree/master/packages/vscode)
inside the EDL repository.

Prerequisites: [Node.js](https://nodejs.org) and `npm`.

```sh
cd packages/vscode

npm install        # install dependencies (adds @vscode/vsce)
npm run check      # validate the manifest and required files
npm run test       # run the test suite
npm run package    # build the VSIX (edl-language-support-<version>.vsix)
```

## Building the VSIX

From `packages/vscode`:

```sh
npm install
npm run package
```

This produces `edl-language-support-<version>.vsix` in the package directory (version comes from
`package.json`). The `.vsix` is a ZIP installable directly in VS Code:

```sh
code --install-extension edl-language-support-0.1.0.vsix
```

To inspect the archive contents:

```sh
unzip -l edl-language-support-0.1.0.vsix
```

## Roadmap

```text
v0.1  Syntax highlighting, language configuration, snippets, VSIX packaging   [this release]
v0.2  Compiler diagnostics integration, basic tooling
v0.3  LSP, completion, hover, go-to-definition, references
v0.4+ Formatter, refactoring, debugger, integrated build/run
```

## Contributing

Contributions are welcome. See the repository
[contributing guidelines](https://github.com/skygenesisenterprise/edl-lang/blob/master/CODE_OF_CONDUCT.md)
and open a pull request. Changes to the grammar must match the normative EDL
syntax in `specs/syntax.md` and are expected to come with a test.

## License

MIT. See [`LICENSE`](LICENSE). EDL itself is MIT licensed; see the repository
[`copying.txt`](https://github.com/skygenesisenterprise/edl-lang/blob/master/copying.txt).