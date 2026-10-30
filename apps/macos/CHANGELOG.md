# @peony/macos

## 0.2.0

### Minor Changes

- 0c916ef: Drive Peony from scripts and AI agents with the new `peony` command: `peony list`, `peony status`, `peony connect <name>` and `peony disconnect`, with `--json` output and exit codes that say what happened. `connect` waits until the VPN is on and your hosts are checked, and Peony stays the only thing that starts or stops a tunnel.
- 5bc1621: Let AI agents such as Claude Code, Codex and Cursor list, connect and disconnect your VPNs as native tools: add `peony mcp` to the agent as an MCP server.
- 7263f39: Sign in to FortiGate VPNs that use single sign-on, such as Microsoft Entra, in a browser window. Choose "Browser (SSO)" in the VPN's settings; Peony opens the sign-in page when you connect and remembers your session, so multi-factor prompts stay rare.
- 3df39e9: Settings now looks and behaves like a Mac settings window. It follows your accent color, and adding a VPN opens a sheet whose Add button turns on once the form is complete. Problems show under the field they're about as you type. Changes to a VPN stay put when you look at another pane, marked Edited until you Save or Revert. Optional fields sit under Advanced, and a missing tool shows up with an Install button where you pick the VPN type. You can drop a configuration file onto the editor, and Peony tells you when it can't read one.
  
  A new Agents pane lets you turn agent control off, so `peony` answers "Agents can't control Peony right now" and exits 3. It also adds Peony to Claude Code, Codex or Cursor, or copies the command so you can run it yourself.

## 0.1.2

### Patch Changes

- bcbac8c: If Peony can't read your VPN list, it keeps the file as `profiles-unreadable-<number>.json` in `~/Library/Application Support/Peony` instead of replacing it with an empty list the next time you save.
- 35efc69: Peony checks the hosts you listed for FortiGate, AnyConnect, GlobalProtect and OpenVPN connections too, not only WireGuard, NetBird and Tailscale. Disconnect now turns off a tunnel Peony found already running when it opened.
- 9ee517d: If macOS won't save a password or config to your Keychain, Settings now says so straight away, instead of the next connection failing with "doesn't have a password yet".
- cbecc9f: `brew uninstall peony` now removes Peony's helper and its sudoers rule too, so no root access is left behind. `--zap` still also removes your VPN list and preferences.

## 0.1.1

### Patch Changes

- 8466d67: Routes and reachable hosts now sit together in one rounded group, like System Settings, and the highlight slides to the route you pick. Open at login is a switch. The Settings sidebar highlights in Peony's own style instead of the Mac's blue, gives each VPN an icon, and marks the connected one with a rose dot. Each pane opens with its icon and name.
- d7dd5de: Peony uses less CPU and battery. It hears about network changes from macOS instead of checking every two seconds, stops waking for reachability checks that already finished, and no longer freezes the menu bar while it checks the helper. The log window keeps following new output after its first 500 lines.
- 2d616a4: Settings uses the Mac's own sidebar again, now highlighted in pink unless you picked an accent colour in System Settings. Each pane's name shows in the title bar instead of a large header. A new VPN's kind is picked from a standard menu. Peony now draws with the current macOS look, where it was falling back to the old one.
- 5b53967: Peony connects to OpenVPN servers with the .ovpn file your admin gave you, and refuses any line in it that would run a script or open a file as root.
- ab1649f: The panel opens right under the menu bar again, instead of sometimes hanging well below it.
- c1bebd4: The panel shrinks to fit when its content gets shorter, so it no longer hangs below the menu bar with empty space above it.
- b2204d1: Refresh the panel's look and motion. State changes blur from one to the next instead of snapping. The flower breathes while a VPN connects. Cards and buttons stay visible in dark mode. A failed connection no longer shows the Log button twice.
- 0c80243: Peony connects to Tailscale through its Mac app or Homebrew client, and turns it off when you switch to another VPN.

## 0.1.0

### Minor Changes

- ec38c2f: Peony connects to FortiGate, AnyConnect, GlobalProtect, Pulse, F5, WireGuard and NetBird through their open-source clients. Click a route or press **⌘1** to **⌘9**, and Peony turns any other VPN off first.
- ec38c2f: Once a tunnel is up, Peony checks the hosts you listed and shows how long each took to answer, so "connected" means you can reach them.
- ec38c2f: The menu bar shows the VPN's name while it's on, and the flower blooms while it connects.
- ec38c2f: When a tunnel won't come up, Peony says why in a sentence and offers the fix: trust the server's certificate, install the helper, or install the missing client.
- ec38c2f: Passwords and WireGuard configs are stored in your Keychain. A small root helper sets routes and DNS, and it validates every field it is sent.
