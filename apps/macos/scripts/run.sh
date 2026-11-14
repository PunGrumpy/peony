#!/usr/bin/env bash
# Debug build, run from the terminal so logs go to stdout.
# It runs in its own home folder ($PEONY_DEV_HOME, default /tmp/peony-dev-<uid>)
# so the installed Peony keeps running. Pass --installed-home to stop the
# installed Peony and run against your real home instead.
set -euo pipefail
cd "$(dirname "$0")/.."

export SDKROOT="${SDKROOT:-$(scripts/sdk.sh)}"
swift build --product Peony

if [[ "${1:-}" == "--installed-home" ]]; then
  pkill -x Peony 2>/dev/null || true
  echo "Stopped the installed Peony. Debug Peony uses your real home."
else
  # Keep this path short: the control socket path must stay under 104 bytes.
  home="${PEONY_DEV_HOME:-/tmp/peony-dev-$(id -u)}"
  mkdir -p "$home"
  chmod 700 "$home"
  export CFFIXED_USER_HOME="$home"
  echo "Debug Peony keeps its VPNs in $home"
fi

exec "$(swift build --show-bin-path)/Peony"
