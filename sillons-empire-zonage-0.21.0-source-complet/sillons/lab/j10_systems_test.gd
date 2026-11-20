extends SceneTree
## J10 : déterminisme du catalogue, mondes chargés à la demande, missions et sauvegardes.
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _port(w: SimWorld, team: int, kind: String) -> SimWorld.Building:
	var home: Vector2 = (w.team_buildings(team, "centre", true)[0] as SimWorld.Building).center
	for y in range(5, 90):
		for x in range(5, 90):
			var p := Vector2i(x, y)
			if home.distance_to(Vector2(p)) < 19.0 and w.footprint_free(p, 4) and w.has_margin(p, 4):
				return w.spawn_building(team, kind, p, true)
	return null

func _initialize() -> void:
	var seed: int = 1102026
	var a := StarSystemGenerator.new(seed)
	var b := StarSystemGenerator.new(seed)
	var other := StarSystemGenerator.new(seed + 1)
	check(a.signature() == b.signature(), "catalogue identique pour une graine identique")
	check(a.signature() != other.signature(), "graines distinctes produisent des systemes differents")
	check(a.systems.size() >= 2 and a.ordered.size() >= 7, "Sol et Proxima, planètes et lunes (J11 étend le catalogue)")
	check(a.has_body("val") and a.has_body("aurore") and a.has_body("nemesis"), "mondes historiques conserves")
	var unique: Dictionary = {}
	var valid: bool = true
	for key in a.ordered:
		var id: String = String(key)
		if unique.has(id):
			valid = false
		unique[id] = true
		var desc: Dictionary = a.info(id)
		if not is_finite(float(desc["orbit"])) or not is_finite(float(desc["size"])) or float(desc["orbit"]) <= 0:
			valid = false
		if String(desc["parent"]) != "" and not a.has_body(String(desc["parent"])):
			valid = false
		var loc: Vector2 = a.body_position(id, 43210)
		if not loc.is_finite():
			valid = false
	check(valid, "IDs uniques, orbites finies et lunes rattachees")
	var c := StarCampaign.new()
	c.create(seed, false, true)
	check(c.worlds.size() == 3 and c.star_catalog.signature() == a.signature(), "J9 et catalogue J10 coexistent sans nouveaux mondes charges")
	check(not c.is_unlocked(0, "sol_p0") and not c.switch_to(0, "sol_p0"), "planetes procedurales fermees avant IX")
	c.ages[0] = 9
	c.resources[0] = {"food": 100000.0, "wood": 100000.0, "ore": 100000.0}
	c._sync_all()
	check(c.is_unlocked(0, "sol_p0") and not c.is_unlocked(0, "prox_p0"), "expansion locale IX et distante X")
	var target: SimWorld = c.materialize("sol_p0")
	check(target != null and bool(target.rules.get("planet_j9", false)) and target.team_buildings(0, "centre", true).is_empty(), "planete generee sans colonie fictive")
	check(c.materialize("sol_p0") == target, "instance du monde persistante et non dupliquee")
	var home: SimWorld = c.worlds["val"]
	var launch: SimWorld.Building = _port(home, 0, "spatioport")
	check(launch != null, "plateforme de depart disponible")
	if launch != null:
		var ship: SimWorld.Unit = home.spawn_unit(0, "navette", launch.center + Vector2(2, 2))
		var worker: SimWorld.Unit = home.spawn_unit(0, "ouvrier", launch.center + Vector2(3, 3))
		var before: int = int(home.teams[0].stats["losses"])
		var flight: Dictionary = c.dispatch(0, "val", launch.id, "sol_p0", [worker.id], ship.id)
		check(bool(flight.get("ok", false)) and c.flights.size() == 1, "mission vers planete procedurale au lieu d'un teleport")
		check(int(home.teams[0].stats["losses"]) == before, "embarquement sans pertes de combat")
		var saved: Dictionary = CampaignSave.snapshot(c)
		var restored: StarCampaign = CampaignSave.from_snapshot(saved)
		check(restored != null and restored.state_hash() == c.state_hash(), "sauvegarde J10 avec destination et vol en cours")
		if restored != null:
			for index in 164:
				c.step()
				restored.step()
			check(c.state_hash() == restored.state_hash(), "reprise deterministe au terme de la mission")
			check(not target.team_buildings(0, "centre", true).is_empty(), "colonie fondee sur nouvelle planete")
			check(target.team_units(0, "builder").size() > 0, "ouvrier debarque vivant")
		var invalid: Dictionary = saved.duplicate(true)
		invalid["extra_maps"]["cle_inconnue"] = saved["extra_maps"]["sol_p0"]
		check(CampaignSave.from_snapshot(invalid) == null, "monde externe falsifie refuse")
		invalid = saved.duplicate(true)
		invalid["star_catalog_version"] = 999
		check(CampaignSave.from_snapshot(invalid) == null, "generation future inconnue refusee")
		invalid = saved.duplicate(true)
		invalid["extra_maps"]["sol_p0"]["seed"] = 9876
		check(CampaignSave.from_snapshot(invalid) == null, "seed de monde falsifie refusee")
	c.ages[0] = 10
	c._sync_all()
	check(c.is_unlocked(0, "prox_p0"), "systeme Proxima accessible a X")
	check(c.switch_to(0, "prox_p0") and c.active == "prox_p0", "camera peut rejoindre une planete distante")
	check(c.materialize("prox_p0") == c.worlds["prox_p0"], "monde de systeme different conserve")
	# Ancienne sauvegarde sans nouveaux mondes : test sur une campagne historique autonome.
	var old := StarCampaign.new()
	old.create(8971, false, false)
	var previous: Dictionary = CampaignSave.snapshot(old)
	previous.erase("extra_maps")
	previous.erase("star_catalog_version")
	var older: StarCampaign = CampaignSave.from_snapshot(previous)
	check(older != null and older.state_hash() == old.state_hash(), "ancienne sauvegarde 0.9.1 toujours lisible")
	print("J10_SYSTEMS_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
