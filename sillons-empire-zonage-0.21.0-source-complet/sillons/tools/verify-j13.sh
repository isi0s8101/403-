#!/usr/bin/env bash
# J13 : contrôles statiques, import Godot réel, puis TOUTES les recettes J1–J13 hors rendu.
# GODOT_BIN=/chemin/vers/godot ./tools/verify-j13.sh
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for check in \
  tools/verify-j678-static.py \
  tools/verify-recette-static.py \
  tools/verify-fix082-static.py \
  tools/verify-j9-static.py \
  tools/verify-j9-complete-static.py \
  tools/verify-j10-static.py \
  tools/verify-j11-static.py \
  tools/verify-j12-static.py \
  tools/verify-evolution-static.py \
  tools/verify-orbital-static.py \
  tools/verify-j13-static.py; do
  python3 "$check" | tail -1
done
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  printf '%s\n' 'J13_RUNTIME=NOT_RUN : moteur Godot absent ; aucune validation réelle.' >&2
  exit 127
fi
"$GODOT_BIN" --headless --path . --version | head -1
import_log="$(mktemp)"
"$GODOT_BIN" --headless --path . --editor --quit >"$import_log" 2>&1 || true
if grep -E 'SCRIPT ERROR|Parse Error|Compile Error' "$import_log"; then
  printf '%s\n' 'J13_GODOT_IMPORT=FAIL' >&2
  exit 1
fi
printf '%s\n' 'J13_GODOT_IMPORT=PASS'
for scenario in \
  res://lab/j9_planet_test.gd \
  res://lab/j9_regions_test.gd \
  res://lab/strategic_test.gd \
  res://lab/recette_integrale_test.gd \
  res://lab/j10_systems_test.gd \
  res://lab/j10_ui_test.gd \
  res://lab/j11_galaxy_test.gd \
  res://lab/j11_ui_test.gd \
  res://lab/j12_empire_test.gd \
  res://lab/j12_perf_test.gd \
  res://lab/view_technology_test.gd \
  res://lab/age_progression_test.gd \
  res://lab/j12_orbital_shipyard_test.gd \
  res://lab/j13_colony_test.gd \
  res://lab/j13_supply_test.gd \
  res://lab/assets_3d_test.gd \
  res://lab/j13_globe_test.gd \
  res://lab/j13_ui_test.gd; do
    scenario_log="$(mktemp)"
    "$GODOT_BIN" --headless --path . --script "$scenario" >"$scenario_log" 2>&1 || { tail -40 "$scenario_log"; printf 'J13_GODOT_HEADLESS=FAIL : %s\n' "$scenario" >&2; exit 1; }
    if grep -E 'SCRIPT ERROR|Parse Error|Compile Error' "$scenario_log"; then
      printf 'J13_GODOT_HEADLESS=FAIL (erreur de script) : %s\n' "$scenario" >&2
      exit 1
    fi
    grep -E 'RESULT|ORBITAL_J12_3' "$scenario_log" | tail -1
done
printf '%s\n' 'J13_GODOT_HEADLESS=PASS ; VALIDATION_ANDROID=NOT_RUN'
