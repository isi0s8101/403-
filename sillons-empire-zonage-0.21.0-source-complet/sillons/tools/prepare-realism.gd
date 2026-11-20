extends SceneTree
## Development-only staging project: models/ contains authored GLBs outside the playable project.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var output: String = args[0]
	var pack_path: String = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://models/manifest.json"))
	if not parsed is Dictionary:
		quit(2)
		return
	var records: Array = (parsed as Dictionary)["models"] as Array
	var prepared: Array = []
	for value in records:
		var record: Dictionary = (value as Dictionary).duplicate(true)
		var id: String = String(record["id"])
		var original: String = "res://models/" + String(record["file"])
		var scene: PackedScene = ResourceLoader.load(original, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if scene == null:
			quit(1)
			return
		var target: String = output.path_join(id + ".scn")
		if ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES) != OK or not ResourceLoader.get_dependencies(target).is_empty():
			push_error("Native scene failed: " + id)
			quit(1)
			return
		var node: Node3D = scene.instantiate() as Node3D
		var bounds: AABB = _bounds(node, Transform3D.IDENTITY)
		record["bounds_min"] = [bounds.position.x, bounds.position.y, bounds.position.z]
		record["size"] = [bounds.size.x, bounds.size.y, bounds.size.z]
		record["file"] = id + ".scn"
		record["source_sha256"] = FileAccess.get_sha256(original)
		record["sha256"] = FileAccess.get_sha256(target)
		node.free()
		prepared.append(record)
	var manifest: Dictionary = {"schema": 1, "prepared": true, "self_contained": true, "engine": Engine.get_version_info()["string"], "models": prepared}
	var file: FileAccess = FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	var packer := PCKPacker.new()
	if packer.pck_start(pack_path) != OK:
		quit(1)
		return
	for item in prepared:
		var name: String = String((item as Dictionary)["file"])
		if packer.add_file("res://realism_native/" + name, output.path_join(name)) != OK:
			quit(1)
			return
	if packer.add_file("res://realism_native/manifest.json", output.path_join("manifest.json")) != OK or packer.flush() != OK:
		quit(1)
		return
	print("REALISM_NATIVE=PASS models=%d pack_sha256=%s" % [prepared.size(), FileAccess.get_sha256(pack_path)])
	quit(0)

func _bounds(node: Node3D, parent: Transform3D) -> AABB:
	var transform_local: Transform3D = parent * node.transform
	var result := AABB()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = transform_local * (node as MeshInstance3D).mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var value: AABB = _bounds(child as Node3D, transform_local)
			if value.size != Vector3.ZERO:
				result = value if result.size == Vector3.ZERO else result.merge(value)
	return result
