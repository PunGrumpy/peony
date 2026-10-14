# Security Policy

Peony installs a helper that runs as root, so a bug in it matters more than a bug in most menu bar apps. Reports are welcome and taken seriously.

## Reporting a vulnerability

Please don't open a public issue. Report it privately through [GitHub Security Advisories](https://github.com/PunGrumpy/peony/security/advisories/new).

Include what you can of:

- the Peony version, and your macOS version;
- the request or input that triggers the problem;
- what the helper or the app did, and what you expected it to refuse;
- whether it needs an account on the Mac, or can be triggered another way.

Peony is maintained by one person in spare time. You'll get a reply as soon as that allows, and credit in the release notes if you'd like it.

## What counts

Anything that lets someone do more than Peony intends, especially:

- getting the root helper to run a command, read a file, or write a file it shouldn't;
- a value that passes validation and reaches a config file or a command line as an option or a second line;
- a password, key, or WireGuard config left on disk, in a log, or in a process's arguments;
- a way around the checks on which VPN clients the helper will execute.

The helper's rules are described in the [README](https://github.com/PunGrumpy/peony#how-it-works-and-what-runs-as-root) and tested in `packages/core`.

## What doesn't

- Bugs in openfortivpn, openconnect, wireguard-tools, NetBird, or Tailscale. Please report those to their projects.
- Anything that needs root or your login password to begin with.
- The app not being notarized yet. That's known, and the README says how to open it.

## Supported versions

Only the [latest release](https://github.com/PunGrumpy/peony/releases/latest) gets fixes.
