extends SceneTree
var frames: int = 0
func _initialize() -> void:
	change_scene_to_file("res://game/main_menu.tscn")
func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		current_scene._modern_sandbox()
	if frames == 15:
		var game = current_scene
		game.paused = true
		var found: int = 0
		for b in game.world.team_buildings(0):
			if int(Rules.BUILDINGS[b.type]["age"]) in range(4, 9):
				found += 1
		var ok: bool = found == 9 and game.world.teams[0].age == 8
		print("SANDBOX_TEST: modern_buildings=%d %s" % [found, "PASS" if ok else "FAIL"])
		quit(0 if ok else 1)
	return false
