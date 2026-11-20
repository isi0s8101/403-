#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
command -v "$GODOT_BIN" >/dev/null || { echo 'Indiquer GODOT_BIN (Godot 4.5.1 ou compatible).' >&2; exit 127; }
mkdir -p game-studio/preuves/j345-local
"$GODOT_BIN" --headless --editor --import --quit 2>&1 | tee game-studio/preuves/j345-local/import.log
if grep -Eq 'SCRIPT ERROR|^ERROR:' game-studio/preuves/j345-local/import.log; then exit 1; fi
for test in modern_test modern_catalog_test modern_ai_test modern_ui_test modern_sandbox_test ui_j21_test touch_test visual_j21c_test visual_j21def_test; do
    logfile="game-studio/preuves/j345-local/${test}.log"
    "$GODOT_BIN" --headless -s "res://lab/${test}.gd" 2>&1 | tee "$logfile"
    if grep -Eq 'SCRIPT ERROR|^ERROR:|^FAIL |RESULT=FAIL' "$logfile"; then exit 1; fi
done
"$GODOT_BIN" --headless -s res://lab/lab_runner.gd -- all --out=res://game-studio/preuves/j345-local/regression
"$GODOT_BIN" --headless -s res://lab/fronts_test.gd -- 100 300
