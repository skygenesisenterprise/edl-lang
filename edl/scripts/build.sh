#!/bin/sh
# Build the EDL compiler.
#
# The EDL compiler is currently written in the Nim bootstrap dialect (ADR-0001)
# and compiled by the Nim bootstrap substrate in bin/. Build the substrate first
# with ./build_all.sh if bin/nim does not exist.
#
# Output: build/edl/edlc (gitignored)

set -e

root=$(cd "$(dirname "$0")/../.." && pwd)
nim="$root/bin/nim"

if [ ! -x "$nim" ]; then
  echo "error: $nim not found." >&2
  echo "       Build the bootstrap substrate first: ./build_all.sh" >&2
  exit 1
fi

mkdir -p "$root/build/edl"

echo "building EDL compiler ..."
"$nim" c \
  --noNimblePath \
  --skipUserCfg \
  --skipParentCfg \
  --hints:off \
  --path:"$root/edl/src" \
  --nimcache:"$root/build/edl/nimcache" \
  -o:"$root/build/edl/edlc" \
  "$root/edl/src/edlc.nim"

echo "ok: $root/build/edl/edlc"
