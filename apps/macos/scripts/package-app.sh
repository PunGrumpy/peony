#!/usr/bin/env bash
# Packages build/Peony.app into dist/ as a .dmg for people, a .zip for updaters, and SHA256SUMS,
# then prints the Homebrew cask for pungrumpy/homebrew-tap. Run scripts/build-app.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Peony.app
OUT=dist
VERSION="$(sed -n 's/^  "version": "\(.*\)",$/\1/p' package.json)"
NAME="Peony-$VERSION"
[[ -d "$APP" ]] || { echo "No $APP. Run scripts/build-app.sh first." >&2; exit 1; }

rm -rf "$OUT" && mkdir -p "$OUT"
ditto -c -k --keepParent "$APP" "$OUT/$NAME.zip"
# The Applications link lets people drag the app across in the mounted window.
staging="$(mktemp -d)"
ditto "$APP" "$staging/Peony.app"
ln -s /Applications "$staging/Applications"
# hdiutil sometimes fails with "Resource busy" right after a build, so retry a few times.
for attempt in 1 2 3 4 5; do
  hdiutil create -quiet -ov -volname Peony -srcfolder "$staging" -format UDZO "$OUT/$NAME.dmg" && break
  [[ "$attempt" -lt 5 ]] || { echo "hdiutil could not create $OUT/$NAME.dmg." >&2; exit 1; }
  sleep "$attempt"
done
rm -rf "$staging"
(cd "$OUT" && shasum -a 256 "$NAME.dmg" "$NAME.zip" > SHA256SUMS)

SHA="$(shasum -a 256 "$OUT/$NAME.dmg" | cut -d' ' -f1)"
sed -e "s/@VERSION@/$VERSION/" -e "s/@SHA256@/$SHA/" Casks/peony.rb.in > "$OUT/peony.rb"
echo "Packaged $OUT/$NAME.dmg and $OUT/$NAME.zip; cask in $OUT/peony.rb"
