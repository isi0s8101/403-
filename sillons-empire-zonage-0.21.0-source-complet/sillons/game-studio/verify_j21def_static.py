#!/usr/bin/env python3
"""Audit statique J2.1-D/E/F sans prétendre compiler GDScript.

Usage : python3 game-studio/verify_j21def_static.py [baseline-j2.zip] [parent-j21c.zip]
Rejouable hors réseau, uniquement Python standard. Codes : 0 PASS, 1 FAIL.
"""
from __future__ import annotations
import hashlib, json, re, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE = Path(sys.argv[1]) if len(sys.argv) > 1 else None
PARENT = Path(sys.argv[2]) if len(sys.argv) > 2 else None
count = 0
failed = 0

def check(label: str, condition: bool) -> None:
    global count, failed
    count += 1
    failed += 0 if condition else 1
    print(f"{'PASS' if condition else 'FAIL'} J21DEF_STATIC {label}")

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

files = {p.relative_to(ROOT).as_posix(): p for p in ROOT.rglob('*') if p.is_file()}
required = [
    'project.godot', 'game/assets.gd', 'game/unit_visual.gd', 'game/building_visual.gd',
    'game/world_view.gd', 'game/hud.gd', 'game/game.gd', 'game/fronts.gd',
    'game/main_menu.gd', 'game/textures/grass_pbr.png',
    'lab/visual_j21c_test.gd', 'lab/visual_j21def_test.gd',
    'lab/ui_j21_test.gd', 'lab/touch_test.gd', 'lab/lab_runner.gd',
]
for name in required:
    check('required:' + name, name in files)
for p in ROOT.rglob('*.tscn'):
    for ref in re.findall(r'path="res://([^"\n]+)"', p.read_text(encoding='utf8')):
        check('scene_ref:' + ref, ref in files)
for p in ROOT.rglob('*.gd'):
    source = p.read_text('utf8')
    check('nonempty:' + p.relative_to(ROOT).as_posix(), bool(source.strip()) and '\x00' not in source)
    # Protection récurrente : Godot 4.7 ne déduit pas := depuis game non typé.
    check('no_game_variant_infer:' + p.name, not re.search(r'\bvar\s+\w+\s*:=\s*game\.', source))
for p in (ROOT / 'lab/scenarios').glob('*.json'):
    try:
        json.loads(p.read_text('utf8'))
        ok = True
    except Exception:
        ok = False
    check('scenario_json:' + p.name, ok)

# Empreintes J2 archivées et présentes dans le ZIP => vérification locale autonome.
manifest = ROOT / 'game-studio/j2-sim.sha256'
if manifest.is_file():
    lines = [line.split('  ', 1) for line in manifest.read_text('utf8').splitlines() if line]
    check('manifest_j2_nont_empty', len(lines) >= 5)
    for h, relative in lines:
        check('sim_j2:' + relative, relative in files and sha(files[relative].read_bytes()) == h)
else:
    check('manifest_j2', False)

if BASELINE is not None:
    check('baseline_exists', BASELINE.is_file())
    if BASELINE.is_file():
        with zipfile.ZipFile(BASELINE) as src:
            sim = [x for x in src.namelist() if x.startswith('sillons/sim/') and not x.endswith('/')]
            check('sim_equals_j2_original', all('sillons/'+rel in src.namelist() and files[rel].read_bytes() == src.read('sillons/'+rel)
                for rel in (x.removeprefix('sillons/') for x in sim)))
            scenarios = {x for x in src.namelist() if x.startswith('sillons/lab/scenarios/') and x.endswith('.json')}
            current = {'sillons/'+x for x in files if x.startswith('lab/scenarios/') and x.endswith('.json')}
            check('j2_scenarios_unchanged', scenarios == current)
if PARENT is not None:
    check('parent_exists', PARENT.is_file())
    if PARENT.is_file():
        with zipfile.ZipFile(PARENT) as arc:
            old = {x.removeprefix('sillons/'): sha(arc.read(x)) for x in arc.namelist() if x.startswith('sillons/') and not x.endswith('/')}
            check('all_parent_files_present', all(x in files for x in old))
            # Les sources de simulation et les textures originales restent identiques.
            check('source_sim_and_pbr_identical_parent', all(sha(files[x].read_bytes()) == h
                for x,h in old.items() if x.startswith('sim/') or x.startswith('game/textures/')))

project = files['project.godot'].read_text('utf8')
view = files['game/world_view.gd'].read_text('utf8')
hud = files['game/hud.gd'].read_text('utf8')
unit = files['game/unit_visual.gd'].read_text('utf8')
bld = files['game/building_visual.gd'].read_text('utf8')
check('project_version', '0.2.3-j2.1def-visual' in project)
check('rig_articulation', all(x in unit for x in ['"Arm" + side', '"Leg" + side', '"Knee"', 'static func animate(', 'static func set_lod(']))
check('building_damage', all(x in bld for x in ['Architecture', 'Damage', 'Cracks', 'func set_damage(', 'func set_lod(']))
check('visual_caps', all(x in view for x in ['MAX_VISUAL_RIGS', 'MAX_DETAILED_BUILDINGS', 'MAX_VISUAL_FX']))
check('damage_fog_limit', 'world.is_visible_to(observer, b.center)' in view)
check('visual_sim_is_readonly', 'world.issue(' not in view and 'world.step(' not in view)
check('hud_controls_quality', 'quality_btn' in hud and 'controls_panel' in hud and 'func _cycle_quality' in hud)
check('gesture_still_available', 'func _select_rectangle(' in files['game/game.gd'].read_text('utf8') and 'func open_radial(' in hud)
check('preserves_labs', len(list((ROOT / 'lab/scenarios').glob('*.json'))) == 23)
print(f"J21DEF_STATIC_RESULT={'PASS' if failed == 0 else 'FAIL'} total={count} fail={failed}")
raise SystemExit(1 if failed else 0)
