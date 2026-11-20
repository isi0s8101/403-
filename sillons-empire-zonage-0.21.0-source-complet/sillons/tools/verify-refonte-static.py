#!/usr/bin/env python3
"""Contrôle reproductible de l'archive : suites historiques, empreintes, conservation du simulateur."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CHECKS = ['j678', 'recette', 'fix082', 'j9', 'j9-complete', 'j10', 'j11', 'j12', 'evolution', 'orbital', 'j13', 'interface', 'urbain']
failures = 0
for name in CHECKS:
    result = subprocess.run([sys.executable, '-I', str(ROOT / 'tools' / ('verify-' + name + '-static.py'))], cwd=ROOT, capture_output=True, text=True)
    print(('PASS ' if result.returncode == 0 else 'FAIL ') + name)
    if result.returncode:
        failures += 1
        print(result.stdout[-4000:])
        print(result.stderr[-1000:])
manifest = ROOT / 'game-studio/baseline-0.13.2-sim.sha256'
baseline_ok = manifest.is_file()
# La 0.14 modifie explicitement la simulation : les scénarios historiques vérifient
# le comportement, cette liste vérifie l'étendue de la modification du socle.
authorized = {'sim/sim_world.gd','sim/sim_map.gd','sim/ai_controller.gd','sim/modern_systems.gd','sim/planet_campaign.gd','sim/star_campaign.gd','sim/save_game.gd','sim/campaign_save.gd','sim/orbital_industry.gd','sim/planet_governor.gd'}
# 0.16 : évolution de la civilisation — données (rules.gd, j13_rules.gd) et crochets d'une ligne (age_progression.gd).
authorized |= {'sim/rules.gd','sim/j13_rules.gd','sim/age_progression.gd'}
changed = []
if baseline_ok:
    for row in manifest.read_text().splitlines():
        expected, name = row.split('  ', 1)
        target = ROOT / name
        if not target.is_file(): baseline_ok = False
        elif hashlib.sha256(target.read_bytes()).hexdigest() != expected:
            changed.append(name)
            if name not in authorized: baseline_ok = False
print(('PASS ' if baseline_ok else 'FAIL ') + 'socle conservé, modifications de simulation déclarées : ' + ', '.join(changed))
failures += int(not baseline_ok)
assets = json.loads((ROOT.parent / 'sources-3d/manifest.json').read_text())['assets']
asset_ok = len(assets) == 800
for asset in assets:
    paths = [asset['model_path']] + asset['lod_paths']
    for name, digest in zip(paths, asset['sha256'], strict=True):
        target = ROOT.parent / 'sources-3d' / name
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            asset_ok = False
            print('FAIL modèle ' + name)
print(('PASS ' if asset_ok else 'FAIL ') + '800 modèles et 2400 GLB conformes au catalogue')
failures += int(not asset_ok)
mobile = subprocess.run([sys.executable, '-I', str(ROOT / 'tools/verify-mobile-import-static.py')], cwd=ROOT, capture_output=True, text=True)
print(mobile.stdout, end='')
if mobile.returncode:
    failures += 1
    print(mobile.stderr)
realism = subprocess.run([sys.executable, '-I', str(ROOT / 'tools/verify-realism-static.py')], cwd=ROOT, capture_output=True, text=True)
print(realism.stdout, end='')
if realism.returncode:
    failures += 1
    print(realism.stderr)
print('REFONTE_STATIC=%s suites=%d failures=%d' % ('PASS' if failures == 0 else 'FAIL', len(CHECKS) + 4, failures))
sys.exit(0 if failures == 0 else 1)
