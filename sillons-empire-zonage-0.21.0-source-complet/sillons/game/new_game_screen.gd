extends Control
## 0.21 : « Nouvelle partie » — réglages avancés, préréglages, résumé, lancement.
## Tout est construit en code (comme le menu principal) ; les valeurs vivent dans GameSetup.

var _form: VBoxContainer
var _summary: Label
var _scroll: ScrollContainer
var _seed_edit: LineEdit

func _ready() -> void:
	GameSetup.load_saved()
	theme = MobileUI.theme()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.07, 1.0)
	add_child(bg)
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var insets: Vector4 = MobileUI.safe_insets(get_viewport())
	frame.add_theme_constant_override("margin_left", int(insets.x) + 12)
	frame.add_theme_constant_override("margin_top", int(insets.y) + 8)
	frame.add_theme_constant_override("margin_right", int(insets.z) + 12)
	frame.add_theme_constant_override("margin_bottom", int(insets.w) + 8)
	add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := Button.new()
	back.text = "←  Retour"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(_back)
	top.add_child(back)
	var title := Label.new()
	title.text = "NOUVELLE PARTIE"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)
	var reset := Button.new()
	reset.text = "Réinitialiser"
	reset.custom_minimum_size = Vector2(0, 48)
	reset.pressed.connect(func() -> void: _preset("Équilibré"))
	top.add_child(reset)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 10)
	_scroll.add_child(_form)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.theme_type_variation = "MutedLabel"
	_summary.add_theme_font_size_override("font_size", 13)
	root.add_child(_summary)
	var go := Button.new()
	go.text = "LANCER LA PARTIE   →"
	go.custom_minimum_size = Vector2(0, 58)
	MobileUI.primary(go)
	go.pressed.connect(_launch)
	root.add_child(go)
	_rebuild()

# ---------------------------------------------------------------- construction du formulaire

func _rebuild() -> void:
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()
	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 6)
	presets.add_theme_constant_override("v_separation", 6)
	_form.add_child(_title_label("PRÉRÉGLAGES"))
	_form.add_child(presets)
	for entry in GameSetup.PRESET_ORDER:
		var b := Button.new()
		b.text = String(entry)
		b.custom_minimum_size = Vector2(0, 44)
		var preset_name: String = String(entry)
		b.pressed.connect(func() -> void: _preset(preset_name))
		presets.add_child(b)
	var planet: bool = GameSetup.is_planet_mode()
	var s1: VBoxContainer = _section("MODE DE JEU")
	s1.add_child(_segments(GameSetup.MODES, "mode", true))
	s1.add_child(_hint(String((GameSetup.MODES[int(GameSetup.v["mode"])] as Dictionary)["hint"])))
	var s2: VBoxContainer = _section("MONDE")
	s2.add_child(_segments(GameSetup.WORLDS, "world", true))
	s2.add_child(_hint(String((GameSetup.WORLDS[int(GameSetup.v["world"])] as Dictionary)["hint"])))
	if int(GameSetup.v["world"]) == 2:
		var row := HBoxContainer.new()
		_seed_edit = LineEdit.new()
		_seed_edit.text = String(GameSetup.v["seed_text"])
		_seed_edit.placeholder_text = "Graine (nombre) · vide = aléatoire"
		_seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		_seed_edit.custom_minimum_size.y = 48
		_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_seed_edit.text_changed.connect(func(t: String) -> void:
			GameSetup.v["seed_text"] = t
			_changed())
		row.add_child(_seed_edit)
		var dice := Button.new()
		dice.text = "🎲"
		dice.custom_minimum_size = Vector2(56, 48)
		dice.pressed.connect(func() -> void:
			GameSetup.v["seed_text"] = str(randi_range(1, 9999999))
			_rebuild_later())
		row.add_child(dice)
		s2.add_child(row)
	if not planet:
		var s3: VBoxContainer = _section("CARTE TACTIQUE")
		s3.add_child(_segments(GameSetup.MAP_SIZES, "map", true))
		s3.add_child(_hint(String((GameSetup.MAP_SIZES[int(GameSetup.v["map"])] as Dictionary)["hint"])))
	var s4: VBoxContainer = _section("RYTHME")
	s4.add_child(_segments(GameSetup.DURATIONS, "duration", true))
	s4.add_child(_hint(String((GameSetup.DURATIONS[int(GameSetup.v["duration"])] as Dictionary)["hint"])))
	var speeds: Array = []
	for sp in GameConfig.SPEED_LEVELS:
		speeds.append({"label": "×" + str(sp).replace(".0", "")})
	s4.add_child(_label("Vitesse de simulation au départ"))
	s4.add_child(_segments(speeds, "speed", false))
	var s5: VBoxContainer = _section("DÉPART")
	s5.add_child(_label("Ressources de départ"))
	s5.add_child(_segments(GameSetup.RESOURCE_TIERS, "resources", false))
	var res: Dictionary = GameSetup.start_resources(int(GameSetup.v["resources"]))
	s5.add_child(_hint("Nourriture %d · bois %d · minerai %d" % [int(res["food"]), int(res["wood"]), int(res["ore"])]))
	s5.add_child(_slider("Ouvriers", "workers", 3, 10))
	s5.add_child(_slider("Éclaireurs", "scouts", 0, 3))
	s5.add_child(_label("Visibilité de la carte"))
	s5.add_child(_toggle_pair(GameSetup.REVEALS, "reveal"))
	var s6: VBoxContainer = _section("ADVERSAIRE")
	s6.add_child(_label("Comportement de l'IA"))
	s6.add_child(_segments(GameSetup.AI_BEHAVIOURS, "ai", true))
	s6.add_child(_hint(String((GameSetup.AI_BEHAVIOURS[int(GameSetup.v["ai"])] as Dictionary)["hint"])))
	s6.add_child(_label("Dotation de départ de l'IA"))
	s6.add_child(_segments(GameSetup.AI_EDGES, "ai_edge", false))
	if not planet:
		s6.add_child(_check("Démonstration : l'IA joue votre camp", "demo"))
	var s7: VBoxContainer = _section("CIVILISATION ET VILLE")
	if not planet:
		s7.add_child(_check("Évolution de la civilisation (voies, monuments, héros)", "civ"))
	s7.add_child(_check("Chaîne d'approvisionnement (troupes issues des habitants)", "supply"))
	s7.add_child(_label("Événements urbains"))
	s7.add_child(_segments(GameSetup.EVENT_LEVELS, "events", true))
	s7.add_child(_hint(String((GameSetup.EVENT_LEVELS[int(GameSetup.v["events"])] as Dictionary)["hint"])))
	_changed()

func _section(caption: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MobileUI.panel())
	_form.add_child(_title_label(caption))
	_form.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box

func _title_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.theme_type_variation = "HeaderLabel"
	return l

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	return l

func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.theme_type_variation = "MutedLabel"
	l.add_theme_font_size_override("font_size", 13)
	return l

func _segments(options: Array, key: String, rebuild: bool) -> HFlowContainer:
	## Boutons exclusifs qui passent à la ligne en portrait. rebuild = l'affichage dépend du choix (aide, sections).
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = String((options[i] as Dictionary)["label"])
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 46)
		b.button_pressed = int(GameSetup.v[key]) == i
		var index: int = i
		b.pressed.connect(func() -> void:
			GameSetup.v[key] = index
			if rebuild:
				_rebuild_later()
			else:
				_changed())
		flow.add_child(b)
	return flow

func _toggle_pair(labels: Array, key: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := Button.new()
		b.text = String(labels[i])
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 46)
		b.button_pressed = (1 if bool(GameSetup.v[key]) else 0) == i
		var on: bool = i == 1
		b.pressed.connect(func() -> void:
			GameSetup.v[key] = on
			_changed())
		flow.add_child(b)
	return flow

func _check(text: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.custom_minimum_size.y = 52
	c.button_pressed = bool(GameSetup.v[key])
	c.toggled.connect(func(on: bool) -> void:
		GameSetup.v[key] = on
		_changed())
	return c

func _slider(caption: String, key: String, lo: int, hi: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.custom_minimum_size.x = 110
	row.add_child(caption_label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 1
	slider.value = clampi(int(GameSetup.v[key]), lo, hi)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 40
	row.add_child(slider)
	var value := Label.new()
	value.text = str(int(slider.value))
	value.custom_minimum_size.x = 30
	row.add_child(value)
	slider.value_changed.connect(func(x: float) -> void:
		GameSetup.v[key] = int(x)
		value.text = str(int(x))
		_changed())
	return row

# ---------------------------------------------------------------- actions

func _rebuild_later() -> void:
	## Reconstruire pendant le signal du bouton qui l'a déclenché libérerait ce bouton : on diffère.
	var keep: float = float(_scroll.scroll_vertical)
	_rebuild.call_deferred()
	(func() -> void: _scroll.scroll_vertical = int(keep)).call_deferred()

func _changed() -> void:
	if _summary != null:
		_summary.text = GameSetup.summary()
	GameSetup.save()

func _preset(preset_name: String) -> void:
	GameSetup.apply_preset(preset_name)
	_rebuild_later()

func _launch() -> void:
	GameSetup.save()
	var scene: String = GameSetup.apply()
	get_tree().change_scene_to_file(scene)

func _back() -> void:
	get_tree().change_scene_to_file("res://game/main_menu.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
