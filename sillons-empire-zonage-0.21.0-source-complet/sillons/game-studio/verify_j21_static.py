#!/usr/bin/env python3
"""Vérification reproductible de l'archive de travail J2.1 (sans Godot).
Usage: python3 game-studio/verify_j21_static.py [chemin/vers/baseline-j2.zip]
Ce script n'est PAS un test de compilation GDScript ni un test de gameplay.
"""
from __future__ import annotations
import re
import sys
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
baseline_path = Path(sys.argv[1]) if len(sys.argv) > 1 else None
fail = 0

def check(label: str, ok: bool) -> None:
    global fail
    print(f"{'PASS' if ok else 'FAIL'} STATIC_J21 {label}")
    fail += 0 if ok else 1

required = ["project.godot", "export_presets.cfg", "game/game.gd", "game/hud.gd", "game/main_menu.gd", "sim/sim_world.gd", "lab/touch_test.gd", "lab/ui_j21_test.gd", "lab/fronts_test.gd"]
for rel in required:
    check(f"file:{rel}", (root / rel).is_file())

for file in root.rglob("*.tscn"):
    contents = file.read_text(encoding="utf-8")
    for res in re.findall(r'path="res://([^"\n]+)"', contents):
        check(f"scene-ref:{file.name}:{res}", (root / res).is_file())

for file in root.rglob("*.gd"):
    src = file.read_text(encoding="utf-8")
    check(f"source:{file.relative_to(root)}", bool(src.strip()) and "\x00" not in src)

for file in root.glob("lab/scenarios/*.json"):
    try:
        import json
        json.loads(file.read_text(encoding="utf-8"))
        check(f"json:{file.name}", True)
    except Exception:
        check(f"json:{file.name}", False)

if baseline_path:
    if not baseline_path.is_file():
        check("baseline_j2_disponible", False)
    else:
        with zipfile.ZipFile(baseline_path) as arc:
            sim_paths = [x for x in arc.namelist() if x.startswith("sillons/sim/") and not x.endswith("/")]
            check("simulation_integralement_preservee", all((root / rel.removeprefix("sillons/")).read_bytes() == arc.read(rel) for rel in sim_paths))
            prior_scenarios = {x for x in arc.namelist() if x.startswith("sillons/lab/scenarios/") and x.endswith(".json")}
            now_scenarios = {"sillons/" + str(x.relative_to(root)) for x in root.glob("lab/scenarios/*.json")}
            check("scenarios_j2_preserves", prior_scenarios == now_scenarios)

# Le runner J2.1 lit des champs de `game` non typé ; Godot 4.7.2 ne peut pas
# inférer des types de `:= game...`. Empêcher la régression signalée dans FIX1.
runner = (root / "lab/ui_j21_test.gd").read_text(encoding="utf-8")
check("j21_test_bool_explicit", "var original: bool = bool(game.hud.minimap.visible)" in runner)
check("j21_test_array_explicit", "var initial_squads: Array = game.world.team_squads(0)" in runner
      and "var selection_squads: Array = game.world.team_squads(0)" in runner)
check("j21_test_no_infer_game", not re.search(r"\bvar\s+\w+\s*:=\s*game\.", runner))

check("version_j21", any(v in (root / "project.godot").read_text() for v in ["0.2.1-j2.1", "0.2.2-j2.1c", "0.2.3-j2.1def"]))
check("mode_radial", 'func open_radial(' in (root / "game/hud.gd").read_text())
check("selection_rectangle", 'func _select_rectangle(' in (root / "game/game.gd").read_text())
print(f"STATIC_J21_RESULT={'PASS' if fail == 0 else 'FAIL'} failures={fail}")
sys.exit(1 if fail else 0)
