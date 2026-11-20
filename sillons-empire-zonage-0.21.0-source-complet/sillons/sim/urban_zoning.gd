class_name UrbanZoning
extends RefCounted
## 0.19 — Zonage peint par le joueur et routes, sur la carte de bataille. Couches par camp dans Team.zoning
## (sauvegardées avec la partie) : "zone" (code par case) et "road" (1 = route). Commandes passées par SimWorld.issue,
## identiques pour le joueur et l'IA. Le réseau routier relié aux centres est recalculé seulement quand il change.
## Repères de genre seulement : aucun nom, chiffre, visuel ou texte repris d'un jeu existant.

## Codes de zone. "building" : bâtiment qui pousse ; "cap" : niveau maximal autorisé par ce zonage.
const KINDS := {
	1: {"key": "r1", "label": "Habitat faible densité", "short": "Hab. bas", "building": "zone_r", "cap": 2, "color": Color(0.45, 0.85, 0.40)},
	2: {"key": "r2", "label": "Habitat densité moyenne", "short": "Hab. moyen", "building": "zone_r", "cap": 4, "color": Color(0.20, 0.72, 0.30)},
	3: {"key": "r3", "label": "Habitat haute densité", "short": "Hab. dense", "building": "zone_r", "cap": 6, "color": Color(0.05, 0.52, 0.22)},
	4: {"key": "c", "label": "Commerce", "short": "Commerce", "building": "zone_c", "cap": 5, "color": Color(0.25, 0.55, 0.98)},
	5: {"key": "i", "label": "Industrie", "short": "Industrie", "building": "zone_i", "cap": 5, "color": Color(0.98, 0.78, 0.15)},
	6: {"key": "a", "label": "Agriculture", "short": "Agricole", "building": "zone_a", "cap": 3, "color": Color(0.78, 0.55, 0.30)},
}
## Pastilles de la barre du zonage (route, gomme), à côté des couleurs des zones.
const ROAD_SWATCH := Color(0.55, 0.52, 0.48)
const ERASE_SWATCH := Color(0.90, 0.25, 0.20)
## Zones spécialisées prévues (architecture extensible) : pas encore peintes, aucune règle ne les utilise.
const PLANNED := {
	20: {"key": "mine", "label": "Zone minière"}, 21: {"key": "energie", "label": "Zone énergétique"},
	22: {"key": "militaire", "label": "Zone militaire"}, 23: {"key": "science", "label": "Zone scientifique"},
	24: {"key": "admin", "label": "Zone administrative"}, 25: {"key": "port", "label": "Zone portuaire"},
	26: {"key": "spatial", "label": "Zone spatiale"}, 27: {"key": "loisirs", "label": "Zone de loisirs"},
	28: {"key": "logistique", "label": "Zone logistique"},
}
const MAX_CELLS: int = 2048             # cases au plus par commande
const ROAD_COST := [{"wood": 2.0}, {"wood": 1.0, "ore": 1.0}, {"ore": 2.0}]   # âges I–III, IV–VI, VII–X
const ROAD_UNDO_WINDOW: int = 200       # ticks pendant lesquels « Annuler » rembourse une route en entier
const LEGACY_CODE := {"zone_r": 2, "zone_c": 4, "zone_i": 5, "zone_a": 6}

# ---------------------------------------------------------------- couches

static func ensure(w: SimWorld, team: int) -> Dictionary:
	## Crée les couches du camp (une seule fois) et migre les zones posées en 0.18.
	var t: SimWorld.Team = w.teams[team]
	var z: Dictionary = t.zoning
	var n: int = w.map_size * w.map_size
	if not z.get("zone") is PackedByteArray or (z["zone"] as PackedByteArray).size() != n:
		var zone := PackedByteArray()
		zone.resize(n)
		z["zone"] = zone
	if not z.get("road") is PackedByteArray or (z["road"] as PackedByteArray).size() != n:
		var road := PackedByteArray()
		road.resize(n)
		z["road"] = road
	if int(z.get("v", 0)) < 1:
		_migrate(w, team, z)
		z["v"] = 1
	return z

static func has_layers(w: SimWorld, team: int) -> bool:
	return (w.teams[team] as SimWorld.Team).zoning.get("zone") is PackedByteArray

static func _migrate(w: SimWorld, team: int, z: Dictionary) -> void:
	## Sauvegardes 0.18 : chaque zone posée comme bâtiment devient une parcelle zonée portant ce bâtiment.
	var zone: PackedByteArray = z["zone"]
	var count: int = 0
	for candidate in w.team_buildings(team):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not LEGACY_CODE.has(b.type):
			continue
		for dy in b.size:
			for dx in b.size:
				var c: Vector2i = b.cell + Vector2i(dx, dy)
				if w.in_map(c):
					zone[w.idx(c)] = int(LEGACY_CODE[b.type])
		if not b.city.has("style_age"):
			b.city["style_age"] = clampi((w.teams[team] as SimWorld.Team).age, 1, 10)
		if not b.city.has("legacy") and not bool(b.city.get("grown", false)):
			b.city["legacy"] = true
		b.city["zoned_once"] = true
		count += 1
	z["zone"] = zone
	z["migrated"] = count
	z["rev"] = int(z.get("rev", 0)) + 1

static func zone_at(w: SimWorld, team: int, c: Vector2i) -> int:
	if not w.in_map(c) or not has_layers(w, team):
		return 0
	return int(((w.teams[team] as SimWorld.Team).zoning["zone"] as PackedByteArray)[w.idx(c)])

static func zone_owner(w: SimWorld, c: Vector2i) -> int:
	for team in w.teams.size():
		if team != SimWorld.TEAM_NEUTRAL and zone_at(w, team, c) != 0:
			return team
	return -1

static func road_layer(w: SimWorld) -> PackedByteArray:
	## Toutes les routes (tous camps confondus), dérivées des couches des camps : utile au placement des bâtiments.
	var n: int = w.map_size * w.map_size
	if w.urban_roads.size() != n:
		var all := PackedByteArray()
		all.resize(n)
		for team in w.teams.size():
			if has_layers(w, team):
				var road: PackedByteArray = (w.teams[team] as SimWorld.Team).zoning["road"]
				for i in n:
					if road[i] != 0:
						all[i] = team + 1
		w.urban_roads = all
	return w.urban_roads

static func road_at(w: SimWorld, c: Vector2i) -> bool:
	if not w.in_map(c) or w.urban_roads.is_empty() and not _any_layers(w):
		return false
	return road_layer(w)[w.idx(c)] != 0

static func team_road_at(w: SimWorld, team: int, c: Vector2i) -> bool:
	if not w.in_map(c) or not has_layers(w, team):
		return false
	return int(((w.teams[team] as SimWorld.Team).zoning["road"] as PackedByteArray)[w.idx(c)]) != 0

static func _any_layers(w: SimWorld) -> bool:
	for team in w.teams.size():
		if has_layers(w, team):
			return true
	return false

static func road_cost(w: SimWorld, team: int) -> Dictionary:
	var age: int = (w.teams[team] as SimWorld.Team).age
	var tier: int = 0 if age <= 3 else (1 if age <= 6 else 2)
	return w.scaled_cost(ROAD_COST[tier] as Dictionary)

# ---------------------------------------------------------------- territoire

static func territory_ok(w: SimWorld, team: int, c: Vector2i) -> bool:
	var p: Vector2 = Vector2(c) + Vector2(0.5, 0.5)
	for candidate in w.team_buildings(team, "", true):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if b.type == "ruine":
			continue
		if b.center.distance_to(p) <= UrbanRules.TERRITORY:
			return true
	return false

static func cell_lack(w: SimWorld, team: int, c: Vector2i, for_road: bool) -> String:
	if not w.in_map(c):
		return "hors de la carte"
	var terrain: int = w.terrain[w.idx(c)]
	if terrain == SimWorld.TERRAIN_WATER or (terrain == SimWorld.TERRAIN_FORD and not for_road):
		return "sur l'eau"
	var owner: int = zone_owner(w, c)
	if owner != -1 and owner != team:
		return "zone d'un autre camp"
	if road_layer(w)[w.idx(c)] != 0 and int(road_layer(w)[w.idx(c)]) != team + 1:
		return "route d'un autre camp"
	if not territory_ok(w, team, c):
		return "trop loin de vos bâtiments"
	if for_road:
		if w._occupied.has(c):
			return "case occupée par un bâtiment"
		if w._node_cells.has(c) and (w.nodes[w._node_cells[c]] as SimWorld.ResNode).amount > 0.0:
			return "ressource sur la case"
	return ""

# ---------------------------------------------------------------- commandes

static func handles(kind: String) -> bool:
	return kind in ["zone_paint", "zone_clear", "road_paint", "road_remove", "zone_historic"]

static func cells_of(w: SimWorld, cmd: Dictionary) -> Array:
	## Cases d'une commande : "cells" [[x, y], …] ou rectangle "from" / "to" (inclus). Dédoublonnées, ordre stable.
	var out: Array = []
	var seen: Dictionary = {}
	if cmd.has("from") and cmd.has("to"):
		var a: Array = cmd["from"] as Array
		var b: Array = cmd["to"] as Array
		var x0: int = mini(int(a[0]), int(b[0]))
		var x1: int = maxi(int(a[0]), int(b[0]))
		var y0: int = mini(int(a[1]), int(b[1]))
		var y1: int = maxi(int(a[1]), int(b[1]))
		if (x1 - x0 + 1) * (y1 - y0 + 1) > MAX_CELLS:
			return []
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				out.append(Vector2i(x, y))
		return out
	for value in cmd.get("cells", []) as Array:
		var c: Vector2i
		if value is Vector2i:
			c = value
		elif value is Array and (value as Array).size() >= 2:
			c = Vector2i(int(value[0]), int(value[1]))
		else:
			continue
		var key: int = c.y * 65536 + c.x
		if seen.has(key):
			continue
		seen[key] = true
		out.append(c)
		if out.size() >= MAX_CELLS:
			break
	return out

static func command(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	if not UrbanCity.enabled(w):
		return w._no("zonage réservé aux parties avec l'évolution de la civilisation")
	var kind: String = String(cmd.get("t", ""))
	if kind == "zone_historic":
		# Quartier historique : le bâtiment (et son quartier s'il est demandé) garde son architecture.
		var b: SimWorld.Building = w.buildings.get(int(cmd.get("building", -1))) as SimWorld.Building
		if b == null or b.team != team or not UrbanRules.is_zone(b.type):
			return w._no("bâtiment de zone allié requis")
		var on: bool = bool(cmd.get("on", true))
		var targets: Array = [b]
		if bool(cmd.get("district", false)):
			targets.clear()
			var cells_set: Dictionary = {}
			for value in district(w, team, b.cell):
				cells_set[(value as Vector2i).y * 65536 + (value as Vector2i).x] = true
			for candidate in w.team_buildings(team):
				var o: SimWorld.Building = candidate as SimWorld.Building
				if UrbanRules.is_zone(o.type) and cells_set.has(o.cell.y * 65536 + o.cell.x):
					targets.append(o)
		for value in targets:
			(value as SimWorld.Building).city["historic"] = on
		var result: Dictionary = w._ok()
		result["changed"] = targets.size()
		return result
	var cells: Array = cells_of(w, cmd)
	if cells.is_empty():
		return w._no("aucune case (ou sélection trop grande)")
	var z: Dictionary = ensure(w, team)
	match kind:
		"zone_paint", "zone_clear":
			var code: int = 0 if kind == "zone_clear" else int(cmd.get("kind", 0))
			if code != 0 and not KINDS.has(code):
				return w._no("type de zone inconnu")
			var zone: PackedByteArray = z["zone"]
			var road: PackedByteArray = z["road"]
			var changed: int = 0
			var refused: String = ""
			for value in cells:
				var c: Vector2i = value
				var why: String = cell_lack(w, team, c, false)
				if why != "":
					refused = why
					continue
				var i: int = w.idx(c)
				if code != 0 and road[i] != 0:
					continue
				if int(zone[i]) != code:
					zone[i] = code
					changed += 1
			z["zone"] = zone
			if changed > 0:
				z["rev"] = int(z.get("rev", 0)) + 1
			if changed == 0 and refused != "":
				return w._no(refused)
			var result: Dictionary = w._ok()
			result["changed"] = changed
			return result
		"road_paint":
			var road: PackedByteArray = z["road"]
			var zone: PackedByteArray = z["zone"]
			var unit_cost: Dictionary = road_cost(w, team)
			var added: Array = []
			var refused: String = ""
			for value in cells:
				var c: Vector2i = value
				var i: int = w.idx(c) if w.in_map(c) else -1
				if i >= 0 and road[i] != 0:
					continue
				var why: String = cell_lack(w, team, c, true)
				if why != "":
					refused = why
					continue
				if not w._can_pay(team, unit_cost):
					refused = w._missing_text(team, unit_cost)
					break
				w._pay(team, unit_cost)
				road[i] = 1
				zone[i] = 0
				added.append([c.x, c.y])
			z["road"] = road
			z["zone"] = zone
			if added.is_empty():
				return w._no(refused if refused != "" else "route déjà tracée")
			z["rev"] = int(z.get("rev", 0)) + 1
			z["road_rev"] = int(z.get("road_rev", 0)) + 1
			z["last_roads"] = {"tick": w.tick, "cells": added, "cost": unit_cost}
			w.urban_roads = PackedByteArray()
			road_layer(w)
			var result: Dictionary = w._ok()
			result["changed"] = added.size()
			return result
		"road_remove":
			var road: PackedByteArray = z["road"]
			var last: Dictionary = z.get("last_roads", {}) as Dictionary
			var undo: bool = bool(cmd.get("undo", false)) and w.tick - int(last.get("tick", -99999)) <= ROAD_UNDO_WINDOW
			var undo_cells: Dictionary = {}
			if undo:
				for pair in last.get("cells", []) as Array:
					undo_cells[int(pair[1]) * 65536 + int(pair[0])] = true
			var removed: int = 0
			var refund: Dictionary = {}
			for value in cells:
				var c: Vector2i = value
				if not w.in_map(c) or road[w.idx(c)] == 0:
					continue
				road[w.idx(c)] = 0
				removed += 1
				var share: float = 1.0 if undo_cells.has(c.y * 65536 + c.x) else 0.5
				var cost: Dictionary = (last.get("cost", {}) as Dictionary) if share >= 1.0 else road_cost(w, team)
				for res in cost.keys():
					refund[res] = float(refund.get(res, 0.0)) + float(cost[res]) * share
			z["road"] = road
			if removed == 0:
				return w._no("aucune route à retirer")
			var t: SimWorld.Team = w.teams[team]
			for res in refund.keys():
				t.res[res] = float(t.res[res]) + float(refund[res])
			z["rev"] = int(z.get("rev", 0)) + 1
			z["road_rev"] = int(z.get("road_rev", 0)) + 1
			w.urban_roads = PackedByteArray()
			road_layer(w)
			var result: Dictionary = w._ok()
			result["changed"] = removed
			return result
	return w._no("commande de zonage inconnue")

# ---------------------------------------------------------------- réseau routier

static func linked(w: SimWorld, team: int) -> PackedByteArray:
	## Cases de route reliées à un centre allié (parcours en largeur), recalculées quand les routes ou les centres changent.
	var z: Dictionary = ensure(w, team)
	var n: int = w.map_size * w.map_size
	# 0.20 : déjà vérifié pendant ce tick (même révision des routes) → pas de nouveau parcours des bâtiments. Sans ce
	# raccourci, l'accès de chaque bâtiment reparcourait tous les bâtiments de la carte (coût au carré).
	if int(z.get("linked_tick", -1)) == w.tick and int(z.get("linked_rev", -1)) == int(z.get("road_rev", 0)) \
			and z.get("linked") is PackedByteArray and (z["linked"] as PackedByteArray).size() == n:
		return z["linked"]
	z["linked_tick"] = w.tick
	z["linked_rev"] = int(z.get("road_rev", 0))
	var centres: Array = []
	for candidate in w.team_buildings(team, "centre", true):
		centres.append(candidate)
	centres.sort_custom(func(a, b) -> bool: return int(a.id) < int(b.id))
	var signature: String = "%d|" % int(z.get("road_rev", 0))
	for c in centres:
		signature += "%d," % int((c as SimWorld.Building).id)
	if String(z.get("linked_sig", "")) == signature and z.get("linked") is PackedByteArray and (z["linked"] as PackedByteArray).size() == n:
		return z["linked"]
	var road: PackedByteArray = z["road"]
	var out := PackedByteArray()
	out.resize(n)
	var queue: Array = []
	for candidate in centres:
		var b: SimWorld.Building = candidate as SimWorld.Building
		for dy in range(-1, b.size + 1):
			for dx in range(-1, b.size + 1):
				var c: Vector2i = b.cell + Vector2i(dx, dy)
				if w.in_map(c) and road[w.idx(c)] != 0 and out[w.idx(c)] == 0:
					out[w.idx(c)] = 1
					queue.append(c)
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if w.in_map(nb) and road[w.idx(nb)] != 0 and out[w.idx(nb)] == 0:
				out[w.idx(nb)] = 1
				queue.append(nb)
	z["linked"] = out
	z["linked_sig"] = signature
	return out

static func access(w: SimWorld, team: int, cell: Vector2i, size: int) -> bool:
	## Une route reliée à un centre passe à moins de ROAD_REACH cases de l'emprise.
	if not has_layers(w, team):
		return false
	var link: PackedByteArray = linked(w, team)
	var r: int = UrbanRules.ROAD_REACH
	for dy in range(-r, size + r):
		for dx in range(-r, size + r):
			var c: Vector2i = cell + Vector2i(dx, dy)
			if w.in_map(c) and link[w.idx(c)] != 0:
				return true
	return false

# ---------------------------------------------------------------- parcelles et quartiers

static func parcel_code(w: SimWorld, team: int, origin: Vector2i) -> int:
	## Code de la parcelle 2×2 si ses quatre cases portent des zones du même bâtiment (sinon 0). Le code le plus
	## dense l'emporte entre variantes d'habitat.
	var code: int = 0
	var building: String = ""
	for dy in UrbanRules.PARCEL:
		for dx in UrbanRules.PARCEL:
			var k: int = zone_at(w, team, origin + Vector2i(dx, dy))
			if k == 0:
				return 0
			var kb: String = String((KINDS[k] as Dictionary)["building"])
			if building == "":
				building = kb
			elif kb != building:
				return 0
			code = maxi(code, k)
	return code

static func parcels(w: SimWorld, team: int) -> PackedInt32Array:
	## Origines possibles des parcelles 2×2 entièrement zonées (index de case), sans grille imposée : une bande
	## peinte de deux cases de large donne des parcelles où qu'elle soit. Recalculées quand le zonage change.
	var z: Dictionary = ensure(w, team)
	if int(z.get("parcels_rev", -1)) == int(z.get("rev", 0)) and z.get("parcels") is PackedInt32Array:
		return z["parcels"]
	var out := PackedInt32Array()
	var zone: PackedByteArray = z["zone"]
	var step: int = UrbanRules.PARCEL
	for y in range(0, w.map_size - step + 1):
		for x in range(0, w.map_size - step + 1):
			if zone[y * w.map_size + x] != 0 and parcel_code(w, team, Vector2i(x, y)) != 0:
				out.append(y * w.map_size + x)
	z["parcels"] = out
	z["parcels_rev"] = int(z.get("rev", 0))
	return out

static func district(w: SimWorld, team: int, start: Vector2i, limit: int = 4096) -> Array:
	## Cases du quartier : zones du même bâtiment reliées par un côté à la case touchée.
	var code: int = zone_at(w, team, start)
	if code == 0:
		return []
	var building: String = String((KINDS[code] as Dictionary)["building"])
	var out: Array = [start]
	var seen: Dictionary = {start.y * 65536 + start.x: true}
	var head: int = 0
	while head < out.size() and out.size() < limit:
		var c: Vector2i = out[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			var key: int = nb.y * 65536 + nb.x
			if seen.has(key):
				continue
			var k: int = zone_at(w, team, nb)
			if k != 0 and String((KINDS[k] as Dictionary)["building"]) == building:
				seen[key] = true
				out.append(nb)
	return out

static func district_stats(w: SimWorld, team: int, start: Vector2i) -> Dictionary:
	## Fiche de quartier : type, habitants, bâtiments, niveaux, emplois, production, richesse, criminalité, états…
	var cells: Array = district(w, team, start)
	if cells.is_empty():
		return {}
	var code: int = zone_at(w, team, start)
	var kind: Dictionary = KINDS[code] as Dictionary
	var cell_set: Dictionary = {}
	for value in cells:
		var c: Vector2i = value
		cell_set[c.y * 65536 + c.x] = true
	var stats: Dictionary = {"code": code, "label": String(kind["label"]), "building": String(kind["building"]), "cells": cells.size(),
		"buildings": 0, "habitants": 0, "jobs": 0, "employed": 0.0, "levels": 0, "level_max": 0, "wealth": 0.0, "crime": 0.0,
		"pollution": 0.0, "states": {}, "out": {}, "burning": 0, "ruins": 0, "sites": 0, "road": false, "potential": 0}
	var counted: int = 0
	for candidate in w.team_buildings(team):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not cell_set.has(b.cell.y * 65536 + b.cell.x):
			continue
		if b.type == "ruine":
			stats["ruins"] = int(stats["ruins"]) + 1
			continue
		if not UrbanRules.is_zone(b.type):
			continue
		stats["buildings"] = int(stats["buildings"]) + 1
		if not bool(stats["road"]) and access(w, team, b.cell, b.size):
			stats["road"] = true
		if not b.complete:
			stats["sites"] = int(stats["sites"]) + 1
			continue
		var c: Dictionary = b.city
		counted += 1
		stats["habitants"] = int(stats["habitants"]) + int(c.get("habitants", 0))
		stats["jobs"] = int(stats["jobs"]) + int(c.get("jobs", 0))
		stats["employed"] = float(stats["employed"]) + float(c.get("employed", 0.0))
		stats["levels"] = int(stats["levels"]) + int(c.get("level", 1))
		stats["level_max"] = maxi(int(stats["level_max"]), int(c.get("level", 1)))
		stats["wealth"] = float(stats["wealth"]) + float(c.get("wealth", 0.0))
		stats["crime"] = float(stats["crime"]) + float(c.get("crime", 0.0))
		stats["pollution"] = float(stats["pollution"]) + float(c.get("pollution", 0.0))
		var state: String = String(c.get("state", "operational"))
		(stats["states"] as Dictionary)[state] = int((stats["states"] as Dictionary).get(state, 0)) + 1
		if float(c.get("burning", 0.0)) > 0.0:
			stats["burning"] = int(stats["burning"]) + 1
		for res in (c.get("out", {}) as Dictionary).keys():
			(stats["out"] as Dictionary)[res] = float((stats["out"] as Dictionary).get(res, 0.0)) + float((c["out"] as Dictionary)[res])
	if counted > 0:
		stats["wealth"] = float(stats["wealth"]) / float(counted)
		stats["crime"] = float(stats["crime"]) / float(counted)
		stats["pollution"] = float(stats["pollution"]) / float(counted)
		stats["level_avg"] = float(stats["levels"]) / float(counted)
	# Parcelles libres (comptées sans chevauchement) et accès routier.
	var taken: Dictionary = {}
	var free_parcels: int = 0
	for value in cells:
		var origin: Vector2i = value
		var key: int = origin.y * 65536 + origin.x
		if taken.has(key) or parcel_code(w, team, origin) == 0 or not w.footprint_free(origin, UrbanRules.PARCEL):
			continue
		var overlap: bool = false
		for dy in UrbanRules.PARCEL:
			for dx in UrbanRules.PARCEL:
				if taken.has((origin.y + dy) * 65536 + origin.x + dx):
					overlap = true
		if overlap:
			continue
		for dy in UrbanRules.PARCEL:
			for dx in UrbanRules.PARCEL:
				taken[(origin.y + dy) * 65536 + origin.x + dx] = true
		free_parcels += 1
		if access(w, team, origin, UrbanRules.PARCEL):
			stats["road"] = true
	stats["potential"] = free_parcels
	stats["cap"] = mini(int(kind["cap"]), mini(UrbanRules.kind_max(String(kind["building"])), UrbanRules.age_cap((w.teams[team] as SimWorld.Team).age)))
	stats["demand"] = float(((w.teams[team] as SimWorld.Team).city.get("demand", {}) as Dictionary).get(String(kind["building"]), 0.0))
	return stats
