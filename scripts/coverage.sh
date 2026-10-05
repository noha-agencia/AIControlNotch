#!/usr/bin/env bash
# Line coverage for AIControlNotchCore (the app target and tap are thin shells).
set -euo pipefail
cd "$(dirname "$0")/.."

MINIMUM=90
./scripts/test.sh --enable-code-coverage >/dev/null
BIN="$(swift build --show-bin-path)"
PROFDATA="$BIN/codecov/default.profdata"
TESTS="$BIN/AIControlNotchPackageTests.xctest/Contents/MacOS/AIControlNotchPackageTests"

xcrun llvm-cov report "$TESTS" -instr-profile "$PROFDATA" \
    -ignore-filename-regex '(\.build|Tests|Sources/AIControlNotchApp|Sources/aicontrolnotch-tap)/'

TOTAL="$(xcrun llvm-cov export "$TESTS" -instr-profile "$PROFDATA" -summary-only \
    -ignore-filename-regex '(\.build|Tests|Sources/AIControlNotchApp|Sources/aicontrolnotch-tap)/' \
    | python3 -c 'import json,sys; print(round(json.load(sys.stdin)["data"][0]["totals"]["lines"]["percent"], 1))')"
echo "Core line coverage: $TOTAL% (minimum $MINIMUM%)"
python3 -c "import sys; sys.exit(0 if $TOTAL >= $MINIMUM else 1)" || { echo "✘ below the minimum" >&2; exit 1; }
