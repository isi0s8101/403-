#!/usr/bin/env python3
"""Audit reproductible de câblage J10. N'exécute PAS GDScript/Android."""
from __future__ import annotations
import hashlib
import pathlib
import re
import sys

ROOT=pathlib.Path(__file__).resolve().parents[1]
checks=[]

def check(condition: bool, title: str) -> None:
    checks.append((bool(condition),title))
    print(('PASS ' if condition else 'FAIL ')+title)

def source(name: str) -> str:
    return (ROOT / name).read_text(encoding='utf-8')

required=[
 'procgen/star_system_generator.gd','views/space_map_view.gd','views/space_map_hud.gd',
 'lab/j10_systems_test.gd','lab/j10_ui_test.gd','sim/star_campaign.gd','sim/campaign_save.gd',
 'game/game.gd','views/planet_hud.gd','game/strategic_hud.gd',
 'tools/verify-j10.sh','tools/export-android-j10.sh','README-J10.md',
]
for name in required: check((ROOT/name).is_file(),f'fichier J10 : {name}')

gen=source('procgen/star_system_generator.gd')
campaign=source('sim/star_campaign.gd')
save=source('sim/campaign_save.gd')
ui=source('game/game.gd')
hud=source('views/space_map_hud.gd')+source('interface/observation_hud.gd')
view=source('views/space_map_view.gd')
for symbol,description in [
 ('func _generate()', 'génération déterministe'),
 ('RandomNumberGenerator.new()', 'graine locale sans RNG global'),
 ('func body_position(', 'trajectoires orbitales paramétriques'),
 ('func signature(', 'signature du catalogue'),
 ('func bodies_for_system(', 'carte système filtrée'),
 ('func orbit_for(', 'lunes par planète'),
 ('"val"', 'identité planète historique Val'),
 ('"aurore"', 'identité planète historique Aurore'),
 ('"nemesis"', 'identité planète historique Némésis'),
 ('"moon"', 'satellites naturels générés')]: check(symbol in gen,description)
for symbol,description in [
 ('func materialize(', 'mondes instanciés à la demande'),
 ('if worlds.has(key):', 'pas de duplication de monde'),
 ('func sector_keys(', 'catalogue de secteurs extensible'),
 ('func _tick_flights(', 'traversée des routes simulée'),
 ('if not SECTORS.has(String(key))', 'tick léger pour secteur vide'),
 ('func _check_defeat(', 'victoire globale conservée'),
 ('planet_regions.step_background(self)', 'simulation J9 préservée'),
 ('func dispatch(', 'convoyage J6–J8 conservé')]: check(symbol in campaign,description)
for symbol,description in [
 ('"extra_maps": extras', 'sauvegarde des mondes générés'),
 ('"star_catalog_version":', 'version du générateur sauvegardée'),
 ('not catalog.has_body(source)', 'rejet de route non présente dans catalogue'),
 ('not extras.has(target)', 'rejet des destinations non sauvegardées'),
 ('dynamic_world.seed_value', 'vérification seed du monde restauré'),
 ('StarSystemGenerator.new(seed)', 'reconstruction déterministe du catalogue'),
 ('region_state', 'sauvegarde J9 préservée')]: check(symbol in save,description)
for symbol,description in [
 ('func enter_space_overview(', 'transition vue spatiale'),
 ('func leave_space_overview(', 'retour vers tactique'),
 ('func land_on_space_selection(', 'atterrissage en région tactique'),
 ('func _handle_space_input(', 'gestes tactiles spatiaux'),
 ('_space_environment(', 'ambiance spatiale distincte'),
 ('if not planet_mode and space_mode == "":', 'rendu tactique désactivé sous vue spatiale')]: check(symbol in ui,description)
for symbol,description in [
 ('extends ObservationHud', 'vue système en observation'),
 ('MovementFeed.records(', 'trafic issu des missions réelles'),
 ('func _open_orbit(', 'accès à la carte orbitale jouable'),
 ('func is_over_ui(', 'panneaux tactiles bloquent la carte')]: check(symbol in hud,description)
check('c.dispatch(' not in hud and 'issue_orbit(' not in hud,'aucun ordre depuis les vues de suivi')
for symbol,description in [
 ('func refresh_sim(', 'animation spatiale selon tick'),
 ('MovementFeed.records(campaign', 'visualisation des convois réels'),
 ('func pick(', 'sélection des astres au toucher'),
 ('Mesh.PRIMITIVE_LINE_STRIP', 'trajectoires orbitales représentées'),
 ('MAX_VISIBLE_FLIGHTS', 'borne des marqueurs de vols en rendu'),
 ('flight_nodes[used]', 'réemploi des instances de marqueurs')]: check(symbol in view,description)

check(any(v in source('project.godot') for v in ['0.10.0-j10-candidate', '0.11.0-j11-candidate', '0.12.3-j12-orbital-candidate', '0.16.0-civilisation-candidate', '0.17.0-interface-candidate', '0.18.0-ville-candidate', '0.18.1-ville-candidate', '0.19.0-zonage-candidate', '0.20.0-zonage-candidate']),'socle J10 conservé dans version J11')
check(int(source('export_presets.cfg').split('version/code=')[1].splitlines()[0]) >= 100,'code version Android >= 100')
check('J10_SYSTEMS_RESULT' in source('lab/j10_systems_test.gd'),'tests moteur avec codes de retour')
check('J10_UI_RESULT' in source('lab/j10_ui_test.gd'),'tests de navigation avec codes de retour')
check('verify-j10.sh' in source('tools/export-android-j10.sh'),'export conditionné à vérification')
for name in required:
    p=ROOT/name
    if not p.is_file(): continue
    s=p.read_text(encoding='utf8')
    check(not re.search(r'^\s*(<<<<<<<|=======|>>>>>>>)',s,re.M),f'aucun marqueur de conflit : {name}')
    check('\x00' not in s and '\r' not in s,f'encodage valide : {name}')
for name in ['sim/rules.gd','sim/sim_world.gd','procgen/planet_generator.gd','procgen/planet_regions.gd','game/world_view.gd']:
    check((ROOT/name).is_file() and (ROOT/name).stat().st_size>100,f'socle J1–J9 conservé : {name}')
manifest=ROOT/('game-studio/manifest-j13.sha256' if any(v in source('project.godot') for v in ['0.16.0-civilisation-candidate', '0.17.0-interface-candidate', '0.18.0-ville-candidate', '0.18.1-ville-candidate', '0.19.0-zonage-candidate', '0.20.0-zonage-candidate']) else 'game-studio/manifest-j12.sha256' if '0.12.3-j12-orbital-candidate' in source('project.godot') else ('game-studio/manifest-j11.sha256' if '0.11.0-j11-candidate' in source('project.godot') else 'game-studio/manifest-j10.sha256'))
if manifest.exists():
    lines=manifest.read_text(encoding='utf8').splitlines()
    valid=True
    for line in lines:
        if '  ' not in line: valid=False;break
        expected,name=line.split('  ',1)
        path=ROOT/name
        if name.startswith('/') or '..' in pathlib.PurePosixPath(name).parts or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=expected:
            valid=False;break
    check(valid and len(lines)>=280,f'intégrité manifeste J10 ({len(lines)} fichiers)')
else:
    print('INFO manifeste non généré avant assemblage final')

failures=[title for ok,title in checks if not ok]
print(f'J10_STATIC_RESULT={"PASS" if not failures else "FAIL"} checks={len(checks)} failures={len(failures)}')
sys.exit(1 if failures else 0)
