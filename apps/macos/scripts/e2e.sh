#!/usr/bin/env bash
# Drives a real connect, switch and disconnect through the debug app and the
# `peony` command. The app runs in a temp home and finds its VPN clients only in
# a temp folder of stand-ins (PEONY_TOOLS_DIR, debug builds only), so no real
# tunnel is touched. Nothing outside the two temp folders is written except one
# preferences file, ~/Library/Preferences/PeonyE2E.plist, which is deleted on exit.
# macOS's Control Center also records the test app's menu bar item under trackedApplications in
# ~/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist;
# that entry is replaced on each run and never removed, and this script can't prevent it.
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
late=""
alpha=""

# The process with this PID is still the test app, not something that took the PID after it exited.
is_test_app() { [[ "$(ps -o comm= -p "$app" 2>/dev/null)" == *PeonyE2E ]]; }

cleanup() {
  # A second Ctrl-C must not cut this short and leave the app or the temp folders behind.
  trap '' INT TERM
  set +e
  # Before the app goes: a client that outlives it would run `open -g -b app.peony.Peony` and start the installed Peony.
  for pid in $late $alpha; do
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
  if [[ -n "$app" ]]; then
    is_test_app && kill "$app" 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      is_test_app || break
      sleep 0.25
    done
    is_test_app && kill -9 "$app" 2>/dev/null
    wait "$app" 2>/dev/null
  fi
  defaults delete PeonyE2E 2>/dev/null || true
  # `defaults delete` empties the domain but leaves a zero-key plist behind.
  rm -f "$HOME/Library/Preferences/PeonyE2E.plist"
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
  "up")
    [[ -e "$dir/tailscale.slow" ]] && sleep 2
    echo Running > "$state" ;;
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
  "up")
    # While netbird.hold exists, `up` waits like a client held on a browser sign-in, then takes a moment to return.
    held=""
    for _ in $(seq 200); do
      [[ -e "$dir/netbird.hold" ]] || break
      held=1
      sleep 0.1
    done
    [[ -z "$held" ]] || sleep 0.5
    echo true > "$state" ;;
  "down") rm -f "$dir/netbird.hold"; echo false > "$state" ;;
  *) exit 1 ;;
esac
EOF

chmod +x "$tools/tailscale" "$tools/netbird"
echo Stopped > "$tools/tailscale.state"
echo false > "$tools/netbird.state"
: > "$tools/calls.log"

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

# Preferences ignore CFFIXED_USER_HOME and are named after the executable. Under its own name the app would
# read and write the debug domain `Peony` (including globalShortcuts), so run a copy under a name of its own.
cp "$bin/Peony" "$tools/PeonyE2E"
defaults delete PeonyE2E 2>/dev/null || true
CFFIXED_USER_HOME="$home" PEONY_TOOLS_DIR="$tools" "$tools/PeonyE2E" > "$home/app.log" 2>&1 &
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

# connect and disconnect open the installed Peony when nothing answers, so never send one once the test app is gone.
require_test_app() {
  if ! kill -0 "$app" 2>/dev/null; then
    echo "e2e: the test app (pid $app) is gone, so nothing more is sent: connect would open the installed Peony. Its output:" >&2
    cat "$home/app.log" >&2
    exit 1
  fi
}

not_available() {
  echo "e2e: Peony isn't available (peony $* exited 3), so the run stops here. The app's output:" >&2
  cat "$home/app.log" >&2
  exit 1
}

drive() {
  require_test_app
  code=0
  seen="$(peony "$@" --json 2>&1)" || code=$?
  [[ "$code" != 3 ]] || not_available "$@"
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

# The gate: send connect and disconnect only to an app that is off and holds exactly the two test VPNs.
# If CFFIXED_USER_HOME stopped redirecting the socket or the VPN list, this would be the installed Peony.
only_the_test_app='.tunnel.state == "off" and ([.vpns[].id] == ["00000000-0000-0000-0000-0000000000A1","00000000-0000-0000-0000-0000000000B2"])'
drive status
if ! reply 0 "$only_the_test_app"; then
  echo "e2e: the app on the socket isn't the test app, so nothing else is sent. status exited $code and said:" >&2
  sed 's/^/     /' <<<"$seen" >&2
  exit 1
fi
check "the tunnel starts off" reply 0 "$only_the_test_app"

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

# NetBird is held on a sign-in and Tailscale is slow, so NetBird's `up` returns while Alpha is still connecting.
# Both clients start directly, not through `peony`: through the function $! would be a subshell, and killing it leaves peony-cli running.
touch "$tools/netbird.hold" "$tools/tailscale.slow"
ups="$(called "netbird up")"
require_test_app
CFFIXED_USER_HOME="$home" "$bin/peony-cli" connect Beta --timeout 15 --json > "$home/late.json" 2>&1 &
late=$!
for _ in $(seq 100); do
  [[ "$(called "netbird up")" -gt "$ups" ]] && break
  kill -0 "$late" 2>/dev/null || break
  sleep 0.1
done

# `peony connect` only looks once its own connect has finished, so a failure shown in between is
# visible to the panel and `peony status` alone.
require_test_app
CFFIXED_USER_HOME="$home" "$bin/peony-cli" connect Alpha --timeout 15 --json > "$home/alpha.json" 2>&1 &
alpha=$!
failed_meanwhile=""
while kill -0 "$alpha" 2>/dev/null; do
  drive status
  reply 0 '.tunnel.state == "failed"' && failed_meanwhile="$seen"
  sleep 0.1
done

alpha_code=0
wait "$alpha" || alpha_code=$?
alpha=""
late_code=0
wait "$late" || late_code=$?
late=""
rm -f "$tools/netbird.hold" "$tools/tailscale.slow"

code=$alpha_code
seen="$(<"$home/alpha.json")"
[[ "$code" != 3 ]] || not_available connect Alpha
check "picking Alpha while NetBird is still connecting leaves Alpha on" \
  reply 0 '.outcome == "done" and .tunnel.state == "on" and .tunnel.vpn.name == "Alpha"'

code=0
seen="$failed_meanwhile"
check "Alpha never shows a failure while it connects" [ -z "$failed_meanwhile" ]

code=$late_code
seen="$(<"$home/late.json")"
[[ "$code" != 3 ]] || not_available connect Beta
check "the replaced connect to Beta is interrupted by the other request" reply 6

drive disconnect
check "disconnect after the late NetBird returned turns everything off" \
  reply 0 '.tunnel.state == "off"'

if (( failures > 0 )); then
  echo "e2e: $failures of 11 checks failed. The stand-ins were called with:" >&2
  sed 's/^/     /' "$tools/calls.log" >&2
  exit 1
fi
echo "e2e: all checks passed"
