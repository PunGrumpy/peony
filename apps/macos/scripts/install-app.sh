#!/usr/bin/env bash
# Copies build/Peony.app to /Applications and relaunches it. Run scripts/build-app.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Peony.app
[[ -d "$APP" ]] || { echo "No $APP. Run scripts/build-app.sh first." >&2; exit 1; }

pkill -x Peony 2>/dev/null || true
rm -rf /Applications/Peony.app
cp -R "$APP" /Applications/
open /Applications/Peony.app
echo "Installed /Applications/Peony.app"
