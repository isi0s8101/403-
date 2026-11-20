#!/usr/bin/env python3
"""Contrôle statique J12.2; ne tient pas lieu de compilation ni de test Godot."""
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
checks=[]
def check(ok, desc):
 checks.append((bool(ok),desc))
 print(('PASS ' if ok else 'FAIL ')+desc)
def src(path):return (root/path).read_text(encoding='utf8')
m=src('sim/age_progression.gd')
rules=src('sim/rules.gd')
world=src('sim/sim_world.gd')
hud=src('game/hud.gd')
star=src('sim/star_campaign.gd')
save=src('sim/save_game.gd')
for name in ['sim/age_progression.gd','game/tech_appearance.gd','lab/age_progression_test.gd','lab/view_technology_test.gd','README-EVOLUTION-0.12.2.md']:
 check((root/name).is_file(), 'fichier intégré : '+name)
for keyword in ['upgrade_building','building_cost','troop_cost','upgrade_status','start_upgrade','complete_job','apply_unit_level','job_signature','building_hp_multiplier','attack_multiplier','production_multiplier']:
 check(keyword in m, 'règle locale : '+keyword)
for field in ['var evolution: int = 1','var origin_building: int = -1','var tier: int = 1','var unit_evolutions: Dictionary = {}','var upgrade_job: Dictionary = {}']:
 check(field in world,'état sérialisable : '+field)
check('upgrade_troop' in world, 'ordre local upgrade_troop')
for pattern in ['AgeProgression.start_upgrade(self, team_id, cmd)','AgeProgression.step(self)','AgeProgression.apply_unit_level(u, int(b.unit_evolutions.get(ut, 1)))','AgeProgression.attack_multiplier(u.evolution)','AgeProgression.production_multiplier(b.tier)']:
 check(pattern in world,'moteur raccordé : '+pattern)
for pattern in ['_local_upgrade_building.bind(b.id)','_local_upgrade_troop.bind(b.id, ut)','AgeProgression.troop_name','AgeProgression.building_name','AgeProgression.job_signature','ViewTechnology.PATH']:
 check(pattern in hud,'interface tactile et arbre : '+pattern)
for pattern in ['"ship_evolution": ship.evolution','"evolution": u.evolution','flight.get("ship_evolution", 1)','d.get("evolution", 1)']:
 check(pattern in star,'conservation transport : '+pattern)
for field in ['ship_evolution','cargo.has("evolution")']:
 check(field in src('sim/campaign_save.gd'),'validation transport : '+field)
for pattern in ['func fields(','func restore(','var team_data: Array','static func from_snapshot(','record.has("unit_evolutions")','record.has("upgrade_job")']:
 check(pattern in save,'sauvegarde héritée : '+pattern)
for type_name in ['ouvrier','eclaireur','lancier','tireur','cavalier','canon','caravane','fusilier','obusier','grenadier','char','avion','antiaerien','train','lance_missiles','drone','brouilleur','navette','fregate']:
 check(f'"{type_name}": [' in m and f'"{type_name}":' in rules,'trois styles : '+type_name)
for type_name in ['centre','caserne','atelier','usine','aerodrome','gare','spatioport','chantier_orbital','marche','fort']:
 check(f'"{type_name}": [' in m,'style bâtiment : '+type_name)
for pattern in ['TechAppearance.decorate','UnitVisual.set_evolution','BuildingVisual.set_evolution']:
 check(pattern in src('game/world_view.gd') or pattern in src('game/unit_visual.gd') or pattern in src('game/building_visual.gd'),'rendu évolutions : '+pattern)
for pattern in ['AgeProgression.upgrade_status','SaveGame.from_snapshot','AgeProgression.apply_unit_level','w.issue({"t":"upgrade_building"']:
 check(pattern in src('lab/age_progression_test.gd'),'recette intégrée : '+pattern)
for pattern in ['if _home_port == null:', 'if yard == null:']:
 check(pattern in src('lab/recette_suite.gd'), 'gardes recette corrigées : '+pattern)
check('res://lab/age_progression_test.gd' in src('tools/verify-j12.sh'),'exécution test de régression prévue')
check(any(v in src('project.godot') for v in ['0.12.3-j12-orbital-candidate', '0.16.0-civilisation-candidate', '0.17.0-interface-candidate', '0.18.0-ville-candidate', '0.18.1-ville-candidate', '0.19.0-zonage-candidate', '0.20.0-zonage-candidate']),'version 0.12.3 ou J13')
check(int(src('export_presets.cfg').split('version/code=')[1].splitlines()[0]) >= 123,'versionCode Android >= 123')
# JSON-like GDScript delimiter and indentation heuristics; no claim to parse Godot.
for filename in ['sim/age_progression.gd','game/tech_appearance.gd','lab/age_progression_test.gd','lab/view_technology_test.gd','lab/recette_suite.gd','game/recette_screen.gd','lab/recette_integrale_test.gd']:
 content=src(filename)
 check(not re.search(r'(?m)^ +[^ #\n]',content) and '\0' not in content and '\r' not in content and not re.search(r'(?m)^(?:<<<<<<<|=======|>>>>>>>)',content),'texte tabulé sans conflit : '+filename)
errors=[title for ok,title in checks if not ok]
print(f'EVOLUTION_STATIC_RESULT={"PASS" if not errors else "FAIL"} checks={len(checks)} failures={len(errors)}')
sys.exit(1 if errors else 1 if not checks else 0)
