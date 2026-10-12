#!/usr/bin/env bash
# Runs the core tests. Command Line Tools sometimes builds the tests without the Swift Testing
# macro plugin and fails to expand @Test, so point swiftc at it when the toolchain has one.
set -euo pipefail
cd "$(dirname "$0")/.."

plugins="$(dirname "$(dirname "$(xcrun --find swiftc)")")/lib/swift/host/plugins/testing"
flags=()
if [[ -d "$plugins" ]]; then flags=(-Xswiftc -plugin-path -Xswiftc "$plugins"); fi
swift test ${flags[@]+"${flags[@]}"} "$@"
