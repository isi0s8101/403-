class_name TerrainChunkStreamer
extends Node3D
## J9-B : streaming incrémental du terrain tactique, sans changer la simulation.
## Maillages par chunks 24x24 ; LOD 1/2/4 ; coutures communes en coordonnées mondiales.
## GPU et scène exclusivement sur le fil principal, quota de création par frame.
const CHUNK_SIZE: int = 24
const MAX_RESIDENT: int = 16
const BUILDS_PER_FRAME: int = 2

var chunk_size: int = CHUNK_SIZE
var world: SimWorld
var _generator: PlanetGenerator
var surface_material: Material
var _resident: Dictionary = {}
var _wanted: Dictionary = {}
var _lod: int = 1
var _clock: int = 0
var _requested_focus: Vector2 = Vector2(48, 48)
var _requested_zoom: float = 24.0
var generated: int = 0
var evicted: int = 0

func setup(p_world: SimWorld, p_material: Material) -> void:
	world = p_world
	chunk_size = 32 if world.map_size > 96 else CHUNK_SIZE
	_generator = PlanetGenerator.new(int(world.rules.get("planet_master_seed", world.seed_value))) if bool(world.rules.get("planet_region_grid", false)) else null
	surface_material = p_material
	update_focus(Vector2(48, 48), 24.0)

func update_focus(focus: Vector2, camera_zoom: float) -> void:
	_requested_focus = focus
	_requested_zoom = camera_zoom
	var target_lod: int = 1 if camera_zoom < 31.0 else (2 if camera_zoom < 57.0 else 4)
	if target_lod != _lod:
		_lod = target_lod
		# On garde les anciens maillages visibles le temps de remplacer le LOD.
	_wanted.clear()
	var radius: float = clampf(camera_zoom * 0.86, 28.0, 87.0)
	for cy in range(ceili(float(world.map_size) / float(chunk_size))):
		for cx in range(ceili(float(world.map_size) / float(chunk_size))):
			var center: Vector2 = Vector2((cx + 0.5) * chunk_size, (cy + 0.5) * chunk_size)
			var key: Vector2i = Vector2i(cx, cy)
			if center.distance_to(focus) < radius + 16.0:
				_wanted[key] = true
	if world.map_size > 96 and _wanted.size() > MAX_RESIDENT:
		var nearest_keys: Array = _wanted.keys()
		nearest_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) + Vector2.ONE * 0.5).distance_squared_to(focus / float(chunk_size)) < (Vector2(b) + Vector2.ONE * 0.5).distance_squared_to(focus / float(chunk_size)))
		for index in range(MAX_RESIDENT, nearest_keys.size()): _wanted.erase(nearest_keys[index])
	for key in _resident.keys():
		var entry: Dictionary = _resident[key]
		var node: MeshInstance3D = entry["node"] as MeshInstance3D
		node.visible = _wanted.has(key)
	_clock += 1
	var pending: Array = []
	for key in _wanted.keys():
		if _resident.has(key) and int((_resident[key] as Dictionary)["lod"]) == _lod:
			(_resident[key] as Dictionary)["last"] = _clock
		else:
			var c: Vector2 = Vector2((key.x + 0.5) * chunk_size, (key.y + 0.5) * chunk_size)
			pending.append([c.distance_squared_to(focus), key])
	pending.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in mini(BUILDS_PER_FRAME, pending.size()):
		var key: Vector2i = pending[i][1]
		if _resident.has(key):
			var old: MeshInstance3D = (_resident[key] as Dictionary)["node"] as MeshInstance3D
			remove_child(old)
			old.queue_free()
			_resident.erase(key)
		var obj := MeshInstance3D.new()
		obj.mesh = _make_mesh(key, _lod)
		obj.material_override = surface_material
		obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(obj)
		_resident[key] = {"node": obj, "lod": _lod, "last": _clock}
		generated += 1
	_evict()

func _evict() -> void:
	if _resident.size() <= MAX_RESIDENT:
		return
	var candidates: Array = []
	for key in _resident.keys():
		if _wanted.has(key):
			continue
		candidates.append([int((_resident[key] as Dictionary)["last"]), key])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for pair in candidates:
		if _resident.size() <= MAX_RESIDENT:
			break
		var key: Vector2i = pair[1]
		var old: MeshInstance3D = (_resident[key] as Dictionary)["node"] as MeshInstance3D
		remove_child(old)
		old.queue_free()
		_resident.erase(key)
		evicted += 1

func _height(vx: int, vy: int) -> float:
	if bool(world.rules.get("planet_region_grid", false)):
		if _generator == null: # J13-0 : utilisable sans setup() (outils, recettes hors rendu)
			_generator = PlanetGenerator.new(int(world.rules.get("planet_master_seed", world.seed_value)))
		return clampf(_generator.region_elevation(int(world.rules.get("region_x", 0)),
			int(world.rules.get("region_y", 0)), float(vx), float(vy), world.map_size) * 2.5, -1.4, 2.2)
	var water: float = 0.0
	var ford: float = 0.0
	for oy in [-1, 0]:
		for ox in [-1, 0]:
			var c: Vector2i = Vector2i(clampi(vx + ox, 0, world.map_size - 1), clampi(vy + oy, 0, world.map_size - 1))
			var t: int = int(world.terrain[world.idx(c)])
			if t == SimWorld.TERRAIN_WATER:
				water += 1.0
			elif t == SimWorld.TERRAIN_FORD:
				ford += 1.0
	return -water * 0.225 - ford * 0.08 + sin(float(vx) * 0.21) * cos(float(vy) * 0.17) * 0.08

func sample_edge_height(x: int, y: int) -> float:
	return _height(x, y)

func _make_mesh(chunk: Vector2i, step: int) -> ArrayMesh:
	var x0: int = chunk.x * chunk_size
	var y0: int = chunk.y * chunk_size
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(y0, mini(world.map_size, y0 + chunk_size), step):
		for x in range(x0, mini(world.map_size, x0 + chunk_size), step):
			for coord in [Vector2i(x, y), Vector2i(x + step, y), Vector2i(x + step, y + step), Vector2i(x, y), Vector2i(x + step, y + step), Vector2i(x, y + step)]:
				var h: float = _height(coord.x, coord.y)
				var grid: bool = bool(world.rules.get("planet_region_grid", false))
				var px: int = coord.x + 1 if grid else clampi(coord.x + 1, 0, world.map_size)
				var nx: int = coord.x - 1 if grid else clampi(coord.x - 1, 0, world.map_size)
				var py: int = coord.y + 1 if grid else clampi(coord.y + 1, 0, world.map_size)
				var ny: int = coord.y - 1 if grid else clampi(coord.y - 1, 0, world.map_size)
				var dx: float = _height(px, coord.y) - _height(nx, coord.y)
				var dz: float = _height(coord.x, py) - _height(coord.x, ny)
				mesh.set_normal(Vector3(-dx, 2.0, -dz).normalized())
				mesh.set_uv(Vector2(coord) * 0.21)
				mesh.add_vertex(Vector3(float(coord.x), h, float(coord.y)))
	mesh.generate_tangents()
	return mesh.commit()

func stats() -> Dictionary:
	return {"visible": _wanted.size(), "resident": _resident.size(), "generated": generated, "evicted": evicted, "lod_step": _lod}
