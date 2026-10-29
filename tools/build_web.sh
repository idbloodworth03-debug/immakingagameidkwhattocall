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
if [ "$STATUS" -ne 0 ]; then
  echo "Tests failed, so nothing was exported."
  exit "$STATUS"
fi

echo "== Exporting the web build to $OUT"
rm -rf "${OUT:?}"/*
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$OUT/index.html" >/dev/null 2>&1
test -f "$OUT/index.wasm" && test -f "$OUT/index.pck"
echo "== Done: $(du -sh "$OUT" | cut -f1)"
