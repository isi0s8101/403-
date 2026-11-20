#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
python3 tools/verify-j678-static.py
python3 tools/verify-recette-static.py
python3 tools/verify-fix082-static.py
python3 tools/verify-j9-static.py
python3 tools/verify-j9-complete-static.py
python3 tools/verify-j10-static.py
python3 tools/verify-j11-static.py
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  printf '%s\n' 'J11_RUNTIME=NOT_RUN ; moteur Godot absent ; aucun PASS runtime/Android.' >&2
  exit 127
fi
"$GODOT_BIN" --headless --path . --editor --quit
for scenario in \
  res://lab/j9_planet_test.gd \
  res://lab/j9_regions_test.gd \
  res://lab/strategic_test.gd \
  res://lab/recette_integrale_test.gd \
  res://lab/j10_systems_test.gd \
  res://lab/j10_ui_test.gd \
  res://lab/j11_galaxy_test.gd \
  res://lab/j11_ui_test.gd; do
  "$GODOT_BIN" --headless --path . --script "$scenario"
done
printf '%s\n' 'J11_GODOT_HEADLESS=PASS ; Android/S25 Ultra=NOT_TESTED'
