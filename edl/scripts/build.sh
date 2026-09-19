#!/bin/sh
# Build the EDL compiler.
#
# The EDL compiler is written in the bootstrap dialect (ADR-0001). Its source
# files carry the `.edl` extension; the bootstrap substrate in bin/ only compiles
# `.nim`. This script therefore derives a `.nim` copy of every `.edl` source into
# the gitignored `build/edl/src-gen/` tree, then compiles the entry point from
# there. The `.nim` files are generated build artifacts, never committed.
#
# Build the substrate first with ./build_all.sh if bin/nim does not exist.
#
# Output: build/edl/edlc (gitignored)

set -e

root=$(cd "$(dirname "$0")/../.." && pwd)
nim="$root/bin/nim"
if [ ! -x "$nim" ] && [ -f "$root/bin/nim.exe" ]; then
  nim="$root/bin/nim.exe"   # Windows: the substrate builds bin/nim.exe
fi

if [ ! -x "$nim" ]; then
  echo "error: $nim not found." >&2
  echo "       Build the bootstrap substrate first: ./build_all.sh" >&2
  exit 1
fi

gen="$root/build/edl/src-gen"

# Derive a .nim copy of every .edl source (preserving the relative layout) so
# the substrate can compile it. Both the compiler sources (edl/src) and the
# tests (edl/tests) share one generated tree, exactly mirroring their imports.
mirror_sources() {
  src_dir="$1"
  out_dir="$2"
  find "$src_dir" -name '*.edl' | while IFS= read -r f; do
    rel="${f#"$src_dir"/}"
    target="$out_dir/${rel%.edl}.nim"
    mkdir -p "$(dirname "$target")"
    cp "$f" "$target"
  done
}

mkdir -p "$gen"
mirror_sources "$root/edl/src" "$gen"
mirror_sources "$root/edl/tests" "$gen"

echo "building EDL compiler ..."
"$nim" c \
  --noNimblePath \
  --skipUserCfg \
  --skipParentCfg \
  --hints:off \
  --path:"$gen" \
  --nimcache:"$root/build/edl/nimcache" \
  -o:"$root/build/edl/edlc" \
  "$gen/edlc.nim"

echo "ok: $root/build/edl/edlc"