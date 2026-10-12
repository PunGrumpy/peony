# @peony/macos

## 0.1.0

The first release. Peony switches between your VPNs from the menu bar and keeps only one on, so their routes and DNS never fight.

### Minor Changes

- Peony connects to FortiGate, AnyConnect, GlobalProtect, Pulse, F5, WireGuard and NetBird through their open-source clients. Click a route or press **⌘1** to **⌘9**, and Peony turns any other VPN off first.
- Once a tunnel is up, Peony checks the hosts you listed and shows how long each took to answer, so "connected" means you can reach them.
- The menu bar shows the VPN's name while it's on, and the flower blooms while it connects.
- When a tunnel won't come up, Peony says why in a sentence and offers the fix: trust the server's certificate, install the helper, or install the missing client.
- Passwords and WireGuard configs are stored in your Keychain. A small root helper sets routes and DNS, and it validates every field it is sent.
