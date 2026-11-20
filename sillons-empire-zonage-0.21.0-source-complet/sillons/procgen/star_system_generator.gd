class_name StarSystemGenerator
extends RefCounted
## J10 : catalogue astronomique déterministe par graine.
## Données pures (pas de Node ni de dépendance au framerate).
## Les distances sont des unités de jeu, et non des unités astronomiques réelles.
const VERSION: int = 2
const MAX_BODIES: int = 128
const SYSTEM_IDS := ["sol", "proxima"]
const SYLLABLES := ["Aster", "Céleste", "Orion", "Kepler", "Boréal", "Tessera", "Hélios", "Nacre"]

var galaxy: GalaxyGenerator
var master_seed: int = 1
var systems: Dictionary = {}
var bodies: Dictionary = {}
var ordered: Array = []

func _init(seed: int = 1) -> void:
	master_seed = maxi(1, seed)
	galaxy = GalaxyGenerator.new(master_seed)
	_generate()

func _add_body(key: String, label: String, system_id: String, kind: String, parent: String,
		orbit: float, phase: float, size: float, seed: int, age: int) -> void:
	var data: Dictionary = {"id": key, "label": label, "system_id": system_id,
		"system": String(systems[system_id]["label"]), "kind": kind, "parent": parent,
		"orbit": orbit, "phase": phase, "size": size, "seed": seed, "age": age}
	bodies[key] = data
	ordered.append(key)

func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = master_seed
	systems = {
		"sol": {"id": "sol", "label": "Sol", "color": Color(1.0, 0.78, 0.43), "seed": master_seed},
		"proxima": {"id": "proxima", "label": "Proxima", "color": Color(1.0, 0.49, 0.35), "seed": master_seed + 100003}
	}
	# Les trois mondes historiques restent aux mêmes adresses logiques.
	_add_body("val", "Val des Deux Gués", "sol", "planet", "", 18.0, 0.17, 2.1, master_seed, 1)
	_add_body("aurore", "Aurore", "sol", "planet", "", 33.0, 2.25, 1.6, master_seed + 100003, 9)
	_add_body("nemesis", "Némésis", "proxima", "planet", "", 25.0, 0.88, 1.8, master_seed + 200006, 10)
	for sys_id in SYSTEM_IDS:
		var age: int = 9 if sys_id == "sol" else 10
		var prefix: String = "sol" if sys_id == "sol" else "prox"
		for index in 2:
			var body_id: String = "%s_p%d" % [prefix, index]
			var title: String = "%s %s-%d" % [String(SYLLABLES[rng.randi_range(0, SYLLABLES.size()-1)]), String(systems[sys_id]["label"]), index + 1]
			var orbit: float = (47.0 + float(index) * 14.0) if sys_id == "sol" else (41.0 + float(index) * 15.0)
			var phase: float = rng.randf_range(0.0, TAU)
			var scale: float = rng.randf_range(1.1, 2.4)
			var body_seed: int = int(rng.randi_range(1, 2000000000))
			_add_body(body_id, title, sys_id, "planet", "", orbit, phase, scale, body_seed, age)
			if index == (0 if sys_id == "sol" else 1):
				var moon_id: String = body_id + "_m0"
				_add_body(moon_id, "Lune de " + title, sys_id, "moon", body_id,
					5.8 + rng.randf_range(0.0, 1.8), rng.randf_range(0.0, TAU), 0.64,
					int(rng.randi_range(1, 2000000000)), age)

	# J11 : un ensemble borné de systèmes additionnels dérivés de la même seed.
	# Généré APRÈS Sol/Proxima : leurs IDs et orbites J10 ne changent pas.
	var galaxy_keys: Array = galaxy.systems.keys()
	galaxy_keys.sort()
	for system_id in galaxy_keys:
		if SYSTEM_IDS.has(String(system_id)):
			continue
		var node: Dictionary = galaxy.systems[system_id]
		systems[system_id] = {"id": system_id, "label": String(node["label"]),
			"color": node["color"], "seed": int(node["seed"])}
		var sys_rng := RandomNumberGenerator.new()
		sys_rng.seed = int(node["seed"])
		var count: int = sys_rng.randi_range(2, 3)
		for index in count:
			var body_id: String = "%s_p%d" % [String(system_id), index]
			var orbit: float = 21.0 + 15.0 * float(index) + sys_rng.randf_range(-2.0, 2.0)
			var body_seed: int = sys_rng.randi_range(1, 2000000000)
			_add_body(body_id, "%s-%d" % [String(node["label"]), index + 1], String(system_id),
				"planet", "", orbit, sys_rng.randf_range(0.0, TAU),
				sys_rng.randf_range(1.15, 2.25), body_seed, 10)
			if index == 0 and sys_rng.randf() < 0.55:
				_add_body(body_id + "_m0", "Lune " + String(node["label"]), String(system_id),
					"moon", body_id, 6.2, sys_rng.randf_range(0.0, TAU), 0.65,
					sys_rng.randi_range(1, 2000000000), 10)

func has_body(body_id: String) -> bool:
	return bodies.has(body_id)

func info(body_id: String) -> Dictionary:
	return (bodies.get(body_id, {}) as Dictionary).duplicate(true)

func sector_keys() -> Array:
	return ordered.duplicate()

func extra_ids() -> Array:
	var result: Array = []
	for body_id in ordered:
		if not ["val", "aurore", "nemesis"].has(String(body_id)):
			result.append(body_id)
	return result

func bodies_for_system(system_id: String, include_moons: bool = false) -> Array:
	var result: Array = []
	for key in ordered:
		var d: Dictionary = bodies[key]
		if String(d["system_id"]) == system_id and (include_moons or d["kind"] == "planet"):
			result.append(d.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["orbit"]) < float(b["orbit"]))
	return result

func orbit_for(body_id: String) -> Array:
	var result: Array = []
	for key in ordered:
		var d: Dictionary = bodies[key]
		if String(key) == body_id or String(d["parent"]) == body_id:
			result.append(d.duplicate(true))
	return result

func body_position(body_id: String, ticks: int) -> Vector2:
	var d: Dictionary = bodies.get(body_id, {}) as Dictionary
	if d.is_empty():
		return Vector2.ZERO
	var a: float = float(d["phase"]) + float(ticks) * 0.000035 / sqrt(maxf(1.0, float(d["orbit"]) / 20.0))
	var offset := Vector2(cos(a), sin(a)) * float(d["orbit"])
	if String(d["parent"]) != "":
		return body_position(String(d["parent"]), ticks) + offset
	return offset

func signature() -> String:
	var values := PackedStringArray([str(VERSION), str(master_seed)])
	for key in ordered:
		values.append(var_to_str(bodies[key]))
	return "|".join(values).sha256_text()
