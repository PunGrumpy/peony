# Changesets

Run `bun changeset` to describe a change to the macOS app. `bun run version` bumps `apps/macos/package.json` and writes the changelog; `scripts/build-app.sh` reads that version into `Info.plist`.
