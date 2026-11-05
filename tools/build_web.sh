#!/usr/bin/env bash
# Builds the web version of Den Duel into the folder given as the first
# argument (default: build/web). Runs the tests first and stops if any fail.
#
#   GODOT=/path/to/godot tools/build_web.sh build/web
#
# Used by .github/workflows/web.yml, and works the same on your own computer.
set -euo pipefail

GODOT="${GODOT:-godot}"
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mkdir -p "${1:-build/web}" && cd "${1:-build/web}" && pwd)"

echo "== Installing web export templates"
python3 "$ROOT/tools/fetch_web_templates.py" "$GODOT_VERSION"

echo "== Importing assets"
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true

echo "== Running tests"
LOG="$(mktemp)"
set +e
"$GODOT" --headless --path "$ROOT/game" res://tests/test_runner.tscn >"$LOG" 2>&1
STATUS=$?
set -e
grep -E "FAIL|tests,|SCRIPT ERROR|^\s+- " "$LOG" || true
if [ "$STATUS" -ne 0 ] || grep -q "SCRIPT ERROR" "$LOG"; then
  echo "Tests failed or a script has errors, so nothing was exported."
  exit 1
fi

python3 "$ROOT/tools/check_release.py" >/dev/null || echo "!! Testing switches are on (endless gold, gems and Acorns...): fine for testing, not for a real release. See tools/check_release.py."

# Which build this is, shown small in a corner of the main menu and the
# profile: the build number (BUILD_NUMBER: the GitHub Actions run) and the
# commit.
BUILD_NUMBER="${BUILD_NUMBER:-local}"
COMMIT="$(git -C "$ROOT" rev-parse --short=7 HEAD 2>/dev/null || echo unknown)"
printf '{"build": "%s", "commit": "%s"}\n' "$BUILD_NUMBER" "$COMMIT" > "$ROOT/game/build.json"
echo "== Build $BUILD_NUMBER, commit $COMMIT"

echo "== Exporting the web build to $OUT"
rm -rf "${OUT:?}"/*
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$OUT/index.html" >/dev/null 2>&1
test -f "$OUT/index.wasm" && test -f "$OUT/index.pck"

# Godot's service worker serves every file from its cache first, which kept
# phones on old builds. Ours asks the network first (see the file).
test -f "$OUT/index.service.worker.js"
sed "s/___BUILD___/$BUILD_NUMBER-$COMMIT/" "$ROOT/tools/web/service_worker.js" > "$OUT/index.service.worker.js"
echo "== Done: $(du -sh "$OUT" | cut -f1)"
