# Security model

This file describes who and what peony trusts, so security reviews and scans judge findings against it. To report a vulnerability, see `.github/SECURITY.md`.

## System overview

Peony is a macOS menu-bar VPN manager that keeps one VPN on at a time. `apps/macos` holds the app, the root helper `peony-helper`, the `peony` CLI (with MCP) and the snapshot renderer; `packages/core` holds validation shared with the helper. See also `.github/SECURITY.md` for what counts as a vulnerability.

## Components

| Component | Code | Distribution surface |
| --- | --- | --- |
| peony | `apps/macos` (app, `peony-helper`, `peony-cli` incl. MCP), `packages/core` | macOS app |
| CI/release | `.github/workflows/*` | macOS app |

## Assets

- Root privileges, routes and DNS on Macs running Peony.
- VPN passwords, keys and configs in the Keychain and the helper's run directory.
- Integrity of the released app and Homebrew cask.

Critical assets across the maintainer's projects, in the maintainer's words: secrets in CI of action users (Cursor API key, `GITHUB_TOKEN`); root privileges and network config on Macs running Peony; integrity of published npm packages and releases; pigo API availability; and the data of downstream apps that use the libraries (logs, vectors, LINE messages).

## Trust boundaries and entry points

- **User-level app → root helper**: `peony-helper` is installed root:wheel 0755 at `/Library/PrivilegedHelperTools/app.peony.helper`, with a sudoers rule `user ALL=(root) NOPASSWD: <helper>` that accepts any argument. Any same-user process can run it as root, so the helper's own validation of arguments, configs and which VPN tools it executes is the root boundary.
- **Helper → VPN clients**: runs openfortivpn, openconnect, wg-quick and openvpn with arguments and configs built from requests; configs are written under a 0700 run directory.
- **Control socket**: `ControlServer.swift` serves the `peony` CLI and MCP (status, connect by name, disconnect).

## Attackers that matter

- Another local process or user on the same Mac. The maintainer did not rule local attackers out.
- A supply-chain attacker targeting the release workflow.

## Existing controls

- The helper refuses to run unless root (except `version`).
- Files are opened with `O_NOFOLLOW`, mode 0600, in a 0700 directory.
- A username allowlist runs before the sudoers rule is written, and the rule is checked with `visudo -cf`.
- What the helper accepts is validated and tested in `packages/core`.

## Out of scope

- `apps/web` (project site).
- Per `.github/SECURITY.md`: bugs in the VPN clients themselves, and anything that already needs root or the login password.
- Across the maintainer's projects: docs and marketing sites, and bench and video packages.
