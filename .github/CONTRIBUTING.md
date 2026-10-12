# Contributing to Peony

Thanks for wanting to help. Peony is a small project, so the process is short.

## Before you start

- For a bug, [search the issues](https://github.com/PunGrumpy/peony/issues) first, then open one with the bug report form.
- For a new feature or another kind of VPN, open a feature request before writing code, so we can agree on the shape.
- For a security problem, follow the [security policy](SECURITY.md) instead of opening an issue.

## Set up

Everything builds with the Command Line Tools; you don't need Xcode. You need [Bun](https://bun.sh).

```sh
bun install
bun run dev --filter=@peony/macos   # debug build of the app
bun run dev --filter=web            # the site, on localhost:3000
bun run test                        # core tests: validation, parsers, helper safety
```

The [README](../README.md#develop) lists every task and what lives where.

## Making a change

- Keep a pull request to one change. Small ones are reviewed sooner.
- Anything the root helper accepts is validated in `packages/core`. If you change what it accepts, add a test that shows what it now refuses.
- If you change a panel, run `bun run snapshots` and commit the new images. The site shows them.
- If people will notice the change in the app, run `bun changeset` and commit the file it writes. That text becomes the changelog entry.

## Pull requests

Titles follow [Conventional Commits](https://www.conventionalcommits.org) with a capitalized subject and no scope, for example `fix: Keep the tunnel up when the lid closes`. A check enforces it. The allowed types are `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `style`, `ci`, and `chore`.

Fill in the pull request template: what changed, and how you tested it. For the macOS app, say which kind of VPN you connected to.

## License

By contributing, you agree that your work is released under the [MIT License](../LICENSE).
