#!/usr/bin/env python3
"""Vérifications J12 uniquement structurelles ; pas de compilation GDScript."""
import hashlib
import json
import re
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
count = 0
fail = 0

def check(ok, msg):
    global count, fail
    count += 1
    if not ok:
        fail += 1
    print(('PASS ' if ok else 'FAIL ') + msg)

def source(name):
    p = ROOT/name
    check(p.is_file(), f'fichier {name}')
    return p.read_text(encoding='utf-8') if p.is_file() else ''

campaign = source('sim/star_campaign.gd')
save = source('sim/campaign_save.gd')
ui = source('orbit/orbital_battle_hud.gd')
view = source('views/galaxy_map_view.gd')
perf = source('game/mobile_perf_budget.gd')
game = source('game/game.gd')
recipe = source('lab/recette_suite.gd')
manual = source('game/recette_screen.gd')
for path in ['lab/j12_empire_test.gd','lab/j12_perf_test.gd','README-J12.md','tools/verify-j12.sh','tools/export-android-j12.sh']:
    source(path)
for term in ['var system_stocks:', 'func system_resources(', 't.res = system_resources(team,',
             'func _route_for_supply(', 'func ship_supplies(', 'func _tick_freight(',
             'func set_system_order(', 'func _tick_directives(', 'FREIGHT_LIMIT',
             'FREIGHT_FARE_FOOD', 'var_to_str(system_stocks)', '_tick_freight()']:
    check(term in campaign, 'moteur : '+term)
for term in ['"system_stocks": c.system_stocks', '"freight_orders": c.freight_orders',
             '"next_freight_id": c.next_freight_id', '"directives": c.directives',
             'local_stocks_value', 'freight_ids', 'not is_finite', 'catalog.galaxy.adjacent(',
             'c.freight_orders =', 'c.system_stocks =', 'StarCampaign.ORDER_MODES']:
    check(term in save, 'persistance et validation : '+term)
for term in ['c.transfer_materials(', 'c.set_system_order(', 'Voyage', 'destination']:
    check(term in ui, 'commande déplacée dans la carte orbitale : '+term)
for term in ['MAX_VISIBLE_TRANSITS', 'var flight_nodes:', 'MovementFeed.records(', 'flight_nodes[used]']:
    check(term in view, 'affichage du trafic et fret borné : '+term)
for term in ['func observe(', 'terrain_lod_bias', 'galaxy_refresh_ticks', 'stage = mini(2, stage + 1)']:
    check(term in perf, 'gouverneur : '+term)
check('mobile_perf.observe(delta)' in game and 'mobile_perf.terrain_lod_bias' in game, 'gouverneur intégré sans toucher aux ticks')
check('phase = "empire"' in recipe and 'func _run_empire_checks()' in recipe, 'recette automatique J9–J12 dans le menu')
check('J1–J12' in manual and '"id": "freight"' in manual, 'contrôles manuels J1–J12')
check(any(v in source('project.godot') for v in ['0.12.3-j12-orbital-candidate', '0.16.0-civilisation-candidate', '0.17.0-interface-candidate', '0.18.0-ville-candidate', '0.18.1-ville-candidate', '0.19.0-zonage-candidate', '0.20.0-zonage-candidate']), 'version 0.12.3 ou J13 candidate')
check(int(source('export_presets.cfg').split('version/code=')[1].splitlines()[0]) >= 123, 'versionCode Android >= 123')
for name in ['sim/star_campaign.gd','sim/campaign_save.gd','views/galaxy_map_hud.gd',
             'views/galaxy_map_view.gd','game/mobile_perf_budget.gd',
             'lab/j12_empire_test.gd','lab/j12_perf_test.gd']:
    src=(ROOT/name).read_text(encoding='utf-8')
    check('\x00' not in src and '\r' not in src and not re.search(r'^\s*(<<<<<<<|=======|>>>>>>>)',src,re.M), f'texte sain {name}')
    funcs=re.findall(r'^func\s+(\w+)\s*\(',src,re.M)
    check(len(funcs)==len(set(funcs)),f'fonctions uniques {name}')
manifest=ROOT/('game-studio/manifest-j13.sha256' if any(v in source('project.godot') for v in ['0.16.0-civilisation-candidate', '0.17.0-interface-candidate', '0.18.0-ville-candidate', '0.18.1-ville-candidate', '0.19.0-zonage-candidate', '0.20.0-zonage-candidate']) else 'game-studio/manifest-j12.sha256')
if manifest.is_file():
    entries=manifest.read_text().splitlines()
    valid=True
    for record in entries:
        if '  ' not in record:
            valid=False;break
        digest,rel=record.split('  ',1)
        target=ROOT/rel
        if not re.fullmatch(r'[0-9a-f]{64}',digest) or rel.startswith('/') or '..' in Path(rel).parts or not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest()!=digest:
            valid=False;break
    check(valid and len(entries)>300,'manifest J12 SHA-256 valide : %d fichiers'%len(entries))
else:
    print('INFO manifeste J12 généré à l’assemblage')
print('J12_STATIC_RESULT=%s checks=%d failures=%d'%('PASS' if fail==0 else 'FAIL',count,fail))
sys.exit(1 if fail else 0)
