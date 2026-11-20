class_name CityPanel
extends PanelContainer
## 0.18 — Panneau « Ville » : bien-être général et ses facteurs, habitants et emplois, réseaux électrique et d'eau,
## production, incidents, conseils (avec « Placer » qui lance la pose du bâtiment conseillé) et vues au sol.
## Lecture seule : les actions passent par la pose habituelle (commandes validées par la simulation).

const FACTORS := [["securite", "Sécurité"], ["incendies", "Protection incendie"], ["sante", "Santé"], ["cadre", "Air (pollution)"],
	["eau", "Eau potable"], ["electricite", "Électricité"], ["services", "Couverture des services"]]
var game
var content: VBoxContainer
var views: HFlowContainer
var legend: Label
var _timer: float = 0.0
var _signature: String = ""

func setup(p_game) -> void:
	game = p_game
	name = "CityPanel"
	theme = MobileUI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 70
	offset_right = -70
	offset_top = 80
	offset_bottom = -30
	mouse_filter = Control.MOUSE_FILTER_STOP
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	var bar := HBoxContainer.new()
	layout.add_child(bar)
	var title := Label.new()
	title.text = "VILLE"
	title.theme_type_variation = "HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var close := MobileUI.button("Fermer", func(): hide(), 48)
	close.custom_minimum_size.x = 140
	bar.add_child(close)
	views = HFlowContainer.new()
	views.add_theme_constant_override("h_separation", 6)
	views.add_theme_constant_override("v_separation", 6)
	layout.add_child(views)
	for key in CityOverlay.VIEWS:
		var b := MobileUI.button(String(CityOverlay.VIEW_LABEL[key]), set_view.bind(String(key)), 44)
		b.custom_minimum_size.x = 96
		b.set_meta("view", String(key))
		b.tooltip_text = "Vue au sol : " + String(CityOverlay.VIEW_LABEL[key])
		views.add_child(b)
	legend = Label.new()
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.theme_type_variation = "MutedLabel"
	layout.add_child(legend)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	hide()

func open() -> void:
	show()
	move_to_front()
	_signature = ""
	rebuild()

func set_view(key: String) -> void:
	game.city_view = key
	if game.city_overlay != null:
		game.city_overlay.set_view(key)
	_signature = ""
	rebuild()

func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer >= 0.5:
		_timer = 0.0
		rebuild()

func _label(text: String, variation: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if variation != "":
		label.theme_type_variation = variation
	content.add_child(label)
	return label

func _bar(caption: String, value: float, detail: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = caption
	name_label.custom_minimum_size.x = 190
	name_label.clip_text = true
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = clampf(value, 0.0, 100.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = CityOverlay.tint(clampf(value / 100.0, 0.0, 1.0))
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var number := Label.new()
	number.text = "%d%s" % [int(round(clampf(value, 0.0, 100.0))), ("  " + detail) if detail != "" else ""] # 0.18 : un réseau excédentaire affiche 100
	number.custom_minimum_size.x = 56
	row.add_child(number)
	content.add_child(row)

func advice(w: SimWorld, team: int) -> Array:
	## [texte, bâtiment conseillé] — les problèmes les plus graves d'abord.
	var c: Dictionary = (w.teams[team] as SimWorld.Team).city
	var out: Array = []
	var power: Array = c.get("power", [0, 0]) as Array
	var water: Array = c.get("water", [0, 0]) as Array
	var f: Dictionary = c.get("factors", {}) as Dictionary
	var team_age: int = (w.teams[team] as SimWorld.Team).age
	if bool(c.get("famine", false)):
		out.append(["Famine : plus de nourriture pour les habitants.", "zone_a"])
	if int(power[1]) > int(power[0]):
		out.append(["Électricité insuffisante (%d / %d) : des bâtiments sont délestés." % [int(power[0]), int(power[1])], "centrale"])
	if int(water[1]) > int(water[0]):
		out.append(["Eau insuffisante (%d / %d) : santé et croissance pénalisées." % [int(water[0]), int(water[1])], "chateau_eau" if bool(c.get("electric", false)) else "puits"])
	var off_grid: int = 0
	for candidate in w.team_buildings(team, "", true):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.POWER_USE.has(b.type) and not bool(b.city.get("powered_grid", true)):
			off_grid += 1
	if off_grid > 0:
		out.append(["%d bâtiment(s) hors du réseau électrique : prolongez-le." % off_grid, "poste_electrique"])
	if int(c.get("burning", 0)) > 0 and float(f.get("incendies", 100.0)) < 60.0:
		out.append(["Incendie en cours sans pompiers à portée.", "caserne_pompiers" if team_age >= 4 else "puits"])
	if float(f.get("securite", 100.0)) < 60.0:
		out.append(["Criminalité élevée.", "commissariat" if team_age >= 3 else "caserne"])
	if float(f.get("sante", 100.0)) < 60.0 and team_age >= 2:
		out.append(["Santé fragile : risque d'épidémie.", "hopital"])
	if float(f.get("cadre", 100.0)) < 65.0 and team_age >= 4:
		out.append(["Air pollué : les habitants souffrent.", "recyclage" if (w.teams[team] as SimWorld.Team).age >= 6 else "decharge"])
	if float(c.get("unemployment", 0.0)) > 0.2:
		out.append(["Chômage %d %% : créez des emplois." % int(100.0 * float(c.get("unemployment", 0.0))), "zone_c"])
	elif float(c.get("fill", 0.0)) < 0.8 and int(c.get("jobs", 0)) > 0:
		out.append(["Emplois vacants : logez plus d'habitants.", "zone_r"])
	return out

func rebuild() -> void:
	var w: SimWorld = game.world
	var team: int = game.player
	var c: Dictionary = (w.teams[team] as SimWorld.Team).city
	# 0.19 : la ville existe dès l'âge I dès qu'il y a du zonage (avant l'Électricité : besoins d'époque).
	var on: bool = UrbanCity.active(w, team) or not c.is_empty()
	for b in views.get_children():
		var button: Button = b as Button
		button.theme_type_variation = "ToggleOnButton" if String(button.get_meta("view")) == String(game.city_view) else ""
		button.disabled = not on and String(button.get_meta("view")) != ""
	legend.text = "Vue au sol : " + String(CityOverlay.VIEW_LABEL.get(game.city_view, "Aucune")) + ((" — " + String(CityOverlay.LEGEND[game.city_view])) if CityOverlay.LEGEND.has(game.city_view) else "")
	var signature: String = "%s:%d:%s" % [str(on), int(c.get("tick", -1)), String(game.city_view)]
	if signature == _signature:
		return
	_signature = signature
	UIMotion.clear(content)
	if not on:
		_label("Bâtissez une ville : bouton « Zones » (en bas à gauche).", "HeaderLabel")
		_label("Tracez une route reliée au centre, peignez de l'habitat, du commerce et de l'agriculture le long de la route : les bâtiments poussent seuls si la demande, les ressources et la sécurité le permettent.")
		_label("À l'âge IV, la recherche « Électricité » (usine) fait passer toute l'économie à la ville : fermes, maisons et récolte s'arrêtent.", "MutedLabel")
		return
	var electric: bool = bool(c.get("electric", false))
	_label("%s · %s · temps %s" % [String(c.get("settlement", "Campement")), "réseaux modernes" if electric else "avant l'électricité", String(c.get("weather", "tempéré"))], "MutedLabel")
	var wb: float = float(c.get("wellbeing", 0.0))
	_bar("Bien-être général", wb, "productivité ×%.2f" % float(c.get("productivity", 1.0)))
	var f: Dictionary = c.get("factors", {}) as Dictionary
	for pair in FACTORS:
		_bar("· " + String(pair[1]), float(f.get(String(pair[0]), 0.0)))
	_label("POPULATION", "HeaderLabel")
	_label("%d habitants · %d actifs · %d emplois (%d occupés) · chômage %d %% · +%d places d'unités" % [int(c.get("habitants", 0)), int(c.get("actifs", 0)), int(c.get("jobs", 0)), int(c.get("employed", 0)), int(round(100.0 * float(c.get("unemployment", 0.0)))), int(c.get("pop_bonus", 0))])
	var demand: Dictionary = c.get("demand", {}) as Dictionary
	if not demand.is_empty():
		_label("DEMANDE", "HeaderLabel")
		_label("Habitat %+d · commerce %+d · industrie %+d · agriculture %+d" % [int(round(100.0 * float(demand.get("zone_r", 0.0)))), int(round(100.0 * float(demand.get("zone_c", 0.0)))), int(round(100.0 * float(demand.get("zone_i", 0.0)))), int(round(100.0 * float(demand.get("zone_a", 0.0))))])
	_label("RÉSEAUX", "HeaderLabel")
	var power: Array = c.get("power", [0, 0]) as Array
	var water: Array = c.get("water", [0, 0]) as Array
	if electric:
		_bar("Électricité", 100.0 * float(power[0]) / float(maxi(1, int(power[1]))) if int(power[1]) > 0 else 100.0, "%d produits / %d demandés" % [int(power[0]), int(power[1])])
	_bar("Eau", 100.0 * float(water[0]) / float(maxi(1, int(water[1]))) if int(water[1]) > 0 else 100.0, "%d fournis / %d demandés" % [int(water[0]), int(water[1])])
	_label("Nourriture des habitants : %.1f vivres/s%s" % [float(c.get("upkeep", 0.0)), " — FAMINE" if bool(c.get("famine", false)) else ""])
	_label("PRODUCTION", "HeaderLabel")
	var p: Dictionary = c.get("production", {}) as Dictionary
	_label("+%.1f nourriture/s · +%.1f bois/s · +%.1f minerai/s (zones et centre de commandement)" % [float(p.get("food", 0.0)), float(p.get("wood", 0.0)), float(p.get("ore", 0.0))])
	_label("INCIDENTS", "HeaderLabel")
	_label("Incendies en cours %d · déclarés %d · bâtiments perdus %d · ruines %d · épidémies %d · émeutes %d · pillages %d" % [int(c.get("burning", 0)), int(c.get("fires_total", 0)), int(c.get("fire_losses", 0)), int(c.get("ruins_total", 0)), int(c.get("epidemics", 0)), int(c.get("riots_total", 0)), int(c.get("pillages", 0))])
	# 0.20 : événements urbains.
	var events: String = UrbanEvents.labels(w.teams[team])
	var last: Dictionary = c.get("last_event", {}) as Dictionary
	if events != "" or not last.is_empty():
		_label("ÉVÉNEMENTS", "HeaderLabel")
		var last_text: String = ""
		if not last.is_empty():
			last_text = "Dernier : %s (%d bâtiment(s) touché(s))" % [String((UrbanEvents.EVENTS.get(String(last["key"]), {}) as Dictionary).get("label", last["key"])), int(last.get("hit", 0))]
		_label(("En cours : " + events + (" · " if last_text != "" else "") if events != "" else "") + last_text)
	# 0.20 : toutes les villes du camp, monde par monde (calcul détaillé à l'écran, abrégé ailleurs).
	if game.campaign != null:
		var empire: Dictionary = UrbanAbstract.empire(game.campaign, team)
		var worlds: Array = empire["worlds"] as Array
		if worlds.size() > 1 or (worlds.size() == 1 and String((worlds[0] as Dictionary)["key"]) != String(game.campaign.active)):
			_label("TOUTES VOS VILLES", "HeaderLabel")
			for raw in worlds:
				var s: Dictionary = raw as Dictionary
				_label("%s : %d habitants · %d bâtiments · niveau moyen %.1f · criminalité %d%s" % [String(s["label"]), int(s["habitants"]), int(s["buildings"]),
					float(s["level_avg"]), int(round(float(s["crime"]))), " (calcul abrégé)" if bool(s["far"]) else " (à l'écran)"])
			_label(UrbanAbstract.empire_line(game.campaign, team), "MutedLabel")
	var tips: Array = advice(w, team)
	_label("CONSEILS", "HeaderLabel")
	if tips.is_empty():
		_label("Rien d'urgent. Améliorez les zones heureuses pour les densifier.", "MutedLabel")
	for tip in tips:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var text := Label.new()
		text.text = String(tip[0])
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var kind: String = String(tip[1])
		var zoned: bool = UrbanZoning.LEGACY_CODE.has(kind)
		var place := MobileUI.button(("Zoner : " if zoned else "Placer : ") + String(Rules.BUILDINGS[kind]["label"]), _place.bind(kind), 44)
		place.custom_minimum_size.x = 200
		place.disabled = not zoned and (not CivEvolution.visible_building(w, team, kind) or int(Rules.BUILDINGS[kind]["age"]) > (w.teams[team] as SimWorld.Team).age)
		row.add_child(place)
		content.add_child(row)

func _place(kind: String) -> void:
	hide()
	if UrbanZoning.LEGACY_CODE.has(kind):
		# 0.19 : une zone ne se pose pas, elle se peint : on ouvre le mode Zonage sur la bonne catégorie.
		if not game.zoning_tool.active:
			game.hud.toggle_zoning()
		game.zoning_tool.set_kind(int(UrbanZoning.LEGACY_CODE[kind]))
		return
	game.start_placement(kind)
