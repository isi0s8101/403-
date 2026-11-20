class_name PlanetHud
extends CanvasLayer
## Commandes mobiles de l'atlas planétaire, sans modifier les ordres tactiques.
var game: Node3D
var root: Control
var panel: PanelContainer
var region_label: Label
var enter_btn: Button
var back_btn: Button
var orbit_btn: Button
var selected_coords: Vector2 = Vector2.ZERO
var has_region: bool = false
var colony_panel: ColonyPanel
var legend: Label                    # 0.18 : légende (repositionnée en portrait)

func setup(p_game: Node3D) -> void:
	game = p_game
	root = Control.new()
	root.theme = MobileUI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.offset_left = 18.0
	panel.offset_right = 370.0
	panel.offset_top = 16.0
	panel.offset_bottom = 319.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "ATLAS PLANÉTAIRE"
	title.add_theme_font_size_override("font_size", 21)
	v.add_child(title)
	region_label = Label.new()
	region_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	region_label.text = "Glisser pour faire pivoter · toucher pour sonder"
	v.add_child(region_label)
	enter_btn = Button.new()
	enter_btn.text = "EXPLORER CETTE RÉGION"
	enter_btn.custom_minimum_size.y = 48
	enter_btn.disabled = true
	enter_btn.pressed.connect(_open_selected)
	v.add_child(enter_btn)
	back_btn = Button.new()
	back_btn.text = "← Retour au terrain tactique"
	back_btn.custom_minimum_size.y = 43
	back_btn.pressed.connect(func(): game.leave_planet_overview())
	v.add_child(back_btn)
	orbit_btn = Button.new()
	orbit_btn.text = "ZOOM − · Orbite de la planète"
	orbit_btn.custom_minimum_size.y = 43
	orbit_btn.pressed.connect(func(): game.enter_space_overview("orbit"))
	v.add_child(orbit_btn)
	var status: Dictionary = game.view_status("orbit")
	orbit_btn.disabled = not bool(status["ok"])
	orbit_btn.tooltip_text = String(status["reason"])
	# J13 : tableau de colonie (âge local, R/C/I, services, gouverneur, verrou orbital).
	colony_panel = ColonyPanel.new()
	root.add_child(colony_panel)
	colony_panel.setup(game)
	legend = Label.new()
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.text = "Planète · régions persistantes, chargées à la demande\nLes unités traversent les frontières via les commandes tactiques."
	legend.anchor_left = 0.0
	legend.anchor_top = 1.0
	legend.anchor_right = 0.0
	legend.anchor_bottom = 1.0
	legend.offset_left = 19.0
	legend.offset_right = 700.0
	legend.offset_top = -60.0
	legend.offset_bottom = -14.0
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(legend)
	root.resized.connect(_apply_orientation)
	_apply_orientation()

func _apply_orientation() -> void:
	## 0.18 : en portrait, l'atlas passe en haut sur toute la largeur et le tableau de colonie en panneau du bas.
	var portrait: bool = ResponsiveLayout.is_portrait(root)
	ResponsiveLayout.apply(panel, ResponsiveLayout.spec(Vector4(0, 0, 1, 0), Vector4(8, 8, -8, 8)) if portrait else {})
	ResponsiveLayout.apply(colony_panel, ResponsiveLayout.spec(Vector4(0, 0.56, 1, 1), Vector4(8, 0, -8, -8)) if portrait else {})
	ResponsiveLayout.apply(legend, ResponsiveLayout.spec(Vector4(0, 0.56, 1, 0.56), Vector4(12, -62, -12, -8)) if portrait else {})

func update_region(info: Dictionary) -> void:
	if not bool(info.get("hit", false)):
		return
	var biome: int = int(info.get("biome", 0))
	selected_coords = Vector2(float(info["lon"]), float(info["lat"]))
	has_region = true
	var region: Vector2i = PlanetGenerator.region_coords(selected_coords.x, selected_coords.y)
	region_label.text = "%s · longitude %.1f° · latitude %.1f°\nRégion %d / %d" % [PlanetGenerator.BIOME_NAMES[biome], rad_to_deg(selected_coords.x), rad_to_deg(selected_coords.y), region.x, region.y]
	enter_btn.disabled = biome == PlanetGenerator.OCEAN

func _open_selected() -> void:
	if has_region and enter_btn != null and not enter_btn.disabled:
		game.open_planet_region(selected_coords.x, selected_coords.y)

func is_over_ui(p: Vector2) -> bool:
	if colony_panel != null and colony_panel.get_global_rect().has_point(p):
		return true
	return panel != null and panel.get_global_rect().has_point(p)
