extends SceneTree
var checks: int = 0
var failures: int = 0
var frames: int = 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void:
	var record: Dictionary = RealismAssets.info("human_ouvrier")
	check("native art pack mounted", not record.is_empty())
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RealismAssets.ROOT + "manifest.json"))
	if not data is Dictionary:
		quit(1)
		return
	var models: Array = (data as Dictionary)["models"] as Array
	check("57 authored assets", models.size() == 57)
	for raw in models:
		var item: Dictionary = raw as Dictionary
		var path: String = RealismAssets.ROOT + String(item["file"])
		check("self contained and intact " + String(item["id"]), ResourceLoader.get_dependencies(path).is_empty() and FileAccess.get_sha256(path) == String(item["sha256"]))
		var node: Node3D = RealismAssets.instantiate(String(item["id"]))
		check("instanced " + String(item["id"]), node != null)
		if node != null: node.free()
	for material in ["grass", "soil", "stone", "sand", "wall", "roof", "wood", "bark"]:
		for channel in ["albedo", "normal", "orm"]:
			check("photographic PBR " + material + ":" + channel, RealismAssets.texture(material, channel) != null)
	var near_model: Node3D = TacticalModels.unit("ouvrier", 0, 1, 0)
	check("near figure uses new authored geometry", near_model.get_node("Body/LibraryModel").has_meta("realism_asset"))
	var players: Array = near_model.get_meta("players", []) as Array
	check("near human has animation player", players.size() == 1)
	if not players.is_empty():
		var player: AnimationPlayer = players[0] as AnimationPlayer
		for action in ["idle", "walk", "work", "attack"]: check("animation " + action, player.has_animation(action))
	near_model.free()
	GameConfig.mode = "skirmish"
	GameConfig.adaptive_visuals = false
	change_scene_to_file("res://game/game.tscn")
func _process(_delta: float) -> bool:
	frames += 1
	if frames < 20: return false
	var game = current_scene
	game.paused = true
	var state: String = game.world.state_hash()
	game.view.sync(1.0, 0.0)
	game.view._refresh_nodes()
	check("visual pass never changes simulation", state == game.world.state_hash())
	var capacity: int = 0
	var drawn: int = 0
	for parts in game.view.node_mm.values():
		for raw in parts:
			var mesh: MultiMesh = (raw as MultiMeshInstance3D).multimesh
			capacity += mesh.instance_count
			drawn += maxi(0, mesh.visible_instance_count)
	check("unseen resource instances not submitted", drawn < capacity)
	print("REALISM_VISUAL_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
	return false
