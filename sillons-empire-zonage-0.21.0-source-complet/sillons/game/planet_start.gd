extends Node3D
## Choix d'une région d'origine sur le globe. Crée une nouvelle campagne J9
## sans altérer les anciennes sauvegardes ou les parties J1-J8.
var globe: PlanetGlobeView
var camera: Camera3D
var label_info: Label
var play_button: Button
var _drag_id: int = -1
var _down: Vector2 = Vector2.ZERO
var _last: Vector2 = Vector2.ZERO
var _dragged: bool = false
var _mouse_dragging: bool = false
var _seed: int = 1

func _ready() -> void:
	_seed = GameConfig.seed_value if GameConfig.seed_value != 0 else int(Time.get_unix_time_from_system()) % 10000000
	GameConfig.seed_value = _seed
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.025, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.8, 1.0)
	env.ambient_light_energy = 0.42
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28.0, 38.0, 0.0)
	light.light_energy = 1.7
	add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 45.0
	ResponsiveLayout.watch(get_tree().root)
	camera.keep_aspect = Camera3D.KEEP_WIDTH if ResponsiveLayout.is_portrait(self) else Camera3D.KEEP_HEIGHT
	camera.position = Vector3(48.0, 12.0, 125.0)
	add_child(camera)
	camera.look_at(Vector3(48.0, 0.0, 48.0))
	globe = PlanetGlobeView.new()
	add_child(globe)
	globe.setup(_seed)
	_build_hud()
	var lon: float = PI * 0.5
	var lat: float = 0.0
	# Chercher une region continentale visible à la caméra pour le premier depart.
	for i in 28:
		var trial_lon: float = PI * 0.5 + float((i % 7) - 3) * 0.10
		var trial_lat: float = float((i / 7) - 1) * 0.12
		var probe: Dictionary = globe.generator.sample(trial_lon, trial_lat)
		if int(probe["biome"]) != PlanetGenerator.OCEAN:
			lon = trial_lon
			lat = trial_lat
			break
	globe.select(lon, lat)
	_update_region({"hit": true, "lon": lon, "lat": lat, "biome": int(globe.generator.sample(lon, lat)["biome"])})

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var panel := PanelContainer.new()
	panel.offset_left = 18.0
	panel.offset_top = 18.0
	panel.offset_right = 368.0
	panel.offset_bottom = 302.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	var vertical := VBoxContainer.new()
	panel.add_child(vertical)
	var title := Label.new()
	title.text = "J9  ·  NOUVELLE PLANÈTE"
	title.add_theme_font_size_override("font_size", 21)
	vertical.add_child(title)
	var instr := Label.new()
	instr.text = "Graine : %d\nTourner le globe pour choisir une région de départ." % _seed
	instr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vertical.add_child(instr)
	label_info = Label.new()
	label_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vertical.add_child(label_info)
	play_button = Button.new()
	var play: Button = play_button
	play.text = "JOUER ICI · nouvelle campagne"
	play.custom_minimum_size.y = 48.0
	play.pressed.connect(_start_campaign)
	vertical.add_child(play)
	var back := Button.new()
	back.text = "Retour au menu"
	back.custom_minimum_size.y = 45.0
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://game/main_menu.tscn"))
	vertical.add_child(back)
	var notice := Label.new()
	notice.text = "J9 : planète traversable par régions de 96×96 cellules, génération à la demande.\nSélectionner des unités et utiliser les flèches de frontière en partie."
	notice.anchor_top = 1.0
	notice.anchor_bottom = 1.0
	notice.anchor_right = 1.0 # 0.18 : largeur de l'écran (portrait compris), texte replié
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.offset_left = 18.0
	notice.offset_right = -18.0
	notice.offset_top = -58.0
	notice.offset_bottom = -8.0
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notice)

func _start_campaign() -> void:
	if int(globe.generator.sample(globe.selected_lon, globe.selected_lat)["biome"]) == PlanetGenerator.OCEAN:
		return
	GameConfig.planet_lon = globe.selected_lon
	GameConfig.planet_lat = globe.selected_lat
	GameConfig.mode = "planet_j9"
	GameConfig.player_ai = false
	GameConfig.loaded_campaign = null
	GameConfig.loaded_world = null
	get_tree().change_scene_to_file("res://game/game.tscn")

func _update_region(hit: Dictionary) -> void:
	if not bool(hit.get("hit", false)):
		return
	var biome: int = int(hit["biome"])
	label_info.text = "Région : %s\nLon %.1f° · Lat %.1f°" % [
		PlanetGenerator.BIOME_NAMES[biome], rad_to_deg(float(hit["lon"])), rad_to_deg(float(hit["lat"]))]
	if play_button != null:
		play_button.disabled = biome == PlanetGenerator.OCEAN
		play_button.text = "Océan : choisir une terre émergée" if biome == PlanetGenerator.OCEAN else "JOUER ICI · nouvelle campagne"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_id = event.index
			_down = event.position
			_last = event.position
			_dragged = false
		elif _drag_id == event.index:
			if not _dragged:
				_update_region(globe.pick(camera, event.position))
			_drag_id = -1
	elif event is InputEventScreenDrag and _drag_id == event.index:
		if event.position.distance_to(_down) > 10.0:
			_dragged = true
		if _dragged:
			globe.drag_rotate(event.position - _last)
		_last = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_dragging = event.pressed
		_down = event.position
		_last = event.position
		_dragged = false
		if not event.pressed and not _dragged:
			_update_region(globe.pick(camera, event.position))
	elif event is InputEventMouseMotion and _mouse_dragging:
		if event.position.distance_to(_down) > 9.0:
			_dragged = true
		if _dragged:
			globe.drag_rotate(event.position - _last)
		_last = event.position
