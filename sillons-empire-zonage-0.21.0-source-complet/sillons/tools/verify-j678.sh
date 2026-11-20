#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "SKIP: moteur Godot 4 introuvable : $GODOT_BIN" >&2
  exit 127
fi
OUT="${SILLONS_TEST_OUT:-game-studio/preuves/j678-local}"
mkdir -p -- "$OUT"
"$GODOT_BIN" --headless --editor --import --quit 2>&1 | tee "$OUT/import.log"
if grep -Eq 'SCRIPT ERROR|^ERROR:|Parse Error|Compile Error' "$OUT/import.log"; then
  echo 'J678_GODOT_RESULT=FAIL_IMPORT' >&2
  exit 1
fi
for test in strategic_test strategic_ui_test modern_test modern_catalog_test modern_ai_test modern_ui_test modern_sandbox_test ui_j21_test touch_test visual_j21c_test visual_j21def_test; do
  echo "TEST $test"
  logfile="$OUT/${test}.log"
  set +e
  "$GODOT_BIN" --headless -s "res://lab/${test}.gd" 2>&1 | tee "$logfile"
  status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]] || grep -Eq 'SCRIPT ERROR|^ERROR:|Parse Error|Compile Error|^FAIL |RESULT=FAIL' "$logfile"; then
    echo "J678_GODOT_RESULT=FAIL_${test}" >&2
    exit 1
  fi
done
"$GODOT_BIN" --headless -s res://lab/lab_runner.gd -- all --out="res://${OUT}/regression" 2>&1 | tee "$OUT/lab_runner.log"
"$GODOT_BIN" --headless -s res://lab/fronts_test.gd -- 100 300 2>&1 | tee "$OUT/fronts_test.log"
if grep -Eq 'SCRIPT ERROR|^ERROR:|Parse Error|Compile Error|^FAIL |RESULT=FAIL' "$OUT/lab_runner.log" "$OUT/fronts_test.log"; then
  echo 'J678_GODOT_RESULT=FAIL_REGRESSION' >&2
  exit 1
fi
echo 'J678_GODOT_RESULT=PASS'
