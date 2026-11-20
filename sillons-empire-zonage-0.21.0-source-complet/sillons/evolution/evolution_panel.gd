class_name EvolutionPanel
extends PanelContainer
var game
var page: String = "Politique"
var body: String = "val"
var actor_owner: int = 0
var content: VBoxContainer
var footer_actions: HBoxContainer
var feedback: Label
var _timer: float = 0.0
var target_composition: Dictionary = {}
var wave_size: int = 6
var summary: Label
func setup(p_game) -> void:
	game = p_game
	body = game.campaign.active
	actor_owner = game.player
	theme = MobileUI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 70
	offset_right = -70
	offset_top = 80
	offset_bottom = -30
	mouse_filter = Control.MOUSE_FILTER_STOP
	var layout := VBoxContainer.new()
	add_child(layout)
	var bar := HBoxContainer.new()
	layout.add_child(bar)
	var title := Label.new()
	title.text = "CONSEIL IMPÉRIAL"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var close: Button = _button(bar, "Fermer", func(): hide())
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size.x = 140
	var tabs := HBoxContainer.new()
	layout.add_child(tabs)
	for label in ["Politique", "Diplomatie", "Production", "Aménagement", "Routes"]:
		_button(tabs, label, func(): page = label; rebuild())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	footer_actions = HBoxContainer.new()
	layout.add_child(footer_actions)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(feedback)
	hide()
func _button(parent: Node, caption: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size.y = 48
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(action)
	parent.add_child(b)
	return b
func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(label)
	return label
func open() -> void:
	body = game.campaign.active
	actor_owner = game.player
	show()
	move_to_front()
	rebuild()
func _result(result: Dictionary) -> void:
	feedback.text = "Ordre appliqué." if bool(result.get("ok", false)) else String(result.get("reason", "Ordre refusé"))
	rebuild()
func _policy(field: String, value: float) -> void:
	_result(game.campaign.issue_evolution({"t": "policy", "team": game.player, "body": body, "field": field, "value": value}))
func _answer(answer: String) -> void:
	_result(game.campaign.issue_evolution({"t": "crisis", "team": game.player, "body": body, "answer": answer}))
func _treaty(kind: String) -> void:
	_result(game.campaign.issue_evolution({"t": "diplomacy", "team": game.player, "target": actor_owner, "body": body, "kind": kind}))
func rebuild() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	summary = null
	for child in footer_actions.get_children(): footer_actions.remove_child(child); child.queue_free()
	var c: StarCampaign = game.campaign
	var chooser := OptionButton.new()
	chooser.custom_minimum_size.y = 48
	content.add_child(chooser)
	var choices: Array = []
	var ids: Array = c.planets.colonies.keys()
	ids.sort()
	for id in ids:
		var candidate: Dictionary = c.planets.colonies[id]
		if not c.system_known(game.player, c._system_of(String(candidate["body"]))): continue
		choices.append(id)
		chooser.add_item(String(c.info(String(candidate["body"])).get("label", candidate["body"])) + " · " + String(c.factions.records[int(candidate["team"])]["name"]))
		if String(candidate["body"]) == body and int(candidate["team"]) == actor_owner: chooser.select(choices.size() - 1)
	chooser.item_selected.connect(func(index: int):
		var chosen: Dictionary = c.planets.colonies[choices[index]]
		body = String(chosen["body"])
		actor_owner = int(chosen["team"])
		rebuild())
	var p: Dictionary = c.planets.colony(actor_owner, body)
	if page == "Production": _production(); return
	if page == "Routes": _roads(p); return
	if page == "Aménagement": _civic(p); return
	if p.is_empty(): _label("Sélectionnez une administration dans la liste."); return
	PoliticalState.ensure(p)
	var ps: Dictionary = p["politics"]
	summary = _label("")
	_update_summary()
	if page == "Diplomatie":
		if actor_owner == game.player: _label("Votre administration. Les territoires indépendants connus apparaissent dans la liste."); return
		_label("Les offres engagent des ressources et un délai. Une trêve arrête les tirs ; elle n'autorise aucun débarquement militaire. L'armée régulière garde sa faction.")
		for pair in [["aid", "Aide · 100 vivres, livraison différée, +30 confiance"], ["autonomy", "Autonomie · bien-être 45, confiance 25, maintien 60 s"], ["federation", "Fédération · gouvernement indépendant, maintien 60 s"], ["vote", "Vote de réunification · bien-être 60, confiance 50, maintien 90 s"], ["protection", "Protection · menace extérieure et 3 défenseurs présents"], ["occupation", "Occupation · orbite libre, commandement adverse neutralisé, 3 soldats pendant 30 s"]]:
			_button(content, String(pair[1]), _treaty.bind(String(pair[0])))
		for t in c.treaties:
			if String(t["body"]) == body: _label("%s : %s · %d / %d s" % [t["kind"], t["state"], int(t["progress"]) / 10, int(t["duration"]) / 10])
		return
	if actor_owner != game.player: _label("La politique est décidée par cette administration indépendante."); return
	for data in [["tax", "Fiscalité", [0.1, 0.2, 0.4, 0.6]], ["autonomy", "Autonomie", [0.0, 0.4, 0.7, 1.0]], ["budget", "Budget des services", [0.0, 0.5, 1.0, 1.5]], ["mobilization", "Mobilisation", [0.0, 0.2, 0.5, 0.8]]]:
		_label(String(data[1]) + " · actuellement %d %%" % int(float(ps[data[0]]) * 100.0))
		var row := HBoxContainer.new()
		content.add_child(row)
		for value in data[2]: _button(row, "%d %%" % int(float(value) * 100.0), _policy.bind(String(data[0]), float(value)))
	_label("Le budget des services est payé sur la trésorerie. L'autonomie réduit la part de surplus reversée à l'empire. La mobilisation retire des travailleurs civils. Les politiques agissent progressivement.")
	if String(ps["stage"]) in ["demands", "agreement"]:
		_label("REVENDICATIONS : " + str(ps["terms"]) + " · échéance %d s" % maxi(0, (int(ps["deadline"]) - c.tick) / 10))
		for answer in ["accept", "counter", "refuse"]: _button(content, {"accept": "Accepter l'accord", "counter": "Contre-proposer : autonomie 60 %, fiscalité 15 %, 5 vivres", "refuse": "Refuser · échéance ramenée à 10 s"}[answer], _answer.bind(answer))
func _update_summary() -> void:
	if summary == null: return
	var c: StarCampaign = game.campaign
	var p: Dictionary = c.planets.colony(actor_owner, body)
	if p.is_empty(): summary.text = "L'administration a changé. Rouvrez le conseil."; return
	var ps: Dictionary = p["politics"]
	var text: String = "Bien-être %d / 100 · Loyauté %d / 100 · rendement ×%.2f
Situation : %s · Confiance diplomatique %d / 100" % [ps["wellbeing"], ps["loyalty"], PoliticalState.productivity(p), ps["stage"], int(ps.get("trust", 0))]
	for name in (ps["factors"] as Dictionary):
		text += "
%s : %d %% · poids %.1f" % [name, float(ps["factors"][name]["value"]) * 100, float(ps["factors"][name]["weight"])]
	for id in (ps["districts"] as Dictionary):
		var district: Dictionary = ps["districts"][id]
		text += "\nDistrict %d · %.0f habitants · bien-être %.0f / 100%s" % [id, district["population"], district["wellbeing"], " · réseau coupé" if not bool(district["connected"]) else ""]
	summary.text = text
func _process(delta: float) -> void:
	if not visible: return
	_timer += delta
	if _timer >= 0.5: _timer = 0.0; _update_summary()
func _production() -> void:
	var w: SimWorld = game.world
	_label("Sélectionnez un producteur sur le terrain pour son drapeau individuel. Le drapeau commun s'applique aux producteurs militaires achevés ; les ouvriers restent dans l'économie.")
	_button(content, "Drapeau commun · choisir au sol ou une armée amie", func(): hide(); game.begin_rally(true))
	var available: Dictionary = {}
	for b in w.team_buildings(game.player, "", true):
		for kind in Rules.BUILDINGS[b.type].get("trains", []):
			if Rules.unit_has(String(kind), "military") and int(Rules.UNITS[kind]["age"]) <= w.teams[game.player].age: available[kind] = true
	if target_composition.is_empty() and not available.is_empty(): target_composition[available.keys()[0]] = 12
	for kind in available:
		var row := HBoxContainer.new()
		content.add_child(row)
		var label := Label.new()
		label.text = String(Rules.UNITS[kind]["label"]) + " · " + Rules.cost_text(Rules.UNITS[kind]["cost"])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var amount := SpinBox.new()
		amount.min_value = 0
		amount.max_value = 60
		amount.step = 1
		amount.value = int(target_composition.get(kind, 0))
		amount.custom_minimum_size = Vector2(140, 48)
		amount.value_changed.connect(func(value: float): target_composition[kind] = int(value))
		row.add_child(amount)
	_label("Taille d'une vague : les soldats restent au point de préparation jusqu'au seuil.")
	var wave := SpinBox.new()
	wave.min_value = 1
	wave.max_value = 60
	wave.value = wave_size
	wave.custom_minimum_size.y = 48
	wave.value_changed.connect(func(value: float): wave_size = int(value))
	content.add_child(wave)
	_button(content, "Créer le plan de renfort", func():
		var producers: Array = []
		var composition: Dictionary = {}
		var destination := Vector2.ZERO
		for kind in target_composition:
			if int(target_composition[kind]) > 0 and available.has(kind): composition[kind] = int(target_composition[kind])
		for b in w.team_buildings(game.player, "", true):
			for kind in Rules.BUILDINGS[b.type].get("trains", []):
				if composition.has(kind): producers.append(b.id); destination = b.rally; break
		_result(w.issue({"t": "army_plan", "team": game.player, "buildings": producers, "composition": composition, "wave": wave_size, "pos": [destination.x, destination.y]})))

	for plan in w.army_plans.values():
		_label("Plan #%d · %s · %s" % [plan["id"], plan["target"], plan["status"]])
		for destination in StarCampaign.SECTORS:
			if destination == game.campaign.active or not game.campaign.is_unlocked(game.player, destination): continue
			_button(content, "Acheminer ce plan vers " + String(game.campaign.info(destination)["label"]), func(): _result(game.campaign.issue_evolution({"t": "reinforcement_mission", "team": game.player, "plan": int(plan["id"]), "target": destination})))
		_button(content, "Suspendre / reprendre le plan #%d" % plan["id"], func(): _result(w.issue({"t": "plan_toggle", "team": game.player, "plan": int(plan["id"])})))
func _roads(p: Dictionary) -> void:
	if p.is_empty() or actor_owner != game.player: _label("Choisissez l'une de vos administrations."); return
	_label("Tracez une route sur l'atlas : maintenez le doigt depuis un district relié, glissez, puis validez le coût total. Le tracé entier est refusé si un segment est invalide.")
	var atlas := RoadAtlas.new()
	atlas.custom_minimum_size = Vector2(500, 170)
	atlas.setup(game.campaign, game.player, body)
	content.add_child(atlas)
	_button(footer_actions, "Valider le tracé", func(): _result(atlas.commit()))

func _civic(p: Dictionary) -> void:
	if p.is_empty() or actor_owner != game.player: _label("Choisissez votre administration."); return
	_label("Aménagez votre planète dès les premiers âges. Les constructions respectent l'âge local, les routes, le budget et les stocks. Les plans retenus et refus apparaissent ci-dessous.")
	for kind in ["R", "C", "I", "power", "water", "hospital", "fire", "police"]:
		var label: String = String(J13Rules.ZONE_LABELS.get(kind, J13Rules.SERVICE_LABELS.get(kind, kind)))
		var cost: Dictionary = J13Rules.ZONE_COST[kind] if J13Rules.ZONES.has(kind) else J13Rules.FACILITIES[kind]["cost"]
		_button(content, "+ " + label + " · " + Rules.cost_text(cost), func(): _result(game.campaign.issue_evolution({"t": "civic", "team": game.player, "body": body, "kind": kind})))
	_label("Population civile %d · logements %d · emplois %d · crédits %.0f · réserve locale %.0f" % [p["pop"], int(p["stats"].get("housing", 0)), int(p["stats"].get("jobs", 0)), game.campaign.planets.credits(actor_owner), float(p["reserve"])])
	for recipe in J13Rules.RECIPES:
		_button(content, "Industrie : " + String(J13Rules.RECIPES[recipe]["label"]), func(): _result(game.campaign.issue_evolution({"t": "civic", "team": game.player, "body": body, "kind": "I", "recipe": recipe})))
	for value in [100.0, 250.0, 500.0]:
		_button(content, "Plafond du gouverneur : %.0f crédits par cycle" % value, func(): _result(game.campaign.issue_evolution({"t": "governor_budget", "team": game.player, "body": body, "value": value})))
	_button(content, "Activer / suspendre le gouverneur (âge X local)", func(): _result(game.campaign.planets.set_governor(game.campaign, game.player, body, not bool(p["governor"]["enabled"]))))
