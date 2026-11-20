#!/usr/bin/env bash
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
  tools/verify-orbital-static.py; do
  python3 "$check" | tail -1
done
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  printf '%s\n' 'J12_RUNTIME=NOT_RUN : moteur Godot absent ; export Android non validé.' >&2
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
  res://lab/j11_ui_test.gd \
  res://lab/j12_empire_test.gd \
  res://lab/j12_perf_test.gd \
  res://lab/view_technology_test.gd \
  res://lab/age_progression_test.gd \
  res://lab/j12_orbital_shipyard_test.gd; do
    "$GODOT_BIN" --headless --path . --script "$scenario"
done
printf '%s\n' 'J12_GODOT_HEADLESS=PASS ; VALIDATION_ANDROID=NOT_RUN'
