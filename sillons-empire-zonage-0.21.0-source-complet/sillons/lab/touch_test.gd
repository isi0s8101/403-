extends SceneTree
## Recette automatisée des gestes tactiles (sans rendu) :
## godot --headless --path . -s res://lab/touch_test.gd
## Vérifie : tap sur une unité -> escouade ; 2e tap -> unité seule ; tap au sol -> ordre ;
## tremblement du doigt sous le seuil -> pas de déplacement de caméra ; tap sur l'interface -> aucun ordre ;
## glisser -> caméra déplacée sans ordre.

var game
var frame := 0
var results := []
var step := 0

func _initialize() -> void:
	GameConfig.mode = "lab"
	GameConfig.lab_path = "res://lab/scenarios/r04_delegation.json"
	change_scene_to_file("res://game/game.tscn")

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	root.push_input(e, true)

func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	root.push_input(e, true)

func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func _screen_of(u) -> Vector2:
	return game.cam.unproject_position(Vector3(u.pos.x, 0.6, u.pos.y))

var u_ref
var cam_before := Vector3.ZERO
var ground_pt := Vector2.ZERO

func _process(_d: float) -> bool:
	frame += 1
	if frame < 5:
		return false
	if game == null:
		game = current_scene
		game.paused = true
		game.focus(Vector2(24, 73))
		return false
	match step:
		0:
			# unité de l'escouade 1 visible à l'écran
			var s = game.world.team_squads(0)[0]
			u_ref = game.world.units[s.units[2]]
			cam_before = game.cam_target
			var p := _screen_of(u_ref)
			print("unit screen ", p, " over_ui=", game.hud.is_over_ui(p), " vp=", game.get_viewport().get_visible_rect().size, " pick=", game._pick(p))
			_touch(0, p, true)
			_drag(0, p + Vector2(6, 4), Vector2(6, 4))   # tremblement < seuil
			_touch(0, p + Vector2(6, 4), false)
			step = 1
		1:
			_check("tap sur une unité : son escouade est sélectionnée", game.sel_squad == u_ref.squad_id, "sel_squad=%d" % game.sel_squad)
			_check("tremblement du doigt : caméra immobile", game.cam_target.is_equal_approx(cam_before))
			step = 15
		15:
			# 0.17 : deux touchers à moins de 0,32 s = double appui (« tous les mêmes à l'écran »).
			# Le 2e toucher LENT garde son sens « unité seule » : on attend donc au-delà du double appui.
			if Time.get_ticks_msec() / 1000.0 - game._last_tap_time < 0.45:
				return false
			var p := _screen_of(u_ref)
			_touch(0, p, true)
			_touch(0, p, false)
			step = 2
		2:
			_check("2e tap : l'unité seule est sélectionnée", game.sel_units == [u_ref.id] and game.sel_squad == -1, str(game.sel_units))
			ground_pt = Vector2(u_ref.pos.x - 4, u_ref.pos.y + 3)
			var sp: Vector2 = game.cam.unproject_position(Vector3(ground_pt.x, 0, ground_pt.y))
			_touch(0, sp, true)
			_touch(0, sp, false)
			step = 3
		3:
			_check("tap au sol : ordre direct à l'unité (reprise en main)", u_ref.direct and u_ref.order.get("type", "") == "move", "direct=%s ordre=%s" % [u_ref.direct, u_ref.order])
			_check("ordre : caméra immobile", game.cam_target.is_equal_approx(cam_before))
			var n_orders: int = game.world.replay.size()
			# tap sur le bouton Construire (interface) : aucun ordre de jeu
			var b: Control = game.hud.build_btn
			var c := b.get_global_rect().get_center()
			_touch(0, c, true)
			_touch(0, c, false)
			set_meta("n", n_orders)
			step = 4
		4:
			_check("tap sur l'interface : aucun ordre émis au sol", game.world.replay.size() == int(get_meta("n")), "%d -> %d" % [int(get_meta("n")), game.world.replay.size()])
			var p := Vector2(640, 300)
			cam_before = game.cam_target
			var n: int = game.world.replay.size()
			set_meta("n", n)
			_touch(0, p, true)
			for i in 6:
				_drag(0, p + Vector2(15 * (i + 1), 0), Vector2(15, 0))
			_touch(0, p + Vector2(90, 0), false)
			step = 5
		5:
			_check("glisser : la caméra se déplace", not game.cam_target.is_equal_approx(cam_before))
			_check("glisser : aucun ordre émis", game.world.replay.size() == int(get_meta("n")))
			var ok := true
			for r in results:
				ok = ok and r
			print("RÉSULTAT TACTILE : %s" % ("PASS" if ok else "FAIL"))
			quit(0 if ok else 1)
	return false
