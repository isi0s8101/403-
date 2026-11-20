extends SceneTree
## J12 : tests réels headless (aucun résultat prérempli), le code de sortie est bloquant.
var assertions: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func place(w: SimWorld, team: int, kind: String) -> SimWorld.Building:
	for y in range(9, 80, 5):
		for x in range(9, 80, 5):
			var cell := Vector2i(x, y)
			if w.footprint_free(cell, 4) and w.has_margin(cell, 4):
				return w.spawn_building(team, kind, cell, true)
	return null

func _initialize() -> void:
	var seed: int = 120026
	var c := StarCampaign.new()
	c.create(seed, false, true)
	c.ages[0] = 10
	c.resources[0] = {"food": 50000.0, "wood": 50000.0, "ore": 50000.0}
	c._sync_all()
	check(c.planet_regions != null and c.worlds.size() == 3, "J9/J10 : atlas conservé et trois ancres historiques")
	check(c.star_catalog.galaxy.signature() == GalaxyGenerator.new(seed).signature(), "J11 : galaxie déterministe")
	check(c.system_resources(0, "sol") == c.resources[0], "J12 : capital initial dans Sol")
	check(float(c.system_resources(0, "proxima")["ore"]) == 0.0, "J12 : stocks locaux sans copie sur Proxima")
	var raw_route: Array = []
	var systems: Array = c.star_catalog.galaxy.systems.keys()
	systems.sort()
	for sys in systems:
		var route: Array = c.star_catalog.galaxy.route("sol", String(sys))
		if route.size() >= 3 and (raw_route.is_empty() or route.size() < raw_route.size()):
			raw_route = route
	check(raw_route.size() >= 3, "corridor multi-sauts trouvé")
	if raw_route.size() < 3:
		quit(1)
		return
	var home: SimWorld = c.worlds["val"]
	var home_port: SimWorld.Building = place(home, 0, "chantier_orbital")
	check(home_port != null, "chantier orbital Sol posé")
	if home_port == null:
		quit(1)
		return
	var relays: Array = []
	for sys in raw_route.slice(1):
		var star_id: String = String(sys)
		(c.discovered_systems[0] as Dictionary)[star_id] = true
		var bodies: Array = c.star_catalog.bodies_for_system(star_id)
		check(not bodies.is_empty(), "monde du système %s" % star_id)
		if bodies.is_empty():
			quit(1)
			return
		var key: String = String(bodies[0]["id"])
		var w: SimWorld = c.materialize(key)
		check(w != null, "monde généré à la demande : %s" % star_id)
		if w == null:
			quit(1)
			return
		var center: SimWorld.Building = place(w, 0, "centre")
		check(center != null, "centre réel dans %s" % star_id)
		if center == null:
			quit(1)
			return
		if star_id != String(raw_route.back()):
			var relay: SimWorld.Building = place(w, 0, "chantier_orbital")
			check(relay != null, "relais orbital intermédiaire dans %s" % star_id)
			if relay == null:
				quit(1)
				return
			relays.append({"world": w, "building": relay})
	var target: String = String(raw_route.back())
	var path: Array = c._route_for_supply(0, "sol", target)
	check(path.size() >= 3 and path[0] == "sol" and path.back() == target, "liaison réelle multi-sauts avec relais")
	var starting: Dictionary = c.system_resources(0, "sol").duplicate(true)
	var refused: Dictionary = c.ship_supplies(0, "sol", target, {"ore": -100})
	check(not bool(refused.get("ok", false)) and c.system_resources(0, "sol") == starting, "requête négative rejetée sans débit")
	refused = c.ship_supplies(0, "sol", target, {"ore": 50001})
	check(not bool(refused.get("ok", false)) and c.system_resources(0, "sol") == starting, "quantité excessive rejetée sans débit")
	var successful: Dictionary = c.ship_supplies(0, "sol", target, {"food": 150, "wood": 80, "ore": 120})
	check(bool(successful.get("ok", false)) and c.freight_orders.size() == 1, "fret réel lancé après contrôle des relais")
	if not bool(successful.get("ok", false)):
		quit(1)
		return
	check(float(c.system_resources(0, "sol")["ore"]) == float(starting["ore"]) - 120.0, "débit minerai unique au départ")
	check(float(c.system_resources(0, target)["ore"]) == 0.0, "aucune téléportation de cargaison")
	var saved: Dictionary = CampaignSave.snapshot(c)
	var clone: StarCampaign = CampaignSave.from_snapshot(saved)
	check(clone != null and clone.state_hash() == c.state_hash(), "sauvegarde J12 en transit et reprise exacte")
	var corrupted: Dictionary = saved.duplicate(true)
	(corrupted["freight_orders"] as Array)[0]["eta"] = -40
	check(CampaignSave.from_snapshot(corrupted) == null, "sauvegarde fret avec ETA falsifié refusée")
	var arrived: bool = false
	for t in range(3200):
		c._tick_freight()
		if clone != null:
			clone._tick_freight()
		if c.freight_orders.is_empty():
			arrived = true
			break
	check(arrived and is_equal_approx(float(c.system_resources(0, target)["ore"]), 120.0), "ressources livrées après plusieurs trajets")
	check(clone != null and clone.state_hash() == c.state_hash(), "fret déterministe après restauration")
	var second: Dictionary = c.ship_supplies(0, "sol", target, {"ore": 50})
	check(bool(second.get("ok", false)), "deuxième fret envoyé")
	if not relays.is_empty() and bool(second.get("ok", false)):
		var relay_rec: Dictionary = relays[0]
		var relay_world: SimWorld = relay_rec["world"]
		var relay_port: SimWorld.Building = relay_rec["building"]
		relay_world.buildings.erase(relay_port.id)
		for t in range(500):
			c._tick_freight()
		check(c.freight_orders.size() == 1 and bool(c.freight_orders[0]["holding"]), "fret en attente si relais détruit")
		var replacement: SimWorld.Building = place(relay_world, 0, "chantier_orbital")
		check(replacement != null, "reconstruction du relais")
		for t in range(3200):
			c._tick_freight()
			if c.freight_orders.is_empty():
				break
		check(c.freight_orders.is_empty() and is_equal_approx(float(c.system_resources(0, target)["ore"]), 170.0), "fret repart après remise en service du relais")
	check(bool(c.set_system_order(0, "sol", "defend").get("ok", false)), "délégation défense Sol")
	c._tick_directives()
	check(String((home.teams[0] as SimWorld.Team).army.get("type", "")) == "defend", "objectif défensif réellement appliqué")
	check(not bool(c.set_system_order(0, "g99", "defend").get("ok", false)), "ordre sur système inexistant rejeté")
	check(bool(c.set_system_order(0, target, "supply").get("ok", false)), "approvisionnement autonome assigné")
	check(bool(c.set_system_order(0, "sol", "observe").get("ok", false)), "défense désactivable")
	var last: Dictionary = CampaignSave.snapshot(c)
	var final_copy: StarCampaign = CampaignSave.from_snapshot(last)
	check(final_copy != null and final_copy.state_hash() == c.state_hash(), "persistance des stocks, relais, directives")
	# Import ancien : tous les fonds restent conservés sans duplication entre systèmes.
	var old: Dictionary = last.duplicate(true)
	old.erase("system_stocks")
	old.erase("freight_orders")
	old.erase("next_freight_id")
	old.erase("directives")
	var migrated: StarCampaign = CampaignSave.from_snapshot(old)
	check(migrated != null and migrated.resources == c.resources and migrated.freight_orders.is_empty(), "migration d'une sauvegarde J11 sans duplication")
	print("J12_EMPIRE_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)
