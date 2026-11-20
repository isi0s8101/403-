extends Node3D
## Test technique « deux fronts » (J2). Deux cartes simulées en parallèle, une seule affichée.
## Mesure : temps de simulation par front, temps de rendu CPU/GPU, images/s, appels de dessin,
## mémoire, pics pendant un siège et lors d'une bascule de vue. Chaleur : relevé du capteur
## thermique quand le système le permet, sinon observation manuelle (cf. recette S25).
## Résultats : user://mesures/deux_fronts_<date>.json (et résumé à l'écran).
##
## Lancement automatique (sans menu) : godot -- --fronts-auto [--fronts-sec=40]

const SWITCH_EVERY := 10.0      # secondes entre deux bascules pendant le protocole
const MAX_STEPS := 3            # ticks rattrapés par image au maximum

var theater: Theater
var views: Array = [null, null]
var active := 0
var cam: Camera3D
var cam_targets := [Vector3(62, 0, 80), Vector3(26, 0, 36)]
var cam_dist := 34.0
var acc := 0.0

# protocole
var protocol := false
var protocol_levels: Array = []
var level_seconds := 40.0
var level_t := 0.0
var next_switch := SWITCH_EVERY
var samples: Array = []
var summaries: Array = []
var switch_events: Array = []
var _sec_acc := 0.0
var _sec := {}
var _pending_switch := false
var _switch_t0 := 0
var _dropped_ticks := 0
var _build_ms := 0.0
var _vp_rid: RID
var _thermal_path := ""
var started_at := ""
var out_path := ""

var ui: CanvasLayer
var info: Label
var status: Label

func _ready() -> void:
	started_at = Time.get_datetime_string_from_system().replace(":", "-")
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	_thermal_path = _find_thermal()
	_build_env()
	_build_ui()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--fronts-sec="):
			level_seconds = float(a.get_slice("=", 1))
	_load_level(40)
	if "--fronts-auto" in args:
		start_protocol()

# ------------------------------------------------------------------ mise en place

func _find_thermal() -> String:
	## Capteur thermique lisible sans droits (souvent refusé sur Android récent).
	for i in 12:
		var p := "/sys/class/thermal/thermal_zone%d/temp" % i
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null and f.get_as_text().strip_edges().is_valid_int():
				return p
	return ""

func _read_thermal() -> float:
	if _thermal_path == "":
		return -1.0
	var f := FileAccess.open(_thermal_path, FileAccess.READ)
	if f == null:
		return -1.0
	var v := float(f.get_as_text().strip_edges())
	return v / 1000.0 if v > 1000.0 else v

func _build_env() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.67, 0.71, 0.73)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.74, 0.74, 0.70)
	e.ambient_light_energy = 0.58
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -39, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 62.0
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 300.0
	add_child(cam)
	cam.current = true

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var theme_res := Theme.new()
	theme_res.default_font_size = 18
	var root := Control.new()
	root.theme = theme_res
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 20)
	v.add_child(status)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 16)
	v.add_child(info)
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -78
	bar.offset_bottom = -12
	bar.offset_left = 12
	bar.offset_right = -12
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	bar.add_child(_btn("Basculer de front", func(): request_switch()))
	for lvl in Theater.LOAD_LEVELS:
		var l: int = lvl
		bar.add_child(_btn("%d u." % l, _manual_level.bind(l)))
	bar.add_child(_btn("Protocole complet", func(): start_protocol()))
	bar.add_child(_btn("Exporter", func(): _export()))
	bar.add_child(_btn("Menu", func(): get_tree().change_scene_to_file("res://game/main_menu.tscn")))

func _manual_level(lvl: int) -> void:
	if not protocol:
		_load_level(lvl)

func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(120, 62)
	b.pressed.connect(cb)
	return b

func _load_level(lvl: int) -> void:
	for v in views:
		if v != null:
			if v.get_parent() != null:
				remove_child(v)
			v.queue_free()
	var t0 := Time.get_ticks_usec()
	theater = Theater.new()
	theater.build(lvl)
	views = []
	for i in 2:
		var wv := WorldView.new()
		add_child(wv)
		wv.setup(theater.world(i), 0)
		wv.set_visual_quality(GameConfig.visual_quality)
		views.append(wv)
	_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	active = 0
	remove_child(views[1])
	_update_camera()
	_sec = {}
	_sec_acc = 0.0
	_dropped_ticks = 0

func _update_camera() -> void:
	var tgt: Vector3 = cam_targets[active]
	var pitch := deg_to_rad(56.0)
	cam.position = tgt + Vector3(0, sin(pitch), cos(pitch)) * cam_dist
	cam.look_at(tgt, Vector3.UP)

# ------------------------------------------------------------------ bascule

func request_switch() -> void:
	_pending_switch = true

func _do_switch() -> void:
	## Une seule carte dans l'arbre de rendu à la fois : l'autre vue est détachée, sa simulation continue.
	_switch_t0 = Time.get_ticks_usec()
	remove_child(views[active])
	active = 1 - active
	add_child(views[active])
	views[active].sync(1.0, 0.0)
	views[active].update_fog_texture()
	_update_camera()
	var ms := (Time.get_ticks_usec() - _switch_t0) / 1000.0
	switch_events.append({"t": snappedf(level_t, 0.01), "level": theater.level, "to_front": active, "cpu_ms": snappedf(ms, 0.01),
		"tick": [theater.world(0).tick, theater.world(1).tick]})
	_sec["switched"] = true
	_sec["switch_cpu_ms"] = ms

# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	if _pending_switch:
		_pending_switch = false
		_do_switch()
	acc += delta
	var steps := 0
	var sim_frame := [0.0, 0.0]
	while acc >= Rules.DT and steps < MAX_STEPS:
		theater.step()
		sim_frame[0] += theater.sim_ms[0]
		sim_frame[1] += theater.sim_ms[1]
		_acc_tick(theater.sim_ms)
		acc -= Rules.DT
		steps += 1
	if acc >= Rules.DT:
		_dropped_ticks += int(acc / Rules.DT)
		acc = fmod(acc, Rules.DT)
	for i in 2:
		var ev := theater.take_events(i)
		if i == active:
			for e in ev:
				if e["type"] == "tir":
					views[i].shot_fx(e["from"], e["to"], bool(e.get("siege", false)))
	views[active].set_visual_lod(cam_dist, Vector2(cam_targets[active].x, cam_targets[active].z))
	views[active].sync(clampf(acc / Rules.DT, 0.0, 1.0), delta)
	_acc_frame(delta)
	if protocol:
		level_t += delta
		if level_t >= next_switch and level_t < level_seconds - 1.0:
			next_switch += SWITCH_EVERY
			request_switch()
		if level_t >= level_seconds:
			_finish_level()
	_refresh_ui()

func _acc_tick(ms: Array) -> void:
	for i in 2:
		var k := "sim%d" % i
		_sec[k + "_sum"] = float(_sec.get(k + "_sum", 0.0)) + ms[i]
		_sec[k + "_max"] = maxf(float(_sec.get(k + "_max", 0.0)), ms[i])
	_sec["ticks"] = int(_sec.get("ticks", 0)) + 1

func _acc_frame(delta: float) -> void:
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) + RenderingServer.get_frame_setup_time_cpu()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
	_sec["frames"] = int(_sec.get("frames", 0)) + 1
	_sec["frame_max"] = maxf(float(_sec.get("frame_max", 0.0)), delta * 1000.0)
	_sec["rcpu_sum"] = float(_sec.get("rcpu_sum", 0.0)) + cpu
	_sec["rcpu_max"] = maxf(float(_sec.get("rcpu_max", 0.0)), cpu)
	_sec["rgpu_sum"] = float(_sec.get("rgpu_sum", 0.0)) + gpu
	_sec["rgpu_max"] = maxf(float(_sec.get("rgpu_max", 0.0)), gpu)
	_sec["draw"] = maxf(float(_sec.get("draw", 0.0)), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_sec_acc += delta
	if _sec_acc >= 1.0:
		_sec_acc -= 1.0
		_flush_second()

func _flush_second() -> void:
	var ticks := maxi(1, int(_sec.get("ticks", 0)))
	var frames := maxi(1, int(_sec.get("frames", 0)))
	var s := {
		"t": snappedf(level_t, 0.1), "level": theater.level, "front_affiche": active,
		"unites": [theater.unit_count(0), theater.unit_count(1)],
		"siege": [theater.sieging(0), theater.sieging(1)],
		"sim_ms_moy": [snappedf(float(_sec.get("sim0_sum", 0.0)) / ticks, 0.01), snappedf(float(_sec.get("sim1_sum", 0.0)) / ticks, 0.01)],
		"sim_ms_max": [snappedf(float(_sec.get("sim0_max", 0.0)), 0.01), snappedf(float(_sec.get("sim1_max", 0.0)), 0.01)],
		"ticks": int(_sec.get("ticks", 0)), "ticks_perdus": _dropped_ticks,
		"rendu_cpu_ms_moy": snappedf(float(_sec.get("rcpu_sum", 0.0)) / frames, 0.01),
		"rendu_cpu_ms_max": snappedf(float(_sec.get("rcpu_max", 0.0)), 0.01),
		"rendu_gpu_ms_moy": snappedf(float(_sec.get("rgpu_sum", 0.0)) / frames, 0.01),
		"rendu_gpu_ms_max": snappedf(float(_sec.get("rgpu_max", 0.0)), 0.01),
		"ips": frames, "image_ms_max": snappedf(float(_sec.get("frame_max", 0.0)), 0.1),
		"appels_dessin_max": int(_sec.get("draw", 0)),
		"memoire_mo": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"memoire_video_mo": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"temperature_c": _read_thermal(),
		"bascule": bool(_sec.get("switched", false)),
	}
	_dropped_ticks = 0
	if protocol:
		samples.append(s)
	_sec = {}
	_last_sample = s

var _last_sample := {}

func _refresh_ui() -> void:
	var w0 := theater.world(0)
	status.text = "Deux fronts — charge %d u./front — affiché : %s%s" % [theater.level, "A (siège du gué)" if active == 0 else "B (bataille)",
		("  ·  protocole %ds/%ds" % [int(level_t), int(level_seconds)]) if protocol else ""]
	if _last_sample.is_empty():
		info.text = "mesure en cours…"
		return
	var s := _last_sample
	info.text = "t=%ds  unités A/B : %d / %d  siège A/B : %s / %s\nsimulation A/B : %.1f / %.1f ms (pic %.1f / %.1f)  ticks perdus : %d\nrendu CPU %.1f ms (pic %.1f)  GPU %.1f ms (pic %.1f)  %d i/s  image max %.0f ms\nappels de dessin %d  mémoire %.0f Mo  vidéo %.0f Mo  temp. %s" % [
		w0.tick / Rules.TICK_RATE, s["unites"][0], s["unites"][1], "oui" if s["siege"][0] else "non", "oui" if s["siege"][1] else "non",
		s["sim_ms_moy"][0], s["sim_ms_moy"][1], s["sim_ms_max"][0], s["sim_ms_max"][1], s["ticks_perdus"],
		s["rendu_cpu_ms_moy"], s["rendu_cpu_ms_max"], s["rendu_gpu_ms_moy"], s["rendu_gpu_ms_max"], s["ips"], s["image_ms_max"],
		s["appels_dessin_max"], s["memoire_mo"], s["memoire_video_mo"],
		("%.1f °C" % s["temperature_c"]) if s["temperature_c"] >= 0.0 else "capteur illisible : observer à la main"]

# ------------------------------------------------------------------ protocole et export

func start_protocol() -> void:
	protocol = true
	protocol_levels = Theater.LOAD_LEVELS.duplicate()
	samples = []
	summaries = []
	switch_events = []
	_start_next_level()

func _start_next_level() -> void:
	var lvl: int = protocol_levels.pop_front()
	_load_level(lvl)
	level_t = 0.0
	next_switch = SWITCH_EVERY
	summaries.append({"level": lvl, "construction_ms": snappedf(_build_ms, 0.1), "unites_depart": [theater.unit_count(0), theater.unit_count(1)]})

func _finish_level() -> void:
	var lvl := theater.level
	var mine := samples.filter(func(s): return s["level"] == lvl)
	var sm: Dictionary = summaries[summaries.size() - 1]
	sm.merge(_summarize(mine))
	sm["unites_fin"] = [theater.unit_count(0), theater.unit_count(1)]
	if protocol_levels.is_empty():
		protocol = false
		_export()
	else:
		_start_next_level()

static func _summarize(arr: Array) -> Dictionary:
	var out := {"secondes": arr.size()}
	if arr.is_empty():
		return out
	for i in 2:
		var moy := 0.0
		var mx := 0.0
		var mx_siege := 0.0
		for s in arr:
			moy += s["sim_ms_moy"][i]
			mx = maxf(mx, s["sim_ms_max"][i])
			if s["siege"][i]:
				mx_siege = maxf(mx_siege, s["sim_ms_max"][i])
		out["front%d_sim_ms_moy" % i] = snappedf(moy / arr.size(), 0.01)
		out["front%d_sim_ms_pic" % i] = mx
		out["front%d_sim_ms_pic_siege" % i] = mx_siege
	var rc := 0.0
	var rg := 0.0
	var rcm := 0.0
	var rgm := 0.0
	var ips_min := 9999
	var ips_moy := 0.0
	var mem := 0.0
	var vmem := 0.0
	var frame_switch := 0.0
	var frame_other := 0.0
	var dropped := 0
	var temp_max := -1.0
	for s in arr:
		rc += s["rendu_cpu_ms_moy"]
		rg += s["rendu_gpu_ms_moy"]
		rcm = maxf(rcm, s["rendu_cpu_ms_max"])
		rgm = maxf(rgm, s["rendu_gpu_ms_max"])
		ips_min = mini(ips_min, int(s["ips"]))
		ips_moy += s["ips"]
		mem = maxf(mem, s["memoire_mo"])
		vmem = maxf(vmem, s["memoire_video_mo"])
		dropped += int(s["ticks_perdus"])
		temp_max = maxf(temp_max, s["temperature_c"])
		if s["bascule"]:
			frame_switch = maxf(frame_switch, s["image_ms_max"])
		else:
			frame_other = maxf(frame_other, s["image_ms_max"])
	out["rendu_cpu_ms_moy"] = snappedf(rc / arr.size(), 0.01)
	out["rendu_cpu_ms_pic"] = rcm
	out["rendu_gpu_ms_moy"] = snappedf(rg / arr.size(), 0.01)
	out["rendu_gpu_ms_pic"] = rgm
	out["ips_moy"] = snappedf(ips_moy / arr.size(), 0.1)
	out["ips_min"] = ips_min
	out["memoire_mo_pic"] = mem
	out["memoire_video_mo_pic"] = vmem
	out["image_ms_pic_bascule"] = frame_switch
	out["image_ms_pic_hors_bascule"] = frame_other
	out["ticks_perdus"] = dropped
	out["temperature_c_max"] = temp_max
	return out

func _export() -> void:
	DirAccess.make_dir_recursive_absolute("user://mesures")
	out_path = "user://mesures/deux_fronts_%s.json" % started_at
	var doc := {
		"test": "deux_fronts", "version": ProjectSettings.get_setting("application/config/version"),
		"appareil": OS.get_model_name(), "os": OS.get_name() + " " + OS.get_version(),
		"processeur": OS.get_processor_name(), "coeurs": OS.get_processor_count(),
		"rendu": RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_video_adapter_api_version(),
		"ecran": str(DisplayServer.window_get_size()), "capteur_thermique": _thermal_path if _thermal_path != "" else "illisible",
		"date": started_at, "tick_rate": Rules.TICK_RATE, "secondes_par_niveau": level_seconds,
		"resume": summaries, "bascules": switch_events, "echantillons": samples,
	}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(doc, "  "))
		f.close()
	print("MESURES deux fronts écrites : ", ProjectSettings.globalize_path(out_path))
	status.text = "Mesures écrites : " + ProjectSettings.globalize_path(out_path)
	if "--fronts-auto" in OS.get_cmdline_user_args() and "--fronts-quit" in OS.get_cmdline_user_args():
		get_tree().quit()

# ------------------------------------------------------------------ caméra (glisser pour déplacer)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var t: Vector3 = cam_targets[active]
		var k := cam_dist / 600.0
		t.x = clampf(t.x - event.relative.x * k, 0.0, Rules.MAP_SIZE)
		t.z = clampf(t.z - event.relative.y * k, 0.0, Rules.MAP_SIZE)
		cam_targets[active] = t
		_update_camera()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var t2: Vector3 = cam_targets[active]
		var k2 := cam_dist / 600.0
		t2.x = clampf(t2.x - event.relative.x * k2, 0.0, Rules.MAP_SIZE)
		t2.z = clampf(t2.z - event.relative.y * k2, 0.0, Rules.MAP_SIZE)
		cam_targets[active] = t2
		_update_camera()

func _exit_tree() -> void:
	# la vue détachée n'appartient pas à l'arbre : la libérer explicitement
	for v in views:
		if v != null and is_instance_valid(v) and v.get_parent() == null:
			v.free()
