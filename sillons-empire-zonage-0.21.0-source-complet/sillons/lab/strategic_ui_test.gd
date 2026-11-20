extends SceneTree
## Instanciation de l'interface et changement de carte, sans mesure GPU.
var frames: int = 0
var checked: bool = false

func _initialize() -> void:
	GameConfig.mode = "skirmish"
	GameConfig.seed_value = 678
	change_scene_to_file("res://game/game.tscn")

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 12:
		return false
	if checked:
		return false
	checked = true
	var game = current_scene
	game.paused = true
	var ui: StrategicHud = game.strategic_hud as StrategicHud
	if ui == null:
		print("FAIL STRATEGIC_UI panneau absent")
		quit(1)
		return false
	game.campaign.ages[0] = 10
	game.campaign._sync_all()
	ui.refresh(1.0, true)
	var lock_ok: bool = not (ui.sector_buttons["nemesis"] as Button).disabled
	var old_world: SimWorld = game.world
	game.switch_sector("aurore")
	var changed: bool = game.world != old_world and game.view.world == game.world
	game.switch_sector("val")
	var returned: bool = game.world == old_world and game.view.world == game.world
	var ok: bool = lock_ok and changed and returned
	print(("PASS" if ok else "FAIL") + " STRATEGIC_UI navigation tactile et carte active")
	quit(0 if ok else 1)
	return false
