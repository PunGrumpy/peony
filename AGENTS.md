# Peony

Peony is a macOS menu bar app that keeps one VPN on at a time. `apps/macos` holds the app, its panel views, the root helper, the `peony` command and the snapshot renderer. `packages/core` holds profiles, validation, log parsers and reachability, shared with the helper, and every unit test. `apps/web` is the site, and it shows the panel snapshots from `apps/macos/Design`.

## Never do this

The installed Peony holds the live VPN of whoever runs you. Some of those VPNs sign in through a browser, which a script cannot redo.

- Don't start, stop, restart or reconfigure the installed Peony. `peony connect` and `peony disconnect`, and the `peony` MCP tools that wrap them, open it when nothing answers on the socket.
- Don't run `apps/macos/scripts/install-app.sh` or `bun run install-app`. It stops the installed Peony, replaces `/Applications/Peony.app` and relaunches it.
- Don't pass `--installed-home` to `apps/macos/scripts/run.sh`. It runs `pkill -x Peony`.
- Don't run `sudo`, accept the administrator prompt, or start a real VPN client to prove a change. They change the Mac's routes and DNS.
- Don't give a debug app a FortiGate, OpenConnect or OpenVPN profile. It adopts a running tunnel of any kind it holds a profile for at launch, and can then stop it (`Connection.adopt`). Test profiles are Tailscale and NetBird only, and only with the stand-in clients `e2e.sh` writes.
- Don't add a fallback to a real client in the `PEONY_TOOLS_DIR` hook (`apps/macos/Sources/Peony/Daemon.swift`). With it set, its folder is the whole world, so a test can't run a real `tailscale down`.
- Don't edit `apps/macos/CHANGELOG.md` or the version in `apps/macos/package.json`, and don't merge the "Version Packages" pull request. The release workflow owns them.
- Don't report a security problem in the root helper as a public issue or pull request. Follow `.github/SECURITY.md`.

## Prove a change

- To run the app, use `apps/macos/scripts/run.sh` (the same as `bun run dev --filter=@peony/macos`). It runs a debug build in its own home, `/tmp/peony-dev-<uid>`, and leaves the installed Peony running. Without `--filter`, `bun run dev` also starts the site.
- To test a change to the core, run `bun run test`, or `packages/core/scripts/test.sh --filter <Suite>` for one suite. Every unit test lives in `packages/core`. The app and UI targets have no test target. If only `two stops join and interrupt once` in `TunnelProcessTests` fails, run the suite again, because it is flaky under load.
- To test a change to the app (`Connection.swift` and the rest of `apps/macos/Sources/Peony`), run `bun run e2e`. It drives a real connect, switch and disconnect through the debug app and `peony`, against stand-in Tailscale and NetBird clients in a temp home. It needs `jq`.
- If you write your own driver, keep a temp home short, under `/tmp`, never `$TMPDIR`. The control socket path must stay under 104 bytes (`packages/core/Sources/PeonyCore/Control.swift`), and `run.sh` refuses a home over 56 bytes.
- `CFFIXED_USER_HOME` moves the VPN list and the control socket, but not preferences. An unbundled debug binary keeps its `UserDefaults` in the real `~/Library/Preferences/<executable name>.plist`, so `e2e.sh` runs a copy named `PeonyE2E`.
- In a driver, send only `peony status` until the app you started has answered. `status` and `list` never open Peony, and `connect` and `disconnect` do. Stop any `connect` you left running before the app exits, or it opens the installed one.
- To check a change to a panel or to Settings, run `bun run snapshots`. Commit only the images whose pixels your change affects. A render can, rarely, change `panel-off-light.png` for no known reason. If an image changes that your change can't explain, restore it and render again.
- Build without Xcode. The scripts pick an SDK with `apps/macos/scripts/sdk.sh`. For a bare `swift build` or `swift run`, set `SDKROOT="$(scripts/sdk.sh)"` from `apps/macos`.
- Check a claim about what a VPN client prints against that client's source, not from memory. A test here once leaned on an openfortivpn line that it prints only at INFO level.
- To check a change to a `Brand` colour in `apps/macos/Sources/PeonyUI/Theme.swift`, run `swift run peony-snapshots contrast` from `apps/macos`. It exits 1 when a text pair is under 4.5 to 1.
- Prove it on the code you changed. A release binary built before your change proves nothing about it.

A person has to check a real VPN, the administrator prompt, a browser sign-in, VoiceOver and the installed app. Say in the pull request that you did not, and what else you left unchecked.

## Ship a change

- Keep a pull request to one change.
- Title it `type: Capitalized subject`, with no scope. The types are `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `style`, `ci` and `chore`, and `lint-pr-title.yml` enforces them. For example, `fix: Keep the installed Peony running during bun run dev`.
- Don't add a label. `label-pr.yml` sets one from the title: `feat` is `enhancement`, `fix` is `bug`, `docs` is `documentation`, `perf` is `performance`, and `test`, `ci`, `chore`, `refactor` and `style` are `maintenance`. If a change improves accessibility, say so in the description, and someone with triage access adds `accessibility`.
- Write the body to `.github/pull_request_template.md`. It has a `### Description` and a `### Testing Instructions`. Name the kind of VPN you connected, or say you connected none.
- If people will notice the change in the app, add a changeset with `bun changeset`, for `@peony/macos` only. `@peony/core` and `web` are ignored in `.changeset/config.json`.
- If you change what the root helper accepts, validate it in `packages/core` and add a test that shows what it refuses. If you change the helper's behaviour, raise `Helper.version` (`packages/core/Sources/PeonyCore/Helper.swift`) so the app reinstalls it.
- If you change a panel or Settings, include the new snapshots, and a screenshot in the pull request.
- Don't widen the control socket without a security review. It reads status, connects a VPN by name and disconnects, and nothing else.

<!-- BEGIN:turborepo-agent-rules -->

# This is NOT the Turborepo you know

Turborepo configuration, task behavior, and CLI commands can vary between installed versions and may differ from your training data. Resolve the `turbo` package from this file's directory or relevant workspace; in monorepos, it may not be visible from the repository root. For example, run `node -p "require.resolve('turbo/package.json')"` from a workspace that depends on `turbo`.

Read `docs/README.md` inside that installed package first, then read the relevant pages from its `docs/` directory before changing Turborepo configuration or commands. Heed deprecation notices. These bundled docs match the installed package version and are available without network access.

This block is written and re-added by `turbo` before repository-scoped commands when an AI agent is detected. In the Turborepo source repository, its template is defined in `crates/turborepo-cli/src/cli/agent_guidance.rs`. Removing the managed block while updates are enabled means a later qualifying invocation will add it again. Set `"agentGuidance": false` in the root `turbo.json` or `turbo.jsonc` to opt out; this does not remove an existing block. Keep the block committed with your work to avoid an uncommitted change on the next agent invocation.
<!-- END:turborepo-agent-rules -->
