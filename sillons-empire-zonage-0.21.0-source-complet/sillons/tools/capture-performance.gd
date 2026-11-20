extends SceneTree
var frames: int = 0
var capture_mode: String = "choices"
var output: String = ""
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	capture_mode = args[0]; output = args[2]
	GameConfig.visual_quality = 1; GameConfig.reduce_motion = true
	change_scene_to_file("res://game/main_menu.tscn" if capture_mode == "laboratory" else "res://game/performance_screen.tscn")
func _process(_delta: float) -> bool:
	frames += 1
	if frames == 4:
		if capture_mode == "laboratory": current_scene._toggle_laboratory()
		elif capture_mode != "choices":
			current_scene.warmup = 0.0; current_scene.duration = 120.0
			current_scene.start("orbit" if capture_mode == "orbit" else "fronts")
	if frames == 45:
		var error: Error = root.get_texture().get_image().save_png(output)
		print("ANDROID_PERFORMANCE_CAPTURE=", "PASS" if error == OK else "FAIL", " mode=", capture_mode)
		quit(0 if error == OK else 1)
	return false
