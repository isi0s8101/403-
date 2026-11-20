class_name RealismAssets
extends RefCounted
## Shared photographic PBR and authored geometry. All runtime resources are native; no GLB parsing.
const PACK: String = "res://data/realism_models.pck"
const ROOT: String = "res://realism_native/"
const TEXTURES: String = "res://game/realism/textures/"
const FOLIAGE_SHADER = preload("res://game/realism/foliage.gdshader")
static var _loaded: bool = false
static var _models: Dictionary = {}
static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}
static var _parts: Dictionary = {}
static var _textures: Dictionary = {}

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not ProjectSettings.load_resource_pack(PACK, false):
		push_error("Bibliothèque réalisme absente : extraire l’archive 0.13.5 complète.")
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	if value is Dictionary:
		for raw in (value as Dictionary).get("models", []) as Array:
			var record: Dictionary = raw as Dictionary
			_models[String(record["id"])] = record

static func info(id: String) -> Dictionary:
	_load()
	return _models.get(id, {}) as Dictionary

static func texture(key: String, channel: String = "albedo") -> Texture2D:
	var path: String = TEXTURES + key + "_" + channel + ".jpg"
	if not _textures.has(path) and ResourceLoader.exists(path):
		_textures[path] = load(path) as Texture2D
	return _textures.get(path) as Texture2D

static func material(key: String, team: int = 0) -> StandardMaterial3D:
	var cache_key: String = key + str(team) if key == "team" else key
	if _materials.has(cache_key):
		return _materials[cache_key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.resource_name = "realism_" + key
	m.roughness = 0.85
	var source: String = "stone" if key == "rock" else ("wall" if key == "brick" else key)
	if key in ["stone", "wall", "wood", "roof", "bark", "rock", "soil", "brick"]:
		m.albedo_texture = texture(source)
		if key == "brick":
			m.albedo_color = Color("b77e62")
		m.normal_enabled = true
		m.normal_texture = texture(source, "normal")
		m.normal_scale = 0.72 if key != "bark" else 1.05
		m.roughness_texture = texture(source, "orm")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_enabled = true
		m.ao_texture = texture(source, "orm")
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.35
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * (0.75 if key != "bark" else 1.2)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		match key:
			"metal":
				m.albedo_color = Color("525b5e")
				m.metallic = 0.82
				m.roughness = 0.38
			"glass":
				m.albedo_color = Color("344f55")
				m.metallic = 0.6
				m.roughness = 0.14
			"skin": m.albedo_color = Color("ae8464")
			"berry": m.albedo_color = Color("a93e31")
			"hair": m.albedo_color = Color("3c3026")
			"cloth": m.albedo_color = Color("777463")
			"leather": m.albedo_color = Color("56402c")
			"team": m.albedo_color = Assets.TEAM_COLORS[clampi(team, 0, 2)].darkened(0.12)
			"leaf":
				m.albedo_color = Color("72804b")
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.vertex_color_use_as_albedo = true
				m.backlight_enabled = true
				m.backlight = Color(0.08, 0.11, 0.025)
	_materials[cache_key] = m
	return m

static func instantiate(id: String, team: int = 0) -> Node3D:
	var record: Dictionary = info(id)
	if record.is_empty():
		return null
	if not _scenes.has(id):
		_scenes[id] = load(ROOT + String(record["file"])) as PackedScene
	var scene: PackedScene = _scenes[id] as PackedScene
	if scene == null:
		return null
	var node: Node3D = scene.instantiate() as Node3D
	_apply(node, team)
	node.set_meta("realism_asset", id)
	return node

static func _apply(node: Node, team: int) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh != null:
			for i in mesh.mesh.get_surface_count():
				var original: Material = mesh.mesh.surface_get_material(i)
				if original != null:
					var name: String = String(original.resource_name).trim_prefix("gfx_").get_slice(".", 0)
					mesh.set_surface_override_material(i, material(name, team))
	for child in node.get_children():
		_apply(child, team)

static func building(kind: String, age: int, team: int, size: float) -> Node3D:
	var era: int = 10 if age >= 9 else (6 if age >= 6 else (3 if age >= 3 else 1))
	var id: String = "bld_%s_a%02d" % [kind, era]
	var model: Node3D = instantiate(id, team)
	if model == null:
		return null
	var record: Dictionary = info(id)
	var dimensions: Array = record["size"] as Array
	var minimum: Array = record["bounds_min"] as Array
	var factor: float = size * 0.95 / maxf(float(dimensions[0]), float(dimensions[2]))
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-(float(minimum[0]) + float(dimensions[0]) * 0.5), -float(minimum[1]), -(float(minimum[2]) + float(dimensions[2]) * 0.5)) * factor
	return model

static func resource_parts(kind: String) -> Array:
	_load()
	if _parts.has(kind):
		return _parts[kind] as Array
	var ids: Array = ["oak_3", "oak_11", "oak_21"] if kind == "arbre" else (["berry_bush"] if kind == "baies" else ["boulder_4", "boulder_9", "boulder_17"])
	var result: Array = []
	for variant in ids.size():
		var model: Node3D = instantiate(String(ids[variant]))
		if model == null:
			continue
		var surfaces: Dictionary = {}
		_collect(model, Transform3D.IDENTITY, surfaces)
		for name in surfaces:
			var stream: SurfaceTool = surfaces[name] as SurfaceTool
			var mesh: ArrayMesh = stream.commit()
			result.append([mesh, material(String(name)), Vector3.ZERO, variant, ids.size()])
		model.free()
	_parts[kind] = result
	return result

static func _collect(node: Node3D, parent: Transform3D, surfaces: Dictionary) -> void:
	var transform_local: Transform3D = parent * node.transform
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			for surface in mi.mesh.get_surface_count():
				var original: Material = mi.mesh.surface_get_material(surface)
				var key: String = String(original.resource_name).trim_prefix("gfx_").get_slice(".", 0)
				if not surfaces.has(key):
					var stream := SurfaceTool.new()
					stream.begin(Mesh.PRIMITIVE_TRIANGLES)
					stream.set_material(material(key))
					surfaces[key] = stream
				(surfaces[key] as SurfaceTool).append_from(mi.mesh, surface, transform_local)
	for child in node.get_children():
		if child is Node3D:
			_collect(child as Node3D, transform_local, surfaces)

static func foliage(fog: Texture2D, mask: Texture2D, grass: bool = false, dimension: int = 96) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	m.set_shader_parameter("map_size", float(dimension))
	m.set_shader_parameter("fog_tex", fog)
	m.set_shader_parameter("ground_mask", mask)
	m.set_shader_parameter("tint", Vector3(0.25, 0.30, 0.12) if grass else Vector3(0.24, 0.31, 0.10))
	m.set_shader_parameter("is_grass", grass)
	return m

static func enhance_legacy(node: Node3D) -> void:
	# Only compatible physical materials are replaced; identity, emission and team markers remain intact.
	var aliases: Dictionary = {"wood": "wood", "wood_dark": "wood", "brick": "wall", "plaster": "wall", "daub": "wall", "concrete": "wall", "concrete_dark": "stone", "stone": "stone", "stone_dark": "stone", "marble": "stone", "slate": "roof", "tile_roof": "roof", "thatch": "roof"}
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			for surface in mi.mesh.get_surface_count():
				var previous: Material = mi.mesh.surface_get_material(surface)
				if previous != null and aliases.has(String(previous.resource_name)):
					mi.set_surface_override_material(surface, material(String(aliases[String(previous.resource_name)])))
	for child in node.get_children():
		if child is Node3D:
			enhance_legacy(child as Node3D)
