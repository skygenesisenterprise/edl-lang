#!/bin/sh
# Run the EDL test suite.
#
# Categories live in edl/tests/<category>/ and are aggregated by
# edl/tests/runner.nim. End-to-end tests (edl/tests/compiler/) exercise the real
# compiler binary, whose path is passed through EDL_BIN.

set -e

root=$(cd "$(dirname "$0")/../.." && pwd)
nim="$root/bin/nim"

if [ ! -x "$nim" ]; then
  echo "error: $nim not found." >&2
  echo "       Build the bootstrap substrate first: ./build_all.sh" >&2
  exit 1
fi

# The end-to-end tests need the compiler itself. Until edlc.nim exists, the
# frontend unit tests still run: they exercise the lexer, parser and semantic
# passes directly, without going through the driver.
if [ -f "$root/edl/src/edlc.nim" ]; then
  "$root/edl/scripts/build.sh"
else
  echo "note: edl/src/edlc.nim does not exist yet; skipping the compiler build."
fi

mkdir -p "$root/build/edl"

echo "building EDL test runner ..."
"$nim" c \
  --noNimblePath \
  --skipUserCfg \
  --skipParentCfg \
  --hints:off \
  --path:"$root/edl/src" \
  --nimcache:"$root/build/edl/nimcache-tests" \
  -o:"$root/build/edl/edl_tests" \
  "$root/edl/tests/runner.nim"

echo "running EDL tests ..."
EDL_BIN="$root/build/edl/edlc" EDL_NIM="$nim" "$root/build/edl/edl_tests"
