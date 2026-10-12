#!/usr/bin/env bash
# Renders every panel state, light and dark, into Design/snapshots.
set -euo pipefail
cd "$(dirname "$0")/.."

export SDKROOT="${SDKROOT:-$(scripts/sdk.sh)}"
swift run peony-snapshots panels Design/snapshots
