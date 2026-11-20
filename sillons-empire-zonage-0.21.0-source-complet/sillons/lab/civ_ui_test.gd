extends SceneTree
## 0.16 — Interface de l'évolution de la civilisation dans la vraie scène de jeu (campagne « deux systèmes »).
var frames: int = 0
var failures: int = 0
var checks: int = 0
var game

func _initialize() -> void:
	GameConfig.mode = "empire"
	GameConfig.seed_value = 16010
	change_scene_to_file("res://game/game.tscn")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

func _press(text: String) -> bool:
	for button in game.hud.root.find_children("*", "Button", true, false):
		if (button as Button).text == text and (button as Button).is_visible_in_tree():
			for pressed in [true, false]:
				var touch := InputEventScreenTouch.new()
				touch.index = 7
				touch.pressed = pressed
				touch.position = (button as Button).get_global_rect().get_center()
				root.push_input(touch, true)
			return true
	return false

func _button_starting(prefix: String) -> Button:
	for button in game.civ_panel.content.get_children():
		if button is Button and (button as Button).text.begins_with(prefix):
			return button as Button
	return null

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 14:
		game = current_scene
		game.paused = true
		var w: SimWorld = game.world
		check(CivEvolution.enabled(w) and game.civ_panel != null, "campagne principale : évolution de la civilisation active")
		check(_press("Civilisation"), "bouton « Civilisation » dans la barre du haut")
	if frames == 16:
		var w: SimWorld = game.world
		check(game.civ_panel.visible and game.hud.is_over_ui(game.civ_panel.get_global_rect().get_center()), "panneau ouvert, il bloque les gestes du terrain")
		check(game.civ_panel.content.get_child_count() > 20, "voies, monuments, héros, améliorations et pouvoirs listés")
		w.teams[0].res = {"food": 50000.0, "wood": 50000.0, "ore": 50000.0}
		w.teams[0].age = 2
		game.civ_panel.rebuild()
		var choice: Button = _button_starting("Voie savante")
		check(choice != null, "choix de voie proposé à l'âge II")
		if choice != null:
			choice.pressed.emit()
		check(String((CivEvolution.state(w, 0)["voies"] as Dictionary).get("antique", "")) == "savante", "voie choisie depuis le panneau (commande simulée)")
		var place: Button = _button_starting("Placer : Citadelle")
		var objective_blocked: bool = place == null and CivEvolution.build_lack(w, 0, "monument_citadelle").begins_with("objectif")
		check(place != null or objective_blocked, "monument de l'âge suivant proposé (ou objectif d'âge affiché)")
		CivEvolution.state(w, 0)["points"] = 5.0
		game.civ_panel.rebuild()
		var unlock: Button = _button_starting("Débloquer (3 points) : Rang 1 · Ravitaillement")
		check(unlock != null, "pouvoir de rang 1 déblocable")
		if unlock != null:
			unlock.pressed.emit()
		var use: Button = _button_starting("Utiliser : Rang 1 · Ravitaillement")
		check(use != null, "pouvoir débloqué prêt à l'emploi")
		if use != null:
			use.pressed.emit()
		check(game.mode == "civ_power" and not game.civ_panel.visible, "ciblage du pouvoir sur la carte")
		var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
		var hurt: SimWorld.Unit = w.spawn_unit(0, "lancier", cc.center + Vector2(4.0, 4.0))
		hurt.hp = hurt.max_hp * 0.3
		game.view.sync(1.0, 0.016)
		var screen: Vector2 = game.cam.unproject_position(Vector3(hurt.pos.x, 0.0, hurt.pos.y))
		game._tap(screen)
		check(hurt.hp > hurt.max_hp * 0.55 and game.mode == "", "toucher la carte lance le pouvoir (soin appliqué)")
		game.sel_building = cc.id
		game.hud.selection_changed()
		game.hud._refresh_selection()
		var drawer = game.hud.root.find_children("BuildingDrawer", "", true, false)
		check(not drawer.is_empty(), "fiche du centre ouverte")
		if not drawer.is_empty():
			drawer[0].open_building(cc.id)
			drawer[0].active_tab = "Unités"
			drawer[0]._signature = ""
			drawer[0].refresh()
			var titles: Array = drawer[0].cards.map(func(card): return String(card.key))
			check(titles.has("heros_antique") and not titles.has("chevalier"), "fiche : héros proposé, unités des autres voies masquées")
			drawer[0].active_tab = "Évolutions"
			drawer[0]._signature = ""
			drawer[0].refresh()
			titles = drawer[0].cards.map(func(card): return String(card.key))
			check(titles.has("civ:charrues") and titles.has("civ:batisseurs"), "fiche : améliorations économiques au centre")
		game._back_action()
		print("CIV_UI_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
		quit(0 if failures == 0 else 1)
	return false
