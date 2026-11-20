extends SceneTree
## Le projet doit fonctionner sans dossier GLB et sans cache d’import des modèles.
var failures: int = 0
var checks: int = 0

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _initialize() -> void:
	check("catalogue natif monté : 800 modèles", AssetLibrary.ids().size() == 800)
	check("aucun dossier GLB dans le projet jouable", not DirAccess.dir_exists_absolute("res://assets_3d"))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AssetLibrary.ROOT + "native-library.json"))
	if not parsed is Dictionary:
		check("index natif présent", false)
		finish()
		return
	var report: Dictionary = parsed as Dictionary
	check("2400 scènes prêtes et 174 images", bool(report.get("prepared", false)) and int(report.get("scenes", 0)) == 2400 and int(report.get("textures", 0)) == 174)
	var files_ok: int = 0
	var dependencies_ok: int = 0
	for entry in report.get("files", []) as Array:
		var file: Dictionary = entry as Dictionary
		var path: String = AssetLibrary.ROOT + String(file["path"])
		if ResourceLoader.exists(path, "PackedScene") and FileAccess.get_sha256(path) == String(file["sha256"]):
			files_ok += 1
		if ResourceLoader.get_dependencies(path).is_empty():
			dependencies_ok += 1
	check("2400 scènes intègres dans le paquet", files_ok == 2400)
	check("aucun lien vers un cache .godot externe", dependencies_ok == 2400)
	var images_ok: int = 0
	for entry in report.get("images", []) as Array:
		var file: Dictionary = entry as Dictionary
		var path: String = AssetLibrary.ROOT + String(file["path"])
		var image: Image = ResourceLoader.load(path, "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
		if image != null and not image.is_empty() and image.get_format() == Image.FORMAT_RGBA8 and image.has_mipmaps() and FileAccess.get_sha256(path) == String(file["sha256"]):
			images_ok += 1
	check("174 images RGBA8 avec mipmaps et empreinte correcte", images_ok == 174)
	var jeep_id: String = AssetLibrary.find("vehicle_ground", "jeep", 7)
	check("jeep de la capture chargée en natif", not jeep_id.is_empty() and AssetLibrary.path(jeep_id).ends_with(".scn"))
	var jeep: Node3D = AssetLibrary.instantiate(jeep_id)
	check("jeep instanciée sans import GLB", jeep != null)
	if jeep != null:
		jeep.free()
	var material: StandardMaterial3D = AssetLibrary.shared_material("brick")
	check("matériau PBR préservé", material != null and material.albedo_texture != null and material.normal_texture != null and material.orm_texture != null)
	finish()

func finish() -> void:
	print("NATIVE_ASSETS_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
