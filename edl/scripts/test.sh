#!/bin/sh
# Run the EDL test suite.
#
# Categories live in edl/tests/<category>/ and are aggregated by
# edl/tests/runner.edl (generated as runner.nim). End-to-end tests
# (edl/tests/compiler/) exercise the real compiler binary, whose path is passed
# through EDL_BIN.

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

# The end-to-end tests need the compiler itself. The compiler and the test
# runner both live as .edl sources and are compiled from the generated .nim tree
# in build/edl/src-gen (see build.sh). Until the compiler entry exists, the
# frontend unit tests still run: they exercise the lexer, parser and semantic
# passes directly, without going through the driver.
if [ -f "$root/edl/src/edlc.edl" ]; then
  "$root/edl/scripts/build.sh"
else
  echo "note: edl/src/edlc.edl does not exist yet; skipping the compiler build."
fi

gen="$root/build/edl/src-gen"
mkdir -p "$gen"

echo "building EDL test runner ..."
"$nim" c \
  --noNimblePath \
  --skipUserCfg \
  --skipParentCfg \
  --hints:off \
  --path:"$gen" \
  --nimcache:"$root/build/edl/nimcache-tests" \
  -o:"$root/build/edl/edl_tests" \
  "$gen/runner.nim"

echo "running EDL tests ..."
EDL_BIN="$root/build/edl/edlc" EDL_BOOTSTRAP="$nim" "$root/build/edl/edl_tests"