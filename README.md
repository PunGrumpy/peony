<p align="center"><img src="apps/macos/Design/AppIcon-1024.png" width="128" alt=""></p>

<h1 align="center">Peony</h1>

<p align="center">One VPN at a time, from the menu bar.</p>

<p align="center"><img src="apps/macos/Design/snapshots/panel-live-light.png" width="340" alt="Peony's panel, connected to a VPN, with reachable hosts listed"></p>

Peony switches between your VPNs (FortiGate, Cisco AnyConnect, GlobalProtect, Pulse, F5, WireGuard and NetBird) and keeps only one on, so their routes and DNS never fight. Once a tunnel is up, it checks the hosts you care about, so "connected" means you can actually reach GitLab.

## Install

```sh
brew install --cask pungrumpy/tap/peony
```

Peony isn't notarized yet, so the first time you open it, go to **System Settings › Privacy & Security** and click **Open Anyway**.

Peony drives the open-source clients. Install the ones you need (Settings › General shows what's missing):

| VPN | Client |
| --- | --- |
| FortiGate SSL-VPN | `brew install openfortivpn` |
| AnyConnect, GlobalProtect, Pulse, F5, Array | `brew install openconnect` |
| WireGuard | `brew install wireguard-tools` |
| NetBird | [NetBird's installer](https://docs.netbird.io/how-to/installation) |

## Use

1. Click the flower in the menu bar, then **Add VPN**.
2. Pick the kind, fill in what your admin gave you, and list a few hosts to check.
3. Click a route (or press <kbd>⌘1</kbd>–<kbd>⌘9</kbd>). Peony turns any other VPN off first.

The menu bar shows the VPN's name while it's on. The flower blooms while connecting.

The first connection asks for an admin password once, to install Peony's helper.

## How it works, and what runs as root

Setting routes and DNS needs root, so Peony installs a small helper, `/Library/PrivilegedHelperTools/app.peony.helper`, plus a sudoers rule (`/etc/sudoers.d/peony`) that lets your account run it without a password. The helper:

- takes one JSON request on stdin, never secrets in arguments;
- validates every field before it reaches a config file or a command line, rejecting line breaks, option-like values and WireGuard `PostUp`/`PreDown` hooks (which would run as root);
- only executes clients from Homebrew's `bin` directories;
- writes generated configs to a root-only directory and deletes FortiGate's as soon as openfortivpn has read it.

Passwords and WireGuard configs live in your Keychain. VPN settings live in `~/Library/Application Support/Peony/profiles.json`.

Remove everything with `brew uninstall --zap peony`, or **Settings › General › Helper › Uninstall**.

## Develop

Everything builds with the Command Line Tools; no Xcode needed. [Turborepo](https://turborepo.dev) runs the tasks, with [Bun](https://bun.sh) as the package manager.

```sh
bun install
bun run dev           # debug build of the app, plus the site on localhost:3000
bun run test          # core tests: validation, parsers, helper safety
bun run build         # universal release build of Peony.app, and the site
bun run install-app   # build, copy to /Applications, relaunch
bun run package       # .dmg, .zip, SHA256SUMS and the Homebrew cask in apps/macos/dist/
bun run snapshots     # render every panel state, light and dark, into Design/snapshots
bun run icon          # regenerate the app icon from the PeonyMark shape
```

| Path | What |
| --- | --- |
| `packages/core` | Profiles, validation, log parsers, reachability. Shared with the helper; has the tests. |
| `apps/macos/Sources/PeonyUI` | Every panel view, driven by plain values (`PanelState`), plus the brand: palette, type, the mark. |
| `apps/macos/Sources/Peony` | The app: profile store, Keychain, the connection, settings. |
| `apps/macos/Sources/peony-helper` | The root helper. |
| `apps/macos/Sources/peony-snapshots` | Renders panels and the icon for design review. |
| `apps/web` | The site (Next.js). It shows the panel snapshots straight from `apps/macos/Design`. |

Add `--filter=@peony/macos` or `--filter=web` to run a task for one of them, e.g. `bun run dev --filter=web`.

The version lives in `apps/macos/package.json`. To release, bump it, add the version's notes to `apps/macos/CHANGELOG.md` (the site's changelog and the GitHub release both read them), then push a `v<version>` tag: a workflow builds the app and publishes the `.dmg`, and [the tap](https://github.com/PunGrumpy/homebrew-tap) picks the new version up within the hour.

The look follows [Orchid](https://orchid.ai/brand): a serif for headlines (New York), the system sans for reading, mono for labels and numbers, ink on paper with a single rose accent.

## License

MIT
