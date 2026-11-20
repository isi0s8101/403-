class_name AssetLibrary
extends RefCounted
## Bibliothèque native préparée (res://assets_3d_native) : chargement par identifiant stable, niveau de détail,
## matériaux partagés texturés et couleur de camp. Purement visuel : ne lit ni ne modifie la simulation.
const ROOT := "res://assets_3d_native/"
const NATIVE_PACK: String = "res://data/assets_3d.pck"
const PARCEL_M: float = 8.0
static var _manifest: Dictionary = {}
static var _by_id: Dictionary = {}
static var _materials: Dictionary = {}
static var _defs: Dictionary = {}
static var _find_cache: Dictionary = {}
static var _scene_cache: Dictionary = {}
static var _compact_cache: Dictionary = {}
static var _team_materials: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _load_attempted: bool = false
const CACHE_LIMIT: int = 64

static func _load() -> void:
	if _load_attempted:
		return
	_load_attempted = true
	if not FileAccess.file_exists(NATIVE_PACK) or not ProjectSettings.load_resource_pack(NATIVE_PACK, false):
		push_error("Paquet 3D natif absent ou illisible : extraire l’archive 0.13.5 complète.")
		return
	if not FileAccess.file_exists(ROOT + "manifest.json"):
		push_error("Bibliothèque native absente : extraire l’archive source complète 0.13.5.")
		return
	var text: String = FileAccess.get_file_as_string(ROOT + "manifest.json")
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	_manifest = parsed as Dictionary
	for raw in _manifest.get("assets", []) as Array:
		var record: Dictionary = raw as Dictionary
		_by_id[String(record["asset_id"])] = record
	var mats: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "materials/materials.json"))
	if mats is Dictionary:
		_defs = (mats as Dictionary).get("materials", {}) as Dictionary

static func ids() -> Array:
	_load()
	return _by_id.keys()

static func info(asset_id: String) -> Dictionary:
	_load()
	return _by_id.get(asset_id, {}) as Dictionary

static func find(category: String, family: String, age: int) -> String:
	## Asset de la famille dont l'âge est le plus proche sans dépasser l'âge demandé (sinon le plus ancien).
	_load()
	var lookup: String = category + ":" + family + ":" + str(age)
	if _find_cache.has(lookup):
		return String(_find_cache[lookup])
	var best: String = ""
	var best_age: int = -1
	var oldest: String = ""
	var oldest_age: int = 99
	for raw in _by_id.values():
		var record: Dictionary = raw as Dictionary
		if String(record["category"]) != category or String(record["family"]) != family:
			continue
		var a: int = int(record["age"])
		if a <= age and a > best_age:
			best_age = a
			best = String(record["asset_id"])
		if a < oldest_age:
			oldest_age = a
			oldest = String(record["asset_id"])
	var found: String = best if not best.is_empty() else oldest
	_find_cache[lookup] = found
	return found

static func path(asset_id: String, lod: int = 0) -> String:
	var record: Dictionary = info(asset_id)
	if record.is_empty():
		return ""
	if lod <= 0:
		return ROOT + String(record["model_path"]).get_basename() + ".scn"
	var lods: Array = record["lod_paths"] as Array
	return ROOT + String(lods[mini(lod, lods.size()) - 1]).get_basename() + ".scn"

static func instantiate(asset_id: String, lod: int = 0, textured: bool = true) -> Node3D:
	var file: String = path(asset_id, lod)
	if file.is_empty() or not ResourceLoader.exists(file):
		return null
	var scene: PackedScene = _scene_cache.get(file) as PackedScene
	if scene == null:
		scene = load(file) as PackedScene
		if scene != null:
			if _scene_cache.size() >= CACHE_LIMIT:
				_scene_cache.erase(_scene_cache.keys()[0])
			_scene_cache[file] = scene
	if scene == null:
		return null
	var node: Node3D = scene.instantiate() as Node3D
	if textured and node != null:
		apply_shared_materials(node)
	return node

static func shared_material(name: String) -> StandardMaterial3D:
	## Un seul matériau par nom pour toute la partie : textures carrelables en projection triplanaire.
	_load()
	if _materials.has(name):
		return _materials[name] as StandardMaterial3D
	var definition: Dictionary = _defs.get(name, {}) as Dictionary
	if definition.is_empty():
		return null
	var m := StandardMaterial3D.new()
	m.resource_name = name
	var c: Array = definition["base_color_linear"] as Array
	m.albedo_color = Color(float(c[0]), float(c[1]), float(c[2]), float(definition.get("alpha", 1.0))).linear_to_srgb()
	m.metallic = float(definition["metallic"])
	m.roughness = float(definition["roughness"])
	var textures: Dictionary = definition["textures"] as Dictionary
	var base_texture: Texture2D = _native_texture(String(textures["base"]))
	if base_texture != null:
		m.albedo_color = Color(1, 1, 1, float(definition.get("alpha", 1.0)))
		m.albedo_texture = base_texture
		m.normal_enabled = true
		m.normal_texture = _native_texture(String(textures["normal"]))
		m.orm_texture = _native_texture(String(textures["orm"]))
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		m.normal_scale = 0.45
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if definition.get("emissive") is Array:
		var e: Array = definition["emissive"] as Array
		m.emission_enabled = true
		m.emission = Color(float(e[0]), float(e[1]), float(e[2])).linear_to_srgb()
	if float(definition.get("alpha", 1.0)) < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[name] = m
	return m

static func apply_shared_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			for surface in mi.mesh.get_surface_count():
				var original: Material = mi.mesh.surface_get_material(surface)
				if original != null:
					var shared: StandardMaterial3D = shared_material(String(original.resource_name))
					if shared != null:
						mi.set_surface_override_material(surface, shared)
	for child in node.get_children():
		apply_shared_materials(child)

static func set_team_color(node: Node, color: Color) -> void:
	## Recolore les surfaces « team » (bannières, marquages) : jamais le seul signal, les silhouettes diffèrent aussi.
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			for surface in mi.mesh.get_surface_count():
				var original: Material = mi.mesh.surface_get_material(surface)
				if original != null and String(original.resource_name) == "team":
					var key: String = color.to_html()
					if not _team_materials.has(key):
						var team_material := StandardMaterial3D.new()
						team_material.albedo_color = color
						team_material.roughness = 0.62
						team_material.resource_name = "team"
						_team_materials[key] = team_material
					var m: StandardMaterial3D = _team_materials[key] as StandardMaterial3D
					mi.set_surface_override_material(surface, m)
	for child in node.get_children():
		set_team_color(child, color)

static func scale_for_cells(asset_id: String, cells: float) -> float:
	## Facteur d'échelle pour que l'emprise du modèle tienne dans « cells » cases de la carte tactique.
	var record: Dictionary = info(asset_id)
	if record.is_empty():
		return 1.0
	var size: Array = record["size_m"] as Array
	return cells / maxf(0.01, maxf(float(size[0]), float(size[2])))

static func instantiate_compact(asset_id: String, lod: int = 0) -> Node3D:
	## Fige un modèle au repos et fusionne ses sous-maillages par matériau.
	## Réservé aux décors et LOD statiques ; les personnages proches gardent squelette et animations.
	var key: String = asset_id + ":" + str(lod)
	var merged: ArrayMesh = _compact_cache.get(key) as ArrayMesh
	if merged == null:
		var original: Node3D = instantiate(asset_id, lod)
		if original == null:
			return null
		var buckets: Dictionary = {}
		_collect_surfaces(original, Transform3D.IDENTITY, buckets)
		merged = ArrayMesh.new()
		for name in buckets:
			var bucket: Dictionary = buckets[name] as Dictionary
			var stream: SurfaceTool = bucket["stream"] as SurfaceTool
			stream.set_material(bucket["material"] as Material)
			stream.commit(merged)
		original.free()
		if _compact_cache.size() >= CACHE_LIMIT:
			_compact_cache.erase(_compact_cache.keys()[0])
		_compact_cache[key] = merged
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = merged
	root.add_child(mi)
	root.set_meta("asset_id", asset_id)
	return root

static func _collect_surfaces(node: Node3D, parent_transform: Transform3D, buckets: Dictionary) -> void:
	var transform_local: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			for surface in mi.mesh.get_surface_count():
				var material: Material = mi.get_active_material(surface)
				var key: String = str(material.get_instance_id()) if material != null else "default"
				if not buckets.has(key):
					var stream := SurfaceTool.new()
					stream.begin(Mesh.PRIMITIVE_TRIANGLES)
					buckets[key] = {"stream": stream, "material": material}
				var bucket: Dictionary = buckets[key] as Dictionary
				(bucket["stream"] as SurfaceTool).append_from(mi.mesh, surface, transform_local)
	for child in node.get_children():
		if child is Node3D:
			_collect_surfaces(child as Node3D, transform_local, buckets)

static func cache_stats() -> Dictionary:
	return {"scenes": _scene_cache.size(), "meshes": _compact_cache.size(), "limit": CACHE_LIMIT, "materials": _materials.size()}

static func _native_texture(source_relative_path: String) -> Texture2D:
	## .res Image RGBA8 avec mipmaps, portable OpenGL/Vulkan, sans réimport PNG du catalogue.
	var file: String = ROOT + source_relative_path.get_basename() + ".res"
	if _texture_cache.has(file):
		return _texture_cache[file] as Texture2D
	if not ResourceLoader.exists(file, "Image"):
		push_error("Image native absente : " + file)
		return null
	var image: Image = ResourceLoader.load(file, "Image") as Image
	if image == null or image.is_empty():
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if _texture_cache.size() >= CACHE_LIMIT:
		_texture_cache.erase(_texture_cache.keys()[0])
	_texture_cache[file] = texture
	return texture
