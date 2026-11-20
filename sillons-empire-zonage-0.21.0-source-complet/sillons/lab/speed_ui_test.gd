extends SceneTree
## Contrôle réel du panneau tactile et des pas fixes après changement de vitesse.
var frames: int = 0
var done: bool = false

func _initialize() -> void:
	GameConfig.sim_speed = 1.0
	GameConfig.mode = "skirmish"
	GameConfig.seed_value = 678
	change_scene_to_file("res://game/game.tscn")

func _process(_delta: float) -> bool:
	frames += 1
	if done or frames < 12:
		return false
	done = true
	var game = current_scene
	game.paused = true
	var ok: bool = game.hud.speed_btn != null
	for setting in GameConfig.SPEED_LEVELS:
		game.set_simulation_speed(float(setting))
		ok = ok and is_equal_approx(game.speed, float(setting)) and game.hud.speed_btn.text.begins_with("×")
	game.set_simulation_speed(8.0)
	game.acc = 0.0
	var before: int = game.campaign.tick
	game.paused = false
	game._process(0.1)
	game.paused = true
	var steps: int = game.campaign.tick - before
	ok = ok and steps >= 7 and steps <= 8
	game.hud._cycle_speed()
	ok = ok and is_equal_approx(game.speed, 0.5) and game.hud.speed_btn.text == "×0.5"
	print(("PASS" if ok else "FAIL") + " SPEED_UI vitesses 0.5-8x / légende / pas fixes : %d ticks" % steps)
	GameConfig.sim_speed = 1.0
	quit(0 if ok else 1)
	return false
