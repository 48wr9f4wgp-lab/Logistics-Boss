#!/usr/bin/env bash
# Every fixture gets a disposable profile: never load or overwrite player saves.
# Godot may return zero after a script error, so diagnostics are a failure gate.
set -euo pipefail
if [[ $# -eq 0 ]]; then
  echo "Usage: run_polish_checks.sh TEST_NAME [TEST_NAME ...]" >&2
  exit 2
fi
REPO=$(cd "$(dirname "$0")/../.." && pwd)
BIN=${GODOT_BIN:-"$REPO/build/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"}
OUT=${FLOTRA_TEST_LOG_DIR:-"$REPO/build/polish-evidence/checks"}
mkdir -p "$OUT"
for test in "$@"; do
  name=$(basename "$test" .gd)
  profile=$(mktemp -d "$REPO/build/test-$name.XXXXXX")
  mkdir -p "$profile/data" "$profile/config" "$profile/cache"
  status=0
  XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" XDG_CACHE_HOME="$profile/cache" FLOTRA_POLISH_ISOLATED=1 \
    timeout 180 "$BIN" --headless --path "$REPO/godot" --script "res://tests/$name.gd" > "$OUT/$name.log" 2>&1 || status=$?
  if [[ $status -ne 0 ]] || grep -Eq 'SCRIPT ERROR|Parse Error|Invalid call|ERROR:|Assertion failed|Failed to load script' "$OUT/$name.log"; then
    echo "FAIL $name exit=$status"; tail -40 "$OUT/$name.log"; exit 1
  fi
  echo "PASS $name"
done
