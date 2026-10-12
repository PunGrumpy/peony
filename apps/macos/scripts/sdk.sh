#!/bin/bash
# Prints the newest macOS SDK whose SwiftUI works without Xcode's macro plugins.
# Command Line Tools can ship an SDK where @State is a macro only Xcode can expand.
set -euo pipefail
probe="$(mktemp -d)/probe.swift"
printf '%s\n' 'import SwiftUI' 'struct Probe: View {' '  @State private var on = false' \
  '  var body: some View { Toggle("", isOn: $on) }' '}' > "$probe"
sdks="$(dirname "$(xcrun --show-sdk-path)")"
for sdk in $(ls -d "$sdks"/MacOSX[0-9]*.sdk | sort -rV); do
  if swiftc -sdk "$sdk" -typecheck "$probe" 2>/dev/null; then echo "$sdk"; exit 0; fi
done
xcrun --show-sdk-path
