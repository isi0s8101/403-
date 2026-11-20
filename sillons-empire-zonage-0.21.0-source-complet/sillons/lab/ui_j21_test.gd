extends SceneTree
## Tests de non-régression ciblés J2.1 (sans changer le moteur de simulation).
## godot --headless --path . -s res://lab/ui_j21_test.gd

var game
var frames := 0
var checks := 0
var failures := 0
var phase := 0

func _initialize() -> void:
	GameConfig.mode = "lab"
	GameConfig.lab_path = "res://lab/scenarios/r04_delegation.json"
	change_scene_to_file("res://game/game.tscn")

func _check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s UI_J21 %s" % ["PASS" if ok else "FAIL", name])

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 8:
		return false
	if game == null:
		game = current_scene
		game.paused = true
		return false
	match phase:
		0:
			var original: bool = bool(game.hud.minimap.visible)
			game.hud._toggle_minimap()
			_check("mini-carte repliable", game.hud.minimap.visible != original)
			game.hud._toggle_minimap()
			_check("mini-carte restauree", game.hud.minimap.visible == original)
			_check("liste escouades masquee par defaut", not game.hud.squad_panel.visible)
			game.hud._toggle_squads()
			_check("liste escouades ouvrable", game.hud.squad_panel.visible)
			game.hud._toggle_squads()
			_check("liste escouades fermable", not UIMotion.is_open(game.hud.squad_panel))
			phase = 1
		1:
			var initial_squads: Array = game.world.team_squads(0)
			_check("escouades disponibles", not initial_squads.is_empty())
			if initial_squads.is_empty():
				quit(1)
				return false
			var s = initial_squads[0]
			game.select_squad(s.id)
			_check("escouade selectionnee", game.sel_squad == s.id)
			var u = game.world.units.get(s.units[0])
			var p: Vector2 = game.cam.unproject_position(Vector3(u.pos.x, 0.6, u.pos.y))
			game.hud.open_radial(p, null, u.pos)
			_check("menu contextuel ouvert", game.hud.radial_open and game.hud.radial_panel.visible)
			var action: Button = game.hud.radial_panel.get_node("RadialBody/TargetAction") as Button
			_check("action sectorielle accessible", action.text == "Déf. armée")
			game.hud.close_radial()
			_check("menu contextuel ferme", not game.hud.radial_open)
			phase = 2
		2:
			var selection_squads: Array = game.world.team_squads(0)
			var ids: Array = []
			for id in selection_squads[0].units:
				if game.world.units.has(id):
					ids.append(id)
				if ids.size() >= 2:
					break
			game.select_many(ids)
			_check("selection multiple", game.sel_units.size() == ids.size() and game.sel_squad == -1)
			_check("surbrillance multiple", game.view.selection_ids.size() == ids.size())
			game.hud._toggle_box()
			_check("mode rectangle active", game.box_select_mode)
			game.hud._toggle_box()
			_check("mode rectangle annule", not game.box_select_mode)
			game.clear_selection()
			_check("panneau selection inactif", game.sel_units.is_empty() and game.sel_squad == -1)
			print("UI_J21_RESULT %d/%d PASS" % [checks - failures, checks])
			quit(0 if failures == 0 else 1)
	return false
