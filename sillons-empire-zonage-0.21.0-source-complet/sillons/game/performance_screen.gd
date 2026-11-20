extends Node
## Même scène de jeu et mêmes shaders ; seules les charges de laboratoire et l'interface de mesure diffèrent.
var game: Node3D
var recorder: AndroidPerfRecorder
var report: Dictionary = {}
var scenario: String = ""
var duration: float = 60.0
var warmup: float = 5.0
var active: bool = false
var suspended: bool = false
var _last_us: int = 0
var _next_switch: float = 20.0
var _switch_index: int = 0
var _startup_ms: float = 0.0
var _warm_elapsed: float = 0.0
var _old_config: Dictionary = {}
var _was_paused: bool = false
var _message: Label
var _metrics: Label
var _choices: VBoxContainer
var _results: TextEdit
var _duration_button: Button
var _copy_button: Button
var _stop_button: Button
var _quit_after: bool = false
var _starting: bool = false
var _interruptions: int = 0

func _ready() -> void:
	get_tree().quit_on_go_back = false
	_old_config = {"speed": GameConfig.sim_speed, "mode": GameConfig.mode, "ai": GameConfig.player_ai,
		"quality": GameConfig.visual_quality, "adaptive": GameConfig.adaptive_visuals}
	_build_ui()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument in args:
		if argument.begins_with("--perf-seconds="): duration = clampf(float(argument.get_slice("=", 1)), 1.0, 1800.0)
		elif argument.begins_with("--perf-warmup="): warmup = clampf(float(argument.get_slice("=", 1)), 0.0, 60.0)
		elif argument.begins_with("--perf-quality="): GameConfig.visual_quality = clampi(int(argument.get_slice("=", 1)), 0, 2)
		elif argument == "--perf-quit": _quit_after = true
	for argument in args:
		if argument.begins_with("--perf-auto="): start.call_deferred(argument.get_slice("=", 1))

func _button(caption: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = caption; button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	return button

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100; add_child(canvas)
	var root: Control = Control.new()
	root.theme = MobileUI.theme(); root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP; canvas.add_child(root)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(14, 14); panel.custom_minimum_size.x = 465; root.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	_message = Label.new(); _message.text = "RECETTE ANDROID · 0.15.1 R2"; column.add_child(_message)
	_metrics = Label.new(); _metrics.text = "Charges reproductibles · graine 15101\nRapports locaux ; température via ADB."
	_metrics.add_theme_font_size_override("font_size", 14); column.add_child(_metrics)
	_choices = VBoxContainer.new(); column.add_child(_choices)
	_choices.add_child(_button("Grande carte · trois mondes 256 × 256", start.bind("large")))
	_choices.add_child(_button("Trois fronts · 360 soldats ajoutés", start.bind("fronts")))
	_choices.add_child(_button("Batailles orbitales · 120 vaisseaux", start.bind("orbit")))
	_duration_button = _button("Durée : 60 s · toucher pour 10 minutes", _toggle_duration)
	_choices.add_child(_duration_button)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 14; bar.offset_right = -14; bar.offset_top = -68; bar.offset_bottom = -14; root.add_child(bar)
	_stop_button = _button("Arrêter et exporter", finish); _stop_button.disabled = true; bar.add_child(_stop_button)
	_copy_button = _button("Copier le rapport JSON", _copy_report); _copy_button.disabled = true; bar.add_child(_copy_button)
	bar.add_child(_button("Retour au menu", _return_menu))
	_results = TextEdit.new(); _results.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.offset_left = 505; _results.offset_right = -14; _results.offset_top = 14; _results.offset_bottom = -90
	_results.editable = false; _results.add_theme_font_size_override("font_size", 14); _results.hide(); root.add_child(_results)

func _toggle_duration() -> void:
	duration = 600.0 if duration < 600.0 else 60.0
	_duration_button.text = "Durée : %d s · toucher pour changer" % int(duration)

func start(kind: String) -> void:
	if active or _starting or kind not in AndroidPerfFixture.KINDS: return
	_starting = true; _choices.hide(); _results.hide(); _copy_button.disabled = true; _stop_button.disabled = true
	if game != null:
		remove_child(game); game.queue_free(); game = null
		await get_tree().process_frame
	_stop_button.disabled = false; scenario = kind; report.clear()
	var started: int = Time.get_ticks_usec()
	var campaign: StarCampaign = AndroidPerfFixture.build(kind)
	GameConfig.loaded_world = null; GameConfig.loaded_campaign = campaign
	GameConfig.mode = "skirmish"; GameConfig.sim_speed = 1.0; GameConfig.player_ai = false
	game = (load("res://game/game.tscn") as PackedScene).instantiate() as Node3D; add_child(game)
	game.set_process_input(false); game.set_process_unhandled_input(false)
	if kind == "orbit":
		game.enter_space_overview("orbit"); game.orbit_focus = Vector2(80, 46); game.orbit_zoom = 94.0; game._update_camera()
	else: game.focus(Vector2(32, 66) if kind == "fronts" else game.world.team_buildings(0, "centre", true)[0].center)
	_hide_game_ui()
	_startup_ms = float(Time.get_ticks_usec() - started) / 1000.0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	recorder = AndroidPerfRecorder.new(); _warm_elapsed = 0.0; _interruptions = 0; _next_switch = 20.0; _switch_index = 0
	_last_us = Time.get_ticks_usec(); active = true; _starting = false; suspended = false
	_message.text = "Préparation des shaders · " + kind

func _hide_game_ui() -> void:
	game.hud.hide()
	if game.strategic_hud != null: game.strategic_hud.hide()
	if game.region_navigation != null: game.region_navigation.hide()
	if game.orbit_hud != null: game.orbit_hud.hide()

func _process(_delta: float) -> void:
	if not active or suspended: return
	var now: int = Time.get_ticks_usec()
	var wall_delta: float = float(now - _last_us) / 1000000.0
	_last_us = now
	if _warm_elapsed < warmup:
		_warm_elapsed += wall_delta
		return
	if recorder.metadata.is_empty():
		var context: Dictionary = AndroidPerfFixture.counts(game.campaign)
		context.merge({"scenario": scenario, "seed": AndroidPerfFixture.SEED, "requested_s": duration,
			"warmup_s": _warm_elapsed, "startup_cpu_ms": _startup_ms, "quality": GameConfig.visual_quality,
			"adaptive": GameConfig.adaptive_visuals, "supply_chain": game.campaign.planets.supply_chain,
			"hud": "diagnostic overlay; game panels hidden", "debug_build": OS.is_debug_build()}, true)
		recorder.begin(context); recorder.interruptions = _interruptions; game.diagnostic_recorder = recorder
		return
	var counts: Dictionary = AndroidPerfFixture.counts(game.campaign)
	counts.merge({"tick": game.campaign.tick, "adaptive_stage": game.mobile_perf.stage,
		"scale_3d": get_viewport().scaling_3d_scale, "active_world": game.campaign.active}, true)
	recorder.record_frame(wall_delta, get_viewport(), counts)
	if recorder.elapsed >= _next_switch:
		_next_switch += 20.0; _switch_index += 1
		var body: String = StarCampaign.SECTORS[_switch_index % StarCampaign.SECTORS.size()]
		game.campaign.active = body; game._refresh_region_world()
		if scenario == "orbit":
			game.space_selected = body; game.enter_space_overview("orbit"); game.orbit_focus = Vector2(80, 46); game._update_camera()
		else: game.focus(Vector2(32, 66))
		_hide_game_ui()
	if not recorder.seconds.is_empty():
		var sample: Dictionary = recorder.seconds[-1]
		_message.text = "%s · %.0f / %.0f s" % [scenario.to_upper(), recorder.elapsed, duration]
		_metrics.text = "%.1f images/s · %d appels de dessin\nRSS : %s MiB · palier visuel %d\nUnités : %d · vaisseaux : %d\nChauffe : relevé externe requis" % [
			float(sample["fps"]), int(sample["draw_calls"]),
			str(snappedf(float(sample["rss_mib"]), 0.1)) if sample["rss_mib"] != null else "indisponible",
			game.mobile_perf.stage, int(counts["ground_units"]), int(counts["orbital_ships"])]
	if recorder.elapsed >= duration: finish()

func finish() -> void:
	if not active: return
	active = false; game.paused = true; game.diagnostic_recorder = null
	if recorder.metadata.is_empty(): recorder.begin({"scenario": scenario, "cancelled_during_warmup": true})
	recorder.interruptions = _interruptions; report = recorder.finish()
	report["final_counts"] = AndroidPerfFixture.counts(game.campaign); report["switches"] = _switch_index
	var suffix: String = Time.get_datetime_string_from_system(true).replace(":", "-") + "_" + str(Time.get_ticks_usec())
	var saved: Error = AndroidPerfRecorder.save_report(report, "user://mesures/perf_" + suffix + "_" + scenario + ".json")
	var latest: Error = AndroidPerfRecorder.save_report(report, "user://mesures/last_report.json")
	_message.text = "Rapport local enregistré" if saved == OK and latest == OK else "Enregistrement impossible · copier le rapport"
	_results.text = JSON.stringify(report, "  "); _results.show(); _choices.show(); _copy_button.disabled = false; _stop_button.disabled = true
	print("ANDROID_PERF_REPORT ", JSON.stringify(report))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	if _quit_after: get_tree().quit(0 if saved == OK and latest == OK else 1)

func _copy_report() -> void:
	if not report.is_empty(): DisplayServer.clipboard_set(JSON.stringify(report, "  ")); _message.text = "Rapport JSON copié"

func _return_menu() -> void:
	if active: finish()
	get_tree().change_scene_to_file("res://game/main_menu.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active and not suspended:
		suspended = true; _was_paused = game.paused; game.paused = true; _interruptions += 1; recorder.interruptions = _interruptions
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and active and suspended:
		suspended = false; game.paused = _was_paused; _last_us = Time.get_ticks_usec()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST: _return_menu.call_deferred()

func _exit_tree() -> void:
	GameConfig.sim_speed = float(_old_config.get("speed", 1.0)); GameConfig.mode = String(_old_config.get("mode", "skirmish"))
	GameConfig.player_ai = bool(_old_config.get("ai", false)); GameConfig.visual_quality = int(_old_config.get("quality", 1))
	GameConfig.adaptive_visuals = bool(_old_config.get("adaptive", true)); GameConfig.loaded_campaign = null; GameConfig.loaded_world = null
