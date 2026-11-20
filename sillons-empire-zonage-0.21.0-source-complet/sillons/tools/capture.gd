extends SceneTree
## Capture d'écran de contrôle (hors livrable de jeu) :
## godot --path . --rendering-method gl_compatibility -s res://tools/capture.gd -- <scene> <secondes_sim> <sortie.png> [lab_path]
var frames := 0
var target_frames := 0
var out := ""
var sim_seconds := 0.0
var game

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var scene: String = a[0]
	sim_seconds = float(a[1])
	out = a[2]
	GameConfig.mode = "skirmish"
	GameConfig.seed_value = 4242
	GameConfig.player_ai = false
	if a.size() > 3:
		if a[3].ends_with(".json"):
			GameConfig.mode = "lab"
			GameConfig.lab_path = a[3]
		elif a[3] == "ai":
			GameConfig.player_ai = true
	GameConfig.show_perf = true
	change_scene_to_file(scene)
	target_frames = 30

func _process(_d: float) -> bool:
	frames += 1
	if frames == 3 and current_scene and current_scene.get("world") != null:
		game = current_scene
		var w: SimWorld = game.world
		var steps := int(sim_seconds * Rules.TICK_RATE)
		for i in steps:
			if game.scenario != null:
				game.scenario.step()
			else:
				w.step()
		game._consume_events()
		var a := OS.get_cmdline_user_args()
		if a.size() > 4:
			# cadrage : x,z,distance
			var f := a[4].split(",")
			game.cam_target = Vector3(float(f[0]), 0, float(f[1]))
			if f.size() > 2:
				game.cam_dist = float(f[2])
			game._update_camera()
	if frames == target_frames:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out)
		print("capture ", out, " ", img.get_size())
		quit()
	return false

func a_focus() -> bool:
	return true
