extends SceneTree
## Paquet natif inerte pour l’éditeur, monté à la demande par AssetLibrary.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0].is_absolute_path() or not args[1].is_absolute_path():
		quit(2)
		return
	var source: String = args[0].simplify_path()
	var destination: String = args[1].simplify_path()
	if FileAccess.file_exists(destination):
		push_error("Le paquet existe déjà ; choisir une nouvelle sortie.")
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("native-library.json")))
	if not parsed is Dictionary or not bool((parsed as Dictionary).get("prepared", false)):
		push_error("Bibliothèque native incomplète.")
		quit(2)
		return
	var report: Dictionary = parsed as Dictionary
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var packer := PCKPacker.new()
	if packer.pck_start(destination) != OK:
		quit(2)
		return
	var paths: Array = ["manifest.json", "materials/materials.json", "native-library.json"]
	for entry in (report["files"] as Array) + (report["images"] as Array):
		paths.append(String((entry as Dictionary)["path"]))
	for raw in paths:
		var path: String = String(raw)
		if path.is_absolute_path() or ".." in path.split("/") or path.contains(":"):
			quit(2)
			return
		if packer.add_file("res://assets_3d_native/" + path, source.path_join(path)) != OK:
			push_error("Fichier absent du paquet : " + path)
			quit(2)
			return
	if packer.flush() != OK:
		quit(2)
		return
	print("NATIVE_PACK=PASS files=%d sha256=%s" % [paths.size(), FileAccess.get_sha256(destination)])
	quit(0)
