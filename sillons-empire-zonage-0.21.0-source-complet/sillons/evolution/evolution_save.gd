class_name EvolutionSave
extends RefCounted
const VERSION: int = 2
const FIELDS := ["active", "tick", "resources", "ages", "technologies", "satellites", "sat_cooldown", "scan_cooldown", "flights", "next_flight", "eliminated", "lost_centers_at", "game_over", "winner", "notices", "discovered_systems", "survey_probes", "next_probe_id", "system_stocks", "freight_orders", "next_freight_id", "directives", "orbital_sites", "orbital_presence", "orbital_flights", "next_orbital_flight", "orbital_initial_granted", "homes", "raw_stocks", "treaties", "reinforcements", "command_log", "orbital_tactics", "orbital_maps", "next_orbit_actor", "civ_states"]
static func snapshot(c: StarCampaign) -> Dictionary:
	if c.orbital_tactics: OrbitalTactics.reconcile(c)
	var state: Dictionary = {}
	for field in FIELDS: state[field] = c.get(field)
	var maps: Dictionary = {}
	var ids: Array = c.worlds.keys()
	ids.sort()
	for id in ids: maps[id] = SaveGame.snapshot(c.worlds[id])
	return {"version": VERSION, "evolutions": true, "seed": c._initial_seed, "factions": c.factions.snapshot(), "state": state.duplicate(true), "maps": maps, "planets": SaveGame.fields(c.planets).duplicate(true)}
static func _plain(value: Variant, depth: int = 0) -> bool:
	if depth > 28 or value is Object: return false
	if value is float: return is_finite(value)
	if value is Vector2: return value.is_finite()
	if value is Array:
		if value.size() > 50000: return false
		for item in value:
			if not _plain(item, depth + 1): return false
	elif value is Dictionary:
		if value.size() > 30000: return false
		for key in value:
			if not (key is String or key is int or key is Vector2i): return false
			if not _plain(value[key], depth + 1): return false
	return true
static func from_snapshot(data: Dictionary) -> StarCampaign:
	if int(data.get("version", -1)) != VERSION or not bool(data.get("evolutions", false)) or not _plain(data): return null
	for field in ["factions", "state", "maps", "planets"]:
		if not data.get(field) is Dictionary: return null
	var registry: FactionRegistry = FactionRegistry.from_snapshot(data["factions"])
	if registry == null: return null
	var seed: int = int(data.get("seed", 0))
	if seed <= 0: return null
	var state: Dictionary = data["state"].duplicate(true)
	var orbit_migration:bool=not state.has("orbital_maps")
	# 0.14 -> 0.15 : positions initialisées depuis les inventaires existants, sans dotation.
	if not state.has("orbital_tactics"): state["orbital_tactics"] = true
	if not state.has("orbital_maps"): state["orbital_maps"] = {}
	if not state.has("next_orbit_actor"): state["next_orbit_actor"] = 1
	# 0.15 -> 0.16 : aucune évolution de civilisation dans les anciennes parties.
	if not state.has("civ_states"): state["civ_states"] = {}
	if not state["civ_states"] is Dictionary or state["civ_states"].size() > 16: return null
	for actor_key in state["civ_states"]:
		if not actor_key is int or not registry.records.has(int(actor_key)) or not state["civ_states"][actor_key] is Dictionary: return null
	if not state["orbital_tactics"] is bool or not state["orbital_maps"] is Dictionary or not state["next_orbit_actor"] is int:return null
	for field in FIELDS:
		if not state.has(field): return null
	var team_count: int = int(registry.actors().max()) + 1
	for field in ["resources", "ages", "technologies", "satellites", "sat_cooldown", "scan_cooldown", "eliminated", "lost_centers_at", "discovered_systems", "orbital_initial_granted"]:
		if not state[field] is Array or state[field].size() != team_count: return null
	for field in ["raw_stocks", "homes", "orbital_sites", "orbital_presence", "directives", "system_stocks"]:
		if not state[field] is Dictionary: return null
	for field in ["flights", "orbital_flights", "freight_orders", "survey_probes", "treaties", "reinforcements", "command_log", "notices"]:
		if not state[field] is Array or state[field].size() > 4096: return null
	var catalog := StarSystemGenerator.new(seed)
	if not data["maps"].has(state["active"]) or data["maps"].size() > StarSystemGenerator.MAX_BODIES: return null
	if not state["tick"] is int or int(state["tick"]) < 0: return null
	for actor in registry.actors():
		if not state["ages"][actor] is int or int(state["ages"][actor]) not in range(1, 11): return null
		if not state["discovered_systems"][actor] is Dictionary or not state["technologies"][actor] is Dictionary: return null
		for system_id in state["discovered_systems"][actor]:
			if not catalog.galaxy.systems.has(system_id): return null
	for id in state["raw_stocks"]:
		var parts: PackedStringArray = String(id).split(":", true, 1)
		if parts.size() != 2 or not parts[0].is_valid_int() or not registry.records.has(int(parts[0])): return null
		if not state["raw_stocks"][id] is Dictionary: return null
		for res in Rules.RESOURCES:
			var amount: Variant = state["raw_stocks"][id].get(res)
			if not (amount is int or amount is float) or float(amount) < 0 or float(amount) > 1.0e12: return null
	var pc: Dictionary = data["planets"]
	if not pc.get("colonies") is Dictionary or not pc.get("treasury") is Array or pc["treasury"].size() != team_count: return null
	for id in pc["colonies"]:
		var p: Variant = pc["colonies"][id]
		if not p is Dictionary: return null
		for field in ["team", "body", "local_age", "cells", "stocks", "reserve", "politics", "status", "governor", "pop", "research", "reserved", "stats"]:
			if not p.has(field): return null
		var team: int = int(p["team"])
		if not registry.actors().has(team) or String(id) != PlanetCampaign.key(team, String(p["body"])) or not data["maps"].has(p["body"]): return null
		if int(p["local_age"]) < 1 or int(p["local_age"]) > 10 or int(p["pop"]) < 0 or float(p["reserve"]) < 0: return null
		if not p["politics"] is Dictionary or String(p["politics"].get("stage", "")) not in PoliticalState.STAGES: return null
		for measure in ["wellbeing", "loyalty"]:
			if not p["politics"].has(measure) or float(p["politics"][measure]) < 0 or float(p["politics"][measure]) > 100: return null
	var c := StarCampaign.new()
	c.evolutions_enabled = true
	c._initial_seed = seed
	c.star_catalog = catalog
	c.factions = registry
	for field in FIELDS: c.set(field, state[field].duplicate(true) if state[field] is Dictionary or state[field] is Array else state[field])
	SaveGame.restore(c.planets, pc.duplicate(true))
	for id in data["maps"]:
		if not catalog.has_body(String(id)) or not data["maps"][id] is Dictionary: return null
		var saved: Dictionary = data["maps"][id]
		if not validate_world(saved, registry): return null
		var w: SimWorld = SaveGame.from_snapshot(saved)
		if w == null or w.tick != c.tick: return null
		w.factions = registry
		c.worlds[id] = w
	for actor in registry.actors():
		if not c.planets.books_balanced(int(actor)): return null
	for field in ["flights", "orbital_flights", "freight_orders", "survey_probes"]:
		var seen: Dictionary = {}
		for item in c.get(field):
			if not item is Dictionary or not registry.actors().has(int(item.get("team", -1))) or int(item.get("eta", -1)) < 0: return null
			if int(item.get("id", -1)) < 1 or seen.has(item["id"]): return null
			seen[item["id"]] = true
	for treaty in c.treaties:
		if not treaty is Dictionary or not registry.actors().has(int(treaty.get("team", -1))) or not registry.actors().has(int(treaty.get("target", -1))) or not c.worlds.has(treaty.get("body", "")): return null
	for actor_key in c.civ_states: CivEvolution.sanitize(c.civ_states[actor_key])
	if orbit_migration:OrbitalTactics.reconcile(c)
	if not OrbitalTactics.validate(c): return null
	c._sync_all()
	return c
static func validate_world(saved: Dictionary, registry: FactionRegistry) -> bool:
	if not saved.get("rules") is Dictionary or not saved.get("entities") is Dictionary or not saved.get("teams") is Array: return false
	var n: int = int(saved["rules"].get("map_size", 0))
	if n not in WorldLayout.PROFILES or saved["teams"].size() != registry.records.size(): return false
	var ids: Dictionary = {}
	var maximum: int = 0
	for kind in ["units", "buildings", "nodes", "squads"]:
		if not saved["entities"].get(kind) is Array: return false
		for entry in saved["entities"][kind]:
			if not entry is Dictionary: return false
			var id: int = int(entry.get("id", -1))
			if id < 1 or ids.has(id): return false
			maximum = maxi(maximum, id)
			ids[id] = true
			if kind != "nodes" and not registry.records.has(int(entry.get("team", -1))): return false
			if kind == "units":
				if not entry.get("pos") is Vector2 or not entry["pos"].is_finite() or entry["pos"].x < 0 or entry["pos"].y < 0 or entry["pos"].x >= n or entry["pos"].y >= n: return false
			if kind in ["units", "buildings"] and float(entry.get("hp", -1)) <= 0.0: return false
	for i in saved["teams"].size():
		if not saved["teams"][i] is Dictionary or int(saved["teams"][i].get("id", -1)) != i or not saved["teams"][i].get("fog") is PackedByteArray or saved["teams"][i]["fog"].size() != n * n: return false
	return int(saved.get("next_id", -1)) > maximum
