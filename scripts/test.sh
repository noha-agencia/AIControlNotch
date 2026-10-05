#!/usr/bin/env bash
# Runs the test suite. With Xcode, plain `swift test` works. Command Line Tools ship
# Testing.framework outside the default search path, so point the compiler and
# linker at it; their _Testing_Foundation overlay has no Swift module, so
# cross-import overlays are disabled (Foundation + Testing would otherwise fail to import).
set -euo pipefail
cd "$(dirname "$0")/.."

DEVELOPER_DIR_PATH="$(xcode-select -p)"
if [[ "$DEVELOPER_DIR_PATH" != *CommandLineTools* ]]; then
    exec swift test "$@"
fi

FW="$DEVELOPER_DIR_PATH/Library/Developer/Frameworks"
swift test \
    -Xswiftc -F -Xswiftc "$FW" \
    -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
    -Xlinker -F -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$FW" \
    "$@"
