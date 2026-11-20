class_name CivPanel
extends PanelContainer
## 0.16 — Panneau « Civilisation » : voies, monuments, héros, améliorations et pouvoirs de commandement.
## La vue ne modifie rien elle-même : chaque bouton envoie une commande validée par la simulation.
var game
var content: VBoxContainer
var feedback: Label
var _timer: float = 0.0
var _signature: String = ""

func setup(p_game) -> void:
	game = p_game
	name = "CivPanel"
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
	title.text = "ÉVOLUTION DE LA CIVILISATION"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var close: Button = _button(bar, "Fermer", func(): hide())
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size.x = 140
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(feedback)
	hide()

func open() -> void:
	show()
	move_to_front()
	_signature = ""
	rebuild()

func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer >= 0.5:
		_timer = 0.0
		rebuild()

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size.y = 48
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _label(text: String, size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	content.add_child(label)
	return label

func _issue(cmd: Dictionary) -> void:
	var result: Dictionary = game.world.issue(cmd)
	feedback.text = "Ordre appliqué." if bool(result.get("ok", false)) else String(result.get("reason", "Ordre refusé"))
	_signature = ""
	rebuild()

func _target_power(power: String) -> void:
	game.civ_power_key = power
	game.mode = "civ_power"
	game.hud.set_hint("%s : touchez la zone visée sur la carte." % String((CivRules.POWERS[power] as Dictionary)["label"]))
	hide()

func _place(kind: String) -> void:
	hide()
	game.start_placement(kind)

func rebuild() -> void:
	var w: SimWorld = game.world
	if w == null or not CivEvolution.enabled(w):
		return
	var team: int = game.player
	var civ: Dictionary = CivEvolution.state(w, team)
	var t: SimWorld.Team = w.teams[team]
	var signature: String = "%d:%d:%d:%d" % [int(civ["v"]), t.age, floori(float(civ["points"])), w.tick / 10]
	for job in civ["jobs"]:
		signature += ":%d" % int(float(job["remaining"]))
	if signature == _signature:
		return
	_signature = signature
	for child in content.get_children():
		child.queue_free()
	_label("Âge %s · points de commandement : %d (gagnés en détruisant des forces ennemies)" % [J13Rules.roman(t.age), floori(float(civ["points"]))], 16)
	# Voies
	_label("VOIES", 18)
	var pending: String = CivEvolution.pending_epoch(w, team)
	if not pending.is_empty():
		_label("Choix à faire — %s (définitif) :" % String(CivRules.EPOCH_LABEL[pending]))
		for voie in ["marchande", "militaire", "savante"]:
			var entry: Dictionary = (CivRules.VOIES[pending] as Dictionary)[voie] as Dictionary
			_button(content, "%s — %s" % [String(CivRules.VOIE_LABEL[voie]), String(entry["text"])], _issue.bind({"t": "civ_voie", "team": team, "epoch": pending, "voie": voie}))
	for epoch in CivRules.EPOCHS:
		if (civ["voies"] as Dictionary).has(epoch):
			var voie: String = String(civ["voies"][epoch])
			_label("√ %s : %s — %s" % [String(CivRules.EPOCH_LABEL[epoch]).get_slice(" (", 0), String(CivRules.VOIE_LABEL[voie]), String(((CivRules.VOIES[epoch] as Dictionary)[voie] as Dictionary)["text"])])
		elif epoch != pending:
			_label("· %s : choix à l'âge %s" % [String(CivRules.EPOCH_LABEL[epoch]).get_slice(" (", 0), J13Rules.roman(int(CivRules.EPOCH_AGE[epoch]))])
	# Monuments
	_label("MONUMENTS D'ÂGE", 18)
	var next: Array = CivRules.monuments_for(t.age + 1)
	if next.is_empty():
		_label("Âge maximal atteint.")
	else:
		_label("Pour passer à l'âge %s, bâtissez UN de ces deux monuments (son bonus dure tant qu'il est debout) :" % J13Rules.roman(t.age + 1))
		for kind in next:
			var key: String = String(kind)
			var lack: String = CivEvolution.build_lack(w, team, key)
			var started: bool = not w.team_buildings(team, key).is_empty()
			var line: String = "%s — %s · %s" % [String((Rules.BUILDINGS[key] as Dictionary)["label"]).get_slice(" (", 0), String((CivRules.MONUMENTS[key] as Dictionary)["text"]), Rules.cost_text(Rules.BUILDINGS[key]["cost"])]
			if started:
				_label("→ " + line + " — en construction")
			elif lack.is_empty():
				_button(content, "Placer : " + line, _place.bind(key))
			else:
				_label("· " + line + " — " + lack)
	for key in (civ["monuments"] as Dictionary).keys():
		if int(civ["monuments"][key]) > 0:
			_label("√ %s : %s" % [String((Rules.BUILDINGS[key] as Dictionary)["label"]).get_slice(" (", 0), String((CivRules.MONUMENTS[key] as Dictionary)["text"])])
	# Héros
	_label("HÉROS", 18)
	for kind in ["heros_antique", "heros_industriel", "heros_spatial"]:
		var record: Dictionary = (civ["heroes"] as Dictionary).get(kind, {}) as Dictionary
		var status: String = String(record.get("state", "none"))
		var text: String = {"alive": "en service", "queued": "en formation au centre", "dead": "tombé", "none": "à recruter au centre de commandement"}.get(status, status)
		if status == "dead":
			var wait: float = CivEvolution.recall_wait(w, team, kind)
			text += " — rappel " + ("possible au centre" if wait <= 0.0 else "dans %d s" % ceili(wait))
		if t.age < int(Rules.UNITS[kind]["age"]):
			text = "âge %s requis" % J13Rules.roman(int(Rules.UNITS[kind]["age"]))
		_label("%s : %s · aura : +15 %% attaque, −15 %% dégâts subis pour les troupes proches" % [CivEvolution.hero_name(w, team, kind), text])
	# Améliorations
	_label("AMÉLIORATIONS (forge, centre, usine, aérodrome)", 18)
	for job in civ["jobs"]:
		_label("… %s niveau %d — %d s" % [String((CivRules.UPGRADES[String(job["key"])] as Dictionary)["label"]), int(job["level"]), ceili(float(job["remaining"]))])
	for key in CivRules.UPGRADES.keys():
		var definition: Dictionary = CivRules.UPGRADES[key] as Dictionary
		var level: int = int((civ["upgrades"] as Dictionary).get(key, 0))
		var next_text: String = "complet" if level >= 3 else "niveau %d à l'âge %s, au bâtiment : %s" % [level + 1, J13Rules.roman(int((definition["ages"] as Array)[level])), String((Rules.BUILDINGS[String(definition["building"])] as Dictionary)["label"])]
		_label("%s : %d/3 — %s" % [String(definition["label"]), level, next_text], 13)
	# Pouvoirs
	_label("POUVOIRS DE COMMANDEMENT", 18)
	for power in CivRules.POWER_ORDER:
		var definition: Dictionary = CivRules.POWERS[power] as Dictionary
		var title: String = "Rang %d · %s — %s" % [int(definition["tier"]), String(definition["label"]), String(definition["text"])]
		if (civ["powers"] as Dictionary).has(power):
			var wait: float = CivEvolution.power_wait(w, team, power)
			if wait > 0.0:
				_label("%s — recharge %d s" % [title, ceili(wait)])
			else:
				_button(content, "Utiliser : " + title, _target_power.bind(power))
		else:
			var status: Dictionary = CivEvolution.unlock_status(w, team, power)
			if bool(status["ok"]):
				_button(content, "Débloquer (%d points) : %s" % [int(definition["unlock"]), title], _issue.bind({"t": "civ_unlock", "team": team, "power": power}))
			else:
				_label("%s — verrouillé : %s" % [title, String(status["reason"])], 13)
	# Journal
	var log: Array = civ["log"] as Array
	if not log.is_empty():
		_label("JOURNAL", 18)
		for i in range(maxi(0, log.size() - 6), log.size()):
			_label("· " + String((log[i] as Dictionary)["text"]), 12)
