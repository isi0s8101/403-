extends SceneTree
## J9 complet : scénarios de continuité planétaire, déterminisme et sauvegardes.
## Exécution : godot --headless --path . --script res://lab/j9_regions_test.gd
var total: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	total += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + message)

func _edge_pair(world: SimWorld, adjacent: SimWorld, direction: Vector2i) -> Vector2i:
	for i in range(1, Rules.MAP_SIZE - 1):
		var a: Vector2i = Vector2i(Rules.MAP_SIZE - 1 if direction.x > 0 else 0, i) if direction.x != 0 else Vector2i(i, Rules.MAP_SIZE - 1 if direction.y > 0 else 0)
		var b: Vector2i = Vector2i(0 if direction.x > 0 else Rules.MAP_SIZE - 1, i) if direction.x != 0 else Vector2i(i, 0 if direction.y > 0 else Rules.MAP_SIZE - 1)
		if world.walkable(a) and adjacent.walkable(b):
			return a
	return Vector2i(-1, -1)

func _initialize() -> void:
	var seed: int = 471901
	var gen := PlanetGenerator.new(seed)
	var identical: bool = true
	for ry in [2, 64, 128, 253]:
		for rx in [0, 17, 256, 511]:
			for xy in [0, 12, 48, 96]:
				var e: float = gen.region_elevation(rx, ry, 96.0, float(xy))
				var next_e: float = gen.region_elevation(posmod(rx + 1, 512), ry, 0.0, float(xy))
				if absf(e - next_e) > 0.000001:
					identical = false
				var n: float = gen.region_elevation(rx, ry, float(xy), 96.0)
				var south: float = gen.region_elevation(rx, ry + 1, float(xy), 0.0)
				if absf(n - south) > 0.000001:
					identical = false
	check(identical, "hauteurs strictement continues N/S et E/O avec couture de longitude")
	var launch: Vector2 = Vector2.ZERO
	var found_land: bool = false
	for row in 14:
		if found_land:
			break
		for col in 24:
			var candidate: Vector2 = PlanetGenerator.lon_lat_from_pixel(col * 19, row * 18)
			if float(gen.sample(candidate.x, candidate.y)["height"]) > 0.15:
				launch = candidate
				found_land = true
				break
	check(found_land, "région de départ continentale identifiée")
	var c := StarCampaign.new()
	c.create(seed, false, true, launch.x, launch.y)
	check(c.planet_regions != null, "gestionnaire planétaire installé")
	var home: SimWorld = c.worlds["val"]
	check(bool(home.rules.get("planet_region_grid", false)), "régions procédurales actives")
	check(home.team_buildings(0, "centre", true).size() == 1, "centre joueur préservé")
	check(home.team_buildings(1, "centre", true).size() == 1, "centre IA préservé")
	check(not home.nodes.is_empty(), "ressources régionales présentes")
	check(home.team_buildings(SimWorld.TEAM_NEUTRAL, "comptoir", true).size() >= 2,
		"comptoirs neutres présents pour le passage à l'âge II")
	check(String((home.rules["age_up_3"] as Dictionary)["objective"]) == "tenir_frontiere",
		"âge III adapte à la géographie procédurale sans fausses rivières")
	var home_coord: Vector2i = c.planet_regions.active
	var source_hash: String = home.state_hash()
	var center: Vector2 = PlanetGenerator.region_center(home_coord.x, home_coord.y)
	check(PlanetGenerator.region_coords(center.x, center.y) == home_coord, "aller-retour atlas et coordonnées")
	var no_op: Dictionary = c.planet_regions.order_cross(c, 0, [], Vector2i.RIGHT)
	check(not bool(no_op["ok"]), "ordre de passage vide refusé")
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	var chosen: Vector2i = Vector2i.ZERO
	var edge: Vector2i = Vector2i(-1, -1)
	var destination: SimWorld = null
	for direction in dirs:
		var to: Vector2i = PlanetRegions.neighbor(home_coord, direction)
		if not PlanetRegions.valid(to):
			continue
		var probe: SimWorld = c.planet_regions.obtain(to)
		var candidate: Vector2i = _edge_pair(home, probe, direction)
		if candidate.x >= 0:
			chosen = direction
			edge = candidate
			destination = probe
			break
	check(destination != null, "au moins une frontière terrestre accessible")
	if destination != null:
		var scout: SimWorld.Unit = home.spawn_unit(0, "eclaireur", Vector2(edge) + Vector2(0.5, 0.5))
		var initial_hp: float = scout.max_hp * 0.63
		scout.hp = initial_hp
		scout.supply = 37.5
		var scout_id: int = scout.id
		var pop_before: int = (home.teams[0] as SimWorld.Team).pop + (destination.teams[0] as SimWorld.Team).pop
		var order: Dictionary = c.planet_regions.order_cross(c, 0, [scout_id], chosen)
		check(bool(order.get("ok", false)), "franchissement ordonné via une frontière praticable")
		var snapshot_in_transit: Dictionary = CampaignSave.snapshot(c)
		var loaded_transit: StarCampaign = CampaignSave.from_snapshot(snapshot_in_transit)
		check(loaded_transit != null and loaded_transit.planet_regions != null and loaded_transit.planet_regions.crossings.size() == 1,
			"sauvegarde d'une unité en traversée et reprise du ticket")
		if bool(order.get("ok", false)):
			c.step()
			var to_coord: Vector2i = PlanetRegions.neighbor(home_coord, chosen)
			check(c.planet_regions.active == to_coord, "la caméra suit la première unité franchissant la frontière")
			check(not home.units.has(scout_id), "unité absente de la région d'origine après traversée")
			var found: SimWorld.Unit = null
			for u in destination.units.values():
				if u.type == "eclaireur" and u.team == 0:
					found = u
					break
			check(found != null, "unité présente dans la région adjacente")
			if found != null:
				check(is_equal_approx(found.hp, initial_hp) and is_equal_approx(found.supply, 37.5), "PV et ravitaillement conservés")
				check(found.planet_uid > 0, "identité permanente de l'unité attribuée")
				check((home.teams[0] as SimWorld.Team).pop + (destination.teams[0] as SimWorld.Team).pop == pop_before,
					"population transférée sans duplication")
			var home_tick: int = home.tick
			for i in 4:
				c.step()
			check(home.tick > home_tick, "combat/économie de la région quittée continuent hors écran")
			var snapshot_after: Dictionary = CampaignSave.snapshot(c)
			var loaded: StarCampaign = CampaignSave.from_snapshot(snapshot_after)
			check(loaded != null, "restauration de campagne multi-région")
			if loaded != null:
				check(loaded.state_hash() == c.state_hash(), "état complet identique après restauration")
				check(loaded.planet_regions.regions.size() >= 2, "régions modifiées et visitées persistées")
				check(loaded.planet_regions.visit(home_coord, loaded), "retour au secteur de départ")
				check((loaded.worlds["val"] as SimWorld).team_buildings(0, "centre", true).size() == 1,
					"bâtiments persistants après retour")
			var corrupted: Dictionary = snapshot_after.duplicate(true)
			corrupted["planet_regions"]["maps"]["9999:5"] = {"invalid": true}
			check(CampaignSave.from_snapshot(corrupted) == null, "coordonnées de sauvegarde falsifiées refusées")
	check(source_hash != "", "empreinte région initiale disponible")
	var legacy := StarCampaign.new()
	legacy.create(seed, false, false)
	check(legacy.planet_regions == null and legacy.current().team_buildings(0, "centre", true).size() == 1,
		"mode historique J1–J8 inchangé")
	print("J9_REGIONS_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", total, failures])
	quit(0 if failures == 0 else 1)
