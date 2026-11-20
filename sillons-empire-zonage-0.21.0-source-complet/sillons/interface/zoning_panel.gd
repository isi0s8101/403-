class_name ZoningPanel
extends PanelContainer
## 0.19 — Barre du mode Zonage : types de zone (couleurs du calque), route, gomme ; outils (pinceau 1 à 3 cases,
## rectangle, parcelle, inspecter), annuler, fermer ; demande habitat / commerce / industrie / agriculture ;
## fiche du quartier inspecté. Mêmes boutons et mêmes gestes à tous les âges ; seul l'habillage change.

var game
var hud
var tool: ZoningTool
var type_buttons: Dictionary = {}     # code -> Button
var tool_buttons: Dictionary = {}     # nom -> Button
var info: Label
var demand_row: HBoxContainer
var demand_bars: Dictionary = {}
var filter_btn: Button                # 0.20 : filtre de la carte, un toucher passe au suivant

const TYPE_ORDER := [1, 2, 3, 4, 5, 6, -1, 0]

func setup(p_game, p_hud, p_tool: ZoningTool) -> void:
	game = p_game
	hud = p_hud
	tool = p_tool
	name = "ZoningPanel"
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var types := HFlowContainer.new()
	types.add_theme_constant_override("h_separation", 5)
	types.add_theme_constant_override("v_separation", 5)
	v.add_child(types)
	for code in TYPE_ORDER:
		var label: String = "Route" if code == -1 else ("Gomme" if code == 0 else String((UrbanZoning.KINDS[code] as Dictionary)["short"]))
		var b: Button = _button(label, func(): tool.set_kind(code), 0)
		b.add_theme_color_override("icon_normal_color", tool.kind_color(code))
		b.icon = _swatch(tool.kind_color(code))
		b.toggle_mode = true
		b.tooltip_text = _type_tip(code)
		types.add_child(b)
		type_buttons[code] = b
	var tools := HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 5)
	tools.add_theme_constant_override("v_separation", 5)
	v.add_child(tools)
	for entry in [["brush", "Pinceau"], ["rect", "Rectangle"], ["parcel", "Parcelle"], ["inspect", "Inspecter"]]:
		var key: String = String(entry[0])
		var b: Button = _button(String(entry[1]), func(): tool.set_tool(key), 0)
		b.toggle_mode = true
		tools.add_child(b)
		tool_buttons[key] = b
	tool_buttons["brush"].tooltip_text = "Peindre au doigt ; toucher de nouveau pour changer la taille (1, 2 ou 3 cases)"
	tool_buttons["rect"].tooltip_text = "Glisser pour couvrir un rectangle"
	tool_buttons["parcel"].tooltip_text = "Un toucher : une parcelle de 2 × 2 cases"
	tool_buttons["inspect"].tooltip_text = "Toucher un quartier pour voir sa fiche"
	filter_btn = _button("Filtre : aucun", func(): cycle_filter(), 0)
	filter_btn.tooltip_text = "Filtres de la carte : zonage, population, densité, criminalité, prospérité, production, pollution, état, incidents, infrastructures"
	tools.add_child(filter_btn)
	tools.add_child(_button("Annuler", func(): tool.undo(), 0))
	tools.add_child(_button("Fermer", func(): hud.toggle_zoning(), 0))
	# Demande : une seule ligne compacte (libellé puis barre), pour laisser la carte visible pendant qu'on peint.
	demand_row = HBoxContainer.new()
	demand_row.add_theme_constant_override("separation", 12)
	v.add_child(demand_row)
	for entry in [["zone_r", "Habitat"], ["zone_c", "Commerce"], ["zone_i", "Industrie"], ["zone_a", "Agricole"]]:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		var label := Label.new()
		label.text = String(entry[1])
		label.theme_type_variation = "MutedLabel"
		label.add_theme_font_size_override("font_size", 13)
		box.add_child(label)
		var bar := ProgressBar.new()
		bar.min_value = -100.0
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(58, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(bar)
		demand_row.add_child(box)
		demand_bars[String(entry[0])] = bar
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 13)
	info.custom_minimum_size = Vector2(300, 0)
	v.add_child(info)
	tool.changed.connect(refresh)
	refresh()
	_fit_buttons.call_deferred()

func _fit_buttons() -> void:
	## Le style « enfoncé » a des marges plus larges que le style normal : on réserve la place pour que le
	## libellé du bouton actif ne soit jamais coupé.
	for b in type_buttons.values() + tool_buttons.values() + [filter_btn]:
		var button: Button = b as Button
		var font: Font = button.get_theme_font("font")
		var text_w: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x if font != null else 0.0
		var icon_w: float = 22.0 if button.icon != null else 0.0
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, ceilf(text_w + icon_w + 30.0))

func _button(text: String, cb: Callable, min_w: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 44)
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	if hud != null and hud.feedback != null:
		hud.feedback.decorate(b)
	return b

func _swatch(color: Color) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	for i in 16:
		img.set_pixel(i, 0, Color(0, 0, 0, 0.6))
		img.set_pixel(i, 15, Color(0, 0, 0, 0.6))
		img.set_pixel(0, i, Color(0, 0, 0, 0.6))
		img.set_pixel(15, i, Color(0, 0, 0, 0.6))
	return ImageTexture.create_from_image(img)

func _type_tip(code: int) -> String:
	if code == -1:
		return "Route : tracer au doigt ; un bâtiment ne pousse qu'à 2 cases au plus d'une route reliée au centre"
	if code == 0:
		return "Gomme : retirer le zonage (les bâtiments se vident puis sont démolis)"
	var k: Dictionary = UrbanZoning.KINDS[code] as Dictionary
	return "%s : niveau %s au plus" % [String(k["label"]), UrbanRules.roman(int(k["cap"]))]

func cycle_filter() -> void:
	## Filtre suivant (Aucun → Zonage → Population → … → Aucun) ; même réglage que les vues du panneau Ville.
	var current: String = String(game.city_view)
	var index: int = CityOverlay.FILTERS.find(current)
	var next: String = String(CityOverlay.FILTERS[(index + 1) % CityOverlay.FILTERS.size()])
	set_filter(next)

func set_filter(key: String) -> void:
	game.city_view = key
	if game.city_overlay != null:
		game.city_overlay.set_view(key)
	refresh()

func refresh() -> void:
	if tool == null:
		return
	if filter_btn != null:
		var label: String = String(CityOverlay.VIEW_LABEL.get(String(game.city_view), "Aucune"))
		filter_btn.text = "Filtre : " + (label.to_lower() if String(game.city_view) != "" else "aucun")
		filter_btn.tooltip_text = String(CityOverlay.LEGEND.get(String(game.city_view), "Filtres de la carte"))
	for code in type_buttons.keys():
		(type_buttons[code] as Button).set_pressed_no_signal(int(code) == tool.kind and tool.tool != "inspect")
	for key in tool_buttons.keys():
		(tool_buttons[key] as Button).set_pressed_no_signal(String(key) == tool.tool)
	(tool_buttons["brush"] as Button).text = "Pinceau %d" % tool.brush
	var t: SimWorld.Team = game.world.teams[game.player]
	var demand: Dictionary = t.city.get("demand", {}) as Dictionary
	for key in demand_bars.keys():
		(demand_bars[key] as ProgressBar).value = 100.0 * float(demand.get(key, 0.0))
	info.text = _info_text()
	# Hors fiche de quartier, deux lignes suffisent : le panneau reste bas et la zone peinte reste visible.
	info.max_lines_visible = -1 if not tool.inspected.is_empty() else 2

func _info_text() -> String:
	var key: String = String(game.city_view)
	var legend: String = ("%s : %s" % [String(CityOverlay.VIEW_LABEL[key]), String(CityOverlay.LEGEND[key])]) if key != "" and CityOverlay.LEGEND.has(key) else ""
	if not tool.inspected.is_empty():
		return (legend + "\n" if legend != "" else "") + district_text(tool.inspected, game.world.teams[game.player])
	var lines: PackedStringArray = PackedStringArray()
	if tool.last_result != "":
		lines.append("Refus : " + tool.last_result)
	if legend != "":
		lines.append(legend)
	var events: String = UrbanEvents.labels(game.world.teams[game.player])
	if events != "":
		lines.append("En cours : " + events)
	if tool.kind == -1:
		var cost: Dictionary = UrbanZoning.road_cost(game.world, game.player)
		lines.append("Route : %s par case. Reliez-la au centre ; les parcelles à 2 cases au plus se construisent." % _cost_text(cost))
	elif tool.kind == 0:
		lines.append("Gomme : glisser sur les zones à retirer.")
	else:
		lines.append("%s : les bâtiments poussent seuls si la demande, la route, les ressources et la sécurité le permettent." % String((UrbanZoning.KINDS[tool.kind] as Dictionary)["label"]))
	var t: SimWorld.Team = game.world.teams[game.player]
	var lack: Dictionary = t.city.get("grow_lack", {}) as Dictionary
	var building: String = String((UrbanZoning.KINDS[tool.kind] as Dictionary)["building"]) if UrbanZoning.KINDS.has(tool.kind) else ""
	if building != "" and String(lack.get(building, "")) != "":
		lines.append("En attente : " + String(lack[building]))
	return "\n".join(lines)

static func _cost_text(cost: Dictionary) -> String:
	var names: Dictionary = {"food": "vivres", "wood": "bois", "ore": "minerai"}
	var parts: PackedStringArray = PackedStringArray()
	for res in cost.keys():
		parts.append("%s %s" % [String.num(float(cost[res]), 1).trim_suffix(".0"), String(names.get(res, res))])
	return ", ".join(parts)

static func district_text(s: Dictionary, t: SimWorld.Team) -> String:
	## Fiche du quartier : type, population, bâtiments, demande, niveau, emplois, production, richesse,
	## criminalité, états, incidents, infrastructures, potentiel d'évolution.
	if s.is_empty() or not s.has("label"):
		return "Aucune zone ici."
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s — %d cases, %d bâtiment(s), %d chantier(s)" % [String(s["label"]), int(s["cells"]), int(s["buildings"]), int(s["sites"])])
	var level_text: String = "niveau moyen %.1f (max %s, plafond %s)" % [float(s.get("level_avg", 0.0)), UrbanRules.roman(int(s["level_max"])), UrbanRules.roman(int(s.get("cap", 1)))]
	if String(s["building"]) == "zone_r":
		lines.append("%d habitants · %s" % [int(s["habitants"]), level_text])
	else:
		lines.append("%d / %d emplois occupés · %s" % [int(round(float(s["employed"]))), int(s["jobs"]), level_text])
	var out: Dictionary = s.get("out", {}) as Dictionary
	if not out.is_empty():
		var names: Dictionary = {"food": "vivres", "wood": "bois", "ore": "minerai"}
		var parts: PackedStringArray = PackedStringArray()
		for res in out.keys():
			parts.append("+%.1f %s/s" % [float(out[res]), String(names.get(res, res))])
		lines.append("Production : " + ", ".join(parts))
	var wealth: float = float(s.get("wealth", 0.0))
	var standing: String = "riche" if wealth >= 70.0 else ("populaire" if wealth <= 35.0 else "moyen")
	lines.append("Richesse %d (quartier %s) · criminalité %d · pollution %d" % [int(wealth), standing, int(float(s.get("crime", 0.0))), int(float(s.get("pollution", 0.0)))])
	var states: PackedStringArray = PackedStringArray()
	for key in (s.get("states", {}) as Dictionary).keys():
		states.append("%s %d" % [UrbanGrowth.state_label(String(key)).to_lower(), int(s["states"][key])])
	if not states.is_empty():
		lines.append("États : " + ", ".join(states))
	if int(s.get("burning", 0)) > 0 or int(s.get("ruins", 0)) > 0:
		lines.append("Incidents : %d en feu, %d ruine(s)" % [int(s.get("burning", 0)), int(s.get("ruins", 0))])
	lines.append("Route reliée : %s · demande %+d · %d parcelle(s) libre(s)" % ["oui" if bool(s.get("road", false)) else "non", int(round(100.0 * float(s.get("demand", 0.0)))), int(s.get("potential", 0))])
	return "\n".join(lines)
