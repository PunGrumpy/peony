#!/usr/bin/env bash
# Builds build/Peony.app with Command Line Tools alone. Set CODESIGN_IDENTITY for a
# Developer ID build.
set -euo pipefail
cd "$(dirname "$0")/.."

export SDKROOT="${SDKROOT:-$(scripts/sdk.sh)}"
# The version lives in package.json; the build number is the commit count.
VERSION="$(sed -n 's/^  "version": "\(.*\)",$/\1/p' package.json)"
APP=build/Peony.app
ARCHS=(${ARCHS:-arm64 x86_64})

swift build -c release $(printf -- '--arch %s ' "${ARCHS[@]}") --product Peony
swift build -c release $(printf -- '--arch %s ' "${ARCHS[@]}") --product peony-helper
swift build -c release $(printf -- '--arch %s ' "${ARCHS[@]}") --product peony-cli
BIN="$(swift build -c release $(printf -- '--arch %s ' "${ARCHS[@]}") --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp "$BIN/Peony" "$APP/Contents/MacOS/Peony"
cp "$BIN/peony-helper" "$APP/Contents/Helpers/peony-helper"
# Helpers, not MacOS: there `peony` would collide with `Peony` on a case-insensitive disk.
cp "$BIN/peony-cli" "$APP/Contents/Helpers/peony"
# Outside Xcode, SwiftPM records the deployment target as the SDK. macOS reads that number to
# pick the look, so Peony would get the old window chrome. Record the SDK it was built with.
MINOS="$(vtool -arch arm64 -show-build "$APP/Contents/MacOS/Peony" | awk '/minos/ { print $2; exit }')"
SDK_VERSION="$(xcrun --sdk "$SDKROOT" --show-sdk-version)"
vtool -set-build-version macos "$MINOS" "$SDK_VERSION" -replace -output "$APP/Contents/MacOS/Peony" "$APP/Contents/MacOS/Peony"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(git rev-list --count HEAD 2>/dev/null || echo 1)" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Developer ID builds get the hardened runtime and a timestamp, which notarization needs.
# Without one the app is signed ad-hoc and opens after Gatekeeper's Open Anyway.
codesign=(codesign --force --sign "${CODESIGN_IDENTITY:--}")
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then codesign+=(--options runtime --timestamp); fi
# Sign the nested helpers first, since signing the bundle seals their hashes.
"${codesign[@]}" "$APP/Contents/Helpers/peony-helper"
"${codesign[@]}" "$APP/Contents/Helpers/peony"
"${codesign[@]}" "$APP"
echo "Built $APP ($VERSION)"
