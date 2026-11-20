extends SceneTree
## Contrats de la refonte : cache, LOD, animations, budgets, entrée tactile et état logique.
var frames: int = 0
var checks: int = 0
var failures: int = 0
var done: bool = false

func _initialize() -> void:
	GameConfig.mode = "lab"
	GameConfig.lab_path = "res://lab/scenarios/r04_delegation.json"
	GameConfig.visual_quality = 2
	change_scene_to_file("res://game/game.tscn")

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func count_nodes(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += count_nodes(child)
	return count

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 18 or done:
		return false
	done = true
	var game = current_scene
	game.paused = true
	var before: String = game.world.state_hash()
	var old: Node3D = Assets.build_building("centre", 0, 4)
	var compact: Node3D = TacticalModels.building("centre", 0, 4, 1)
	check("bâtiment de bibliothèque intégré", compact != null and compact.has_meta("library_asset"))
	if compact != null:
		print("NODE_COMPARISON legacy=%d compact=%d" % [count_nodes(old), count_nodes(compact)])
		check("architecture fusionnée réduit les nœuds", count_nodes(compact) < count_nodes(old))
		compact.free()
	old.free()
	var near_unit: Node3D = TacticalModels.unit("ouvrier", 0, 1, 0)
	var far_unit: Node3D = TacticalModels.unit("ouvrier", 0, 1, 1)
	check("personnage proche et LOD lointain disponibles", near_unit != null and far_unit != null)
	if near_unit != null and far_unit != null:
		check("LOD lointain sans AnimationPlayer", (far_unit.get_meta("players", []) as Array).is_empty())
		check("LOD lointain plus léger", count_nodes(far_unit) < count_nodes(near_unit))
		var players: Array = near_unit.get_meta("players", []) as Array
		check("animation proche conservée", not players.is_empty())
		TacticalModels.animate(near_unit, true, false, false, 3.6)
		if not players.is_empty():
			var animation: AnimationPlayer = players[0] as AnimationPlayer
			check("marche synchronisée à la vitesse", animation.current_animation == "walk" and is_equal_approx(animation.speed_scale, 1.5))
			TacticalModels.animate(near_unit, true, false, false, 3.6, false)
			check("pause : animation immobilisée", not animation.active)
			TacticalModels.animate(near_unit, true, false, false, 3.6, true)
			check("reprise : animation réactivée", animation.active)
		near_unit.free()
		far_unit.free()
	for key in Rules.BUILDINGS:
		var building: Node3D = TacticalModels.building(String(key), 0, int((Rules.BUILDINGS[key] as Dictionary)["size"]), 10, 1)
		if building != null:
			check("bâtiment %s respecte un âge disponible" % key, int(AssetLibrary.info(String(building.get_meta("library_asset"))).get("age", 99)) <= 10)
			building.free()
	for key in Rules.UNITS:
		var unit: Node3D = TacticalModels.unit(String(key), 0, 10, 1)
		check("unité %s conserve une représentation" % key, unit != null)
		if unit != null:
			unit.free()
	var ids: Array = AssetLibrary.ids()
	for i in 75:
		var model: Node3D = AssetLibrary.instantiate_compact(String(ids[i]), 2)
		check("fusion %d disponible" % i, model != null)
		if model != null:
			model.free()
	game.view.set_visual_lod(65.0, Vector2(48, 48))
	game.view.sync(1.0, 0.0)
	var visual_stats: Dictionary = game.view.visual_stats()
	check("unités éloignées rendues par lots", int(visual_stats["batched_units"]) > 0)
	check("lots régionaux bornés", int(visual_stats["batches"]) <= WorldView.MAX_FAR_BATCHES)
	check("instanciation GPU regroupe les unités", int(visual_stats["batches"]) < int(visual_stats["batched_units"]))
	print("BATCH_COMPARISON units=%d groups=%d" % [int(visual_stats["batched_units"]), int(visual_stats["batches"])])
	var stats: Dictionary = AssetLibrary.cache_stats()
	check("cache de scènes borné", int(stats["scenes"]) <= int(stats["limit"]))
	check("cache de maillages borné", int(stats["meshes"]) <= int(stats["limit"]))
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	game.set_visual_quality(0)
	check("profil économie : ombres coupées", not game.sun.shadow_enabled)
	check("profil économie : résolution 3D abaissée", game.get_viewport().scaling_3d_scale < 0.8)
	check("interface conserve sa résolution", game.get_viewport().get_visible_rect().size == viewport_size)
	game.set_visual_quality(2)
	game.mobile_perf.stage = 2
	game._apply_render_profile()
	check("surcharge : ombres désactivées", not game.sun.shadow_enabled)
	check("surcharge : échelle 3D bornée", game.get_viewport().scaling_3d_scale >= 0.6 and game.get_viewport().scaling_3d_scale < 1.0)
	game.touches[0] = Vector2(500, 300)
	game.press_time = 1.0
	game.pan_velocity = Vector3.ONE
	var canceled := InputEventScreenTouch.new()
	canceled.index = 0
	canceled.canceled = true
	canceled.pressed = false
	game._input(canceled)
	check("toucher annulé : aucun doigt bloqué", game.touches.is_empty() and game.press_time == 0.0)
	check("toucher annulé : inertie arrêtée", game.pan_velocity == Vector3.ZERO)
	game.touches[0] = Vector2(500, 300)
	game.dragging = true
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("perte du focus : état tactile nettoyé", game.touches.is_empty() and not game.dragging)
	game.hud._toggle_controls()
	game._back_action()
	check("retour de l’aide vers le menu parent", not game.hud.controls_panel.visible and game.hud.menu_panel.visible)
	game._back_action()
	check("retour suivant reprend la partie", not game.hud.menu_panel.visible and not game.paused)
	game.hud._toggle_build()
	game._back_action()
	check("retour ferme la construction", not UIMotion.is_open(game.hud.build_panel))
	game.hud._toggle_menu()
	game.hud.refresh(0.0)
	var build_button: Button = game.hud.build_btn
	for pressed in [true, false]:
		var tap := InputEventScreenTouch.new()
		tap.index = 4
		tap.pressed = pressed
		tap.position = build_button.get_global_rect().get_center()
		root.push_input(tap, true)
	check("menu modal bloque les boutons du terrain", not game.hud.build_panel.visible and game.hud.menu_panel.visible)
	game.hud._toggle_menu()
	game.hud.refresh(0.0)
	check("retour terrain retire le voile modal", not game.hud._modal_scrim.visible)
	check("refonte sans modification de simulation", game.world.state_hash() == before)
	print("REFONTE_VISUAL_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
	return false
