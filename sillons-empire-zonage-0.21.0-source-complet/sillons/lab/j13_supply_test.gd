extends SceneTree
## J13.1 — chaîne d'approvisionnement : habitants -> troupes et colons, industrie -> équipements et bâtiments.
## godot --headless --path . --script res://lab/j13_supply_test.gd
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func site(w: SimWorld, team: int, kind: String) -> SimWorld.Building:
	var center: Vector2 = (w.team_buildings(team, "centre", true)[0] as SimWorld.Building).center
	var size: int = int(Rules.BUILDINGS[kind]["size"])
	for radius in range(6, 26):
		for y in range(maxi(0, int(center.y) - radius), mini(Rules.MAP_SIZE - size, int(center.y) + radius)):
			for x in range(maxi(0, int(center.x) - radius), mini(Rules.MAP_SIZE - size, int(center.x) + radius)):
				var cell := Vector2i(x, y)
				if w.footprint_free(cell, size) and w.has_margin(cell, size):
					return w.spawn_building(team, kind, cell, true)
	return null

func _initialize() -> void:
	var c := StarCampaign.new()
	c.create(1919)
	var w: SimWorld = c.worlds["val"]
	var barracks: SimWorld.Building = site(w, 0, "caserne")
	c.resources[0] = {"food": 50000.0, "wood": 50000.0, "ore": 50000.0}
	c._sync_all()
	var p: Dictionary = c.planets.colony(0, "val")
	check(w.supply_gate == null and w.train_check(0, barracks, "lancier") == "", "sans chaîne d'approvisionnement : règles 0.13.0 inchangées")
	c.enable_supply_chain()
	check(c.planets.supply_chain and w.supply_gate != null and int(p["pop"]) == 12, "chaîne activée : premiers habitants du monde fondateur")
	# Habitants -> troupes.
	var pop: int = int(p["pop"])
	var need: int = int(J13Rules.unit_needs("lancier")["people"])
	check(bool(w.issue({"t": "train", "team": 0, "building": barracks.id, "unit": "lancier"})["ok"]) and int(p["pop"]) == pop - need, "une recrue formée quitte la population (%d habitant)" % need)
	p["pop"] = 0
	var state: String = c.state_hash()
	var refused: Dictionary = w.issue({"t": "train", "team": 0, "building": barracks.id, "unit": "lancier"})
	check(not bool(refused["ok"]) and String(refused.get("reason", refused.get("why", ""))).contains("habitants") and c.state_hash() == state, "sans habitants : aucune troupe, aucun débit")
	var centre: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
	check(not bool(w.issue({"t": "train", "team": 0, "building": centre.id, "unit": "ouvrier"})["ok"]), "sans habitants : pas d'ouvrier ni de colon non plus")
	# Logements -> habitants.
	p["pop"] = 12
	var sites: Dictionary = PlanetGovernor._sites(c, c.planets, p, c.planets.connected(p))
	if (sites["free"] as Array).is_empty():
		c.build_road(0, "val", int((sites["frontier"] as Array)[0]))
		sites = PlanetGovernor._sites(c, c.planets, p, c.planets.connected(p))
	check(bool(c.zone_planet(0, "val", int((sites["free"] as Array)[0]), "R").get("ok", false)), "zone d'habitation (maisons) construite")
	for i in 1200:
		c.planets.step(c)
		c.tick += 1
	check(int(p["pop"]) > 16, "les logements font grandir la réserve de recrues (%d habitants)" % int(p["pop"]))
	# Industrie -> équipements des troupes.
	c.ages[0] = 6
	c._sync_all()
	var factory: SimWorld.Building = site(w, 0, "usine")
	var lack: String = w.train_check(0, factory, "fusilier")
	check(lack.contains("alliage"), "fusilier sans alliage refusé (%s)" % lack)
	(p["stocks"] as Dictionary)["alloy"] = 100.0
	var alloy_need: float = float(J13Rules.unit_needs("fusilier")["alloy"])
	check(bool(w.issue({"t": "train", "team": 0, "building": factory.id, "unit": "fusilier"})["ok"]) and is_equal_approx(float((p["stocks"] as Dictionary)["alloy"]), 100.0 - alloy_need), "fusilier équipé : alliage consommé une fois")
	lack = w.train_check(0, factory, "char")
	check(lack.contains("carburant"), "char sans carburant refusé (%s)" % lack)
	(p["stocks"] as Dictionary)["fuel"] = 50.0
	check(w.train_check(0, factory, "char") == "", "char autorisé avec alliage et carburant")
	# Industrie -> bâtiments.
	var needs: Dictionary = J13Rules.building_needs("usine")
	check(J13Rules.building_needs("maison").is_empty() and needs.has("concrete"), "bâtiments anciens libres, bâtiments industriels en béton")
	var spot := Vector2i(-1, -1)
	var worker_pos: Vector2 = (w.team_units(0, "builder")[0] as SimWorld.Unit).pos
	for radius in range(3, 20):
		for y in range(int(worker_pos.y) - radius, int(worker_pos.y) + radius):
			for x in range(int(worker_pos.x) - radius, int(worker_pos.x) + radius):
				if spot.x < 0 and x > 2 and y > 2 and x < Rules.MAP_SIZE - 6 and y < Rules.MAP_SIZE - 6:
					(p["stocks"] as Dictionary)["concrete"] = 500.0
					if w.build_check(0, "usine", Vector2i(x, y)) == "":
						spot = Vector2i(x, y)
	(p["stocks"] as Dictionary)["concrete"] = 0.0
	check(spot.x >= 0 and w.build_check(0, "usine", spot).contains("béton"), "usine sans béton refusée")
	(p["stocks"] as Dictionary)["concrete"] = 40.0
	check(bool(w.issue({"t": "build", "team": 0, "type": "usine", "cell": spot}).get("ok", false)) and is_equal_approx(float((p["stocks"] as Dictionary)["concrete"]), 40.0 - float(needs["concrete"])), "usine bâtie : béton consommé une fois")
	# Sauvegarde.
	var copy: StarCampaign = CampaignSave.from_snapshot(CampaignSave.snapshot(c))
	check(copy != null and copy.planets.supply_chain and (copy.worlds["val"] as SimWorld).supply_gate != null and copy.state_hash() == c.state_hash(), "réglage et état conservés par la sauvegarde")
	var old: Dictionary = CampaignSave.snapshot(c)
	old.erase("j13")
	var migrated: StarCampaign = CampaignSave.from_snapshot(old)
	check(migrated != null and not migrated.planets.supply_chain, "partie 0.12.3 migrée : anciennes règles conservées")
	# IA contre IA avec la chaîne complète : personne ne reste bloqué.
	var duel := StarCampaign.new()
	duel.create(2020, true)
	duel.enable_supply_chain()
	for i in 9000:
		duel.step()
	for team in 2:
		var colony: Dictionary = duel.planets.colony(team, "val")
		var soldiers: int = (duel.worlds["val"] as SimWorld).team_units(team, "military").size()
		var trained: int = int((duel.worlds["val"] as SimWorld).teams[team].stats.get("trained", -1))
		print("  camp %d : âge %d, habitants %d, districts zonés %d, soldats %d, formés %d, crédits %d" % [team, int(duel.ages[team]), int(colony["pop"]), int(duel.planets.zoning_shares(colony)["count"]), soldiers, trained, int(duel.planets.credits(team))])
		check(int(duel.planets.zoning_shares(colony)["count"]) >= 1 and int(colony["pop"]) >= 0, "IA camp %d : zones construites par l'intendant" % team)
		check(soldiers > 0 or int((duel.worlds["val"] as SimWorld).teams[team].stats.get("losses", 0)) > 0, "IA camp %d : armée levée malgré la chaîne d'approvisionnement" % team)
		check(duel.planets.books_balanced(team), "IA camp %d : comptes équilibrés" % team)
	print("J13_SUPPLY_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
