extends Control
## Accueil 3D, campagne, reprise et ateliers de jeu.

var lab_list: ItemList
var seed_edit: LineEdit
var speed_menu_btn: Button

var _quality_menu: Button
var _lab_drawer: PanelContainer

var backdrop: MenuBackdrop
var settings_drawer: PanelContainer
var settings_scrim:ColorRect
var _middle: BoxContainer          # 0.18 : colonnes côte à côte en paysage, empilées en portrait
var _hero: VBoxContainer
var _era_row: HBoxContainer
var _lab_columns: BoxContainer
var _tools_scroll: ScrollContainer
var _frame: MarginContainer
func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--perf-auto="):
			get_tree().change_scene_to_file.call_deferred("res://game/performance_screen.tscn")
			return
	if "--fronts-auto" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://game/fronts.tscn")
		return
	GameConfig.load_preferences()
	# 0.21 : les réglages de « Nouvelle partie » ne débordent pas sur les autres façons de lancer une partie.
	GameConfig.custom_rules = {}
	GameConfig.map_dimension = 256
	GameConfig.civ_evolution = true
	GameConfig.supply_chain = true
	Engine.max_fps = 60
	AgeTheme.apply(0)
	get_tree().root.content_scale_factor = GameConfig.ui_scale
	ResponsiveLayout.watch(get_tree().root)
	theme = MobileUI.theme()
	backdrop=MenuBackdrop.new(); add_child(backdrop)
	var veil:=ColorRect.new(); veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
void fragment(){
 float left=1.0-smoothstep(0.18,0.76,UV.x);
 float edge=pow(abs(UV.y-0.5)*2.0,3.0);
 COLOR=vec4(vec3(0.015,0.039,0.055),clamp(left*0.88+edge*0.32+0.08,0.0,0.96));
}"""
	var material:=ShaderMaterial.new(); material.shader=shader; veil.material=material; add_child(veil)
	var frame:=MarginContainer.new(); frame.set_anchors_preset(Control.PRESET_FULL_RECT); _frame=frame
	for edge in ["left","right"]:frame.add_theme_constant_override("margin_"+edge,36)
	for edge in ["top","bottom"]:frame.add_theme_constant_override("margin_"+edge,24)
	add_child(frame)
	var layout:=VBoxContainer.new(); layout.add_theme_constant_override("separation",12); frame.add_child(layout)
	var top:=HBoxContainer.new();layout.add_child(top)
	var label:=Label.new();label.text="S / E     •     STRATÉGIE SANS FRONTIÈRES";label.add_theme_font_size_override("font_size",13)
	label.theme_type_variation="HeaderLabel";label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(label)
	top.add_child(_btn("Paramètres",_toggle_settings))
	var middle:=BoxContainer.new();middle.size_flags_vertical=Control.SIZE_EXPAND_FILL;layout.add_child(middle);_middle=middle
	var menu:=VBoxContainer.new();menu.custom_minimum_size.x=408;menu.add_theme_constant_override("separation",9);middle.add_child(menu)
	var space:=Control.new();space.custom_minimum_size.y=12;menu.add_child(space)
	var title:=Label.new();title.text="SILLONS\nD'EMPIRE";title.add_theme_font_size_override("font_size",46);menu.add_child(title)
	var description:=Label.new();description.text="De la première cité aux confins des étoiles.";description.theme_type_variation="MutedLabel";description.add_theme_font_size_override("font_size",14);menu.add_child(description)
	var play:Button=_btn("NOUVELLE PARTIE   →",_new_game,58);MobileUI.primary(play);menu.add_child(play)
	menu.add_child(_btn("Partie rapide · campagne par défaut",_empire))
	var resume:Button=_btn("Continuer mon empire",_resume_save)
	resume.disabled=not FileAccess.file_exists(CampaignSave.PATH) and not FileAccess.file_exists(CampaignSave.PATH+".bak") and not FileAccess.file_exists(SaveGame.PATH);menu.add_child(resume)
	menu.add_child(_btn("Choisir une planète",_planet_skirmish))
	menu.add_child(_btn("Laboratoire et scénarios",_toggle_laboratory))
	var hero:=VBoxContainer.new();hero.size_flags_horizontal=Control.SIZE_EXPAND_FILL;hero.size_flags_vertical=Control.SIZE_EXPAND_FILL;middle.add_child(hero);_hero=hero
	var flexible:=Control.new();flexible.size_flags_vertical=Control.SIZE_EXPAND_FILL;hero.add_child(flexible)
	var story:=Label.new();story.text="BÂTIR. EXPLORER. CONQUÉRIR.";story.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;story.add_theme_font_size_override("font_size",20);hero.add_child(story)
	var era_row:=HBoxContainer.new();era_row.alignment=BoxContainer.ALIGNMENT_END;hero.add_child(era_row);_era_row=era_row
	for age in [1,3,6,10]:
		var age_button:Button=_btn("Âge "+J13Rules.roman(age),func():backdrop.show_age(age),44)
		age_button.tooltip_text="Aperçu de l'architecture ; la campagne débute à l'âge I.";era_row.add_child(age_button)
	var bottom:=HBoxContainer.new();layout.add_child(bottom)
	var note:=Label.new();note.text="10 ÂGES   /   PLANÈTES VIVANTES   /   COMBAT ORBITAL";note.add_theme_font_size_override("font_size",12);note.theme_type_variation="MutedLabel";note.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bottom.add_child(note)
	bottom.add_child(_btn("Quitter",func():get_tree().quit(),40))
	_build_laboratory()
	_build_settings()
	resized.connect(_apply_orientation)
	_apply_orientation()

func _build_settings()->void:
	settings_scrim=ColorRect.new();settings_scrim.set_anchors_preset(Control.PRESET_FULL_RECT);settings_scrim.color=Color(AgeTheme.c("scrim"),0.70);settings_scrim.mouse_filter=Control.MOUSE_FILTER_STOP;settings_scrim.hide();add_child(settings_scrim)
	settings_drawer=PanelContainer.new();settings_drawer.set_anchors_preset(Control.PRESET_CENTER)
	settings_drawer.offset_left=-240;settings_drawer.offset_right=240;settings_drawer.offset_top=-180;settings_drawer.offset_bottom=180
	add_child(settings_drawer)
	var v:=VBoxContainer.new();settings_drawer.add_child(v)
	var title:=Label.new();title.text="PARAMÈTRES";title.add_theme_font_size_override("font_size",24);v.add_child(title)
	_quality_menu=_btn("",_menu_quality);v.add_child(_quality_menu);_quality_caption()
	var motion:=CheckButton.new();motion.text="Réduire les animations";motion.custom_minimum_size.y=52;motion.button_pressed=GameConfig.reduce_motion
	motion.toggled.connect(func(enabled:bool):GameConfig.reduce_motion=enabled;GameConfig.save_preferences());v.add_child(motion)
	var help := Label.new(); help.text="Touchez une unité ou un bâtiment pour le sélectionner.\nTouchez le terrain pour déplacer la sélection.\nGlissez pour explorer la carte, pincez pour zoomer."
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; help.add_theme_font_size_override("font_size",14); v.add_child(help)
	v.add_child(_btn("Fermer",_toggle_settings))
	settings_drawer.hide()

func _toggle_settings()->void:
	if UIMotion.is_open(settings_drawer):UIMotion.conceal(settings_drawer);settings_scrim.hide()
	else:settings_scrim.show();UIMotion.reveal(settings_drawer)

func _quality_caption() -> void:
	_quality_menu.text = "Graphismes : " + ["Économie", "Équilibrés", "Détaillés"][GameConfig.visual_quality]

func _menu_quality() -> void:
	GameConfig.visual_quality = (GameConfig.visual_quality + 1) % 3
	GameConfig.save_preferences()
	backdrop.apply_quality()
	_quality_caption()

func _toggle_laboratory() -> void:
	UIMotion.toggle(_lab_drawer)

func _build_laboratory() -> void:
	_lab_drawer = PanelContainer.new()
	_lab_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lab_drawer.offset_left = 30
	_lab_drawer.offset_top = 20
	_lab_drawer.offset_right = -30
	_lab_drawer.offset_bottom = -20
	_lab_drawer.visible = false
	add_child(_lab_drawer)
	var columns := BoxContainer.new()
	_lab_drawer.add_child(columns)
	_lab_columns = columns
	var tools_scroll := ScrollContainer.new()
	_tools_scroll = tools_scroll
	tools_scroll.custom_minimum_size.x = 500
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(tools_scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_scroll.add_child(v)
	v.add_child(_btn("Retour", _toggle_laboratory))
	v.add_child(_btn("Performances Android · grande carte / fronts / orbite", func(): get_tree().change_scene_to_file("res://game/performance_screen.tscn")))
	seed_edit = LineEdit.new()
	seed_edit.text = "0"
	seed_edit.placeholder_text = "Graine : 0 = aléatoire"
	seed_edit.custom_minimum_size.y = 48
	seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	v.add_child(seed_edit)
	speed_menu_btn = _btn("", _menu_speed)
	v.add_child(speed_menu_btn)
	_menu_speed_caption()
	for entry in [["Reprendre la planète sauvegardée", _resume_planet], ["Atelier industrie · âge VIII", _modern_sandbox],
		["Atelier empire · âge X", _strategic_sandbox], ["Observer IA contre IA", _demo],
		["Vérifications intégrales", _recipe], ["Escarmouche avec débogage IA", _skirmish_debug]]:
		v.add_child(_btn(String(entry[0]), entry[1] as Callable))
	v.add_child(_btn("Banc d'essai · deux fronts", func(): get_tree().change_scene_to_file("res://game/fronts.tscn")))
	v.add_child(_btn("Zone témoin · rendu 3D", func(): get_tree().change_scene_to_file("res://game/witness.tscn")))
	var scenario_column := VBoxContainer.new()
	scenario_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(scenario_column)
	var heading := Label.new()
	heading.text = "SCÉNARIOS REPRODUCTIBLES"
	scenario_column.add_child(heading)
	lab_list = ItemList.new()
	lab_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for path in LabScenario.list_scenarios():
		var sc: LabScenario = LabScenario.load_file(path)
		lab_list.add_item(String(sc.data.get("name", path.get_file())) if sc != null else path.get_file())
		lab_list.set_item_metadata(lab_list.item_count - 1, path)
	scenario_column.add_child(lab_list)
	scenario_column.add_child(_btn("Lancer le scénario sélectionné", _lab))

func _btn(t: String, cb: Callable, height: int = 48) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, height)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _recipe() -> void:
	get_tree().change_scene_to_file("res://game/recette_screen.tscn")

func _menu_speed_caption() -> void:
	if speed_menu_btn != null:
		speed_menu_btn.text = "Vitesse simulation : ×%s (toucher pour modifier)" % str(GameConfig.sim_speed).replace(".0", "")

func _menu_speed() -> void:
	GameConfig.sim_speed = GameConfig.next_speed(GameConfig.sim_speed)
	_menu_speed_caption()

func _seed() -> int:
	return int(seed_edit.text) if seed_edit.text.is_valid_int() else 0

func _skirmish() -> void:
	GameConfig.mode = "skirmish"
	GameConfig.seed_value = _seed()
	GameConfig.show_ai_debug = false
	GameConfig.player_ai = false
	get_tree().change_scene_to_file("res://game/game.tscn")

func _planet_skirmish() -> void:
	GameConfig.mode = "planet_j9"
	GameConfig.seed_value = _seed()
	GameConfig.show_ai_debug = false
	GameConfig.player_ai = false
	GameConfig.loaded_world = null
	GameConfig.loaded_campaign = null
	get_tree().change_scene_to_file("res://game/planet_start.tscn")

func _resume_planet() -> void:
	var restored: StarCampaign = CampaignSave.load_campaign("user://sillons-j9-planet.save")
	if restored == null or not bool((restored.worlds["val"] as SimWorld).rules.get("planet_j9", false)):
		var dialog := AcceptDialog.new()
		add_child(dialog)
		dialog.dialog_text = "Aucune sauvegarde J9 valide."
		dialog.popup_centered()
		return
	GameConfig.loaded_campaign = restored
	GameConfig.loaded_world = null
	GameConfig.mode = "planet_j9"
	get_tree().change_scene_to_file("res://game/game.tscn")

func _skirmish_debug() -> void:
	GameConfig.mode = "skirmish"
	GameConfig.seed_value = _seed()
	GameConfig.show_ai_debug = true
	GameConfig.player_ai = false
	get_tree().change_scene_to_file("res://game/game.tscn")

func _demo() -> void:
	GameConfig.mode = "skirmish"
	GameConfig.seed_value = _seed()
	GameConfig.show_ai_debug = true
	GameConfig.player_ai = true
	get_tree().change_scene_to_file("res://game/game.tscn")

func _lab() -> void:
	var sel := lab_list.get_selected_items()
	if sel.is_empty():
		return
	GameConfig.mode = "lab"
	GameConfig.lab_path = lab_list.get_item_metadata(sel[0])
	get_tree().change_scene_to_file("res://game/game.tscn")

func _resume_save() -> void:
	var restored_campaign: StarCampaign = CampaignSave.load_campaign()
	if restored_campaign != null:
		if CampaignSave.last_load_source == "backup":
			GameConfig.recovery_notice = "Reprise du backup .bak vérifié (dernière modification UTC : %s)." % CampaignSave.last_load_timestamp
		GameConfig.loaded_campaign = restored_campaign
		GameConfig.loaded_world = null
	else:
		var restored: SimWorld = SaveGame.load_world()
		if restored == null:
			var dialog := AcceptDialog.new()
			add_child(dialog)
			dialog.dialog_text = "Aucune sauvegarde compatible et intacte."
			dialog.popup_centered()
			return
		GameConfig.loaded_world = restored
		GameConfig.loaded_campaign = null
	GameConfig.mode = "skirmish"
	get_tree().change_scene_to_file("res://game/game.tscn")

func _modern_sandbox() -> void:
	var world := SimWorld.new()
	world.setup(345)
	world.start_standard()
	for team in 2:
		world.teams[team].age = 8
		world.teams[team].pop_cap = 250
		world.teams[team].res = {"food": 12000.0, "wood": 12000.0, "ore": 12000.0}
	var home: Vector2 = world.team_buildings(0, "centre", true)[0].center
	for kind in ["usine", "academie", "gare", "gare", "depot", "aerodrome", "radar", "silo", "intercepteur"]:
		var placed: bool = false
		var size: int = int(Rules.BUILDINGS[kind]["size"])
		for y in range(65, 91):
			if placed:
				break
			for x in range(4, 36):
				var cell := Vector2i(x, y)
				if Vector2(cell).distance_to(home) < 23.0 and world.footprint_free(cell, size) and world.has_margin(cell, size):
					world.spawn_building(0, kind, cell, true)
					placed = true
					break
	for kind in ["fusilier", "grenadier", "obusier", "char", "antiaerien", "avion", "drone", "brouilleur", "lance_missiles"]:
		var unit := world.spawn_unit(0, kind, home + Vector2(4, -5))
		world._join_squad(unit, null, true)
	var stations: Array = world.team_buildings(0, "gare", true)
	if not stations.is_empty():
		world.spawn_unit(0, "train", stations[0].rally)
	world.update_fog(true)
	ModernSystems._network(world)
	# Pas d'IA automatique dans cet atelier : essai libre des commandes et sauvegardes.
	GameConfig.loaded_world = world
	GameConfig.mode = "skirmish"
	get_tree().change_scene_to_file("res://game/game.tscn")

func _strategic_sandbox() -> void:
	## Laboratoire de gameplay manuel : aucun effet sur une sauvegarde existante.
	var c := StarCampaign.new()
	c.create(678)
	c.ages[0] = 10
	for key in ViewTechnology.RESEARCH_ORDER:
		c.technologies[0][key] = true # Laboratoire J12 : simuler un arbre de technologies complet.
	c.resources[0] = {"food": 60000.0, "wood": 60000.0, "ore": 60000.0}
	c.satellites[0] = 1
	var w: SimWorld = c.current()
	w.teams[0].pop_cap = 250
	c._sync_all()
	var center: Vector2 = (w.team_buildings(0, "centre", true)[0] as SimWorld.Building).center
	var ports: Array = []
	for kind in ["spatioport", "chantier_orbital"]:
		var found: bool = false
		for y in range(63, 90):
			if found:
				break
			for x in range(5, 37):
				var cell := Vector2i(x, y)
				if w.footprint_free(cell, 4) and w.has_margin(cell, 4) and Vector2(cell).distance_to(center) < 25.0:
					ports.append(w.spawn_building(0, kind, cell, true))
					found = true
					break
	if not ports.is_empty():
		var source: SimWorld.Building = ports[0]
		for kind in ["navette", "fregate", "ouvrier", "ouvrier", "fusilier", "char"]:
			w.spawn_unit(0, kind, source.center + Vector2(5.0 + float(w.units.size() % 3), 4.0))
	w.update_fog(true)
	GameConfig.loaded_campaign = c
	GameConfig.loaded_world = null
	GameConfig.mode = "skirmish"
	get_tree().change_scene_to_file("res://game/game.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if settings_drawer != null and UIMotion.is_open(settings_drawer):
			_toggle_settings()
		elif _lab_drawer != null and UIMotion.is_open(_lab_drawer):
			UIMotion.conceal(_lab_drawer)
		else:
			get_tree().quit()

func _new_game() -> void:
	get_tree().change_scene_to_file("res://game/new_game_screen.tscn")

func _empire() -> void:
	GameConfig.mode = "empire"
	GameConfig.seed_value = _seed()
	GameConfig.loaded_world = null
	GameConfig.loaded_campaign = null
	GameConfig.player_ai = false
	get_tree().change_scene_to_file("res://game/game.tscn")


func _apply_orientation() -> void:
	## 0.18 : en portrait, les colonnes s'empilent et les marges se resserrent (mêmes boutons, même ordre).
	var portrait: bool = ResponsiveLayout.is_portrait(self)
	if _middle != null:
		_middle.vertical = portrait
	if _era_row != null:
		_era_row.alignment = BoxContainer.ALIGNMENT_CENTER if portrait else BoxContainer.ALIGNMENT_END
	if _frame != null:
		for edge in ["left", "right"]:
			_frame.add_theme_constant_override("margin_" + edge, 16 if portrait else 36)
	if _lab_columns != null:
		_lab_columns.vertical = portrait
		_tools_scroll.custom_minimum_size = Vector2(0, 420) if portrait else Vector2(500, 0)
	if _lab_drawer != null:
		_lab_drawer.offset_left = 8 if portrait else 30
		_lab_drawer.offset_right = -8 if portrait else -30
