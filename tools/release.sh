#!/usr/bin/env bash
# One-command iterative deploy:  tools/release.sh 0.11.0 ["release notes"]
#   1. runs the full test suite (aborts on any failure)
#   2. stamps the version, exports Web + Windows + macOS into build/
#   3. tags the commit vX.Y.Z and pushes branch + tag to GitHub (nothing is ever lost)
#   4. publishes the web build to GitHub Pages (gh-pages branch) - the always-playable demo
#   5. creates a GitHub Release (pre-release until 1.0) with the downloadable builds
# Rollback: every release is a tag; `git checkout vX.Y.Z` + re-run gives the old build back.
set -euo pipefail
VERSION="${1:?usage: tools/release.sh X.Y.Z [notes]}"
NOTES="${2:-See CHANGELOG.md}"
GODOT="${GODOT:-$HOME/Desktop/Godot_v4.7.2.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== tests"
RESULT=$("$GODOT" --headless -s tests/run_tests.gd 2>&1 | grep -E "passed, [0-9]+ failed" | tail -1)
echo "$RESULT"
[[ "$RESULT" == *" 0 failed"* ]] || { echo "tests failed - aborting release"; exit 1; }

echo "== version $VERSION"
sed -i '' -E "s/(application\/(short_)?version=)\"[^\"]*\"/\1\"$VERSION\"/" export_presets.cfg
sed -i '' -E "s/(application\/(file|product)_version=)\"[^\"]*\"/\1\"$VERSION.0\"/" export_presets.cfg
sed -i '' -E "s/^config\/version=.*/config\/version=\"$VERSION\"/" project.godot

echo "== export"
rm -rf build/web build/windows build/mac && mkdir -p build/web build/windows build/mac && touch build/.gdignore
"$GODOT" --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1
"$GODOT" --headless --path . --export-release "Windows" build/windows/Shmittens.exe >/dev/null 2>&1
"$GODOT" --headless --path . --export-release "macOS" build/mac/Shmittens.zip >/dev/null 2>&1
rm -f build/web/*.import
(cd build && rm -f Shmittens-*.zip && zip -qr "Shmittens-$VERSION-windows.zip" windows && cp mac/Shmittens.zip "Shmittens-$VERSION-macos.zip" && zip -qr "Shmittens-$VERSION-web.zip" web)

echo "== tag + push"
git add -A
git commit -qm "Release v$VERSION" || true
git tag -a "v$VERSION" -m "v$VERSION: $NOTES"
BRANCH=$(git branch --show-current)
git push -q origin "$BRANCH" --tags

echo "== web demo -> GitHub Pages"
TMP=$(mktemp -d)
git worktree add -q "$TMP" gh-pages 2>/dev/null || git worktree add -q -b gh-pages "$TMP"
(cd "$TMP" && git rm -rqf . >/dev/null 2>&1 || true; cp -R "$ROOT/build/web/." . && touch .nojekyll && git add -A && git commit -qm "Web demo v$VERSION" && git push -q origin gh-pages)
git worktree remove --force "$TMP"

echo "== GitHub release"
PRE="--prerelease"; [[ "$VERSION" == 1.* ]] && PRE=""
gh release create "v$VERSION" build/Shmittens-$VERSION-*.zip --title "Shmittens! v$VERSION" --notes "$NOTES" $PRE
echo "done: v$VERSION"
