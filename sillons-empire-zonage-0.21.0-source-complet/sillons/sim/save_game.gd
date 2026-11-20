class_name SaveGame
extends RefCounted
## Instantané binaire sans objets exécutables. Version stricte + SHA-256 + remplacement atomique.
const PATH := "user://sillons-j345.save"
const VERSION := 1
const LIMIT := 33554432

static func fields(object: Object) -> Dictionary:
	var out: Dictionary = {}
	for prop in object.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = object.get(prop["name"])
			if typeof(value) != TYPE_OBJECT:
				out[String(prop["name"])] = value
	return out

static func restore(object: Object, data: Dictionary) -> void:
	for prop in object.get_property_list():
		var key: String = String(prop["name"])
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and data.has(key) and typeof(object.get(key)) != TYPE_OBJECT:
			object.set(key, data[key])

static func snapshot(w: SimWorld) -> Dictionary:
	var entities: Dictionary = {}
	for key in ["units", "buildings", "nodes", "squads"]:
		var entries: Array = []
		for entity in w.get(key).values():
			entries.append(fields(entity))
		entities[key] = entries
	var team_data: Array = []
	for t in w.teams:
		team_data.append(fields(t))
	var ai_data: Array = []
	for ai in w.ai_controllers:
		ai_data.append(fields(ai))
	# J13-0 : copie profonde. Sans elle, l'instantané partageait ses tableaux (chemins,
	# files, statistiques) avec la partie vivante : une reprise en mémoire divergeait.
	return ({"version": VERSION, "seed": w.seed_value, "tick": w.tick, "rng_state": w.rng.state,
		"rules": w.rules, "terrain": w.terrain, "next_id": w.next_id, "modern": w.modern,
		"orbital_scans": w.orbital_scans, "factions_v2": w.factions.snapshot(),
		"army_plans": w.army_plans, "next_plan_id": w.next_plan_id, "rally_notices": w.rally_notices,
		"entities": entities, "teams": team_data, "ai": ai_data, "replay": w.replay,
		"winner": w.winner, "game_over": w.game_over} as Dictionary).duplicate(true)

static func save(w: SimWorld, path: String = PATH) -> Error:
	var payload: PackedByteArray = var_to_bytes(snapshot(w))
	if payload.size() > LIMIT:
		return ERR_OUT_OF_MEMORY
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(hash.finish())
	file.store_buffer(payload)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return error
	if FileAccess.file_exists(path):
		var backup_error: Error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return backup_error
	return DirAccess.rename_absolute(path + ".tmp", path)

static func load_world(path: String = PATH) -> SimWorld:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 33 or file.get_length() > LIMIT + 32:
		return null
	var checksum: PackedByteArray = file.get_buffer(32)
	var payload: PackedByteArray = file.get_buffer(file.get_length() - 32)
	file.close()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	if hash.finish() != checksum:
		return null
	var value = bytes_to_var(payload)
	if not value is Dictionary:
		return null
	return from_snapshot(value)

static func from_snapshot(data: Dictionary) -> SimWorld:
	if int(data.get("version", -1)) != VERSION or not data.get("entities") is Dictionary:
		return null
	# J13-0 : le monde restauré ne doit partager aucun conteneur avec l'instantané.
	data = data.duplicate(true)
	var layout: int = int((data.get("rules", {}) as Dictionary).get("map_size", 96))
	if not WorldLayout.PROFILES.has(layout): return null
	if not data.get("terrain") is PackedByteArray or data["terrain"].size() != layout * layout:
		return null
	if not data.get("teams") is Array or (data["teams"].size() < 3 or data["teams"].size() > 512):
		return null
	var entities: Dictionary = data["entities"]
	for kind in ["units", "buildings", "nodes", "squads"]:
		if not entities.get(kind) is Array or entities[kind].size() > 20000:
			return null
		for record in entities[kind]:
			if not record is Dictionary or int(record.get("id", -1)) < 1:
				return null
			if kind in ["units", "buildings"]:
				if int(record.get("team", -1)) < 0 or int(record["team"]) >= (data["teams"] as Array).size():
					return null
				var definitions: Dictionary = Rules.UNITS if kind == "units" else Rules.BUILDINGS
				if not definitions.has(record.get("type", "")):
					return null
				if kind == "units":
					if record.has("evolution") and (not record["evolution"] is int or int(record["evolution"]) not in [1, 2, 3]):
						return null
					if record.has("origin_building") and not record["origin_building"] is int:
						return null
				elif record.has("tier") and (not record["tier"] is int or int(record["tier"]) not in [1, 2, 3]):
					return null
				if kind == "buildings" and record.has("unit_evolutions"):
					if not record["unit_evolutions"] is Dictionary:
						return null
					var valid_types: Array = definitions[String(record["type"])].get("trains", []) as Array
					for unit_kind in (record["unit_evolutions"] as Dictionary).keys():
						var level: Variant = record["unit_evolutions"][unit_kind]
						if not unit_kind is String or not valid_types.has(unit_kind) or not level is int or int(level) not in [1, 2, 3]:
							return null
				if kind == "buildings" and record.has("upgrade_job"):
					if not record["upgrade_job"] is Dictionary:
						return null
					var job: Dictionary = record["upgrade_job"] as Dictionary
					if not job.is_empty():
						if job.get("mode", "") not in ["building", "troop"] or not job.get("target") is int or int(job["target"]) not in [2, 3]:
							return null
						var remaining: Variant = job.get("remaining", -1)
						if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or float(remaining) < 0.0 or float(remaining) > 180.0:
							return null
						if job["mode"] == "troop" and not (definitions[String(record["type"])].get("trains", []) as Array).has(String(job.get("unit", ""))):
							return null
	var w := SimWorld.new()
	w.setup(int(data["seed"]), data["rules"])
	w.units.clear()
	w.buildings.clear()
	w.nodes.clear()
	w.squads.clear()
	w._occupied.clear()
	w._node_cells.clear()
	for i in w.terrain.size():
		w.set_terrain(Vector2i(i % w.map_size, i / w.map_size), int(data["terrain"][i]))
	for kind in ["units", "buildings", "nodes", "squads"]:
		for record in entities[kind]:
			var entity: RefCounted
			match kind:
				"units": entity = SimWorld.Unit.new()
				"buildings": entity = SimWorld.Building.new()
				"nodes": entity = SimWorld.ResNode.new()
				_: entity = SimWorld.Squad.new()
			restore(entity, record)
			w.get(kind)[int(record["id"])] = entity
	for b in w.buildings.values():
		for dy in b.size:
			for dx in b.size:
				var cell: Vector2i = b.cell + Vector2i(dx, dy)
				if not w.in_map(cell):
					return null
				w._occupied[cell] = b.id
				w.astar.set_point_solid(cell, true)
	for n in w.nodes.values():
		w._node_cells[n.cell] = n.id
	w.ensure_faction((data["teams"] as Array).size() - 1)
	for i in (data["teams"] as Array).size():
		restore(w.teams[i], data["teams"][i])
	for record in data["ai"]:
		var ai := AiController.new(int(record["team"]))
		restore(ai, record)
		w.ai_controllers.append(ai)
	if data.has("factions_v2"):
		w.factions = FactionRegistry.from_snapshot(data["factions_v2"])
		if w.factions == null: return null
	w.army_plans = (data.get("army_plans", {}) as Dictionary).duplicate(true)
	w.next_plan_id = int(data.get("next_plan_id", 1))
	w.rally_notices = (data.get("rally_notices", {}) as Dictionary).duplicate(true)
	w.tick = int(data["tick"])
	w.next_id = int(data["next_id"])
	w.rng.state = int(data["rng_state"])
	w.modern = data["modern"].duplicate(true)
	w.orbital_scans = (data.get("orbital_scans", []) as Array).duplicate(true)
	w.replay = data["replay"].duplicate(true)
	w.game_over = bool(data["game_over"])
	w.winner = int(data["winner"])
	w.events.clear()
	w.event_log.clear()
	w._rebuild_ugrid()
	return w
