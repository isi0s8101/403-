extends SceneTree
## Rejouable hors rendu : mode campagne, orbite, colonisation, interstellaire et sérialisation.
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func port_near(w: SimWorld, team: int, kind: String) -> SimWorld.Building:
	var center: Vector2 = (w.team_buildings(team, "centre", true)[0] as SimWorld.Building).center
	for radius in range(7, 24):
		for y in range(maxi(0, int(center.y) - radius), mini(Rules.MAP_SIZE - 4, int(center.y) + radius)):
			for x in range(maxi(0, int(center.x) - radius), mini(Rules.MAP_SIZE - 4, int(center.x) + radius)):
				var cell := Vector2i(x, y)
				if w.footprint_free(cell, 4) and w.has_margin(cell, 4) and center.distance_to(Vector2(cell)) < 24.0:
					return w.spawn_building(team, kind, cell, true)
	return null

func advance(c: StarCampaign, n: int) -> void:
	for i in n:
		c.step()

func _initialize() -> void:
	var c := StarCampaign.new()
	c.create(678)
	check(c.worlds.size() == 3 and c.active == "val", "trois planètes uniques")
	check(not c.is_unlocked(0, "aurore") and not c.is_unlocked(0, "nemesis"), "secteurs verrouillés au départ")
	check(not c.switch_to(0, "aurore"), "bascule prématurée refusée")
	c.ages[0] = 9
	c.resources[0] = {"food": 150000.0, "wood": 150000.0, "ore": 150000.0}
	c._sync_all()
	check(c.is_unlocked(0, "aurore") and not c.is_unlocked(0, "nemesis"), "IX débloque la planète locale, pas une autre étoile")
	var home: SimWorld = c.worlds["val"]
	var launch: SimWorld.Building = port_near(home, 0, "spatioport")
	check(launch != null, "emplacement spatioport valide")
	if launch == null:
		_finish()
		return
	check(not c.launch_satellite(1, "val", launch.id)["ok"], "satellite : usurpation d'un port refusée")
	check(c.launch_satellite(0, "val", launch.id)["ok"], "satellite lancé à l'âge IX")
	check(not c.launch_satellite(0, "val", launch.id)["ok"], "recharge satellite non contournable")
	var aurore: SimWorld = c.worlds["aurore"]
	var target := Vector2(47.0, 47.0)
	check(not aurore.is_visible_to(0, target), "brouillard planétaire distinct avant scan")
	check(c.scan(0, "aurore", target)["ok"], "balayage orbital distant")
	check(aurore.is_visible_to(0, target), "scan révèle le secteur")
	check(not c.scan(0, "aurore", target)["ok"], "recharge du scan")
	check(not c.scan(0, "aurore", Vector2(-1, 0))["ok"], "coordonnées de scan invalides")
	check(home.teams[1].age == 1 and aurore.teams[1].age == 1, "âges des camps indépendants")
	check(not c.dispatch(0, "val", launch.id, "nemesis")["ok"], "interstellaire interdit avant X")
	check(not c.dispatch(1, "val", launch.id, "aurore")["ok"], "détournement du port refusé")
	var ship: SimWorld.Unit = home.spawn_unit(0, "navette", launch.center + Vector2(4, 4))
	var builder: SimWorld.Unit = home.spawn_unit(0, "ouvrier", launch.center + Vector2(5, 5))
	var old_loss: int = int(home.teams[0].stats["losses"])
	check(c.dispatch(0, "val", launch.id, "aurore", [builder.id], ship.id)["ok"], "expédition avec navette et ouvrier")
	check(not home.units.has(ship.id) and not home.units.has(builder.id), "troupes embarquées absentes de la carte source")
	check(int(home.teams[0].stats["losses"]) == old_loss, "embarquement sans pertes fictives")
	check(c.flights.size() == 1 and aurore.team_buildings(0, "centre", true).is_empty(), "voyage non instantané")
	var saved: Dictionary = CampaignSave.snapshot(c)
	var clone: StarCampaign = CampaignSave.from_snapshot(saved)
	check(clone != null and clone.state_hash() == c.state_hash(), "instantané multi-cartes cohérent")
	if clone != null:
		advance(c, 162)
		advance(clone, 162)
		check(clone.state_hash() == c.state_hash(), "reprise déterministe avec voyage en cours")
	else:
		advance(c, 162)
	check(not aurore.team_buildings(0, "centre", true).is_empty(), "première colonie fondée")
	check(aurore.team_units(0, "builder").size() >= 1, "ouvrier réellement débarqué")
	advance(c, 25)
	check(not aurore.is_visible_to(0, target), "visibilité du scan expire")
	check(aurore.is_explored_by(0, target), "exploration conservée après scan")
	c.ages[0] = 10
	c._sync_all()
	check(c.is_unlocked(0, "nemesis"), "âge X ouvre le système externe")
	var shipyard: SimWorld.Building = port_near(aurore, 0, "chantier_orbital")
	check(shipyard != null, "chantier orbital colonial placé")
	if shipyard == null:
		_finish()
		return
	aurore.spawn_unit(0, "fregate", shipyard.center + Vector2(3, 3))
	aurore.spawn_unit(0, "ouvrier", shipyard.center + Vector2(4, 4))
	check(c.dispatch(0, "aurore", shipyard.id, "nemesis")["ok"], "frégate interstellaire envoyée")
	advance(c, 422)
	var distant: SimWorld = c.worlds["nemesis"]
	check(not distant.team_buildings(0, "centre", true).is_empty(), "colonisation d'une autre étoile")
	check(not distant.team_units(0).is_empty(), "unités combattantes conservées à destination")
	check(home.tick == aurore.tick and aurore.tick == distant.tick, "toutes les planètes continuent en parallèle")
	check(not c.switch_to(1, "nemesis"), "camp sans âge X ne peut accéder au secteur")
	check(c.switch_to(0, "nemesis") and c.current() == distant, "bascule caméra et secteur autorisée")
	# Deux combats dans un même tick : aucun index invalide après suppression de convois.
	var meeting := StarCampaign.new()
	meeting.create(9921)
	meeting.flights = [
		{"id": 101, "team": 0, "from": "val", "to": "aurore", "eta": 160,
			"ship": "navette", "units": [{"type": "ouvrier"}], "colony": false},
		{"id": 102, "team": 1, "from": "aurore", "to": "val", "eta": 160,
			"ship": "navette", "units": [{"type": "ouvrier"}], "colony": false},
		{"id": 103, "team": 0, "from": "val", "to": "nemesis", "eta": 420,
			"ship": "fregate", "units": [{"type": "ouvrier"}], "colony": false},
		{"id": 104, "team": 1, "from": "nemesis", "to": "val", "eta": 420,
			"ship": "fregate", "units": [{"type": "ouvrier"}], "colony": false},
	]
	meeting._tick_flights()
	check(meeting.flights.size() == 4, "aucune interception instantanée au décollage")
	for i in 210:
		meeting._tick_flights()
	check(meeting.flights.is_empty(), "interceptions multiples à mi-trajet sans accès hors bornes")
	var invalid: Dictionary = saved.duplicate(true)
	invalid["version"] = 999
	check(CampaignSave.from_snapshot(invalid) == null, "version de sauvegarde inconnue refusée")
	invalid = saved.duplicate(true)
	invalid["flights"] = [{"team": -999, "to": "val", "from": "nemesis", "eta": -1, "ship": "fregate", "units": []}]
	check(CampaignSave.from_snapshot(invalid) == null, "vol corrompu refusé")
	var p := "user://strategic-j678-test.save"
	var err: Error = CampaignSave.save(c, p)
	check(err == OK, "écriture contrôlée sur disque")
	if err == OK:
		var from_disk: StarCampaign = CampaignSave.load_campaign(p)
		check(from_disk != null and from_disk.state_hash() == c.state_hash(), "restauration sur disque identique")
		var stream := FileAccess.open(p, FileAccess.READ_WRITE)
		if stream != null:
			stream.seek(40)
			stream.store_8(255)
			stream.close()
		check(CampaignSave.load_campaign(p, false) == null, "fichier principal altéré refusé")
	_finish()

func _finish() -> void:
	print("STRATEGIC_RESULT=%s checks=%d fail=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
