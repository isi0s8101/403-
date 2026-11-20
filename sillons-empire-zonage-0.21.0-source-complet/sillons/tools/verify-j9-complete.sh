#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
python3 tools/verify-j678-static.py
python3 tools/verify-recette-static.py
python3 tools/verify-fix082-static.py
python3 tools/verify-j9-static.py
python3 tools/verify-j9-complete-static.py
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo 'J9_COMPLETE_RUNTIME=NOT_RUN : Godot absent ; les tests statiques ne sont pas une validation d’exécution.' >&2
  exit 127
fi
"$GODOT_BIN" --headless --path . --editor --quit
"$GODOT_BIN" --headless --path . --script res://lab/j9_planet_test.gd
"$GODOT_BIN" --headless --path . --script res://lab/j9_regions_test.gd
"$GODOT_BIN" --headless --path . --script res://lab/recette_integrale_test.gd
"$GODOT_BIN" --headless --path . --script res://lab/strategic_test.gd
echo 'J9_COMPLETE_GODOT=PASS ; validation sur appareil=NOT_RUN'
