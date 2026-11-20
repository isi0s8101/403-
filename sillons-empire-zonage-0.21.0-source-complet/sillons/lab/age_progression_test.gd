extends SceneTree
## Tests d'exécution de l'arbre d'âges, locaux aux bâtiments. A lancer sous Godot.
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + message)

func _initialize() -> void:
	var w := SimWorld.new()
	w.setup(817261, {"max_age": 10})
	w.start_standard()
	var a: SimWorld.Team = w.teams[0] as SimWorld.Team
	a.res = {"food": 100000.0, "wood": 100000.0, "ore": 100000.0}
	a.age = 1
	var barracks: SimWorld.Building = w.spawn_building(0, "caserne", Vector2i(19, 65), true)
	var second: SimWorld.Building = w.spawn_building(0, "caserne", Vector2i(27, 65), true)
	check(not AgeProgression.upgrade_status(w, 0, barracks, "building")["ok"], "Niveau II interdit à l'âge I")
	check(not w.issue({"t":"upgrade_troop", "team":0, "building":barracks.id, "unit":"fregate"})["ok"], "Bâtiment non producteur interdit")
	a.age = 2
	check(w.issue({"t":"upgrade_building", "team":0, "building":barracks.id})["ok"], "Caserne renforcée achetable")
	check(not w.issue({"t":"upgrade_building", "team":0, "building":barracks.id})["ok"], "Recherche locale concurrente interdite")
	for i in 310:
		AgeProgression.step(w)
	check(barracks.tier == 2 and second.tier == 1, "Amélioration limitée à une seule caserne")
	check(w.issue({"t":"upgrade_troop", "team":0, "building":barracks.id, "unit":"lancier"})["ok"], "Amélioration lanciers déclenchée")
	for i in 250:
		AgeProgression.step(w)
	check(int(barracks.unit_evolutions.get("lancier", 1)) == 2, "Niveau d'équipement local acquis")
	check(w.issue({"t":"train", "team":0, "building":barracks.id, "unit":"lancier"})["ok"], "Production d'un lancier modernisé acceptée")
	for i in 125:
		w._production_and_research()
	var found_produced: bool = false
	for candidate in w.units.values():
		if candidate.team == 0 and candidate.type == "lancier" and candidate.origin_building == barracks.id and candidate.evolution == 2:
			found_produced = true
	check(found_produced, "Une troupe issue de la caserne hérite de son style")
	check(int(second.unit_evolutions.get("lancier", 1)) == 1, "Autre caserne indépendante")
	var u: SimWorld.Unit = w.spawn_unit(0, "lancier", Vector2(21.0, 64.0))
	u.origin_building = barracks.id
	AgeProgression.apply_unit_level(u, int(barracks.unit_evolutions["lancier"]))
	check(u.evolution == 2 and u.max_hp > float(Rules.UNITS["lancier"]["hp"]), "Unité équipée et statistiques augmentées")
	check(not w.issue({"t":"upgrade_troop", "team":1, "building":barracks.id, "unit":"lancier"})["ok"], "L'ennemi ne peut pas améliorer nos troupes")
	check(not w.issue({"t":"upgrade_troop", "team":0, "building":barracks.id, "unit":"lancier"})["ok"], "Niveau III refusé avant l'âge III")
	var opponent: SimWorld.Unit = w.spawn_unit(1, "lancier", Vector2(80.0, 80.0))
	var shot: float = w._damage_value(u, opponent)
	check(shot > 0.0, "Dégâts d'évolution calculables")
	var restored: SimWorld = SaveGame.from_snapshot(SaveGame.snapshot(w))
	check(restored != null, "Sauvegarde restaurée")
	if restored != null:
		var b2: SimWorld.Building = restored.buildings.get(barracks.id) as SimWorld.Building
		var u2: SimWorld.Unit = restored.units.get(u.id) as SimWorld.Unit
		check(b2 != null and b2.tier == 2 and int(b2.unit_evolutions.get("lancier", 1)) == 2, "Niveaux des bâtiments persistants")
		check(u2 != null and u2.evolution == 2, "Niveaux individuels des unités persistants")
	print("AGE_TREE_RESULT=%s checks=%d fails=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
