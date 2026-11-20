extends SceneTree
var frames: int = 0
var mode_name: String = "tactical"
var output: String = ""
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	mode_name = args[0]
	output = args[2]
	GameConfig.mode = "empire"
	GameConfig.seed_value = 14001
	GameConfig.visual_quality = 2
	GameConfig.adaptive_visuals = false
	change_scene_to_file("res://game/main_menu.tscn" if mode_name == "menu" else "res://game/game.tscn")
func _process(_delta: float) -> bool:
	frames += 1
	if frames in [1, 8, 16]: print("CAPTURE_FRAME ",frames)
	if frames == 8 and mode_name != "menu":
		var game = current_scene
		game.paused = true
		game.hud.set_hint("Campagne interstellaire · deux civilisations à l'âge I · carte 256 × 256")
		if mode_name in ["politics", "production", "roads", "diplomacy"]:
			game.evolution_panel.open()
			game.evolution_panel.page = {"politics":"Politique", "production":"Production", "roads":"Routes", "diplomacy":"Diplomatie"}[mode_name]
			game.evolution_panel.rebuild()
	if frames == 20:
		get_root().get_texture().get_image().save_png(output)
		print("EVOLUTION_CAPTURE=PASS ",mode_name)
		quit()
	return false
