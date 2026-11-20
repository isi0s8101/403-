extends SceneTree
## 0.20 — Recette du lot B : événements urbains extensibles (séisme, inondation, tempête, crise, migration, exode),
## tirage déterministe et délai de grâce, sauvegarde ; calcul réparti (camps et mondes décalés) ; villes lointaines
## calculées en abrégé (cohérence économique, croissance, aller-retour d'échelle) ; résumés multi-échelles ;
## IA qui zone dès l'âge I sur ses surplus ; seuils de coût mesurés. Graines fixes.
var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

func fixture(age: int = 3, tech: bool = false, seed_value: int = 20010) -> SimWorld:
	var w := SimWorld.new()
	w.setup(seed_value, {"campaign": true, "urban": true})
	for y in 96:
		for x in 96:
			w.set_terrain(Vector2i(x, y), SimWorld.TERRAIN_GRASS)
	for b in w.buildings.values().duplicate():
		w._destroy_building(b, -1)
	w.nodes.clear()
	w._node_cells.clear()
	for t in [0, 1]:
		w.teams[t].res = {"food": 8000.0, "wood": 8000.0, "ore": 8000.0}
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

func street(w: SimWorld, team: int = 0, length: int = 16) -> void:
	var cc: SimWorld.Building = w.team_buildings(team, "centre")[0]
	var cells: Array = []
	for y in range(cc.cell.y, cc.cell.y + cc.size + length):
		cells.append([cc.cell.x - 1, y])
	w.issue({"t": "road_paint", "team": team, "cells": cells})

func place(w: SimWorld, kind: String, code: int, cell: Vector2i, style_age: int = 3, level: int = 1, team: int = 0) -> SimWorld.Building:
	w.issue({"t": "zone_paint", "team": team, "kind": code, "from": [cell.x, cell.y], "to": [cell.x + 1, cell.y + 1]})
	var b: SimWorld.Building = w.spawn_building(team, kind, cell, true)
	b.city = {"grown": true, "zoned_once": true, "level": level, "density": float(level), "style_age": style_age, "variant": cell.x * 7 + cell.y, "rot": 0, "state": "operational"}
	return b

func town(w: SimWorld, style_age: int = 3) -> Array:
	## Petite ville le long d'une route reliée : 6 habitations, 2 commerces, 2 exploitations agricoles.
	street(w)
	var out: Array = []
	var cc: SimWorld.Building = w.team_buildings(0, "centre")[0]
	var x: int = cc.cell.x
	var y: int = cc.cell.y + cc.size
	for k in 6:
		out.append(place(w, "zone_r", 2, Vector2i(x, y + k * 2), style_age, 2))
	out.append(place(w, "zone_c", 4, Vector2i(x - 3, y), style_age, 1))
	out.append(place(w, "zone_c", 4, Vector2i(x - 3, y + 2), style_age, 1))
	out.append(place(w, "zone_a", 6, Vector2i(x - 3, y + 4), style_age, 1))
	out.append(place(w, "zone_a", 6, Vector2i(x - 3, y + 6), style_age, 1))
	return out

func _initialize() -> void:
	_events()
	_schedule()
	_far()
	_ai()
	_cost()
	print("URBAN_LOTB_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

# ---------------------------------------------------------------- événements

func _events() -> void:
	var keys_ok: bool = true
	for key in UrbanEvents.EVENTS.keys():
		var def: Dictionary = UrbanEvents.EVENTS[key] as Dictionary
		if not def.has("label") or not def.has("chance") or not String(def.get("area", "none")) in ["epicentre", "water", "all", "homes", "none"]:
			keys_ok = false
	check(UrbanEvents.EVENTS.size() >= 5 and keys_ok, "E01 %d événements décrits par des données (vocabulaire commun, extensible)" % UrbanEvents.EVENTS.size())
	# Séisme : dégâts autour de l'épicentre, atténués avec la distance.
	var w: SimWorld = fixture(3, false, 20011)
	var city: Array = town(w)
	period(w, 2)
	var near: SimWorld.Building = city[0] as SimWorld.Building
	var far: SimWorld.Building = city[5] as SimWorld.Building
	var r: Dictionary = w.issue({"t": "lab_urban_event", "team": 0, "event": "seisme", "at": [near.cell.x, near.cell.y]})
	var report: Dictionary = r.get("report", {}) as Dictionary
	check(bool(r.get("ok", false)) and int(report.get("hit", 0)) >= 3 and near.hp < near.max_hp, "E02 séisme : %d bâtiments touchés, vie de l'épicentre %.0f %%" % [int(report.get("hit", 0)), 100.0 * near.hp / near.max_hp])
	check(far.hp / far.max_hp > near.hp / near.max_hp and near.hp >= near.max_hp * 0.1 - 0.01, "E03 dégâts atténués avec la distance, jamais rasé d'un coup (%.0f %% / %.0f %%)" % [100.0 * near.hp / near.max_hp, 100.0 * far.hp / far.max_hp])
	var burning: int = 0
	for b in city:
		if float((b as SimWorld.Building).city.get("burning", 0.0)) > 0.0:
			burning += 1
	check(burning == int(report.get("fires", 0)), "E04 incendies du séisme : %d (même nombre que le bilan)" % burning)
	check(String(w.issue({"t": "lab_urban_event", "team": 0, "event": "meteorite"}).get("reason", "")) != "", "E05 événement inconnu : refusé")
	# Tempête : éteint les feux, abîme plus les maisons de bois.
	var w2: SimWorld = fixture(3, false, 20012)
	var c2: Array = town(w2, 1)
	var modern: SimWorld.Building = place(w2, "zone_r", 2, Vector2i(20, 30), 8, 2)
	var wooden: SimWorld.Building = c2[1] as SimWorld.Building
	(c2[2] as SimWorld.Building).city["burning"] = 30.0
	w2.issue({"t": "lab_urban_event", "team": 0, "event": "tempete"})
	check(float((c2[2] as SimWorld.Building).city.get("burning", 0.0)) <= 0.0, "E06 tempête : l'incendie en cours est éteint")
	check(wooden.hp / wooden.max_hp < modern.hp / modern.max_hp, "E07 tempête : la maison de bois (âge I) souffre plus que l'immeuble de l'âge VIII (%.0f %% / %.0f %%)" % [100.0 * wooden.hp / wooden.max_hp, 100.0 * modern.hp / modern.max_hp])
	# Inondation : seulement au bord de l'eau ; production arrêtée puis reprise.
	var w3: SimWorld = fixture(3, false, 20013)
	var c3: Array = town(w3)
	period(w3, 2)
	var dry: Dictionary = w3.issue({"t": "lab_urban_event", "team": 0, "event": "inondation"}).get("report", {}) as Dictionary
	check(int(dry.get("hit", -1)) == 0, "E08 inondation : aucune zone touchée loin de l'eau")
	var farm: SimWorld.Building = c3[8] as SimWorld.Building
	for dy in range(0, 2):
		w3.set_terrain(farm.cell + Vector2i(-1, dy), SimWorld.TERRAIN_WATER)
		w3.set_terrain(farm.cell + Vector2i(-2, dy), SimWorld.TERRAIN_WATER)
	var wet: Dictionary = w3.issue({"t": "lab_urban_event", "team": 0, "event": "inondation", "at": [farm.cell.x, farm.cell.y]}).get("report", {}) as Dictionary
	period(w3, 1)
	var out_sum: float = 0.0
	for v in (farm.city.get("out", {}) as Dictionary).values():
		out_sum += float(v)
	check(int(wet.get("hit", 0)) >= 1 and float(farm.city.get("flooded", 0.0)) > 0.0 and out_sum == 0.0, "E09 inondation au bord de l'eau : %d bâtiment(s), production arrêtée" % int(wet.get("hit", 0)))
	period(w3, 22)
	out_sum = 0.0
	for v in (farm.city.get("out", {}) as Dictionary).values():
		out_sum += float(v)
	check(not farm.city.has("flooded") and out_sum > 0.0, "E10 décrue : la production reprend (%.2f/s)" % out_sum)
	# Crise : deux mondes identiques, l'un en crise.
	var a: SimWorld = fixture(4, false, 20014)
	var b2: SimWorld = fixture(4, false, 20014)
	town(a)
	town(b2)
	period(a, 3)
	period(b2, 3)
	b2.issue({"t": "lab_urban_event", "team": 0, "event": "crise"})
	period(a, 1)
	period(b2, 1)
	var da: float = float((a.teams[0].city.get("demand", {}) as Dictionary).get("zone_c", 0.0))
	var db: float = float((b2.teams[0].city.get("demand", {}) as Dictionary).get("zone_c", 0.0))
	var shop_a: float = 0.0
	var shop_b: float = 0.0
	for k in a.team_buildings(0, "zone_c"):
		for v in ((k as SimWorld.Building).city.get("out", {}) as Dictionary).values():
			shop_a += float(v)
	for k in b2.team_buildings(0, "zone_c"):
		for v in ((k as SimWorld.Building).city.get("out", {}) as Dictionary).values():
			shop_b += float(v)
	check(db < da - 0.2 and shop_b < shop_a, "E11 crise : demande du commerce %+.2f → %+.2f, production %.2f → %.2f/s" % [da, db, shop_a, shop_b])
	period(b2, 61)
	check(UrbanEvents.active(b2.teams[0]).is_empty(), "E12 la crise prend fin après sa durée (2 minutes)")
	# Migration et exode : densité de l'habitat.
	var w4: SimWorld = fixture(3, false, 20015)
	var c4: Array = town(w4)
	for b in c4:
		(b as SimWorld.Building).city["density"] = 1.0
	var moved: Dictionary = w4.issue({"t": "lab_urban_event", "team": 0, "event": "migration"}).get("report", {}) as Dictionary
	check(float(moved.get("density", 0.0)) > 0.5, "E13 vague de migration : densité de l'habitat %+.1f" % float(moved.get("density", 0.0)))
	var left: Dictionary = w4.issue({"t": "lab_urban_event", "team": 0, "event": "exode"}).get("report", {}) as Dictionary
	check(float(left.get("density", 0.0)) < -0.5, "E14 exode : densité de l'habitat %+.1f" % float(left.get("density", 0.0)))
	# Tirage : jamais pendant le délai de grâce ; ensuite déterministe.
	var n1: SimWorld = fixture(4, false, 20016)
	var n2: SimWorld = fixture(4, false, 20016)
	town(n1)
	town(n2)
	run(n1, UrbanEvents.GRACE_TICKS - 20)
	check(int(n1.teams[0].city.get("events_total", 0)) == 0, "E15 aucun événement tiré pendant les 15 premières minutes")
	run(n1, UrbanRules.PERIOD * UrbanEvents.CHECK_EVERY * 40)
	run(n2, UrbanEvents.GRACE_TICKS - 20 + UrbanRules.PERIOD * UrbanEvents.CHECK_EVERY * 40)
	check(int(n1.teams[0].city.get("events_total", 0)) >= 1, "E16 tirage naturel : %d événement(s) en 20 minutes de plus" % int(n1.teams[0].city.get("events_total", 0)))
	check(n1.state_hash() == n2.state_hash() and var_to_str(n1.teams[0].city.get("last_event", {})) == var_to_str(n2.teams[0].city.get("last_event", {})), "E17 même graine, mêmes événements (déterministe)")
	# Sauvegarde : événement en cours et quartier inondé.
	var s: SimWorld = fixture(4, false, 20017)
	var cs: Array = town(s)
	period(s, 2)
	s.issue({"t": "lab_urban_event", "team": 0, "event": "crise"})
	(cs[0] as SimWorld.Building).city["flooded"] = 30.0
	var copy: SimWorld = SaveGame.from_snapshot(SaveGame.snapshot(s))
	check(copy != null and var_to_str(copy.teams[0].city.get("events", [])) == var_to_str(s.teams[0].city.get("events", [])) and float((copy.buildings[(cs[0] as SimWorld.Building).id] as SimWorld.Building).city.get("flooded", 0.0)) == 30.0, "E18 sauvegarde : événement en cours et inondation conservés")
	run(s, 400)
	run(copy, 400)
	check(s.state_hash() == copy.state_hash(), "E19 reprise déterministe après chargement")
	# Même règle pour l'IA.
	var ai_w: SimWorld = fixture(3, false, 20018)
	var cc1: SimWorld.Building = ai_w.team_buildings(1, "centre")[0]
	street(ai_w, 1)
	var ai_b: SimWorld.Building = place(ai_w, "zone_r", 2, Vector2i(cc1.cell.x, cc1.cell.y + cc1.size), 3, 2, 1)
	var ai_r: Dictionary = ai_w.issue({"t": "lab_urban_event", "team": 1, "event": "seisme", "at": [ai_b.cell.x, ai_b.cell.y]}).get("report", {}) as Dictionary
	check(int(ai_r.get("hit", 0)) >= 1 and ai_b.hp < ai_b.max_hp, "E20 les événements touchent l'IA comme le joueur")

# ---------------------------------------------------------------- calcul réparti

func _schedule() -> void:
	var w: SimWorld = fixture(3, false, 20021)
	town(w)
	var cc1: SimWorld.Building = w.team_buildings(1, "centre")[0]
	street(w, 1)
	place(w, "zone_r", 2, Vector2i(cc1.cell.x, cc1.cell.y + cc1.size), 3, 1, 1)
	period(w, 3)
	var t0: int = int(w.teams[0].city.get("tick", -1))
	var t1: int = int(w.teams[1].city.get("tick", -1))
	check(posmod(t0, UrbanRules.PERIOD) != posmod(t1, UrbanRules.PERIOD), "S01 deux camps calculés à des ticks différents (%d et %d dans la période)" % [posmod(t0, UrbanRules.PERIOD), posmod(t1, UrbanRules.PERIOD)])
	w.urban_phase = 2
	period(w, 2)
	check(posmod(int(w.teams[0].city.get("tick", -1)), UrbanRules.PERIOD) == posmod(t0, UrbanRules.PERIOD) + 2, "S02 décalage du monde : le calcul glisse de 2 ticks (mondes désynchronisés)")
	var updates: int = 0
	var last: int = int(w.teams[0].city.get("tick", -1))
	for i in 20:
		period(w, 1)
		if int(w.teams[0].city.get("tick", -1)) != last:
			updates += 1
			last = int(w.teams[0].city.get("tick", -1))
	check(updates == 20, "S03 monde affiché : un calcul par période (%d sur 20)" % updates)

# ---------------------------------------------------------------- villes lointaines

func _far() -> void:
	var near_w: SimWorld = fixture(4, false, 20031)
	var far_w: SimWorld = fixture(4, false, 20031)
	town(near_w)
	town(far_w)
	# Parcelles libres pour la croissance, le long de la route (à 2 cases au plus).
	for w in [near_w, far_w]:
		var cc: SimWorld.Building = (w as SimWorld).team_buildings(0, "centre")[0]
		var y: int = cc.cell.y + cc.size
		(w as SimWorld).issue({"t": "zone_paint", "team": 0, "kind": 4, "from": [cc.cell.x, y + 12], "to": [cc.cell.x + 1, y + 15]})
		(w as SimWorld).issue({"t": "zone_paint", "team": 0, "kind": 4, "from": [cc.cell.x - 3, y + 8], "to": [cc.cell.x - 2, y + 15]})
	far_w.urban_far = true
	var food0_n: float = float(near_w.teams[0].stats["gathered"]["food"])
	var food0_f: float = float(far_w.teams[0].stats["gathered"]["food"])
	var updates: int = 0
	var last: int = -1
	for i in 60:
		period(near_w, 1)
		period(far_w, 1)
		if int(far_w.teams[0].city.get("tick", -1)) != last:
			updates += 1
			last = int(far_w.teams[0].city.get("tick", -1))
	check(updates == 20, "M01 ville lointaine : un calcul toutes les %d périodes (%d sur 60)" % [UrbanRules.FAR_EVERY, updates])
	var made_n: float = float(near_w.teams[0].stats["gathered"]["food"]) - food0_n
	var made_f: float = float(far_w.teams[0].stats["gathered"]["food"]) - food0_f
	check(made_n > 0.0 and absf(made_f - made_n) <= made_n * 0.3, "M02 cohérence économique : vivres produits %.0f (détaillé) / %.0f (abrégé)" % [made_n, made_f])
	var grown_n: int = 0
	var grown_f: int = 0
	for b in near_w.team_buildings(0, "zone_c"):
		grown_n += 1
	for b in far_w.team_buildings(0, "zone_c"):
		grown_f += 1
	check(grown_f > 2 and float(grown_f) >= float(grown_n) * 0.5, "M03 la ville lointaine grandit aussi (%d commerces, %d en détail ; 2 au départ)" % [grown_f, grown_n])
	check(int(far_w.teams[0].city.get("habitants", 0)) > 0 and absf(float(far_w.teams[0].city.get("habitants", 0)) - float(near_w.teams[0].city.get("habitants", 0))) <= float(near_w.teams[0].city.get("habitants", 1)) * 0.4, "M04 habitants comparables (%d / %d)" % [int(near_w.teams[0].city.get("habitants", 0)), int(far_w.teams[0].city.get("habitants", 0))])
	# Coût du seul calcul de la ville (grande ville, 30 périodes) : détaillé contre lointain.
	var big_n: SimWorld = _big_city(20032)
	var big_f: SimWorld = _big_city(20032)
	big_f.urban_far = true
	var start: int = big_n.tick
	var t_near: int = 0
	var t_far: int = 0
	for i in UrbanRules.PERIOD * 30:
		big_n.tick = start + i
		big_f.tick = start + i
		var s0: int = Time.get_ticks_usec()
		UrbanCity.step(big_n)
		t_near += Time.get_ticks_usec() - s0
		s0 = Time.get_ticks_usec()
		UrbanCity.step(big_f)
		t_far += Time.get_ticks_usec() - s0
	check(float(t_far) < float(t_near) * 0.5, "M05 coût du calcul d'une ville lointaine : %.0f %% du calcul détaillé (%.0f ms / %.0f ms sur 1 min de jeu)" % [100.0 * float(t_far) / maxf(1.0, float(t_near)), float(t_far) / 1000.0, float(t_near) / 1000.0])
	# Aller-retour d'échelle : rien ne se perd.
	var ids: Array = []
	for b in far_w.team_buildings(0):
		ids.append((b as SimWorld.Building).id)
	for k in 6:
		far_w.urban_far = k % 2 == 0
		period(far_w, 5)
	var kept: bool = true
	for id in ids:
		if not far_w.buildings.has(id) and not far_w.buildings.values().any(func(o): return (o as SimWorld.Building).type == "ruine"):
			kept = false
	check(kept and int(far_w.teams[0].city.get("habitants", 0)) > 0, "M06 aller-retour entre vue détaillée et lointaine : bâtiments et habitants conservés")
	var s: Dictionary = UrbanAbstract.summary(far_w, 0)
	check(bool(s["has_city"]) and int(s["buildings"]) >= 10 and int(s["habitants"]) == int(far_w.teams[0].city.get("habitants", 0)), "M07 résumé d'une ville (vue planète) : %d bâtiments, %d habitants" % [int(s["buildings"]), int(s["habitants"])])
	check(UrbanCity.time_scale == 1.0, "M08 l'échelle de temps revient à 1 après chaque calcul")

# ---------------------------------------------------------------- IA avant l'électricité

func _ai() -> void:
	var w: SimWorld = fixture(2, false, 20041)
	for k in 6:
		w.spawn_unit(1, "ouvrier", Vector2(78.5 + float(k % 3), 77.5 + float(k / 3)))
	w.spawn_building(1, "maison", Vector2i(76, 84), true)
	w.teams[1].res = {"food": 3000.0, "wood": 3000.0, "ore": 1500.0}
	var ai: AiController = AiController.new(1)
	w.ai_controllers.append(ai)
	run(w, 4800)
	var zones: int = 0
	var roads: int = 0
	for b in w.team_buildings(1):
		if UrbanRules.is_zone((b as SimWorld.Building).type):
			zones += 1
	if UrbanZoning.has_layers(w, 1):
		for v in (w.teams[1].zoning["road"] as PackedByteArray):
			if v != 0:
				roads += 1
	check(roads >= 6 and zones >= 1, "I01 âge II, sans électricité : l'IA trace des routes (%d cases) et sa ville pousse (%d bâtiments)" % [roads, zones])
	var refused: int = 0
	for entry in w.replay:
		if int(entry["cmd"].get("team", -1)) == 1 and not bool(entry["ok"]) and String(entry["cmd"].get("t", "")) in ["zone_paint", "road_paint"]:
			refused += 1
	check(refused == 0, "I02 aucun ordre de zonage de l'IA refusé (mêmes commandes et mêmes règles que le joueur)")
	var poor: SimWorld = fixture(2, false, 20042)
	for k in 6:
		poor.spawn_unit(1, "ouvrier", Vector2(78.5 + float(k % 3), 77.5 + float(k / 3)))
	poor.teams[1].res = {"food": 120.0, "wood": 120.0, "ore": 50.0}
	var ai2: AiController = AiController.new(1)
	poor.ai_controllers.append(ai2)
	run(poor, 600)
	check(not UrbanZoning.has_layers(poor, 1) or UrbanZoning.parcels(poor, 1).is_empty(), "I03 sans surplus, l'IA garde ses ressources pour l'armée et les âges (pas de zonage)")

# ---------------------------------------------------------------- coût mesuré

func _big_city(seed_value: int) -> SimWorld:
	var w: SimWorld = fixture(6, true, seed_value)
	var cc: SimWorld.Building = w.team_buildings(0, "centre")[0]
	var road: Array = []
	for y in range(4, 92):
		road.append([cc.cell.x - 1, y])
		road.append([cc.cell.x + 9, y])
	w.issue({"t": "road_paint", "team": 0, "cells": road})
	w.issue({"t": "zone_paint", "team": 0, "kind": 2, "from": [cc.cell.x, 20], "to": [cc.cell.x + 7, 90]})
	for y in range(20, 88, 2):
		for x in [cc.cell.x, cc.cell.x + 2, cc.cell.x + 4, cc.cell.x + 6]:
			var b: SimWorld.Building = w.spawn_building(0, "zone_r", Vector2i(x, y), true)
			b.city = {"grown": true, "level": 2, "density": 1.5, "style_age": 6, "variant": x + y, "rot": 0}
	period(w, 2)
	return w

func _cost() -> void:
	var w: SimWorld = _big_city(20051)
	var t0: int = Time.get_ticks_usec()
	for b in w.team_buildings(0):
		UrbanZoning.access(w, 0, (b as SimWorld.Building).cell, (b as SimWorld.Building).size)
	var access_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	check(access_ms < 6.0, "P01 accès à la route de %d bâtiments dans un même tick : %.2f ms (seuil 6 ms, Linux)" % [w.team_buildings(0).size(), access_ms])
	var best: float = INF
	for i in 3:
		var s0: int = Time.get_ticks_usec()
		UrbanCity._update(w, 0)
		best = minf(best, float(Time.get_ticks_usec() - s0) / 1000.0)
	check(best < 20.0, "P02 calcul complet d'une ville de 136 bâtiments : %.1f ms (seuil 20 ms, Linux ; Android NOT_RUN)" % best)
	print("URBAN_LOTB_COST access_ms=%.2f update_ms=%.2f buildings=%d" % [access_ms, best, w.team_buildings(0).size()])
