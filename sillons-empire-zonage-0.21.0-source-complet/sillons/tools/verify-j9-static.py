#!/usr/bin/env python3
"""Contrôles de structure et de câblage J9, sans prétendre exécuter GDScript."""
from pathlib import Path
import re, sys
root = Path(__file__).resolve().parents[1]
checks = []
def expect(ok, label):
    checks.append((bool(ok), label))
    print(('PASS' if ok else 'FAIL') + ' ' + label)

def source(rel):
    p = root / rel
    return p.read_text(encoding='utf-8') if p.is_file() else ''

required = [
    'procgen/planet_generator.gd','streaming/terrain_chunk_streamer.gd',
    'views/planet_globe_view.gd','views/planet_hud.gd',
    'game/planet_start.gd','game/planet_start.tscn',
    'lab/j9_planet_test.gd','README-J9.md',
]
for name in required:
    expect((root/name).is_file(), 'présence '+name)
expect(any(v in source('project.godot') for v in ['0.9.0-j9-candidate', '0.9.1-j9-completion-candidate', '0.10.0-j10-candidate', '0.11.0-j11-candidate', '0.12.3-j12-orbital-candidate', '0.16.0-civilisation-candidate', '0.17.0-interface-candidate', '0.18.0-ville-candidate', '0.18.1-ville-candidate', '0.19.0-zonage-candidate', '0.20.0-zonage-candidate']), 'version J9 explicitement candidate')
expect('class_name PlanetGenerator' in source('procgen/planet_generator.gd'), 'générateur identifié')
expect('get_noise_3dv' in source('procgen/planet_generator.gd'), 'relief sur sphère (bruit 3D sans jointure de longitude)')
expect('GENERATOR_VERSION: int = 1' in source('procgen/planet_generator.gd'), 'version du générateur fixée')
expect('region_seed(' in source('procgen/planet_generator.gd'), 'graine de région indépendante du chargement')
expect('tactical_decorate' in source('procgen/planet_generator.gd'), 'départ tactique conservateur et symétrique')
expect('"planet_j9"' in source('sim/sim_world.gd'), 'mode procédural opt-in dans SimWorld')
expect('planet_j9: bool = false' in source('sim/star_campaign.gd'), 'mode J9 optionnel, compatibilité J1-J8')
expect('"user://sillons-j9-planet.save"' in source('game/game.gd'), 'slot J9 indépendant')
expect('"user://sillons-j9-planet.save"' in source('game/main_menu.gd'), 'reprise slot J9')
expect('res://game/planet_start.tscn' in source('game/main_menu.gd'), 'entrée menu vers planète')
expect('res://game/main_menu.tscn' in source('game/planet_start.gd'), 'retour au menu possible')
expect('PlanetGenerator.OCEAN' in source('game/planet_start.gd'), 'départ en mer refusé')
expect('enter_planet_overview()' in source('game/game.gd'), 'entrée atlas par dézoom')
expect('leave_planet_overview()' in source('game/game.gd'), 'retour à la tactique')
expect('touches.clear()' in source('game/game.gd'), 'gestes tactiques remis à zéro lors de la transition')
expect('CHUNK_SIZE: int = 24' in source('streaming/terrain_chunk_streamer.gd'), 'chunks dimensionnés sur la grille historique')
expect('BUILDS_PER_FRAME: int = 2' in source('streaming/terrain_chunk_streamer.gd'), 'quota de création par image')
expect('MAX_RESIDENT: int = 16' in source('streaming/terrain_chunk_streamer.gd'), 'borne cache mémoire')
expect('_height(' in source('streaming/terrain_chunk_streamer.gd'), 'hauteurs de sommets communes aux chunks')
expect('terrain_streamer.update_focus(' in source('game/world_view.gd'), 'flux caméra -> streaming')
expect('Assets.build_terrain(world)' in source('game/world_view.gd'), 'rendu historique préservé')
expect('biome_tint' in source('game/assets.gd'), 'teinte de biome dans matériaux tactiques')
expect('1000' in source('lab/j9_planet_test.gd'), 'batterie multi-graine définie')
expect('SaveGame.from_snapshot' in source('lab/j9_planet_test.gd'), 'test de sauvegarde tactique prévu')
expect('CampaignSave.from_snapshot' in source('lab/j9_planet_test.gd'), 'test sauvegarde campagne prévu')
expect('J9_TEST_RESULT' in source('lab/j9_planet_test.gd'), 'test Godot doté du code de sortie')
for name in ['game/planet_start.tscn','game/game.tscn']:
    for path in re.findall(r'path="(res://[^"]+)"', source(name)):
        expect((root/path[6:]).is_file(), f'ressource existante dans {name}: {path}')
for folder in ['procgen', 'streaming', 'views', 'game', 'sim', 'lab']:
    for p in sorted((root/folder).glob('*.gd')):
        new = p.name in {'planet_generator.gd','terrain_chunk_streamer.gd','planet_globe_view.gd','planet_hud.gd','planet_start.gd','j9_planet_test.gd'}
        if not new:
            continue
        data = p.read_text()
        lines = data.splitlines()
        expect(all(not l.startswith(' ') for l in lines if l.strip()) and '\r' not in data, 'indentation tabulation: '+p.name)
        expect(all(not l.rstrip().endswith('=') for l in lines), 'aucune affectation tronquée: '+p.name)
failed=[label for ok,label in checks if not ok]
print(f'J9_STATIC_RESULT={"PASS" if not failed else "FAIL"} checks={len(checks)} failures={len(failed)}')
sys.exit(1 if failed else 0)
