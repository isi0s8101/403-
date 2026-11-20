extends SceneTree
## J11 : génération, routes, exploration, conquête et sauvegarde, même à ×8.
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _port(w: SimWorld, team: int) -> SimWorld.Building:
	var centers: Array = w.team_buildings(team, "centre", true)
	if centers.is_empty():
		return null
	var home: Vector2 = (centers[0] as SimWorld.Building).center
	for y in range(6, 90):
		for x in range(6, 90):
			var p := Vector2i(x, y)
			if home.distance_to(Vector2(p)) < 20.0 and w.footprint_free(p, 4) and w.has_margin(p, 4):
				return w.spawn_building(team, "chantier_orbital", p, true)
	return null

func _initialize() -> void:
	var seed: int = 20261110
	var g := GalaxyGenerator.new(seed)
	check(g.systems.size() == 16 and g.edges.size() >= 15, "16 étoiles et routes connectées")
	check(g.signature() == GalaxyGenerator.new(seed).signature(), "même seed, mêmes routes")
	check(g.signature() != GalaxyGenerator.new(seed + 1).signature(), "seed différente, galaxie différente")
	var all_connected: bool = true
	for key in g.systems.keys():
		all_connected = all_connected and not g.route("sol", String(key)).is_empty()
		for neighbor in g.neighbors(String(key)):
			all_connected = all_connected and g.adjacent(String(neighbor), String(key))
	check(all_connected, "routes symétriques et galaxie entièrement connectée")
	check(g.adjacent("sol", "proxima"), "corridor historique Sol Proxima conservé")
	var star := StarSystemGenerator.new(seed)
	check(star.systems.size() == 16 and star.has_body("val") and star.has_body("nemesis"), "J10 préservé et étendu")
	check(StarCampaign.expected_flight_duration(star, "val", "nemesis") == 420, "ETA historique interstellaire préservé")
	var c := StarCampaign.new()
	c.create(seed, false, true)
	check(c.worlds.size() == 3, "galaxie générée sans créer toutes les cartes tactiques")
	c.ages[0] = 10
	c.resources[0] = {"food": 100000.0, "wood": 100000.0, "ore": 100000.0}
	c._sync_all()
	var neighbor: String = ""
	for key in g.neighbors("sol"):
		if not c.system_known(0, String(key)):
			neighbor = String(key)
			break
	check(not neighbor.is_empty(), "étoile inconnue accessible depuis Sol")
	if neighbor.is_empty():
		quit(1)
		return
	var bodies: Array = star.bodies_for_system(neighbor)
	check(not bodies.is_empty(), "planète procédurale dans le système inconnu")
	var target: String = String(bodies[0]["id"])
	check(not c.is_unlocked(0, target), "brouillard interdit l'accès à une planète inconnue")
	check(not c.is_unlocked(1, target), "brouillard indépendant entre camps")
	var home: SimWorld = c.worlds["val"]
	var launch: SimWorld.Building = _port(home, 0)
	check(launch != null, "chantier orbital de reconnaissance constructible")
	if launch == null:
		quit(1)
		return
	var probe: Dictionary = c.survey_system(0, "sol", neighbor)
	check(bool(probe.get("ok", false)) and c.survey_probes.size() == 1, "sonde exige une route et un chantier")
	check(not bool(c.survey_system(0, "sol", neighbor).get("ok", false)), "sonde identique non doublée")
	var initial_snapshot: Dictionary = CampaignSave.snapshot(c)
	var restored: StarCampaign = CampaignSave.from_snapshot(initial_snapshot)
	check(restored != null and restored.state_hash() == c.state_hash(), "sonde en cours sauvegardée intégralement")
	if restored != null:
		for tick_index in range(int(probe.get("eta", 0)) + 1):
			c.step()
			restored.step()
		check(c.state_hash() == restored.state_hash(), "exploration identique après reprise et mêmes ticks")
	check(c.system_known(0, neighbor) and c.is_unlocked(0, target), "sonde révèle le monde à son arrivée")
	check(not c.system_known(1, neighbor), "aucune fuite d'information vers l'adversaire")
	check(c.system_owner(neighbor) == -1, "découverte ne colonise pas automatiquement")
	var far: String = ""
	for id in g.systems.keys():
		if id != "sol" and id != "proxima" and not g.adjacent("sol", String(id)):
			far = String(id)
			break
	check(not far.is_empty() and g.route("sol", far).size() > 2, "chemin interstellaire multiétape disponible")
	var ship: SimWorld.Unit = home.spawn_unit(0, "fregate", launch.center + Vector2(2.0, 2.0))
	var worker: SimWorld.Unit = home.spawn_unit(0, "ouvrier", launch.center + Vector2(3.0, 3.0))
	# Révéler fictivement un système lointain ne crée aucune liaison directe.
	if not far.is_empty():
		(c.discovered_systems[0] as Dictionary)[far] = true
		var remote_planets: Array = star.bodies_for_system(far)
		var refused: Dictionary = c.dispatch(0, "val", launch.id, String(remote_planets[0]["id"]), [worker.id], ship.id)
		check(not bool(refused.get("ok", false)) and home.units.has(ship.id), "route non adjacente refusée sans retirer l'équipage")
		(c.discovered_systems[0] as Dictionary).erase(far)
	var voyage: Dictionary = c.dispatch(0, "val", launch.id, target, [worker.id], ship.id)
	check(bool(voyage.get("ok", false)) and c.flights.size() == 1, "flotte en route, pas de téléportation")
	check(int(c.flights[0]["duration"]) == StarCampaign.expected_flight_duration(star, "val", target), "ETA lié à la distance de la route")
	var saved: Dictionary = CampaignSave.snapshot(c)
	restored = CampaignSave.from_snapshot(saved)
	check(restored != null and restored.state_hash() == c.state_hash(), "sauvegarde d'une flotte galactique")
	if restored != null:
		for tick_index in range(int(c.flights[0]["duration"]) + 4):
			c.step()
			restored.step()
		check(c.state_hash() == restored.state_hash(), "transport et colonisation déterministes après reprise")
		check(c.system_owner(neighbor) == 0, "système conquis via une colonie réelle")
		check(not c.worlds[target].team_units(0, "builder").is_empty(), "ouvrier débarqué vivant")
	var falsified: Dictionary = saved.duplicate(true)
	falsified["discovered_systems"][0]["g999"] = true
	check(CampaignSave.from_snapshot(falsified) == null, "sauvegarde révélant un système inexistant rejetée")
	falsified = initial_snapshot.duplicate(true)
	falsified["survey_probes"][0]["target"] = "g999"
	check(CampaignSave.from_snapshot(falsified) == null, "sonde falsifiée refusée")
	# Interception sur une même liaison malgré des planètes différentes.
	var conflict := StarCampaign.new()
	conflict.create(20261110, false, false)
	var second_body: String = String(bodies[1]["id"])
	conflict.materialize(second_body)
	var travel_ticks: int = StarCampaign.expected_flight_duration(conflict.star_catalog, "val", target)
	var midway: int = int(ceil(float(travel_ticks) / 2.0))
	var payload: Array = [{"type": "ouvrier", "hp_ratio": 1.0, "supply": 100.0}]
	conflict.flights = [
		{"id": 1, "team": 0, "from": "val", "to": target, "eta": midway,
		"duration": travel_ticks, "ship": "fregate", "ship_hp_ratio": 1.0, "units": payload.duplicate(true), "colony": false},
		{"id": 2, "team": 1, "from": second_body, "to": "aurore", "eta": midway,
		"duration": travel_ticks, "ship": "fregate", "ship_hp_ratio": 1.0, "units": payload.duplicate(true), "colony": false}
	]
	conflict._tick_flights()
	check(conflict.flights.is_empty(), "interception sur une arête malgré des planètes distinctes")
	var legacy := StarCampaign.new()
	legacy.create(1178, false, false)
	var older: Dictionary = CampaignSave.snapshot(legacy)
	older["star_catalog_version"] = 1
	older.erase("discovered_systems")
	older.erase("survey_probes")
	older.erase("next_probe_id")
	older.erase("galaxy_version")
	var older_loaded: StarCampaign = CampaignSave.from_snapshot(older)
	check(older_loaded != null and older_loaded.state_hash() == legacy.state_hash(), "compatibilité des instantanés J10")
	print("J11_GALAXY_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
