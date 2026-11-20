class_name CampaignSave
extends RefCounted
## Enveloppe J6-J8 versionnée : sous-instantanés complets SimWorld, sans objets exécutables.
## Un fichier incompatible ou altéré n'est jamais appliqué à la partie active.
const PATH := "user://sillons-j678.save"
const VERSION := 1
const LIMIT := 134217728
static var last_load_source: String = ""
static var last_load_timestamp: String = ""

static func snapshot(c: StarCampaign) -> Dictionary:
	if c.orbital_tactics: OrbitalTactics.reconcile(c)
	if c.evolutions_enabled: return EvolutionSave.snapshot(c)
	var maps: Dictionary = {}
	for key in StarCampaign.SECTORS:
		maps[key] = SaveGame.snapshot(c.worlds[key] as SimWorld)
	var extras: Dictionary = {}
	for key in c.worlds.keys():
		if not StarCampaign.SECTORS.has(String(key)):
			extras[key] = SaveGame.snapshot(c.worlds[key] as SimWorld)
	# J13-0 : instantané immuable (copie profonde), indépendant de la partie vivante.
	var out: Dictionary = {"version": VERSION, "star_catalog_version": StarSystemGenerator.VERSION,
		"extra_maps": extras, "seed": c._initial_seed, "active": c.active, "tick": c.tick,
		"maps": maps, "resources": c.resources, "ages": c.ages,
		"technologies": c.technologies, "satellites": c.satellites,
		"sat_cooldown": c.sat_cooldown, "scan_cooldown": c.scan_cooldown,
		"flights": c.flights, "next_flight": c.next_flight,
		"galaxy_version": GalaxyGenerator.VERSION, "discovered_systems": c.discovered_systems,
		"survey_probes": c.survey_probes, "next_probe_id": c.next_probe_id,
		"eliminated": c.eliminated, "lost_centers_at": c.lost_centers_at,
		"winner": c.winner, "game_over": c.game_over, "notices": c.notices,
		"planet_regions": c.planet_regions.snapshot() if c.planet_regions != null else {},
		"system_stocks": c.system_stocks, "freight_orders": c.freight_orders,
		"next_freight_id": c.next_freight_id, "directives": c.directives,
		"orbital_sites": c.orbital_sites, "orbital_presence": c.orbital_presence,
		"orbital_flights": c.orbital_flights, "next_orbital_flight": c.next_orbital_flight,
		"orbital_initial_granted": c.orbital_initial_granted}
	J13Save.write(c, out)
	if c.orbital_tactics: out["orbital_tactical"] = {"enabled": true, "maps": c.orbital_maps, "next_id": c.next_orbit_actor}
	return out.duplicate(true)

static func save(c: StarCampaign, path: String = PATH) -> Error:
	var payload: PackedByteArray = var_to_bytes(snapshot(c))
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
	var err: Error = file.get_error()
	file.close()
	if err != OK:
		return err
	if FileAccess.file_exists(path) and _load_exact(path) != null:
		# Ne jamais remplacer un backup valide par une sauvegarde principale corrompue.
		var backup_err: Error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_err != OK:
			return backup_err
	return DirAccess.rename_absolute(path + ".tmp", path)

static func load_campaign(path: String = PATH, allow_backup: bool = true) -> StarCampaign:
	last_load_source = ""
	last_load_timestamp = ""
	var primary: StarCampaign = _load_exact(path)
	if primary != null:
		last_load_source = "primary"
		last_load_timestamp = Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(path)))
		return primary
	if allow_backup:
		var backup: StarCampaign = _load_exact(path + ".bak")
		if backup != null:
			last_load_source = "backup"
			last_load_timestamp = Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(path + ".bak")))
			return backup
	return null

static func _load_exact(path: String) -> StarCampaign:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var size: int = file.get_length()
	if size < 33 or size > LIMIT + 32:
		file.close()
		return null
	var digest: PackedByteArray = file.get_buffer(32)
	var payload: PackedByteArray = file.get_buffer(size - 32)
	file.close()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	if hash.finish() != digest:
		return null
	var value = bytes_to_var(payload)
	if not value is Dictionary:
		return null
	return from_snapshot(value)

static func _valid_ratio(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var ratio: float = float(value)
	return is_finite(ratio) and ratio > 0.0 and ratio <= 1.0

static func _valid_supply(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number >= 0.0 and number <= 100.0

static func from_snapshot(data: Dictionary) -> StarCampaign:
	if int(data.get("version", -1)) == 2: return EvolutionSave.from_snapshot(data)
	if int(data.get("version", -1)) != VERSION or not data.get("maps") is Dictionary:
		return null
	var seed: int = int(data.get("seed", 0))
	if seed <= 0:
		return null
	if int(data.get("star_catalog_version", 1)) not in [1, StarSystemGenerator.VERSION]:
		return null
	var catalog := StarSystemGenerator.new(seed)
	if not catalog.has_body(String(data.get("active", ""))):
		return null
	if int(data.get("galaxy_version", GalaxyGenerator.VERSION)) != GalaxyGenerator.VERSION:
		return null
	var discoveries_value: Variant = data.get("discovered_systems", [{"sol": true, "proxima": true}, {"sol": true, "proxima": true}])
	if not discoveries_value is Array or (discoveries_value as Array).size() != 2:
		return null
	var discoveries: Array = discoveries_value as Array
	for team in 2:
		if not discoveries[team] is Dictionary:
			return null
		var known: Dictionary = discoveries[team] as Dictionary
		if known.size() > GalaxyGenerator.MAX_SYSTEMS or not known.has("sol") or not known.has("proxima"):
			return null
		for key in known.keys():
			if not key is String or not catalog.galaxy.systems.has(key) or known[key] != true:
				return null
	var probes_value: Variant = data.get("survey_probes", [])
	if not probes_value is Array or (probes_value as Array).size() > 32:
		return null
	var probe_ids: Dictionary = {}
	var probe_destinations: Dictionary = {}
	for probe_value in probes_value:
		if not probe_value is Dictionary:
			return null
		var probe: Dictionary = probe_value as Dictionary
		for field in ["id", "team", "eta", "duration"]:
			if not probe.get(field) is int:
				return null
		var pid: int = int(probe["id"])
		var team: int = int(probe["team"])
		var from_id: String = String(probe.get("from", ""))
		var to_id: String = String(probe.get("target", ""))
		if pid <= 0 or probe_ids.has(pid) or team not in [0, 1]:
			return null
		if not catalog.galaxy.adjacent(from_id, to_id) or not (discoveries[team] as Dictionary).has(from_id):
			return null
		if (discoveries[team] as Dictionary).has(to_id):
			return null
		var expected: int = StarCampaign.SURVEY_BASE_TICKS + int(round(catalog.galaxy.edge_distance(from_id, to_id) * 3.0))
		if int(probe["duration"]) != expected or int(probe["eta"]) < 1 or int(probe["eta"]) > expected:
			return null
		var target_key: String = "%d:%s" % [team, to_id]
		if probe_destinations.has(target_key):
			return null
		probe_ids[pid] = true
		probe_destinations[target_key] = true
	var next_probe: int = int(data.get("next_probe_id", 1))
	if next_probe < 1 or (not probe_ids.is_empty() and next_probe <= int((probe_ids.keys() as Array).max())):
		return null
	var extras_value: Variant = data.get("extra_maps", {})
	if not extras_value is Dictionary or (extras_value as Dictionary).size() > StarSystemGenerator.MAX_BODIES:
		return null
	var extras: Dictionary = extras_value as Dictionary
	for key in extras.keys():
		if not key is String or StarCampaign.SECTORS.has(key) or not catalog.has_body(key):
			return null
	var maps: Dictionary = data["maps"]
	if maps.size() != StarCampaign.SECTORS.size():
		return null
	for key in ["resources", "ages", "technologies", "satellites", "sat_cooldown", "scan_cooldown", "eliminated", "lost_centers_at"]:
		if not data.get(key) is Array or (data[key] as Array).size() != 2:
			return null
	if not data.get("flights") is Array or (data["flights"] as Array).size() > 256:
		return null
	for team in 2:
		if not data["resources"][team] is Dictionary or not data["technologies"][team] is Dictionary:
			return null
		if int(data["ages"][team]) < 1 or int(data["ages"][team]) > 10:
			return null
		if int(data["satellites"][team]) < 0 or int(data["satellites"][team]) > 3:
			return null
	var ids: Dictionary = {}
	for rec in data["flights"]:
		if not rec is Dictionary:
			return null
		if not rec.get("id") is int or int(rec["id"]) <= 0 or ids.has(int(rec["id"])):
			return null
		ids[int(rec["id"])] = true
		var source: String = String(rec.get("from", ""))
		var target: String = String(rec.get("to", ""))
		if not catalog.has_body(source) or not catalog.has_body(target) or source == target:
			return null
		if (not StarCampaign.SECTORS.has(source) and not extras.has(source)) or (not StarCampaign.SECTORS.has(target) and not extras.has(target)):
			return null
		if not rec.get("team") is int or int(rec["team"]) not in [0, 1]:
			return null
		if not rec.get("eta") is int:
			return null
		var source_system: String = String(catalog.info(source)["system_id"])
		var target_system: String = String(catalog.info(target)["system_id"])
		var interstellar: bool = source_system != target_system
		if not (discoveries[int(rec["team"])] as Dictionary).has(source_system) or not (discoveries[int(rec["team"])] as Dictionary).has(target_system):
			return null
		var duration: int = StarCampaign.expected_flight_duration(catalog, source, target)
		if duration < 0:
			return null
		if rec.has("duration"):
			if not rec["duration"] is int or int(rec["duration"]) != duration:
				return null
		if int(rec["eta"]) < 0 or int(rec["eta"]) > duration:
			return null
		if rec.has("holding") and not rec["holding"] is bool:
			return null
		if not rec.get("colony") is bool or not rec.get("ship") is String:
			return null
		for field in ["planet_to", "planet_from"]:
			if rec.has(field):
				if not rec[field] is Vector2i or not PlanetRegions.valid(rec[field]):
					return null
				if (field == "planet_to" and target != "val") or (field == "planet_from" and source != "val"):
					return null
		var ship: String = String(rec["ship"])
		if ship != ("fregate" if interstellar else "navette"):
			return null
		if not _valid_ratio(rec.get("ship_hp_ratio")):
			return null
		if rec.has("ship_evolution"):
			if not rec["ship_evolution"] is int or int(rec["ship_evolution"]) not in [1, 2, 3]:
				return null
		if not rec.get("units") is Array or (rec["units"] as Array).is_empty() or (rec["units"] as Array).size() > 6:
			return null
		for cargo in rec["units"]:
			if not cargo is Dictionary or not cargo.get("type") is String:
				return null
			if not Rules.UNITS.has(String(cargo["type"])) or Rules.unit_has(String(cargo["type"]), "orbital"):
				return null
			if not _valid_ratio(cargo.get("hp_ratio")) or not _valid_supply(cargo.get("supply")):
				return null
			if cargo.has("evolution"):
				if not cargo["evolution"] is int or int(cargo["evolution"]) not in [1, 2, 3]:
					return null
	# J12 : champs absents des sauvegardes J1–J11 = migration conservatrice.
	var local_stocks_value: Variant = data.get("system_stocks", {})
	if not local_stocks_value is Dictionary:
		return null
	var local_stocks: Dictionary = (local_stocks_value as Dictionary).duplicate(true)
	if local_stocks.size() > GalaxyGenerator.MAX_SYSTEMS:
		return null
	for sys in local_stocks.keys():
		if not sys is String or not catalog.galaxy.systems.has(sys):
			return null
		if not local_stocks[sys] is Array or (local_stocks[sys] as Array).size() != 2:
			return null
		for team in 2:
			var reserve: Variant = (local_stocks[sys] as Array)[team]
			if not reserve is Dictionary or (reserve as Dictionary).size() != 3:
				return null
			for kind in ["food", "wood", "ore"]:
				if not reserve.has(kind) or not (reserve[kind] is int or reserve[kind] is float):
					return null
				if not is_finite(float(reserve[kind])) or float(reserve[kind]) < 0.0 or float(reserve[kind]) > 1e12:
					return null
	if not local_stocks.is_empty():
		if not local_stocks.has("sol") or local_stocks["sol"] != data["resources"]:
			return null
	var freight_value: Variant = data.get("freight_orders", [])
	if not freight_value is Array or (freight_value as Array).size() > StarCampaign.FREIGHT_LIMIT:
		return null
	var freight_ids: Dictionary = {}
	for raw_freight in freight_value:
		if not raw_freight is Dictionary:
			return null
		var freight: Dictionary = raw_freight as Dictionary
		for field in ["id", "team", "hop", "eta"]:
			if not freight.get(field) is int:
				return null
		if int(freight["id"]) <= 0 or freight_ids.has(int(freight["id"])) or int(freight["team"]) not in [0, 1]:
			return null
		freight_ids[int(freight["id"])] = true
		if not freight.get("route") is Array or not freight.get("goods") is Dictionary or not freight.get("holding") is bool:
			return null
		var path: Array = freight["route"] as Array
		if path.size() < 2 or path.size() > GalaxyGenerator.MAX_SYSTEMS or int(freight["hop"]) < 0 or int(freight["hop"]) >= path.size() - 1:
			return null
		if not freight.get("from") is String or not freight.get("to") is String or path[0] != freight["from"] or path.back() != freight["to"]:
			return null
		var visited: Dictionary = {}
		for i in range(path.size()):
			if not path[i] is String or not catalog.galaxy.systems.has(path[i]) or visited.has(path[i]):
				return null
			visited[path[i]] = true
			if not (discoveries[int(freight["team"])] as Dictionary).has(path[i]):
				return null
			if i > 0 and not catalog.galaxy.adjacent(String(path[i - 1]), String(path[i])):
				return null
		var upper: int = 80 + int(round(catalog.galaxy.edge_distance(String(path[int(freight["hop"])]), String(path[int(freight["hop"]) + 1])) * 4.0))
		if int(freight["eta"]) < 0 or int(freight["eta"]) > upper:
			return null
		var request: Dictionary = freight["goods"] as Dictionary
		if request.is_empty() or request.size() > 3:
			return null
		for kind in request.keys():
			if not kind is String or not Rules.RESOURCES.has(kind) or not request[kind] is int:
				return null
			if int(request[kind]) < 1 or int(request[kind]) > StarCampaign.FREIGHT_MAX_UNITS:
				return null
	var following_id: int = int(data.get("next_freight_id", 1))
	if following_id < 1 or (not freight_ids.is_empty() and following_id <= int((freight_ids.keys() as Array).max())):
		return null
	var orders_value: Variant = data.get("directives", {})
	if not orders_value is Dictionary or (orders_value as Dictionary).size() > GalaxyGenerator.MAX_SYSTEMS * 2:
		return null
	for order_key in (orders_value as Dictionary).keys():
		if not order_key is String or not (orders_value as Dictionary)[order_key] is String:
			return null
		var parts: PackedStringArray = String(order_key).split(":")
		if parts.size() != 2 or parts[0] not in ["0", "1"] or not catalog.galaxy.systems.has(parts[1]):
			return null
		if (orders_value as Dictionary)[order_key] not in StarCampaign.ORDER_MODES:
			return null
	# Un état orbital falsifié est refusé avant toute modification des mondes.
	if not OrbitalIndustry.validate_state(catalog, data):
		return null
	var c := StarCampaign.new()
	c.star_catalog = catalog
	for key in StarCampaign.SECTORS:
		if not maps.get(key) is Dictionary:
			return null
		var w: SimWorld = SaveGame.from_snapshot(maps[key])
		if w == null:
			return null
		w.rules["campaign"] = true
		w.rules["sector"] = key
		c.worlds[key] = w
	for key in extras.keys():
		if not extras[key] is Dictionary:
			return null
		var dynamic_world: SimWorld = SaveGame.from_snapshot(extras[key])
		if dynamic_world == null or int(dynamic_world.seed_value) != int(catalog.info(key)["seed"]):
			return null
		dynamic_world.rules["campaign"] = true
		dynamic_world.rules["sector"] = key
		c.worlds[key] = dynamic_world
	if not c.worlds.has(String(data["active"])):
		return null
	c._initial_seed = seed
	c.discovered_systems = discoveries.duplicate(true)
	c.survey_probes = (probes_value as Array).duplicate(true)
	c.next_probe_id = next_probe
	c.active = String(data["active"])
	c.tick = maxi(0, int(data["tick"]))
	c.resources = (data["resources"] as Array).duplicate(true)
	if not local_stocks.is_empty():
		c.system_stocks = local_stocks
		c.resources = c.system_stocks["sol"] as Array
	else:
		# J11 partageait un seul trésor : conservation exacte dans Sol, sans duplication.
		c.system_stocks = {"sol": c.resources}
	c.freight_orders = (freight_value as Array).duplicate(true)
	c.next_freight_id = following_id
	c.directives = (orders_value as Dictionary).duplicate(true)
	c.orbital_sites = (data.get("orbital_sites", {}) as Dictionary).duplicate(true)
	c.orbital_presence = (data.get("orbital_presence", {}) as Dictionary).duplicate(true)
	c.orbital_flights = (data.get("orbital_flights", []) as Array).duplicate(true)
	c.next_orbital_flight = int(data.get("next_orbital_flight", 1))
	c.orbital_initial_granted = (data.get("orbital_initial_granted", [false, false]) as Array).duplicate(true)
	c.ages = (data["ages"] as Array).duplicate(true)
	c.technologies = (data["technologies"] as Array).duplicate(true)
	c.satellites = (data["satellites"] as Array).duplicate(true)
	c.sat_cooldown = (data["sat_cooldown"] as Array).duplicate(true)
	c.scan_cooldown = (data["scan_cooldown"] as Array).duplicate(true)
	c.flights = (data["flights"] as Array).duplicate(true)
	c.next_flight = maxi(1, int(data.get("next_flight", 1)))
	c.eliminated = (data["eliminated"] as Array).duplicate(true)
	c.lost_centers_at = (data["lost_centers_at"] as Array).duplicate(true)
	c.winner = int(data.get("winner", -1))
	c.game_over = bool(data.get("game_over", false))
	c.notices = (data.get("notices", []) as Array).duplicate(true)
	var region_state: Variant = data.get("planet_regions", {})
	if not region_state is Dictionary:
		return null
	if not region_state.is_empty():
		c.planet_regions = PlanetRegions.restore(region_state, c.worlds["val"] as SimWorld)
		if c.planet_regions == null or c.planet_regions.master_seed != c._initial_seed:
			return null
	elif bool((c.worlds["val"] as SimWorld).rules.get("planet_j9", false)):
		# Sauvegarde candidate 0.9.0 : région d'origine conservée sans réécriture.
		c.planet_regions = PlanetRegions.new()
		c.planet_regions.setup(c._initial_seed, PlanetGenerator.region_coords(float((c.worlds["val"] as SimWorld).rules.get("planet_lon", 0.0)), float((c.worlds["val"] as SimWorld).rules.get("planet_lat", 0.0))), c.worlds["val"] as SimWorld)
	# J13 : bloc planétaire validé, ou migration 0.12.3 sans station ni crédit ajoutés.
	if not J13Save.read(c, data):
		return null
	if data.has("orbital_tactical"):
		var tactical: Variant = data["orbital_tactical"]
		if not tactical is Dictionary or not tactical.get("maps") is Dictionary or not tactical.get("enabled") is bool or not tactical.get("next_id") is int or not EvolutionSave._plain(tactical): return null
		c.orbital_tactics = bool(tactical.get("enabled", false))
		c.orbital_maps = tactical["maps"].duplicate(true)
		c.next_orbit_actor = int(tactical.get("next_id", -1))
		if not OrbitalTactics.validate(c): return null
	c._sync_all()
	return c
