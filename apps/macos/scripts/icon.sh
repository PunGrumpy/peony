#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from the PeonyMark shape.
set -euo pipefail
cd "$(dirname "$0")/.."

export SDKROOT="${SDKROOT:-$(scripts/sdk.sh)}"
swift run peony-snapshots icon build/icon
iconutil -c icns build/icon/AppIcon.iconset -o Resources/AppIcon.icns
cp build/icon/AppIcon-1024.png Design/AppIcon-1024.png
