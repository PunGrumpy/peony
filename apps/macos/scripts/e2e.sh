#!/usr/bin/env bash
# Drives a real connect, switch and disconnect through the debug app and the
# `peony` command. The app runs in a temp home and finds its VPN clients only in
# a temp folder of stand-ins (PEONY_TOOLS_DIR, debug builds only), so no real
# tunnel is touched and nothing outside the two temp folders is written.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null || { echo "e2e: jq is needed to read the replies." >&2; exit 1; }

export SDKROOT="${SDKROOT:-$(scripts/sdk.sh)}"
swift build --product Peony
swift build --product peony-cli
bin="$(swift build --show-bin-path)"

# Short on purpose: the control socket path must stay under 104 bytes, and $TMPDIR is too long.
home="$(mktemp -d /tmp/peony-e2e.XXXXXX)"
tools="$(mktemp -d /tmp/peony-e2e-tools.XXXXXX)"
app=""

cleanup() {
  set +e
  if [[ -n "$app" ]]; then
    kill "$app" 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      kill -0 "$app" 2>/dev/null || break
      sleep 0.25
    done
    kill -9 "$app" 2>/dev/null
    wait "$app" 2>/dev/null
  fi
  rm -rf "$home" "$tools"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# One `case` per argument, so a scenario that needs a new behaviour adds one line.
cat > "$tools/tailscale" <<'EOF'
#!/bin/bash
dir="${0%/*}"
echo "tailscale $*" >> "$dir/calls.log"
state="$dir/tailscale.state"
case "$*" in
  "status --json") printf '{"BackendState":"%s","Self":{"TailscaleIPs":["100.64.0.1"]}}\n' "$(cat "$state")" ;;
  "up") echo Running > "$state" ;;
  "down") echo Stopped > "$state" ;;
  *) exit 1 ;;
esac
EOF

cat > "$tools/netbird" <<'EOF'
#!/bin/bash
dir="${0%/*}"
echo "netbird $*" >> "$dir/calls.log"
state="$dir/netbird.state"
case "$*" in
  "status --json") printf '{"management":{"connected":%s},"netbirdIp":"100.92.0.2/16"}\n' "$(cat "$state")" ;;
  "up") echo true > "$state" ;;
  "down") echo false > "$state" ;;
  *) exit 1 ;;
esac
EOF

chmod +x "$tools/tailscale" "$tools/netbird"
echo Stopped > "$tools/tailscale.state"
echo false > "$tools/netbird.state"
: > "$tools/calls.log"

# With a stand-in missing the app would have nothing to run, so stop before it starts.
for tool in tailscale netbird; do
  if [[ ! -x "$tools/$tool" ]]; then
    echo "e2e: the stand-in $tools/$tool isn't executable, so the app has no client to run. Not starting it." >&2
    exit 1
  fi
done

# Only a Tailscale and a NetBird profile: the app adopts a running tunnel of a kind it has a profile for.
mkdir -p "$home/Library/Application Support/Peony"
cat > "$home/Library/Application Support/Peony/profiles.json" <<'EOF'
[
  {"destinations": [], "id": "00000000-0000-0000-0000-0000000000A1",
   "kind": {"tailscale": {}}, "name": "Alpha"},
  {"destinations": [], "id": "00000000-0000-0000-0000-0000000000B2",
   "kind": {"netBird": {"_0": {"managementURL": ""}}}, "name": "Beta"}
]
EOF

# Without CFFIXED_USER_HOME this would talk to the installed Peony.
peony() { CFFIXED_USER_HOME="$home" "$bin/peony-cli" "$@"; }

CFFIXED_USER_HOME="$home" PEONY_TOOLS_DIR="$tools" "$bin/Peony" > "$home/app.log" 2>&1 &
app=$!

# connect and disconnect open the installed Peony when nothing answers, so send nothing but status until it does.
ready=""
for _ in $(seq 120); do
  if peony status --json >/dev/null 2>&1; then ready=1; break; fi
  kill -0 "$app" 2>/dev/null || break
  sleep 0.25
done
if [[ -z "$ready" ]]; then
  socket="$home/Library/Application Support/Peony/control.sock"
  echo "e2e: the debug app never answered on $socket (${#socket} bytes). Its output:" >&2
  cat "$home/app.log" >&2
  exit 1
fi

code=0
seen=""
failures=0

drive() {
  code=0
  seen="$(peony "$@" --json 2>&1)" || code=$?
}

# reply <exit code> [jq filter]: the last reply exited with that code and its JSON satisfies the filter.
reply() {
  [[ "$code" == "$1" ]] || return 1
  [[ $# -lt 2 ]] || jq -e "$2" >/dev/null <<<"$seen"
}

called() { grep -c -x -- "$1" "$tools/calls.log" || true; }

# The first line of calls.log equal to $1 comes before the first equal to $2.
called_before() {
  awk -v a="$1" -v b="$2" '$0 == a && !x { x = NR } $0 == b && !y { y = NR } END { exit !(x && y && x < y) }' "$tools/calls.log"
}

check() {
  local what="$1"
  shift
  if "$@"; then
    echo "ok $what"
  else
    echo "FAIL $what (exit $code)"
    sed 's/^/     /' <<<"$seen"
    failures=$((failures + 1))
  fi
}

drive status
check "the tunnel starts off" reply 0 '.tunnel.state == "off"'

drive connect Alpha
check "connecting Alpha turns Tailscale on" \
  reply 0 '.outcome == "done" and .tunnel.state == "on" and .tunnel.vpn.name == "Alpha" and .tunnel.address == "100.64.0.1"'

drive connect Beta
check "connecting Beta switches to NetBird" \
  reply 0 '.outcome == "done" and .tunnel.state == "on" and .tunnel.vpn.name == "Beta" and .tunnel.address == "100.92.0.2"'

switched_off_first() {
  called_before "tailscale down" "netbird up" && [[ "$(<"$tools/tailscale.state")" == Stopped ]]
}
check "the switch turned Tailscale off before NetBird came up" switched_off_first

drive connect Beta
repeat_left_it_alone() {
  reply 0 '.outcome == "done"' && [[ "$(called "netbird up")" == 1 ]]
}
check "connecting Beta again doesn't restart NetBird" repeat_left_it_alone

drive disconnect
disconnected() {
  reply 0 '.tunnel.state == "off"' && [[ "$(<"$tools/netbird.state")" == false ]]
}
check "disconnect turns NetBird off" disconnected

drive connect Nope
check "an unknown name exits 4" reply 4

if (( failures > 0 )); then
  echo "e2e: $failures of 7 checks failed. The stand-ins were called with:" >&2
  sed 's/^/     /' "$tools/calls.log" >&2
  exit 1
fi
echo "e2e: all checks passed"
