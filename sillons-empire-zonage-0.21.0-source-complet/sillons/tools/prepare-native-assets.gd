extends SceneTree
## Préparation sur poste de développement. Le téléphone reçoit les .scn/.res déjà prêts.
## Lancer depuis un projet de préparation contenant assets_3d/ déjà importé :
## godot --headless --path <projet_preparation> --script <ce_script> -- <sortie_native_neuve>
const SOURCE: String = "res://assets_3d/"
const SAVE_FLAGS: int = ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		push_error("Fournir un dossier de sortie absolu et neuf.")
		quit(2)
		return
	var output: String = args[0].simplify_path()
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		push_error("La sortie doit être neuve : aucune bibliothèque existante n’est écrasée.")
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "manifest.json"))
	var materials_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "materials/materials.json"))
	if not parsed is Dictionary or not materials_parsed is Dictionary:
		push_error("Catalogues sources absents ou invalides.")
		quit(2)
		return
	var catalogue: Dictionary = parsed as Dictionary
	var materials: Dictionary = (materials_parsed as Dictionary).get("materials", {}) as Dictionary
	var assets: Array = catalogue.get("assets", []) as Array
	if assets.size() != 800 or materials.size() != 58:
		push_error("800 modèles et 58 matériaux attendus.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var records: Array = []
	var scenes: int = 0
	var failures: int = 0
	for raw in assets:
		var asset: Dictionary = raw as Dictionary
		var paths: Array = [asset["model_path"]]
		paths.append_array(asset["lod_paths"] as Array)
		for lod in paths.size():
			var rel: String = String(paths[lod])
			if not _safe_relative(rel):
				failures += 1
				continue
			var source_file: String = SOURCE + rel
			var native_rel: String = rel.get_basename() + ".scn"
			var target: String = output.path_join(native_rel)
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			var scene: PackedScene = ResourceLoader.load(source_file, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			if scene == null or ResourceSaver.save(scene, target, SAVE_FLAGS) != OK:
				push_error("Préparation impossible : " + rel)
				failures += 1
				continue
			# Aucun lien vers un cache .godot local ou vers le GLB ne doit rester nécessaire.
			var dependencies: PackedStringArray = ResourceLoader.get_dependencies(target)
			if not dependencies.is_empty():
				push_error("Ressource non autonome : " + native_rel + " : " + str(dependencies))
				failures += 1
				continue
			records.append({"asset_id": String(asset["asset_id"]), "lod": lod, "source_path": rel,
				"source_sha256": FileAccess.get_sha256(source_file), "path": native_rel,
				"sha256": FileAccess.get_sha256(target)})
			scenes += 1
			if scenes % 200 == 0:
				print("NATIVE_PREPARE_SCENES=%d/2400" % scenes)
	var texture_records: Array = []
	var seen: Dictionary = {}
	for raw in materials.values():
		var definition: Dictionary = raw as Dictionary
		var textures: Dictionary = definition["textures"] as Dictionary
		for entry in textures.values():
			var rel: String = String(entry)
			if seen.has(rel):
				continue
			seen[rel] = true
			if not _safe_relative(rel):
				failures += 1
				continue
			var image := Image.new()
			var image_error: Error = image.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE + rel))
			if image_error != OK or image.is_empty():
				failures += 1
				continue
			# Images CPU RGBA portables, sans format de compression GPU propre au poste de préparation.
			image.convert(Image.FORMAT_RGBA8)
			image.generate_mipmaps()
			var native_rel: String = rel.get_basename() + ".res"
			var target: String = output.path_join(native_rel)
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			if ResourceSaver.save(image, target, SAVE_FLAGS) != OK:
				failures += 1
				continue
			texture_records.append({"source_path": rel, "source_sha256": FileAccess.get_sha256(SOURCE + rel),
				"path": native_rel, "sha256": FileAccess.get_sha256(target), "width": image.get_width(),
				"height": image.get_height(), "mipmaps": image.get_mipmap_count(), "format": "RGBA8"})
	for rel in ["manifest.json", "materials/materials.json"]:
		DirAccess.make_dir_recursive_absolute(output.path_join(rel).get_base_dir())
		var destination: FileAccess = FileAccess.open(output.path_join(rel), FileAccess.WRITE)
		if destination == null:
			failures += 1
		else:
			destination.store_string(FileAccess.get_file_as_string(SOURCE + rel))
	var report: Dictionary = {"schema": 1, "engine": Engine.get_version_info().get("string", ""),
		"source_manifest_sha256": FileAccess.get_sha256(SOURCE + "manifest.json"), "models": assets.size(),
		"scenes": scenes, "textures": texture_records.size(), "failures": failures, "files": records,
		"images": texture_records, "self_contained": true, "prepared": failures == 0 and scenes == 2400 and texture_records.size() == 174}
	var report_file: FileAccess = FileAccess.open(output.path_join("native-library.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "  ") + "\n")
	else:
		failures += 1
	var ok: bool = failures == 0 and scenes == 2400 and texture_records.size() == 174
	print("NATIVE_PREPARE_RESULT=%s scenes=%d images=%d failures=%d" % ["PASS" if ok else "FAIL", scenes, texture_records.size(), failures])
	quit(0 if ok else 1)

func _safe_relative(path: String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not path.contains(":") and not path.contains("\\") and not ".." in path.split("/")
