class_name ColonyPanel
extends PanelContainer
## J13 : tableau de colonie de la vue planétaire (lecture + commandes tactiles).
## La vue n'écrit jamais l'état : chaque bouton appelle une commande métier validée
## par la simulation, et affiche la raison en cas de refus. Rafraîchi par minuterie,
## jamais par la logique de jeu.
var game: Node
var team: int = 0
var info: Label
var feedback: Label
var governor_btn: Button
var ratio_btn: Button
var age_btn: Button
var _preset: int = 0

func setup(p_game: Node, p_team: int = 0) -> void:
	game = p_game
	team = p_team
	theme = MobileUI.theme()
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -408.0
	offset_right = -18.0
	offset_top = 16.0
	offset_bottom = -18.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	add_child(v)
	var title := Label.new()
	title.text = "COLONIE PLANÉTAIRE"
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	var pages: Dictionary = {}
	for page in ["État", "Zones", "Services", "Gestion"]:
		var scroll := ScrollContainer.new()
		scroll.name = page
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(content)
		pages[page] = content
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 15)
	(pages["État"] as VBoxContainer).add_child(info)
	var zone_page: VBoxContainer = pages["Zones"] as VBoxContainer
	var help := Label.new()
	help.text = "Habitat → habitants\nCommerce → crédits\nIndustrie → équipements\nLes routes et services conditionnent la production."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", MobileUI.MUTED)
	zone_page.add_child(help)
	for kind in J13Rules.ZONES:
		var row := HBoxContainer.new()
		zone_page.add_child(row)
		var construct: Button = _button("+ " + String(J13Rules.ZONE_LABELS[kind]), _build.bind(String(kind)))
		construct.add_theme_color_override("font_color", MobileUI.ZONE_COLORS[kind] as Color)
		row.add_child(construct)
		var densify: Button = _button("Densifier", _densify.bind(String(kind)))
		row.add_child(densify)
	ratio_btn = _button("Modifier la cible R/C/I", _cycle_ratio)
	zone_page.add_child(ratio_btn)
	var service_page: VBoxContainer = pages["Services"] as VBoxContainer
	for kind in ["power", "water", "hospital", "fire", "police"]:
		service_page.add_child(_button("+ " + String(J13Rules.SERVICE_LABELS[kind]), _build.bind(String(kind))))
	var management: VBoxContainer = pages["Gestion"] as VBoxContainer
	governor_btn = _button("Gouverneur", _toggle_governor)
	management.add_child(governor_btn)
	age_btn = _button("Âge local suivant", _age_up)
	management.add_child(age_btn)
	var overlay_label := Label.new()
	overlay_label.text = "COUCHE D'ANALYSE DU GLOBE"
	management.add_child(overlay_label)
	var overlay := OptionButton.new()
	overlay.custom_minimum_size.y = 48
	for label in ["Zonage · triangle R / carré C / hexagone I", "Électricité", "Eau", "Hôpital", "Pompiers", "Police", "Vue naturelle"]:
		overlay.add_item(label)
	overlay.item_selected.connect(func(index: int):
		var view_node: PlanetGlobeView = game.planet_globe as PlanetGlobeView
		if view_node != null:
			view_node.set_overlay(["zones", "power", "water", "hospital", "fire", "police", "none"][index]))
	management.add_child(overlay)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 14)
	feedback.custom_minimum_size.y = 38
	v.add_child(feedback)
	var legend := Label.new()
	legend.text = "R habitat · C commerce · I industrie\nServices : vert couvert · rouge non desservi\nLe placement rapide choisit une parcelle reliée."
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", MobileUI.MUTED)
	v.add_child(legend)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)
	refresh()

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	return b

func _campaign() -> StarCampaign:
	return game.campaign as StarCampaign if game != null else null

func _say(result: Dictionary, done: String) -> void:
	feedback.text = done if bool(result.get("ok", false)) else "Refusé : " + String(result.get("reason", "?"))
	refresh()

func _build(kind: String) -> void:
	var c: StarCampaign = _campaign()
	if c == null:
		return
	var result: Dictionary = c.planets.quick_build(c, team, c.active, kind)
	_say(result, String(result.get("note", "Construit")))

func _densify(kind: String) -> void:
	var c: StarCampaign = _campaign()
	if c == null:
		return
	var result: Dictionary = c.planets.quick_densify(c, team, c.active, kind)
	_say(result, "Niveau supérieur : " + String(result.get("note", "")))

func _cycle_ratio() -> void:
	var c: StarCampaign = _campaign()
	if c == null:
		return
	var names: Array = J13Rules.PRESETS.keys()
	_preset = (_preset + 1) % names.size()
	var target: Dictionary = J13Rules.PRESETS[names[_preset]] as Dictionary
	_say(c.set_zoning_balance(team, c.active, float(target["R"]), float(target["C"]), float(target["I"])), "Cible : " + String(names[_preset]))

func _toggle_governor() -> void:
	var c: StarCampaign = _campaign()
	if c == null or not c.planets.has_colony(team, c.active):
		return
	var enabled: bool = bool((c.planets.colony(team, c.active)["governor"] as Dictionary)["enabled"])
	_say(c.set_governor_policy(team, c.active, not enabled), "Gouverneur suspendu" if enabled else "Gouverneur actif")

func _age_up() -> void:
	var c: StarCampaign = _campaign()
	if c != null:
		_say(c.advance_colony_age(team, c.active), "Passage d'âge local lancé")

func refresh() -> void:
	var c: StarCampaign = _campaign()
	if c == null or info == null:
		return
	var s: Dictionary = c.planets.summary(c, team, c.active)
	if s.is_empty():
		info.text = "Aucune colonie du camp sur ce monde.\nFonder une colonie par navette (elle naîtra à l'âge VII)."
		var blocked: String = c.planets.lock_text(c, team, c.active)
		if not blocked.is_empty():
			info.text += "\n× " + blocked
		return
	var target: Dictionary = s["target"] as Dictionary
	var gov: Dictionary = s["governor"] as Dictionary
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Empire %s · colonie %s%s" % [J13Rules.roman(int(s["empire_age"])), J13Rules.roman(int(s["local_age"])), "" if String(s["status"]) == "integrated" else " · " + String(s["status"])])
	lines.append("Trésorerie %d cr · réserve locale %d cr" % [int(float(s["credits"])), int(float(s["reserve"]))])
	lines.append("Population %d / %d · emplois %d / %d" % [int(s["pop"]), int(s.get("housing", 0)), int(s.get("employed", 0)), int(s.get("jobs", 0))])
	lines.append("R %d %% · C %d %% · I %d %%  (cible %d/%d/%d)" % [int(float(s.get("R", 0.0)) * 100.0), int(float(s.get("C", 0.0)) * 100.0), int(float(s.get("I", 0.0)) * 100.0),
		int(float(target["R"]) * 100.0), int(float(target["C"]) * 100.0), int(float(target["I"]) * 100.0)])
	lines.append("Électricité %d %% · eau %d %%" % [int(float(s.get("power", 1.0)) * 100.0), int(float(s.get("water", 1.0)) * 100.0)])
	lines.append("Santé %d %% · pompiers %d %% · police %d %%" % [int(float(s.get("hospital", 1.0)) * 100.0), int(float(s.get("fire", 1.0)) * 100.0), int(float(s.get("police", 1.0)) * 100.0)])
	lines.append("Périmètre éligible aménagé : %d %%" % int(float(s.get("developed", 0.0)) * 100.0))
	var stocks: Dictionary = s["stocks"] as Dictionary
	var goods: PackedStringArray = PackedStringArray()
	for good in J13Rules.GOODS:
		if float(stocks[good]) >= 1.0:
			goods.append("%s %d" % [String(J13Rules.GOOD_LABELS[good]), int(float(stocks[good]))])
	lines.append("Industrie : " + (", ".join(goods) if not goods.is_empty() else "aucun stock fabriqué"))
	lines.append("Stations en orbite : %d alliée(s), %d ennemie(s)" % [int(s["stations"]), int(s["enemy_stations"])])
	if not String(s["lock"]).is_empty():
		lines.append("× " + String(s["lock"]))
	if not (s["research"] as Dictionary).is_empty():
		lines.append("Passage à l'âge %s : %d ticks" % [J13Rules.roman(int(s["research"]["target"])), maxi(0, int(s["research"]["remaining"]))])
	if not String(gov["status"]).is_empty():
		lines.append("Gouverneur : " + String(gov["status"]))
	info.text = "\n".join(lines)
	governor_btn.text = "Gouverneur : " + ("ACTIF · suspendre" if bool(gov["enabled"]) else ("suspendu" if bool(gov["granted"]) else "âge X local requis"))
	governor_btn.disabled = int(s["local_age"]) < 10
	age_btn.disabled = String(s["origin"]) in ["home", "legacy"] or int(s["local_age"]) >= 10
