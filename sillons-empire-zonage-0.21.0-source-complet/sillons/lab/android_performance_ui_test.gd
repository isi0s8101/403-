extends SceneTree
var frames: int = 0
var checks: int = 0
var failures: int = 0
var screen
var pause_tick: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void:
	GameConfig.sim_speed = 4.0
	change_scene_to_file("res://game/performance_screen.tscn")
func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		screen = current_scene; screen.warmup = 5.0
		var button: Button = screen._choices.get_child(0) as Button
		for pressed in [true, false]:
			var event: InputEventScreenTouch = InputEventScreenTouch.new()
			event.index = 7; event.pressed = pressed; event.position = button.get_global_rect().get_center()
			root.push_input(event, true)
	if frames == 6:
		check(screen.active and screen.scenario == "large", "démarrage tactile d'une recette")
		check(screen.recorder != null and GameConfig.sim_speed == 1.0, "recette à vitesse ×1")
		check(not screen.game.hud.visible and not screen.game.is_processing_unhandled_input(), "ordres et sauvegardes de partie inaccessibles")
		screen._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT); pause_tick = screen.game.campaign.tick
	if frames == 9:
		check(screen.game.campaign.tick == pause_tick and screen.suspended, "arrière-plan suspendu")
		screen._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN); screen._warm_elapsed = 5.0
	if frames == 13:
		screen.finish()
		check(not screen.active and int(screen.report["interruptions"]) == 1, "interruption pendant préparation conservée")
		check(FileAccess.file_exists("user://mesures/last_report.json") and not FileAccess.file_exists(CampaignSave.PATH), "rapport sans écrasement de sauvegarde")
		screen._return_menu()
	if frames == 16:
		check(current_scene.scene_file_path == "res://game/main_menu.tscn" and GameConfig.sim_speed == 4.0, "retour menu et préférences rétablies")
		print("ANDROID_PERFORMANCE_UI_RESULT checks=", checks, " failures=", failures, " DEVICE=NOT_RUN")
		quit(0 if failures == 0 else 1)
	return false
