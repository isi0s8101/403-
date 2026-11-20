#!/usr/bin/env python3
"""Intégrité et séparation des sources lourdes du projet destiné à Android."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / 'sources-3d'
results = []

def check(ok, label):
    results.append(bool(ok))
    print(('PASS ' if ok else 'FAIL ') + label)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

try:
    metadata = json.loads((ROOT / 'data/native-package.json').read_text())
    pack = ROOT / 'data/assets_3d.pck'
    check(pack.is_file() and pack.stat().st_size == metadata['bytes'] and digest(pack) == metadata['sha256'], 'paquet natif complet et SHA-256 exact')
    check(not any(ROOT.rglob('*.glb')), 'aucun GLB dans res://')
    check(not (ROOT / 'assets_3d_native').exists(), 'aucune bibliothèque native libre à analyser par l’éditeur')
    check(SOURCE.is_dir() and not SOURCE.is_relative_to(ROOT), 'sources 3D conservées hors du projet jouable')
    check(len(list(SOURCE.rglob('*.glb'))) == 2430, '2430 GLB source conservés, dont 2400 niveaux du catalogue')
    check(digest(SOURCE / 'manifest.json') == metadata['source_manifest_sha256'], 'catalogue source correspondant au paquet')
    report = json.loads((ROOT / 'game-studio/preuves/import-mobile-0.13.4/native-library.json').read_text())
    check(report['prepared'] and report['self_contained'] and report['models'] == metadata['models'] == 800 and report['scenes'] == metadata['scenes'] == 2400 and report['textures'] == metadata['images'] == 174, '800 modèles, 2400 scènes, 174 images prêts')
    source_files = json.loads((SOURCE / 'manifest.json').read_text())['assets']
    expected = {name: sha for asset in source_files for name, sha in zip([asset['model_path']] + asset['lod_paths'], asset['sha256'], strict=True)}
    actual = {entry['source_path']: entry['source_sha256'] for entry in report['files']}
    check(expected == actual, 'correspondance complète entre scènes natives et GLB du catalogue')
    check('*.pck' in (ROOT / 'export_presets.cfg').read_text(), 'paquet inclus dans le filtre d’export Android')
    check((ROOT / 'game-studio/.gdignore').is_file(), 'preuves et anciennes captures exclues du scan d’assets')
except (OSError, ValueError, KeyError, TypeError) as error:
    check(False, str(error))

print('MOBILE_IMPORT_STATIC=%s checks=%d failures=%d' % ('PASS' if all(results) else 'FAIL', len(results), sum(not result for result in results)))
sys.exit(0 if all(results) else 1)
