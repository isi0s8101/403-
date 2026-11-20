extends SceneTree
## J13 — recette réelle hors rendu (cadrage V3.0, §70) :
## godot --headless --path . --script res://lab/j13_colony_test.gd
## Colonie à âge local, zonage R/C/I, services par graphe, gouverneur, verrou orbital,
## transports auditables, trésorerie, sauvegarde et migration 0.12.3.
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func mk(seed: int) -> StarCampaign:
	var c := StarCampaign.new()
	c.create(seed)
	c.ages[0] = 10
	c.resources[0] = {"food": 200000.0, "wood": 200000.0, "ore": 200000.0}
	c._sync_all()
	# Recette contrôlée : le gouverneur du monde fondateur (âge X) est suspendu, sauf dans son propre groupe.
	c.planets._governor_gate(c, c.planets.colony(0, "val"))
	c.set_governor_policy(0, "val", false)
	return c

func fund(c: StarCampaign, team: int, amount: float) -> void:
	c.planets._mint(c, team, "treasury", amount, "dotation de laboratoire")

func fast(c: StarCampaign, n: int) -> void:
	## Accélération de laboratoire : seule la couche planétaire avance (même code, même ordre).
	for i in n:
		c.planets.step(c)
		c.tick += 1

func full(c: StarCampaign, n: int) -> void:
	for i in n:
		c.step()

func grow(c: StarCampaign, team: int, body: String, plan: Array) -> Array:
	## Construit par l'API joueur : route si besoin, puis zone ou équipement. Renvoie les districts.
	var out: Array = []
	for raw in plan:
		var item: String = String(raw)
		var p: Dictionary = c.planets.colony(team, body)
		var sites: Dictionary = PlanetGovernor._sites(c, c.planets, p, c.planets.connected(p))
		var guard: int = 0
		while (sites["free"] as Array).is_empty() and not (sites["frontier"] as Array).is_empty() and guard < 12:
			guard += 1
			if not bool(c.build_road(team, body, int((sites["frontier"] as Array)[0])).get("ok", false)):
				break
			sites = PlanetGovernor._sites(c, c.planets, p, c.planets.connected(p))
		if (sites["free"] as Array).is_empty():
			print("  grow %s : aucun district libre" % item)
			out.append(-1)
			continue
		var id: int = int((sites["free"] as Array)[0])
		var result: Dictionary = {}
		if item in ["R", "C"]:
			result = c.zone_planet(team, body, id, item)
		elif item.begins_with("I"):
			result = c.zone_planet(team, body, id, "I", item.get_slice(":", 1) if item.contains(":") else "fonderie")
		else:
			result = c.build_civic(team, body, id, item)
		if not bool(result.get("ok", false)):
			print("  grow %s refusé : %s" % [item, String(result.get("reason", "?"))])
		out.append(id if bool(result.get("ok", false)) else -1)
	return out

func port_near(w: SimWorld, team: int, kind: String) -> SimWorld.Building:
	var center: Vector2 = (w.team_buildings(team, "centre", true)[0] as SimWorld.Building).center
	for radius in range(7, 24):
		for y in range(maxi(0, int(center.y) - radius), mini(Rules.MAP_SIZE - 4, int(center.y) + radius)):
			for x in range(maxi(0, int(center.x) - radius), mini(Rules.MAP_SIZE - 4, int(center.x) + radius)):
				var cell := Vector2i(x, y)
				if w.footprint_free(cell, 4) and w.has_margin(cell, 4) and center.distance_to(Vector2(cell)) < 24.0:
					return w.spawn_building(team, kind, cell, true)
	return null

func colony_ready(c: StarCampaign) -> void:
	## Monde fondateur prêt à exporter : logements, port au sol, population de laboratoire.
	grow(c, 0, "val", ["R", "R", "R"])
	port_near(c.worlds["val"] as SimWorld, 0, "spatioport")
	c.planets.colony(0, "val")["pop"] = 100
	full(c, 1)

func _initialize() -> void:
	_tech()
	_zoning()
	_services()
	_governor()
	_orbital()
	_transport_and_treasury()
	print("J13_COLONY_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

# ---------------------------------------------------------------- technologies et colonie
func _tech() -> void:
	var c: StarCampaign = mk(1313)
	var pc: PlanetCampaign = c.planets
	check(is_equal_approx(pc.credits(0), J13Rules.SCENARIO_CREDITS) and pc.books_balanced(0), "nouvelle partie : dotation tracée, comptes équilibrés")
	check(c.local_age(0, "val") == 10 and c.local_age(1, "val") == 1, "monde fondateur : âge local = âge du camp")
	colony_ready(c)
	check(not bool(c.found_colony(0, "val", "val").get("ok", true)), "fondation sur son propre monde refusée")
	var before: int = int(pc.colony(0, "val")["pop"])
	var sent: Dictionary = c.found_colony(0, "val", "aurore")
	check(bool(sent.get("ok", false)) and int(pc.colony(0, "val")["pop"]) == before - 12, "12 colons réservés et retirés une seule fois au départ")
	check(not pc.has_colony(0, "aurore") and pc.transports.size() == 1, "trajet non instantané, colonie pas encore fondée")
	full(c, int(sent["eta"]))
	check(pc.has_colony(0, "aurore") and int(pc.colony(0, "aurore")["pop"]) in [12, 13] and int((pc.transport_log[0] as Dictionary)["passengers"]) == 12, "12 arrivées, pas 24 (une naissance possible le même tick)")
	check(c.local_age(0, "aurore") == 7 and int(c.ages[0]) == 10, "empire X : la colonie naît à l'âge VII local")
	check(int((c.worlds["aurore"] as SimWorld).teams[0].age) == 7 and int((c.worlds["val"] as SimWorld).teams[0].age) == 10, "le terrain tactique de la colonie produit à l'âge VII")
	check(not (c.worlds["aurore"] as SimWorld).team_buildings(0, "centre", true).is_empty(), "commandement terrestre réellement posé")
	check(not bool(c.set_governor_policy(0, "aurore", true).get("ok", true)), "gouverneur refusé à l'âge VII")
	check(String(c.start_orbital_station(0, "aurore").get("reason_code", "")) == "age", "station orbitale refusée avant l'âge IX local")
	# Renfort X importé : il existe et sert, sans débloquer l'arsenal local.
	full(c, 200)
	check(OrbitalIndustry.has_hub(c, 0, "val"), "chantier naval du monde fondateur opérationnel")
	OrbitalIndustry.presence(c, 0, "val")["fregate"] = 1
	check(bool(c.orbital_send(0, "val", "aurore", {"fregate": 1}).get("ok", false)), "frégate X envoyée en renfort")
	full(c, 165)
	check(int(OrbitalIndustry.presence(c, 0, "aurore").get("fregate", 0)) == 1, "frégate X importée présente en orbite de la colonie")
	check(not bool(c.orbital_train(0, "aurore", "fregate").get("ok", true)) and not bool(c.orbital_shipyard(0, "aurore").get("ok", true)), "frégate importée : aucun arsenal local débloqué")
	# VII -> VIII -> IX -> X : industrie, matériaux, crédits, énergie puis station locale.
	check(String(c.advance_colony_age(0, "aurore").get("reason_code", "")) == "industry", "VIII refusé sans industrie locale")
	check(grow(c, 0, "aurore", ["power", "water", "I", "I", "I:usine_civile", "I"]).min() >= 0, "industrie locale construite")
	check(String(c.advance_colony_age(0, "aurore").get("reason_code", "")) == "cost", "VIII refusé sans matériaux ni crédits")
	var stocks: Dictionary = pc.colony(0, "aurore")["stocks"] as Dictionary
	stocks["alloy"] = 200.0
	fund(c, 0, 5000.0)
	var hash_before: String = c.state_hash()
	stocks["alloy"] = 10.0
	check(not bool(c.advance_colony_age(0, "aurore").get("ok", true)) and c.state_hash() != "" and is_equal_approx(float(stocks["alloy"]), 10.0), "refus sans aucun débit")
	stocks["alloy"] = 200.0
	check(hash_before == c.state_hash(), "état inchangé après un refus")
	check(bool(c.advance_colony_age(0, "aurore").get("ok", false)), "passage VIII lancé")
	check(String(c.advance_colony_age(0, "aurore").get("reason_code", "")) == "busy", "un seul passage d'âge à la fois")
	fast(c, 320)
	check(c.local_age(0, "aurore") == 8, "âge VIII local atteint après le délai")
	stocks["alloy"] = 200.0
	stocks["electronics"] = 200.0
	stocks["machinery"] = 100.0
	check(bool(c.advance_colony_age(0, "aurore").get("ok", false)), "passage IX lancé")
	fast(c, 420)
	check(c.local_age(0, "aurore") == 9, "âge IX local atteint")
	check(String(c.advance_colony_age(0, "aurore").get("reason_code", "")) == "station", "X refusé sans station orbitale locale")
	port_near(c.worlds["aurore"] as SimWorld, 0, "spatioport")
	check(bool(c.start_orbital_station(0, "aurore").get("ok", false)) and pc.station_count(c, 0, "aurore") == 0, "station locale payée, en assemblage")
	full(c, 185)
	check(pc.station_count(c, 0, "aurore") == 1, "station locale opérationnelle après assemblage")
	check(bool(c.advance_colony_age(0, "aurore").get("ok", false)), "passage X lancé")
	fast(c, 520)
	check(c.local_age(0, "aurore") == 10 and bool((pc.colony(0, "aurore")["governor"] as Dictionary)["enabled"]), "âge X local : gouverneur activé par défaut")
	check(bool(c.set_governor_policy(0, "aurore", false).get("ok", false)) and not bool((pc.colony(0, "aurore")["governor"] as Dictionary)["enabled"]), "gouverneur suspendable")
	check(pc.books_balanced(0), "comptes équilibrés après la progression")
	# Migration : une partie 0.12.3 garde ses âges, ne reçoit ni crédit ni station.
	var legacy_campaign: StarCampaign = mk(2024)
	full(legacy_campaign, 200)
	var old: Dictionary = CampaignSave.snapshot(legacy_campaign)
	old.erase("j13")
	var migrated: StarCampaign = CampaignSave.from_snapshot(old)
	check(migrated != null and migrated.local_age(0, "val") == 10 and migrated.planets.migrated_from == "0.12.3", "sauvegarde 0.12.3 migrée : âge conservé")
	if migrated != null:
		check(is_zero_approx(migrated.planets.credits(0)) and migrated.planets.stations.is_empty(), "migration : trésorerie 0, aucune station offerte")
		check(migrated.orbital_sites.size() == legacy_campaign.orbital_sites.size() and var_to_str(migrated.system_stocks) == var_to_str(legacy_campaign.system_stocks), "migration : chantiers et stocks ni perdus ni dupliqués")
		var again: StarCampaign = CampaignSave.from_snapshot(CampaignSave.snapshot(CampaignSave.from_snapshot(CampaignSave.snapshot(migrated))))
		check(again != null and again.state_hash() == migrated.state_hash(), "trois rechargements : aucun crédit, colon ou stock en plus")
	var forged: Dictionary = CampaignSave.snapshot(c)
	(forged["j13"]["treasury"][0] as Dictionary)["credits"] = 999999.0
	check(CampaignSave.from_snapshot(forged) == null, "sauvegarde aux crédits falsifiés refusée")
	forged = CampaignSave.snapshot(c)
	(forged["j13"]["colonies"]["0:aurore"] as Dictionary)["local_age"] = 14
	check(CampaignSave.from_snapshot(forged) == null, "sauvegarde à l'âge local hors bornes refusée")

# ---------------------------------------------------------------- zonage
func _zoning() -> void:
	var c: StarCampaign = mk(1414)
	var pc: PlanetCampaign = c.planets
	var p: Dictionary = pc.colony(0, "val")
	check(not bool(c.set_zoning_balance(0, "val", 0.5, 0.3, 0.3).get("ok", true)), "ratio dont la somme dépasse 100 % refusé")
	check(not bool(c.set_zoning_balance(0, "val", 0.98, 0.01, 0.01).get("ok", true)), "ratio hors bornes refusé")
	check(bool(c.set_zoning_balance(0, "val", 0.6, 0.2, 0.2).get("ok", false)), "ratio 60/20/20 accepté")
	var ocean: int = -1
	var wild: int = -1
	for id in 72:
		if pc.land_of(c, p, id) == J13Rules.LAND_OCEAN and ocean < 0:
			ocean = id
		if pc.land_of(c, p, id) in [J13Rules.LAND_RELIEF, J13Rules.LAND_PROTECTED] and wild < 0:
			wild = id
	check(ocean >= 0 and not pc.eligible(c, p, ocean) and wild >= 0 and String(c.build_road(0, "val", wild).get("reason_code", "")) == "land", "océan hors périmètre, relief et réserve naturelle non aménageables")
	var far: int = -1
	for id in 72:
		if pc.eligible(c, p, id) and not (p["cells"] as Dictionary).has(id):
			var touching: bool = false
			for n in PlanetCampaign.neighbors(id):
				if (p["cells"] as Dictionary).has(n):
					touching = true
			if not touching:
				far = id
				break
	check(far >= 0 and String(c.zone_planet(0, "val", far, "R").get("reason_code", "")) == "site", "zone sans accès routier refusée")
	fund(c, 0, 1000.0)
	var first_network: Array = grow(c, 0, "val", ["power", "water"])
	var built: Array = grow(c, 0, "val", ["R", "R"])
	check(built.min() >= 0, "deux districts résidentiels construits")
	(p["stocks"] as Dictionary)["concrete"] = 100.0
	check(bool(pc.densify(c, 0, "val", int(built[1])).get("ok", false)), "densification payée (crédits + béton)")
	var housing: Dictionary = pc.housing_by_cell(p, pc.connected(p), pc.utilities(p, pc.connected(p)))
	check(int(housing[int(built[1])]) == 2 * int(housing[int(built[0])]), "capacité de logement selon la densité, pas selon la surface")
	fast(c, 400)
	check(int(p["pop"]) > 0 and int(p["pop"]) <= int((p["stats"] as Dictionary)["housing"]), "population née dans les logements, bornée par la capacité")
	# Commerce sans produit : aucun crédit inventé.
	var shop: Array = grow(c, 0, "val", ["C"])
	var food_saved: float = float(c.resources[0]["food"])
	c.resources[0]["food"] = 0.0
	var minted: float = float((pc.treasury[0] as Dictionary)["minted"])
	var pop_before: int = int(p["pop"])
	fast(c, 200)
	check(shop[0] >= 0 and is_equal_approx(float((pc.treasury[0] as Dictionary)["minted"]), minted), "commerce sans produit à vendre : zéro crédit créé")
	check(int(p["pop"]) < pop_before, "sans nourriture la population recule")
	c.resources[0]["food"] = food_saved
	fast(c, 200)
	check(float((pc.treasury[0] as Dictionary)["minted"]) > minted, "produit réel vendu : chiffre d'affaires")
	# Usine : eau et énergie réelles.
	pc.demolish(c, 0, "val", int(first_network[0]))
	var plant: Array = grow(c, 0, "val", ["I"])
	var alloy: float = float((p["stocks"] as Dictionary)["alloy"])
	fast(c, 60)
	var cell: Dictionary = (p["cells"] as Dictionary)[int(plant[0])] as Dictionary
	check(String(cell["halt"]) == "électricité" and is_equal_approx(float((p["stocks"] as Dictionary)["alloy"]), alloy), "usine sans électricité : production refusée et expliquée")
	check(float((p["stats"] as Dictionary)["power"]) < 1.0, "centrales insuffisantes : déficit mesuré")
	grow(c, 0, "val", ["power"])
	fast(c, 60)
	check(String(cell["halt"]).is_empty() and float((p["stocks"] as Dictionary)["alloy"]) > alloy, "réseau rétabli : l'usine produit")
	var ore: float = float(c.resources[0]["ore"])
	alloy = float((p["stocks"] as Dictionary)["alloy"])
	fast(c, 20)
	check(ore - float(c.resources[0]["ore"]) >= 2.0 * (float((p["stocks"] as Dictionary)["alloy"]) - alloy) - 0.001, "recette conservatrice : pas de matière créée")
	check(bool(pc.demolish(c, 0, "val", int(first_network[1])).get("ok", false)), "station d'eau retirée")
	fast(c, 40)
	check(String(cell["halt"]) == "eau", "sans station d'eau la production s'arrête")
	# Budget zéro : refus sans effet.
	(pc.treasury[0] as Dictionary)["spent"] = float((pc.treasury[0] as Dictionary)["spent"]) + pc.credits(0)
	(pc.treasury[0] as Dictionary)["credits"] = 0.0
	var state: String = c.state_hash()
	var refused: Array = grow(c, 0, "val", ["hospital"])
	check(refused[0] == -1 and c.state_hash() == state, "construction à budget zéro refusée, aucun débit")
	check(pc.books_balanced(0), "comptes équilibrés")

# ---------------------------------------------------------------- services
func _services() -> void:
	var c: StarCampaign = mk(1515)
	var pc: PlanetCampaign = c.planets
	var p: Dictionary = pc.colony(0, "val")
	fund(c, 0, 50000.0)
	var ids: Array = grow(c, 0, "val", ["power", "water", "hospital", "fire", "police", "R", "R", "R", "R"])
	check(ids.min() >= 0, "quartier et services construits")
	p["pop"] = 150
	var report: Dictionary = pc.service_report(p)
	var initial: float = float((report["hospital"] as Dictionary)["coverage"])
	var explained: bool = true
	for cause in ((report["hospital"] as Dictionary)["uncovered"] as Dictionary).values():
		if String(cause).is_empty():
			explained = false
	check(initial > 0.3 and explained, "quartiers desservis par la route (%d %%), les autres avec leur cause" % int(initial * 100.0))
	# Dans le rayon visuel mais sans accès routier.
	var hospital: int = int(ids[2])
	check(pc.damage_road(0, "val", hospital), "route de l'hôpital coupée")
	report = pc.service_report(p)
	check(float((report["hospital"] as Dictionary)["coverage"]) < 0.01, "voisin immédiat mais hors accès routier = non desservi")
	check(bool(pc.repair_road(c, 0, "val", hospital).get("ok", false)) and is_equal_approx(float((pc.service_report(p)["hospital"] as Dictionary)["coverage"]), initial), "route reconstruite : service rétabli")
	# Saturation par la capacité, pas par la distance.
	for id in ids.slice(5):
		((p["cells"] as Dictionary)[int(id)] as Dictionary)["density"] = 3
	p["pop"] = 496
	report = pc.service_report(p)
	var causes: Array = ((report["hospital"] as Dictionary)["uncovered"] as Dictionary).values()
	check(float((report["hospital"] as Dictionary)["coverage"]) < 1.0 and (causes.has("poste saturé") or causes.has("hors d'atteinte par la route")), "hôpital saturé ou trop loin : quartier sous-couvert avec sa cause")
	p["pop"] = 150
	check(float((pc.service_report(p)["police"] as Dictionary)["coverage"]) > 0.0, "couverture recalculée après changement de population")

# ---------------------------------------------------------------- gouverneur
func _governor() -> void:
	var c: StarCampaign = mk(1616)
	var pc: PlanetCampaign = c.planets
	var p: Dictionary = pc.colony(0, "val")
	var gov: Dictionary = p["governor"] as Dictionary
	check(bool(gov["granted"]) and not bool(gov["enabled"]) and bool(c.set_governor_policy(0, "val", true).get("ok", false)), "gouverneur accordé à l'âge X local, suspendu puis repris par le joueur")
	check(not bool((pc.colony(1, "val")["governor"] as Dictionary)["enabled"]), "pas de gouverneur pour le camp resté à l'âge I")
	# Sans ressources : rien de gratuit.
	var saved_stock: Dictionary = (c.resources[0] as Dictionary).duplicate(true)
	c.resources[0]["wood"] = 0.0
	c.resources[0]["ore"] = 0.0
	var cells_before: int = (p["cells"] as Dictionary).size()
	fast(c, 400)
	check((p["cells"] as Dictionary).size() == cells_before and String(gov["status"]).begins_with("en attente"), "sans ressources : aucun chantier gratuit, cause affichée")
	c.resources[0]["wood"] = float(saved_stock["wood"])
	c.resources[0]["ore"] = float(saved_stock["ore"])
	# Réserve protégée, bâtiment manuel et ratio du joueur.
	var sites: Dictionary = PlanetGovernor._sites(c, pc, p, pc.connected(p))
	var reserve: int = int((sites["frontier"] as Array)[0])
	check(bool(pc.set_reserved(c, 0, "val", reserve, true).get("ok", false)), "district protégé par le joueur")
	var manual: Array = grow(c, 0, "val", ["C"])
	c.set_zoning_balance(0, "val", 0.4, 0.3, 0.3)
	fund(c, 0, 10000000.0)
	gov["budget_cap"] = 100000.0
	for good in J13Rules.GOODS:
		(p["stocks"] as Dictionary)[good] = 4000.0
	fast(c, 1500)
	var midway: Dictionary = CampaignSave.snapshot(c)
	var clone: StarCampaign = CampaignSave.from_snapshot(midway)
	check(clone != null and clone.state_hash() == c.state_hash(), "plan du gouverneur sauvegardé")
	var history: Dictionary = {}
	var rebuilt: bool = false
	var done_at: int = -1
	for cycle in 400:
		fast(c, 100)
		if clone != null and cycle < 10:
			fast(clone, 100)
		for id in (p["cells"] as Dictionary).keys():
			var kind: String = PlanetCampaign.cell_kind((p["cells"] as Dictionary)[id] as Dictionary)
			if history.has(id) and not String(history[id]).is_empty() and String(history[id]) != kind:
				rebuilt = true
			history[id] = kind
		if cycle == 9 and clone != null:
			check(clone.state_hash() == c.state_hash(), "reprise du plan : mêmes décisions aux mêmes ticks")
		if done_at < 0 and String(gov["status"]).begins_with("périmètre éligible aménagé à 100"):
			done_at = cycle
			break
	check(done_at >= 0 and is_equal_approx(pc.developed_ratio(c, p), 1.0), "100 %% du périmètre éligible aménagé (cycle %d)" % done_at)
	var clean: bool = true
	for id in (p["cells"] as Dictionary).keys():
		var occupied: bool = not PlanetCampaign.cell_kind((p["cells"] as Dictionary)[id] as Dictionary).is_empty()
		if (occupied and pc.land_of(c, p, int(id)) != J13Rules.LAND_BUILDABLE) or int(id) == reserve:
			clean = false
		if pc.land_of(c, p, int(id)) in [J13Rules.LAND_RELIEF, J13Rules.LAND_PROTECTED]:
			clean = false
	check(clean, "ni océan, ni relief, ni réserve aménagés pour atteindre 100 %")
	check(not rebuilt and String(((p["cells"] as Dictionary)[int(manual[0])] as Dictionary)["zone"]) == "C", "aucune démolition/reconstruction, bâtiment manuel intact")
	check(is_equal_approx(float((p["target"] as Dictionary)["R"]), 0.4) and float((p["stats"] as Dictionary)["balance"]) > 0.9, "ratio du joueur respecté, jamais modifié")
	var stats: Dictionary = p["stats"] as Dictionary
	check(float(stats["power"]) >= 0.999 and float(stats["water"]) >= 0.999, "eau et électricité couvertes")
	check(float(stats["hospital"]) >= 0.99 and float(stats["fire"]) >= 0.99 and float(stats["police"]) >= 0.99, "santé, pompiers et police >= 99 %% (%.3f %.3f %.3f)" % [float(stats["hospital"]), float(stats["fire"]), float(stats["police"])])
	fast(c, 100000)
	var moved: bool = false
	for id in (p["cells"] as Dictionary).keys():
		if not history.has(id) or String(history[id]) != PlanetCampaign.cell_kind((p["cells"] as Dictionary)[id] as Dictionary):
			moved = true
	check(not moved, "stable après 1 000 cycles supplémentaires : aucun chantier parasite")
	check(pc.books_balanced(0), "comptes équilibrés après 100 000 ticks")
	check(not (gov["journal"] as Array).is_empty() and String(((gov["journal"] as Array)[0] as Dictionary)["why"]) != "", "journal des décisions avec raisons")
	var negative: bool = false
	for good in J13Rules.GOODS:
		if float((p["stocks"] as Dictionary)[good]) < -0.001:
			negative = true
	check(not negative and float(c.resources[0]["ore"]) >= 0.0 and float(c.resources[0]["food"]) >= 0.0, "aucun stock négatif")

# ---------------------------------------------------------------- verrou orbital
func _orbital() -> void:
	var c: StarCampaign = mk(1717)
	var pc: PlanetCampaign = c.planets
	colony_ready(c)
	full(c, 200)
	# Colonie adverse VII sur Aurore, sans station : vulnérable.
	var w: SimWorld = c.worlds["aurore"]
	w.spawn_building(1, "centre", c._landing_cell(w, 1), true)
	pc.found(c, 1, "aurore", "colony", 20)
	c.resources[1] = {"food": 50000.0, "wood": 50000.0, "ore": 50000.0}
	check(pc.landing_blocked(c, 0, "aurore") == 0 and bool(c.request_hostile_landing(0, "aurore").get("ok", false)), "colonie VII sans station : débarquement possible")
	# Deux stations ennemies.
	c.orbital_sites[OrbitalIndustry.key(1, "aurore")] = OrbitalIndustry._new_site(1, "aurore", 0)
	OrbitalIndustry.presence(c, 1, "aurore")["drone"] = 1
	c.ages[1] = 9
	pc.colony(1, "aurore")["local_age"] = 9
	fund(c, 1, 1000.0)
	check(bool(c.start_orbital_station(1, "aurore").get("ok", false)), "seconde station payée par le défenseur")
	check(pc.landing_blocked(c, 0, "aurore") == 1, "station en assemblage : pas encore comptée")
	full(c, 181)
	check(pc.landing_blocked(c, 0, "aurore") == 2 and pc.lock_text(c, 0, "aurore") == "INVASION BLOQUÉE : 2 STATIONS DE COMMANDEMENT ENNEMIES", "deux stations opérationnelles : invasion bloquée")
	var home: SimWorld = c.worlds["val"]
	var port: SimWorld.Building = null
	for b in home.team_buildings(0, "spatioport", true):
		port = b
	var ship: SimWorld.Unit = home.spawn_unit(0, "navette", port.center + Vector2(4, 4))
	var builder: SimWorld.Unit = home.spawn_unit(0, "ouvrier", port.center + Vector2(5, 5))
	var landing: Dictionary = c.dispatch(0, "val", port.id, "aurore", [builder.id], ship.id)
	check(String(landing.get("reason_code", "")) == "orbital_lock" and home.units.has(ship.id) and home.units.has(builder.id), "débarquement refusé, équipage resté au sol")
	check(String(c.found_colony(0, "val", "aurore").get("reason_code", "")) == "orbital_lock", "transport de colons refusé par le même verrou")
	check(not bool(c.attack_orbital_station(0, "aurore").get("ok", true)), "pas d'assaut sans escadre armée en orbite")
	# Première destruction : toujours bloqué.
	OrbitalIndustry.presence(c, 0, "val")["intercepteur"] = 12
	check(bool(c.orbital_send(0, "val", "aurore", {"intercepteur": 12}).get("ok", false)), "attaque spatiale autorisée malgré le verrou")
	full(c, 162)
	check(pc.landing_blocked(c, 0, "aurore") == 1 and not bool(c.request_hostile_landing(0, "aurore").get("ok", true)), "une station détruite sur deux : invasion toujours bloquée")
	check(int(OrbitalIndustry.presence(c, 0, "aurore").get("intercepteur", 0)) == 12, "escadre victorieuse restée en orbite")
	check(bool(c.attack_orbital_station(0, "aurore").get("destroyed", false)) and pc.landing_blocked(c, 0, "aurore") == 0, "seconde destruction : débarquement ouvert")
	check(not w.team_buildings(1, "centre", true).is_empty(), "détruire les stations ne conquiert pas la planète")
	landing = c.dispatch(0, "val", port.id, "aurore", [builder.id], ship.id)
	check(bool(landing.get("ok", false)), "première vague légale envoyée")
	full(c, 100)
	# Station reconstruite pendant le vol : la vague attend, rien n'est perdu.
	c.orbital_sites[OrbitalIndustry.key(1, "aurore")] = OrbitalIndustry._new_site(1, "aurore", 0)
	full(c, 80)
	check(c.flights.size() == 1 and bool(c.flights[0].get("locked", false)) and w.team_buildings(0, "centre", true).is_empty(), "station reconstruite : nouvelle vague bloquée en orbite, sans perte")
	c.attack_orbital_station(0, "aurore")
	full(c, 3)
	check(c.flights.is_empty() and not w.team_buildings(0, "centre", true).is_empty(), "verrou levé : la vague débarque une seule fois")
	check(pc.has_colony(0, "aurore") and String(pc.colony(0, "aurore")["origin"]) == "conquered", "tête de pont enregistrée comme occupation, pas comme colonie neuve")
	c.orbital_sites[OrbitalIndustry.key(1, "aurore")] = OrbitalIndustry._new_site(1, "aurore", 0)
	check(not w.team_units(0, "builder").is_empty() and pc.landing_blocked(c, 0, "aurore") == 1, "troupes déjà au sol conservées, renforts suivants bloqués")
	# L'IA (camp 1) subit exactement la même validation.
	check(pc.station_count(c, 0, "val") == 1 and pc.landing_blocked(c, 1, "val") == 0, "monde fondateur partagé : jamais un débarquement hostile")
	pc.found(c, 0, "nemesis", "colony", 12)
	c.orbital_sites[OrbitalIndustry.key(0, "nemesis")] = OrbitalIndustry._new_site(0, "nemesis", 0)
	c.ages[1] = 10
	check(String(c.transfer_materials(1, "aurore", "nemesis", {"colonists": 12, "found": true}).get("reason_code", "")) in ["orbital_lock", "route", "destination"] and pc.landing_blocked(c, 1, "nemesis") == 1, "l'IA est bloquée par la même règle")
	# L'IA assiège la station au lieu de rester bloquée : hangar -> intercepteurs -> escadre -> assaut.
	c.orbital_sites[OrbitalIndustry.key(1, "val")] = OrbitalIndustry._new_site(1, "val", 0)
	OrbitalIndustry.presence(c, 1, "val")["drone"] = 1
	c._sync_all()
	var ore_before: float = float(c.resources[1]["ore"])
	var first_action: String = pc.ai_orbital(c, 1)
	check(first_action.begins_with("hangar:") and float(c.resources[1]["ore"]) < ore_before, "IA : construit un hangar payé pour lever le verrou (%s)" % first_action)
	(c.orbital_sites[OrbitalIndustry.key(1, "val")] as Dictionary)["job"] = {}
	((c.orbital_sites[OrbitalIndustry.key(1, "val")] as Dictionary)["modules"] as Dictionary)["hangar"] = 1
	check(pc.ai_orbital(c, 1) == "intercepteur:val", "IA : produit des intercepteurs payés")
	(c.orbital_sites[OrbitalIndustry.key(1, "val")] as Dictionary)["job"] = {}
	OrbitalIndustry.presence(c, 1, "val")["intercepteur"] = 11
	OrbitalIndustry.presence(c, 1, "val")["fregate"] = 1
	var ai_action: String = pc.ai_orbital(c, 1)
	check(ai_action.begins_with("escadre:") and c.orbital_flights.size() == 1 and int(c.orbital_flights[0]["team"]) == 1, "IA : envoie une escadre contre la station (%s), pas de débarquement" % ai_action)
	c._sync_all()
	var snapshot: Dictionary = CampaignSave.snapshot(c)
	var copy: StarCampaign = CampaignSave.from_snapshot(snapshot)
	check(copy != null and copy.state_hash() == c.state_hash() and copy.planets.landing_blocked(copy, 0, "aurore") == 1, "verrou et stations conservés par la sauvegarde")

# ---------------------------------------------------------------- transports et trésorerie
func _transport_and_treasury() -> void:
	var c: StarCampaign = mk(1818)
	var pc: PlanetCampaign = c.planets
	colony_ready(c)
	var state: String = c.state_hash()
	check(not bool(c.transfer_materials(0, "val", "aurore", {"colonists": 13, "found": true}).get("ok", true)) and c.state_hash() == state, "manifeste au-delà de la capacité refusé sans débit")
	check(not bool(c.transfer_materials(0, "val", "aurore", {"colonists": 3}).get("ok", true)), "transport sans colonie d'accueil refusé")
	var sent: Dictionary = c.found_colony(0, "val", "aurore")
	check(bool(sent.get("ok", false)), "mission de fondation lancée")
	full(c, 70)
	var mission: Dictionary = pc.transports[0] as Dictionary
	check(String(mission["state"]) == "en_route" and not pc.has_colony(0, "aurore") and not bool(mission["delivered_once"]), "en vol : ni au sol ni livré")
	var mid: Dictionary = CampaignSave.snapshot(c)
	var resumed: StarCampaign = CampaignSave.from_snapshot(mid)
	check(resumed != null and resumed.state_hash() == c.state_hash(), "sauvegarde au milieu du trajet")
	full(c, 95)
	if resumed != null:
		full(resumed, 95)
		check(resumed.state_hash() == c.state_hash() and int(resumed.planets.colony(0, "aurore")["pop"]) in [12, 13] and resumed.planets.transport_log.size() == 1, "reprise : une seule arrivée, 12 colons")
	check(pc.transports.is_empty() and pc.transport_log.size() == 1 and bool((pc.transport_log[0] as Dictionary)["delivered_once"]), "mission archivée, livrée une fois")
	var forged: Dictionary = mid.duplicate(true)
	(forged["j13"]["transports"][0] as Dictionary)["delivered_once"] = true
	check(CampaignSave.from_snapshot(forged) == null, "sauvegarde d'un transport actif déjà livré refusée")
	# Matériaux localisés : B ne reçoit que par navette.
	(pc.colony(0, "val")["stocks"] as Dictionary)["alloy"] = 400.0
	check(is_zero_approx(float((pc.colony(0, "aurore")["stocks"] as Dictionary)["alloy"])), "400 alliages sur A : 0 utilisable sur B")
	check(not bool(c.transfer_materials(0, "val", "aurore", {"goods": {"alloy": 500}}).get("ok", true)), "fret supérieur au stock ou à la cale refusé")
	check(bool(c.transfer_materials(0, "val", "aurore", {"goods": {"alloy": 50}, "colonists": 3}).get("ok", false)), "50 alliages et 3 colons embarqués")
	check(is_equal_approx(float((pc.colony(0, "val")["stocks"] as Dictionary)["alloy"]), 350.0), "stock de départ débité une fois")
	var lost_id: int = int((pc.transports[0] as Dictionary)["id"])
	full(c, 40)
	check(pc.destroy_transport(c, lost_id, "interception"), "transport détruit explicitement")
	full(c, 200)
	check(is_zero_approx(float((pc.colony(0, "aurore")["stocks"] as Dictionary)["alloy"])) and String((pc.transport_log.back() as Dictionary)["state"]) == "lost", "transport perdu : rien n'arrive, passagers perdus consignés")
	check(bool(c.transfer_materials(0, "val", "aurore", {"goods": {"alloy": 50}}).get("ok", false)), "second envoi")
	full(c, 165)
	check(is_equal_approx(float((pc.colony(0, "aurore")["stocks"] as Dictionary)["alloy"]), 50.0) and is_equal_approx(float((pc.colony(0, "val")["stocks"] as Dictionary)["alloy"]), 300.0), "50 livrés sur B, 300 restent sur A : ni perte ni duplication")
	check(not bool(c.transfer_materials(0, "val", "aurore", {"goods": {"ore": 50}}).get("ok", true)), "minerai : déjà dans le dépôt commun du système, pas de téléportation simulée")
	# Trésorerie : un virement par période, seulement s'il y a un bénéfice.
	var p: Dictionary = pc.colony(0, "val")
	fund(c, 0, 500.0)
	var funded: float = pc.credits(0)
	grow(c, 0, "val", ["power", "water", "C", "C"])
	fast(c, 5 * J13Rules.TRANSFER_PERIOD)
	var transfers: int = 0
	for entry in pc.ledger:
		if String(entry["memo"]) == "bénéfice net":
			transfers += 1
	check(transfers >= 1 and transfers <= 5 and pc.credits(0) > funded, "bénéfice net viré à la trésorerie, au plus une fois par période (%d)" % transfers)
	check(float(p["reserve"]) <= J13Rules.RESERVE_FLOOR + float((p["stats"] as Dictionary)["sales"]) * 12.0, "réserve d'exploitation locale conservée")
	check(pc.books_balanced(0), "comptes équilibrés : trésorerie + réserves = créé - dépensé")
	var credits_now: float = pc.credits(0)
	var reloaded: StarCampaign = CampaignSave.from_snapshot(CampaignSave.snapshot(CampaignSave.from_snapshot(CampaignSave.snapshot(c))))
	check(reloaded != null and is_equal_approx(reloaded.planets.credits(0), credits_now), "rechargements : aucun bénéfice recrédité")
	c.resources[0]["food"] = 0.0
	var seq: int = int((pc.treasury[0] as Dictionary)["seq"])
	(pc.colony(0, "val")["reserve"]) = 0.0
	(pc.treasury[0] as Dictionary)["minted"] = pc.credits(0) + float(pc.colony(0, "aurore")["reserve"]) + float((pc.treasury[0] as Dictionary)["spent"])
	fast(c, 2 * J13Rules.TRANSFER_PERIOD)
	check(int((pc.treasury[0] as Dictionary)["seq"]) == seq and float(p["reserve"]) >= 0.0, "déficit : aucun profit fictif, réserve jamais négative")
	var path: String = "user://j13-test.save"
	check(CampaignSave.save(c, path) == OK, "écriture atomique du fichier de campagne")
	var from_disk: StarCampaign = CampaignSave.load_campaign(path, false)
	check(from_disk != null and from_disk.state_hash() == c.state_hash(), "relecture du fichier : état identique")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
