#!/usr/bin/env bash
# Debug build, run from the terminal so logs go to stdout.
set -euo pipefail
cd "$(dirname "$0")/.."

export SDKROOT="${SDKROOT:-$(scripts/sdk.sh)}"
swift build --product Peony
pkill -x Peony 2>/dev/null || true
exec "$(swift build --show-bin-path)/Peony"
