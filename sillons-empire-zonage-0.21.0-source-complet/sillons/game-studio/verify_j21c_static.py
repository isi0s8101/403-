#!/usr/bin/env python3
"""Contrôles J2.1-C sans compilation moteur. Usage :
python3 game-studio/verify_j21c_static.py /chemin/sillons-empire-j2-src-0.2.0.zip
"""
from __future__ import annotations
import re
import sys
import zipfile
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent.parent
failure = 0
checks = 0

def check(label, ok):
    global failure, checks
    checks += 1
    if not ok:
        failure += 1
    print(f"{'PASS' if ok else 'FAIL'} STATIC_J21C {label}")

baseline = Path(sys.argv[1]) if len(sys.argv) > 1 else None
if baseline:
    with zipfile.ZipFile(baseline) as z:
        relpaths = [p for p in z.namelist() if p.startswith('sillons/sim/') and not p.endswith('/')]
        check('all_sim_files_unchanged', all((root / p.removeprefix('sillons/')).read_bytes() == z.read(p) for p in relpaths))
        old_scenarios = {p for p in z.namelist() if p.startswith('sillons/lab/scenarios/') and p.endswith('.json')}
        new_scenarios = {'sillons/' + p.relative_to(root).as_posix() for p in (root/'lab/scenarios').glob('*.json')}
        check('all_j2_scenarios_preserved', new_scenarios == old_scenarios)

for p in (root / 'game/textures').glob('*.png'):
    with Image.open(p) as img:
        check('texture_512x512_RGBA_' + p.name, img.mode == 'RGBA' and img.size == (512,512) and bool(img.verify() is None))
check('five_original_textures', len(list((root/'game/textures').glob('*.png'))) == 5)
for rel in ['game/assets.gd', 'game/world_view.gd', 'game/game.gd', 'game/fronts.gd', 'game/witness.gd', 'lab/visual_j21c_test.gd']:
    p = root / rel
    check('source_present_' + rel, p.is_file() and bool(p.read_text().strip()))
for file in root.rglob('*.tscn'):
    src=file.read_text()
    for ref in re.findall(r'path="res://([^"\n]+)"', src):
        check('scene_path_'+file.name+'_'+ref, (root/ref).is_file())
wv=(root/'game/world_view.gd').read_text()
assets=(root/'game/assets.gd').read_text()
check('fog_preserved_for_ground', 'texture(fog_tex, uv)' in assets)
check('fog_preserved_for_decor', 'var fog: PackedByteArray = world.teams[observer].fog' in wv and 'visible == 0' in wv)
check('lod_present', 'func set_visual_lod(camera_distance: float' in wv)
check('pbr_normal_tangents', 'st.generate_tangents()' in assets and 'NORMAL_MAP =' in assets)
check('textures_bound', all(f'"{key}"' in wv for key in ['grass_tex', 'soil_tex', 'sand_tex', 'rock_tex', 'normal_tex']))
check('ui_unchanged_present', 'func open_radial(' in (root/'game/hud.gd').read_text() and 'func _select_rectangle(' in (root/'game/game.gd').read_text())
check('version', any(v in (root/'project.godot').read_text() for v in ['0.2.2-j2.1c-visual', '0.2.3-j2.1def-visual']))
print(f'STATIC_J21C_RESULT={"PASS" if failure == 0 else "FAIL"} checks={checks} fail={failure}')
raise SystemExit(1 if failure else 0)
