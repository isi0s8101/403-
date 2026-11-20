class_name Hud
extends CanvasLayer
## Interface tactile : ressources et priorités, passage d'âge, escouades et armée,
## panneau de sélection, construction, mini-carte, messages, mesures et débogage IA.

const RES_COLORS := AgeTheme.RES
const BTN_H := 52
const ICON_HOME = preload("res://game/icons/home.svg")
const ICON_PAUSE = preload("res://game/icons/pause.svg")
const ICON_BUILD = preload("res://game/icons/build.svg")
const ICON_SELECT = preload("res://game/icons/select.svg")
const ICON_ARMY = preload("res://game/icons/army.svg")
const ICON_PLAY = preload("res://game/icons/play.svg")
const MINIMAP_SIDE := 108.0          # côté de la mini-carte en paysage
const MINIMAP_SIDE_PORTRAIT := 188.0 # 0.18.1 : en portrait, la place ne manque pas en largeur

var building_drawer: BuildingDrawer
var game
var root: Control
var res_chips := {}
var pop_label: Label
var age_btn: Button
var squad_box: VBoxContainer
var squad_panel: PanelContainer
var squad_toggle: Button
var minimap_panel: PanelContainer
var minimap_toggle: Button
var box_btn: Button
var radial_panel: PanelContainer
var radial_target := Vector2.ZERO
var radial_entity = null
var radial_open := false
var army_btn: Button
var army_cancel_btn: Button
var sel_panel: PanelContainer
var sel_title: Label
var sel_info: Label
var sel_actions: HBoxContainer
var build_btn: Button
var build_panel: PanelContainer
var build_grid: GridContainer
var place_bar: HFlowContainer
var place_ok: Button
var place_label: Label
var hint_label: Label
var toast_box: VBoxContainer
var minimap: TextureRect
var mini_img: Image
var mini_tex: ImageTexture
var perf_label: Label
var ai_label: Label
var lab_label: Label
var menu_panel: PanelContainer
var quality_btn: Button
var speed_btn: Button
var controls_panel: PanelContainer
var over_panel: PanelContainer
var over_label: Label
var age_panel: PanelContainer
var age_label: Label
var tech_panel: PanelContainer
var tech_rows: VBoxContainer
var tech_status: Label
var _refresh_t := 0.0
var _mini_t := 0.0
var _sel_dirty := true
var _ui_blockers: Array = []
var _info_entity = null
var _last_toast := {}
var _tech_refresh_timer: float = 0.0
var _safe: Vector4 = Vector4(12, 12, 12, 12)
var _safe_controls: Array[Control] = []
var _modal_scrim: ColorRect
var _modal_target: Control
# 0.17 : interface « grand RTS » au pouce et thème qui suit l'âge.
var feedback: UIFeedback
var command_card: CommandCard
var selection_bar: SelectionBar
var control_groups: ControlGroups
var alerts: AlertFeed
var command_bars: CommandBars
var ceremony: AgeCeremony
var production_panel: ProductionPanel
var quick_panel: PanelContainer
var groups_panel: PanelContainer
var idle_btn: Button
var army_select_btn: Button
var hero_btn: Button
var add_btn: Button
var produce_btn: Button
var alert_btn: Button
var active_pause_btn: Button
var line_btn: Button
var multi_btn: Button
var pop_btn: Button
var city_btn: Button                  # 0.18 : panneau Ville
var top_panel: PanelContainer          # 0.18 : barre du haut (deux rangées en portrait)
var top_flow: HFlowContainer
var portrait_mode: int = -1            # 0.18 : -1 inconnu, 0 paysage, 1 portrait
var _portrait_top_h: float = 0.0       # 0.18 : hauteur de la barre du haut au dernier calcul (portrait)
var zoning_panel: ZoningPanel          # 0.19 : barre du mode Zonage
var zones_btn: Button                  # 0.19 : entrée du mode Zonage (rangée Bâtir)
var refusal_label: Label
var queue_bubble: PanelContainer
var queue_bubble_point: Dictionary = {}
var settings_buttons: Dictionary = {}
var _last_age_text: String = ""
var _bars_t: float = 0.0
var _layout_controls: Array[Control] = []
var _idle_cycle: int = 0
var _refusal_t: float = 0.0
var _shown_res: Dictionary = {}

func setup(p_game) -> void:
	game = p_game
	layer = 10
	AgeTheme.apply(AgeTheme.wanted_age(game))
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	feedback = UIFeedback.new()
	add_child(feedback)
	_build_top()
	_build_right()
	_build_bottom()
	_build_left()
	_build_overlays()
	_modal_scrim = ColorRect.new()
	_modal_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_scrim.color = AgeTheme.c("scrim")
	_modal_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_scrim.mouse_force_pass_scroll_events = false
	_modal_scrim.visible = false
	root.add_child(_modal_scrim)
	_ui_blockers.append(_modal_scrim)
	_safe_controls.assign(root.get_children().filter(func(node: Node) -> bool: return node is Control))
	for control in _safe_controls:
		control.set_meta("base_offsets", Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom))
	_apply_safe_layout()
	root.resized.connect(_on_root_resized)
	building_drawer = BuildingDrawer.new()
	root.add_child(building_drawer)
	building_drawer.setup(game)
	_ui_blockers.append(building_drawer)
	_build_late()
	AgeTheme.on_changed(_on_theme_changed)
	selection_changed()
	call_deferred("_apply_ui_preferences")

func _make_theme() -> Theme:
	return MobileUI.theme()

func _btn(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	if text == "[maison]":
		b.text = ""
		b.icon = ICON_HOME
	elif text == "[menu]":
		b.text = ""
		b.icon = ICON_PAUSE
		b.tooltip_text = "Pause et réglages"
	elif text == "+ Bâtir":
		b.text = "Bâtir"
		b.icon = ICON_BUILD
	elif text == "[choisir]":
		b.text = "Choisir"
		b.icon = ICON_SELECT
	elif text == "[armées]":
		b.text = "Armées"
		b.icon = ICON_ARMY
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 22)
	b.custom_minimum_size = Vector2(min_w, BTN_H)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	if feedback != null:
		feedback.decorate(b)
	return b

func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	_ui_blockers.append(p)
	return p

# ------------------------------------------------------------------ construction de l'interface

func _build_top() -> void:
	var p := _panel(root)
	p.position = Vector2(12, 12)
	top_panel = p
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 5)
	h.add_theme_constant_override("v_separation", 5)
	p.add_child(h)
	top_flow = h
	for r in Rules.RESOURCES:
		var chip := ResChip.new()
		chip.res = r
		chip.color = RES_COLORS[r]
		chip.custom_minimum_size = Vector2(102, BTN_H + 3)
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(_cycle_priority.bind(r))
		h.add_child(chip)
		res_chips[r] = chip
	pop_btn = _btn("", _pop_pressed, 156)
	pop_btn.custom_minimum_size = Vector2(156, BTN_H + 3)
	pop_btn.tooltip_text = "Population et ouvriers : toucher = ouvriers inactifs, ou maison si la population est pleine"
	h.add_child(pop_btn)
	pop_label = Label.new()
	pop_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_label.offset_left = 8
	pop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_label.add_theme_font_size_override("font_size", 14)
	pop_btn.add_child(pop_label)
	age_btn = _btn("Âge I", _age_pressed, 132)
	age_btn.add_theme_font_size_override("font_size", 14)
	h.add_child(age_btn)
	if game.campaign != null and game.campaign.evolutions_enabled:
		h.add_child(_btn("Conseil", func(): game.evolution_panel.open(), 100))
	if CivEvolution.enabled(game.world):
		h.add_child(_btn("Civilisation", func(): if game.civ_panel != null: game.civ_panel.open(), 140))
	if UrbanCity.enabled(game.world):
		city_btn = _btn("Ville", func(): if game.city_panel != null: game.city_panel.open(), 96)
		city_btn.tooltip_text = "Ville : bien-être, réseaux, production, conseils et vues au sol (après la recherche Électricité)"
		h.add_child(city_btn)

func _build_right() -> void:
	# La mini-carte et les escouades ne sont plus imposées sur toute la hauteur.
	minimap_panel = _panel(root)
	minimap_panel.anchor_left = 1.0
	minimap_panel.anchor_right = 1.0
	minimap_panel.offset_left = -222
	minimap_panel.offset_right = -12
	minimap_panel.offset_top = 12
	var mv := HBoxContainer.new()
	mv.add_theme_constant_override("separation", 5)
	minimap_panel.add_child(mv)
	minimap_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap = TextureRect.new()
	minimap.custom_minimum_size = Vector2(MINIMAP_SIDE, MINIMAP_SIDE)
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	# 0.18.1 : la carte reste carrée (elle s'étirait sur la hauteur de la colonne de boutons).
	minimap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.mouse_force_pass_scroll_events = false
	minimap.gui_input.connect(_minimap_input)
	mini_img = Image.create(game.world.map_size, game.world.map_size, false, Image.FORMAT_RGB8)
	mini_tex = ImageTexture.create_from_image(mini_img)
	minimap.texture = mini_tex
	mv.add_child(minimap)
	var mb := VBoxContainer.new()
	mb.add_theme_constant_override("separation", 4)
	mv.add_child(mb)
	mb.add_child(_btn("[menu]", _toggle_menu, 48))
	active_pause_btn = _btn("‖", _toggle_active_pause, 48)
	active_pause_btn.tooltip_text = "Pause active : la partie s'arrête, vous pouvez encore donner des ordres"
	mb.add_child(active_pause_btn)
	speed_btn = _btn("×1", _cycle_speed, 66)
	speed_btn.tooltip_text = "Vitesse de simulation : 0,5× / 1× / 2× / 4× / 8×"
	mb.add_child(speed_btn)
	_refresh_speed_caption()
	minimap_toggle = _btn("–", _toggle_minimap, 48)
	minimap_toggle.tooltip_text = "Afficher/masquer la mini-carte"
	mb.add_child(minimap_toggle)
	minimap_toggle.text = "−"
	minimap_toggle.tooltip_text = "Replier / déplier la mini-carte"
	minimap_toggle.visible = true
	# Liste repliable : accessible sans couvrir en permanence le champ de bataille.
	command_bars = CommandBars.new()
	command_bars.anchor_left = 1.0
	command_bars.anchor_right = 1.0
	command_bars.offset_left = -248
	command_bars.offset_right = -12
	command_bars.offset_top = 326
	command_bars.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(command_bars)
	command_bars.setup(game)
	_ui_blockers.append(command_bars)
	var launcher := _panel(root)
	launcher.anchor_left = 1.0
	launcher.anchor_right = 1.0
	launcher.offset_left = -154
	launcher.offset_right = -12
	launcher.offset_top = 258
	squad_toggle = _btn("[armées]", _toggle_squads, 122)
	launcher.add_child(squad_toggle)
	squad_panel = _panel(root)
	squad_panel.anchor_left = 1.0
	squad_panel.anchor_right = 1.0
	squad_panel.offset_left = -252
	squad_panel.offset_right = -12
	squad_panel.offset_top = 326
	squad_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	squad_panel.add_child(v)
	var t := Label.new()
	t.text = "COMMANDEMENT"
	t.add_theme_font_size_override("font_size", 14)
	v.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(208, 0)
	scroll.size = Vector2(208, 124)
	scroll.custom_minimum_size.y = 124
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	squad_box = VBoxContainer.new()
	squad_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	squad_box.add_theme_constant_override("separation", 4)
	scroll.add_child(squad_box)
	army_btn = _btn("Défendre un secteur", _start_delegate)
	v.add_child(army_btn)
	army_cancel_btn = _btn("Arrêter délégation", func(): game.world.issue({"t": "army_cancel", "team": game.player}))
	v.add_child(army_cancel_btn)

func _build_bottom() -> void:
	# Les boutons permanents ne couvrent pas la sélection ; le panneau n'apparaît que si nécessaire.
	var tools := _panel(root)
	tools.anchor_top = 1.0
	tools.anchor_bottom = 1.0
	tools.offset_left = 12
	tools.offset_top = -76
	tools.offset_bottom = -12
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 6)
	tools.add_child(tool_row)
	build_btn = _btn("+ Bâtir", _toggle_build, 106)
	tool_row.add_child(build_btn)
	box_btn = _btn("[choisir]", _toggle_box, 114)
	box_btn.tooltip_text = "Sélection par rectangle : glisser sur la carte"
	tool_row.add_child(box_btn)
	var home := _btn("[maison]", _focus_home, 52)
	home.tooltip_text = "Centrer sur le commandement"
	tool_row.add_child(home)
	# 0.19 : zonage peint (habitat, commerce, industrie, agriculture, routes) dans les parties avec la civilisation.
	zones_btn = _btn("Zones", toggle_zoning, 96)
	zones_btn.tooltip_text = "Zonage : peindre des zones et tracer des routes ; la ville se construit seule"
	zones_btn.visible = UrbanCity.enabled(game.world)
	tool_row.add_child(zones_btn)
	# 0.17 : sélections globales au pouce gauche (une touche chacune).
	quick_panel = _panel(root)
	quick_panel.anchor_top = 1.0
	quick_panel.anchor_bottom = 1.0
	quick_panel.offset_left = 12
	quick_panel.offset_top = -144
	quick_panel.offset_bottom = -84
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	quick_panel.add_child(quick)
	idle_btn = _btn("Inactifs 0", _select_idle, 104)
	idle_btn.tooltip_text = "Ouvriers inactifs : un toucher les sélectionne tous ; chaque toucher centre sur le suivant"
	quick.add_child(idle_btn)
	army_select_btn = _btn("Armée", func(): game.select_army(), 74)
	army_select_btn.tooltip_text = "Sélectionner toute l'armée de cette carte"
	quick.add_child(army_select_btn)
	hero_btn = _btn("Héros", func(): game.select_heroes(), 70)
	hero_btn.tooltip_text = "Sélectionner les héros présents"
	hero_btn.visible = CivEvolution.enabled(game.world)
	quick.add_child(hero_btn)
	produce_btn = _btn("Former", _toggle_production, 76)
	produce_btn.tooltip_text = "Former une unité depuis n'importe où (producteur le moins chargé)"
	quick.add_child(produce_btn)
	add_btn = _btn("+", _toggle_additive, 48)
	add_btn.tooltip_text = "Sélection additive : toucher des unités les ajoute ou les retire (rectangle : ajoute)"
	quick.add_child(add_btn)
	sel_panel = _panel(root)
	sel_panel.anchor_left = 0.0
	sel_panel.anchor_right = 1.0
	sel_panel.anchor_top = 1.0
	sel_panel.anchor_bottom = 1.0
	sel_panel.offset_left = 434
	sel_panel.offset_right = -12
	sel_panel.offset_top = -145
	sel_panel.offset_bottom = -12
	sel_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	sel_panel.add_child(v)
	sel_title = Label.new()
	sel_title.add_theme_font_size_override("font_size", 17)
	v.add_child(sel_title)
	sel_info = Label.new()
	sel_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_info.add_theme_font_size_override("font_size", 13)
	v.add_child(sel_info)
	var actions_scroller := ScrollContainer.new()
	actions_scroller.custom_minimum_size = Vector2(0, 57)
	actions_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	actions_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(actions_scroller)
	sel_actions = HBoxContainer.new()
	sel_actions.add_theme_constant_override("separation", 5)
	actions_scroller.add_child(sel_actions)
	actions_scroller.name = "ActionsScroller"
	selection_bar = SelectionBar.new()
	selection_bar.setup(game)
	selection_bar.visible = false
	v.add_child(selection_bar)
	command_card = CommandCard.new()
	command_card.anchor_left = 1.0
	command_card.anchor_right = 1.0
	command_card.anchor_top = 1.0
	command_card.anchor_bottom = 1.0
	command_card.offset_left = -370
	command_card.offset_right = -12
	command_card.offset_top = -196
	command_card.offset_bottom = -12
	command_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	command_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(command_card)
	command_card.setup(game)
	_ui_blockers.append(command_card)
	build_panel = _panel(root)
	build_panel.anchor_top = 1.0
	build_panel.anchor_bottom = 1.0
	build_panel.offset_left = 12
	build_panel.offset_top = -420
	build_panel.offset_bottom = -84
	build_panel.visible = false
	build_grid = GridContainer.new()
	build_grid.columns = 2
	build_grid.add_theme_constant_override("h_separation", 6)
	build_grid.add_theme_constant_override("v_separation", 5)
	var build_scroll := ScrollContainer.new()
	build_scroll.custom_minimum_size = Vector2(380, 320)
	build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_panel.add_child(build_scroll)
	build_scroll.add_child(build_grid)
	for type in ["maison", "ferme", "entrepot", "caserne", "marche", "relais", "palissade", "fort", "atelier", "centre", "usine", "academie", "depot", "gare", "aerodrome", "radar", "silo", "intercepteur", "spatioport", "chantier_orbital"]:
		var b := DataCard.new()
		b.setup(String(Rules.BUILDINGS[type]["label"]),Portraits.building(type,game.world.teams[game.player].age),Rules.cost_text(Rules.BUILDINGS[type]["cost"]),_choose_building.bind(type))
		b.set_meta("type", type)
		b.custom_minimum_size.y = 154
		build_grid.add_child(b)
	place_bar = HFlowContainer.new()
	place_bar.add_theme_constant_override("h_separation", 6)
	place_bar.add_theme_constant_override("v_separation", 6)
	var pp := _panel(root)
	pp.anchor_left = 0.5
	pp.anchor_right = 0.5
	pp.anchor_top = 1.0
	pp.anchor_bottom = 1.0
	pp.offset_left = -380
	pp.offset_right = 380
	pp.offset_top = -214
	pp.offset_bottom = -144
	pp.add_child(place_bar)
	pp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	place_label = Label.new()
	place_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_label.custom_minimum_size = Vector2(300, 0)
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_label.add_theme_font_size_override("font_size", 14)
	place_bar.add_child(place_label)
	line_btn = _btn("Ligne", _toggle_line, 74)
	line_btn.tooltip_text = "Pose en ligne : glisser le doigt pour aligner murs ou maisons, puis Valider"
	place_bar.add_child(line_btn)
	multi_btn = _btn("Plusieurs", _toggle_multi, 96)
	multi_btn.tooltip_text = "Pose multiple : le mode reste actif ; un toucher sur un emplacement valide pose aussitôt"
	place_bar.add_child(multi_btn)
	place_ok = _btn("Valider", func(): game.confirm_placement(), 96)
	place_bar.add_child(place_ok)
	place_bar.add_child(_btn("Annuler", func(): game.cancel_mode(), 96))
	pp.visible = false
	place_bar.set_meta("panel", pp)

func _build_overlays() -> void:
	# Commandes disposées autour d'un centre, lisibles au pouce (pas de shader circulaire coûteux).
	radial_panel = _panel(root)
	radial_panel.visible = false
	var rad := Control.new()
	rad.name = "RadialBody"
	rad.custom_minimum_size = Vector2(302, 218)
	radial_panel.add_child(rad)
	var rad_title := Label.new()
	rad_title.name = "Title"
	rad_title.text = "ORDRES"
	rad_title.position = Vector2(114, 101)
	rad_title.theme_type_variation = "HeaderLabel"
	rad.add_child(rad_title)
	var walk := _btn("Marcher", _radial_move, 94)
	walk.position = Vector2(104, 4)
	rad.add_child(walk)
	var assault := _btn("Assaut", _radial_assault, 94)
	assault.position = Vector2(6, 83)
	rad.add_child(assault)
	var target := _btn("Déf. armée", _radial_target_action, 94)
	target.name = "TargetAction"
	target.position = Vector2(203, 83)
	rad.add_child(target)
	var cancel := _btn("Annuler", close_radial, 94)
	cancel.position = Vector2(104, 162)
	rad.add_child(cancel)
	# 0.17 : menu circulaire enrichi (arrêt, tenir, repli), cibles de 48 px minimum.
	var stop_button := _btn("Arrêt", func(): command_card.run("stop"); close_radial(), 94)
	stop_button.position = Vector2(6, 4)
	rad.add_child(stop_button)
	var hold_button := _btn("Tenir", func(): command_card.run("hold"); close_radial(), 94)
	hold_button.position = Vector2(203, 4)
	rad.add_child(hold_button)
	var retreat_button := _btn("Repli", func(): command_card.run("retreat"); close_radial(), 94)
	retreat_button.position = Vector2(6, 162)
	rad.add_child(retreat_button)
	var garrison_button := _btn("Garnison", _radial_garrison, 94)
	garrison_button.name = "Garrison"
	garrison_button.position = Vector2(203, 162)
	rad.add_child(garrison_button)
	if game.campaign != null and game.campaign.evolutions_enabled:
		rad.custom_minimum_size.y = 336
		var advanced := GridContainer.new()
		advanced.columns = 2
		advanced.position = Vector2(4, 220)
		rad.add_child(advanced)
		for kind in ["patrol", "wait", "defend", "escort"]:
			advanced.add_child(_btn({"patrol": "Patrouille", "wait": "Pause 10 s", "defend": "Tenir", "escort": "Escorter"}[kind], _queue_advanced.bind(kind), 143))
	# Rectangle de sélection dessiné sans intercepter les événements tactiles.
	var selection_overlay := SelectionOverlay.new()
	selection_overlay.name = "SelectionOverlay"
	selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(selection_overlay)
	hint_label = Label.new()
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.offset_left = -300
	hint_label.offset_right = 300
	hint_label.offset_top = 86
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_label)
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_left = -330
	toast_box.offset_right = 330
	toast_box.offset_top = 118
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	perf_label = Label.new()
	perf_label.position = Vector2(10, 84)
	perf_label.add_theme_font_size_override("font_size", 13)
	perf_label.add_theme_color_override("font_outline_color", Color.BLACK)
	perf_label.add_theme_constant_override("outline_size", 4)
	perf_label.visible = GameConfig.show_perf
	root.add_child(perf_label)
	ai_label = Label.new()
	ai_label.position = Vector2(10, 150)
	ai_label.custom_minimum_size = Vector2(560, 0)
	ai_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_label.add_theme_font_size_override("font_size", 13)
	ai_label.add_theme_color_override("font_color", AgeTheme.c("warning"))
	ai_label.add_theme_color_override("font_outline_color", Color.BLACK)
	ai_label.add_theme_constant_override("outline_size", 4)
	ai_label.visible = GameConfig.show_ai_debug or game.scenario != null
	ai_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ai_label)
	lab_label = Label.new()
	lab_label.anchor_left = 1.0
	lab_label.anchor_right = 1.0
	lab_label.offset_left = -560
	lab_label.offset_right = -210
	lab_label.offset_top = 180
	lab_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab_label.add_theme_font_size_override("font_size", 12)
	lab_label.add_theme_color_override("font_outline_color", Color.BLACK)
	lab_label.add_theme_constant_override("outline_size", 4)
	lab_label.visible = game.scenario != null
	lab_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lab_label)
	# panneau de passage d'âge
	age_panel = _panel(root)
	age_panel.position = Vector2(300, 80)
	age_panel.visible = false
	var av := VBoxContainer.new()
	age_panel.add_child(av)
	age_label = Label.new()
	age_label.custom_minimum_size = Vector2(440, 0)
	age_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	av.add_child(age_label)
	var ah := HBoxContainer.new()
	av.add_child(ah)
	ah.add_child(_btn("Lancer le passage", _do_age_up, 200))
	ah.add_child(_btn("Parcours technologique", _toggle_tech_panel, 230))
	ah.add_child(_btn("Fermer", _toggle_age_panel, 110))
	# menu pause
	menu_panel = _panel(root)
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left = -170
	menu_panel.offset_right = 170
	menu_panel.offset_top = -280
	menu_panel.offset_bottom = 280
	menu_panel.visible = false
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 3)
	menu_panel.offset_left = -245
	menu_panel.offset_right = 245
	menu_panel.offset_top = -240
	menu_panel.offset_bottom = 240
	var menu_scroll := ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_panel.add_child(menu_scroll)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.add_child(mv)
	var ml := Label.new()
	ml.text = "Pause — graine %d" % game.world.seed_value
	mv.add_child(ml)
	mv.add_child(_btn("Reprendre", _toggle_menu))
	mv.add_child(_btn("Sauvegarder", game.save_match))
	mv.add_child(_btn("Charger la sauvegarde", game.load_match))
	mv.add_child(_btn("Mesures (FPS, simulation)", func(): perf_label.visible = not perf_label.visible))
	mv.add_child(_btn("Accélérer la simulation", _cycle_speed))
	quality_btn = _btn("Graphismes : Équilibré", _cycle_quality)
	mv.add_child(quality_btn)
	mv.add_child(_btn("Mini-carte : afficher / masquer", _toggle_minimap))
	var adaptive := CheckButton.new()
	adaptive.text = "Adapter les graphismes à la charge"
	adaptive.custom_minimum_size.y = 48
	adaptive.button_pressed = GameConfig.adaptive_visuals
	adaptive.toggled.connect(func(enabled: bool):
		GameConfig.adaptive_visuals = enabled
		game.mobile_perf.stage = 0
		game._apply_render_profile()
		GameConfig.save_preferences())
	mv.add_child(adaptive)
	_refresh_quality_caption()
	_build_interface_settings(mv)
	mv.add_child(_btn("Progression : accès aux vues", _toggle_tech_panel))
	mv.add_child(_btn("Gestes et commandes", _toggle_controls))
	mv.add_child(_btn("Débogage IA", func(): ai_label.visible = not ai_label.visible))
	mv.add_child(_btn("Ombres oui/non", func(): game.set_shadows(not game.sun.shadow_enabled)))
	mv.add_child(_btn("Quitter vers le menu", func(): game.get_tree().change_scene_to_file("res://game/main_menu.tscn")))
	# Arbre technologique plein écran, défilable sur mobile en paysage.
	tech_panel = _panel(root)
	tech_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tech_panel.offset_left = 14
	tech_panel.offset_top = 12
	tech_panel.offset_right = -14
	tech_panel.offset_bottom = -12
	tech_panel.visible = false
	var tech_scroll := ScrollContainer.new()
	tech_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tech_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tech_panel.add_child(tech_scroll)
	tech_rows = VBoxContainer.new()
	tech_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_rows.add_theme_constant_override("separation", 8)
	tech_scroll.add_child(tech_rows)
	tech_status = Label.new()
	tech_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tech_rows.add_child(tech_status)
	tech_rows.add_child(_btn("Fermer le parcours technologique", _toggle_tech_panel))
	# Aide consultable uniquement sur demande : l'écran reste dégagé pendant la partie.
	controls_panel = _panel(root)
	controls_panel.anchor_left = 0.5
	controls_panel.anchor_right = 0.5
	controls_panel.anchor_top = 0.5
	controls_panel.anchor_bottom = 0.5
	controls_panel.offset_left = -330
	controls_panel.offset_right = 330
	controls_panel.offset_top = -200
	controls_panel.offset_bottom = 200
	controls_panel.visible = false
	var cv := VBoxContainer.new()
	controls_panel.add_child(cv)
	var help := Label.new()
	help.text = "COMMANDES TACTILES\n\nToucher une escouade : sélectionner · double toucher rapide : tous les mêmes à l'écran\nDeuxième toucher lent : unité seule · appui long sur une unité : unité seule\nToucher le terrain : déplacement · toucher un ennemi : attaque\nGlisser depuis vos unités, ou appui long puis glisser : rectangle de sélection\nGlisser ailleurs : caméra · deux doigts : zoom et rotation\nAppui long au sol : menu d'ordres\nEnchaîner (carte de commandes) : chaque ordre s'ajoute à la file\nGroupes (bord gauche) : appui long = enregistrer, toucher = rappeler, double toucher = centrer"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 15)
	cv.add_child(help)
	cv.add_child(_btn("Fermer l'aide", _toggle_controls))
	over_panel = _panel(root)
	over_panel.anchor_left = 0.5
	over_panel.anchor_right = 0.5
	over_panel.anchor_top = 0.5
	over_panel.anchor_bottom = 0.5
	over_panel.offset_left = -220
	over_panel.offset_right = 220
	over_panel.offset_top = -90
	over_panel.offset_bottom = 90
	over_panel.visible = false
	var ov := VBoxContainer.new()
	over_panel.add_child(ov)
	over_label = Label.new()
	over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over_label.custom_minimum_size = Vector2(400, 0)
	over_label.add_theme_font_size_override("font_size", 22)
	ov.add_child(over_label)
	ov.add_child(_btn("Retour au menu", func(): game.get_tree().change_scene_to_file("res://game/main_menu.tscn")))
	ov.add_child(_btn("Observer", func(): over_panel.visible = false))

func is_over_ui(p: Vector2) -> bool:
	for c in _ui_blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false

# ------------------------------------------------------------------ actions

func toggle_zoning() -> void:
	## 0.19 : ouvre ou ferme le mode Zonage (calque coloré visible seulement pendant ce mode).
	var tool: ZoningTool = game.zoning_tool
	if tool.active:
		tool.close()
		UIMotion.conceal(zoning_panel)
		zones_btn.set_pressed_no_signal(false)
		return
	game.cancel_mode()
	game.clear_selection()
	if UIMotion.is_open(build_panel):
		_toggle_build()
	tool.open()
	UIMotion.reveal(zoning_panel)
	zoning_panel.refresh()

func _toggle_squads() -> void:
	UIMotion.toggle(squad_panel)
	squad_toggle.text = "Fermer" if UIMotion.is_open(squad_panel) else "Armées"
	if UIMotion.is_open(squad_panel):
		build_panel.visible = false
		close_radial()

func _toggle_minimap() -> void:
	minimap.visible = not minimap.visible
	minimap_panel.offset_left = -222 if minimap.visible else -77
	minimap_toggle.text = "–" if minimap.visible else "▯"

func _toggle_box() -> void:
	if game.mode != "":
		game.cancel_mode()
	game.box_select_mode = not game.box_select_mode
	set_select_mode(game.box_select_mode)
	build_panel.visible = false
	close_radial()

func set_select_mode(enabled: bool) -> void:
	box_btn.text = "Annuler" if enabled else "Choisir"
	box_btn.theme_type_variation = "ToggleOnButton" if enabled else ""
	if enabled:
		set_hint("Glissez pour encadrer vos unités · toucher le sol pour annuler")
	else:
		set_hint("")
		show_selection_rect(Vector2.ZERO, Vector2.ZERO, false)

func show_selection_rect(a: Vector2, b: Vector2, enabled: bool) -> void:
	var overlay: SelectionOverlay = root.get_node("SelectionOverlay") as SelectionOverlay
	overlay.begin = a
	overlay.end = b
	overlay.visible = enabled
	overlay.queue_redraw()

func open_radial(sp: Vector2, entity, where: Vector2) -> void:
	if not game.has_command_selection() or game.mode != "":
		return
	build_panel.visible = false
	squad_panel.visible = false
	squad_toggle.text = "Armées"
	radial_target = where
	radial_entity = entity
	var target: Button = radial_panel.get_node("RadialBody/TargetAction") as Button
	var hostile: bool = entity != null and game.world.factions.hostile(game.player, entity.team)
	target.text = "Cibler" if hostile else "Déf. armée"
	radial_panel.visible = true
	# Garder le panneau dans l'écran et hors de la zone directement pressée.
	var viewport_size: Vector2 = root.size
	var width := 326.0
	var height: float = 360.0 if game.campaign != null and game.campaign.evolutions_enabled else 242.0
	var top: float = sp.y - height - 18.0
	if top < 70.0:
		top = sp.y + 18.0
	radial_panel.position = Vector2(clampf(sp.x - width * 0.5, 8.0, maxf(8.0, viewport_size.x - width - 8.0)),
		clampf(top, 70.0, maxf(70.0, viewport_size.y - height - 12.0)))
	radial_open = true

func close_radial() -> void:
	radial_panel.visible = false
	radial_open = false
	radial_entity = null

func _radial_move() -> void:
	game.issue_radial("move", radial_target, null)
	close_radial()

func _radial_assault() -> void:
	game.issue_radial("amove", radial_target, null)
	close_radial()

func _radial_target_action() -> void:
	var e = radial_entity
	if e != null and game.world.factions.hostile(game.player, e.team):
		game.issue_radial("attack", radial_target, e)
	else:
		var r: Dictionary = game.world.issue({"t": "army_defend", "team": game.player,
			"pos": [radial_target.x, radial_target.y], "radius": 12.0})
		if bool(r.get("ok", false)):
			game.view.add_marker(radial_target, AgeTheme.c("info"))
			toast("Défense déléguée à l'armée", AgeTheme.c("info"))
	close_radial()

func _cycle_priority(r: String) -> void:
	if UrbanCity.active(game.world, game.player) and game.city_panel != null:
		game.city_panel.open()
		return
	var t: SimWorld.Team = game.world.teams[game.player]
	var v: int = (int(t.priorities[r]) + 1) % 4
	game.world.issue({"t": "set_priority", "team": game.player, "res": r, "value": v})
	toast("Priorité %s : %s" % [Rules.RES_LABEL[r], ["aucune", "basse", "moyenne", "haute"][v]], RES_COLORS[r].lightened(0.3))

func _toggle_age_panel() -> void:
	age_panel.visible = not age_panel.visible
	if age_panel.visible:
		build_panel.visible = false
		close_radial()

func _do_age_up() -> void:
	var r: Dictionary = game.world.issue({"t": "age_up", "team": game.player})
	if r["ok"]:
		age_panel.visible = false

func _toggle_tech_panel() -> void:
	tech_panel.visible = not tech_panel.visible
	if tech_panel.visible:
		age_panel.visible = false
		menu_panel.visible = false
		game.paused = false
		build_panel.visible = false
		close_radial()
		_refresh_tech_panel()

func _research_view_technology(key: String) -> void:
	if game.campaign == null or not Rules.TECHNOLOGIES.has(key):
		return
	var home: SimWorld = game.campaign.worlds.get("val") as SimWorld
	if home == null:
		tech_status.text = "Aucun centre de recherche principal disponible."
		return
	var tech: Dictionary = Rules.TECHNOLOGIES[key]
	var required_building: String = String(tech["building"])
	var buildings: Array = home.team_buildings(game.player, required_building, true)
	if buildings.is_empty():
		tech_status.text = "Bâtiment requis à Val : %s" % String(Rules.BUILDINGS[required_building]["label"])
		return
	var facility: SimWorld.Building = buildings[0] as SimWorld.Building
	var result: Dictionary = home.issue({"t": "technology", "team": game.player, "building": facility.id, "key": key})
	tech_status.text = "Recherche %s engagée" % String(tech["label"]) if bool(result.get("ok", false)) else String(result.get("reason", "Recherche refusée"))
	_refresh_tech_panel()

func _refresh_tech_panel() -> void:
	if tech_rows == null or game.campaign == null:
		return
	for child in tech_rows.get_children():
		if child != tech_status:
			tech_rows.remove_child(child)
			child.queue_free()
	var c: StarCampaign = game.campaign
	var age: int = int(c.ages[game.player])
	var unlocked: Dictionary = c.technologies[game.player] as Dictionary
	var home: SimWorld = c.worlds.get("val") as SimWorld
	tech_status.text = "ARBRE TECHNOLOGIQUE · âge %d\nChaque bâtiment améliore ses propres unités ; les recherches de navigation sont communes au camp." % age
	for step in ViewTechnology.PATH:
		var view_key: String = String(step["view"])
		var status: Dictionary = ViewTechnology.get_status(age, unlocked, view_key)
		var card := VBoxContainer.new()
		tech_rows.add_child(card)
		var caption := Label.new()
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.text = ("ACQUIS  ·  " if bool(status["ok"]) else "VERROUILLÉ  ·  ") + String(step["label"]) + ("" if bool(status["ok"]) else "\n" + String(status["reason"]))
		card.add_child(caption)
		if view_key == "galaxy":
			_add_tech_research_button(card, "navigation_stellaire", home, unlocked, age)
		var tech_key: String = String(step["tech"])
		if not tech_key.is_empty():
			_add_tech_research_button(card, tech_key, home, unlocked, age)
	var separator := Label.new()
	separator.text = "ÉVOLUTION DES BÂTIMENTS ET TROUPES — choisir un bâtiment sur la carte"
	separator.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tech_rows.add_child(separator)
	for kind in Rules.BUILDINGS:
		var definition: Dictionary = Rules.BUILDINGS[kind]
		if bool(definition.get("neutral", false)):
			continue
		var trained: Array = definition.get("trains", []) as Array
		if trained.is_empty():
			continue
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var titles := PackedStringArray()
		for unit_kind in trained:
			titles.append(AgeProgression.troop_name(String(unit_kind), 1) + " → " + AgeProgression.troop_name(String(unit_kind), 2) + " → " + AgeProgression.troop_name(String(unit_kind), 3))
		line.text = "%s (âge %d)\n%s" % [String(definition["label"]), int(definition.get("age", 1)), "\n".join(titles)]
		tech_rows.add_child(line)
	tech_rows.add_child(_btn("Fermer le parcours technologique", _toggle_tech_panel))

func _add_tech_research_button(parent: VBoxContainer, key: String, home: SimWorld, unlocked: Dictionary, age: int) -> void:
	var tech: Dictionary = Rules.TECHNOLOGIES[key]
	var facility_type: String = String(tech["building"])
	var building_name: String = String(Rules.BUILDINGS[facility_type]["label"])
	var reason: String = ""
	if unlocked.has(key):
		reason = "Acquise"
	elif age < int(tech["age"]):
		reason = "Âge %d requis" % int(tech["age"])
	else:
		for required_value in tech.get("requires", []):
			var required: String = String(required_value)
			if not unlocked.has(required):
				reason = "Prérequis : " + String(Rules.TECHNOLOGIES[required]["label"])
				break
	if reason.is_empty() and home != null:
		if not (home.teams[game.player] as SimWorld.Team).tech_research.is_empty():
			var running: Dictionary = (home.teams[game.player] as SimWorld.Team).tech_research
			reason = "Recherche en cours (%d s)" % ceili(float(running["remaining"]))
		elif home.team_buildings(game.player, facility_type, true).is_empty():
			reason = "Construire : " + building_name + " à Val"
		elif not home._can_pay(game.player, home.scaled_cost(tech["cost"])):
			reason = "Ressources insuffisantes"
	var button := _btn(String(tech["label"]) + " · " + Rules.cost_text(tech["cost"]) + "\n" + (reason if not reason.is_empty() else "Lancer la recherche"), _research_view_technology.bind(key))
	button.custom_minimum_size.y = 54
	button.disabled = not reason.is_empty()
	parent.add_child(button)

func _start_delegate() -> void:
	if game.mode != "":
		game.cancel_mode()
	squad_panel.visible = false
	squad_toggle.text = "Armées"
	game.mode = "delegate"
	set_hint("Touchez le secteur à défendre : l'armée répartit les escouades libres")

func _toggle_build() -> void:
	game.box_select_mode = false
	set_select_mode(false)
	UIMotion.toggle(build_panel)
	if build_panel.visible:
		squad_panel.visible = false
		squad_toggle.text = "Armées"
		close_radial()
		_refresh_build_buttons()

func _choose_building(type: String) -> void:
	build_panel.visible = false
	game.start_placement(type)

func _toggle_controls() -> void:
	game.cancel_gestures()
	controls_panel.visible = not controls_panel.visible
	menu_panel.visible = not controls_panel.visible
	game.paused = true

func _refresh_quality_caption() -> void:
	if quality_btn != null:
		quality_btn.text = "Graphismes : " + ["Économie", "Équilibré", "Détaillé"][GameConfig.visual_quality]

func _cycle_quality() -> void:
	game.set_visual_quality((GameConfig.visual_quality + 1) % 3)
	_refresh_quality_caption()
	toast("Profil graphique : " + ["Économie", "Équilibré", "Détaillé"][GameConfig.visual_quality])

func _toggle_menu() -> void:
	game.cancel_gestures()
	if controls_panel.visible:
		controls_panel.visible = false
	menu_panel.visible = not menu_panel.visible
	game.paused = menu_panel.visible
	game.touches.clear()
	game.pan_velocity = Vector3.ZERO
	if menu_panel.visible:
		close_radial()
		build_panel.visible = false
		squad_panel.visible = false
		squad_toggle.text = "Armées"

func _refresh_speed_caption() -> void:
	if speed_btn != null:
		speed_btn.text = "×%s" % str(game.speed).replace(".0", "")

func _cycle_speed() -> void:
	game.set_simulation_speed(GameConfig.next_speed(game.speed))
	toast("Simulation ×%s" % str(game.speed).replace(".0", ""))

func _minimap_input(ev: InputEvent) -> void:
	var p := Vector2(-1, -1)
	if ev is InputEventScreenTouch and ev.pressed:
		p = ev.position
	elif ev is InputEventMouseButton and ev.pressed:
		p = ev.position
	elif ev is InputEventScreenDrag:
		p = ev.position
	if p.x >= 0:
		var s := minimap.size
		if s.x <= 0.0 or s.y <= 0.0:
			return
		game.focus(Vector2(clampf(p.x / s.x, 0.0, 1.0) * game.world.map_size,
			clampf(p.y / s.y, 0.0, 1.0) * game.world.map_size))
		minimap.accept_event()

func set_hint(t: String) -> void:
	hint_label.text = t

func toast(text: String, color: Color = Color.TRANSPARENT) -> void:
	if text == "":
		return
	var now := Time.get_ticks_msec()
	if _last_toast.get(text, 0) > now - 2500:
		return
	_last_toast[text] = now
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", AgeTheme.c("text") if color.a <= 0.0 else color)
	l.add_theme_color_override("font_outline_color", AgeTheme.c("bg"))
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_font_size_override("font_size", 18)
	l.set_meta("t", 0.0)
	toast_box.add_child(l)
	while toast_box.get_child_count() > 4:
		var c := toast_box.get_child(0)
		toast_box.remove_child(c)
		c.queue_free()

func on_event(e: Dictionary) -> void:
	var team: int = e["team"]
	var mine: bool = team == game.player
	match e["type"]:
		"refus":
			if mine:
				toast(e["text"], AgeTheme.c("danger"))
		"penurie", "pop", "alerte_missile", "recherche_perdue":
			if mine:
				toast(e["text"], AgeTheme.c("warning"))
		"technologie", "interception", "penurie_fin", "reaffectation", "acheve", "comptoir", "age", "armee", "controle", "garnison":
			if mine:
				toast(e["text"], AgeTheme.c("success"))
		"epuise":
			if mine:
				toast("Gisement épuisé : les ouvriers cherchent le plus proche", AgeTheme.c("warning"))
		"age_atteint":
			toast(e["text"], AgeTheme.c("info"))
			if mine:
				_last_age_text = String(e["text"])
				check_theme_age()
		"detruit":
			if mine:
				toast(e["text"], AgeTheme.c("danger"))
			elif team != SimWorld.TEAM_NEUTRAL:
				toast("Ennemi : " + e["text"], AgeTheme.c("info"))
		"elimine":
			toast(e["text"], AgeTheme.c("warning"))
		"fin":
			over_panel.visible = true
			over_label.text = ("Victoire !" if e["winner"] == game.player else "Défaite") + "\n" + e["text"] + "\nDurée : %d min %02d s" % [game.world.tick / 600, (game.world.tick / 10) % 60]
	if alerts != null:
		alerts.on_event(e)
	if e["type"] == "unite" and mine and building_drawer != null and building_drawer.visible:
		var recruit: SimWorld.Unit = game.world.units.get(int(e.get("unit", -1))) as SimWorld.Unit
		if recruit != null:
			for card in building_drawer.cards:
				if (card as DataCard).key == recruit.type:
					UIFeedback.pulse(card, 0.5)
	if e["type"] in ["mort", "detruit", "unite", "escouade"]:
		_sel_dirty = true

func show_info(e) -> void:
	_info_entity = e
	_sel_dirty = true

func selection_changed() -> void:
	if building_drawer != null:
		if game.sel_building >= 0: building_drawer.open_building(game.sel_building)
		else: building_drawer.close_drawer()
	_info_entity = null
	_sel_dirty = true
	if radial_open:
		close_radial()

func placement_changed() -> void:
	var pp: Control = place_bar.get_meta("panel")
	pp.visible = game.mode == "place"
	if game.mode == "place":
		var why: String = game.world.build_check(game.player, game.place_type, game.place_cell)
		place_label.text = "%s (%s) — touchez le sol pour placer. %s" % [Rules.BUILDINGS[game.place_type]["label"],
			Rules.cost_text(Rules.BUILDINGS[game.place_type]["cost"]), "Emplacement valide." if why == "" else "Impossible : " + why]
		place_ok.disabled = why != "" and not (game.placement_tool.line_mode and game.placement_tool.cells.size() > 1)
		line_btn.theme_type_variation = "ToggleOnButton" if game.placement_tool.line_mode else ""
		multi_btn.theme_type_variation = "ToggleOnButton" if game.placement_tool.multi_mode else ""
		if game.placement_tool.line_mode and game.placement_tool.cells.size() > 1:
			place_label.text = "%s × %d en ligne (%s chacun) — Valider pour poser" % [Rules.BUILDINGS[game.place_type]["label"], game.placement_tool.cells.size(), Rules.cost_text(Rules.BUILDINGS[game.place_type]["cost"])]

# ------------------------------------------------------------------ rafraîchissement

func refresh(delta: float) -> void:
	_update_modal_scrim()
	_refresh_017(delta)
	if tech_panel != null and tech_panel.visible:
		_tech_refresh_timer += delta
		if _tech_refresh_timer >= 0.65:
			_tech_refresh_timer = 0.0
			_refresh_tech_panel()
	for l in toast_box.get_children():
		var t: float = l.get_meta("t") + delta
		l.set_meta("t", t)
		l.modulate.a = clampf(4.0 - t, 0.0, 1.0)
		if t > 4.0:
			l.queue_free()
	_refresh_t += delta
	_mini_t += delta
	if _mini_t > 0.5:
		_mini_t = 0.0
		if minimap.visible:
			_update_minimap()
	if _refresh_t < 0.15 and not _sel_dirty:
		return
	_refresh_t = 0.0
	var w: SimWorld = game.world
	var t: SimWorld.Team = w.teams[game.player]
	var counts := {"food": 0, "wood": 0, "ore": 0}
	for u in w.team_units(game.player, "worker"):
		if counts.has(u.task):
			counts[u.task] += 1
	var urban_on: bool = UrbanCity.active(w, game.player)
	if city_btn != null:
		city_btn.text = "Ville %d" % int(float(t.city.get("wellbeing", 0.0))) if urban_on else "Ville"
		city_btn.theme_type_variation = "ToggleOnButton" if urban_on and (int(t.city.get("burning", 0)) > 0 or int((t.city.get("power", [0, 0]) as Array)[1]) > int((t.city.get("power", [0, 0]) as Array)[0])) else ""
	for r in Rules.RESOURCES:
		var chip: ResChip = res_chips[r]
		chip.city = urban_on
		chip.amount = int(t.res[r])
		chip.workers = counts[r]
		chip.priority = int(t.priorities[r])
		chip.shortage = not t.res_access[r]
		chip.queue_redraw()
	var builders := 0
	var idle := 0
	for u in w.team_units(game.player, "worker"):
		if u.task == "build":
			builders += 1
		elif u.task == "" and not u.direct:
			idle += 1
	pop_label.text = "Pop. %d/%d\nChantier %d · Inactifs %d" % [t.pop, t.pop_cap, builders, idle]
	pop_label.add_theme_color_override("font_color", AgeTheme.c("warning") if t.pop >= t.pop_cap else AgeTheme.c("text"))
	idle_btn.text = "Inactifs %d" % idle
	idle_btn.theme_type_variation = "ToggleOnButton" if idle > 0 else ""
	var st := w.age_up_status(game.player)
	if not t.research.is_empty():
		age_btn.text = "Âge %s : %d%%" % [ROMAN[int(t.research["to"])], int(100.0 * (1.0 - t.research["remaining"] / t.research["total"]))]
	elif not Rules.AGE_UP.has(t.age + 1) or t.age + 1 > int(w.rule("max_age", 99)):
		age_btn.text = "Âge " + _age_name(t.age)
	else:
		age_btn.text = "Âge %s → %s" % [ROMAN[t.age], ROMAN[t.age + 1]] + (" (prêt)" if st["possible"] else "")
	var monument: String = ready_monument()
	if monument != "":
		age_btn.text = "Monument ! → %s" % ROMAN[t.age + 1]
		age_btn.theme_type_variation = "PrimaryButton"
	else:
		age_btn.theme_type_variation = ""
	age_label.text = _age_text(st, t)
	if squad_panel.visible:
		_refresh_squads()
	army_cancel_btn.visible = not t.army.is_empty()
	if game.mode == "place":
		placement_changed()
	if build_panel.visible:
		_refresh_build_buttons()
	_refresh_selection()
	if perf_label.visible:
		var visual: Dictionary = game.view.visual_stats()
		perf_label.text = "FPS %d · image %.1f ms · sim %.2f ms/tick · appels %d · prim. %dk · unités %d · rigs %d · effets %d · tick %d" % [
			Engine.get_frames_per_second(), 1000.0 / max(1, Engine.get_frames_per_second()), game.sim_ms,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			w.units.size(), int(visual["rigs"]), int(visual["effects"]), w.tick]
		if visual.has("chunks"):
			var chunks: Dictionary = visual["chunks"] as Dictionary
			perf_label.text += " · chunks %d/%d · LOD %d" % [int(chunks["resident"]), int(chunks["visible"]), int(chunks["lod_step"])]
	if ai_label.visible:
		var lines := PackedStringArray()
		for ai in w.ai_controllers:
			lines.append("IA camp %d [%s] objectif : %s | cible : %s" % [ai.team, ai.debug["opening"], ai.debug["objective"], ai.debug["target"]])
			lines.append("   infos utilisées : " + "; ".join(ai.debug["info"]))
			if ai.debug["abandon"] != "":
				lines.append("   dernier abandon : " + ai.debug["abandon"])
		ai_label.text = "\n".join(lines)
	if lab_label.visible and game.scenario != null:
		var sc: LabScenario = game.scenario
		var lines := PackedStringArray()
		lines.append("LABO %s — t=%ds" % [sc.data.get("name", ""), w.tick / 10])
		for r in sc.results:
			lines.append("%s %s" % ["PASS" if r["ok"] else "FAIL", r["label"]])
		lab_label.text = "\n".join(lines)

const ROMAN := ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
const AGE_UNLOCKS := {
	4: "Usine : fusiliers, obusiers, conversion bois/minerai et outillage.",
	5: "Académie, grenadiers et standardisation industrielle.",
	6: "Chars, aviation, antiaériens, gares, trains et ravitaillement.",
	7: "Radars, lance-missiles, silos et batteries antimissiles.",
	8: "Drones, brouilleurs et contre-mesures électroniques.",
	9: "Premier chantier naval orbital automatique, drones, modules spatiaux, navettes et satellites.",
	10: "Arsenal orbital, frégates, corridors interstellaires et conquêtes multisystèmes.",
	2: "Âge II : tireurs, cavaliers, marché, relais marchand, caravanes, échanges et palissades.",
	3: "Âge III : forts (tiennent un passage), atelier de siège et canons (mise en batterie, portée minimale).",
}

func _age_name(a: int) -> String:
	for ag in Rules.AGES:
		if int(ag["id"]) == a:
			return String(ag["name"])
	return ROMAN[a]

func _age_text(st: Dictionary, t: SimWorld.Team) -> String:
	var lines := PackedStringArray()
	lines.append("Âge actuel : " + _age_name(t.age))
	if not t.research.is_empty():
		lines.append("Passage à l'âge %s en cours : %d s restantes" % [_age_name(int(t.research["to"])), int(t.research["remaining"])])
		return "\n".join(lines)
	if st["cost"].is_empty():
		lines.append("Âge maximal disponible dans ce jalon atteint.")
		return "\n".join(lines)
	var to: int = st["to"]
	lines.append("Passage à l'âge " + _age_name(to))
	lines.append("Coût : %s — %s" % [Rules.cost_text(st["cost"]), "OK" if st["res_ok"] else "insuffisant"])
	lines.append("Objectif : %s — %s" % [Rules.OBJECTIVE_LABEL.get(st["objective"], st["objective"]), "atteint" if st["obj_ok"] else "à accomplir"])
	if st["objective"] == "comptoir_decouvert" and not st["obj_ok"]:
		lines.append("Astuce : envoyez l'éclaireur vers les coins de la carte, de votre côté de la rivière.")
	if st["objective"] == "tenir_gue" and not st["obj_ok"]:
		lines.append("Astuce : une palissade ou une maison achevée près d'un gué suffit ; le gué lui-même accepte palissades et forts.")
	if not st["possible"]:
		lines.append("Manque : " + "; ".join(st["missing"]))
	lines.append(AGE_UNLOCKS.get(to, ""))
	return "\n".join(lines)

func _refresh_squads() -> void:
	var w: SimWorld = game.world
	var squads := w.team_squads(game.player)
	while squad_box.get_child_count() < squads.size():
		var b := _btn("", func(): pass)
		b.custom_minimum_size.y = 46
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		squad_box.add_child(b)
	while squad_box.get_child_count() > squads.size():
		var c := squad_box.get_child(squad_box.get_child_count() - 1)
		squad_box.remove_child(c)
		c.queue_free()
	for i in squads.size():
		var s: SimWorld.Squad = squads[i]
		var b: Button = squad_box.get_child(i)
		var role: String = s.army_role if s.army_role != "" else ("Ordre direct" if s.direct else "En attente")
		b.text = "%d · %d u. · %s" % [s.number, s.units.size(), role]
		b.theme_type_variation = "ToggleOnButton" if game.sel_squad == s.id else ""
		if int(b.get_meta("squad", -1)) != s.id:
			for c in b.pressed.get_connections():
				b.pressed.disconnect(c["callable"])
			b.pressed.connect(_squad_button.bind(s.id))
			b.set_meta("squad", s.id)

func _squad_button(sid: int) -> void:
	if game.sel_squad == sid:
		game.focus(game.world._squad_center(game.world.squads[sid]))
	game.select_squad(sid)

func _refresh_build_buttons() -> void:
	var w: SimWorld = game.world
	for b in build_grid.get_children():
		var type: String = b.get_meta("type")
		var def: Dictionary = Rules.BUILDINGS[type]
		var locked: bool = w.teams[game.player].age < int(def["age"])
		if b is DataCard:
			b.caption.text=String(def["label"])
			b.picture.texture=Portraits.building(type,maxi(game.world.teams[game.player].age,int(def["age"])))
			b.description.text=Rules.cost_text(def["cost"])
			b.availability("Âge "+ROMAN[int(def["age"])]+" requis" if locked else "")
		else: b.text = "%s\n%s" % [def["label"], Rules.cost_text(def["cost"]) ]
		b.disabled = locked
		b.add_theme_font_size_override("font_size", 14)

func _clear_actions() -> void:
	for c in sel_actions.get_children():
		sel_actions.remove_child(c)
		c.queue_free()

func _refresh_selection() -> void:
	if selection_bar != null and selection_bar.visible:
		selection_bar.refresh()
	if building_drawer != null and game.sel_building >= 0:
		sel_panel.hide()
		building_drawer.refresh()
		return
	sel_panel.visible = game.sel_squad != -1 or not game.sel_units.is_empty() or game.sel_building != -1 or _info_entity != null
	var w: SimWorld = game.world
	var rebuild := _sel_dirty
	_sel_dirty = false
	if game.sel_squad != -1 and w.squads.has(game.sel_squad):
		var s: SimWorld.Squad = w.squads[game.sel_squad]
		var types := {}
		var hp := 0.0
		var mhp := 0.0
		for u in w._squad_members(s):
			types[Rules.UNITS[u.type]["label"]] = types.get(Rules.UNITS[u.type]["label"], 0) + 1
			hp += u.hp
			mhp += u.max_hp
		var comp := PackedStringArray()
		for k in types.keys():
			comp.append("%d %s" % [types[k], k])
		sel_title.text = "Escouade %d — %s" % [s.number, ", ".join(comp)]
		var mode_txt := "ordre direct du joueur (prioritaire sur la délégation)" if s.direct else ("délégation : " + s.army_role if s.army_role != "" else "en attente")
		sel_info.text = "Santé %d%% · %s%s\nTerrain : marcher · ennemi : cibler · appui long au sol : ordres avancés." % [int(100 * hp / max(1.0, mhp)), mode_txt, _command_status()]
		if rebuild:
			_clear_actions()
			if s.direct:
				sel_actions.add_child(_btn("Rendre à l'armée", func(): w.issue({"t": "release_squad", "team": game.player, "squad": s.id}); game.hud.selection_changed()))
			sel_actions.add_child(_btn("Centrer", func(): game.focus(w._squad_center(s))))
			sel_actions.add_child(_btn("Désélectionner", func(): game.clear_selection()))
		return
	if game.sel_squad != -1:
		game.sel_squad = -1
		rebuild = true
	if not game.sel_units.is_empty():
		var u = w.units.get(game.sel_units[0])
		if u == null:
			game.clear_selection()
			return
		var def: Dictionary = Rules.UNITS[u.type]
		if game.sel_units.size() > 1:
			sel_title.text = "%d unités sélectionnées" % game.sel_units.size()
			sel_info.text = "Toucher le terrain : déplacement groupé · toucher un ennemi : attaque%s" % _command_status()
			if rebuild:
				_clear_actions()
				sel_actions.add_child(_btn("Centrer", func(): game.focus(game.selection_center()), 96))
				sel_actions.add_child(_btn("Annuler", func(): game.clear_selection(), 96))
			return
		sel_title.text = "%s #%d" % [def["label"], u.id]
		var st := _state_text(u) + " · " + AgeProgression.troop_name(u.type, u.evolution) + " (niv.%d)" % u.evolution
		var ctrl := "contrôle direct (hors escouade et délégation)" if u.direct else ("dans l'escouade %d" % w.squads[u.squad_id].number if w.squads.has(u.squad_id) else "autonome")
		sel_info.text = "Santé %d/%d · %s · %s%s%s" % [int(u.hp), int(u.max_hp), st, ctrl, _command_status(), ("\nProblème : " + u.blocked_reason) if u.blocked_reason != "" else ""]
		if Rules.unit_has(u.type, "vehicle") or Rules.unit_has(u.type, "air"):
			sel_info.text += "\nRavitaillement : %d%% · efficacité : %d%%" % [int(u.supply), int(100.0 * ModernSystems.efficiency(w, u))]
		if rebuild:
			_clear_actions()
			if u.direct:
				var lbl := "Rendre à l'escouade" if w.squads.has(u.squad_id) else ("Rendre à l'économie" if Rules.unit_has(u.type, "worker") else "Rendre la main")
				sel_actions.add_child(_btn(lbl, func(): w.issue({"t": "release_unit", "team": game.player, "unit": u.id}); game.hud.selection_changed()))
			if w.squads.has(u.squad_id):
				sel_actions.add_child(_btn("Sélectionner l'escouade", func(): game.select_squad(u.squad_id)))
			sel_actions.add_child(_btn("Centrer", func(): game.focus(u.pos)))
		return
	if game.sel_building != -1:
		var b = w.buildings.get(game.sel_building)
		if b == null:
			game.clear_selection()
			return
		var def: Dictionary = Rules.BUILDINGS[b.type]
		sel_title.text = def["label"] + ("" if b.complete else " (chantier %d%%)" % int(b.progress * 100))
		var q := PackedStringArray()
		for ut in b.queue:
			q.append(Rules.UNITS[ut]["label"])
		var info := "Santé %d/%d · %s (niv. %d)" % [int(b.hp), int(b.max_hp), AgeProgression.building_name(b.type, b.tier), b.tier]
		if not b.upgrade_job.is_empty():
			info += "\nÉvolution en cours : %d s" % ceili(float(b.upgrade_job["remaining"]))
		if not b.queue.is_empty():
			info += " · Production : %s (%d%%)" % [", ".join(q), int(100 * b.prod_timer / float(Rules.UNITS[b.queue[0]]["time"]))]
		if not b.rally_contract.is_empty():
			info += "\nDrapeau v%d · %s (%.0f, %.0f)" % [b.rally_revision, b.rally_contract["kind"], b.rally.x, b.rally.y]
		if b.prod_blocked != "":
			info += "\nBloqué : " + b.prod_blocked
		if def.get("trade_hub", false):
			info += "\nCommerce : les caravanes rapportent %s ; taux d'échange %d%%." % [Rules.RES_LABEL[w.teams[game.player].trade_res].to_lower(), int(w.teams[game.player].exchange_rate * 100)]
		if b.type == "relais":
			info += "\nInvestissement exposé : un relais détruit coupe la route commerciale."
		if b.type == "usine":
			info += "\nIndustrie : 2 bois/s → 1,5 minerai/s."
		if b.type in ["gare", "depot", "aerodrome"]:
			info += "\nRéseau : " + ("relié au centre" if w.modern["connected"].has(b.id) else "isolé — relais à moins de 24 cases")
		if b.type == "silo" or b.type == "intercepteur":
			info += "\nRecharge : %d s" % ceili(b.cd)
		if not w.teams[game.player].tech_research.is_empty():
			info += "\nRecherche : %s (%d s)" % [w.teams[game.player].tech_research["key"], ceili(float(w.teams[game.player].tech_research["remaining"]))]
		sel_info.text = info
		if rebuild or _train_buttons_stale(b):
			_clear_actions()
			if b.complete and not (def.get("trains", []) as Array).is_empty():
				sel_actions.add_child(_btn("Point de ralliement", func(): game.begin_rally(false), 180))
			for ut in def.get("trains", []):
				var ud: Dictionary = Rules.UNITS[ut]
				var why: String = w.train_check(game.player, b, ut)
				var style_level: int = int(b.unit_evolutions.get(ut, 1))
				var bt := _btn("%s · niv.%d\n%s" % [AgeProgression.troop_name(ut, style_level), style_level, Rules.cost_text(ud["cost"])], _train.bind(b.id, ut), 150)
				bt.custom_minimum_size.y = 56
				bt.add_theme_font_size_override("font_size", 14)
				bt.disabled = w.teams[game.player].age < int(ud["age"])
				bt.tooltip_text = why
				sel_actions.add_child(bt)
			if b.team == game.player and b.complete and b.type != "comptoir":
				var bstate: Dictionary = AgeProgression.upgrade_status(w, game.player, b, "building")
				if b.tier < 3:
					var bcost: Dictionary = AgeProgression.building_cost(b.type, b.tier + 1)
					var bb: Button = _btn("Bâtiment niv.%d → %d\n%s" % [b.tier, b.tier + 1, Rules.cost_text(bcost)], _local_upgrade_building.bind(b.id), 184)
					bb.disabled = not bool(bstate["ok"])
					bb.tooltip_text = String(bstate["reason"])
					sel_actions.add_child(bb)
				for ut in def.get("trains", []):
					var current_level: int = int(b.unit_evolutions.get(ut, 1))
					if current_level >= 3:
						continue
					var ust: Dictionary = AgeProgression.upgrade_status(w, game.player, b, "troop", ut)
					var cost: Dictionary = AgeProgression.troop_cost(ut, current_level + 1)
					var ub: Button = _btn("Équiper %s niv.%d → %d\n%s" % [Rules.UNITS[ut]["label"], current_level, current_level + 1, Rules.cost_text(cost)], _local_upgrade_troop.bind(b.id, ut), 198)
					ub.disabled = not bool(ust["ok"])
					ub.tooltip_text = String(ust["reason"])
					sel_actions.add_child(ub)
			if not b.queue.is_empty():
				sel_actions.add_child(_btn("Annuler dernier", func(): w.issue({"t": "cancel_train", "team": game.player, "building": b.id})))
			for key in Rules.TECHNOLOGIES:
				var tech: Dictionary = Rules.TECHNOLOGIES[key]
				if tech["building"] == b.type:
					sel_actions.add_child(_btn(String(tech["label"]) + "\n" + Rules.cost_text(tech["cost"]), _research.bind(b.id, key), 220))
			if b.type == "silo":
				sel_actions.add_child(_btn("Missile : 250 minerai\nChoisir une cible visible", func(): game.mode = "missile"; set_hint("Touchez la cible visible — dégâts alliés possibles."), 230))
			if b.type == "centre":
				sel_actions.add_child(_btn("Passage d'âge…", _toggle_age_panel))
			if def.get("trade_hub", false) and b.complete:
				for r in Rules.RESOURCES:
					sel_actions.add_child(_btn("Caravanes → %s" % Rules.RES_LABEL[r].to_lower(), func(): w.issue({"t": "trade_res", "team": game.player, "res": r})))
				sel_actions.add_child(_btn("Échanger 100 bois → minerai", func(): w.issue({"t": "exchange", "team": game.player, "sell": "wood", "buy": "ore"})))
				sel_actions.add_child(_btn("Échanger 100 nourriture → bois", func(): w.issue({"t": "exchange", "team": game.player, "sell": "food", "buy": "wood"})))
			sel_actions.set_meta("for", b.id)
			sel_actions.set_meta("age", w.teams[game.player].age)
			sel_actions.set_meta("building_tier", b.tier)
			sel_actions.set_meta("troop_tiers", var_to_str(b.unit_evolutions))
			sel_actions.set_meta("upgrade_state", AgeProgression.job_signature(b))
		return
	if _info_entity != null:
		var e = _info_entity
		if e is SimWorld.Unit:
			sel_title.text = "%s ennemi" % Rules.UNITS[e.type]["label"] if e.team != SimWorld.TEAM_NEUTRAL else Rules.UNITS[e.type]["label"]
			sel_info.text = "Santé %d/%d" % [int(e.hp), int(e.max_hp)]
		else:
			sel_title.text = Rules.BUILDINGS[e.type]["label"] + ("" if e.team == SimWorld.TEAM_NEUTRAL else " ennemi")
			sel_info.text = "Comptoir neutre : bâtissez un relais marchand à côté (âge II) pour ouvrir une route commerciale." if e.type == "comptoir" else "Santé %d/%d" % [int(e.hp), int(e.max_hp)]
		if rebuild:
			_clear_actions()
		return
	sel_title.text = "Aucune sélection"
	sel_info.text = "Touchez une unité ou une escouade pour commander."
	if rebuild:
		_clear_actions()

func _train_buttons_stale(b) -> bool:
	return sel_actions.get_meta("for", -1) != b.id or sel_actions.get_meta("age", 0) != game.world.teams[game.player].age or sel_actions.get_meta("building_tier", 0) != b.tier or sel_actions.get_meta("troop_tiers", "") != var_to_str(b.unit_evolutions) or sel_actions.get_meta("upgrade_state", "") != AgeProgression.job_signature(b)

func _train(bid: int, ut: String) -> void:
	game.world.issue({"t": "train", "team": game.player, "building": bid, "unit": ut})
	_sel_dirty = true

func _local_upgrade_building(bid: int) -> void:
	var r: Dictionary = game.world.issue({"t": "upgrade_building", "team": game.player, "building": bid})
	set_hint("Évolution du bâtiment engagée" if bool(r.get("ok", false)) else String(r.get("reason", "Refus")))
	_sel_dirty = true

func _local_upgrade_troop(bid: int, unit_kind: String) -> void:
	var r: Dictionary = game.world.issue({"t": "upgrade_troop", "team": game.player, "building": bid, "unit": unit_kind})
	set_hint("Modernisation des troupes engagée" if bool(r.get("ok", false)) else String(r.get("reason", "Refus")))
	_sel_dirty = true

func _state_text(u) -> String:
	var tasks := {"food": "récolte nourriture", "wood": "coupe du bois", "ore": "extrait du minerai", "build": "construit", "repair": "répare", "": "inactif"}
	if u.garrison_id != -1:
		return "en garnison"
	if Rules.unit_has(u.type, "worker"):
		return tasks.get(u.task, u.task) + (" (transporte %d)" % int(u.carry_amt) if u.carry_amt > 0.5 else "")
	if Rules.unit_has(u.type, "caravan"):
		return "route commerciale" if u.blocked_reason == "" else "à l'arrêt"
	return {"idle": "en position", "move": "en mouvement", "attack": "au combat" if not Rules.unit_has(u.type, "siege") else "tir de siège",
		"batterie": "mise en batterie (%d %%)" % int(100.0 * u.deploy / maxf(0.1, float(Rules.UNITS[u.type].get("setup", 1.0)))),
		"trop_pres": "cible trop proche : recule"}.get(u.state, u.state)

func _update_minimap() -> void:
	var w: SimWorld = game.world
	var fog: PackedByteArray = w.teams[game.player].fog
	var data := PackedByteArray()
	data.resize(game.world.map_size * game.world.map_size * 3)
	for i in fog.size():
		var t := w.terrain[i]
		var c: Color = AgeTheme.MAP["grass"] if t == SimWorld.TERRAIN_GRASS else (AgeTheme.MAP["water"] if t == SimWorld.TERRAIN_WATER else AgeTheme.MAP["rock"])
		var k := 0.0 if fog[i] == 0 else (0.5 if fog[i] == 1 else 1.0)
		data[i * 3] = int(c.r * k * 255)
		data[i * 3 + 1] = int(c.g * k * 255)
		data[i * 3 + 2] = int(c.b * k * 255)
	mini_img.set_data(game.world.map_size, game.world.map_size, false, Image.FORMAT_RGB8, data)
	for b in w.buildings.values():
		var known: bool = b.team == game.player or w.teams[game.player].memory.has(b.id)
		if known:
			var col: Color = Assets.TEAM_COLORS[b.team].lightened(0.2)
			mini_img.fill_rect(Rect2i(b.cell, Vector2i(b.size, b.size)), col)
	for u in w.units.values():
		if u.team == game.player or w.is_visible_to(game.player, u.pos):
			var c := w.cell_of(u.pos)
			mini_img.set_pixelv(c, Assets.TEAM_COLORS[u.team].lightened(0.45))
	var ct := Vector2i(int(game.cam_target.x), int(game.cam_target.z))
	for d in range(-3, 4):
		for pp in [ct + Vector2i(d, -3), ct + Vector2i(d, 3), ct + Vector2i(-3, d), ct + Vector2i(3, d)]:
			if pp.x >= 0 and pp.y >= 0 and pp.x < game.world.map_size and pp.y < game.world.map_size:
				mini_img.set_pixelv(pp, AgeTheme.MAP["frame"])
	_minimap_overlays(w)
	mini_tex.update(mini_img)

class ResChip extends Button:
	## Chip compact : stock, ouvriers, priorité de travail et manque de gisement.
	var res := "food"
	var color := Color.WHITE
	var amount := 0
	var workers := 0
	var priority := 2
	var shortage := false
	var shown: float = -1.0           # 0.17 : compteur animé (le nombre défile vers la valeur réelle)
	var trend: int = 0                # +1 gain, -1 perte (flèche et couleur pendant 0,8 s)
	var trend_t: float = 0.0
	var per_minute: float = 0.0
	var city: bool = false            # 0.18 : la ville produit (plus de récolte par les ouvriers)
	func animate(delta: float) -> void:
		if shown < 0.0 or GameConfig.reduce_motion:
			if shown >= 0.0 and int(shown) != amount:
				trend = 1 if amount > int(shown) else -1
				trend_t = 0.8
			shown = float(amount)
		elif absf(shown - float(amount)) >= 0.5:
			var before: int = int(shown)
			shown = lerpf(shown, float(amount), 1.0 - exp(-10.0 * delta))
			if absf(shown - float(amount)) < 1.0:
				shown = float(amount)
			if int(shown) != before:
				trend = 1 if amount > before else -1
				trend_t = 0.8
		if trend_t > 0.0:
			trend_t -= delta
			queue_redraw()
		elif trend != 0:
			trend = 0
			queue_redraw()
	func _draw() -> void:
		var f := get_theme_default_font()
		draw_rect(Rect2(8, 10, 10, 10), color)
		var short_labels := {"food": "Vivres", "wood": "Bois", "ore": "Miner."}
		var value: int = int(shown) if shown >= 0.0 else amount
		var tint: Color = AgeTheme.c("text") if trend == 0 else (AgeTheme.c("success") if trend > 0 else AgeTheme.c("danger"))
		draw_string(f, Vector2(23, 21), "%s %d%s" % [short_labels[res], value, "" if trend == 0 else ("↑" if trend > 0 else "↓")], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
		if city:
			draw_string(f, Vector2(9, 42), "ville +%d/m" % int(per_minute), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AgeTheme.c("muted"))
		else:
			draw_string(f, Vector2(9, 42), "%d ouv." % workers if per_minute < 0.5 else "%d ouv. +%d/m" % [workers, int(per_minute)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AgeTheme.c("muted"))
		for i in 3:
			var r := Rect2(66 + i * 13, 34, 11, 7)
			if per_minute < 0.5 and not city:
				draw_rect(r, color if i < priority else AgeTheme.c("track"))
		if shortage:
			draw_rect(Rect2(9, 48, 96, 2), AgeTheme.c("danger"))

class SelectionOverlay extends Control:
	## Dessin uniquement : les événements restent adressés à Game.
	var begin := Vector2.ZERO
	var end := Vector2.ZERO
	func _draw() -> void:
		var r := Rect2(begin, end - begin).abs()
		if r.size.length_squared() < 12.0:
			return
		draw_rect(r, Color(AgeTheme.c("select"), 0.12), true)
		draw_rect(r, Color(AgeTheme.c("select"), 0.94), false, 2.0)

func _research(building: int, key: String) -> void:
	var result: Dictionary = game.world.issue({"t": "technology", "team": game.player, "building": building, "key": key})
	set_hint("Recherche lancée" if result["ok"] else String(result.get("reason", "Refus")))

func _focus_home() -> void:
	var centers: Array = game.world.team_buildings(game.player, "centre", true)
	if not centers.is_empty():
		game.focus((centers[0] as SimWorld.Building).center)
	elif game.has_command_selection():
		game.focus(game.selection_center())

func _apply_safe_layout() -> void:
	_safe = MobileUI.safe_insets(root.get_viewport())
	for control in _safe_controls:
		if control.has_meta("mirrored"):
			continue
		var base: Vector4 = control.get_meta("base_offsets", Vector4.ZERO) as Vector4
		control.offset_left = base.x + (_safe.x - 12.0 if control.anchor_left < 0.1 else 0.0)
		control.offset_right = base.z - (_safe.z - 12.0 if control.anchor_right > 0.9 else 0.0)
		control.offset_top = base.y + (_safe.y - 12.0 if control.anchor_top < 0.1 else 0.0)
		control.offset_bottom = base.w - (_safe.w - 12.0 if control.anchor_bottom > 0.9 else 0.0)

func _update_modal_scrim() -> void:
	var target: Control = null
	for panel_node in [age_panel, menu_panel, controls_panel, over_panel, tech_panel]:
		if panel_node != null and panel_node.visible:
			target = panel_node as Control
	_modal_scrim.visible = target != null
	if target != null and target != _modal_target:
		var index: int = target.get_index()
		if _modal_scrim.get_index() < index:
			index -= 1
		root.move_child(_modal_scrim, index)
	_modal_target = target

func _queue_advanced(kind: String) -> void:
	var ids: Array = game.world.squads[game.sel_squad].units.duplicate() if game.sel_squad != -1 and game.world.squads.has(game.sel_squad) else game.sel_units.duplicate()
	var start: Vector2 = game.selection_center()
	var order: Dictionary = {"type": kind, "pos": [radial_target.x, radial_target.y], "back": [start.x, start.y], "ticks": 100}
	if kind == "escort": order["target"] = radial_entity.id if radial_entity is SimWorld.Unit else -1
	var steps: Array = [{"type": "move", "pos": [radial_target.x, radial_target.y]}, order] if kind == "wait" else [order]
	var result: Dictionary = game.world.issue({"t": "queue_orders", "team": game.player, "units": ids, "orders": steps})
	toast("Ordres successifs enregistrés" if bool(result.get("ok", false)) else String(result.get("reason", "Refus")))
	close_radial()

# ------------------------------------------------------------------ 0.17 : interface « grand RTS » au pouce

func _build_left() -> void:
	# Groupes de contrôle au bord gauche (pouce gauche) et file d'alertes sous la barre du haut.
	groups_panel = ControlGroups.new()
	groups_panel.offset_left = 12
	groups_panel.offset_top = 96
	root.add_child(groups_panel)
	groups_panel.setup(game)
	control_groups = groups_panel as ControlGroups
	_ui_blockers.append(groups_panel)
	alerts = AlertFeed.new()
	alerts.offset_left = 92
	alerts.offset_top = 92
	alerts.offset_right = 410
	root.add_child(alerts)
	alerts.setup(game)

func _build_late() -> void:
	ceremony = AgeCeremony.new()
	root.add_child(ceremony)
	ceremony.setup(feedback)
	_ui_blockers.append(ceremony)
	production_panel = ProductionPanel.new()
	root.add_child(production_panel)
	production_panel.setup(game)
	_ui_blockers.append(production_panel)
	queue_bubble = _panel(root)
	queue_bubble.visible = false
	var bubble := HBoxContainer.new()
	queue_bubble.add_child(bubble)
	for entry in [["Déplacer", "move"], ["Supprimer", "remove"], ["Insérer avant", "insert"], ["×", "close"]]:
		bubble.add_child(_btn(String(entry[0]), _bubble_action.bind(String(entry[1])), 48 if entry[1] == "close" else 96))
	refusal_label = Label.new()
	refusal_label.visible = false
	refusal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refusal_label.add_theme_font_size_override("font_size", 16)
	refusal_label.add_theme_constant_override("outline_size", 7)
	root.add_child(refusal_label)
	zoning_panel = ZoningPanel.new()
	root.add_child(zoning_panel)
	zoning_panel.anchor_top = 1.0
	zoning_panel.anchor_bottom = 1.0
	zoning_panel.offset_left = 12
	zoning_panel.offset_right = 772
	zoning_panel.offset_top = -152
	zoning_panel.offset_bottom = -152
	zoning_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	zoning_panel.setup(game, self, game.zoning_tool)
	_ui_blockers.append(zoning_panel)
	feedback.setup(root)
	_layout_controls.assign([quick_panel, groups_panel, alerts, command_card, command_bars, building_drawer, production_panel, sel_panel, minimap_panel, zoning_panel])

func _build_interface_settings(mv: VBoxContainer) -> void:
	var theme_button := _btn("", _cycle_theme_mode)
	mv.add_child(theme_button)
	settings_buttons["theme"] = theme_button
	for entry in [["sounds", "Sons d'interface"], ["vibration", "Vibrations"], ["left", "Main gauche (miroir des barres)"], ["motion", "Réduire les animations"]]:
		var check := CheckButton.new()
		check.text = String(entry[1])
		check.custom_minimum_size.y = 48
		check.toggled.connect(_interface_toggle.bind(String(entry[0])))
		mv.add_child(check)
		settings_buttons[entry[0]] = check
	var scale_button := _btn("", _cycle_ui_scale)
	mv.add_child(scale_button)
	settings_buttons["scale"] = scale_button
	var ranges := CheckButton.new()
	ranges.text = "Afficher les portées de la sélection"
	ranges.custom_minimum_size.y = 48
	ranges.toggled.connect(func(enabled: bool): game.path_view.show_ranges = enabled)
	mv.add_child(ranges)
	_refresh_settings_captions()

func _refresh_settings_captions() -> void:
	if settings_buttons.is_empty():
		return
	(settings_buttons["theme"] as Button).text = "Thème : " + ("suit l'âge (%s)" % AgeTheme.age_name(AgeTheme.game_age(game)) if GameConfig.theme_mode == 0 else "âge %s fixe — %s" % [ROMAN[GameConfig.theme_mode], AgeTheme.age_name(GameConfig.theme_mode)])
	(settings_buttons["sounds"] as CheckButton).set_pressed_no_signal(GameConfig.ui_sounds)
	(settings_buttons["vibration"] as CheckButton).set_pressed_no_signal(GameConfig.ui_vibration)
	(settings_buttons["left"] as CheckButton).set_pressed_no_signal(GameConfig.left_handed)
	(settings_buttons["motion"] as CheckButton).set_pressed_no_signal(GameConfig.reduce_motion)
	(settings_buttons["scale"] as Button).text = "Échelle de l'interface : %d %%" % int(round(GameConfig.ui_scale * 100.0))

func _cycle_theme_mode() -> void:
	GameConfig.theme_mode = (GameConfig.theme_mode + 1) % 11
	GameConfig.save_preferences()
	AgeTheme.apply(AgeTheme.wanted_age(game))
	_refresh_settings_captions()

func _interface_toggle(enabled: bool, key: String) -> void:
	match key:
		"sounds": GameConfig.ui_sounds = enabled
		"vibration": GameConfig.ui_vibration = enabled
		"left":
			GameConfig.left_handed = enabled
			_apply_mirror()
		"motion": GameConfig.reduce_motion = enabled
	GameConfig.save_preferences()

func _cycle_ui_scale() -> void:
	var i: int = GameConfig.UI_SCALES.find(GameConfig.ui_scale)
	GameConfig.ui_scale = float(GameConfig.UI_SCALES[(i + 1) % GameConfig.UI_SCALES.size()])
	GameConfig.save_preferences()
	_apply_ui_preferences()
	_refresh_settings_captions()

func _apply_ui_preferences() -> void:
	if root == null or not root.is_inside_tree():
		return
	root.get_tree().root.content_scale_factor = GameConfig.ui_scale
	ResponsiveLayout.watch(root.get_tree().root)
	apply_orientation(true)

func _apply_mirror() -> void:
	## Mode gaucher : toutes les barres passent en miroir horizontal (gestes et ordre des boutons inchangés).
	for control in _layout_controls + _safe_controls:
		if control == null:
			continue
		if not control.has_meta("layout_base"):
			control.set_meta("layout_base", [control.anchor_left, control.anchor_right, control.offset_left, control.offset_right, control.grow_horizontal])
		var base: Array = control.get_meta("layout_base") as Array
		if not GameConfig.left_handed:
			control.remove_meta("mirrored")
			control.anchor_left = float(base[0])
			control.anchor_right = float(base[1])
			control.offset_left = float(base[2])
			control.offset_right = float(base[3])
			control.grow_horizontal = int(base[4])
			continue
		var width: float = maxf(control.size.x, control.get_combined_minimum_size().x)
		var left: float = float(base[2])
		var right: float = float(base[3])
		if is_equal_approx(float(base[0]), float(base[1])) and right <= left + 1.0:
			right = left + width
		control.set_meta("mirrored", true)
		control.anchor_left = 1.0 - float(base[1])
		control.anchor_right = 1.0 - float(base[0])
		control.offset_left = -right
		control.offset_right = -left
		control.grow_horizontal = Control.GROW_DIRECTION_BEGIN if int(base[4]) == Control.GROW_DIRECTION_END else Control.GROW_DIRECTION_END
	_apply_safe_layout()

func _on_theme_changed(_age: int) -> void:
	_modal_scrim.color = AgeTheme.c("scrim")
	for chip in res_chips.values():
		(chip as Control).queue_redraw()
	if alerts != null:
		alerts.retheme(_age)
	if command_card != null:
		command_card._signature = ""
	_refresh_settings_captions()
	_sel_dirty = true

func check_theme_age() -> void:
	## Le thème change au moment exact où l'âge de référence change (monument achevé ou passage classique).
	var wanted: int = AgeTheme.wanted_age(game)
	if wanted == AgeTheme.current_age or (ceremony != null and ceremony.active and ceremony.target_age == wanted):
		return
	if GameConfig.theme_mode > 0 or wanted < AgeTheme.current_age or ceremony == null:
		AgeTheme.apply(wanted)
		return
	ceremony.play(wanted, _last_age_text)
	_last_age_text = ""

func ready_monument() -> String:
	## Monument du prochain âge constructible tout de suite (bouton direct depuis la barre d'âge).
	var w: SimWorld = game.world
	if not CivEvolution.enabled(w):
		return ""
	var age: int = w.teams[game.player].age
	for kind in CivRules.MONUMENTS.keys():
		var definition: Dictionary = Rules.BUILDINGS[kind]
		if int(definition.get("monument", 0)) != age + 1:
			continue
		if not CivEvolution.visible_building(w, game.player, String(kind)) or CivEvolution.build_lack(w, game.player, String(kind)) != "":
			continue
		if w._can_pay(game.player, w.scaled_cost(definition["cost"])):
			return String(kind)
	return ""

func _age_pressed() -> void:
	var monument: String = ready_monument()
	if monument != "":
		game.start_placement(monument)
		toast("Choisissez l'emplacement du monument : %s" % String(Rules.BUILDINGS[monument]["label"]).get_slice(" (", 0), AgeTheme.c("info"))
		return
	_toggle_age_panel()

func _pop_pressed() -> void:
	var t: SimWorld.Team = game.world.teams[game.player]
	if t.pop >= t.pop_cap:
		var housing: String = "zone_r" if UrbanCity.active(game.world, game.player) else "maison"
		game.start_placement(housing)
		toast("Population pleine : placez une %s" % ("zone d'habitation" if housing == "zone_r" else "maison"), AgeTheme.c("warning"))
	else:
		_select_idle()

func _select_idle() -> void:
	var idle: Array = game.idle_workers()
	if idle.is_empty():
		toast("Aucun ouvrier inactif")
		return
	var ids: Array = []
	for u in idle:
		ids.append(u.id)
	game.select_many(ids)
	_idle_cycle = (_idle_cycle + 1) % idle.size()
	game.focus((idle[_idle_cycle] as SimWorld.Unit).pos)

func _toggle_production() -> void:
	if UIMotion.is_open(production_panel):
		UIMotion.conceal(production_panel)
	else:
		build_panel.visible = false
		production_panel.open()

func _toggle_additive() -> void:
	game.add_mode = not game.add_mode
	add_btn.theme_type_variation = "ToggleOnButton" if game.add_mode else ""
	set_hint("Sélection additive : touchez des unités pour les ajouter ou les retirer" if game.add_mode else "")

func _toggle_active_pause() -> void:
	game.paused = not game.paused
	active_pause_btn.text = "" if game.paused else "‖"
	active_pause_btn.icon = ICON_PLAY if game.paused else null
	active_pause_btn.theme_type_variation = "ToggleOnButton" if game.paused else ""
	set_hint("Pause active : donnez vos ordres, touchez le bouton lecture pour reprendre" if game.paused else "")

func _toggle_line() -> void:
	game.placement_tool.line_mode = not game.placement_tool.line_mode
	game.placement_tool.cells.clear()
	set_hint("Glissez le doigt pour tracer la ligne, puis Valider" if game.placement_tool.line_mode else "")
	placement_changed()

func _toggle_multi() -> void:
	game.placement_tool.multi_mode = not game.placement_tool.multi_mode
	placement_changed()

func _radial_garrison() -> void:
	var e = radial_entity
	close_radial()
	if e is SimWorld.Building and e.team == game.player:
		command_card.on_target("garrison", Vector2(-1, -1), radial_target, e, null)
	else:
		command_card.run("garrison")

func refusal(text: String, sp: Vector2) -> void:
	## Ordre refusé : raison lisible près du doigt (ou au centre si aucun point).
	var at: Vector2 = sp if sp.x >= 0.0 else root.size * Vector2(0.5, 0.42)
	refusal_label.text = text
	refusal_label.add_theme_color_override("font_color", AgeTheme.c("danger"))
	refusal_label.add_theme_color_override("font_outline_color", AgeTheme.c("bg"))
	refusal_label.reset_size()
	refusal_label.position = Vector2(clampf(at.x - refusal_label.size.x * 0.5, 8.0, maxf(8.0, root.size.x - refusal_label.size.x - 8.0)), clampf(at.y - 64.0, 90.0, maxf(90.0, root.size.y - 60.0)))
	refusal_label.visible = true
	refusal_label.modulate.a = 1.0
	_refusal_t = 1.8
	AgeTheme.haptic(25)

func _command_status() -> String:
	## État de commandement lisible : contrôle direct, file d'ordres, posture, garnison.
	var units: Array = game.selected_units()
	if units.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var steps: int = 0
	var current: int = 0
	var looped: bool = false
	var direct: int = 0
	var garrisoned: int = 0
	for u in units:
		if u.order_steps.size() > steps:
			steps = u.order_steps.size()
			current = u.order_step
		looped = looped or u.order_loop
		if u.direct: direct += 1
		if u.garrison_id != -1: garrisoned += 1
	if steps > 0:
		parts.append("file %d/%d%s" % [current + 1, steps, " ∞" if looped else ""])
	if direct > 0 and game.sel_squad != -1:
		parts.append("contrôle direct")
	var first: SimWorld.Unit = units[0]
	if first.stance != "":
		parts.append("posture " + String(UnitCommands.STANCE_LABELS[first.stance]).to_lower())
	if garrisoned > 0:
		parts.append("%d en garnison" % garrisoned)
	return (" · " + " · ".join(parts)) if not parts.is_empty() else ""

func open_queue_bubble(point: Dictionary, sp: Vector2) -> void:
	queue_bubble_point = point
	queue_bubble.visible = true
	queue_bubble.reset_size()
	queue_bubble.position = Vector2(clampf(sp.x - 180.0, 8.0, maxf(8.0, root.size.x - 400.0)), clampf(sp.y - 90.0, 90.0, maxf(90.0, root.size.y - 80.0)))

func _bubble_action(kind: String) -> void:
	var point: Dictionary = queue_bubble_point
	queue_bubble.visible = false
	if point.is_empty():
		return
	match kind:
		"remove":
			var r: Dictionary = game.world.issue({"t": "queue_edit", "team": game.player, "units": point["units"], "op": "remove", "index": int(point["index"])})
			if not bool(r.get("ok", false)): refusal(String(r.get("reason", "refus")), Vector2(-1, -1))
		"move":
			game.mode = "queue_move"
			game.queue_edit_point = point
			set_hint("Touchez la nouvelle position de l'étape %d" % (int(point["index"]) + 1))
		"insert":
			game.mode = "queue_insert"
			game.queue_edit_point = point
			set_hint("Touchez le point à insérer avant l'étape %d" % (int(point["index"]) + 1))
	command_card._signature = ""

func _layout_selection(units_selected: bool) -> void:
	var scroller: Control = sel_panel.find_child("ActionsScroller", true, false) as Control
	if scroller != null:
		scroller.visible = not units_selected
	selection_bar.visible = units_selected
	if units_selected:
		selection_bar.refresh()
	var base: float = -380.0 if command_card.visible else -12.0
	if portrait_mode == 1:
		return # 0.18 : en portrait, la carte de commandes est sous la sélection (pleine largeur).
	if not GameConfig.left_handed and not is_equal_approx(sel_panel.offset_right, base):
		sel_panel.offset_right = base
		sel_panel.set_meta("base_offsets", Vector4(sel_panel.offset_left, sel_panel.offset_top, base, sel_panel.offset_bottom))

func _minimap_overlays(w: SimWorld) -> void:
	# Signaux d'attaque (carrés pulsés) et étapes de la file de la sélection (points simplifiés).
	if alerts != null:
		var pulse: int = 2 + int(Time.get_ticks_msec() / 500) % 2
		for p in alerts.pings:
			var c: Vector2i = w.cell_of(p["pos"])
			mini_img.fill_rect(Rect2i(c - Vector2i(pulse, pulse), Vector2i(pulse * 2 + 1, pulse * 2 + 1)), AgeTheme.c("danger"))
	if game.path_view != null:
		for p in game.path_view.points:
			var cell: Vector2i = w.cell_of(p["pos"])
			if cell.x >= 1 and cell.y >= 1 and cell.x < w.map_size - 1 and cell.y < w.map_size - 1:
				mini_img.fill_rect(Rect2i(cell - Vector2i(1, 1), Vector2i(3, 3)), AgeTheme.STEP_COLORS["move"])

func _refresh_017(delta: float) -> void:
	if feedback == null:
		return
	if alerts != null:
		alerts.tick(delta)
	if game.path_view != null:
		game.path_view.tick(delta)
	if game.placement_tool != null:
		game.placement_tool.refresh()
	for chip in res_chips.values():
		(chip as ResChip).animate(delta)
	if _refusal_t > 0.0:
		_refusal_t -= delta
		refusal_label.modulate.a = clampf(_refusal_t / 0.5, 0.0, 1.0)
		if _refusal_t <= 0.0:
			refusal_label.visible = false
	_bars_t += delta
	if _bars_t < 0.2:
		return
	_bars_t = 0.0
	check_theme_age()
	if portrait_mode == 1 and absf(top_panel.size.y - _portrait_top_h) > 2.0:
		apply_orientation(true) # 0.18 : la barre du haut a changé de nombre de rangées
	if zoning_panel != null and zoning_panel.visible:
		zoning_panel.refresh()
	command_card.refresh()
	control_groups.refresh()
	command_bars.refresh()
	if squad_panel.visible:
		command_bars.visible = false
	production_panel.refresh()
	var units_selected: bool = game.sel_building == -1 and game.has_command_selection()
	_layout_selection(units_selected)
	hero_btn.visible = CivEvolution.enabled(game.world)
	quick_panel.visible = not build_panel.visible
	var per_minute: Dictionary = game.income_per_minute()
	for r in res_chips.keys():
		(res_chips[r] as ResChip).per_minute = float(per_minute.get(r, 0.0))


# ---------------------------------------------------------------- 0.18 : paysage et portrait


func _on_root_resized() -> void:
	# En portrait, la largeur change encore après la bascule (base d'échelle mise à jour) : on recalcule à chaque fois.
	apply_orientation(portrait_mode == 1)
	_apply_safe_layout()

func _root_child(node: Node) -> Control:
	var n: Node = node
	while n != null and n.get_parent() != root:
		n = n.get_parent()
	return n as Control

func _top_width() -> float:
	var width: float = 0.0
	var count: int = 0
	for child in top_flow.get_children():
		var c: Control = child as Control
		if c != null and c.visible:
			width += c.get_combined_minimum_size().x
			count += 1
	width += 5.0 * float(maxi(0, count - 1))
	var box: StyleBox = top_panel.get_theme_stylebox("panel")
	return width + (box.get_minimum_size().x if box != null else 24.0)

func _flow_height(width: float) -> float:
	## Hauteur de la barre du haut repliée sur `width` points (calcul direct, sans attendre le tri du conteneur).
	var x: float = 0.0
	var row_h: float = 0.0
	var total: float = 0.0
	var rows: int = 0
	for child in top_flow.get_children():
		var c: Control = child as Control
		if c == null or not c.visible:
			continue
		var s: Vector2 = c.get_combined_minimum_size()
		if x > 0.0 and x + s.x > width:
			total += row_h
			rows += 1
			x = 0.0
			row_h = 0.0
		x += s.x + 5.0
		row_h = maxf(row_h, s.y)
	total += row_h
	rows += 1
	return total + 5.0 * float(rows - 1)

func _portrait_top() -> float:
	## Haut de la zone sous la barre du haut, en portrait (barre sur deux ou trois rangées selon la largeur).
	var box: StyleBox = top_panel.get_theme_stylebox("panel")
	var pad: Vector2 = box.get_minimum_size() if box != null else Vector2(24, 24)
	var width: float = root.size.x - 16.0 - pad.x
	_portrait_top_h = _flow_height(width) + pad.y
	return 8.0 + _portrait_top_h + 12.0

func _portrait_specs() -> Array:
	var top: float = _portrait_top()
	var down := Vector2i(Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	var up := Vector2i(Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	var left := Vector2i(Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	return [
		[top_panel, ResponsiveLayout.spec(Vector4(0, 0, 1, 0), Vector4(8, 8, -8, 8))],
		[minimap_panel, ResponsiveLayout.spec(Vector4(1, 0, 1, 0), Vector4(-302, top, -12, 0), down)],
		[_root_child(squad_toggle), ResponsiveLayout.spec(Vector4(1, 0, 1, 0), Vector4(-154, top + 250.0, -12, 0), down)],
		[command_bars, ResponsiveLayout.spec(Vector4(1, 0, 1, 0), Vector4(-248, top + 332.0, -12, 0), left)],
		[squad_panel, ResponsiveLayout.spec(Vector4(1, 0, 1, 0), Vector4(-252, top + 332.0, -12, 0), down)],
		[groups_panel, ResponsiveLayout.spec(Vector4(0, 0, 0, 0), Vector4(8, top, 0, 0), down)],
		[alerts, ResponsiveLayout.spec(Vector4(0, 0, 1, 0), Vector4(92, top, -232, 0), down)],
		[command_card, ResponsiveLayout.spec(Vector4(0, 1, 1, 1), Vector4(8, -204, -8, -8), up)],
		[sel_panel, ResponsiveLayout.spec(Vector4(0, 1, 1, 1), Vector4(8, -362, -8, -212), up)],
		[quick_panel, ResponsiveLayout.spec(Vector4(0, 1, 0, 1), Vector4(8, -446, 0, -378), up)],
		[_root_child(build_btn), ResponsiveLayout.spec(Vector4(0, 1, 0, 1), Vector4(8, -522, 0, -454), up)],
		[build_panel, ResponsiveLayout.spec(Vector4(0, 1, 1, 1), Vector4(8, -924, -8, -530), up)],
		[_root_child(place_bar), ResponsiveLayout.spec(Vector4(0, 1, 1, 1), Vector4(8, -644, -8, -530), up)],
		[production_panel, ResponsiveLayout.spec(Vector4(0, 1, 1, 1), Vector4(8, -924, -8, -530), up)],
		[zoning_panel, ResponsiveLayout.spec(Vector4(0, 1, 1, 1), Vector4(8, -530, -8, -530), up)],
		[hint_label, ResponsiveLayout.spec(Vector4(0, 1, 1, 1), Vector4(10, -688, -10, -654), up)],
		[toast_box, ResponsiveLayout.spec(Vector4(0, 1, 1, 1), Vector4(10, -696, -10, -696), up)],
		[age_panel, ResponsiveLayout.spec(Vector4(0, 0, 1, 0), Vector4(8, top, -8, 0), down)],
		[controls_panel, ResponsiveLayout.spec(Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-292, -420, 292, 420))],
		[tech_panel, ResponsiveLayout.spec(Vector4(0, 0, 1, 1), Vector4(8, 8, -8, -8))],
	]

func apply_orientation(force: bool) -> void:
	## Bascule paysage / portrait : mêmes boutons, mêmes gestes ; seules les positions changent.
	if root == null or top_panel == null:
		return
	var portrait: bool = ResponsiveLayout.is_portrait(root)
	if not force and int(portrait) == portrait_mode:
		return
	portrait_mode = int(portrait)
	ResponsiveLayout.remember(top_panel)
	var landscape_top: Dictionary = top_panel.get_meta("landscape_layout") as Dictionary
	var offsets: Vector4 = landscape_top["offsets"] as Vector4
	landscape_top["offsets"] = Vector4(offsets.x, offsets.y, offsets.x + _top_width(), offsets.y + 1.0)
	for entry in _portrait_specs():
		var control: Control = entry[0] as Control
		if control != null:
			ResponsiveLayout.apply(control, entry[1] as Dictionary if portrait else {})
	place_label.custom_minimum_size.x = 540.0 if portrait else 300.0
	var side: float = MINIMAP_SIDE_PORTRAIT if portrait else MINIMAP_SIDE
	minimap.custom_minimum_size = Vector2(side, side)
	if building_drawer != null:
		building_drawer.portrait = portrait
		building_drawer.apply_layout()
	for panel in [game.civ_panel, game.city_panel, game.evolution_panel]:
		if panel != null:
			ResponsiveLayout.fit_full_panel(panel as Control, portrait)
	if game.has_method("apply_orientation"):
		game.apply_orientation(portrait)
	if GameConfig.left_handed:
		_apply_mirror()
	else:
		_apply_safe_layout()
	_sel_dirty = true
