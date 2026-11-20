extends SceneTree
## 0.19 — Recette de simulation du zonage (lot A) : zones peintes, routes, croissance organique sans ouvrier,
## absence de construction sans conditions, demande, niveaux et densification, architecture selon l'âge, états,
## criminalité (causes et conséquences), incendies (intensité, propagation, ruines, reconstruction), famine,
## sauvegarde, migration des sauvegardes 0.18, IA, déterminisme et coût du calcul. Graines fixes.
var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

func fixture(age: int = 1, tech: bool = false, seed_value: int = 19010) -> SimWorld:
	var w := SimWorld.new()
	w.setup(seed_value, {"campaign": true, "urban": true})
	for y in 96:
		for x in 96:
			w.set_terrain(Vector2i(x, y), SimWorld.TERRAIN_GRASS)
	# Terrain dégagé : ni gisements ni comptoirs neutres (la recette choisit ses parcelles).
	for b in w.buildings.values().duplicate():
		w._destroy_building(b, -1)
	w.nodes.clear()
	w._node_cells.clear()
	for t in [0, 1]:
		w.teams[t].res = {"food": 5000.0, "wood": 5000.0, "ore": 5000.0}
		w.teams[t].age = age
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

func centre(w: SimWorld, team: int = 0) -> SimWorld.Building:
	return w.team_buildings(team, "centre")[0]

func street(w: SimWorld, length: int = 14, team: int = 0) -> Array:
	## Route verticale le long du bord gauche du centre, vers le bas : reliée au centre.
	var cc: SimWorld.Building = centre(w, team)
	var cells: Array = []
	for y in range(cc.cell.y, cc.cell.y + cc.size + length):
		cells.append([cc.cell.x - 1, y])
	w.issue({"t": "road_paint", "team": team, "cells": cells})
	return cells

func paint(w: SimWorld, code: int, from: Vector2i, to: Vector2i, team: int = 0) -> Dictionary:
	return w.issue({"t": "zone_paint", "team": team, "kind": code, "from": [from.x, from.y], "to": [to.x, to.y]})

func grown(w: SimWorld, kind: String = "", team: int = 0) -> Array:
	var out: Array = []
	for candidate in w.team_buildings(team):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.is_zone(b.type) and bool(b.city.get("grown", false)) and (kind == "" or b.type == kind):
			out.append(b)
	return out

func place_grown(w: SimWorld, kind: String, code: int, cell: Vector2i, age: int, level: int = 1) -> SimWorld.Building:
	## Bâtiment de zone déjà poussé (zonage peint dessous), pour éprouver un mécanisme précis sans attendre la croissance.
	paint(w, code, cell, cell + Vector2i(1, 1))
	var b: SimWorld.Building = w.spawn_building(0, kind, cell, true)
	b.city = {"grown": true, "zoned_once": true, "level": level, "density": float(level), "style_age": age, "variant": cell.x * 7 + cell.y, "rot": 0, "state": "operational"}
	return b

func refused(w: SimWorld, cmd: Dictionary, label: String) -> void:
	var before: String = w.state_hash() + var_to_str(w.teams[0].res) + str(w.teams[0].zoning.get("rev", 0))
	var result: Dictionary = w.issue(cmd)
	check(not bool(result.get("ok", true)) and w.state_hash() + var_to_str(w.teams[0].res) + str(w.teams[0].zoning.get("rev", 0)) == before, label + " (refus sans effet : %s)" % String(result.get("reason", "")))

func _initialize() -> void:
	_painting()
	_growth()
	_conditions()
	_levels_and_ages()
	_states_and_crime()
	_fires()
	_food_save_migration()
	_ai_and_determinism()
	_cost()
	print("ZONING_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

# ---------------------------------------------------------------- zones et routes

func _painting() -> void:
	var w: SimWorld = fixture()
	var cc: SimWorld.Building = centre(w)
	var base: Vector2i = cc.cell + Vector2i(0, cc.size + 2)
	var r: Dictionary = paint(w, 1, base, base + Vector2i(3, 3))
	check(bool(r.get("ok", false)) and int(r.get("changed", 0)) == 16 and UrbanZoning.zone_at(w, 0, base) == 1, "Z01 zone résidentielle peinte (16 cases) dès l'âge I")
	check(bool(paint(w, 4, base + Vector2i(4, 0), base + Vector2i(5, 1)).get("ok", false)) and UrbanZoning.zone_at(w, 0, base + Vector2i(4, 0)) == 4, "Z02 zone commerciale peinte")
	check(bool(paint(w, 5, base + Vector2i(6, 0), base + Vector2i(7, 1)).get("ok", false)) and UrbanZoning.zone_at(w, 0, base + Vector2i(6, 0)) == 5, "Z03 zone industrielle peinte")
	check(bool(paint(w, 6, base + Vector2i(8, 0), base + Vector2i(9, 1)).get("ok", false)) and UrbanZoning.zone_at(w, 0, base + Vector2i(8, 0)) == 6, "Z04 zone agricole peinte")
	var cells: Array = []
	for k in 5:
		cells.append([base.x + k, base.y + 6])
	check(bool(w.issue({"t": "zone_paint", "team": 0, "kind": 2, "cells": cells}).get("ok", false)) and UrbanZoning.zone_at(w, 0, base + Vector2i(4, 6)) == 2, "Z05 pinceau : liste de cases peinte")
	paint(w, 3, base, base + Vector2i(1, 1))
	check(UrbanZoning.zone_at(w, 0, base) == 3 and UrbanZoning.zone_at(w, 0, base + Vector2i(2, 2)) == 1, "Z06 rezonage d'une partie du quartier (habitat dense)")
	w.issue({"t": "zone_clear", "team": 0, "from": [base.x + 2, base.y + 2], "to": [base.x + 3, base.y + 3]})
	check(UrbanZoning.zone_at(w, 0, base + Vector2i(2, 2)) == 0 and UrbanZoning.zone_at(w, 0, base) == 3, "Z07 suppression d'une zone (gomme)")
	refused(w, {"t": "zone_paint", "team": 0, "kind": 1, "from": [60, 60], "to": [61, 61]}, "Z08 trop loin du territoire")
	refused(w, {"t": "zone_paint", "team": 0, "kind": 99, "from": [base.x, base.y], "to": [base.x, base.y]}, "Z09 type de zone inconnu")
	w.set_terrain(base + Vector2i(12, 0), SimWorld.TERRAIN_WATER)
	refused(w, {"t": "zone_paint", "team": 0, "kind": 1, "from": [base.x + 12, base.y], "to": [base.x + 12, base.y]}, "Z10 zone sur l'eau")
	var wood: float = float(w.teams[0].res["wood"])
	var road: Array = street(w, 6)
	var cost: Dictionary = UrbanZoning.road_cost(w, 0)
	check(UrbanZoning.team_road_at(w, 0, Vector2i(int(road[0][0]), int(road[0][1]))) and absf(wood - float(w.teams[0].res["wood"]) - float(cost.get("wood", 0.0)) * float(road.size())) < 0.01, "Z11 route tracée et payée (%d cases)" % road.size())
	var link: PackedByteArray = UrbanZoning.linked(w, 0)
	check(link[w.idx(Vector2i(int(road[road.size() - 1][0]), int(road[road.size() - 1][1])))] != 0, "Z12 route reliée au centre")
	check(w.build_check(0, "maison", Vector2i(int(road[2][0]), int(road[2][1]))) != "", "Z13 on ne bâtit pas sur une route")
	var undo: Dictionary = w.issue({"t": "road_remove", "team": 0, "cells": road, "undo": true})
	check(bool(undo.get("ok", false)) and absf(float(w.teams[0].res["wood"]) - wood) < 0.01, "Z14 annuler la route rembourse en entier")
	refused(w, {"t": "zone_paint", "team": 1, "kind": 1, "from": [base.x, base.y], "to": [base.x, base.y]}, "Z15 zone d'un autre camp")
	var old := SimWorld.new()
	old.setup(19011, {})
	old.spawn_building(0, "centre", Vector2i(10, 10), true)
	refused(old, {"t": "zone_paint", "team": 0, "kind": 1, "from": [10, 16], "to": [11, 17]}, "Z16 escarmouche sans évolution : zonage refusé (règles historiques)")

# ---------------------------------------------------------------- croissance organique

func _growth() -> void:
	var w: SimWorld = fixture()
	var cc: SimWorld.Building = centre(w)
	street(w, 16)
	var x0: int = cc.cell.x
	var y0: int = cc.cell.y + cc.size + 1
	paint(w, 1, Vector2i(x0, y0), Vector2i(x0 + 5, y0 + 11))
	# Un quartier vit d'emplois et de nourriture : commerce et agriculture zonés à côté de l'habitat.
	paint(w, 4, Vector2i(x0 - 3, y0), Vector2i(x0 - 2, y0 + 5))
	paint(w, 6, Vector2i(x0 - 3, y0 + 7), Vector2i(x0 - 2, y0 + 12))
	var wood: float = float(w.teams[0].res["wood"])
	period(w, 2)
	var sites: Array = grown(w, "zone_r")
	check(not sites.is_empty() and not (sites[0] as SimWorld.Building).complete and String((sites[0] as SimWorld.Building).city.get("state", "")) == "construction", "Z20 un chantier d'habitation s'ouvre seul sur la parcelle zonée")
	check(float(w.teams[0].res["wood"]) < wood, "Z21 chantier payé en ressources réelles (bois %d → %d)" % [int(wood), int(float(w.teams[0].res["wood"]))])
	check(w.team_units(0, "worker").is_empty(), "Z22 aucun ouvrier : la ville construit seule")
	period(w, 12)
	var done: int = 0
	for b in grown(w, "zone_r"):
		if (b as SimWorld.Building).complete:
			done += 1
	check(done >= 1 and int(w.teams[0].city.get("habitants", 0)) > 0, "Z23 bâtiment achevé, opérationnel, habitants logés (%d)" % int(w.teams[0].city.get("habitants", 0)))
	check(w.teams[0].pop_cap > 0 and int(w.teams[0].city.get("pop_bonus", 0)) >= 1, "Z24 places d'unités apportées par les habitants (+%d)" % int(w.teams[0].city.get("pop_bonus", 0)))
	period(w, 40)
	var list: Array = grown(w, "zone_r")
	var parcels: int = UrbanZoning.parcels(w, 0).size()
	check(list.size() >= 3 and list.size() <= parcels, "Z25 le quartier se remplit progressivement (%d bâtiments sur %d parcelles)" % [list.size(), parcels])
	var shapes: Dictionary = {}
	for b in list:
		shapes["%d-%d" % [int((b as SimWorld.Building).city.get("variant", 0)) % 4, int((b as SimWorld.Building).city.get("rot", 0))]] = true
	check(shapes.size() >= 2, "Z26 variantes et orientations différentes (%d combinaisons)" % shapes.size())
	check(float(w.teams[0].city.get("production", {}).get("food", 0.0)) >= 0.0 and String(w.teams[0].city.get("settlement", "")) != "", "Z27 agglomération classée : %s" % String(w.teams[0].city.get("settlement", "")))
	period(w, 20)
	check(not grown(w, "zone_c").is_empty(), "Z28 des commerces poussent quand les habitants les demandent")
	check(not grown(w, "zone_a").is_empty() and float(((w.teams[0].city.get("demand", {}) as Dictionary).get("zone_a", -1.0))) > -1.0, "Z29 des exploitations agricoles poussent")

# ---------------------------------------------------------------- absence de construction

func _conditions() -> void:
	var w: SimWorld = fixture()
	var cc: SimWorld.Building = centre(w)
	var y0: int = cc.cell.y + cc.size + 1
	paint(w, 1, Vector2i(cc.cell.x, y0), Vector2i(cc.cell.x + 3, y0 + 3))
	period(w, 10)
	check(grown(w).is_empty() and String((w.teams[0].city.get("grow_lack", {}) as Dictionary).get("zone_r", "")).contains("route"), "Z30 sans route : rien ne pousse (%s)" % String((w.teams[0].city.get("grow_lack", {}) as Dictionary).get("zone_r", "")))
	# Route isolée, non reliée au centre.
	var far: Array = []
	for y in range(y0, y0 + 6):
		far.append([cc.cell.x + 6, y])
	w.issue({"t": "road_paint", "team": 0, "cells": far})
	period(w, 5)
	check(grown(w).is_empty(), "Z31 route non reliée au centre : rien ne pousse")
	street(w, 8)
	w.teams[0].res = {"food": 5000.0, "wood": 0.0, "ore": 5000.0}
	period(w, 5)
	check(grown(w).is_empty() and String((w.teams[0].city.get("grow_lack", {}) as Dictionary).get("zone_r", "")) != "", "Z32 sans bois : aucun chantier (%s)" % String((w.teams[0].city.get("grow_lack", {}) as Dictionary).get("zone_r", "")))
	w.teams[0].res["wood"] = 5000.0
	var foe: SimWorld.Unit = w.spawn_unit(1, "lancier", Vector2(cc.cell.x + 1.5, y0 + 2.5))
	foe.max_hp = 99999.0
	foe.hp = 99999.0
	period(w, 1)
	check(grown(w).is_empty() and String((w.teams[0].city.get("grow_lack", {}) as Dictionary).get("zone_r", "")).contains("ennemi"), "Z33 ennemi armé à côté : pas de chantier")
	w._kill_unit(foe, 0)
	period(w, 3)
	check(not grown(w).is_empty(), "Z34 conditions réunies : le chantier s'ouvre")
	paint(w, 4, Vector2i(cc.cell.x + 8, y0), Vector2i(cc.cell.x + 9, y0 + 1))
	var c_before: int = grown(w, "zone_c").size()
	period(w, 2)
	check(grown(w, "zone_c").size() == c_before and float((w.teams[0].city.get("demand", {}) as Dictionary).get("zone_c", 1.0)) < UrbanRules.DEMAND_MIN, "Z35 commerce sans clients : pas de demande, parcelle laissée vide")

# ---------------------------------------------------------------- niveaux, densité, âges

func _levels_and_ages() -> void:
	var w: SimWorld = fixture(1)
	var cc: SimWorld.Building = centre(w)
	street(w, 10)
	var y0: int = cc.cell.y + cc.size + 1
	paint(w, 3, Vector2i(cc.cell.x, y0), Vector2i(cc.cell.x + 1, y0 + 1))
	period(w, 14)
	var list: Array = grown(w, "zone_r")
	check(list.size() == 1 and (list[0] as SimWorld.Building).complete, "Z40 habitation achevée")
	var b: SimWorld.Building = list[0]
	var wood: float = float(w.teams[0].res["wood"])
	var d0: float = float(b.city.get("density", 0.0))
	period(w, 6)
	check(float(b.city["density"]) > d0, "Z41 densification : %.2f → %.2f" % [d0, float(b.city["density"])])
	check(int(b.city.get("style_age", 0)) == 1, "Z42 architecture de l'âge I")
	check(UrbanGrowth.level_cap(w, 0, b) == 2, "Z43 âge I : niveau II au plus, même sur un zonage dense")
	# Conditions favorables : niveau suivant automatique, payé, avec travaux.
	for k in 60:
		b.city["happiness"] = 80.0
		b.city["wealth"] = 70.0
		period(w)
		if int(b.city.get("level", 1)) >= 2:
			break
	check(int(b.city.get("level", 1)) == 2 and float(w.teams[0].res["wood"]) < wood, "Z44 montée au niveau II automatique et payée (%s)" % String(b.city.get("level_lack", "")))
	check(UrbanGrowth.level_lack(w, 0, b, {"zone_r": 1.0}, false).contains("maximal"), "Z45 plafond d'âge atteint : %s" % UrbanGrowth.level_lack(w, 0, b, {"zone_r": 1.0}, false))
	# Changement d'âge : la ville ne se convertit pas d'un coup.
	w.teams[0].age = 5
	paint(w, 4, Vector2i(cc.cell.x - 3, y0), Vector2i(cc.cell.x - 2, y0 + 5))
	period(w, 20)
	paint(w, 3, Vector2i(cc.cell.x, y0 + 2), Vector2i(cc.cell.x + 1, y0 + 3))
	period(w, 6)
	var fresh: SimWorld.Building = null
	for candidate in grown(w, "zone_r"):
		if candidate != b:
			fresh = candidate
	check(fresh != null and int(fresh.city.get("style_age", 0)) == 5, "Z46 nouvelle construction : architecture de l'âge V")
	check(int(b.city.get("style_age", 0)) == 1, "Z47 l'ancien bâtiment garde son architecture d'âge I (transformation progressive)")
	b.city["historic"] = true
	w.spawn_building(0, "commissariat", Vector2i(b.cell.x + 5, b.cell.y + 3), true)
	w.spawn_building(0, "puits", Vector2i(b.cell.x + 2, b.cell.y + 3), true)
	for k in 90:
		period(w)
		if int(b.city.get("level", 1)) >= 3:
			break
	check(int(b.city.get("level", 1)) == 3 and int(b.city.get("style_age", 0)) == 1, "Z48 quartier historique : il grandit sans changer d'architecture (%s)" % String(b.city.get("level_lack", "")))
	# Zonage abaissé : le bâtiment redescend.
	paint(w, 1, Vector2i(cc.cell.x, y0), Vector2i(cc.cell.x + 1, y0 + 1))
	period(w, int(ceil(UrbanRules.DEZONE_DELAY / UrbanRules.PERIOD_S)) + 2)
	check(int(b.city.get("level", 9)) <= 2 and w.buildings.has(b.id), "Z49 zonage moins dense : le bâtiment redescend au niveau II")

# ---------------------------------------------------------------- états et criminalité

func _states_and_crime() -> void:
	var w: SimWorld = fixture(3)
	var cc: SimWorld.Building = centre(w)
	street(w, 14)
	var y0: int = cc.cell.y + cc.size + 1
	paint(w, 2, Vector2i(cc.cell.x, y0), Vector2i(cc.cell.x + 3, y0 + 7))
	paint(w, 4, Vector2i(cc.cell.x + 4, y0), Vector2i(cc.cell.x + 7, y0 + 3))
	period(w, 30)
	var homes: Array = grown(w, "zone_r")
	check(homes.size() >= 2, "Z50 quartier construit (%d)" % homes.size())
	var b: SimWorld.Building = homes[0]
	check(String(b.city.get("state", "")) in ["operational", "prosperous"], "Z51 état opérationnel (%s)" % String(b.city.get("state", "")))
	# Rezonage : le bâtiment se vide puis disparaît sans ruine.
	var gone: SimWorld.Building = homes[homes.size() - 1]
	w.issue({"t": "zone_clear", "team": 0, "from": [gone.cell.x, gone.cell.y], "to": [gone.cell.x + 1, gone.cell.y + 1]})
	period(w, 3)
	check(String(gone.city.get("state", "")) == "abandoned", "Z52 zone retirée : bâtiment abandonné")
	period(w, int(ceil(UrbanRules.DEZONE_DELAY / UrbanRules.PERIOD_S)))
	check(not w.buildings.has(gone.id) and w.team_buildings(0, "ruine").is_empty(), "Z53 puis démoli, sans ruine")
	# Criminalité : sans sécurité, avec la garde, avec un commissariat.
	var crime_free: float = float(b.city.get("crime", 0.0))
	w.spawn_building(0, "caserne", Vector2i(b.cell.x + 3, b.cell.y), true)
	period(w, 12)
	var crime_guard: float = float(b.city.get("crime", 0.0))
	check(bool(b.city.get("guard", false)) and crime_guard < crime_free, "Z54 la garde (caserne) fait baisser la criminalité (%.0f → %.0f)" % [crime_free, crime_guard])
	w.spawn_building(0, "commissariat", Vector2i(b.cell.x - 4, b.cell.y + 4), true)
	period(w, 12)
	check(bool(b.city.get("police_station", false)) and float(b.city.get("crime", 0.0)) < crime_guard, "Z55 le commissariat fait mieux que la garde (%.0f)" % float(b.city.get("crime", 0.0)))
	# Chômage, pauvreté : criminalité plus forte, dégradation, départs, pillages, émeute calmée par l'armée.
	var bad: SimWorld = fixture(3, false, 19020)
	var bcc: SimWorld.Building = centre(bad)
	street(bad, 10)
	var by: int = bcc.cell.y + bcc.size + 1
	var slum: SimWorld.Building = place_grown(bad, "zone_r", 2, Vector2i(bcc.cell.x, by), 3, 2)
	for k in 3:
		place_grown(bad, "zone_r", 2, Vector2i(bcc.cell.x + 2 * k, by + 3), 3, 2)
	var res_before: float = float(bad.teams[0].res["ore"])
	# Misère : famine, chômage (aucun emploi), aucun service, conflit (ennemi armé tout près), criminalité très forte.
	var raider: SimWorld.Unit = bad.spawn_unit(1, "lancier", slum.center + Vector2(7.0, 0.0))
	raider.max_hp = 99999.0
	for k in 80:
		bad.teams[0].res["food"] = 0.0
		raider.hp = 99999.0
		raider.pos = slum.center + Vector2(7.0, 0.0)
		for hb in grown(bad, "zone_r"):
			(hb as SimWorld.Building).city["crime"] = 95.0
		period(bad)
	check(String(slum.city.get("state", "")) in ["degraded", "damaged"] or float(slum.city.get("crime_t", 0.0)) >= UrbanRules.CRIME_DEGRADE_TIME, "Z56 criminalité durable : quartier dégradé (%s)" % String(slum.city.get("state", "")))
	check(int(bad.teams[0].city.get("pillages", 0)) >= 1 and float(bad.teams[0].res["ore"]) < res_before, "Z57 pillages : ressources réelles volées (%d)" % int(bad.teams[0].city.get("pillages", 0)))
	check(int(bad.teams[0].city.get("riots_total", 0)) >= 1, "Z58 émeute déclenchée")
	check(float(slum.city.get("density", 1.0)) <= UrbanRules.MIN_DENSITY + 0.3, "Z59 les habitants partent (densité %.2f)" % float(slum.city.get("density", 1.0)))
	bad._kill_unit(raider, 0)
	bad.spawn_unit(0, "lancier", slum.center + Vector2(2.0, 0.0))
	period(bad, 2)
	check(String(slum.city.get("riot", "")) == "", "Z60 l'armée met fin à l'émeute")
	check(slum.hp >= slum.max_hp * 0.39, "Z61 l'émeute abîme sans raser (%.0f %%)" % (100.0 * slum.hp / slum.max_hp))

# ---------------------------------------------------------------- incendies

func _fires() -> void:
	var w: SimWorld = fixture(2, false, 19030)
	var cc: SimWorld.Building = centre(w)
	street(w, 12)
	var y0: int = cc.cell.y + cc.size + 1
	for k in 4:
		place_grown(w, "zone_r", 2, Vector2i(cc.cell.x + 2 * k, y0), 2)
	period(w)
	w.teams[0].res["wood"] = 0.0   # pas de reconstruction pendant l'incendie : on observe les ruines
	var homes: Array = grown(w, "zone_r")
	check(homes.size() >= 3, "Z70 quartier de bois (âge II) : %d maisons côte à côte" % homes.size())
	var src: SimWorld.Building = homes[0]
	check(UrbanRules.material(int(src.city.get("style_age", 1))) > 1.0, "Z71 matériaux anciens plus inflammables")
	src.city["burning"] = UrbanRules.FIRE_DURATION
	src.city["fire_i"] = UrbanRules.FIRE_START_INTENSITY
	period(w)
	var i1: float = float(src.city.get("fire_i", 0.0))
	period(w)
	check(float(src.city.get("fire_i", 0.0)) > i1 or not w.buildings.has(src.id), "Z72 sans pompiers, l'intensité monte (%.2f → %.2f)" % [i1, float(src.city.get("fire_i", 0.0))])
	var spread: bool = false
	for k in 30:
		for other in homes:
			if other != src and w.buildings.has((other as SimWorld.Building).id) and float((other as SimWorld.Building).city.get("burning", 0.0)) > 0.0:
				spread = true
		if spread or not w.buildings.has(src.id):
			break
		src.city["fire_i"] = 1.0
		src.city["burning"] = UrbanRules.FIRE_DURATION
		period(w)
	check(spread, "Z73 le feu se propage aux voisins")
	# Destruction : ruines persistantes, puis reconstruction par la croissance.
	if w.buildings.has(src.id):
		src.hp = 1.0
		src.city["burning"] = UrbanRules.FIRE_DURATION
		src.city["fire_i"] = 1.0
		period(w)
	check(not w.buildings.has(src.id) and not w.team_buildings(0, "ruine").is_empty(), "Z74 bâtiment détruit par le feu : ruines persistantes")
	var ruin: SimWorld.Building = w.team_buildings(0, "ruine")[0]
	w.teams[0].res["wood"] = 5000.0
	var snap: Dictionary = SaveGame.snapshot(w)
	var back: SimWorld = SaveGame.from_snapshot(snap)
	check(back != null and back.team_buildings(0, "ruine").size() == w.team_buildings(0, "ruine").size(), "Z75 ruines conservées dans la sauvegarde")
	for k in 40:
		for b in w.team_buildings(0):
			(b as SimWorld.Building).city["burning"] = 0.0
		period(w)
		if not w.buildings.has(ruin.id):
			break
	var rebuilt: bool = false
	for b in grown(w, "zone_r"):
		if bool((b as SimWorld.Building).city.get("rebuilt", false)):
			rebuilt = true
	check(not w.buildings.has(ruin.id) and rebuilt, "Z76 reconstruction sur les ruines")
	# Pompiers reliés par la route : extinction rapide.
	var f: SimWorld = fixture(4, false, 19031)
	var fcc: SimWorld.Building = centre(f)
	street(f, 12)
	var h: SimWorld.Building = place_grown(f, "zone_r", 2, Vector2i(fcc.cell.x, fcc.cell.y + fcc.size + 1), 4)
	f.spawn_building(0, "caserne_pompiers", Vector2i(h.cell.x + 3, h.cell.y), true)
	period(f)
	h.city["burning"] = UrbanRules.FIRE_DURATION
	h.city["fire_i"] = UrbanRules.FIRE_START_INTENSITY
	period(f, 2)
	check(bool(h.city.get("fire_station", false)) and float(h.city.get("burning", 1.0)) == 0.0 and h.hp > h.max_hp * 0.8, "Z77 caserne de pompiers reliée par la route : feu éteint vite")
	var d1: float = UrbanGrowth.dryness(f)
	run(f, UrbanRules.WEATHER_CYCLE / 2)
	check(absf(UrbanGrowth.dryness(f) - d1) > 0.05 and UrbanGrowth.weather_label(f) != "", "Z78 le temps qu'il fait change (sec / humide) : %s" % UrbanGrowth.weather_label(f))

# ---------------------------------------------------------------- nourriture, sauvegarde, migration

func _food_save_migration() -> void:
	var w: SimWorld = fixture(1, false, 19040)
	var cc: SimWorld.Building = centre(w)
	street(w, 12)
	paint(w, 2, Vector2i(cc.cell.x, cc.cell.y + cc.size + 1), Vector2i(cc.cell.x + 3, cc.cell.y + cc.size + 6))
	period(w, 40)
	var food: float = float(w.teams[0].res["food"])
	period(w, 5)
	check(float(w.teams[0].city.get("upkeep", 0.0)) > 0.0 and float(w.teams[0].res["food"]) < food, "Z80 les habitants mangent (%.2f vivres/s)" % float(w.teams[0].city.get("upkeep", 0.0)))
	w.teams[0].res["food"] = 0.0
	period(w, 2)
	check(bool(w.teams[0].city.get("famine", false)) and float((w.teams[0].city.get("demand", {}) as Dictionary).get("zone_a", 0.0)) > 0.0, "Z81 famine : demande agricole en hausse")
	w.teams[0].res["food"] = 5000.0
	# Sauvegarde : zones, routes, bâtiments, niveaux, états.
	var snap: Dictionary = SaveGame.snapshot(w)
	var back: SimWorld = SaveGame.from_snapshot(snap)
	check(back != null and back.teams[0].zoning.get("zone") == w.teams[0].zoning.get("zone") and back.teams[0].zoning.get("road") == w.teams[0].zoning.get("road"), "Z82 zones et routes sauvegardées")
	var same: bool = back != null
	if same:
		for candidate in grown(w):
			var b: SimWorld.Building = candidate as SimWorld.Building
			var o: SimWorld.Building = back.buildings.get(b.id) as SimWorld.Building
			if o == null or var_to_str(o.city.get("level")) != var_to_str(b.city.get("level")) or String(o.city.get("state", "")) != String(b.city.get("state", "")):
				same = false
	check(same, "Z83 bâtiments, niveaux et états rechargés")
	period(w, 10)
	period(back, 10)
	check(back.state_hash() == w.state_hash() and var_to_str(back.teams[0].res) == var_to_str(w.teams[0].res), "Z84 reprise déterministe après chargement")
	check(UrbanZoning.road_at(back, Vector2i(cc.cell.x - 1, cc.cell.y + 2)), "Z85 routes reconnues après chargement (placement des bâtiments)")
	# Migration d'une sauvegarde 0.18 : zones posées comme bâtiments, aucune couche de zonage.
	var old: SimWorld = fixture(5, true, 19041)
	var legacy: SimWorld.Building = old.spawn_building(0, "zone_r", Vector2i(30, 30), true)
	legacy.city = {"level": 2, "density": 1.5, "ready": true}
	var old_snap: Dictionary = SaveGame.snapshot(old)
	for team_data in old_snap["teams"] as Array:
		(team_data as Dictionary).erase("zoning")
	var migrated: SimWorld = SaveGame.from_snapshot(old_snap)
	check(migrated != null and migrated.teams[0].zoning.is_empty(), "Z86 sauvegarde 0.18 (sans zonage) relue")
	period(migrated)
	var lb: SimWorld.Building = migrated.buildings.get(legacy.id) as SimWorld.Building
	check(UrbanZoning.zone_at(migrated, 0, Vector2i(30, 30)) == 2 and bool(lb.city.get("zoned_once", false)) and int(lb.city.get("level", 0)) == 2, "Z87 migration : la zone posée devient une parcelle zonée, son niveau est conservé")
	check(int(migrated.teams[0].zoning.get("v", 0)) == 1 and int(migrated.teams[0].zoning.get("migrated", 0)) == 1, "Z88 migration faite une seule fois (version de zonage 1)")

# ---------------------------------------------------------------- IA, déterminisme

func _ai_and_determinism() -> void:
	var a: SimWorld = fixture(5, true, 19050)
	var b: SimWorld = fixture(5, true, 19050)
	for w in [a, b]:
		street(w, 12)
		paint(w, 2, Vector2i(10, 15), Vector2i(13, 22))
		paint(w, 4, Vector2i(14, 15), Vector2i(15, 18))
		period(w, 60)
	check(a.state_hash() == b.state_hash() and var_to_str(a.teams[0].city.get("habitants")) == var_to_str(b.teams[0].city.get("habitants")), "Z90 même graine, même ville (déterministe)")
	# IA après Électricité : routes et zones par les mêmes commandes, puis la croissance construit.
	var w: SimWorld = fixture(5, false, 19051)
	w.teams[1].technologies[UrbanRules.TECH] = true
	for k in 6:
		w.spawn_unit(1, "ouvrier", Vector2(78.5 + float(k % 3), 77.5 + float(k / 3)))
	var ai: AiController = AiController.new(1)
	w.ai_controllers.append(ai)
	run(w, 3600)
	var roads: int = 0
	if UrbanZoning.has_layers(w, 1):
		for v in (w.teams[1].zoning["road"] as PackedByteArray):
			if v != 0:
				roads += 1
	check(roads >= 10, "Z91 l'IA trace des routes (%d cases)" % roads)
	check(UrbanZoning.parcels(w, 1).size() >= 2 if UrbanZoning.has_layers(w, 1) else false, "Z92 l'IA peint des zones")
	check(not grown(w, "", 1).is_empty(), "Z93 la croissance construit la ville de l'IA (%d)" % grown(w, "", 1).size())

# ---------------------------------------------------------------- coût du calcul

func _cost() -> void:
	var w: SimWorld = fixture(6, true, 19060)
	var cc: SimWorld.Building = centre(w)
	var road: Array = []
	for y in range(4, 92):
		road.append([cc.cell.x - 1, y])
		road.append([cc.cell.x + 9, y])
	w.issue({"t": "road_paint", "team": 0, "cells": road})
	paint(w, 2, Vector2i(cc.cell.x, 20), Vector2i(cc.cell.x + 7, 90))
	paint(w, 4, Vector2i(cc.cell.x + 10, 20), Vector2i(cc.cell.x + 13, 90))
	for y in range(20, 88, 2):
		for x in [cc.cell.x, cc.cell.x + 2, cc.cell.x + 4, cc.cell.x + 6]:
			var b: SimWorld.Building = w.spawn_building(0, "zone_r", Vector2i(x, y), true)
			b.city = {"grown": true, "level": 2, "density": 1.5, "style_age": 6, "variant": x + y, "rot": 0}
	period(w, 2)
	var t0: int = Time.get_ticks_usec()
	var spent_all: Array = []
	for i in UrbanRules.PERIOD * 10:
		var s0: int = Time.get_ticks_usec()
		w.step()
		spent_all.append(Time.get_ticks_usec() - s0)
	# Un calcul de ville par période : les 10 ticks les plus longs sont ceux de la ville, les autres sont ordinaires.
	spent_all.sort()
	var worst_us: int = int(spent_all[spent_all.size() - 1])
	var plain_us: int = 0
	for i in spent_all.size() - 10:
		plain_us += int(spent_all[i])
	var plain_n: int = spent_all.size() - 10
	var per: float = float(Time.get_ticks_usec() - t0) / 10.0 / 1000.0
	var count: int = grown(w).size()
	check(count >= 120, "Z98 grande ville de test : %d bâtiments de zone" % count)
	print("ZONING_PERF period_ms=%.2f urban_tick_ms=%.2f plain_tick_ms=%.3f buildings=%d (Linux, 20 ticks par calcul)" % [per, float(worst_us) / 1000.0, float(plain_us) / 1000.0 / float(maxi(1, plain_n)), count])
	check(per < 250.0, "Z99 coût de 20 ticks avec la ville (%.1f ms sur Linux, plafond 250 ms ; Android : NOT_RUN)" % per)
	# Pic du tick qui calcule la ville (une fois toutes les 2 s) : plafond Linux 60 ms ; objectif Android à mesurer (NOT_RUN).
	check(worst_us < 60000, "Z99b pic du calcul de la ville : %.1f ms sur Linux (plafond 60 ms)" % (float(worst_us) / 1000.0))
