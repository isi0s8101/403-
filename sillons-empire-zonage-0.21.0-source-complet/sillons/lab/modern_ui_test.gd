extends SceneTree
var frames: int = 0
var checked: bool = false
func _initialize() -> void:
	GameConfig.mode = "skirmish"
	GameConfig.seed_value = 345
	change_scene_to_file("res://game/game.tscn")
func _process(_delta: float) -> bool:
	frames += 1
	if frames < 10:
		return false
	if not checked:
		checked = true
		var game = current_scene
		game.paused = true
		game.world.teams[0].age = 8
		game.world.teams[0].res = {"food": 20000.0, "wood": 20000.0, "ore": 20000.0}
		var i: int = 0
		for kind in Rules.UNITS:
			if int(Rules.UNITS[kind]["age"]) >= 4:
				game.world.spawn_unit(0, kind, Vector2(8 + i * 2, 75))
				i += 1
		i = 0
		for kind in Rules.BUILDINGS:
			if int(Rules.BUILDINGS[kind]["age"]) in range(4, 9):
				# 0.18 : 13 bâtiments urbains d'âges IV à VIII s'ajoutent ; la rangée unique dépassait la carte de
				# 96 cases (erreurs hors limites). Comportement voulu inchangé : on passe à la ligne toutes les 16 poses.
				var b = game.world.spawn_building(0, kind, Vector2i(8 + (i % 16) * 5, 65 - floori(float(i) / 16.0) * 6), true)
				game.sel_building = b.id
				game.hud.selection_changed()
				game.hud._refresh_selection()
				i += 1
		game.world.update_fog(true)
		ModernSystems._network(game.world)
		game.view.sync(1.0, 0.016)
		game.hud._refresh_build_buttons()
		for u in game.world.team_units(0):
			game.clear_selection()
			game.sel_units = [u.id]
			game.hud.selection_changed()
			game.hud._refresh_selection()
		print("MODERN_UI: models, building actions, unit information and network instantiated")
	if frames >= 20:
		quit(0)
	return false
