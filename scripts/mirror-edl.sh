#!/bin/sh
# Mirror every .edl source back to a sibling .nim so the Nim bootstrap
# substrate can compile it.
#
# The repository sources carry the `.edl` extension (EDL); the Nim substrate
# only compiles `.nim`. This script materialises a transient `.nim` copy next to
# each `.edl` in the *substrate* tree, so the existing build commands (`koch`,
# `compiler/nim.edl`, `testament`, ...) resolve their imports and entry points
# unchanged.
#
# The generated `.nim` are build artifacts: they are ignored by git (see
# `.gitignore`) and never committed. The committed tree stays exclusively `.edl`.
#
# The EDL toolchain tree (`edl/`) is excluded: `edl/scripts/build.sh` derives its
# own `.nim` into `build/edl/src-gen/`.

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

find . -name '*.edl' \
  -not -path './.git/*' \
  -not -path './build/*' \
  -not -path './.edlout/*' \
  -not -path './edl/*' \
  -not -path '*/node_modules/*' \
  | while IFS= read -r f; do
      cp "$f" "${f%.edl}.nim"
    done