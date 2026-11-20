#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "RECETTE_GODOT_RESULT=SKIP (Godot 4 introuvable)" >&2
  exit 127
fi
# Banc de non-régression complet précédent (dont import, scènes/UI, J1-J8).
"$(dirname -- "${BASH_SOURCE[0]}")/verify-j678.sh"
OUT="${SILLONS_TEST_OUT:-game-studio/preuves/recette-local}"
mkdir -p -- "$OUT"
for script in lab/recette_integrale_test.gd lab/speed_ui_test.gd; do
  name="${script##*/}"
  logfile="$OUT/$name.log"
  echo "RECETTE $script"
  "$GODOT_BIN" --headless --path . --script "res://$script" 2>&1 | tee "$logfile"
  if grep -Eq 'SCRIPT ERROR|^ERROR:|Parse Error|Compile Error|^FAIL |RESULT=FAIL' "$logfile"; then
    echo "RECETTE_GODOT_RESULT=FAIL_${name}" >&2
    exit 1
  fi
done
echo 'RECETTE_GODOT_RESULT=PASS (auto uniquement ; validation S25 manuelle requise)'
