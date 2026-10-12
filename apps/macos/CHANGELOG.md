# @peony/macos

## 0.1.0

### Minor Changes

- ec38c2f: Peony connects to FortiGate, AnyConnect, GlobalProtect, Pulse, F5, WireGuard and NetBird through their open-source clients. Click a route or press **⌘1** to **⌘9**, and Peony turns any other VPN off first.
- ec38c2f: Once a tunnel is up, Peony checks the hosts you listed and shows how long each took to answer, so "connected" means you can reach them.
- ec38c2f: The menu bar shows the VPN's name while it's on, and the flower blooms while it connects.
- ec38c2f: When a tunnel won't come up, Peony says why in a sentence and offers the fix: trust the server's certificate, install the helper, or install the missing client.
- ec38c2f: Passwords and WireGuard configs are stored in your Keychain. A small root helper sets routes and DNS, and it validates every field it is sent.
