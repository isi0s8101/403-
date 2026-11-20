class_name StrategicHud
extends CanvasLayer
## J6-J8 : panneau d'orbite et de théâtres, commandes accessibles au pouce.
## L'interface ne manipule jamais la simulation autrement que via StarCampaign.

var game
var root: Control
var toggle_btn: Button
var panel: PanelContainer
var status: Label
var sector_buttons: Dictionary = {}
var launch_buttons: Dictionary = {}
var alert_buttons: Array = []
var sat_btn: Button
var scan_btn: Button
var galaxy_btn: Button
var _timer: float = 0.0

func setup(p_game) -> void:
	game = p_game
	root = Control.new()
	root.theme = MobileUI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	toggle_btn = _button("+ SECTEURS", _toggle)
	toggle_btn.anchor_left = 1.0
	toggle_btn.anchor_right = 1.0
	toggle_btn.offset_left = -190.0
	toggle_btn.offset_right = -12.0
	toggle_btn.offset_top = 152.0
	toggle_btn.offset_bottom = 206.0
	root.add_child(toggle_btn)
	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -306.0
	panel.offset_right = -12.0
	panel.offset_top = 212.0
	panel.offset_bottom = 565.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# 0.17 : le panneau stratégique prend l'habillage du thème de l'âge (aucune couleur fixée ici).
	panel.add_theme_constant_override("margin", 8)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var items := VBoxContainer.new()
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items.add_theme_constant_override("separation", 5)
	scroll.add_child(items)
	var heading := Label.new()
	heading.text = "COMMANDEMENT STRATÉGIQUE"
	heading.add_theme_font_size_override("font_size", 16)
	items.add_child(heading)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	items.add_child(status)
	galaxy_btn = _button("CARTE GALACTIQUE · ÂGE X", func(): game.enter_space_overview("galaxy"))
	items.add_child(galaxy_btn)
	for key in game.campaign.sector_keys():
		if not StarCampaign.SECTORS.has(String(key)):
			continue
		var sector: String = key
		var b := _button("", func(): game.switch_sector(sector))
		sector_buttons[sector] = b
		items.add_child(b)
	var heading_actions := Label.new()
	heading_actions.text = "ORBITAL / EXPÉDITIONS"
	items.add_child(heading_actions)
	sat_btn = _button("Placer un satellite · 400 minerai", _satellite)
	items.add_child(sat_btn)
	scan_btn = _button("Balayage orbital · toucher la carte", _scan)
	items.add_child(scan_btn)
	for key in game.campaign.sector_keys():
		if not StarCampaign.SECTORS.has(String(key)):
			continue
		var sector: String = key
		var b := _button("", func(): _dispatch(sector))
		launch_buttons[sector] = b
		items.add_child(b)
	var alert_label := Label.new()
	alert_label.text = "ALERTES DES AUTRES SECTEURS · toucher pour rejoindre"
	alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items.add_child(alert_label)
	for i in range(5):
		var alert_button := _button("", _jump_to_alert.bind(i))
		alert_buttons.append(alert_button)
		items.add_child(alert_button)
	var close := _button("Fermer", _toggle)
	items.add_child(close)
	panel.visible = false
	refresh(0.0, true)

func _button(caption: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _toggle() -> void:
	panel.visible = not panel.visible
	toggle_btn.text = "× SECTEURS" if panel.visible else "+ SECTEURS"
	refresh(0.0, true)

func is_over_ui(p: Vector2) -> bool:
	return (toggle_btn.visible and toggle_btn.get_global_rect().has_point(p)) or (panel.visible and panel.get_global_rect().has_point(p))

func _selected_port() -> SimWorld.Building:
	var w: SimWorld = game.world
	var b: SimWorld.Building = w.buildings.get(game.sel_building) as SimWorld.Building
	if b != null and b.team == game.player and b.complete and b.type in ["spatioport", "chantier_orbital"]:
		return b
	return null

func _satellite() -> void:
	var port: SimWorld.Building = _selected_port()
	if port == null:
		game.hud.set_hint("Sélectionner un spatioport ou chantier orbital achevé.")
		return
	var result: Dictionary = game.campaign.launch_satellite(game.player, game.campaign.active, port.id)
	game.hud.set_hint("Satellite déployé" if result["ok"] else String(result["reason"]))
	refresh(0.0, true)

func _scan() -> void:
	var yard: Dictionary = OrbitalIndustry.site(game.campaign, game.player, game.campaign.active)
	var sensors: bool = OrbitalIndustry.has_hub(game.campaign, game.player, game.campaign.active) and int((yard.get("modules", {}) as Dictionary).get("radar", 0)) > 0
	if int(game.campaign.satellites[game.player]) < 1 and not sensors:
		game.hud.set_hint("Lancer un satellite ou construire un radar orbital.")
		return
	game.mode = "scan_orbite"
	panel.visible = false
	game.hud.set_hint("Touchez une position de la planète pour la révéler 18 secondes.")

func _dispatch(to: String) -> void:
	var port: SimWorld.Building = _selected_port()
	if port == null:
		game.hud.set_hint("Sélectionner d'abord un spatioport ou chantier orbital achevé.")
		return
	var available: Dictionary = game.campaign.shipping_candidates(game.player, game.campaign.active, port.id, to)
	if not bool(available.get("ok", false)):
		game.hud.set_hint(String(available.get("reason", "Convoi impossible")))
		return
	var ships: Array = available["ships"]
	var cargo: Array = available["cargo"]
	if ships.is_empty() or cargo.is_empty():
		game.hud.set_hint("Un vaisseau et au moins une unité doivent se trouver près du port.")
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Composer le convoi → " + String(game.campaign.info(to)["label"])
	dialog.ok_button_text = "Confirmer et payer"
	dialog.dialog_hide_on_ok = false
	dialog.min_size = Vector2i(540, 420)
	root.add_child(dialog)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 300)
	dialog.add_child(box)
	var ship_label := Label.new()
	ship_label.text = "Vaisseau :"
	box.add_child(ship_label)
	var ships_select := OptionButton.new()
	for item in ships:
		ships_select.add_item("%s #%d" % [String(Rules.UNITS[String(item["type"])]["label"]), int(item["id"])], int(item["id"]))
	box.add_child(ships_select)
	var interstellar: bool = String(game.campaign.info(game.campaign.active)["system"]) != String(game.campaign.info(to)["system"])
	var price: Dictionary = StarCampaign.STAR_TRAVEL_COST.duplicate(true) if interstellar else StarCampaign.TRAVEL_COST.duplicate(true)
	var destination_world: SimWorld = game.campaign.materialize(to)
	if destination_world == null:
		game.hud.set_hint("Monde inaccessible")
		return
	if destination_world.team_buildings(game.player, "centre", true).is_empty():
		for resource in StarCampaign.COLONY_COST:
			price[resource] = int(price.get(resource, 0)) + int(StarCampaign.COLONY_COST[resource])
	var cost_label := Label.new()
	cost_label.text = "Coût confirmé au lancement : %d nourriture · %d bois · %d minerai" % [int(price.get("food", 0)), int(price.get("wood", 0)), int(price.get("ore", 0))]
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(cost_label)
	var label := Label.new()
	label.text = "Choisir 1 à 6 unités (max.). Aucune unité n'est choisie à votre place."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 220
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	scroll.add_child(rows)
	var selection: Dictionary = {}
	for item in cargo:
		var check := CheckBox.new()
		check.text = "%s #%d" % [String(Rules.UNITS[String(item["type"])]["label"]), int(item["id"])]
		rows.add_child(check)
		selection[int(item["id"])] = check
	var from_sector: String = game.campaign.active
	var port_id: int = port.id
	dialog.confirmed.connect(func():
		var chosen: Array = []
		for uid in selection.keys():
			var checkbox: CheckBox = selection[uid] as CheckBox
			if checkbox.button_pressed:
				chosen.append(int(uid))
		if chosen.is_empty() or chosen.size() > 6:
			game.hud.set_hint("Sélectionner entre 1 et 6 unités ; aucun convoi lancé.")
			return
		var result: Dictionary = game.campaign.dispatch(game.player, from_sector, port_id, to, chosen, ships_select.get_selected_id())
		game.hud.set_hint("Convoi confirmé vers %s (%d unités)" % [String(game.campaign.info(to)["label"]), chosen.size()] if bool(result["ok"]) else String(result["reason"]))
		if bool(result["ok"]):
			dialog.hide()
			dialog.queue_free()
		refresh(0.0, true)
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	# La fenêtre reste ouverte en cas de cargaison invalide.
	# Elle est libérée uniquement après validation du lancement.
	dialog.popup_centered()

func _jump_to_alert(index: int) -> void:
	var visible_alerts: Array = _player_alerts()
	if index < visible_alerts.size():
		var sector: String = String(visible_alerts[index]["sector"])
		if game.campaign.is_unlocked(game.player, sector):
			game.switch_sector(sector)
			var region: String = String(visible_alerts[index].get("region", ""))
			if sector == "val" and game.campaign.planet_regions != null and not region.is_empty():
				var coords: PackedStringArray = region.split(":")
				if coords.size() == 2 and coords[0].is_valid_int() and coords[1].is_valid_int():
					game.jump_to_region(Vector2i(int(coords[0]), int(coords[1])))
			panel.visible = false
		else:
			game.hud.set_hint("Alerte sur un secteur non encore débloqué : " + String(game.campaign.info(sector)["label"]))

func _player_alerts() -> Array:
	var relevant: Array = []
	for n in game.campaign.notices:
		if int(n.get("team", -1)) == game.player:
			var sector: String = String(n.get("sector", ""))
			var region: String = String(n.get("region", ""))
			var remote: bool = sector != game.campaign.active
			if sector == "val" and game.campaign.planet_regions != null and not region.is_empty():
				remote = remote or region != PlanetRegions.key(game.campaign.planet_regions.active)
			if remote:
				relevant.append(n)
	relevant.reverse()
	return relevant.slice(0, 5)

func refresh(delta: float, force: bool = false) -> void:
	_timer += delta
	if not force and _timer < 0.75:
		return
	_timer = 0.0
	var c: StarCampaign = game.campaign
	if c == null:
		return
	var team: int = game.player
	var flights_count: int = 0
	for mission in c.flights:
		if int(mission["team"]) == team:
			flights_count += 1
	var region_count: int = c.planet_regions.regions.size() if c.planet_regions != null else 0
	status.text = "Âge %s · satellites %d/3 · convois %d\nSecteurs : %d · régions actives : %d" % [Hud.ROMAN[int(c.ages[team])], int(c.satellites[team]), flights_count, c.worlds.size(), region_count]
	var current_notices: Array = _player_alerts()
	if not current_notices.is_empty():
		status.text += "\nAlertes hors écran : %d (5 dernières affichées)" % current_notices.size()
	for i in range(alert_buttons.size()):
		var b_alert: Button = alert_buttons[i] as Button
		b_alert.visible = i < current_notices.size()
		if i < current_notices.size():
			var message: Dictionary = current_notices[i]
			b_alert.text = "T%d · %s" % [int(message["tick"]), String(message["text"]).substr(0, 75)]
	var port: SimWorld.Building = _selected_port()
	for key in sector_buttons.keys():
		var def: Dictionary = c.info(key)
		var w: SimWorld = c.worlds.get(key) as SimWorld
		var units_count: int = w.team_units(team).size() if w != null else 0
		var b: Button = sector_buttons[key]
		b.text = ("• " if c.active == key else "· ") + String(def["label"]) + " · %d unités" % units_count
		b.disabled = not c.is_unlocked(team, key)
		var launch: Button = launch_buttons[key]
		launch.text = "Envoyer → " + String(def["label"])
		launch.disabled = key == c.active or port == null or not c.is_unlocked(team, key)
	sat_btn.disabled = port == null or int(c.ages[team]) < 9 or int(c.satellites[team]) >= 3 or c.tick < int(c.sat_cooldown[team])
	scan_btn.disabled = int(c.satellites[team]) < 1 or c.tick < int(c.scan_cooldown[team])
	var galaxy_access: Dictionary = game.view_status("galaxy")
	galaxy_btn.disabled = not bool(galaxy_access["ok"])
	galaxy_btn.tooltip_text = String(galaxy_access["reason"])
