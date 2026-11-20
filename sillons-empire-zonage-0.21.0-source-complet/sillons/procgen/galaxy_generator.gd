class_name GalaxyGenerator
extends RefCounted
## J11 : graphe galactique reproductible et connecté, sans scène ni horloge.
## Les coordonnées/durées sont des unités de gameplay, pas des années-lumière.
const VERSION: int = 1
const GENERATED_SYSTEMS: int = 14
const MAX_SYSTEMS: int = 32
const LABELS := ["Altair", "Vega", "Lyra", "Cassiopée", "Arcturus", "Deneb", "Aldébaran", "Sirius", "Eridan", "Orion", "Carina", "Rigel", "Nacre", "Horizon"]
var master_seed: int = 1
var systems: Dictionary = {}
var edges: Array = []
var links: Dictionary = {}

func _init(seed: int = 1) -> void:
	master_seed = maxi(1, seed)
	_generate()

func _register(key: String, label: String, pos: Vector2, value_seed: int, tint: Color) -> void:
	systems[key] = {"id": key, "label": label, "pos": pos, "seed": value_seed, "color": tint}
	links[key] = []

func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func _add_link(a: String, b: String) -> void:
	if a == b or not systems.has(a) or not systems.has(b) or (links[a] as Array).has(b):
		return
	(links[a] as Array).append(b)
	(links[b] as Array).append(a)
	edges.append({"a": a, "b": b, "distance": edge_distance(a, b)})

func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = master_seed ^ 0x4A110B
	_register("sol", "Sol", Vector2(-64.0, -9.0), master_seed, Color(1.0, 0.78, 0.43))
	_register("proxima", "Proxima", Vector2(-47.0, -5.0), master_seed + 100003, Color(1.0, 0.49, 0.35))
	for i in GENERATED_SYSTEMS:
		var pos := Vector2.ZERO
		for attempt in 180:
			pos = Vector2(rng.randf_range(-82.0, 82.0), rng.randf_range(-66.0, 66.0))
			var separated: bool = true
			for key in systems.keys():
				if (systems[key]["pos"] as Vector2).distance_to(pos) < 19.0:
					separated = false
					break
			if separated:
				break
		var key: String = "g%02d" % (i + 1)
		_register(key, "%s %02d" % [LABELS[i % LABELS.size()], i + 1], pos,
			rng.randi_range(1, 2000000000), Color(rng.randf_range(0.48, 0.95), rng.randf_range(0.52, 0.90), 1.0))
	# Arbre couvrant minimum : chaque système a au moins une route accessible.
	var connected: Dictionary = {"sol": true}
	while connected.size() < systems.size():
		var best_a: String = ""
		var best_b: String = ""
		var best: float = INF
		var inside: Array = connected.keys()
		inside.sort()
		var outside: Array = systems.keys()
		outside.sort()
		for a in inside:
			for b in outside:
				if connected.has(b):
					continue
				var distance: float = edge_distance(String(a), String(b))
				if distance < best:
					best = distance
					best_a = String(a)
					best_b = String(b)
		_add_link(best_a, best_b)
		connected[best_b] = true
	# Quelques routes supplémentaires, mais pas de graphe complet irréaliste.
	var keys: Array = systems.keys()
	keys.sort()
	for a in keys:
		var candidates: Array = []
		for b in keys:
			if a == b or (links[a] as Array).has(b):
				continue
			candidates.append({"id": b, "distance": edge_distance(String(a), String(b))})
		candidates.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["distance"]) < float(y["distance"]))
		if not candidates.is_empty() and (links[a] as Array).size() < 3 and float(candidates[0]["distance"]) < 40.0:
			_add_link(String(a), String(candidates[0]["id"]))
	# Une voie d'exploration doit démarrer directement du berceau Sol.
	# La connexion historique Sol-Proxima, à elle seule, ne suffit pas au gameplay J11.
	var generated: Array = systems.keys().filter(func(id: String) -> bool: return id != "sol" and id != "proxima")
	generated.sort_custom(func(x: String, y: String) -> bool: return edge_distance("sol", x) < edge_distance("sol", y))
	if not generated.is_empty() and not (links["sol"] as Array).has(generated[0]):
		_add_link("sol", String(generated[0]))
	for key in links.keys():
		(links[key] as Array).sort()
	edges.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return _pair_key(String(x["a"]), String(x["b"])) < _pair_key(String(y["a"]), String(y["b"])))

func edge_distance(a: String, b: String) -> float:
	if not systems.has(a) or not systems.has(b):
		return INF
	return (systems[a]["pos"] as Vector2).distance_to(systems[b]["pos"] as Vector2)

func adjacent(a: String, b: String) -> bool:
	return systems.has(a) and (links[a] as Array).has(b)

func neighbors(system_id: String) -> Array:
	return (links.get(system_id, []) as Array).duplicate()

func route(a: String, b: String) -> Array:
	## Dijkstra sans dépendance extérieure. Sert aussi à afficher le réseau.
	if not systems.has(a) or not systems.has(b):
		return []
	var distances: Dictionary = {a: 0.0}
	var previous: Dictionary = {}
	var visited: Dictionary = {}
	while true:
		var current: String = ""
		var best: float = INF
		for candidate in distances.keys():
			if not visited.has(candidate) and float(distances[candidate]) < best:
				best = float(distances[candidate])
				current = String(candidate)
		if current.is_empty() or current == b:
			break
		visited[current] = true
		for neighbor in neighbors(current):
			var next_id: String = String(neighbor)
			var tentative: float = best + edge_distance(current, next_id)
			if tentative < float(distances.get(next_id, INF)):
				distances[next_id] = tentative
				previous[next_id] = current
	if not distances.has(b):
		return []
	var result: Array = [b]
	while String(result[0]) != a:
		var before: String = String(previous.get(String(result[0]), ""))
		if before.is_empty():
			return []
		result.push_front(before)
	return result

func signature() -> String:
	var parts := PackedStringArray([str(VERSION), str(master_seed)])
	var keys: Array = systems.keys()
	keys.sort()
	for key in keys:
		parts.append(String(key) + ":" + var_to_str(systems[key]))
	for e in edges:
		parts.append(_pair_key(String(e["a"]), String(e["b"])))
	return "|".join(parts).sha256_text()
