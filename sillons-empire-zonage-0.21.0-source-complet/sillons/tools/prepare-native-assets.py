#!/usr/bin/env python3
"""Prépare le paquet 3D sur un poste de développement ; aucun module Python externe."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]

def relative_file(value: str) -> Path:
    path = PurePosixPath(value)
    if path.is_absolute() or '..' in path.parts or '\\' in value or ':' in value:
        raise ValueError('Chemin de catalogue invalide : ' + value)
    return Path(*path.parts)

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    parser.add_argument('--source', type=Path, default=ROOT.parent / 'sources-3d')
    parser.add_argument('--output', type=Path, default=ROOT / 'data/assets_3d.pck')
    parser.add_argument('--replace', action='store_true', help='Sauvegarder le paquet existant avant remplacement atomique.')
    parser.add_argument('--timeout', type=int, default=1200)
    args = parser.parse_args()
    if not 60 <= args.timeout <= 7200:
        parser.error('--timeout doit être compris entre 60 et 7200 secondes.')
    binary = shutil.which(args.godot)
    if not binary:
        parser.error('Godot 4.7.2 introuvable.')
    source = args.source.resolve(strict=True)
    if args.output.is_symlink():
        parser.error('La sortie ne doit pas être un lien symbolique.')
    output = args.output.resolve()
    if source == output:
        parser.error('Sortie invalide.')
    if output.exists() and not args.replace:
        parser.error('Paquet déjà présent et prêt à jouer ; --replace est réservé à sa régénération.')
    manifest = json.loads((source / 'manifest.json').read_text())
    materials = json.loads((source / 'materials/materials.json').read_text())
    if len(manifest.get('assets', [])) != 800:
        parser.error('800 modèles attendus dans le catalogue.')
    files = {'manifest.json', 'materials/materials.json'}
    for record in manifest['assets']:
        paths = [record['model_path']] + record['lod_paths']
        for name, expected in zip(paths, record['sha256'], strict=True):
            path = source / relative_file(name)
            if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                parser.error('GLB modifié sans mise à jour du catalogue : ' + name)
            files.add(name)
    for definition in materials['materials'].values():
        files.update(definition['textures'].values())
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='native-preparation-', dir=output.parent) as temporary:
        stage = Path(temporary)
        project = stage / 'project'
        project.mkdir()
        (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Sillons Native Preparation"\nconfig/features=PackedStringArray("4.7", "Mobile")\n[animation]\ncompatibility/default_parent_skeleton_in_mesh_instance_3d=true\n[rendering]\nrenderer/rendering_method="mobile"\n')
        for name in sorted(files):
            destination = project / 'assets_3d' / relative_file(name)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / relative_file(name), destination)
        for name in ['prepare-native-assets.gd', 'pack-native-assets.gd']:
            shutil.copyfile(ROOT / 'tools' / name, project / name)
        native = stage / 'native'
        packed = stage / 'assets_3d.pck'
        commands = [
            [binary, '--headless', '--path', str(project), '--editor', '--quit'],
            [binary, '--headless', '--path', str(project), '--script', 'res://prepare-native-assets.gd', '--', str(native)],
            [binary, '--headless', '--path', str(project), '--script', 'res://pack-native-assets.gd', '--', str(native), str(packed)],
        ]
        for index, command in enumerate(commands, 1):
            result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
            (output.parent / ('native-build-step-%d.log' % index)).write_text(result.stdout + result.stderr)
            if result.returncode or any(marker in result.stdout + result.stderr for marker in ['SCRIPT ERROR', 'Parse Error', 'Compile Error', '\nERROR:']):
                raise RuntimeError('Préparation arrêtée à l’étape %d ; consulter le journal.' % index)
        report = json.loads((native / 'native-library.json').read_text())
        if not report.get('prepared') or report['scenes'] != 2400 or report['textures'] != 174:
            raise RuntimeError('Bibliothèque incomplète ; paquet précédent conservé.')
        if output.exists():
            stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
            backup = output.with_name(output.name + '.' + stamp + '.bak')
            shutil.copy2(output, backup)
        os.replace(packed, output)
        metadata = {'schema': 1, 'file': output.name, 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'bytes': output.stat().st_size,
                    'scenes': 2400, 'images': 174, 'models': 800, 'source_manifest_sha256': report['source_manifest_sha256'], 'engine': report['engine']}
        temporary_metadata = output.parent / 'native-package.json.tmp'
        temporary_metadata.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
        os.replace(temporary_metadata, output.parent / 'native-package.json')
        print('NATIVE_LIBRARY_BUILD=PASS ' + str(output))

if __name__ == '__main__':
    main()
