extends SceneTree
## Bibliothèque native : 800 modèles et trois LOD instanciés sans importer les GLB sur le téléphone.
## godot --headless --path . --script res://lab/assets_3d_test.gd
func _count(node: Node, out: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out["meshes"] = int(out["meshes"]) + 1
		out["aabb"] = (out["aabb"] as AABB).merge((node as MeshInstance3D).get_aabb()) if int(out["meshes"]) > 1 else (node as MeshInstance3D).get_aabb()
	if node is Skeleton3D:
		out["bones"] = (node as Skeleton3D).get_bone_count()
	if node is AnimationPlayer:
		out["anims"] = (node as AnimationPlayer).get_animation_list().size()
	if node is CollisionShape3D:
		out["collision"] = true
	for child in node.get_children():
		_count(child, out)

func _initialize() -> void:
	var total: int = 0
	var loaded: int = 0
	var failures: Array = []
	var assets_ok: int = 0
	for raw in AssetLibrary.ids():
		var id: String = String(raw)
		var record: Dictionary = AssetLibrary.info(id)
		var good: bool = true
		for lod in 3:
			total += 1
			var node: Node3D = AssetLibrary.instantiate(id, lod, lod == 0)
			if node == null:
				good = false
				failures.append("%s LOD%d : chargement impossible" % [id, lod])
				continue
			var stats: Dictionary = {"meshes": 0, "aabb": AABB(), "bones": 0, "anims": 0, "collision": false}
			_count(node, stats)
			var problem: String = ""
			if int(stats["meshes"]) < 1 or (stats["aabb"] as AABB).get_longest_axis_size() <= 0.01:
				problem = "aucune géométrie"
			elif bool(record.get("skinned", false)) and (int(stats["bones"]) != 11 or int(stats["anims"]) < 4):
				problem = "squelette ou animations absents (%d os, %d animations)" % [int(stats["bones"]), int(stats["anims"])]
			elif lod == 0 and not bool(stats["collision"]):
				problem = "collision absente"
			if problem.is_empty():
				loaded += 1
			else:
				good = false
				failures.append("%s LOD%d : %s" % [id, lod, problem])
			node.free()
		if good:
			assets_ok += 1
	var found: String = AssetLibrary.find("building_special", "hospital", 9)
	var lookup: bool = found == "bld.special.hospital.a08" and AssetLibrary.shared_material("brick") != null and AssetLibrary.shared_material("brick").albedo_texture != null
	for line in failures.slice(0, 12):
		print("FAIL " + String(line))
	print("%s recherche par famille et âge, matériau partagé texturé" % ("PASS" if lookup else "FAIL"))
	var ok: bool = failures.is_empty() and lookup and assets_ok == 800
	print("ASSETS_GODOT_RESULT=%s assets=%d/%d fichiers=%d/%d" % ["PASS" if ok else "FAIL", assets_ok, AssetLibrary.ids().size(), loaded, total])
	quit(0 if ok else 1)
