#!/usr/bin/env bash
# Depuis le projet Godot : GODOT_BIN=/chemin/godot bash tools/verify-refonte.sh
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
python3 -I tools/verify-refonte-static.py
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  printf '%s\n' 'REFONTE_RUNTIME=NOT_RUN : moteur Godot absent.' >&2
  exit 127
fi
run_godot() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --kill-after=5s "${seconds}s" "$GODOT_BIN" "$@"
  else
    "$GODOT_BIN" "$@"
  fi
}
run_log="$(mktemp -d)"
trap 'rm -rf -- "$run_log"' EXIT
if ! run_godot 600 --headless --path . --editor --quit >"$run_log/import.log" 2>&1; then
  cat "$run_log/import.log"
  exit 1
fi
if grep -nE 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:' "$run_log/import.log"; then
  printf '%s\n' 'REFONTE_IMPORT=FAIL' >&2
  exit 1
fi
printf '%s\n' 'REFONTE_IMPORT=PASS'
# 0.17 : l'import ne signale pas toutes les erreurs d'analyse ; chaque script est chargé explicitement.
if ! run_godot 300 --headless --path . --script res://tools/check-scripts.gd >"$run_log/scripts.log" 2>&1 || ! grep -q 'SCRIPTS_RESULT=PASS' "$run_log/scripts.log"; then
  grep -E 'SCRIPT_FAIL|Parse Error|at: ' "$run_log/scripts.log" | head -40
  printf '%s\n' 'REFONTE_SCRIPTS=FAIL' >&2
  exit 1
fi
printf '%s\n' 'REFONTE_SCRIPTS=PASS'
# 0.18.1 : chaque caractère des textes d'interface existe dans les polices livrées (sinon carré sur Android).
if ! run_godot 120 --headless --path . --script res://tools/check-glyphs.gd >"$run_log/glyphs.log" 2>&1 || ! grep -q 'GLYPHS_RESULT=PASS' "$run_log/glyphs.log"; then
  grep -E 'GLYPH' "$run_log/glyphs.log" >&2 || true
  printf '%s\n' 'REFONTE_GLYPHS=FAIL' >&2
  exit 1
fi
printf '%s\n' 'REFONTE_GLYPHS=PASS'
for scenario in \
  j9_planet j9_regions strategic recette_integrale j10_systems j10_ui \
  j11_galaxy j11_ui j12_empire j12_perf view_technology age_progression \
  j12_orbital_shipyard j13_colony j13_supply assets_3d j13_globe j13_ui \
  fronts modern modern_ai modern_catalog modern_sandbox modern_ui strategic_ui \
  speed_ui touch ui_j21 visual_j21c visual_j21def refonte_visual modal_touch native_assets realism_visual \
  evolution_campaign evolution_rally evolution_politics evolution_diplomacy \
  evolution_logistics evolution_ui evolution_progression evolution_performance \
  interface_menu interface_interaction interface_portraits orbit_tactical orbit_save orbit_performance \
  android_performance android_performance_ui civ_evolution civ_ui \
  unit_commands ui_selection ui_orders ui_production ui_alerts ui_theme urban_city ui_city ui_portrait zoning ui_zoning urban_lotb; do
  if ! XDG_DATA_HOME="$run_log/user-$scenario" run_godot 240 --headless --path . --script "res://lab/${scenario}_test.gd" >"$run_log/$scenario.log" 2>&1; then
    tail -60 "$run_log/$scenario.log"
    exit 1
  fi
  if grep -nE 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:|^FAIL([[:space:]]|$)' "$run_log/$scenario.log"; then
    printf 'REFONTE_SCENARIO=FAIL %s\n' "$scenario" >&2
    exit 1
  fi
  printf 'PASS %s\n' "$scenario"
done
python3 -I tools/verify-native-package.py --godot "$GODOT_BIN"
printf '%s\n' 'REFONTE_GODOT=PASS scenarios=64 ; ANDROID_DEVICE=NOT_RUN'
