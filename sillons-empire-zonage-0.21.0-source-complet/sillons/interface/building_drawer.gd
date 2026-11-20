class_name BuildingDrawer
extends PanelContainer
var game
var building_id: int = -1
var active_tab: String = "Unités"
var folded: bool = false
var header: Label
var status: Label
var art: TextureRect
var health: ProgressBar
var queue_label: Label
var grid: GridContainer
var scroll: ScrollContainer
var tabs: HBoxContainer
var fold_button: Button
var action_bar: Container
var queue_row: HBoxContainer            # 0.17 : file visible, chaque élément annulable
var batch: int = 1                      # 0.17 : ×1 / ×5
var _held_card: DataCard = null
var _held_since: float = -1.0
var _held_last: float = 0.0
var _queue_signature: String = ""
var _demolish_armed: float = -10.0
var body_box: VBoxContainer
var cards: Array = []
var portrait: bool = false        # 0.18 : en portrait, la fiche devient un panneau du bas, pleine largeur
var _clock: float = 0.0
var _signature: String = ""
func setup(p_game) -> void:
	game = p_game
	name = "BuildingDrawer"
	anchor_left = 1.0; anchor_right = 1.0; anchor_bottom = 1.0
	offset_left = -484; offset_right = -12; offset_top = 84; offset_bottom = -14
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = MobileUI.theme()
	var layout := VBoxContainer.new(); layout.add_theme_constant_override("separation", 8); add_child(layout)
	var row := HBoxContainer.new(); layout.add_child(row)
	art = TextureRect.new(); art.custom_minimum_size = Vector2(64,64)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(art)
	var labels := VBoxContainer.new(); labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(labels)
	header = Label.new(); header.add_theme_font_size_override("font_size", 20); labels.add_child(header)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.add_theme_font_size_override("font_size", 13); labels.add_child(status)
	fold_button = MobileUI.button("−", toggle_fold, 48); fold_button.custom_minimum_size.x = 48; fold_button.size_flags_horizontal = Control.SIZE_SHRINK_END; row.add_child(fold_button)
	var close: Button = MobileUI.button("×", func(): game.clear_selection(); close_drawer(),48)
	close.custom_minimum_size.x = 48; close.size_flags_horizontal = Control.SIZE_SHRINK_END; row.add_child(close)
	body_box = VBoxContainer.new(); body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL; layout.add_child(body_box)
	health = ProgressBar.new(); health.show_percentage = false; health.custom_minimum_size.y = 5; body_box.add_child(health)
	queue_label = Label.new(); queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; queue_label.add_theme_font_size_override("font_size", 13); body_box.add_child(queue_label)
	queue_row = HBoxContainer.new(); queue_row.add_theme_constant_override("separation", 5); body_box.add_child(queue_row)
	tabs = HBoxContainer.new(); body_box.add_child(tabs)
	for tab in ["Unités", "Bâtiments", "Évolutions"]:
		var button: Button = MobileUI.button(tab, _switch_tab.bind(tab),48); button.toggle_mode = true; button.set_meta("tab", tab); tabs.add_child(button)
	scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body_box.add_child(scroll)
	grid = GridContainer.new(); grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(grid)
	var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 6); flow.add_theme_constant_override("v_separation", 6)
	action_bar = flow; body_box.add_child(action_bar)
	hide()
func open_building(id: int) -> void:
	var b: SimWorld.Building = game.world.buildings.get(id) as SimWorld.Building
	if b == null or b.team != game.player: close_drawer(); return
	var changed: bool = id != building_id
	building_id = id
	game.hud.build_panel.hide(); game.hud.squad_panel.hide()
	if changed:
		active_tab = "Unités" if not (Rules.BUILDINGS[b.type].get("trains", []) as Array).is_empty() else "Bâtiments"
		folded = false; fold_button.text = "−"; body_box.show(); apply_layout()
	_signature = ""
	refresh()
	UIMotion.reveal(self)
func close_drawer() -> void:
	building_id = -1
	UIMotion.conceal(self)
func toggle_fold() -> void:
	folded = not folded
	body_box.visible = not folded
	fold_button.text = "+" if folded else "−"
	apply_layout()
func apply_layout() -> void:
	if portrait:
		anchor_left = 0.0; anchor_right = 1.0; anchor_top = 1.0 if folded else 0.4; anchor_bottom = 1.0
		offset_left = 8; offset_right = -8; offset_top = -96.0 if folded else 0.0; offset_bottom = -8
		grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		anchor_left = 1.0; anchor_right = 1.0; anchor_top = 0.0; anchor_bottom = 0.0 if folded else 1.0
		offset_left = -484; offset_right = -12; offset_top = 84; offset_bottom = 170.0 if folded else -14.0
		grow_vertical = Control.GROW_DIRECTION_END
	remove_meta("layout_base")
func _switch_tab(tab: String) -> void:
	active_tab = tab; _signature = ""; refresh()
func _process(delta: float) -> void:
	if not visible or building_id < 0: return
	_clock += delta
	if _clock >= 0.25: _clock = 0; refresh()
	# Appui maintenu sur une carte d'unité : formation en continu (une recrue toutes les 0,4 s).
	if _held_card != null and _held_since >= 0.0:
		var now: float = float(Time.get_ticks_msec()) / 1000.0
		if now - _held_since >= 0.5 and now - _held_last >= 0.4:
			_held_last = now
			_train(_held_card.key, 1)
func _hold_start(card: DataCard) -> void:
	_held_card = card
	_held_since = float(Time.get_ticks_msec()) / 1000.0
	_held_last = _held_since
func _hold_end(card: DataCard) -> void:
	var held_long: bool = _held_since >= 0.0 and float(Time.get_ticks_msec()) / 1000.0 - _held_since >= 0.5
	_held_card = null
	_held_since = -1.0
	if held_long:
		card.set_meta("skip_press", true)
func _card_pressed(card: DataCard) -> void:
	if bool(card.get_meta("skip_press", false)):
		card.set_meta("skip_press", false)
		return
	_train(card.key, batch)
func _train(kind: String, count: int) -> int:
	## Forme `count` unités (chaque ordre validé par la simulation ; arrêt au premier refus).
	var b: SimWorld.Building = game.world.buildings.get(building_id) as SimWorld.Building
	if b == null: return 0
	var done: int = 0
	var reason: String = ""
	for i in count:
		var r: Dictionary = game.world.issue({"t": "train", "team": game.player, "building": b.id, "unit": kind})
		if not bool(r.get("ok", false)):
			reason = String(r.get("reason", "refus"))
			break
		done += 1
	if count > 1 or reason != "":
		game.hud.toast("%d %s en file%s" % [done, String(Rules.UNITS[kind]["label"]).to_lower(), (" · " + reason) if reason != "" else ""], AgeTheme.c("success") if reason == "" else AgeTheme.c("warning"))
	_queue_signature = ""
	refresh()
	return done
func _refresh_queue(b: SimWorld.Building) -> void:
	var signature: String = var_to_str(b.queue) + str(int(b.prod_timer))
	if signature == _queue_signature: return
	_queue_signature = signature
	UIMotion.clear(queue_row)
	var age: int = game.world.teams[b.team].age
	for i in b.queue.size():
		var kind: String = String(b.queue[i])
		var tile := TouchTile.new()
		tile.custom_minimum_size = Vector2(52, 52)
		tile.icon = Portraits.unit(kind, age)
		tile.badge = "×"
		tile.gauge = clampf(b.prod_timer / maxf(0.1, float(Rules.UNITS[kind]["time"])), 0.0, 1.0) if i == 0 else -1.0
		tile.tooltip_text = "%s — toucher pour annuler (remboursé : %s)" % [String(Rules.UNITS[kind]["label"]), Rules.cost_text(game.world.scaled_cost(Rules.UNITS[kind]["cost"]))]
		tile.tapped.connect(_cancel_at.bind(i))
		queue_row.add_child(tile)
func _cancel_at(index: int) -> void:
	_outcome(game.world.issue({"t": "cancel_train_at", "team": game.player, "building": building_id, "index": index}))
	_queue_signature = ""
func _card(title: String, texture: Texture2D, text: String, key: String, action: Callable) -> void:
	var card := DataCard.new(); card.key = key; card.setup(title, texture, text, action); grid.add_child(card); cards.append(card)
func _unit_card(title: String, texture: Texture2D, text: String, key: String) -> void:
	var card := DataCard.new(); card.key = key
	card.setup(title, texture, text, Callable())
	card.pressed.connect(_card_pressed.bind(card))
	card.button_down.connect(_hold_start.bind(card))
	card.button_up.connect(_hold_end.bind(card))
	grid.add_child(card); cards.append(card)
func _outcome(result: Dictionary) -> void:
	game.hud.toast("Ordre accepté" if bool(result.get("ok", false)) else String(result.get("reason", "Refus")))
	_signature = ""; refresh()
func refresh() -> void:
	var w: SimWorld = game.world
	var b: SimWorld.Building = w.buildings.get(building_id) as SimWorld.Building
	if b == null or b.team != game.player: close_drawer(); return
	var age: int = w.teams[b.team].age
	header.text = String(Rules.BUILDINGS[b.type]["label"])
	status.text = "Âge %s · bâtiment niv. %d · %d / %d PV" % [J13Rules.roman(age), b.tier, int(b.hp), int(b.max_hp)]
	art.texture = Portraits.building(b.type, age)
	health.max_value = b.max_hp; health.value = b.hp
	var queued := PackedStringArray()
	for kind in b.queue: queued.append(String(Rules.UNITS[kind]["label"]))
	queue_label.text = "File : " + (", ".join(queued) if not queued.is_empty() else "aucune production")
	if not b.complete: queue_label.text = "Construction · %d %%" % int(b.progress * 100)
	if not b.prod_blocked.is_empty(): queue_label.text += "\n" + b.prod_blocked
	if b.repeat_unit != "": queue_label.text += "\nProduction répétée : " + String(Rules.UNITS[b.repeat_unit]["label"])
	if b.rally_node != -1: queue_label.text += "\nNouveaux ouvriers : récolte directe"
	var inside: int = UnitCommands.occupants(w, b).size()
	if UnitCommands.capacity(b) > 0 and b.complete: queue_label.text += "\nGarnison : %d / %d" % [inside, UnitCommands.capacity(b)]
	if UrbanRules.is_urban(b.type) and b.complete:
		queue_label.text = UrbanCity.zone_summary(b) if bool(b.city.get("ready", false)) or not UrbanRules.is_zone(b.type) else "Mise en service…"
		for row in UrbanCity.zone_indicators(b): queue_label.text += "\n%s : %s" % [String(row[0]), String(row[2])]
		if float(b.city.get("burning", 0.0)) > 0.0: queue_label.text += "\nEN FEU — " + ("les pompiers interviennent" if bool(b.city.get("fire", false)) else "aucun pompier à portée")
	elif b.type == "ferme" and bool(b.city.get("retired", false)):
		queue_label.text = "Ferme arrêtée : la ville a remplacé l'agriculture (recherche Électricité). Démolissez-la pour libérer la place."
	_refresh_queue(b)
	var civ_on: bool = CivEvolution.enabled(w)
	if civ_on:
		for job in CivEvolution.state(w, b.team)["jobs"]:
			if int(job["building"]) == b.id and String(job.get("sector", "")) == String(w.rules.get("sector", "")):
				queue_label.text += "\nAmélioration : %s niv. %d · %d s" % [String((CivRules.UPGRADES[String(job["key"])] as Dictionary)["label"]), int(job["level"]), ceili(float(job["remaining"]))]
	var signature: String = "%d:%d:%s:%d:%s:%s:%d:%d:%s:%d:%d:%d:%d:%s" % [b.id, age, active_tab, b.tier, var_to_str(b.unit_evolutions), AgeProgression.job_signature(b), int(CivEvolution.state(w, b.team)["v"]) if civ_on else 0, batch, b.repeat_unit, b.rally_node, inside, int(b.complete), int(b.city.get("level", 0)), str(UrbanCity.active(w, b.team))]
	if signature != _signature:
		_signature = signature
		UIMotion.clear(grid); UIMotion.clear(action_bar); cards.clear()
		for button in tabs.get_children(): button.button_pressed = String(button.get_meta("tab")) == active_tab
		if active_tab == "Unités":
			for kind in Rules.BUILDINGS[b.type].get("trains", []):
				if not CivEvolution.visible_unit(w, game.player, String(kind)): continue
				var definition: Dictionary = Rules.UNITS[kind]
				_unit_card(CivEvolution.hero_name(w, game.player, String(kind)) + " (héros)" if CivRules.HEROES.has(kind) else String(definition["label"]), Portraits.unit(String(kind), age), Rules.cost_text(definition["cost"]) + " · %d s" % int(definition["time"]), String(kind))
			if cards.is_empty():
				var empty := Label.new(); empty.text = "Ce bâtiment ne produit pas d'unités."; empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; grid.add_child(empty)
			action_bar.add_child(_small("Drapeau", func(): hide(); game.begin_rally(false)))
			action_bar.add_child(_small("Annuler dernier", func(): _outcome(w.issue({"t":"cancel_train","team":game.player,"building":b.id}))))
			var trains: Array = Rules.BUILDINGS[b.type].get("trains", []) as Array
			if not trains.is_empty():
				var batch_button: Button = _small("×%d" % batch, func(): batch = 5 if batch == 1 else 1; _signature = ""; refresh())
				batch_button.tooltip_text = "Former 1 ou 5 unités par toucher (appui maintenu : en continu)"
				batch_button.theme_type_variation = "ToggleOnButton" if batch == 5 else ""
				action_bar.add_child(batch_button)
				var repeat_caption: String = "Répéter : " + (String(Rules.UNITS[b.repeat_unit]["label"]) if b.repeat_unit != "" else "non")
				var repeat_button: Button = _small(repeat_caption, _cycle_repeat)
				repeat_button.tooltip_text = "Production répétée : la file est relancée tant que population et ressources le permettent"
				repeat_button.theme_type_variation = "ToggleOnButton" if b.repeat_unit != "" else ""
				action_bar.add_child(repeat_button)
			if trains.has("ouvrier"):
				var rally_res: Button = _small("Ouvriers → ressource" if b.rally_node == -1 else "Ralliement ressource ×", _toggle_rally_resource)
				rally_res.tooltip_text = "Les nouveaux ouvriers vont directement récolter la ressource touchée"
				action_bar.add_child(rally_res)
		elif active_tab == "Bâtiments":
			for kind in Rules.BUILDINGS:
				if kind == "comptoir": continue
				if not CivEvolution.visible_building(w, game.player, String(kind)): continue
				var definition: Dictionary = Rules.BUILDINGS[kind]
				if CivRules.MONUMENTS.has(kind):
					_card(String(definition["label"]).get_slice(" (", 0), Portraits.building(String(kind), age + 1), String((CivRules.MONUMENTS[kind] as Dictionary)["text"]) + " · " + Rules.cost_text(definition["cost"]) + " · passe à l'âge " + J13Rules.roman(int(definition["monument"])), String(kind), func(): hide(); game.start_placement(String(kind)))
					continue
				_card(String(definition["label"]), Portraits.building(String(kind), maxi(age,int(definition["age"]))), Rules.cost_text(definition["cost"]) + " · âge " + J13Rules.roman(int(definition["age"])), String(kind), func(): hide(); game.start_placement(String(kind)))
		else:
			var next_level: int = b.tier + 1
			if next_level <= 3: _card("Améliorer le bâtiment", Portraits.building(b.type,age), Rules.cost_text(AgeProgression.building_cost(b.type,next_level)), "building", func(): _outcome(w.issue({"t":"upgrade_building","team":game.player,"building":b.id})))
			for kind in Rules.BUILDINGS[b.type].get("trains", []):
				var level: int = int(b.unit_evolutions.get(kind,1))
				if level < 3: _card(String(Rules.UNITS[kind]["label"]) + " · niv.%d" % (level+1),Portraits.unit(String(kind),age),Rules.cost_text(AgeProgression.troop_cost(String(kind),level+1)),"troop:"+String(kind),func(): _outcome(w.issue({"t":"upgrade_troop","team":game.player,"building":b.id,"unit":kind})))
			if civ_on:
				for key in CivRules.UPGRADES:
					var up: Dictionary = CivRules.UPGRADES[key]
					if String(up["building"]) != b.type: continue
					var lvl: int = int((CivEvolution.state(w, b.team)["upgrades"] as Dictionary).get(key, 0))
					if lvl >= 3: continue
					_card(String(up["label"]) + " · niv.%d" % (lvl + 1), Portraits.building(b.type, age), Rules.cost_text(CivRules.upgrade_cost(String(key), lvl + 1, CivEvolution.mod(w, b.team, "upgrade_discount"))), "civ:" + String(key), func(): _outcome(w.issue({"t": "civ_upgrade", "team": game.player, "building": b.id, "key": key})))
			if civ_on and b.type == "centre": action_bar.add_child(MobileUI.button("Civilisation", func(): if game.civ_panel != null: game.civ_panel.open(), 48))
			for key in Rules.TECHNOLOGIES:
				var tech: Dictionary = Rules.TECHNOLOGIES[key]
				if String(tech["building"]) == b.type and UrbanCity.tech_lack(w, String(key)) == "": _card(String(tech["label"]),Portraits.building(b.type,age),Rules.cost_text(tech["cost"]),"tech:"+String(key),func(): _outcome(w.issue({"t":"technology","team":game.player,"building":b.id,"key":key})))
			if b.type == "centre": action_bar.add_child(MobileUI.button("Passage d'âge", game.hud._toggle_age_panel,48))
			if b.type == "silo": action_bar.add_child(MobileUI.button("Cibler un missile", func(): hide(); game.mode="missile"; game.hud.set_hint("Touchez une cible visible."),48))
		if inside > 0:
			action_bar.add_child(_small("Sortir la garnison (%d)" % inside, func(): _outcome(w.issue({"t": "ungarrison", "team": game.player, "building": b.id}))))
		if UrbanRules.is_zone(b.type) and b.complete:
			var zone_level: int = int(b.city.get("level", 1))
			if zone_level < UrbanGrowth.level_cap(w, b.team, b):
				var upgrade: Button = _small("Améliorer : niveau %s (%s)" % [UrbanRules.roman(zone_level + 1), Rules.cost_text(UrbanCity.upgrade_cost(w, b))], func(): _outcome(w.issue({"t": "urban_upgrade", "team": game.player, "building": b.id})))
				upgrade.tooltip_text = "Passe au niveau %s sans attendre. Sinon le bâtiment monte seul quand la demande, la richesse, les services et la route le permettent." % UrbanRules.level_name(b.type, zone_level + 1)
				upgrade.set_meta("urban_upgrade", true)
				action_bar.add_child(upgrade)
			# 0.19 : quartier historique — le bâtiment garde son architecture quand il grandit ou change d'âge.
			var historic: bool = bool(b.city.get("historic", false))
			var keep: Button = _small("Architecture conservée" if historic else "Conserver l'architecture", func(): _outcome(w.issue({"t": "zone_historic", "team": game.player, "building": b.id, "on": not historic})))
			keep.tooltip_text = "Quartier historique : ce bâtiment garde l'architecture de l'âge %s" % UrbanRules.roman(int(b.city.get("style_age", 1)))
			action_bar.add_child(keep)
		var demolish: Button = _small("Démolir", _demolish)
		demolish.tooltip_text = "Démolir : chantier inachevé remboursé à 50 %, bâtiment achevé sans remboursement (deux touchers pour confirmer)"
		action_bar.add_child(demolish)
	for card in cards:
		var reason: String = ""
		if active_tab == "Unités": reason = w.train_check(game.player,b,card.key)
		elif active_tab == "Bâtiments":
			var definition: Dictionary = Rules.BUILDINGS[card.key]
			if CivEvolution.civ_building(card.key): reason = CivEvolution.build_lack(w, game.player, card.key)
			if not reason.is_empty(): pass
			elif age < int(definition["age"]): reason = "Âge " + J13Rules.roman(int(definition["age"])) + " requis"
			elif not w._can_pay(game.player,w.scaled_cost(definition["cost"])): reason = "Ressources insuffisantes"
		elif card.key == "building": reason = String(AgeProgression.upgrade_status(w,game.player,b,"building")["reason"])
		elif card.key.begins_with("civ:"): reason = String(CivEvolution.upgrade_status(w,game.player,b,card.key.trim_prefix("civ:"))["reason"])
		elif card.key.begins_with("troop:"): reason = String(AgeProgression.upgrade_status(w,game.player,b,"troop",card.key.trim_prefix("troop:"))["reason"])
		elif card.key.begins_with("tech:"):
			var tech_key: String = card.key.trim_prefix("tech:")
			if w.teams[game.player].technologies.has(tech_key): reason="Déjà acquise"
			elif age < int(Rules.TECHNOLOGIES[tech_key]["age"]): reason="Âge insuffisant"
			elif not b.complete:reason="Bâtiment en construction"
			elif not w.teams[game.player].tech_research.is_empty():reason="Recherche en cours"
			elif not w._can_pay(game.player,w.scaled_cost(Rules.TECHNOLOGIES[tech_key]["cost"])):reason="Ressources insuffisantes"
			else:
				for prerequisite in Rules.TECHNOLOGIES[tech_key].get("requires",[]):
					if not w.teams[game.player].technologies.has(prerequisite):reason="Recherche préalable requise";break
		card.availability(reason)
		if active_tab == "Unités":
			var queued_count: int = b.queue.count(card.key)
			if not card.has_meta("title"): card.set_meta("title", card.caption.text)
			card.caption.text = String(card.get_meta("title")) + ("  ·  %d en file" % queued_count if queued_count > 0 else "")

func _small(caption: String, action: Callable) -> Button:
	var button: Button = MobileUI.button(caption, action, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size.x = 64
	if game.hud.feedback != null: game.hud.feedback.decorate(button)
	return button
func _cycle_repeat() -> void:
	var b: SimWorld.Building = game.world.buildings.get(building_id) as SimWorld.Building
	if b == null: return
	var options: Array = [""]
	for kind in Rules.BUILDINGS[b.type].get("trains", []):
		if not CivRules.HEROES.has(kind) and CivEvolution.visible_unit(game.world, game.player, String(kind)) and game.world.teams[b.team].age >= int(Rules.UNITS[kind]["age"]):
			options.append(String(kind))
	var next: String = String(options[(options.find(b.repeat_unit) + 1) % options.size()])
	_outcome(game.world.issue({"t": "repeat_train", "team": game.player, "building": b.id, "unit": next}))
func _toggle_rally_resource() -> void:
	var b: SimWorld.Building = game.world.buildings.get(building_id) as SimWorld.Building
	if b == null: return
	if b.rally_node != -1:
		_outcome(game.world.issue({"t": "rally_resource", "team": game.player, "building": b.id, "node": -1}))
		return
	game.mode = "rally_resource"
	game.rally_resource_building = b.id
	game.hud.set_hint("Touchez la ressource que récolteront les nouveaux ouvriers")
func _demolish() -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _demolish_armed > 3.0:
		_demolish_armed = now
		game.hud.toast("Toucher encore « Démolir » pour confirmer", AgeTheme.c("warning"))
		return
	_demolish_armed = -10.0
	var result: Dictionary = game.world.issue({"t": "demolish", "team": game.player, "building": building_id})
	if bool(result.get("ok", false)):
		game.hud.toast("Bâtiment démoli", AgeTheme.c("warning"))
		game.clear_selection()
	else:
		_outcome(result)
