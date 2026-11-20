#!/usr/bin/env python3
"""Vérification structurelle J12.3 ; ne remplace pas l'exécution Godot."""
from pathlib import Path
import sys, re
root=Path(__file__).resolve().parents[1]
checks=[]
def test(ok, label):
    checks.append(bool(ok))
    print(('PASS' if ok else 'FAIL')+' '+label)
def get(name):return (root/name).read_text(encoding='utf-8')
for name in ['sim/orbital_industry.gd','lab/j12_orbital_shipyard_test.gd','views/space_map_hud.gd','views/space_map_view.gd','README-CHANTIER-ORBITAL-0.12.3.md']:
    test((root/name).is_file(),name)
module=get('sim/orbital_industry.gd')
campaign=get('sim/star_campaign.gd')
save=get('sim/campaign_save.gd')
ui=get('orbit/orbital_battle_hud.gd')
visual=get('views/space_map_view.gd')
for k in ['"habitat"','"hydroponie"','"extracteur"','"depot"','"hangar"','"radar"','"batterie"','"arsenal"','"drone"','"sonde"','"navette"','"intercepteur"','"fregate"']:
    test(k in module,'équivalent orbital '+k)
for k in ['_first_site','deploy(','start(','send_fleet(','send_probe(','_arrive(','validate_state(','logistics_bonus(','capacity(','population(']:
    test(k in module, 'mécanique '+k)
for k in ['var orbital_sites:','var orbital_presence:','var orbital_flights:', 'orbital_initial_granted', 'OrbitalIndustry.step(self)', 'OrbitalIndustry.has_hub_in_system', 'func orbital_shipyard(', 'func orbital_send(', 'OrbitalIndustry.logistics_bonus']:
    test(k in campaign,'campagne '+k)
for k in ['"orbital_sites": c.orbital_sites','"orbital_presence": c.orbital_presence','"orbital_flights": c.orbital_flights','"orbital_initial_granted": c.orbital_initial_granted','OrbitalIndustry.validate_state(catalog, data)', 'c.orbital_sites =','c.orbital_initial_granted =']:
    test(k in save,'persistance '+k)
for k in ['Portraits.orbital(', 'OrbitalIndustry.UNITS', 'OrbitalIndustry.MODULES', '_place("hub")', '"action":"train"', '_place("module",kind)', '"action":"upgrade_hub"', '"action":"depart"', '"action":"attack"', 'OrbitalIndustry.send_probe(']:
    test(k in ui,'carte orbitale tactile '+k)
for k in ['_refresh_orbital_glyphs', 'orbital_glyphs', 'BoxMesh.new()']:
    test(k in visual,'rendu '+k)
test(any(v in get('project.godot') for v in ['"0.12.3-j12-orbital-candidate"', '"0.16.0-civilisation-candidate"', '"0.17.0-interface-candidate"', '"0.18.0-ville-candidate"', '"0.18.1-ville-candidate"', '"0.19.0-zonage-candidate"', '"0.20.0-zonage-candidate"']), 'version 0.12.3 ou J13')
test('run/main_scene' in get('project.godot'), 'scène principale')
test(int(get('export_presets.cfg').split('version/code=')[1].splitlines()[0]) >= 123, 'versionCode >= 123')
test('res://lab/j12_orbital_shipyard_test.gd' in get('tools/verify-j12.sh'),'test GDScript branché')
for path in ['sim/orbital_industry.gd','sim/star_campaign.gd','sim/campaign_save.gd','views/space_map_hud.gd','views/space_map_view.gd','lab/j12_orbital_shipyard_test.gd']:
    source=get(path)
    test(not re.search(r'(?m)^(?:<<<<<<<|=======|>>>>>>>)',source) and '\0' not in source and '\r' not in source and not re.search(r'(?m)^ +\S',source),'texte sans conflits/espaces '+path)
    funcs=re.findall(r'^\s*(?:static )?func (\w+)\(',source,re.M)
    test(len(funcs)==len(set(funcs)), 'fonctions uniques '+path)
print('ORBITAL_STATIC=%s checks=%d failures=%d'%('PASS' if all(checks) else 'FAIL',len(checks),sum(not c for c in checks)))
sys.exit(0 if all(checks) else 1)
