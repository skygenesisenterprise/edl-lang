## The backend interface.
##
## Everything the rest of the compiler knows about code generation goes through
## this module. Swapping the transitional bootstrap backend for a native one is
## supposed to be a change to one `case` branch, not to the language, the
## frontend, the IR, or the driver.
##
## Dispatch is an enum plus a `case` rather than an object hierarchy: virtual
## dispatch has no EDL equivalent, so it would be an untranslatable construct in
## the middle of a toolchain that is meant to be migrated mechanically.
##
## Bootstrap dialect: see specs/decisions/ADR-0001.

import ../ir
import ../types
import ./nimbackend

type
  BackendKind* = enum
    bkError
    bkBootstrap   ## EDL IR -> bootstrap source -> C -> native (transitional)

proc backendName*(kind: BackendKind): string =
  case kind
  of bkError: result = "<error>"
  of bkBootstrap: result = "bootstrap"

proc backendSourceExtension*(kind: BackendKind): string =
  ## Extension of the file `emitModule` produces.
  case kind
  of bkError: result = ""
  of bkBootstrap: result = "nim"

proc emitModule*(kind: BackendKind, m: IrModule, t: TypeTable): string =
  ## Renders an IR module as source in this backend's language.
  case kind
  of bkError: result = ""
  of bkBootstrap: result = emitNimModule(m, t)

proc compileOutput*(kind: BackendKind, compilerExe, srcPath, outPath, workDir,
                    cacheDir: string, output: var string): bool =
  ## Turns this backend's emitted source into a native executable.
  case kind
  of bkError: result = false
  of bkBootstrap:
    result = compileNimSource(compilerExe, srcPath, outPath, workDir, cacheDir,
                              output)
