class_name PlanetRegions
extends RefCounted
## J9 — Gestion des régions tactiques (atlas 512×256, 96 cellules par région).
## Les mondes habités restent simulés à chaque tick, même hors écran ; les régions
## vierges sont regénérées à partir de la seed, ce qui borne leur empreinte persistée.
## Règle : aucun transfert avant l'arrivée physique à la frontière praticable.
const FORMAT: int = 1
const MAX_SAVE_REGIONS: int = 1024
const OFFSCREEN_ALERTS := ["mort", "detruit", "alerte_missile", "penurie", "sans_centre", "elimine", "recherche_perdue", "age_atteint"]

var master_seed: int = 1
var home: Vector2i = Vector2i.ZERO
var active: Vector2i = Vector2i.ZERO
var regions: Dictionary = {}  # id "x:y" -> SimWorld
var crossings: Array = []   # {region, unit, team, edge:V2, dir:V2i}
var next_identity: int = 1
var last_arrivals: Array = []

static func key(c: Vector2i) -> String:
	return "%d:%d" % [c.x, c.y]

static func neighbor(c: Vector2i, direction: Vector2i) -> Vector2i:
	return Vector2i(posmod(c.x + direction.x, PlanetGenerator.ATLAS_W), c.y + direction.y)

static func valid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < PlanetGenerator.ATLAS_W and c.y >= 0 and c.y < PlanetGenerator.ATLAS_H

func setup(seed: int, position: Vector2i, starting_world: SimWorld) -> void:
	master_seed = seed
	home = position
	active = position
	regions[key(position)] = starting_world

func _new_world(c: Vector2i, player_ai: bool) -> SimWorld:
	var ll: Vector2 = PlanetGenerator.region_center(c.x, c.y)
	var generator := PlanetGenerator.new(master_seed)
	var s: int = generator.region_seed(ll.x, ll.y)
	var w := SimWorld.new()
	w.setup(s, {"campaign": true, "sector": "val", "planet_j9": true,
		"planet_region_grid": true, "planet_origin": false,
		"planet_master_seed": master_seed, "planet_lon": ll.x, "planet_lat": ll.y,
		"region_x": c.x, "region_y": c.y, "map_size": (regions[key(home)] as SimWorld).map_size})
	w.teams[0].ai_controlled = player_ai
	w.teams[1].ai_controlled = true
	w.update_fog(true)
	return w

func obtain(c: Vector2i, player_ai: bool = false) -> SimWorld:
	if not valid(c):
		return null
	var k: String = key(c)
	if not regions.has(k):
		regions[k] = _new_world(c, player_ai)
	return regions[k] as SimWorld

func _has_persistent_content(w: SimWorld) -> bool:
	if not w.units.is_empty() or not w.buildings.is_empty() or not w.orbital_scans.is_empty():
		return true
	for team in 2:
		if not (w.teams[team] as SimWorld.Team).memory.is_empty():
			return true
		for cell_value in (w.teams[team] as SimWorld.Team).fog:
			if int(cell_value) != 0:
				return true
	for n in w.nodes.values():
		if n.amount != n.max_amount:
			return true
	return false

func _prune_empty() -> void:
	# Une région vierge n'a aucun événement ni économie à simuler.
	# Retirer sa simulation du cache ne détruit pas le terrain : il est pur par seed.
	var required: Dictionary = {key(active): true}
	for order in crossings:
		required[String(order["region"])] = true
	for k in regions.keys():
		if required.has(k):
			continue
		var w: SimWorld = regions[k]
		if not _has_persistent_content(w):
			regions.erase(k)

func visit(c: Vector2i, campaign) -> bool:
	if not valid(c) or not bool((campaign.worlds["val"] as SimWorld).rules.get("planet_j9", false)):
		return false
	var w: SimWorld = obtain(c, bool((campaign.worlds["val"] as SimWorld).teams[0].ai_controlled))
	if w == null:
		return false
	active = c
	campaign.worlds["val"] = w
	campaign._sync_all()
	_prune_empty()
	return true

func _edge_cells(w: SimWorld, destination: SimWorld, u: SimWorld.Unit, direction: Vector2i) -> Dictionary:
	var preferred: int = clampi(int(round(u.pos.y if direction.x != 0 else u.pos.x)), 1, w.map_size - 2)
	for distance in w.map_size:
		for sign_value in [-1, 1]:
			var index: int = preferred + distance * sign_value
			if index < 1 or index >= w.map_size - 1:
				continue
			var source_cell := Vector2i(w.map_size - 1 if direction.x > 0 else 0, index) if direction.x != 0 else Vector2i(index, w.map_size - 1 if direction.y > 0 else 0)
			var target_cell := Vector2i(0 if direction.x > 0 else w.map_size - 1, index) if direction.x != 0 else Vector2i(index, 0 if direction.y > 0 else w.map_size - 1)
			if w.walkable(source_cell) and destination.walkable(target_cell):
				var source_pos: Vector2 = Vector2(source_cell) + Vector2(0.5, 0.5)
				if w.find_path(u.pos, source_pos).is_empty() and w.cell_of(u.pos) != source_cell:
					continue
				return {"source": source_pos, "destination": Vector2(target_cell) + Vector2(0.5, 0.5)}
	return {}

func order_cross(campaign, team: int, unit_ids: Array, direction: Vector2i) -> Dictionary:
	if direction not in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		return {"ok": false, "reason": "direction invalide"}
	if team < 0 or team > 1 or unit_ids.is_empty() or unit_ids.size() > 32:
		return {"ok": false, "reason": "sélection invalide (1 à 32 unités)"}
	if campaign.active != "val":
		return {"ok": false, "reason": "ouvrir d’abord la planète principale"}
	var destination_coord: Vector2i = neighbor(active, direction)
	if not valid(destination_coord):
		return {"ok": false, "reason": "pôle de la planète atteint"}
	var source: SimWorld = campaign.worlds["val"]
	var destination: SimWorld = obtain(destination_coord, bool(source.teams[0].ai_controlled))
	var accepted: int = 0
	var unique: Dictionary = {}
	for entry in unit_ids:
		var uid: int = int(entry)
		if unique.has(uid):
			continue
		unique[uid] = true
		var u: SimWorld.Unit = source.units.get(uid) as SimWorld.Unit
		if u == null or u.team != team or u.type == "train":
			continue
		var cells: Dictionary = _edge_cells(source, destination, u, direction)
		if cells.is_empty():
			continue
		var result: Dictionary = source.issue({"t": "move", "team": team, "units": [uid],
			"pos": [(cells["source"] as Vector2).x, (cells["source"] as Vector2).y]})
		if not bool(result.get("ok", false)):
			continue
		# Un seul passage en cours par unité et région d'origine.
		for prev in crossings.duplicate():
			if String(prev["region"]) == key(active) and int(prev["unit"]) == uid:
				crossings.erase(prev)
		crossings.append({"region": key(active), "unit": uid, "team": team, "dir": direction,
			"edge": cells["source"], "landing": cells["destination"], "dest": destination_coord})
		accepted += 1
	if accepted == 0:
		_prune_empty()
		return {"ok": false, "reason": "aucun passage terrestre praticable vers cette région"}
	return {"ok": true, "accepted": accepted, "target": destination_coord}

func _move_unit(source: SimWorld, destination: SimWorld, u: SimWorld.Unit, landing: Vector2) -> int:
	# Le navire/engin et sa cargaison ne sont pas concernés par cette transition terrestre.
	var data: Dictionary = SaveGame.fields(u)
	if u.planet_uid <= 0:
		u.planet_uid = next_identity
		next_identity += 1
		data["planet_uid"] = u.planet_uid
	source.transfer_out_unit(u)
	var arrived: SimWorld.Unit = destination.spawn_unit(u.team, u.type, landing)
	var new_id: int = arrived.id
	SaveGame.restore(arrived, data)
	# Le producteur appartient à l’ancienne région : éviter toute collision d’ID de bâtiment.
	# L’équipement et les PV restent conservés dans l’unité.
	arrived.origin_building = -1
	arrived.id = new_id # identité tactique locale réservée par destination.new_id()
	arrived.pos = landing
	arrived.prev_pos = landing
	arrived.path = PackedVector2Array()
	arrived.path_goal = Vector2(-999, -999)
	arrived.path_failed = false
	arrived.target_id = -1
	arrived.squad_id = -1
	arrived.build_id = -1
	arrived.node_id = -1
	arrived.goal_key = -1
	arrived.direct = true
	arrived.task = ""
	arrived.order = {"type": "hold", "pos": landing}
	destination.update_fog(true)
	return new_id

func step_background(campaign) -> void:
	last_arrivals.clear()
	# Pas de raccourci de tick : régions habitées, combats et constructions continuent.
	var region_keys: Array = regions.keys()
	region_keys.sort()
	for k in region_keys:
		if k == key(active):
			continue
		var w: SimWorld = regions[k]
		for t in 2:
			(w.teams[t] as SimWorld.Team).res = campaign.resources[t]
			(w.teams[t] as SimWorld.Team).age = campaign.ages[t]
			(w.teams[t] as SimWorld.Team).technologies = campaign.technologies[t]
			(w.teams[t] as SimWorld.Team).eliminated = campaign.eliminated[t]
		w.step()
		for event in w.events:
			if String(event.get("type", "")) in OFFSCREEN_ALERTS:
				var owner: int = int(event.get("team", -1))
				if owner >= 0 and owner < 2:
					campaign._record_notice(owner, "[Planète %s] %s" % [String(k), String(event.get("text", "Alerte"))], "val", String(k))
		w.events.clear()
		if campaign.tick % 100 == 0 and w.event_log.size() > 2000:
			w.event_log = w.event_log.slice(-2000)
		for team in 2:
			campaign.ages[team] = maxi(int(campaign.ages[team]), int((w.teams[team] as SimWorld.Team).age))
			campaign.technologies[team].merge((w.teams[team] as SimWorld.Team).technologies, true)
	# Transferts seulement APRÈS le tick, jamais dans une itération d'unités.
	for ticket in crossings.duplicate():
		var source: SimWorld = regions.get(String(ticket["region"])) as SimWorld
		if source == null:
			crossings.erase(ticket)
			continue
		var unit: SimWorld.Unit = source.units.get(int(ticket["unit"])) as SimWorld.Unit
		if unit == null or unit.team != int(ticket["team"]):
			crossings.erase(ticket)
			continue
		if unit.pos.distance_to(ticket["edge"] as Vector2) > 0.78:
			continue
		var coord: Vector2i = ticket["dest"]
		var dest: SimWorld = obtain(coord, bool((source.teams[0] as SimWorld.Team).ai_controlled))
		var landing: Vector2 = ticket["landing"]
		if not dest.walkable(dest.cell_of(landing)):
			continue
		var new_id: int = _move_unit(source, dest, unit, landing)
		crossings.erase(ticket)
		last_arrivals.append({"from": ticket["region"], "to": key(coord), "id": new_id, "identity": (dest.units[new_id] as SimWorld.Unit).planet_uid, "team": int(ticket["team"])})
		if int(ticket["team"]) == 0 and key(active) == String(ticket["region"]) and campaign.active == "val":
			visit(coord, campaign)
			campaign._record_notice(0, "Frontière franchie : région %s" % key(coord), "val")
	if campaign.tick % 30 == 0:
		_prune_empty()

func worlds_in_play() -> Array:
	var result: Array = []
	for k in regions.keys():
		result.append(regions[k])
	return result

func snapshot() -> Dictionary:
	var maps: Dictionary = {}
	for k in regions.keys():
		if k != key(active):
			maps[k] = SaveGame.snapshot(regions[k] as SimWorld)
	return {"version": FORMAT, "seed": master_seed, "home": home, "active": active,
		"maps": maps, "crossings": crossings.duplicate(true), "next_identity": next_identity}

static func restore(data: Dictionary, current: SimWorld) -> PlanetRegions:
	if int(data.get("version", -1)) != FORMAT or not data.get("home") is Vector2i or not data.get("active") is Vector2i:
		return null
	var restored := PlanetRegions.new()
	restored.master_seed = int(data.get("seed", 0))
	restored.home = data["home"]
	restored.active = data["active"]
	if restored.master_seed <= 0 or not valid(restored.home) or not valid(restored.active):
		return null
	if bool(current.rules.get("planet_region_grid", false)):
		if int(current.rules.get("region_x", -1)) != restored.active.x or int(current.rules.get("region_y", -1)) != restored.active.y:
			return null
	var maps: Variant = data.get("maps", {})
	if not maps is Dictionary or maps.size() > MAX_SAVE_REGIONS:
		return null
	restored.regions[key(restored.active)] = current
	for raw_key in maps.keys():
		var parts: PackedStringArray = String(raw_key).split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return null
		var coord: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		if not valid(coord) or key(coord) != String(raw_key) or String(raw_key) == key(restored.active):
			return null
		var world_state: Variant = maps[raw_key]
		if not world_state is Dictionary:
			return null
		var w: SimWorld = SaveGame.from_snapshot(world_state)
		if w == null or int(w.rules.get("region_x", -1)) != coord.x or int(w.rules.get("region_y", -1)) != coord.y:
			return null
		restored.regions[String(raw_key)] = w
	var crossings_data: Variant = data.get("crossings", [])
	if not crossings_data is Array or crossings_data.size() > 256:
		return null
	for record in crossings_data:
		if not record is Dictionary or not record.get("dest") is Vector2i or not record.get("dir") is Vector2i or not record.get("edge") is Vector2 or not record.get("landing") is Vector2:
			return null
		if not restored.regions.has(String(record.get("region", ""))) or not valid(record["dest"]):
			return null
		if int(record.get("unit", -1)) < 1 or int(record.get("team", -1)) not in [0,1]:
			return null
		restored.crossings.append(record.duplicate(true))
	restored.next_identity = maxi(1, int(data.get("next_identity", 1)))
	return restored
