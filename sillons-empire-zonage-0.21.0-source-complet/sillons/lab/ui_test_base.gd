extends SceneTree
## 0.17 — Base des recettes d'interface : vraie scène de jeu (campagne « deux systèmes »), vrais événements
## tactiles injectés (InputEventScreenTouch / InputEventScreenDrag), compteur de touchers par action.
var failures: int = 0
var checks: int = 0
var game
var touches_used: int = 0
var touch_table: Dictionary = {}
var seed_value: int = 17020

func _initialize() -> void:
	GameConfig.mode = "empire"
	GameConfig.seed_value = seed_value
	GameConfig.reduce_motion = true
	GameConfig.ui_sounds = false
	GameConfig.theme_mode = 0
	GameConfig.left_handed = false
	GameConfig.ui_scale = 1.0
	change_scene_to_file("res://game/game.tscn")
	_boot()

func _boot() -> void:
	for i in 14:
		await process_frame
	game = current_scene
	game.paused = true
	for w in game.campaign.worlds.values():
		w.ai_controllers.clear()
	await run()
	if checks == 0:
		failures += 1
		print("FAIL aucune vérification exécutée (erreur dans la recette)")
	print("%s=%s checks=%d failures=%d" % [result_key(), "PASS" if failures == 0 else "FAIL", checks, failures])
	if not touch_table.is_empty():
		print("TOUCH_TABLE " + JSON.stringify(touch_table))
	quit(0 if failures == 0 else 1)

func result_key() -> String:
	return "UI_RESULT"

func run() -> void:
	pass

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

# ---------------------------------------------------------------- gestes

func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	root.push_input(e, true)
	if pressed and index == 0:
		touches_used += 1

func drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	root.push_input(e, true)

func tap(pos: Vector2) -> void:
	touch(0, pos, true)
	touch(0, pos, false)
	await frames(2)

func hold(pos: Vector2, seconds: float) -> void:
	touch(0, pos, true)
	await wait(seconds)
	touch(0, pos, false)
	await frames(2)

func swipe(a: Vector2, b: Vector2, steps: int = 8) -> void:
	touch(0, a, true)
	await frames(1)
	var last: Vector2 = a
	for i in range(1, steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		drag(0, p, p - last)
		last = p
		await frames(1)
	touch(0, b, false)
	await frames(2)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func center_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func press(control: Control) -> void:
	await tap(center_of(control))

func button(text: String, prefix: bool = false) -> Button:
	for node in game.hud.root.find_children("*", "Button", true, false):
		var b: Button = node as Button
		if b.is_visible_in_tree() and (b.text == text or (prefix and b.text.begins_with(text))):
			return b
	return null

func screen(p: Vector2) -> Vector2:
	return game.cam.unproject_position(Vector3(p.x, 0.6, p.y))

func ground(p: Vector2) -> Vector2:
	return game.cam.unproject_position(Vector3(p.x, 0.0, p.y))

func spawn(kind: String, at: Vector2, count: int, new_squad: bool = true, team: int = 0) -> Array:
	var ids: Array = []
	for i in count:
		var r: Dictionary = game.world.issue({"t": "lab_spawn", "team": team, "unit": kind, "pos": [at.x + float(i % 4) * 1.2, at.y + float(i / 4) * 1.2], "new_squad": new_squad and i == 0})
		ids.append(int(r.get("id", -1)))
	return ids

func home() -> Vector2:
	return (game.world.team_buildings(0, "centre", true)[0] as SimWorld.Building).center

func count_touches(key: String, before: int, target: String) -> void:
	touch_table[key] = {"mesure": touches_used - before, "cible": target}

func free_cell(kind: String, near: Vector2, radius: int = 18) -> Vector2i:
	for r in range(3, radius):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c: Vector2i = Vector2i(int(near.x) + dx, int(near.y) + dy)
				if game.world.build_check(0, kind, c) == "":
					return c
	return Vector2i(-1, -1)
