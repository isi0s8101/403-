extends SceneTree
## Parcours tactile réel : pause -> aide -> retour pause -> reprise. Aucun clic traversant.
var frames: int = 0
var stage: int = 0
var failures: int = 0
var game

func _initialize() -> void:
	GameConfig.mode = "lab"
	GameConfig.lab_path = "res://lab/scenarios/r04_delegation.json"
	change_scene_to_file("res://game/game.tscn")

func check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func tap_button(panel: Control, caption: String) -> bool:
	for child in panel.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.text != caption:
			continue
		for pressed in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 6
			event.position = button.get_global_rect().get_center()
			event.pressed = pressed
			root.push_input(event, true)
		return true
	return false

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 12:
		return false
	if stage == 0:
		game = current_scene
		game.hud._toggle_menu()
		stage = 1
	elif stage == 1:
		game.hud._toggle_controls()
		stage = 2
	elif stage == 2:
		check("bouton aide accessible", tap_button(game.hud.controls_panel, "Fermer l'aide"))
		stage = 3
	elif stage == 3:
		check("toucher ferme l'aide et restaure le menu", not game.hud.controls_panel.visible and game.hud.menu_panel.visible)
		check("bouton reprendre accessible", tap_button(game.hud.menu_panel, "Reprendre"))
		stage = 4
	elif stage == 4:
		check("reprise sans panneau ni doigt bloqué", not game.hud.menu_panel.visible and not game.paused and game.touches.is_empty())
		print("MODAL_TOUCH_RESULT=%s checks=4 failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
		quit(0 if failures == 0 else 1)
	return false
