extends SceneTree
## 0.18 — Recette de simulation de la ville (UrbanCity) : déclencheur, remplacement net, zones, réseaux, services,
## criminalité, incendies, maladies, pollution, bien-être, production, sauvegarde, déterminisme, IA, anciens modes intacts.
var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

func fixture(urban: bool = true, tech: bool = true) -> SimWorld:
	var w := SimWorld.new()
	w.setup(18010, {"campaign": true, "urban": urban})
	for y in 96:
		for x in 96:
			w.set_terrain(Vector2i(x, y), SimWorld.TERRAIN_GRASS)
	for t in [0, 1]:
		w.teams[t].res = {"food": 5000.0, "wood": 5000.0, "ore": 5000.0}
		w.teams[t].age = 4
	w.spawn_building(0, "centre", Vector2i(10, 10), true)
	w.spawn_building(1, "centre", Vector2i(80, 80), true)
	w.issue({"t": "lab_reveal", "team": 0})
	w.issue({"t": "lab_reveal", "team": 1})
	w.update_fog(true)
	if tech:
		w.teams[0].technologies[UrbanRules.TECH] = true
	return w

func run(w: SimWorld, ticks: int) -> void:
	for i in ticks:
		w.step()

func period(w: SimWorld, n: int = 1) -> void:
	run(w, UrbanRules.PERIOD * n)

func zone(w: SimWorld, kind: String, cell: Vector2i, team: int = 0) -> SimWorld.Building:
	return w.spawn_building(team, kind, cell, true)

func refused(w: SimWorld, cmd: Dictionary, label: String) -> void:
	var before: String = w.state_hash() + var_to_str(w.teams[0].res)
	var result: Dictionary = w.issue(cmd)
	check(not bool(result.get("ok", true)) and w.state_hash() + var_to_str(w.teams[0].res) == before, label + " (refus sans effet : %s)" % String(result.get("reason", "")))

func events_of(w: SimWorld, kind: String) -> int:
	var n: int = 0
	for e in w.event_log:
		if String(e["type"]) == kind:
			n += 1
	return n

func _initialize() -> void:
	_gating()
	_research_and_switch()
	_networks()
	_services_and_pollution()
	_growth_and_production()
	_fire_and_disease()
	_save_and_determinism()
	_ai()
	print("URBAN_CITY_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

# ---------------------------------------------------------------- déclencheur

func _gating() -> void:
	var old: SimWorld = fixture(false, false)
	var usine: SimWorld.Building = old.spawn_building(0, "usine", Vector2i(20, 10), true)
	refused(old, {"t": "technology", "team": 0, "building": usine.id, "key": UrbanRules.TECH}, "U01 partie sans évolution de la civilisation : recherche Électricité refusée")
	check(not CivEvolution.visible_building(old, 0, "zone_r") and CivEvolution.visible_building(old, 0, "maison"), "U02 ancien mode : zones invisibles, maison toujours proposée")
	check(old.build_check(0, "zone_r", Vector2i(20, 20)) != "", "U03 ancien mode : zone refusée (%s)" % old.build_check(0, "zone_r", Vector2i(20, 20)))
	var w: SimWorld = fixture(true, false)
	w.spawn_unit(0, "ouvrier", Vector2(16.5, 16.5))
	# 0.19 (décision de l'auteur) : les zones ne se posent plus par « Bâtir », elles poussent sur le zonage dès l'âge I.
	check(w.build_check(0, "zone_r", Vector2i(20, 20)).contains("Zonage") and w.build_check(0, "centrale", Vector2i(20, 20)).contains("Électricité"), "U04 zone : par le zonage ; centrale : « recherche Électricité requise »")
	check(w.build_check(0, "maison", Vector2i(20, 20)) == "" and CivEvolution.visible_building(w, 0, "maison"), "U05 sans la recherche : maison constructible")
	var u2: SimWorld.Building = w.spawn_building(0, "usine", Vector2i(24, 10), true)
	w.teams[0].age = 3
	refused(w, {"t": "technology", "team": 0, "building": u2.id, "key": UrbanRules.TECH}, "U06 âge III : recherche refusée")

# ---------------------------------------------------------------- recherche et remplacement net

func _research_and_switch() -> void:
	var w: SimWorld = fixture(true, false)
	var house: SimWorld.Building = w.spawn_building(0, "maison", Vector2i(16, 10), true)
	var farm: SimWorld.Building = w.spawn_building(0, "ferme", Vector2i(16, 14), true)
	var usine: SimWorld.Building = w.spawn_building(0, "usine", Vector2i(22, 10), true)
	var cap_before: int = w.teams[0].pop_cap
	var worker: SimWorld.Unit = w.spawn_unit(0, "ouvrier", Vector2(14.5, 16.5))
	w.nodes.clear()
	var tree: SimWorld.ResNode = SimWorld.ResNode.new()
	tree.id = w.new_id(); tree.kind = "arbre"; tree.res = "wood"; tree.pos = Vector2(15.5, 20.5); tree.amount = 500.0; tree.max_amount = 500.0; tree.cell = Vector2i(15, 20)
	w.nodes[tree.id] = tree
	w.teams[0].priorities = {"food": 0, "wood": 3, "ore": 0}
	run(w, 120)
	check(worker.task == "wood" and worker.carry_amt > 0.0, "U07 avant la recherche : l'ouvrier récolte du bois")
	var r: Dictionary = w.issue({"t": "technology", "team": 0, "building": usine.id, "key": UrbanRules.TECH})
	check(bool(r.get("ok", false)), "U08 recherche Électricité lancée à l'usine, âge IV (%s)" % String(r.get("reason", "")))
	run(w, int(float(Rules.TECHNOLOGIES[UrbanRules.TECH]["time"]) * Rules.TICK_RATE) + 40)
	check(w.teams[0].technologies.has(UrbanRules.TECH) and bool(w.teams[0].city.get("switched", false)), "U09 recherche achevée : la ville est ouverte")
	check(house.type == "zone_r" and int(house.city.get("level", 0)) == 1, "U10 la maison est devenue une zone d'habitation de niveau I")
	check(w.teams[0].pop_cap == cap_before, "U11 aucune place d'unité perdue à la conversion (%d → %d)" % [cap_before, w.teams[0].pop_cap])
	check(bool(farm.city.get("retired", false)) and farm.farmer == -1, "U12 la ferme est arrêtée")
	check(events_of(w, "ville") >= 1, "U13 annonce « Électricité : la ville remplace… »")
	run(w, 200)
	var wood: float = float(w.teams[0].stats["gathered"]["wood"])
	run(w, 200)
	check(worker.task == "" and worker.carry_amt == 0.0 and tree.amount > 0.0, "U14 l'ouvrier a déposé sa charge et ne récolte plus")
	check(float(w.teams[0].stats["gathered"]["wood"]) - wood < 1.0, "U15 plus aucun bois récolté par les ouvriers")
	refused(w, {"t": "gather", "team": 0, "units": [worker.id], "node": tree.id}, "U16 ordre « récolter » refusé")
	for kind in ["maison", "ferme", "entrepot"]:
		check(w.build_check(0, kind, Vector2i(30, 30)).contains("remplacé"), "U17 %s : plus constructible (%s)" % [kind, w.build_check(0, kind, Vector2i(30, 30))])
	# 0.19 (décision de l'auteur) : la pose manuelle des zones est remplacée par le zonage peint ; la zone commerciale
	# pousse seule sur une parcelle zonée reliée au centre par une route (même commande pour le joueur et l'IA).
	check(not CivEvolution.visible_building(w, 0, "maison") and not CivEvolution.visible_building(w, 0, "zone_c") and CivEvolution.visible_building(w, 0, "commissariat"), "U18 menu Bâtir : maison et zones masquées, services proposés")
	var b: Dictionary = w.issue({"t": "build", "team": 0, "type": "zone_c", "cell": [14, 20]})
	check(not bool(b.get("ok", false)), "U19 « build » d'une zone refusé : elle se crée par le zonage")
	var cc: SimWorld.Building = w.team_buildings(0, "centre")[0]
	var road: Array = []
	for y in range(cc.cell.y + cc.size, cc.cell.y + cc.size + 8):
		road.append([cc.cell.x - 1, y])
	w.issue({"t": "road_paint", "team": 0, "cells": road})
	w.issue({"t": "zone_paint", "team": 0, "kind": 4, "from": [cc.cell.x, cc.cell.y + cc.size + 2], "to": [cc.cell.x + 1, cc.cell.y + cc.size + 5]})
	w.teams[0].city["demand"] = {}
	run(w, 600)
	var zc: SimWorld.Building = null
	for candidate in w.team_buildings(0, "zone_c"):
		zc = candidate
	check(zc != null and zc.complete and bool(zc.city.get("ready", false)) and bool(zc.city.get("grown", false)), "U20 la zone commerciale a poussé sur la parcelle zonée, elle est en service")

# ---------------------------------------------------------------- réseaux

func _networks() -> void:
	var w: SimWorld = fixture()
	period(w)
	var near: SimWorld.Building = zone(w, "zone_r", Vector2i(16, 10))
	var far: SimWorld.Building = zone(w, "zone_r", Vector2i(40, 40))
	period(w)
	check(bool(near.city.get("powered", false)) and bool(near.city.get("watered", false)), "N01 près du centre : électricité et eau du centre")
	check(not bool(far.city.get("powered", true)) and not bool(far.city.get("powered_grid", true)), "N02 loin : hors réseau")
	check(UrbanCity.zone_summary(far).contains("hors réseau"), "N03 la fiche explique « hors réseau »")
	var plant: SimWorld.Building = zone(w, "centrale", Vector2i(44, 36))
	period(w)
	check(bool(far.city.get("powered", false)), "N04 une centrale proche alimente la zone")
	var lonely: SimWorld.Building = zone(w, "zone_c", Vector2i(60, 36))
	period(w)
	check(not bool(lonely.city.get("powered", true)), "N05 zone hors de portée de la centrale")
	zone(w, "poste_electrique", Vector2i(52, 37))
	zone(w, "poste_electrique", Vector2i(57, 37))
	period(w)
	check(bool(lonely.city.get("powered", false)), "N06 deux postes électriques en chaîne prolongent le réseau")
	var power: Array = w.teams[0].city["power"] as Array
	check(int(power[0]) == 8 + 60 and int(power[1]) >= 3, "N07 bilan électrique : production %d, consommation %d" % [int(power[0]), int(power[1])])
	# Pénurie : délestage par priorité, services d'abord.
	var w2: SimWorld = fixture()
	var hosp: SimWorld.Building = zone(w2, "hopital", Vector2i(16, 14))
	var zones: Array = []
	for i in 4:
		zones.append(zone(w2, "zone_i", Vector2i(16 + 3 * i, 6)))
	period(w2)
	check(bool(hosp.city.get("powered", false)), "N08 pénurie : l'hôpital reste alimenté (priorité)")
	var cut: int = 0
	for z in zones:
		if not bool((z as SimWorld.Building).city.get("powered", true)):
			cut += 1
	check(cut >= 2 and events_of(w2, "panne_electrique") >= 1, "N09 pénurie : %d zones délestées, alerte émise" % cut)
	# Eau : un château d'eau sans électricité ne fournit rien.
	var w3: SimWorld = fixture()
	var t1: SimWorld.Building = zone(w3, "chateau_eau", Vector2i(50, 50))
	var dry: SimWorld.Building = zone(w3, "zone_r", Vector2i(53, 50))
	period(w3)
	check(not bool(dry.city.get("watered", true)), "N10 château d'eau sans électricité : pas d'eau")
	zone(w3, "centrale", Vector2i(46, 46))
	period(w3)
	check(bool(t1.city.get("powered", false)) and bool(dry.city.get("watered", false)), "N11 château d'eau alimenté : quartier desservi")

# ---------------------------------------------------------------- services, criminalité, pollution

func _services_and_pollution() -> void:
	var w: SimWorld = fixture()
	zone(w, "centrale", Vector2i(30, 30))
	zone(w, "chateau_eau", Vector2i(34, 30))
	var safe: SimWorld.Building = zone(w, "zone_r", Vector2i(30, 36))
	var unsafe: SimWorld.Building = zone(w, "zone_r", Vector2i(46, 20))
	zone(w, "centrale", Vector2i(46, 24))
	zone(w, "chateau_eau", Vector2i(50, 24))
	var police: SimWorld.Building = zone(w, "commissariat", Vector2i(26, 36))
	period(w)
	check(bool(safe.city.get("police", false)) and not bool(unsafe.city.get("police", true)), "S01 commissariat : quartier proche couvert, quartier lointain non")
	check(int(police.city.get("served", 0)) >= 1 and UrbanCity.zone_summary(police).contains("Dessert"), "S02 la fiche du commissariat indique les bâtiments desservis")
	period(w, 12)
	check(float(safe.city["crime"]) < float(unsafe.city["crime"]), "S03 criminalité plus basse sous la police (%.1f < %.1f)" % [float(safe.city["crime"]), float(unsafe.city["crime"])])
	# Capacité limitée : les plus proches d'abord.
	var w2: SimWorld = fixture()
	zone(w2, "centrale", Vector2i(40, 40))
	var station: SimWorld.Building = zone(w2, "caserne_pompiers", Vector2i(44, 44))
	for i in 24:
		zone(w2, "zone_r", Vector2i(36 + (i % 6) * 3, 36 + (i / 6) * 3))
	period(w2)
	check(int(station.city.get("served", 0)) == int(UrbanRules.SERVICES["caserne_pompiers"]["capacity"]), "S04 capacité de la caserne respectée (%d)" % int(station.city.get("served", 0)))
	# Pollution et déchets.
	var w3: SimWorld = fixture()
	zone(w3, "centrale", Vector2i(30, 30))
	var industry: SimWorld.Building = zone(w3, "zone_i", Vector2i(30, 36))
	var homes: SimWorld.Building = zone(w3, "zone_r", Vector2i(33, 36))
	var clean: SimWorld.Building = zone(w3, "zone_r", Vector2i(24, 24))
	period(w3)
	var dirty: float = float(homes.city["pollution"])
	check(dirty > float(clean.city["pollution"]) + 5.0, "S05 l'industrie pollue ses voisins (%.1f contre %.1f)" % [dirty, float(clean.city["pollution"])])
	zone(w3, "decharge", Vector2i(36, 32))
	period(w3)
	check(bool(homes.city.get("waste", false)) and float(homes.city["pollution"]) < dirty * 0.7, "S06 la décharge réduit la pollution (%.1f → %.1f)" % [dirty, float(homes.city["pollution"])])
	check(float(industry.city["pollution"]) > 0.0, "S07 la zone industrielle reste la plus exposée")

# ---------------------------------------------------------------- développement et production

func _growth_and_production() -> void:
	var w: SimWorld = fixture()
	zone(w, "centrale", Vector2i(30, 30))
	zone(w, "chateau_eau", Vector2i(34, 30))
	var r: SimWorld.Building = zone(w, "zone_r", Vector2i(30, 36))
	var r2: SimWorld.Building = zone(w, "zone_r", Vector2i(33, 36))
	var c: SimWorld.Building = zone(w, "zone_c", Vector2i(36, 36))
	var i: SimWorld.Building = zone(w, "zone_i", Vector2i(36, 26))
	period(w)
	check(is_equal_approx(float(r.city["density"]), UrbanRules.START_DENSITY) or float(r.city["density"]) > UrbanRules.START_DENSITY, "G01 zone neuve à demi-densité")
	period(w, 10)
	check(is_equal_approx(float(r.city["density"]), 1.0), "G02 quartier alimenté et heureux : densité au niveau I (%.2f)" % float(r.city["density"]))
	refused(w, {"t": "urban_upgrade", "team": 0, "building": w.team_buildings(0, "centre")[0].id}, "G03 amélioration d'un bâtiment non zone")
	var res_before: Dictionary = w.teams[0].res.duplicate()
	var up: Dictionary = w.issue({"t": "urban_upgrade", "team": 0, "building": r.id})
	check(bool(up.get("ok", false)) and int(r.city["level"]) == 2 and float(w.teams[0].res["wood"]) < float(res_before["wood"]), "G04 amélioration au niveau II payée")
	period(w, 15)
	check(float(r.city["density"]) > 1.0, "G05 le quartier se densifie au-delà du niveau I (%.2f)" % float(r.city["density"]))
	# 0.19 : jusqu'à 6 niveaux selon la catégorie, le zonage et l'âge ; on monte jusqu'au plafond puis on vérifie le refus.
	for k in 6:
		w.issue({"t": "urban_upgrade", "team": 0, "building": r.id})
	refused(w, {"t": "urban_upgrade", "team": 0, "building": r.id}, "G06 niveau maximal (%d)" % UrbanGrowth.level_cap(w, 0, r))
	var hab: int = int(w.teams[0].city["habitants"])
	check(hab == int(r.city["habitants"]) + int(r2.city["habitants"]) and hab > 24, "G07 habitants comptés (%d)" % hab)
	check(int(w.teams[0].city["pop_bonus"]) == hab / UrbanRules.POP_PER_UNIT, "G08 une place d'unité pour %d habitants (+%d)" % [UrbanRules.POP_PER_UNIT, int(w.teams[0].city["pop_bonus"])])
	var food: float = float(w.teams[0].res["food"])
	var ore: float = float(w.teams[0].res["ore"])
	period(w, 5)
	var prod: Dictionary = w.teams[0].city["production"] as Dictionary
	check(float(w.teams[0].res["food"]) > food and float(prod["food"]) > float(UrbanRules.CENTRE_TRICKLE["food"]), "G09 le commerce produit de la nourriture (%.2f/s)" % float(prod["food"]))
	check(float(prod["wood"]) > float(UrbanRules.CENTRE_TRICKLE["wood"]), "G10 le commerce produit du bois (%.2f/s)" % float(prod["wood"]))
	check(float(w.teams[0].res["ore"]) > ore and float(prod["ore"]) > float(UrbanRules.CENTRE_TRICKLE["ore"]), "G11 l'industrie produit du minerai (%.2f/s)" % float(prod["ore"]))
	check(float(c.city.get("employed", 0.0)) > 0.0 and float(i.city.get("employed", 0.0)) > 0.0, "G12 emplois occupés par les habitants")
	var wb: float = float(w.teams[0].city["wellbeing"])
	var f: Dictionary = w.teams[0].city["factors"] as Dictionary
	check(wb >= 0.0 and wb <= 100.0 and f.size() == 7 and float(w.teams[0].city["productivity"]) >= UrbanRules.PRODUCTIVITY_MIN, "G13 bien-être général %.0f / 100, 7 facteurs" % wb)
	# Sans électricité : plus de production.
	var w2: SimWorld = fixture()
	var lone: SimWorld.Building = zone(w2, "zone_i", Vector2i(60, 60))
	zone(w2, "zone_r", Vector2i(16, 10))
	period(w2, 3)
	check(float((lone.city.get("out", {}) as Dictionary).get("ore", 0.0)) == 0.0, "G14 industrie sans électricité : aucune production")
	var r3: SimWorld.Building = zone(w2, "zone_r", Vector2i(64, 64))
	period(w2, 10)
	check(float(r3.city["density"]) <= UrbanRules.START_DENSITY, "G15 quartier sans électricité ni eau : il ne grandit pas")

# ---------------------------------------------------------------- incendies et maladies

func _fire_and_disease() -> void:
	var w: SimWorld = fixture()
	zone(w, "centrale", Vector2i(30, 30))
	var burning: SimWorld.Building = zone(w, "zone_c", Vector2i(50, 30))
	zone(w, "centrale", Vector2i(54, 30))
	period(w)
	burning.city["burning"] = UrbanRules.FIRE_DURATION
	var hp: float = burning.hp
	period(w, 2)
	check(burning.hp < hp, "F01 un incendie endommage le bâtiment (%.0f → %.0f)" % [hp, burning.hp])
	burning.hp = 30.0
	period(w, 2)
	check(not w.buildings.has(burning.id) and events_of(w, "incendie_perte") >= 1, "F02 sans pompiers, le bâtiment brûle entièrement")
	var covered: SimWorld.Building = zone(w, "zone_c", Vector2i(30, 36))
	zone(w, "caserne_pompiers", Vector2i(26, 36))
	period(w)
	covered.city["burning"] = UrbanRules.FIRE_DURATION
	period(w, 3)
	check(w.buildings.has(covered.id) and float(covered.city.get("burning", 1.0)) == 0.0 and covered.hp > covered.max_hp * 0.7, "F03 avec les pompiers, l'incendie est éteint vite")
	var seeds: int = 0
	var test: SimWorld = fixture()
	zone(test, "centrale", Vector2i(30, 30))
	for k in 40:
		zone(test, "zone_i", Vector2i(20 + (k % 10) * 3, 40 + (k / 10) * 3))
	period(test, 150)
	seeds = int(test.teams[0].city.get("fires_total", 0))
	check(seeds >= 1, "F04 des incendies se déclarent seuls dans une ville sans pompiers (%d en 5 min)" % seeds)
	# Maladies.
	var m: SimWorld = fixture()
	var sick: SimWorld.Building = zone(m, "zone_r", Vector2i(50, 50))
	period(m)
	sick.city["density"] = 1.0
	for k in 80:
		sick.city["health_v"] = 10.0
		period(m)
	check(int(m.teams[0].city.get("epidemics", 0)) >= 1 and float(sick.city["density"]) < 1.0, "M01 quartier insalubre sans hôpital : épidémie, habitants perdus")
	var h: SimWorld = fixture()
	zone(h, "centrale", Vector2i(40, 40))
	var ward: SimWorld.Building = zone(h, "zone_r", Vector2i(40, 46))
	zone(h, "hopital", Vector2i(36, 45))
	var other: SimWorld.Building = zone(h, "zone_r", Vector2i(46, 34))
	period(h)
	ward.city["health_v"] = 30.0
	other.city["health_v"] = 30.0
	period(h, 6)
	check(bool(ward.city.get("health", false)) and not bool(other.city.get("health", true)) and float(ward.city["health_v"]) > float(other.city["health_v"]) + 10.0, "M02 sans eau, l'hôpital soigne mieux le quartier qu'il dessert (%.0f contre %.0f)" % [float(ward.city["health_v"]), float(other.city["health_v"])])

# ---------------------------------------------------------------- sauvegarde et déterminisme

func _save_and_determinism() -> void:
	var w: SimWorld = fixture()
	zone(w, "centrale", Vector2i(30, 30))
	zone(w, "chateau_eau", Vector2i(34, 30))
	for k in 6:
		zone(w, ["zone_r", "zone_c", "zone_i"][k % 3], Vector2i(26 + (k % 3) * 3, 36 + (k / 3) * 3))
	period(w, 5)
	var snap: Dictionary = SaveGame.snapshot(w)
	var copy: SimWorld = SaveGame.from_snapshot(snap)
	check(copy != null and var_to_str(copy.teams[0].city) == var_to_str(w.teams[0].city), "D01 sauvegarde : bilan de la ville identique")
	var same: bool = true
	for b in w.buildings.values():
		var other: SimWorld.Building = copy.buildings.get(b.id) as SimWorld.Building
		if other == null or var_to_str(other.city) != var_to_str(b.city) or other.type != b.type:
			same = false
	check(same, "D02 sauvegarde : état de chaque bâtiment identique")
	run(w, 400)
	run(copy, 400)
	check(w.state_hash() == copy.state_hash() and var_to_str(w.teams[0].city) == var_to_str(copy.teams[0].city), "D03 reprise déterministe : même ville 40 s plus tard")

# ---------------------------------------------------------------- IA

func _ai() -> void:
	var w: SimWorld = fixture(true, false)
	w.teams[1].technologies[UrbanRules.TECH] = true
	for k in 6:
		w.spawn_unit(1, "ouvrier", Vector2(78.5 + float(k % 3), 77.5 + float(k / 3)))
	w.spawn_building(1, "maison", Vector2i(76, 84), true)
	var ai: AiController = AiController.new(1)
	w.ai_controllers.append(ai)
	# 0.20 — Adapté (comportement voulu changé) : les camps sont calculés à des ticks différents (calcul réparti) et
	# la partie évolue autrement ; un incendie peut ensuite détruire un bâtiment d'une IA à court de bois. A01 vérifie
	# donc ce que l'IA a bâti (le plus grand nombre atteint pendant la partie), pas ce qui a survécu aux incendies.
	var built: Dictionary = {}
	for i in 36:
		run(w, 100)
		var now: Dictionary = {}
		for b in w.team_buildings(1, "", true):
			now[b.type] = int(now.get(b.type, 0)) + 1
		for key in now.keys():
			built[key] = maxi(int(built.get(key, 0)), int(now[key]))
	var c: Dictionary = w.teams[1].city
	var counts: Dictionary = {}
	for b in w.team_buildings(1, "", true):
		counts[b.type] = int(counts.get(b.type, 0)) + 1
	check(int(built.get("zone_r", 0)) >= 2 and int(built.get("zone_c", 0)) >= 1 and int(built.get("zone_i", 0)) >= 1, "A01 l'IA bâtit sa ville : %s (au plus : %s)" % [str(counts), str(built)])
	check(int(counts.get("centrale", 0)) >= 1 or int((c.get("power", [0, 0]) as Array)[0]) > 8, "A02 l'IA construit une centrale")
	var prod: Dictionary = c.get("production", {}) as Dictionary
	check(float(prod.get("ore", 0.0)) > float(UrbanRules.CENTRE_TRICKLE["ore"]) or float(prod.get("food", 0.0)) > float(UrbanRules.CENTRE_TRICKLE["food"]), "A03 la ville de l'IA produit (%s)" % str(prod))
	check(int(c.get("habitants", 0)) > 0, "A04 la ville de l'IA a des habitants (%d)" % int(c.get("habitants", 0)))
	var refusals: int = 0
	for entry in w.replay:
		if int(entry["cmd"].get("team", -1)) == 1 and not bool(entry["ok"]) and String(entry["cmd"].get("t", "")) in ["build", "urban_upgrade"]:
			refusals += 1
	check(refusals == 0, "A05 l'IA n'émet aucun ordre de ville refusé (%d)" % refusals)
	var old: SimWorld = fixture(false, false)
	var usine: SimWorld.Building = old.spawn_building(1, "usine", Vector2i(70, 80), true)
	old.teams[1].res = {"food": 9000.0, "wood": 9000.0, "ore": 9000.0}
	old.ai_controllers.append(AiController.new(1))
	run(old, 400)
	check(not old.teams[1].technologies.has(UrbanRules.TECH) and usine != null, "A06 ancien mode : l'IA ne voit pas l'électricité")
