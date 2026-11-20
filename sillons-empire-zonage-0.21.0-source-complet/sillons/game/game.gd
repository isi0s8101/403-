extends Node3D
## Partie : boucle de simulation à pas fixe, caméra, gestes tactiles et ordres.
## Les gestes ne modifient la simulation que via SimWorld.issue().

const TAP_MAX_TIME := 0.35
const LONG_PRESS := 0.5
const PICK_RADIUS_PX := 34.0      # tolérance de sélection sur mobile
const PAN_DAMPING := 12.0
const ZOOM_LERP := 13.0
const MAX_SIM_STEPS_PER_FRAME := 12

var evolution_panel: EvolutionPanel
var civ_panel: CivPanel                # 0.16 : évolution de la civilisation
var city_panel: CityPanel              # 0.18 : ville de l'âge de l'électricité
var city_overlay: CityOverlay
var city_view: String = ""
var civ_power_key: String = ""          # pouvoir de commandement en attente de cible
var rally_producers: Array = []
var world: SimWorld
var campaign: StarCampaign
var planet_globe: PlanetGlobeView
var planet_hud: PlanetHud
var orbit_view: OrbitalBattleView
var orbit_hud: OrbitalBattleHud
var orbit_focus: Vector2 = Vector2(32,80)
var orbit_zoom: float = 110.0
var space_view: SpaceMapView
var space_hud: SpaceMapHud
var galaxy_view: GalaxyMapView
var galaxy_hud: GalaxyMapHud
var galaxy_selected: String = "sol"
var space_mode: String = ""
var space_selected: String = ""
var _space_touches: Dictionary = {}
var _space_touch_begin: Dictionary = {}
var _space_pinch_baseline: float = 0.0
var planet_mode: bool = false
var region_navigation: CanvasLayer
var region_info_label: Label
var _planet_dragging: bool = false
var _planet_touch_start: Vector2 = Vector2.ZERO
var _planet_last_pos: Vector2 = Vector2.ZERO
var _planet_touch_index: int = -1
var _planet_touches: Dictionary = {}
var _planet_pinch_start: float = 0.0
var strategic_hud: StrategicHud
var camera_sectors: Dictionary = {}
var scenario: LabScenario
var view: WorldView
var hud: Hud
var cam: Camera3D
var cam_target := Vector3(20, 0, 76)
var cam_dist := 24.0
var cam_yaw := 0.0
var portrait_view: bool = false        # 0.18 : écran tenu en portrait
var sun: DirectionalLight3D
var _shadows_user_preference: bool = true
var env: WorldEnvironment
var acc := 0.0
var speed := 1.0
var _bench_speed: float = -1.0
var _bench_recorded: bool = false
var _bench_elapsed: float = 0.0
var _bench_ticks: int = 0
var _bench_frame_ms: Array[float] = []
var paused := false
var sim_ms := 0.0
var diagnostic_recorder: AndroidPerfRecorder = null
var player := 0

# sélection
var sel_squad := -1
var sel_units: Array = []
var sel_building := -1
var mode := ""                   # "" | place | delegate
var place_type := ""
var place_cell := Vector2i(-1, -1)
var ghost: MeshInstance3D

# gestes
var touches := {}
var press_pos := Vector2.ZERO
var press_time := 0.0
var dragging := false
var long_fired := false
var pinch_start_dist := 0.0
var pinch_start_cam := 30.0
var drag_last := Vector2.ZERO
var drag_threshold_px := 18.0
var cam_zoom_goal := 24.0
var pan_velocity := Vector3.ZERO
var _frame_delta := 0.016
var mobile_perf: MobilePerfBudget = MobilePerfBudget.new()
var render_state: Dictionary = {}
var _applied_perf_stage: int = -1
var _overview_latched: bool = false
var pinch_start_yaw := 0.0
var pinch_start_angle := 0.0
var pinch_last_mid := Vector2.ZERO
var box_select_mode := false
var box_start := Vector2.ZERO
var box_end := Vector2.ZERO
# 0.17 : gestes et commandes « grand RTS » au pouce.
const DOUBLE_TAP := 0.32
var add_mode: bool = false                 # sélection additive (bouton +)
var gesture_box: bool = false              # rectangle sans bouton (glissé depuis une unité, ou appui long puis glissé)
var _press_on_unit: bool = false
var _last_tap_time: float = -10.0
var _last_tap_pos: Vector2 = Vector2(-999, -999)
var _last_tap_type: String = ""
var power_preview: Vector2 = Vector2.ZERO
var _power_drag: bool = false
var rally_resource_building: int = -1
var queue_edit_point: Dictionary = {}
var path_view: OrderPathView
var placement_tool: PlacementTool
var _line_drag: bool = false
var zoning_tool: ZoningTool             # 0.19 : mode Zonage (pinceau, rectangle, parcelle, routes)
var _zone_drag: bool = false
var _income_samples: Array = []
var _income_t: float = 0.0
var follow_selection: bool = false      # la caméra suit la sélection (bascule « Suivre » de la carte)

func set_simulation_speed(multiplier: float) -> void:
	if not GameConfig.SPEED_LEVELS.has(multiplier):
		return
	speed = multiplier
	GameConfig.sim_speed = multiplier
	if hud != null:
		hud._refresh_speed_caption()
	_bench_speed = -1.0
	_bench_recorded = false

func _ready() -> void:
	Engine.max_fps = 60
	get_tree().quit_on_go_back = false
	speed = GameConfig.sim_speed if GameConfig.SPEED_LEVELS.has(GameConfig.sim_speed) else 1.0
	world = null
	if GameConfig.loaded_campaign != null:
		campaign = GameConfig.loaded_campaign
		GameConfig.loaded_campaign = null
		world = campaign.current()
	elif GameConfig.loaded_world != null:
		world = GameConfig.loaded_world
		GameConfig.loaded_world = null
		if GameConfig.mode != "lab":
			campaign = StarCampaign.new()
			campaign.adopt_legacy(world)
	elif GameConfig.mode == "lab" and GameConfig.lab_path != "":
		scenario = LabScenario.load_file(GameConfig.lab_path)
		world = scenario.build()
	else:
		var sd := GameConfig.seed_value if GameConfig.seed_value != 0 else int(Time.get_unix_time_from_system()) % 100000
		campaign = StarCampaign.new()
		if GameConfig.mode == "empire": CampaignSetup.create(campaign, sd, GameConfig.player_ai, GameConfig.map_dimension)
		else: campaign.create(sd, GameConfig.player_ai, GameConfig.mode == "planet_j9", GameConfig.planet_lon, GameConfig.planet_lat)
		# J13.1 : économie complète sur les nouvelles parties (réglable dans GameConfig).
		if GameConfig.supply_chain:
			campaign.enable_supply_chain()
		world = campaign.current()
	if campaign!=null and GameConfig.mode!="lab": OrbitalTactics.enable(campaign)
	var ccs := world.team_buildings(player, "centre")
	if not ccs.is_empty():
		cam_target = Vector3(ccs[0].center.x + 3, 0, ccs[0].center.y - 3)
	# seuil de glissement adapté à la densité d'écran (≈ 3 mm)
	var dpi := DisplayServer.screen_get_dpi()
	if dpi > 0:
		drag_threshold_px = max(14.0, dpi * 0.12 * _ui_scale_inv())
	_build_environment()
	_apply_sector_atmosphere()
	view = WorldView.new()
	add_child(view)
	view.setup(world, player)
	view.set_visual_quality(GameConfig.visual_quality)
	_apply_render_profile()
	ghost = MeshInstance3D.new()
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = gm
	ghost.mesh = BoxMesh.new()
	ghost.visible = false
	add_child(ghost)
	path_view = OrderPathView.new()
	add_child(path_view)
	path_view.setup(self)
	city_overlay = CityOverlay.new()
	add_child(city_overlay)
	city_overlay.setup(self)
	placement_tool = PlacementTool.new()
	add_child(placement_tool)
	placement_tool.setup(self)
	zoning_tool = ZoningTool.new()
	add_child(zoning_tool)
	zoning_tool.setup(self)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	hud.control_groups.load_for(world.seed_value, world.tick)
	if not GameConfig.recovery_notice.is_empty():
		hud.set_hint(GameConfig.recovery_notice)
		GameConfig.recovery_notice = ""
	if campaign != null:
		strategic_hud = StrategicHud.new()
		add_child(strategic_hud)
		strategic_hud.setup(self)
	if campaign != null and campaign.evolutions_enabled:
		evolution_panel = EvolutionPanel.new()
		hud.root.add_child(evolution_panel)
		evolution_panel.setup(self)
		hud._ui_blockers.append(evolution_panel)
	if CivEvolution.enabled(world):
		civ_panel = CivPanel.new()
		hud.root.add_child(civ_panel)
		civ_panel.setup(self)
		hud._ui_blockers.append(civ_panel)
	if UrbanCity.enabled(world):
		city_panel = CityPanel.new()
		hud.root.add_child(city_panel)
		city_panel.setup(self)
		hud._ui_blockers.append(city_panel)
	cam_zoom_goal = cam_dist
	_build_region_navigation()
	_update_camera()

func apply_orientation(portrait: bool) -> void:
	## 0.18 : en portrait, l'angle de vue est tenu en largeur (même étendue de terrain visible de gauche à droite).
	portrait_view = portrait
	if cam != null:
		cam.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
		_update_camera()

func _ui_scale_inv() -> float:
	var vp := get_viewport()
	var real := DisplayServer.window_get_size()
	if real.y <= 0:
		return 1.0
	return float(vp.get_visible_rect().size.y) / float(real.y)

func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.43, 0.66)
	sm.sky_horizon_color = Color(0.77, 0.79, 0.75)
	sm.ground_bottom_color = Color(0.21, 0.19, 0.15)
	sm.ground_horizon_color = Color(0.64, 0.61, 0.55)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.48
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.05
	e.fog_enabled = true
	e.fog_light_color = Color(0.71, 0.73, 0.70)
	e.fog_density = 0.0018
	e.fog_sun_scatter = 0.12
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 62.0
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 2.0
	sun.light_angular_distance = 0.7
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.near = 0.5
	cam.far = 300.0
	add_child(cam)
	cam.current = true

func _apply_sector_atmosphere() -> void:
	if campaign == null or env == null:
		return
	var sky: ProceduralSkyMaterial = env.environment.sky.sky_material as ProceduralSkyMaterial
	match campaign.active:
		"aurore":
			sky.sky_top_color = Color(0.42, 0.40, 0.58)
			sky.sky_horizon_color = Color(0.88, 0.72, 0.61)
			sun.light_color = Color(1.0, 0.85, 0.67)
		"nemesis":
			sky.sky_top_color = Color(0.12, 0.20, 0.35)
			sky.sky_horizon_color = Color(0.42, 0.56, 0.64)
			sun.light_color = Color(0.72, 0.84, 1.0)
		_:
			sky.sky_top_color = Color(0.25, 0.43, 0.66)
			sky.sky_horizon_color = Color(0.77, 0.79, 0.75)
			sun.light_color = Color(1.0, 0.94, 0.82)

func _space_environment(enabled: bool) -> void:
	if env == null or env.environment == null:
		return
	var environment: Environment = env.environment
	environment.background_mode = Environment.BG_COLOR if enabled else Environment.BG_SKY
	environment.background_color = Color(0.008, 0.017, 0.035)
	environment.fog_enabled = not enabled
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if enabled else Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.19, 0.27, 0.38) if enabled else Color.WHITE
	sun.light_energy = 1.15 if enabled else 0.95

func _update_camera() -> void:
	if space_mode=="orbit" and orbit_view!=null:
		var shift:float=orbit_zoom*0.325 if orbit_hud!=null and UIMotion.is_open(orbit_hud.drawer) else 0.0
		var focus:=Vector3(orbit_focus.x-32+shift,0,orbit_focus.y-32)
		cam.far=500
		cam.position=focus+Vector3(0,orbit_zoom,orbit_zoom*0.26)
		cam.look_at(focus,Vector3.UP)
		return
	if space_mode != "":
		var height: float = 340.0 if space_mode == "galaxy" else 300.0
		cam.far = 800.0 if space_mode == "galaxy" else 350.0
		cam.position = Vector3(48.0, height, 78.0 + height * 0.10)
		cam.look_at(Vector3(48.0, 0.0, 78.0), Vector3.UP)
		return
	if planet_mode:
		cam.position = Vector3(48.0, 12.0, 125.0)
		cam.look_at(Vector3(48.0, 0.0, 48.0), Vector3.UP)
		return
	cam_dist = clampf(cam_dist, 12.0, 70.0)
	cam_target.x = clampf(cam_target.x, 0.0, world.map_size)
	cam_target.z = clampf(cam_target.z, 0.0, world.map_size)
	var pitch_deg: float = lerpf(48.0, 62.0, (cam_dist - 12.0) / 58.0)
	if portrait_view:
		pitch_deg = minf(pitch_deg + 18.0, 80.0) # 0.18 : écran haut, vue plus plongeante (le terrain remplit l'écran)
	var pitch := deg_to_rad(pitch_deg)
	var offset := Vector3(0, sin(pitch), cos(pitch)) * cam_dist
	offset = offset.rotated(Vector3.UP, cam_yaw)
	cam.position = cam_target + offset
	cam.look_at(cam_target, Vector3.UP)

func _process(delta: float) -> void:
	_frame_delta = maxf(0.001, delta)
	if GameConfig.adaptive_visuals:
		mobile_perf.observe(delta)
	if _applied_perf_stage != mobile_perf.stage:
		_apply_render_profile()
	if cam_zoom_goal < 65.0:
		_overview_latched = false
	if not _overview_latched and not planet_mode and space_mode == "" and cam_zoom_goal >= 69.0 and cam_dist >= 63.0 and campaign != null:
		_overview_latched = true
		enter_planet_overview()
	# Mouvement cinétique court, décroissance indépendante du nombre d'images.
	# La simulation reste à pas fixe ; seule la caméra bénéficie de l'interpolation.
	if touches.is_empty() and not paused and not box_select_mode and pan_velocity.length_squared() > 0.0001:
		cam_target += pan_velocity * delta
		pan_velocity *= exp(-PAN_DAMPING * delta)
		_update_camera()
	if absf(cam_zoom_goal - cam_dist) > 0.005:
		cam_dist = lerpf(cam_dist, cam_zoom_goal, 1.0 - exp(-ZOOM_LERP * delta))
		_update_camera()
	if not paused:
		acc += delta * speed
		var steps := 0
		while acc >= Rules.DT and steps < MAX_SIM_STEPS_PER_FRAME:
			var t0 := Time.get_ticks_usec()
			if scenario != null:
				scenario.step()
			elif campaign != null:
				campaign.step()
			else:
				world.step()
			var tick_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
			sim_ms = lerpf(sim_ms, tick_ms, 0.1)
			if diagnostic_recorder != null:
				diagnostic_recorder.record_tick(tick_ms)
			acc -= Rules.DT
			steps += 1
		if steps >= MAX_SIM_STEPS_PER_FRAME and acc >= Rules.DT:
			# Ne pas lancer une spirale de rattrapage sous surcharge CPU mobile.
			# La simulation reste déterministe par tick ; ralentissement effectif
			# possible lorsque la cadence demandée excède le budget disponible.
			acc = minf(acc, Rules.DT)
		_sample_speed(delta, steps)
	if campaign != null and campaign.current() != world:
		_refresh_region_world()
	_consume_events()
	if space_mode == "galaxy" and galaxy_view != null:
		galaxy_view.refresh_tick_budget = mobile_perf.galaxy_refresh_ticks
		galaxy_view.refresh_sim()
		if galaxy_hud != null:
			galaxy_hud.refresh()
	elif space_mode=="orbit" and orbit_view!=null:
		orbit_view.sync(clampf(acc/Rules.DT,0,1))
	elif space_mode != "" and space_view != null:
		space_view.refresh_sim()
		if space_hud != null:
			space_hud.refresh()
	if not planet_mode and space_mode == "":
		view.set_visual_lod(cam_dist + mobile_perf.terrain_lod_bias, Vector2(cam_target.x, cam_target.z))
		_sync_rally_flag()
	if not planet_mode and space_mode == "":
		view.sync(clampf(acc / Rules.DT, 0.0, 1.0), 0.0 if paused else delta)
	_update_ghost()
	_sample_income(delta)
	if follow_selection and touches.is_empty() and has_command_selection() and not planet_mode and space_mode == "":
		var target: Vector2 = selection_world_center()
		cam_target = cam_target.lerp(Vector3(target.x, 0, target.y), 1.0 - exp(-6.0 * delta))
		_update_camera()
	# appui long
	if touches.size() == 1 and not box_select_mode and not dragging and not long_fired and press_time > 0.0:
		if Time.get_ticks_msec() / 1000.0 - press_time > LONG_PRESS:
			long_fired = true
			_long_press(press_pos)
	hud.refresh(delta)
	if strategic_hud != null:
		strategic_hud.refresh(delta)

func _sample_speed(delta: float, executed_ticks: int) -> void:
	# Benchmark réel sur la partie en cours (pas une injection manuelle de _process).
	# 15 s par vitesse, p95/p99 et débit de ticks pour révéler la saturation à ×8.
	if paused or delta <= 0.0:
		return
	if not is_equal_approx(_bench_speed, speed):
		_bench_speed = speed
		_bench_elapsed = 0.0
		_bench_ticks = 0
		_bench_frame_ms.clear()
		_bench_recorded = false
	if _bench_recorded:
		return
	_bench_elapsed += delta
	_bench_ticks += executed_ticks
	_bench_frame_ms.append(delta * 1000.0)
	if _bench_elapsed < 15.0:
		return
	_bench_frame_ms.sort()
	var n: int = _bench_frame_ms.size()
	var slow_frames: int = 0
	for frame_ms in _bench_frame_ms:
		if frame_ms > 33.3:
			slow_frames += 1
	var p95: float = _bench_frame_ms[clampi(int(ceil(n * 0.95)) - 1, 0, n - 1)]
	var p99: float = _bench_frame_ms[clampi(int(ceil(n * 0.99)) - 1, 0, n - 1)]
	var ticks_per_second: float = float(_bench_ticks) / _bench_elapsed
	var nominal: float = float(Rules.TICK_RATE) * speed
	var key: String = "x%s" % str(speed).replace(".0", "")
	GameConfig.speed_benchmarks[key] = {
		"duration_s": snappedf(_bench_elapsed, 0.001),
		"avg_fps": snappedf(float(n) / _bench_elapsed, 0.01),
		"p95_frame_ms": snappedf(p95, 0.01),
		"p99_frame_ms": snappedf(p99, 0.01),
		"frames_over_33ms": slow_frames,
		"jank_ratio_over_33ms": snappedf(float(slow_frames) / float(n), 0.001),
		"ticks_per_second": snappedf(ticks_per_second, 0.01),
		"requested_ticks_per_second": nominal,
		"delivered_ratio": snappedf(ticks_per_second / nominal, 0.001),
		"godot_static_memory_mb": snappedf(float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0, 0.1),
		"sector": campaign.active if campaign != null else "single",
		"recorded_at_utc": Time.get_datetime_string_from_system(true),
	}
	# Une seule fenêtre de mesure par vitesse : repasser à 1× puis 8× relance la mesure.
	_bench_recorded = true
	if hud != null:
		hud.set_hint("Mesures %s enregistrées : FPS moyen %.0f · p99 %.1f ms · ticks/s %.1f" % [key, float(n) / _bench_elapsed, p99, ticks_per_second])

func _consume_events() -> void:
	for e in world.events:
		if e["type"] == "tir":
			if world.is_visible_to(player, e["from"]) or world.is_visible_to(player, e["to"]):
				view.shot_fx(e["from"], e["to"], bool(e.get("siege", false)))
			if hud.alerts != null and int(e["team"]) != player:
				hud.alerts.on_event(e)    # 0.17 : attaque repérée → alerte et signal sur la mini-carte
			continue
		hud.on_event(e)
	world.events.clear()

# ------------------------------------------------------------------ entrées tactiles

var _ignored := {}

func _unhandled_input(event: InputEvent) -> void:
	if space_mode != "":
		_handle_space_input(event)
		return
	if planet_mode:
		_handle_planet_input(event)
		return
	if hud.menu_panel.visible or hud.over_panel.visible or hud.controls_panel.visible:
		return
	if OS.has_environment("SILLONS_DEBUG_INPUT"):
		print("input ", event)
	if event is InputEventScreenTouch and event.pressed and (hud.is_over_ui(event.position) or (strategic_hud != null and strategic_hud.is_over_ui(event.position))):
		_ignored[event.index] = true
		return
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and _ignored.has(event.index):
		if event is InputEventScreenTouch and not event.pressed:
			_ignored.erase(event.index)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				press_pos = event.position
				drag_last = event.position
				press_time = Time.get_ticks_msec() / 1000.0
				dragging = false
				long_fired = false
				gesture_box = false
				_power_drag = false
				_line_drag = false
				pan_velocity = Vector3.ZERO
				var touched = _pick(event.position) if mode == "" and not box_select_mode else null
				_press_on_unit = touched is SimWorld.Unit and touched.team == player
				if box_select_mode:
					box_start = event.position
					box_end = event.position
				if mode == "civ_power":
					power_preview = screen_to_ground(event.position)
					_power_drag = true
				if mode == "place" and placement_tool.line_mode:
					placement_tool.begin_line(screen_to_ground(event.position))
					_line_drag = true
				_zone_drag = false
				if mode == "zone" and zoning_tool != null and zoning_tool.active:
					zoning_tool.begin(screen_to_ground(event.position))
					_zone_drag = true
			elif touches.size() == 2:
				# On ne mélange jamais un geste à deux doigts avec une sélection.
				if box_select_mode:
					box_select_mode = false
					hud.set_select_mode(false)
				# Un pincement annule tout geste à un doigt en cours (rectangle, visée, ligne).
				gesture_box = false
				_power_drag = false
				_line_drag = false
				if _zone_drag:
					_zone_drag = false
					zoning_tool.cancel()
				hud.show_selection_rect(Vector2.ZERO, Vector2.ZERO, false)
				var pts: Array = touches.values()
				pinch_start_dist = pts[0].distance_to(pts[1])
				pinch_start_cam = cam_zoom_goal
				pinch_start_yaw = cam_yaw
				pinch_start_angle = (pts[1] - pts[0]).angle()
				pinch_last_mid = (pts[0] + pts[1]) * 0.5
				dragging = true
				pan_velocity = Vector3.ZERO
		else:
			var was_single: bool = touches.size() == 1
			if was_single and gesture_box:
				var gesture_rect := Rect2(press_pos, event.position - press_pos).abs()
				gesture_box = false
				hud.show_selection_rect(Vector2.ZERO, Vector2.ZERO, false)
				if gesture_rect.size.length() >= drag_threshold_px:
					_select_rectangle(gesture_rect)
				touches.erase(event.index)
				if touches.is_empty():
					press_time = 0.0
					dragging = false
				return
			if was_single and _power_drag and mode == "civ_power" and dragging:
				_power_drag = false
				touches.erase(event.index)
				_cast_power(power_preview)
				if touches.is_empty():
					press_time = 0.0
					dragging = false
				return
			if was_single and _zone_drag and mode == "zone":
				_zone_drag = false
				zoning_tool.end(screen_to_ground(event.position), dragging)
				hud.zoning_panel.refresh()
				touches.erase(event.index)
				if touches.is_empty():
					press_time = 0.0
					dragging = false
				return
			if was_single and _line_drag and mode == "place":
				_line_drag = false
				placement_tool.end_line()
				hud.placement_changed()
				touches.erase(event.index)
				if touches.is_empty():
					press_time = 0.0
					dragging = false
				return
			var was_box: bool = box_select_mode
			if was_box and was_single:
				var selection_rect := Rect2(box_start, box_end - box_start).abs()
				if selection_rect.size.length() >= drag_threshold_px:
					_select_rectangle(selection_rect)
				box_select_mode = false
				hud.set_select_mode(false)
			touches.erase(event.index)
			if touches.size() == 1 and not was_single:
				drag_last = touches.values()[0]
				dragging = true
				pan_velocity = Vector3.ZERO
			if was_single and not was_box and not dragging and not long_fired:
				if not hud.radial_open and Time.get_ticks_msec() / 1000.0 - press_time <= TAP_MAX_TIME + 0.4:
					if not _double_tap(event.position):
						_tap(event.position)
			if touches.is_empty():
				press_time = 0.0
				dragging = false
	elif event is InputEventScreenDrag:
		if not touches.has(event.index):
			return
		touches[event.index] = event.position
		if touches.size() == 1:
			if box_select_mode:
				box_end = event.position
				hud.show_selection_rect(box_start, box_end, true)
				dragging = true
				return
			if _power_drag and mode == "civ_power":
				power_preview = screen_to_ground(event.position)
				if event.position.distance_to(press_pos) > drag_threshold_px:
					dragging = true
				return
			if _zone_drag and mode == "zone":
				zoning_tool.drag(screen_to_ground(event.position))
				if event.position.distance_to(press_pos) > drag_threshold_px:
					dragging = true
				return
			if _line_drag and mode == "place":
				placement_tool.drag_line(screen_to_ground(event.position))
				dragging = true
				hud.placement_changed()
				return
			if gesture_box:
				hud.show_selection_rect(press_pos, event.position, true)
				return
			if not dragging and event.position.distance_to(press_pos) > drag_threshold_px:
				# Rectangle sans bouton : glissé démarré sur une unité alliée, ou appui long puis glissé.
				if mode == "" and (_press_on_unit or long_fired):
					if hud.radial_open:
						hud.close_radial()
					gesture_box = true
					dragging = true
					hud.show_selection_rect(press_pos, event.position, true)
					return
				dragging = true
			if dragging:
				_pan(event.position - drag_last, true)
				drag_last = event.position
		elif touches.size() == 2:
			var pts: Array = touches.values()
			var d: float = pts[0].distance_to(pts[1])
			if pinch_start_dist > 10.0:
				cam_zoom_goal = clampf(pinch_start_cam * pinch_start_dist / maxf(10.0, d), 12.0, 70.0)
			# Rotation : un delta angulaire cumulé par rapport au début, sans saut à +/- PI.
			var a: float = (pts[1] - pts[0]).angle()
			cam_yaw = pinch_start_yaw + wrapf(a - pinch_start_angle, -PI, PI)
			var mid: Vector2 = (pts[0] + pts[1]) * 0.5
			_pan(mid - pinch_last_mid, false)
			pinch_last_mid = mid
			_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom_goal = clampf(cam_zoom_goal * 0.9, 12.0, 70.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom_goal = clampf(cam_zoom_goal * 1.1, 12.0, 70.0)

func view_status(level: String) -> Dictionary:
	if campaign == null:
		return {"ok": level == "tactical", "reason": "Campagne nécessaire", "label": level}
	var techs: Dictionary = campaign.technologies[player] as Dictionary
	return ViewTechnology.get_status(int(campaign.ages[player]), techs, level)

func can_open_view(level: String) -> bool:
	return bool(view_status(level)["ok"])

func _require_view(level: String) -> bool:
	var result: Dictionary = view_status(level)
	if bool(result["ok"]):
		return true
	if hud != null:
		hud.set_hint(String(result["reason"]))
	return false

func enter_planet_overview() -> void:
	if planet_mode or campaign == null:
		return
	if not _require_view("planet"):
		cam_zoom_goal = 61.0
		return
	if space_mode != "":
		leave_space_overview(false)
	_space_environment(true)
	planet_mode = true
	touches.clear()
	_ignored.clear()
	planet_hud = null
	planet_globe = null
	pan_velocity = Vector3.ZERO
	mode = ""
	clear_selection()
	ghost.visible = false
	view.visible = false
	hud.visible = false
	if strategic_hud != null:
		strategic_hud.visible = false
	if region_navigation != null:
		region_navigation.visible = false
	planet_globe = PlanetGlobeView.new()
	add_child(planet_globe)
	var seed: int = int(world.rules.get("planet_master_seed", world.seed_value))
	planet_globe.setup(seed)
	if campaign != null:   # J13.2 : zones, équipements et routes de la colonie en 3D sur le globe
		planet_globe.bind_campaign(campaign, player)
	planet_hud = PlanetHud.new()
	add_child(planet_hud)
	planet_hud.setup(self)
	_update_camera()

func leave_planet_overview() -> void:
	if not planet_mode:
		return
	planet_mode = false
	_space_environment(false)
	_planet_touch_index = -1
	_planet_touches.clear()
	_planet_pinch_start = 0.0
	touches.clear()
	_planet_dragging = false
	if planet_hud != null:
		planet_hud.queue_free()
		planet_hud = null
	if planet_globe != null:
		planet_globe.queue_free()
		planet_globe = null
	hud.visible = true
	view.visible = true
	if strategic_hud != null:
		strategic_hud.visible = true
	if region_navigation != null:
		region_navigation.visible = true
	cam_dist = 56.0
	cam_zoom_goal = 43.0
	_update_camera()
	hud.set_hint("Retour au terrain · dézoomer complètement pour retrouver la planète")

func _handle_planet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			leave_planet_overview()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			enter_space_overview("orbit")
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			if planet_hud != null and planet_hud.is_over_ui(event.position):
				return
			_planet_touches[event.index] = event.position
			if _planet_touches.size() == 1:
				_planet_touch_index = event.index
				_planet_touch_start = event.position
				_planet_last_pos = event.position
				_planet_dragging = false
			elif _planet_touches.size() == 2:
				var points: Array = _planet_touches.values()
				_planet_pinch_start = (points[0] as Vector2).distance_to(points[1] as Vector2)
				_planet_dragging = true
		else:
			_planet_touches.erase(event.index)
			if _planet_touch_index == event.index and not _planet_dragging and planet_globe != null:
				var hit: Dictionary = planet_globe.pick(cam, event.position)
				if planet_hud != null:
					planet_hud.update_region(hit)
			_planet_touch_index = -1
	elif event is InputEventScreenDrag and _planet_touches.has(event.index):
		_planet_touches[event.index] = event.position
		if _planet_touches.size() >= 2 and _planet_pinch_start > 10.0:
			var points: Array = _planet_touches.values()
			var distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
			if distance > _planet_pinch_start * 1.26:
				leave_planet_overview()
			elif distance < _planet_pinch_start * 0.78:
				enter_space_overview("orbit")
			return
		if event.index == _planet_touch_index:
			if event.position.distance_to(_planet_touch_start) > 10.0:
				_planet_dragging = true
			if _planet_dragging and planet_globe != null:
				planet_globe.drag_rotate(event.position - _planet_last_pos)
			_planet_last_pos = event.position


func enter_space_overview(level: String) -> void:
	if campaign == null or level not in ["orbit", "system", "galaxy"]:
		return
	if not _require_view(level):
		return
	if space_mode == "" or not campaign.star_catalog.has_body(space_selected):
		space_selected = campaign.active
	if level == "galaxy":
		galaxy_selected = String(campaign.star_catalog.info(space_selected)["system_id"])
	if planet_mode:
		planet_mode = false
		_planet_touches.clear()
		_planet_touch_index = -1
		if planet_hud != null:
			planet_hud.queue_free()
			planet_hud = null
		if planet_globe != null:
			planet_globe.queue_free()
			planet_globe = null
	if orbit_hud!=null:
		orbit_hud.queue_free();orbit_hud=null
	if orbit_view!=null:
		orbit_view.queue_free();orbit_view=null
	if space_hud != null:
		space_hud.queue_free()
		space_hud = null
	if space_view != null:
		space_view.queue_free()
		space_view = null
	if galaxy_hud != null:
		galaxy_hud.queue_free()
		galaxy_hud = null
	if galaxy_view != null:
		galaxy_view.queue_free()
		galaxy_view = null
	space_mode = level
	_space_environment(true)
	_space_touches.clear()
	_space_touch_begin.clear()
	_space_pinch_baseline = 0.0
	touches.clear()
	_ignored.clear()
	pan_velocity = Vector3.ZERO
	mode = ""
	clear_selection()
	ghost.visible = false
	view.visible = false
	hud.visible = false
	if strategic_hud != null:
		strategic_hud.visible = false
	if region_navigation != null:
		region_navigation.visible = false
	if level=="orbit":
		orbit_view=OrbitalBattleView.new();add_child(orbit_view)
		orbit_view.setup(campaign,space_selected,player)
		orbit_focus=OrbitalTactics.anchor(player);orbit_zoom=110
		orbit_hud=OrbitalBattleHud.new();add_child(orbit_hud);orbit_hud.setup(self)
	elif level == "galaxy":
		galaxy_view = GalaxyMapView.new()
		add_child(galaxy_view)
		galaxy_view.setup(campaign, player)
		galaxy_hud = GalaxyMapHud.new()
		add_child(galaxy_hud)
		galaxy_hud.setup(self)
	else:
		space_view = SpaceMapView.new()
		add_child(space_view)
		space_view.setup(campaign, level, space_selected)
		space_hud = SpaceMapHud.new()
		add_child(space_hud)
		space_hud.setup(self)
	_update_camera()

func leave_space_overview(restore_tactical: bool = true) -> void:
	if space_mode == "":
		return
	space_mode = ""
	_space_environment(false)
	_space_touches.clear()
	_space_touch_begin.clear()
	if orbit_hud!=null:
		orbit_hud.queue_free();orbit_hud=null
	if orbit_view!=null:
		orbit_view.queue_free();orbit_view=null
	if space_hud != null:
		space_hud.queue_free()
		space_hud = null
	if space_view != null:
		space_view.queue_free()
		space_view = null
	if galaxy_hud != null:
		galaxy_hud.queue_free()
		galaxy_hud = null
	if galaxy_view != null:
		galaxy_view.queue_free()
		galaxy_view = null
	if restore_tactical:
		cam.far = 300.0
		hud.visible = true
		view.visible = true
		if strategic_hud != null:
			strategic_hud.visible = true
		if region_navigation != null:
			region_navigation.visible = campaign.active == "val"
		cam_dist = 51.0
		cam_zoom_goal = 43.0
	_update_camera()

func switch_space_system() -> void:
	if campaign == null or space_mode == "" or int(campaign.ages[player]) < 10:
		return
	var selected: Dictionary = campaign.star_catalog.info(space_selected)
	var other_system: String = "proxima" if String(selected.get("system_id", "sol")) == "sol" else "sol"
	space_selected = "nemesis" if other_system == "proxima" else "val"
	enter_space_overview("system")

func open_galaxy_system(system_id: String) -> void:
	if campaign == null or not campaign.system_known(player, system_id):
		return
	var body_list: Array = campaign.star_catalog.bodies_for_system(system_id)
	if body_list.is_empty():
		return
	space_selected = String(body_list[0]["id"])
	enter_space_overview("system")

func land_on_space_selection() -> void:
	if campaign == null or not campaign.is_unlocked(player, space_selected):
		return
	var target: String = space_selected
	leave_space_overview(true)
	switch_sector(target)

func _handle_space_input(event: InputEvent) -> void:
	if space_mode=="orbit" and orbit_hud!=null:
		orbit_hud.handle_input(event)
		return
	if space_mode == "galaxy":
		_handle_galaxy_input(event)
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if space_mode == "orbit":
				enter_space_overview("system")
			elif space_mode == "system":
				enter_space_overview("galaxy")
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if space_mode == "system":
				enter_space_overview("orbit")
			else:
				land_on_space_selection()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and space_hud != null and not space_hud.is_over_ui(event.position):
			var hit: String = space_view.pick(cam, event.position)
			if hit != "":
				space_selected = hit
				space_hud.refresh(true)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if space_hud != null and space_hud.is_over_ui(event.position):
				return
			_space_touches[event.index] = event.position
			_space_touch_begin[event.index] = event.position
			if _space_touches.size() == 2:
				var pts: Array = _space_touches.values()
				_space_pinch_baseline = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
		else:
			if _space_touches.has(event.index) and _space_touches.size() == 1:
				var first: Vector2 = _space_touch_begin.get(event.index, event.position) as Vector2
				if first.distance_to(event.position) < 18.0:
					var chosen: String = space_view.pick(cam, event.position)
					if chosen != "":
						space_selected = chosen
						space_hud.refresh(true)
			_space_touches.erase(event.index)
			_space_touch_begin.erase(event.index)
			if _space_touches.size() < 2:
				_space_pinch_baseline = 0.0
	elif event is InputEventScreenDrag and _space_touches.has(event.index):
		_space_touches[event.index] = event.position
		if _space_touches.size() == 2 and _space_pinch_baseline > 12.0:
			var pts: Array = _space_touches.values()
			var current_distance: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
			if current_distance < _space_pinch_baseline * 0.74:
				if space_mode == "orbit":
					enter_space_overview("system")
				elif space_mode == "system":
					enter_space_overview("galaxy")
			elif current_distance > _space_pinch_baseline * 1.33:
				if space_mode == "system":
					enter_space_overview("orbit")
				else:
					land_on_space_selection()

func _handle_galaxy_input(event: InputEvent) -> void:
	if galaxy_view == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			open_galaxy_system(galaxy_selected)
		elif event.button_index == MOUSE_BUTTON_LEFT and (galaxy_hud == null or not galaxy_hud.is_over_ui(event.position)):
			var hit: String = galaxy_view.pick(cam, event.position)
			if not hit.is_empty():
				galaxy_selected = hit
				galaxy_hud.refresh(true)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if galaxy_hud != null and galaxy_hud.is_over_ui(event.position):
				return
			_space_touches[event.index] = event.position
			_space_touch_begin[event.index] = event.position
			if _space_touches.size() == 2:
				var points: Array = _space_touches.values()
				_space_pinch_baseline = (points[0] as Vector2).distance_to(points[1] as Vector2)
		else:
			if _space_touches.has(event.index) and _space_touches.size() == 1:
				var first: Vector2 = _space_touch_begin.get(event.index, event.position) as Vector2
				if first.distance_to(event.position) < 18.0:
					var selected: String = galaxy_view.pick(cam, event.position)
					if not selected.is_empty():
						galaxy_selected = selected
						galaxy_hud.refresh(true)
			_space_touches.erase(event.index)
			_space_touch_begin.erase(event.index)
			if _space_touches.size() < 2:
				_space_pinch_baseline = 0.0
	elif event is InputEventScreenDrag and _space_touches.has(event.index):
		_space_touches[event.index] = event.position
		if _space_touches.size() == 2 and _space_pinch_baseline > 10.0:
			var pts: Array = _space_touches.values()
			if (pts[0] as Vector2).distance_to(pts[1] as Vector2) > _space_pinch_baseline * 1.32:
				open_galaxy_system(galaxy_selected)

func _pan(rel: Vector2, inertial: bool = false) -> void:
	var h: float = float(get_viewport().get_visible_rect().size.y)
	var k: float = cam_dist * 1.25 / maxf(1.0, h)
	var right := Vector3(1, 0, 0).rotated(Vector3.UP, cam_yaw)
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, cam_yaw)
	var displacement: Vector3 = -right * rel.x * k - fwd * rel.y * k
	cam_target += displacement
	if inertial and rel.length_squared() > 0.5:
		var instant: Vector3 = displacement / maxf(0.016, _frame_delta)
		pan_velocity = (pan_velocity * 0.55 + instant * 0.45).limit_length(60.0)
	_update_camera()

func _select_rectangle(area: Rect2) -> void:
	var ids: Array = []
	for u in world.units.values():
		if u.team != player:
			continue
		var pos := Vector3(u.pos.x, 0.6, u.pos.y)
		if not cam.is_position_behind(pos) and area.has_point(cam.unproject_position(pos)):
			ids.append(u.id)
	if ids.is_empty():
		hud.toast("Aucune unité dans la zone")
		return
	if add_mode:
		for uid in selected_ids():
			if not ids.has(uid):
				ids.append(uid)
	select_many(ids)

func select_many(ids: Array) -> void:
	clear_selection()
	var unique := {}
	for id in ids:
		var uid: int = int(id)
		var u = world.units.get(uid)
		if u == null or u.team != player or unique.has(uid):
			continue
		unique[uid] = true
		sel_units.append(uid)
		view.selection_ids[uid] = true
	hud.selection_changed()

func selection_center() -> Vector2:
	var total := Vector2.ZERO
	var valid := 0
	for uid in sel_units:
		var u = world.units.get(int(uid))
		if u != null:
			total += u.pos
			valid += 1
	return total / float(valid) if valid > 0 else Vector2(cam_target.x, cam_target.z)

func issue_radial(kind: String, pos: Vector2, entity) -> void:
	if not has_command_selection() or hud.menu_panel.visible:
		return
	if kind == "attack":
		if entity == null or entity.team == player or entity.team == SimWorld.TEAM_NEUTRAL or not world.is_visible_to(player, world.entity_pos(entity)):
			hud.refusal("Cible hors de vue", Vector2(-1, -1))
			return
		_order({"t": "attack", "target": entity.id}, world.entity_pos(entity), AgeTheme.STEP_COLORS["attack"])
	elif kind in ["move", "amove"]:
		_order({"t": kind, "pos": [pos.x, pos.y]}, pos, AgeTheme.STEP_COLORS[kind])

func screen_to_ground(sp: Vector2) -> Vector2:
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	if absf(dir.y) < 0.0001:
		return Vector2(-1, -1)
	var t := -from.y / dir.y
	var p := from + dir * t
	return Vector2(p.x, p.z)

func _pick(sp: Vector2):
	## Sélection en espace écran : l'entité la plus proche du doigt dans un rayon tolérant.
	var best = null
	var bd := PICK_RADIUS_PX * PICK_RADIUS_PX
	for u in world.units.values():
		if u.team != player and not world.is_visible_to(player, u.pos):
			continue
		var wp := Vector3(u.pos.x, 0.6, u.pos.y)
		if cam.is_position_behind(wp):
			continue
		var d := cam.unproject_position(wp).distance_squared_to(sp)
		if d < bd:
			bd = d
			best = u
	if best != null:
		return best
	var g := screen_to_ground(sp)
	var building_pick = null
	var nearest_depth: float = INF
	for b in world.buildings.values():
		var known: bool = b.team == player or world.is_visible_to(player, b.center) or world.teams[player].memory.has(b.id)
		if not known: continue
		var half: float = float(b.size) * 0.5 + 0.3
		var footprint: bool = absf(g.x-b.center.x)<=half and absf(g.y-b.center.y)<=half
		var bounds := PackedVector2Array()
		var height: float = maxf(2.0, float(b.size) * 0.75)
		for x in [-half,half]:
			for z in [-half,half]:
				for y in [0.0,height]:
					var corner := Vector3(b.center.x+x,y,b.center.y+z)
					if not cam.is_position_behind(corner): bounds.append(cam.unproject_position(corner))
		var roof: bool = bounds.size()>=3 and Geometry2D.is_point_in_polygon(sp,Geometry2D.convex_hull(bounds))
		var depth: float = cam.global_position.distance_squared_to(Vector3(b.center.x,0,b.center.y))
		if (footprint or roof) and depth<nearest_depth: building_pick=b;nearest_depth=depth
	return building_pick

func _tap(sp: Vector2) -> void:
	if hud.menu_panel.visible or hud.over_panel.visible:
		return
	if hud.radial_open:
		hud.close_radial()
		return
	var g := screen_to_ground(sp)
	if hud.queue_bubble.visible:
		hud.queue_bubble.visible = false
	if _tap_017(sp, g):
		return
	if mode == "rally":
		var target = _pick(sp)
		var cmd: Dictionary = {"t": "rally_group", "team": player, "buildings": rally_producers, "pos": [g.x, g.y]}
		if target is SimWorld.Unit and target.team == player and Rules.unit_has(target.type, "military"):
			cmd["kind"] = "unit"
			cmd["target"] = target.id
		var result: Dictionary = world.issue(cmd)
		hud.set_hint("Drapeau posé : les prochaines recrues rejoindront cette destination." if bool(result.get("ok", false)) else String(result.get("reason", "Refus")))
		if bool(result.get("ok", false)):
			view.add_marker(g, AgeTheme.c("success"))
			mode = ""
		return
	if mode == "scan_orbite" and campaign != null:
		var scan_result: Dictionary = campaign.scan(player, campaign.active, g)
		hud.set_hint("Balayage orbital en cours" if scan_result["ok"] else String(scan_result["reason"]))
		mode = ""
		return
	if mode == "civ_power":
		var power_result: Dictionary = world.issue({"t": "civ_power", "team": player, "power": civ_power_key, "pos": [g.x, g.y]})
		hud.set_hint("Pouvoir lancé : " + String((CivRules.POWERS.get(civ_power_key, {"label": "?"}) as Dictionary)["label"]) if power_result["ok"] else String(power_result.get("reason", "Refus")))
		if bool(power_result["ok"]):
			view.add_marker(g, AgeTheme.c("accent"))
		else:
			hud.refusal(String(power_result.get("reason", "Refus")), sp)
		mode = ""
		return
	if mode == "missile":
		var result: Dictionary = world.issue({"t": "missile", "team": player, "building": sel_building, "pos": [g.x, g.y]})
		hud.set_hint("Missile lancé" if result["ok"] else String(result.get("reason", "Refus")))
		mode = ""
		return
	if mode == "place":
		place_cell = Vector2i(int(g.x - Rules.BUILDINGS[place_type]["size"] * 0.5 + 0.5), int(g.y - Rules.BUILDINGS[place_type]["size"] * 0.5 + 0.5))
		if placement_tool.line_mode:
			placement_tool.begin_line(g)
			placement_tool.end_line()
		elif (placement_tool.multi_mode or hud.command_card.chain_active) and world.build_check(player, place_type, place_cell) == "":
			confirm_placement()
			return
		hud.placement_changed()
		return
	if mode == "delegate":
		var r := world.issue({"t": "army_defend", "team": player, "pos": [g.x, g.y], "radius": 12.0})
		if r["ok"]:
			view.add_marker(g, AgeTheme.c("info"))
		mode = ""
		hud.set_hint("")
		return
	var e = _pick(sp)
	var node = _pick_node(sp) if e == null else null
	if has_command_selection() and hud.command_card.chain_tap(sp, g, e, node):
		return
	if e is SimWorld.Unit and e.team == player:
		if add_mode:
			toggle_in_selection(e.id)
			return
		_select_unit_tap(e)
		return
	if has_command_selection() and hud.command_card.context_tap(sp, g, e, node):
		return
	if e is SimWorld.Building and e.team == player:
		clear_selection()
		sel_building = e.id
		hud.selection_changed()
		return
	var hostile: bool = e != null and world.factions.hostile(player, e.team)
	if has_command_selection():
		if hostile:
			_order({"t": "attack", "target": e.id}, world.entity_pos(e), AgeTheme.STEP_COLORS["attack"])
		elif e == null or e.team == SimWorld.TEAM_NEUTRAL:
			_order({"t": "move", "pos": [g.x, g.y]}, g, AgeTheme.STEP_COLORS["move"])
		return
	if e != null:
		clear_selection()
		hud.show_info(e)
		return
	clear_selection()

func _select_unit_tap(u) -> void:
	# 1er tap : escouade ; 2e tap sur une unité de l'escouade sélectionnée : cette unité seule
	if u.squad_id != -1 and world.squads.has(u.squad_id) and not u.direct:
		if sel_squad == u.squad_id:
			select_single(u.id)
		else:
			select_squad(u.squad_id)
		return
	select_single(u.id)

func _long_press(sp: Vector2) -> void:
	var e = _pick(sp)
	if e is SimWorld.Unit and e.team == player:
		select_single(e.id)
		hud.toast("Unité sélectionnée seule", AgeTheme.c("info"))
	elif has_command_selection() and mode == "":
		hud.open_radial(sp, e, screen_to_ground(sp))

func has_command_selection() -> bool:
	return sel_squad != -1 or not sel_units.is_empty()

func _order(base: Dictionary, marker: Vector2, color: Color) -> void:
	var cmd := base.duplicate()
	cmd["team"] = player
	var res := {}
	if sel_squad != -1:
		cmd["squad"] = sel_squad
		res = world.issue(cmd)
	else:
		# ordre direct à une unité : elle sort de la délégation et de son escouade (reprise en main)
		for id in sel_units:
			var u = world.units.get(id)
			if u != null and not u.direct and u.squad_id != -1:
				world.issue({"t": "take_unit", "team": player, "unit": id})
		cmd["units"] = sel_units.duplicate()
		res = world.issue(cmd)
	if res["ok"]:
		view.add_marker(marker, color)
		AgeTheme.haptic(10)
	else:
		hud.refusal(String(res.get("text", res.get("reason", "Ordre impossible"))), Vector2(-1, -1))
	hud.selection_changed()

func select_squad(sid: int) -> void:
	clear_selection()
	sel_squad = sid
	var s = world.squads.get(sid)
	if s != null:
		for id in s.units:
			view.selection_ids[id] = false
	hud.selection_changed()

func select_single(uid: int) -> void:
	clear_selection()
	sel_units = [uid]
	view.selection_ids[uid] = true
	hud.selection_changed()

func clear_selection() -> void:
	sel_squad = -1
	sel_units = []
	sel_building = -1
	view.selection_ids.clear()
	hud.selection_changed()

func focus(p: Vector2) -> void:
	pan_velocity = Vector3.ZERO
	cam_target = Vector3(p.x, 0, p.y)
	_update_camera()

func start_placement(type: String) -> void:
	box_select_mode = false
	hud.set_select_mode(false)
	hud.close_radial()
	if mode != "place" or place_type != type:
		placement_tool.reset()
	if hud.building_drawer != null and hud.building_drawer.visible:
		hud.building_drawer.hide()    # 0.17 : la fiche ne masque jamais la barre de placement
	mode = "place"
	place_type = type
	var c := cam_target
	var s := int(Rules.BUILDINGS[type]["size"])
	place_cell = Vector2i(int(c.x) - s / 2, int(c.z) - s / 2)
	hud.placement_changed()

func confirm_placement() -> void:
	## 0.17 : pose simple, en ligne ou multiple ; avec « Enchaîner », chaque pose devient une étape des ouvriers.
	var placed: int = placement_tool.confirm()
	if placed > 0:
		hud.toast(placement_tool.last_report if placement_tool.last_report.contains("refus") or placed > 1 else "%s : fondation posée, ouvriers affectés" % Rules.BUILDINGS[place_type]["label"], AgeTheme.c("success"))
		if not placement_tool.multi_mode and not hud.command_card.chain_active:
			mode = ""
			ghost.visible = false
			placement_tool.reset()
	else:
		hud.refusal(placement_tool.last_report.get_slice("refus : ", 1) if placement_tool.last_report.contains("refus") else "pose impossible", Vector2(-1, -1))
	hud.placement_changed()

func cancel_mode() -> void:
	if zoning_tool != null and zoning_tool.active:
		zoning_tool.close()
		if hud.zoning_panel != null:
			UIMotion.conceal(hud.zoning_panel)
	mode = ""
	if placement_tool != null:
		placement_tool.reset()
		placement_tool.multi_mode = false
	box_select_mode = false
	hud.set_select_mode(false)
	ghost.visible = false
	hud.set_hint("")
	hud.placement_changed()

func _update_ghost() -> void:
	if mode != "place":
		ghost.visible = false
		return
	var s := int(Rules.BUILDINGS[place_type]["size"])
	ghost.visible = true
	(ghost.mesh as BoxMesh).size = Vector3(s, 1.2, s)
	ghost.position = Vector3(place_cell.x + s * 0.5, 0.6, place_cell.y + s * 0.5)
	var ok := world.build_check(player, place_type, place_cell) == ""
	(ghost.material_override as StandardMaterial3D).albedo_color = Color(AgeTheme.c("success"), 0.45) if ok else Color(AgeTheme.c("danger"), 0.45)
	ghost.visible = not (placement_tool.line_mode and placement_tool.cells.size() > 1)

func set_shadows(on: bool) -> void:
	_shadows_user_preference = on
	_apply_render_profile()

func set_visual_quality(level: int) -> void:
	GameConfig.visual_quality = clampi(level, 0, 2)
	view.set_visual_quality(GameConfig.visual_quality)
	mobile_perf.stage = 0
	_apply_render_profile()
	GameConfig.save_preferences()

func _apply_render_profile() -> void:
	_applied_perf_stage = mobile_perf.stage
	render_state = RenderProfile.apply(get_viewport(), sun, GameConfig.visual_quality, mobile_perf.stage, _shadows_user_preference)

func cancel_gestures() -> void:
	if orbit_hud!=null:orbit_hud.cancel_gestures()
	touches.clear()
	_ignored.clear()
	_planet_touches.clear()
	_space_touches.clear()
	dragging = false
	long_fired = false
	press_time = 0.0
	pan_velocity = Vector3.ZERO
	_planet_touch_index = -1
	_planet_dragging = false
	pinch_start_dist = 0.0
	_planet_pinch_start = 0.0
	_space_pinch_baseline = 0.0
	if hud != null:
		hud.show_selection_rect(Vector2.ZERO, Vector2.ZERO, false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_gestures()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and hud != null:
		_back_action()

func _back_action() -> void:
	cancel_gestures()
	if city_panel != null and city_panel.visible:
		city_panel.hide()
		return
	if civ_panel != null and civ_panel.visible:
		civ_panel.hide()
		return
	if evolution_panel != null and evolution_panel.visible:
		evolution_panel.hide()
		return
	if space_mode=="orbit" and orbit_hud!=null and orbit_hud.back():
		return
	if space_mode != "":
		leave_space_overview()
	elif planet_mode:
		leave_planet_overview()
	elif hud.controls_panel.visible:
		hud._toggle_controls()
	elif hud.tech_panel.visible:
		hud._toggle_tech_panel()
	elif hud.radial_open:
		hud.close_radial()
	elif hud.ceremony != null and hud.ceremony.active:
		hud.ceremony.skip()
	elif hud.queue_bubble.visible:
		hud.queue_bubble.visible = false
	elif mode != "":
		cancel_mode()
	elif hud.command_card.chain_active:
		hud.command_card.set_chain(false)
	elif UIMotion.is_open(hud.production_panel):
		UIMotion.conceal(hud.production_panel)
	elif add_mode:
		hud._toggle_additive()
	elif hud.building_drawer!=null and UIMotion.is_open(hud.building_drawer):
		clear_selection()
	elif UIMotion.is_open(hud.build_panel):
		hud._toggle_build()
	elif UIMotion.is_open(hud.squad_panel):
		hud._toggle_squads()
	else:
		hud._toggle_menu()

func _input(event: InputEvent) -> void:
	if hud == null:
		return
	if space_mode=="orbit" and orbit_hud!=null:
		var tracked_release:bool=(event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and orbit_hud.mouse_start.x>=0) or (event is InputEventScreenTouch and not event.pressed and orbit_hud.touches.has(event.index))
		if tracked_release and orbit_hud.is_over_ui(event.position):
			orbit_hud.handle_input(event);get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_back_action()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.canceled:
			cancel_gestures()
		elif not event.pressed and touches.has(event.index) and (hud.is_over_ui(event.position) or (strategic_hud != null and strategic_hud.is_over_ui(event.position))):
			# La GUI peut consommer le relâchement : terminer tout de même le geste de carte.
			dragging = true
			_unhandled_input(event)
			get_viewport().set_input_as_handled()

func _build_region_navigation() -> void:
	if campaign == null or campaign.planet_regions == null:
		return
	region_navigation = CanvasLayer.new()
	add_child(region_navigation)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = MobileUI.theme()
	region_navigation.add_child(root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 14.0
	panel.offset_right = 270.0
	panel.offset_top = 145.0
	panel.offset_bottom = 308.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	region_info_label = Label.new()
	region_info_label.add_theme_font_size_override("font_size", 14)
	box.add_child(region_info_label)
	var up := Button.new()
	up.text = "↑ NORD"
	up.custom_minimum_size.y = 48.0
	up.pressed.connect(func(): travel_selected(Vector2i.UP))
	box.add_child(up)
	var row := HBoxContainer.new()
	box.add_child(row)
	for item in [{"label": "← OUEST", "dir": Vector2i.LEFT}, {"label": "SUD ↓", "dir": Vector2i.DOWN}, {"label": "EST →", "dir": Vector2i.RIGHT}]:
		var b := Button.new()
		b.text = String(item["label"])
		b.custom_minimum_size.y = 48.0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var direction: Vector2i = item["dir"]
		b.pressed.connect(func(): travel_selected(direction))
		row.add_child(b)
	_refresh_region_label()

func _refresh_region_label() -> void:
	if region_info_label != null and campaign != null and campaign.planet_regions != null:
		var current_region: Vector2i = campaign.planet_regions.active
		region_info_label.text = "RÉGION %d / %d · Sélectionner des unités" % [current_region.x, current_region.y]

func travel_selected(direction: Vector2i) -> void:
	if campaign == null or campaign.planet_regions == null:
		return
	var ids: Array = sel_units.duplicate()
	if sel_squad != -1 and world.squads.has(sel_squad):
		ids = (world.squads[sel_squad] as SimWorld.Squad).units.duplicate()
	var result: Dictionary = campaign.planet_regions.order_cross(campaign, player, ids, direction)
	hud.set_hint("Traversée engagée : %d unité(s) vers la frontière" % int(result["accepted"]) if bool(result.get("ok", false)) else String(result.get("reason", "Passage impossible")))

func open_planet_region(lon: float, lat: float) -> void:
	if campaign == null:
		return
	if campaign.active != "val":
		# Les nouveaux mondes J10 possèdent une zone de débarquement tactique
		# et un atlas visuel ; les régions continues restent propres au Val J9.
		leave_planet_overview()
		return
	if campaign.planet_regions == null:
		return
	if campaign.active != "val":
		hud.set_hint("Revenir au secteur Val pour explorer les régions de sa planète.")
		return
	var region: Vector2i = PlanetGenerator.region_coords(lon, lat)
	if not campaign.planet_regions.visit(region, campaign):
		hud.set_hint("Région inaccessible")
		return
	leave_planet_overview()
	_refresh_region_world()

func jump_to_region(region: Vector2i) -> void:
	if campaign == null or campaign.planet_regions == null or not PlanetRegions.valid(region):
		return
	if campaign.active != "val":
		campaign.switch_to(player, "val")
	if campaign.planet_regions.visit(region, campaign):
		_refresh_region_world()

func _refresh_region_world() -> void:
	if campaign == null or campaign.current() == world:
		return
	if world != null:
		camera_sectors[world.seed_value] = cam_target
	mode = ""
	ghost.visible = false
	clear_selection()
	if view != null:
		remove_child(view)
		view.queue_free()
	world = campaign.current()
	if region_navigation != null:
		region_navigation.visible = campaign.active == "val"
	_refresh_region_label()
	_apply_sector_atmosphere()
	view = WorldView.new()
	add_child(view)
	view.setup(world, player)
	view.set_visual_quality(GameConfig.visual_quality)
	var positions: Array = world.team_units(player)
	var anchor: Vector2 = positions[0].pos if not positions.is_empty() else Vector2(48.0, 48.0)
	cam_target = camera_sectors.get(world.seed_value, Vector3(anchor.x, 0, anchor.y)) as Vector3
	cam_zoom_goal = 24.0
	cam_dist = 24.0
	if campaign.planet_regions != null:
		for arrival in campaign.planet_regions.last_arrivals:
			if String(arrival.get("to", "")) == PlanetRegions.key(campaign.planet_regions.active) and int(arrival.get("team", -1)) == player:
				sel_units = [int(arrival["id"])]
				view.selection_ids[int(arrival["id"])] = true
				var arrived: SimWorld.Unit = world.units.get(int(arrival["id"])) as SimWorld.Unit
				if arrived != null:
					cam_target = Vector3(arrived.pos.x, 0.0, arrived.pos.y)
				break
	_update_camera()
	_refresh_region_label()
	hud.selection_changed()
	if strategic_hud != null:
		strategic_hud.refresh(0.0, true)

func switch_sector(key: String) -> void:
	if space_mode != "":
		leave_space_overview(true)
	if planet_mode:
		leave_planet_overview()
	if campaign == null or not campaign.switch_to(player, key):
		return
	if world != null:
		camera_sectors[world.seed_value] = cam_target
	mode = ""
	ghost.visible = false
	clear_selection()
	if view != null:
		remove_child(view)
		view.queue_free()
	world = campaign.current()
	if region_navigation != null:
		region_navigation.visible = campaign.active == "val"
	_refresh_region_label()
	_apply_sector_atmosphere()
	view = WorldView.new()
	add_child(view)
	view.setup(world, player)
	view.set_visual_quality(GameConfig.visual_quality)
	var friendly: Array = world.team_buildings(player, "centre", true)
	var anchor: Vector2 = friendly[0].center if not friendly.is_empty() else StarCampaign.LANDING[player]
	cam_target = camera_sectors.get(world.seed_value, Vector3(anchor.x, 0, anchor.y)) as Vector3
	_update_camera()
	hud.selection_changed()
	hud.set_hint("Secteur actif : " + String(campaign.info(key)["label"]))
	if strategic_hud != null:
		strategic_hud.refresh(0.0, true)

func save_match() -> void:
	if scenario != null:
		hud.set_hint("Sauvegarde réservée aux escarmouches ; le laboratoire se rejoue par graine.")
		return
	var is_planet: bool = campaign != null and bool((campaign.worlds["val"] as SimWorld).rules.get("planet_j9", false))
	var result: Error = CampaignSave.save(campaign, "user://sillons-j9-planet.save") if is_planet else (CampaignSave.save(campaign) if campaign != null else SaveGame.save(world))
	if result == OK:
		hud.control_groups.save(world.seed_value, world.tick)
	hud.set_hint("Partie sauvegardée" if result == OK else "Échec sauvegarde : " + error_string(result))

func load_match() -> void:
	var j9_save: bool = campaign != null and bool((campaign.worlds["val"] as SimWorld).rules.get("planet_j9", false))
	var restored_campaign: StarCampaign = CampaignSave.load_campaign("user://sillons-j9-planet.save") if j9_save else CampaignSave.load_campaign()
	if restored_campaign != null:
		if CampaignSave.last_load_source == "backup":
			GameConfig.recovery_notice = "Sauvegarde principale invalide : .bak vérifié (UTC %s)." % CampaignSave.last_load_timestamp
		GameConfig.loaded_campaign = restored_campaign
		GameConfig.loaded_world = null
	else:
		var restored: SimWorld = SaveGame.load_world()
		if restored == null:
			hud.set_hint("Sauvegarde absente, incompatible ou corrompue : partie actuelle préservée.")
			return
		GameConfig.loaded_world = restored
		GameConfig.loaded_campaign = null
	GameConfig.mode = "skirmish"
	get_tree().reload_current_scene()

func begin_rally(common: bool = false) -> void:
	rally_producers.clear()
	for b in world.team_buildings(player, "", true):
		if not common and b.id != sel_building: continue
		for kind in Rules.BUILDINGS[b.type].get("trains", []):
			if Rules.unit_has(String(kind), "military"):
				rally_producers.append(b.id)
				break
	if rally_producers.is_empty():
		hud.set_hint("Sélectionnez un producteur militaire achevé.")
		return
	mode = "rally"
	hud.set_hint("Touchez un point terrestre libre ou une armée amie. Retour : annuler.")

func _sync_rally_flag() -> void:
	var producer: SimWorld.Building = world.buildings.get(sel_building) as SimWorld.Building
	var enabled: bool = producer != null and not producer.rally_contract.is_empty()
	var position: Vector2 = producer.rally if enabled else Vector2.ZERO
	if enabled and String(producer.rally_contract.get("kind", "point")) == "unit":
		var target: SimWorld.Unit = world.units.get(int(producer.rally_contract["target"])) as SimWorld.Unit
		if target != null: position = target.pos
	view.show_rally_flag(position, enabled)


# ------------------------------------------------------------------ 0.17 : sélection et commandes

func selected_ids() -> Array:
	if sel_squad != -1 and world.squads.has(sel_squad):
		return (world.squads[sel_squad] as SimWorld.Squad).units.duplicate()
	return sel_units.duplicate()

func selected_units() -> Array:
	var out: Array = []
	for raw in selected_ids():
		var u: SimWorld.Unit = world.units.get(int(raw)) as SimWorld.Unit
		if u != null and u.team == player:
			out.append(u)
	return out

func selection_world_center() -> Vector2:
	var units: Array = selected_units()
	if units.is_empty():
		return Vector2(cam_target.x, cam_target.z)
	var total: Vector2 = Vector2.ZERO
	for u in units:
		total += u.pos
	return total / float(units.size())

func _on_screen(u: SimWorld.Unit) -> bool:
	var wp := Vector3(u.pos.x, 0.6, u.pos.y)
	if cam.is_position_behind(wp):
		return false
	return get_viewport().get_visible_rect().has_point(cam.unproject_position(wp))

func select_same_type_on_screen(kind: String) -> int:
	## Double appui : toutes les unités alliées du même type visibles à l'écran.
	var ids: Array = []
	for u in world.team_units(player, ""):
		if u.type == kind and u.garrison_id == -1 and _on_screen(u):
			ids.append(u.id)
	if not ids.is_empty():
		select_many(ids)
		hud.toast("%d %s à l'écran" % [ids.size(), String(Rules.UNITS[kind]["label"]).to_lower()], AgeTheme.c("info"))
	return ids.size()

func _double_tap(sp: Vector2) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	var e = _pick(sp) if mode == "" else null
	var kind: String = e.type if e is SimWorld.Unit and e.team == player else ""
	var is_double: bool = kind != "" and kind == _last_tap_type and now - _last_tap_time <= DOUBLE_TAP and sp.distance_to(_last_tap_pos) <= 44.0
	_last_tap_time = -10.0 if is_double else now
	_last_tap_pos = sp
	_last_tap_type = "" if is_double else kind
	if is_double:
		select_same_type_on_screen(kind)
	return is_double

func filter_selection(kind: String, keep: bool) -> void:
	## Barre de sélection : garder ce type (toucher) ou le retirer (appui long).
	var ids: Array = []
	for u in selected_units():
		if (u.type == kind) == keep:
			ids.append(u.id)
	if ids.is_empty():
		clear_selection()
	else:
		select_many(ids)

func toggle_in_selection(uid: int) -> void:
	var ids: Array = selected_ids()
	if ids.has(uid):
		ids.erase(uid)
	else:
		ids.append(uid)
	if ids.is_empty():
		clear_selection()
	else:
		select_many(ids)

func idle_workers() -> Array:
	var out: Array = []
	for u in world.team_units(player, "worker"):
		if u.task == "" and not u.direct and not u.manual and u.garrison_id == -1:
			out.append(u)
	return out

func select_army() -> void:
	var ids: Array = []
	for u in world.team_units(player, "military"):
		if u.garrison_id == -1:
			ids.append(u.id)
	if ids.is_empty():
		hud.toast("Aucune troupe sur cette carte")
		return
	select_many(ids)
	hud.toast("Armée : %d unité(s)" % ids.size(), AgeTheme.c("info"))

func select_heroes() -> void:
	var ids: Array = []
	for u in world.team_units(player, ""):
		if CivRules.HEROES.has(u.type):
			ids.append(u.id)
	if ids.is_empty():
		hud.toast("Aucun héros présent")
		return
	select_many(ids)
	focus(selection_world_center())

func _pick_node(sp: Vector2):
	## Gisement (arbre, baies, minerai) le plus proche du doigt, s'il est exploré.
	var best = null
	var bd: float = PICK_RADIUS_PX * PICK_RADIUS_PX * 1.4
	for n in world.nodes.values():
		if n.amount <= 0.0 or not world.is_explored_by(player, n.pos):
			continue
		var wp := Vector3(n.pos.x, 0.5, n.pos.y)
		if cam.is_position_behind(wp):
			continue
		var d: float = cam.unproject_position(wp).distance_squared_to(sp)
		if d < bd:
			bd = d
			best = n
	return best

func _cast_power(at: Vector2) -> void:
	var result: Dictionary = world.issue({"t": "civ_power", "team": player, "power": civ_power_key, "pos": [at.x, at.y]})
	if bool(result.get("ok", false)):
		hud.set_hint("Pouvoir lancé : " + String((CivRules.POWERS.get(civ_power_key, {"label": "?"}) as Dictionary)["label"]))
		view.add_marker(at, AgeTheme.c("accent"))
		AgeTheme.haptic(30)
	else:
		hud.refusal(String(result.get("reason", "Refus")), Vector2(-1, -1))
	mode = ""

func _tap_017(sp: Vector2, g: Vector2) -> bool:
	## Modes de ciblage 0.17 : commandes de la carte, édition d'étape, ralliement sur ressource.
	if mode.begins_with("cmd:"):
		var e = _pick(sp)
		hud.command_card.on_target(mode.trim_prefix("cmd:"), sp, g, e, _pick_node(sp) if e == null or e is SimWorld.Building else null)
		return true
	if mode == "rally_resource":
		var e2 = _pick(sp)
		var node = _pick_node(sp)
		var target_id: int = node.id if node != null else (e2.id if e2 is SimWorld.Building and e2.type == "ferme" else -1)
		var result: Dictionary = world.issue({"t": "rally_resource", "team": player, "building": rally_resource_building, "node": target_id})
		if bool(result.get("ok", false)):
			hud.toast("Les nouveaux ouvriers iront récolter directement", AgeTheme.c("success"))
			view.add_marker(g, AgeTheme.c("success"))
		else:
			hud.refusal(String(result.get("reason", "Refus")), sp)
		mode = ""
		hud.set_hint("")
		return true
	if mode == "queue_move" or mode == "queue_insert":
		var point: Dictionary = queue_edit_point
		var cmd: Dictionary = {"t": "queue_edit", "team": player, "units": point.get("units", []), "index": int(point.get("index", -1))}
		if mode == "queue_move":
			cmd["op"] = "move"
			cmd["pos"] = [g.x, g.y]
		else:
			cmd["op"] = "insert"
			cmd["step"] = {"type": "move", "pos": [g.x, g.y]}
		var edit: Dictionary = world.issue(cmd)
		if not bool(edit.get("ok", false)):
			hud.refusal(String(edit.get("reason", "Refus")), sp)
		mode = ""
		hud.set_hint("")
		return true
	if mode == "" and has_command_selection() and path_view != null:
		var point_hit: Dictionary = path_view.point_at(sp, cam)
		if not point_hit.is_empty():
			hud.open_queue_bubble(point_hit, sp)
			return true
	return false

func _sample_income(delta: float) -> void:
	_income_t += delta
	if _income_t < 5.0:
		return
	_income_t = 0.0
	var gathered: Dictionary = (world.teams[player].stats["gathered"] as Dictionary).duplicate()
	_income_samples.append({"tick": world.tick, "gathered": gathered})
	while _income_samples.size() > 13:
		_income_samples.pop_front()

func income_per_minute() -> Dictionary:
	## Revenus récoltés par minute sur la dernière minute de jeu (cliquables dans la barre du haut).
	if _income_samples.size() < 2:
		return {}
	var first: Dictionary = _income_samples[0]
	var last: Dictionary = _income_samples[_income_samples.size() - 1]
	var minutes: float = float(int(last["tick"]) - int(first["tick"])) / float(Rules.TICK_RATE * 60)
	if minutes <= 0.0:
		return {}
	var out: Dictionary = {}
	for r in Rules.RESOURCES:
		out[r] = maxf(0.0, (float(last["gathered"].get(r, 0.0)) - float(first["gathered"].get(r, 0.0))) / minutes)
	return out
