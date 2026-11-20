class_name UrbanAI
extends RefCounted
## 0.18 — Ville de l'IA après la recherche « Électricité ». Mêmes commandes et mêmes conditions que le joueur
## ("build", "urban_upgrade") ; une décision toutes les 2 s au plus. Aucun privilège : aucune ressource ni information cachée.
## 0.19 — Les zones ne se posent plus : l'IA trace des routes ("road_paint") et peint des parcelles ("zone_paint"),
## puis la croissance (UrbanGrowth) construit pour elle comme pour le joueur.

const MAX_ZONES: int = 36
const MAX_PENDING: int = 2
const TARGET := {"zone_r": 0.45, "zone_c": 0.25, "zone_i": 0.3}

static func think(w: SimWorld, ai: AiController, t: SimWorld.Team, home: Vector2) -> void:
	if w.tick % 20 != ai.think_offset % 20:
		return
	var team: int = ai.team
	var city: Dictionary = t.city
	var counts: Dictionary = {}
	var pending: int = 0
	var zones: Array = []
	for candidate in w.team_buildings(team):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not UrbanRules.is_urban(b.type):
			continue
		counts[b.type] = int(counts.get(b.type, 0)) + 1
		if not b.complete:
			pending += 1
		elif UrbanRules.is_zone(b.type):
			zones.append(b)
	if pending >= MAX_PENDING:
		return
	var power: Array = city.get("power", [0, 0]) as Array
	var water: Array = city.get("water", [0, 0]) as Array
	var factors: Dictionary = city.get("factors", {}) as Dictionary
	var zone_total: int = int(counts.get("zone_r", 0)) + int(counts.get("zone_c", 0)) + int(counts.get("zone_i", 0))
	# 1. Électricité, puis eau : sans elles, rien ne fonctionne.
	if (int(counts.get("centrale", 0)) + int(counts.get("centrale_solaire", 0)) == 0 and zone_total >= 3) or int(power[1]) + 6 > int(power[0]):
		var plant: String = "centrale_solaire" if t.age >= 8 and float(factors.get("cadre", 100.0)) < 70.0 else "centrale"
		if ai._place(w, plant, home, 6, 16):
			return
	if int(water[1]) + 4 > int(water[0]):
		if _place_in_grid(w, team, "chateau_eau"):
			return
	# 2. Zones hors réseau : prolonger le réseau par un poste électrique.
	for candidate in zones:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not bool(b.city.get("powered_grid", true)):
			if _place_relay_toward(w, team, b):
				return
			break
	# 3. Services selon la taille et l'état de la ville.
	if zone_total >= 6 and int(counts.get("caserne_pompiers", 0)) < 1 + zone_total / 16:
		if _place_in_grid(w, team, "caserne_pompiers"):
			return
	if zone_total >= 8 and (int(counts.get("commissariat", 0)) == 0 or (float(factors.get("securite", 100.0)) < 55.0 and int(counts.get("commissariat", 0)) < 1 + zone_total / 14)):
		if _place_in_grid(w, team, "commissariat"):
			return
	if zone_total >= 10 and (int(counts.get("hopital", 0)) == 0 or (float(factors.get("sante", 100.0)) < 60.0 and int(counts.get("hopital", 0)) < 1 + zone_total / 20)):
		if _place_in_grid(w, team, "hopital"):
			return
	if zone_total >= 6 and float(factors.get("cadre", 100.0)) < 65.0 and int(counts.get("decharge", 0)) + int(counts.get("recyclage", 0)) == 0:
		if _place_in_grid(w, team, "recyclage" if t.age >= 6 else "decharge"):
			return
	# 4. Améliorations quand le stock le permet.
	if float(t.res["wood"]) >= 500.0 and float(t.res["ore"]) >= 500.0:
		for candidate in zones:
			var b: SimWorld.Building = candidate as SimWorld.Building
			var level: int = int(b.city.get("level", 1))
			if level < UrbanRules.LEVEL_MAX and float(b.city.get("density", 0.0)) >= float(level) - 0.05 and float(b.city.get("happiness", 0.0)) >= 60.0 and UrbanCity.upgrade_lack(w, team, b) == "":
				w.issue({"t": "urban_upgrade", "team": team, "building": b.id})
				return
	# 5. 0.19 : nouvelles zones par le zonage (comme le joueur) : routes reliées au centre, puis parcelles peintes.
	if zone_total >= MAX_ZONES:
		return
	var kind: String = _next_zone(t, counts, zone_total)
	zone_for(w, team, kind)

## 0.20 — Avant l'électricité : l'IA zone aussi dès l'âge I, en petit, avec les mêmes commandes que le joueur et
## seulement sur ses surplus (l'armée et le passage des âges restent prioritaires).
const EARLY_EVERY: int = 60                                    # une décision toutes les 6 s
const EARLY_ZONES := [0, 4, 6, 9, 12, 14, 16, 18, 20, 22, 24]  # bâtiments de zone visés selon l'âge
const EARLY_RESERVE := {"food": 300.0, "wood": 300.0}

static func think_early(w: SimWorld, ai: AiController, t: SimWorld.Team, home: Vector2) -> void:
	if w.tick % EARLY_EVERY != ai.think_offset % EARLY_EVERY or not UrbanCity.enabled(w):
		return
	for key in EARLY_RESERVE.keys():
		if float(t.res.get(key, 0.0)) < float(EARLY_RESERVE[key]):
			return
	var team: int = ai.team
	var counts: Dictionary = {}
	var pending: int = 0
	for candidate in w.team_buildings(team):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not UrbanRules.is_urban(b.type):
			continue
		counts[b.type] = int(counts.get(b.type, 0)) + 1
		if not b.complete:
			pending += 1
	var zone_total: int = int(counts.get("zone_r", 0)) + int(counts.get("zone_c", 0)) + int(counts.get("zone_i", 0)) + int(counts.get("zone_a", 0))
	if pending >= MAX_PENDING or zone_total >= int(EARLY_ZONES[clampi(t.age, 0, 10)]):
		return
	# Un puits dès que le quartier grandit (eau et lutte contre le feu de l'époque).
	if zone_total >= 4 and int(counts.get("puits", 0)) == 0 and UrbanCity.build_lack(w, team, "puits", Vector2i(-1, -1)) == "":
		if ai._place(w, "puits", home, 4, 12):
			return
	zone_for(w, team, _next_zone(t, counts, zone_total))

static func _next_zone(t: SimWorld.Team, counts: Dictionary, zone_total: int) -> String:
	var city: Dictionary = t.city
	# 0.19 : l'IA répond à la demande calculée par la croissance (mêmes chiffres que le panneau du joueur).
	var demand: Dictionary = city.get("demand", {}) as Dictionary
	if int(counts.get("zone_r", 0)) == 0:
		return "zone_r"
	if not demand.is_empty():
		var top: String = ""
		var top_value: float = UrbanRules.DEMAND_MIN
		for key in ["zone_r", "zone_c", "zone_i", "zone_a"]:
			if float(demand.get(key, -1.0)) > top_value:
				top_value = float(demand[key])
				top = key
		if top != "":
			return top
	if float(city.get("unemployment", 0.0)) > 0.1 or int(city.get("jobs", 0)) == 0:
		return "zone_c" if float(t.res["food"]) + float(t.res["wood"]) < float(t.res["ore"]) * 2.0 or int(counts.get("zone_c", 0)) == 0 else "zone_i"
	if t.pop_cap - t.pop <= 4 or (float(city.get("fill", 0.0)) >= 0.95 and int(city.get("jobs", 0)) > 0):
		return "zone_r"
	var best: String = "zone_r"
	var gap: float = -INF
	for key in TARGET.keys():
		var share: float = float(counts.get(key, 0)) / float(maxi(1, zone_total))
		var d: float = float(TARGET[key]) - share
		if d > gap:
			gap = d
			best = String(key)
	return best

static func _grid_nodes(w: SimWorld, team: int) -> Array:
	var nodes: Array = []
	for candidate in w.team_buildings(team, "", true):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if b.type == "centre":
			nodes.append([b.center, float(UrbanRules.POWER_SOURCES["centre"]["reach"]), b.id])
		elif UrbanRules.POWER_SOURCES.has(b.type):
			nodes.append([b.center, float(UrbanRules.POWER_SOURCES[b.type]["reach"]), b.id])
		elif UrbanRules.RELAY.has(b.type) and bool(b.city.get("powered", false)):
			nodes.append([b.center, float(UrbanRules.RELAY[b.type]), b.id])
	nodes.sort_custom(func(a, b) -> bool: return int(a[2]) < int(b[2]))
	return nodes

static func _place_in_grid(w: SimWorld, team: int, kind: String) -> bool:
	## Pose dans la desserte électrique existante, en laissant une case libre autour (passages).
	var size: int = int(Rules.BUILDINGS[kind]["size"])
	for node in _grid_nodes(w, team):
		var center: Vector2 = node[0] as Vector2
		var reach: float = float(node[1])
		for r in range(2, int(reach)):
			for k in 12:
				var ang: float = float(k) / 12.0 * TAU + float(r) * 0.37
				var p: Vector2 = center + Vector2(cos(ang), sin(ang)) * float(r)
				var cell: Vector2i = Vector2i(int(p.x - float(size) * 0.5), int(p.y - float(size) * 0.5))
				if w.has_margin(cell, size) and w.build_check(team, kind, cell) == "":
					return bool(w.issue({"t": "build", "team": team, "type": kind, "cell": [cell.x, cell.y]})["ok"])
	return false

static func _place_relay_toward(w: SimWorld, team: int, target: SimWorld.Building) -> bool:
	var best: Vector2 = Vector2(-1, -1)
	var best_d: float = INF
	for node in _grid_nodes(w, team):
		var d: float = (node[0] as Vector2).distance_to(target.center)
		if d < best_d:
			best_d = d
			best = node[0] as Vector2
	if best.x < 0.0:
		return false
	var dir: Vector2 = (target.center - best).normalized()
	for step in range(4, 0, -1):
		var p: Vector2 = best + dir * minf(best_d - 1.0, float(step) * 1.5 + 2.0)
		var cell: Vector2i = Vector2i(int(p.x), int(p.y))
		if w.build_check(team, "poste_electrique", cell) == "":
			return bool(w.issue({"t": "build", "team": team, "type": "poste_electrique", "cell": [cell.x, cell.y]})["ok"])
	return false


# ---------------------------------------------------------------- 0.19 : zonage de l'IA

const ROAD_BATCH: int = 10             # cases de route tracées au plus par décision
const ZONE_CODE := {"zone_r": 2, "zone_c": 4, "zone_i": 5, "zone_a": 6}

static func road_plan(w: SimWorld, team: int) -> Array:
	## Plan routier déterministe : anneau autour du premier centre, quatre axes, rues transversales tous les 6 cases.
	var centres: Array = w.team_buildings(team, "centre", true)
	if centres.is_empty():
		return []
	centres.sort_custom(func(a, b) -> bool: return int(a.id) < int(b.id))
	var cc: SimWorld.Building = centres[0] as SimWorld.Building
	var out: Array = []
	var seen: Dictionary = {}
	var add := func(c: Vector2i) -> void:
		var key: int = c.y * 65536 + c.x
		if w.in_map(c) and not seen.has(key):
			seen[key] = true
			out.append(c)
	for x in range(-1, cc.size + 1):
		add.call(cc.cell + Vector2i(x, -1))
		add.call(cc.cell + Vector2i(x, cc.size))
	for y in range(0, cc.size):
		add.call(cc.cell + Vector2i(-1, y))
		add.call(cc.cell + Vector2i(cc.size, y))
	var mid: int = cc.size / 2
	var reach: int = int(UrbanRules.TERRITORY) - 4
	var axes: Array = [[Vector2i(mid, -1), Vector2i(0, -1)], [Vector2i(mid, cc.size), Vector2i(0, 1)], [Vector2i(-1, mid), Vector2i(-1, 0)], [Vector2i(cc.size, mid), Vector2i(1, 0)]]
	for step in range(1, reach):
		for axis in axes:
			var origin: Vector2i = cc.cell + (axis[0] as Vector2i)
			var dir: Vector2i = axis[1] as Vector2i
			var c: Vector2i = origin + dir * step
			add.call(c)
			if step % 6 == 0:
				var side: Vector2i = Vector2i(dir.y, dir.x)
				for k in range(1, 9):
					add.call(c + side * k)
					add.call(c - side * k)
	return out

static func zone_for(w: SimWorld, team: int, kind: String) -> bool:
	## Peint une parcelle de la catégorie demandée près d'une route reliée ; à défaut, prolonge les routes.
	UrbanZoning.ensure(w, team)
	var free: int = 0
	var free_any: int = 0
	for idx in UrbanZoning.parcels(w, team):
		var origin: Vector2i = Vector2i(idx % w.map_size, idx / w.map_size)
		var code: int = UrbanZoning.parcel_code(w, team, origin)
		if code == 0 or not w.footprint_free(origin, UrbanRules.PARCEL) or not UrbanZoning.access(w, team, origin, UrbanRules.PARCEL):
			continue
		free_any += 1
		if String((UrbanZoning.KINDS[code] as Dictionary)["building"]) == kind:
			free += 1
	if free >= 2:
		return false
	var centres: Array = w.team_buildings(team, "centre", true)
	if centres.is_empty():
		return false
	var home: Vector2 = (centres[0] as SimWorld.Building).center
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = INF
	var radius: int = int(UrbanRules.TERRITORY) - 3
	var step: int = UrbanRules.PARCEL
	var x0: int = (int(home.x) - radius) / step * step
	var y0: int = (int(home.y) - radius) / step * step
	for y in range(maxi(0, y0), mini(w.map_size - step, int(home.y) + radius), step):
		for x in range(maxi(0, x0), mini(w.map_size - step, int(home.x) + radius), step):
			var origin: Vector2i = Vector2i(x, y)
			if UrbanZoning.zone_at(w, team, origin) != 0 or not w.footprint_free(origin, step):
				continue
			if UrbanZoning.cell_lack(w, team, origin, false) != "" or UrbanZoning.cell_lack(w, team, origin + Vector2i(1, 1), false) != "":
				continue
			if not UrbanZoning.access(w, team, origin, step):
				continue
			var d: float = (Vector2(origin) + Vector2.ONE).distance_to(home)
			# Habitat et commerce près du centre, industrie et agriculture plus loin.
			var score: float = d if kind in ["zone_r", "zone_c"] else absf(d - 12.0)
			if score < best_score:
				best_score = score
				best = origin
	if best.x >= 0:
		return bool(w.issue({"t": "zone_paint", "team": team, "kind": int(ZONE_CODE[kind]), "from": [best.x, best.y], "to": [best.x + step - 1, best.y + step - 1]}).get("ok", false))
	# Routes : seulement si les parcelles prêtes manquent, et en gardant une réserve (même prudence que le joueur).
	var t: SimWorld.Team = w.teams[team]
	# Réserve sur les ressources que la route coûte réellement à cet âge (bois seul aux premiers âges).
	var road_cost: Dictionary = UrbanZoning.road_cost(w, team)
	var short: bool = false
	for key in road_cost.keys():
		if float(road_cost[key]) > 0.0 and float(t.res.get(key, 0.0)) < 150.0:
			short = true
	if free_any >= 6 or short:
		return false
	var batch: Array = []
	for value in road_plan(w, team):
		var c: Vector2i = value
		if UrbanZoning.team_road_at(w, team, c) or UrbanZoning.cell_lack(w, team, c, true) != "":
			continue
		batch.append([c.x, c.y])
		if batch.size() >= ROAD_BATCH:
			break
	if batch.is_empty():
		return false
	return bool(w.issue({"t": "road_paint", "team": team, "cells": batch}).get("ok", false))
