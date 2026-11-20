#!/usr/bin/env python3
"""0.18 — Contrôle statique de la ville de l'âge de l'électricité et du jeu en portrait. 0.19 : zonage, routes, croissance."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
failures = 0


def check(ok, label):
    global failures
    failures += int(not ok)
    print(('PASS ' if ok else 'FAIL ') + label)


def src(name):
    return (ROOT / name).read_text(encoding='utf-8')


NEW = ['sim/urban_rules.gd', 'sim/urban_city.gd', 'sim/urban_ai.gd', 'interface/city_panel.gd', 'interface/city_overlay.gd',
       'interface/responsive_layout.gd', 'lab/urban_city_test.gd', 'lab/ui_city_test.gd', 'lab/ui_portrait_test.gd']
check(all((ROOT / n).is_file() for n in NEW), 'fichiers 0.18 présents (%d)' % len(NEW))
check(any(v in src('project.godot') for v in ['"0.18.0-ville-candidate"', '"0.18.1-ville-candidate"', '"0.19.0-zonage-candidate"', '"0.20.0-zonage-candidate"']) and any(v in src('export_presets.cfg') for v in ['version/code=180', 'version/code=181', 'version/code=190', 'version/code=200']), 'version 0.18.x à 0.20.0 / code 180 à 200')
check(re.search(r'^window/handheld/orientation=6$', src('project.godot'), re.M) is not None, 'orientation capteur (paysage et portrait)')
rules = src('sim/rules.gd')
for kind in ['zone_r', 'zone_c', 'zone_i', 'centrale', 'chateau_eau', 'commissariat', 'caserne_pompiers', 'hopital', 'decharge']:
    check('"%s"' % kind in rules, 'bâtiment urbain déclaré : %s' % kind)
check('"electricite"' in rules and 'electricite' in src('sim/urban_rules.gd'), 'recherche Électricité déclarée')
city = src('sim/urban_city.gd')
for word in ['crime', 'fire', 'health', 'pollution', 'water', 'power', 'happiness']:
    check(word in city, 'simulation de la ville : %s' % word)
# Tirages déterministes : aucun hasard non reproductible dans la simulation de la ville.
check(not re.search(r'\b(randf|randi|randf_range|randi_range|RandomNumberGenerator|Time\.get_)', city + src('sim/urban_ai.gd') + src('sim/urban_rules.gd')),
      'ville sans hasard ni horloge (partie reproductible)')
# Aucun privilège pour l'IA : elle passe par world.issue comme le joueur.
ai = src('sim/urban_ai.gd')
check('issue(' in ai and 'spawn_building' not in ai and not re.search(r'\.res\[[^\]]*\]\s*[-+*/]?=(?!=)', ai),
      "IA de la ville : mêmes commandes que le joueur (aucune ressource ni bâtiment donné directement)")
# Aucun contenu repris d'un jeu existant : pas de nom de jeu dans le code ni dans les ressources.
text_files = [p for p in ROOT.rglob('*') if p.suffix in ('.gd', '.tscn', '.cfg', '.json') and '.godot' not in p.parts]
check(not any(re.search(r'theo\s*town', p.read_text(encoding='utf-8', errors='ignore'), re.I) for p in text_files),
      "aucun nom ni texte d'un jeu existant dans le projet")
hud = src('game/hud.gd')
check('apply_orientation' in hud and '_portrait_specs' in hud, 'HUD tactique : mise en page portrait')
for name in ['game/main_menu.gd', 'views/planet_hud.gd', 'orbit/orbital_battle_hud.gd', 'game/planet_start.gd']:
    check('ResponsiveLayout' in src(name), 'écran adapté au portrait : %s' % name)
# 0.19 — Zonage dynamique : fichiers, déterminisme, aucun privilège, commandes validées, migration.
NEW19 = ['sim/urban_zoning.gd', 'sim/urban_growth.gd', 'game/urban_visual.gd', 'interface/zoning_tool.gd', 'interface/zoning_panel.gd',
         'lab/zoning_test.gd', 'lab/ui_zoning_test.gd']
check(all((ROOT / n).is_file() for n in NEW19), 'fichiers 0.19 présents (%d)' % len(NEW19))
zoning = src('sim/urban_zoning.gd')
growth = src('sim/urban_growth.gd')
check(not re.search(r'\b(randf|randi|randf_range|randi_range|RandomNumberGenerator|Time\.get_)', zoning + growth),
      'zonage et croissance sans hasard ni horloge (partie reproductible)')
for command in ['zone_paint', 'zone_clear', 'road_paint', 'road_remove', 'zone_historic']:
    check('"%s"' % command in zoning, 'commande validée par la simulation : %s' % command)
check('_migrate' in zoning and 'LEGACY_CODE' in zoning, 'conversion des parties 0.18 (zones posées → parcelles zonées)')
tool = src('interface/zoning_tool.gd')
check('issue(' in tool and 'spawn_building' not in tool and '.zoning[' not in tool, "outil de zonage : passe par les commandes (n'écrit jamais l'état)")
check('road_tex' in src('game/realism/terrain.gdshader') and 'zone_tex' in src('game/realism/terrain.gdshader'), 'routes et calque du zonage dessinés par le terrain (sans géométrie ajoutée)')
check('"zoned": true' in rules, 'zones résidentielles, commerciales, industrielles : plus de pose manuelle')
# 0.20 — LOT B : événements, villes lointaines, résumés, filtres, IA avant l'électricité.
NEW20 = ['sim/urban_events.gd', 'sim/urban_abstract.gd', 'lab/urban_lotb_test.gd', 'tools/profile-urban.gd']
check(all((ROOT / n).is_file() for n in NEW20), 'fichiers 0.20 présents (%d)' % len(NEW20))
events = src('sim/urban_events.gd')
abstract = src('sim/urban_abstract.gd')
check(not re.search(r'\b(randf|randi|randf_range|randi_range|RandomNumberGenerator|Time\.get_)', events + abstract),
      'événements et villes lointaines sans hasard ni horloge (partie reproductible)')
check(all(k in events for k in ['"seisme"', '"inondation"', '"tempete"', '"crise"', '"migration"']) and 'GRACE_TICKS' in events,
      'événements : séisme, inondation, tempête, crise, migration ; délai de grâce')
check('spawn_building' not in events and 'spawn_building' not in abstract, 'événements et résumés : aucun bâtiment créé hors des règles')
check('static var time_scale' in city and 'FAR_EVERY' in src('sim/urban_rules.gd') and 'urban_far' in src('sim/sim_world.gd'),
      'ville lointaine : calcul abrégé avec échelle de temps')
check('think_early' in src('sim/urban_ai.gd') and 'UrbanAI.think_early' in src('sim/ai_controller.gd'), "IA : zonage avant l'électricité, par les mêmes commandes")
check('"population"' in src('interface/city_overlay.gd') and 'FILTERS' in src('interface/city_overlay.gd') and 'cycle_filter' in src('interface/zoning_panel.gd'),
      'filtres de la carte : population, densité, criminalité, prospérité, production, pollution, état, incidents, infrastructures, zonage')
print('URBAIN_STATIC=%s failures=%d' % ('PASS' if failures == 0 else 'FAIL', failures))
raise SystemExit(1 if failures else 0)
