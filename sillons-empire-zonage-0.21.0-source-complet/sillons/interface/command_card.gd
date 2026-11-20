class_name CommandCard
extends PanelContainer
## 0.17 — Carte de commandes contextuelle (coin bas droit, pouce droit). Elle change selon la sélection :
## troupes (Marcher, Assaut, Arrêt, Tenir, Patrouille, Repli, Garnison, puis Formation, Posture, Cible
## prioritaire, Suivre, Explorer, Rendre à l'armée), ouvriers (Bâtir, Réparer, Récolter, Dépôt, Automatique).
## Bouton « Enchaîner » : basculé d'un toucher, ou maintenu au pouce pendant qu'on touche la carte ; tant qu'il
## est actif, chaque ordre s'AJOUTE à la file (queue_append) au lieu de la remplacer. Toute action passe par
## une commande simulée ; un refus s'affiche près du doigt et ne change rien.

const HOLD := 0.35
const ARMY_1 := ["move", "amove", "stop", "hold", "patrol", "retreat", "garrison", "more"]
const ARMY_2 := ["formation", "stance", "priority", "follow", "explore", "release", "center", "back"]
const WORKERS := ["build", "repair", "gather", "return", "auto", "stop", "garrison", "center"]
const LABELS := {"move": "Marcher", "amove": "Assaut", "stop": "Arrêt", "hold": "Tenir", "patrol": "Patrouille", "retreat": "Repli",
	"garrison": "Garnison", "more": "Plus ›", "formation": "Formation", "stance": "Posture", "priority": "Cible", "follow": "Suivre",
	"explore": "Explorer", "release": "Rendre", "center": "Centrer", "back": "‹ Retour", "build": "Bâtir", "repair": "Réparer",
	"gather": "Récolter", "return": "Dépôt", "auto": "Auto"}
const TIPS := {"move": "Marcher jusqu'au point touché (sans combattre en route).", "amove": "Assaut : avancer et combattre tout ennemi rencontré.",
	"stop": "Arrêt : annule l'ordre et la file, l'unité reste sur place.", "hold": "Tenir la position : ne poursuit pas hors de portée.",
	"patrol": "Patrouille en boucle entre la position actuelle et le point touché (Enchaîner : plusieurs points).",
	"retreat": "Repli vers le centre ou le fort le plus proche, sans combattre.", "garrison": "Entrer en garnison dans le bâtiment allié touché (protégé, tire depuis l'intérieur).",
	"formation": "Formation de l'escouade : bloc, ligne, colonne, carré, dispersée.", "stance": "Posture : agressive, défensive, tenir, passive.",
	"priority": "Cible prioritaire : la plus proche, tireurs, cavaliers, fantassins, siège, véhicules, ouvriers, bâtiments.",
	"follow": "Suivre l'unité alliée touchée.", "explore": "Exploration automatique des zones inconnues les plus proches.",
	"release": "Rendre à l'armée ou à l'économie (fin du contrôle direct).", "center": "Centrer la caméra et la faire suivre la sélection (toucher encore pour arrêter).",
	"build": "Ouvrir la liste des bâtiments ; avec Enchaîner, chaque pose devient une étape des ouvriers sélectionnés.",
	"repair": "Réparer le bâtiment allié touché (coût : une part du prix).", "gather": "Récolter la ressource touchée (gisement ou ferme).",
	"return": "Déposer la charge au dépôt le plus proche.", "auto": "Rendre les ouvriers à l'économie automatique."}
const TARGETED := ["move", "amove", "patrol", "garrison", "follow", "repair", "gather"]

var game
var chain_btn: Button
var undo_btn: Button
var clear_btn: Button
var loop_btn: Button
var grid: GridContainer
var buttons: Dictionary = {}
var page: String = "army1"
var chain_active: bool = false
var _chain_was: bool = false
var _down_at: float = -1.0
var _signature: String = ""

func setup(p_game) -> void:
	game = p_game
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	chain_btn = _make("Enchaîner", Callable(), 150)
	chain_btn.set_meta("no_tip", true)
	chain_btn.tooltip_text = "Enchaîner : chaque ordre s'ajoute à la suite de la file (toucher pour basculer, ou maintenir au pouce)."
	chain_btn.button_down.connect(_chain_down)
	chain_btn.button_up.connect(_chain_up)
	top.add_child(chain_btn)
	undo_btn = _make("←", _undo, 48)
	undo_btn.tooltip_text = "Annuler la dernière étape de la file"
	top.add_child(undo_btn)
	clear_btn = _make("×", _clear, 48)
	clear_btn.tooltip_text = "Vider la file d'ordres"
	top.add_child(clear_btn)
	loop_btn = _make("∞", _loop, 48)
	loop_btn.tooltip_text = "File en boucle (patrouille sur plusieurs points)"
	top.add_child(loop_btn)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for i in 8:
		var b := _make("", Callable(), 80)
		b.custom_minimum_size = Vector2(80, 52)
		b.pressed.connect(_slot_pressed.bind(i))
		b.add_theme_font_size_override("font_size", 13)
		grid.add_child(b)

func _make(text: String, callback: Callable, width: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	if callback.is_valid():
		b.pressed.connect(callback)
	if game != null and game.hud != null and game.hud.feedback != null:
		game.hud.feedback.decorate(b)
	return b

# ---------------------------------------------------------------- contexte

func context() -> String:
	var units: Array = game.selected_units()
	if units.is_empty():
		return ""
	var workers: bool = true
	for u in units:
		workers = workers and Rules.unit_has(u.type, "worker")
	return "workers" if workers else "army"

func refresh() -> void:
	var ctx: String = context()
	visible = ctx != "" and game.mode != "place"
	if not visible:
		if chain_active and ctx == "":
			set_chain(false)
		return
	if ctx == "workers":
		page = "workers"
	elif page == "workers":
		page = "army1"
	var steps: int = 0
	var looped: bool = false
	for u in game.selected_units():
		steps = maxi(steps, u.order_steps.size())
		looped = looped or u.order_loop
	var mode: String = String(game.mode)
	var squad: SimWorld.Squad = game.world.squads.get(game.sel_squad) as SimWorld.Squad
	var signature: String = "%s|%s|%d|%s|%s|%s|%s|%s" % [page, str(chain_active), steps, str(looped), mode, str(game.follow_selection), _cycle_caption("formation"), _cycle_caption("stance") + _cycle_caption("priority") + ("" if squad == null else squad.formation)]
	if signature == _signature:
		return
	_signature = signature
	chain_btn.text = "Enchaîner · %d/%d" % [steps, OrderQueue.MAX_STEPS] if chain_active or steps > 0 else "Enchaîner"
	chain_btn.theme_type_variation = "ToggleOnButton" if chain_active else ""
	undo_btn.disabled = steps == 0
	clear_btn.disabled = steps == 0
	loop_btn.disabled = steps < 2
	loop_btn.theme_type_variation = "ToggleOnButton" if looped else ""
	var keys: Array = ARMY_1 if page == "army1" else (ARMY_2 if page == "army2" else WORKERS)
	buttons.clear()
	for i in 8:
		var b: Button = grid.get_child(i) as Button
		var key: String = String(keys[i])
		b.set_meta("key", key)
		b.text = _cycle_caption(key) if key in ["formation", "stance", "priority"] else ("Suivi actif" if key == "center" and game.follow_selection else String(LABELS[key]))
		b.tooltip_text = String(TIPS.get(key, ""))
		b.theme_type_variation = "ToggleOnButton" if mode == "cmd:" + key else ""
		b.disabled = not _available(key)
		buttons[key] = b

func _available(key: String) -> bool:
	match key:
		"formation":
			return game.sel_squad != -1
		"explore":
			for u in game.selected_units():
				if Rules.unit_has(u.type, "scout") or Rules.unit_has(u.type, "cavalry"):
					return true
			return false
		"release":
			for u in game.selected_units():
				if u.direct or u.manual:
					return true
			var s: SimWorld.Squad = game.world.squads.get(game.sel_squad) as SimWorld.Squad
			return s != null and s.direct
	return true

func _first_unit() -> SimWorld.Unit:
	var units: Array = game.selected_units()
	return units[0] if not units.is_empty() else null

func _cycle_caption(key: String) -> String:
	var u: SimWorld.Unit = _first_unit()
	match key:
		"formation":
			var s: SimWorld.Squad = game.world.squads.get(game.sel_squad) as SimWorld.Squad
			return "Form. : " + String(UnitCommands.FORMATION_LABELS["grid" if s == null or s.formation == "" else s.formation])
		"stance":
			return "Post. : " + String(UnitCommands.STANCE_LABELS["aggressive" if u == null or u.stance == "" else u.stance])
		"priority":
			return "Cible : " + String(UnitCommands.PRIORITY_LABELS["" if u == null else u.target_pref]).substr(0, 10)
	return ""

# ---------------------------------------------------------------- enchaîner

func set_chain(value: bool) -> void:
	chain_active = value
	_signature = ""
	if not value and String(game.mode).begins_with("cmd:") and String(game.mode) in ["cmd:move", "cmd:amove"]:
		game.mode = ""
		game.hud.set_hint("")
	refresh()

func _chain_down() -> void:
	_chain_was = chain_active
	_down_at = float(Time.get_ticks_msec()) / 1000.0
	if not chain_active:
		set_chain(true)

func _chain_up() -> void:
	var held: float = float(Time.get_ticks_msec()) / 1000.0 - _down_at
	_down_at = -1.0
	if held >= HOLD:
		set_chain(false)             # maintenu : actif seulement pendant l'appui (comme une touche Maj)
	elif _chain_was:
		set_chain(false)             # toucher : bascule
	game.hud.set_hint("Enchaîner actif : chaque ordre s'ajoute à la file" if chain_active else "")

# ---------------------------------------------------------------- actions

func _slot_pressed(i: int) -> void:
	var b: Button = grid.get_child(i) as Button
	run(String(b.get_meta("key", "")))

func run(key: String) -> void:
	## Exécute une commande de la carte (aussi utilisé par les recettes et le menu circulaire).
	match key:
		"more":
			page = "army2"
		"back":
			page = "army1"
		"center":
			# Premier toucher : centrer et suivre la sélection ; second toucher : arrêter le suivi.
			game.follow_selection = not game.follow_selection
			game.focus(game.selection_world_center())
			game.hud.toast("La caméra suit la sélection" if game.follow_selection else "Suivi de la caméra arrêté", AgeTheme.c("info"))
		"stop":
			_issue({"t": "stop"}, "Arrêt")
		"hold":
			_issue({"t": "hold"}, "Tenir la position")
		"retreat":
			_issue({"t": "retreat"}, "Repli")
		"explore":
			_issue({"t": "explore", "units": _ids(func(u): return Rules.unit_has(u.type, "scout") or Rules.unit_has(u.type, "cavalry") or Rules.unit_has(u.type, "military"))}, "Exploration automatique")
		"auto":
			_issue({"t": "worker_auto"}, "Retour à l'économie")
		"return":
			_issue({"t": "return_drop"}, "Retour au dépôt")
		"release":
			_release()
		"formation":
			var s: SimWorld.Squad = game.world.squads.get(game.sel_squad) as SimWorld.Squad
			if s != null:
				var current: int = UnitCommands.FORMATIONS.find("grid" if s.formation == "" else s.formation)
				_issue({"t": "formation", "value": UnitCommands.FORMATIONS[(current + 1) % UnitCommands.FORMATIONS.size()]}, "")
		"stance":
			var u: SimWorld.Unit = _first_unit()
			var now: int = UnitCommands.STANCES.find("aggressive" if u == null or u.stance == "" else u.stance)
			_issue({"t": "stance", "value": UnitCommands.STANCES[(now + 1) % UnitCommands.STANCES.size()], "units": _ids(func(x): return Rules.unit_has(x.type, "military") or Rules.unit_has(x.type, "scout"))}, "")
		"priority":
			var first: SimWorld.Unit = _first_unit()
			var at: int = UnitCommands.PRIORITIES.find("" if first == null else first.target_pref)
			_issue({"t": "target_priority", "value": UnitCommands.PRIORITIES[(at + 1) % UnitCommands.PRIORITIES.size()], "units": _ids(func(x): return Rules.unit_has(x.type, "military"))}, "")
		"build":
			game.hud._toggle_build()
		_:
			if key in TARGETED:
				game.mode = "cmd:" + key
				game.hud.set_hint({"move": "Touchez la destination", "amove": "Touchez le point d'assaut", "patrol": "Touchez le point de patrouille",
					"garrison": "Touchez un bâtiment allié", "follow": "Touchez l'unité alliée à suivre", "repair": "Touchez le bâtiment à réparer",
					"gather": "Touchez la ressource à récolter"}[key] + (" · Enchaîner : chaque toucher ajoute une étape" if chain_active else ""))
	_signature = ""
	refresh()

func _ids(filter: Callable = Callable()) -> Array:
	var out: Array = []
	for u in game.selected_units():
		if not filter.is_valid() or bool(filter.call(u)):
			out.append(u.id)
	return out

func _base(cmd: Dictionary) -> Dictionary:
	var full: Dictionary = cmd.duplicate()
	full["team"] = game.player
	if not full.has("units") and not full.has("squad"):
		if game.sel_squad != -1 and cmd["t"] in ["stop", "hold", "stance", "formation", "retreat", "target_priority"]:
			full["squad"] = game.sel_squad
		else:
			full["units"] = _ids()
	return full

func _issue(cmd: Dictionary, label: String, at: Vector2 = Vector2(-1, -1)) -> bool:
	var result: Dictionary = game.world.issue(_base(cmd))
	if bool(result.get("ok", false)):
		if label != "":
			game.hud.toast(label, AgeTheme.c("success"))
		AgeTheme.haptic(10)
		game.hud.selection_changed()
		return true
	game.hud.refusal(String(result.get("reason", "Ordre impossible")), at)
	return false

func _release() -> void:
	var s: SimWorld.Squad = game.world.squads.get(game.sel_squad) as SimWorld.Squad
	if s != null and s.direct:
		game.world.issue({"t": "release_squad", "team": game.player, "squad": s.id})
	for u in game.selected_units():
		if u.direct or u.manual or not u.order_steps.is_empty():
			game.world.issue({"t": "release_unit", "team": game.player, "unit": u.id})
			if Rules.unit_has(u.type, "worker"):
				game.world.issue({"t": "worker_auto", "team": game.player, "units": [u.id]})
	game.hud.toast("Rendu à l'armée / à l'économie", AgeTheme.c("success"))
	game.hud.selection_changed()

func _undo() -> void:
	_issue({"t": "queue_edit", "op": "undo", "units": _ids(func(u): return not u.order_steps.is_empty())}, "")

func _clear() -> void:
	_issue({"t": "queue_clear", "units": _ids(func(u): return not u.order_steps.is_empty())}, "File vidée")

func _loop() -> void:
	var ids: Array = _ids(func(u): return not u.order_steps.is_empty())
	var current: bool = false
	for u in game.selected_units():
		current = current or u.order_loop
	_issue({"t": "queue_edit", "op": "loop", "value": not current, "units": ids}, "File en boucle" if not current else "Boucle désactivée")

# ---------------------------------------------------------------- ciblage

func queue_step(step: Dictionary, sp: Vector2, marker: Vector2) -> bool:
	## Ajoute (Enchaîner) ou remplace la file des unités capables de cette étape.
	var kind: String = String(step["type"])
	var ids: Array = _ids(func(u): return OrderQueue.can_queue(u, kind))
	if ids.is_empty():
		game.hud.refusal("aucune unité sélectionnée ne peut : " + String(OrderQueue.STEP_LABELS[kind]), sp)
		return false
	var cmd: Dictionary = {"t": "queue_append" if chain_active else "queue_orders", "orders": [step], "units": ids}
	if not chain_active and kind == "amove" and step.has("loop"):
		cmd["loop"] = true
	var ok: bool = _issue(cmd, "", sp)
	if ok:
		game.view.add_marker(marker, AgeTheme.STEP_COLORS.get(kind, AgeTheme.c("accent")))
		_announce_direct()
	return ok

func _announce_direct() -> void:
	var s: SimWorld.Squad = game.world.squads.get(game.sel_squad) as SimWorld.Squad
	if s != null and not bool(get_meta("direct_told_%d" % s.id, false)):
		set_meta("direct_told_%d" % s.id, true)
		game.hud.toast("Escouade %d en contrôle direct pour suivre la file — « Rendre » la rend à l'armée" % s.number, AgeTheme.c("info"))

func on_target(kind: String, sp: Vector2, g: Vector2, e, node) -> void:
	## Toucher après un bouton à cible (mode « cmd:… »).
	var keep: bool = chain_active and kind in ["move", "amove", "patrol"]
	match kind:
		"move", "amove":
			if chain_active:
				queue_step({"type": kind, "pos": [g.x, g.y]}, sp, g)
			elif e != null and game.world.factions.hostile(game.player, e.team):
				game._order({"t": "attack", "target": e.id}, game.world.entity_pos(e), AgeTheme.STEP_COLORS["attack"])
			else:
				game._order({"t": kind, "pos": [g.x, g.y]}, g, AgeTheme.STEP_COLORS[kind])
		"patrol":
			if chain_active:
				queue_step({"type": "amove", "pos": [g.x, g.y]}, sp, g)
				var ids: Array = _ids(func(u): return not u.order_steps.is_empty())
				if not ids.is_empty():
					game.world.issue({"t": "queue_edit", "team": game.player, "units": ids, "op": "loop", "value": true})
			else:
				var start: Vector2 = game.selection_world_center()
				var ids2: Array = _ids(func(u): return OrderQueue.can_queue(u, "amove"))
				var result: Dictionary = game.world.issue({"t": "queue_orders", "team": game.player, "units": ids2, "loop": true,
					"orders": [{"type": "amove", "pos": [g.x, g.y]}, {"type": "amove", "pos": [start.x, start.y]}]})
				if bool(result.get("ok", false)):
					game.view.add_marker(g, AgeTheme.STEP_COLORS["patrol"])
					_announce_direct()
				else:
					game.hud.refusal(String(result.get("reason", "Patrouille impossible")), sp)
		"garrison":
			if e is SimWorld.Building and e.team == game.player:
				if chain_active:
					queue_step({"type": "garrison", "building": e.id}, sp, e.center)
				else:
					_issue({"t": "garrison", "building": e.id, "units": _ids(func(u): return UnitCommands.can_garrison(u))}, "Garnison : %s" % Rules.BUILDINGS[e.type]["label"], sp)
			else:
				game.hud.refusal("touchez un bâtiment allié", sp)
		"follow":
			if e is SimWorld.Unit and e.team == game.player:
				if chain_active:
					queue_step({"type": "follow", "target": e.id}, sp, e.pos)
				else:
					_issue({"t": "follow", "target": e.id}, "Suivre : %s" % Rules.UNITS[e.type]["label"], sp)
			else:
				game.hud.refusal("touchez une unité alliée", sp)
		"repair":
			if e is SimWorld.Building and e.team == game.player:
				if chain_active:
					queue_step({"type": "repair", "building": e.id}, sp, e.center)
				else:
					_issue({"t": "repair", "building": e.id, "units": _ids(func(u): return Rules.unit_has(u.type, "worker"))}, "Réparation", sp)
			else:
				game.hud.refusal("touchez un bâtiment allié endommagé", sp)
		"gather":
			var target_id: int = node.id if node != null else (e.id if e is SimWorld.Building and e.type == "ferme" else -1)
			if target_id == -1:
				game.hud.refusal("touchez un gisement ou une ferme", sp)
			elif chain_active:
				queue_step({"type": "gather", "node": target_id}, sp, g)
			else:
				_issue({"t": "gather", "node": target_id, "units": _ids(func(u): return Rules.unit_has(u.type, "worker"))}, "Récolte", sp)
	if not keep:
		game.mode = ""
		game.hud.set_hint("")
	_signature = ""
	refresh()

func chain_tap(sp: Vector2, g: Vector2, e, node) -> bool:
	## Toucher simple pendant « Enchaîner » : l'étape s'ajoute selon ce qui est touché.
	if not chain_active or not game.has_command_selection():
		return false
	if e != null and game.world.factions.hostile(game.player, e.team) and game.world.is_visible_to(game.player, game.world.entity_pos(e)):
		return queue_step({"type": "attack", "target": e.id}, sp, game.world.entity_pos(e))
	var workers: bool = context() == "workers"
	if workers and e is SimWorld.Building and e.team == game.player and not e.complete:
		return queue_step({"type": "build", "building": e.id}, sp, e.center)
	if workers and e is SimWorld.Building and e.team == game.player and e.complete and e.hp < e.max_hp - 0.5:
		return queue_step({"type": "repair", "building": e.id}, sp, e.center)
	if workers and node != null:
		return queue_step({"type": "gather", "node": node.id}, sp, g)
	if e is SimWorld.Unit and e.team == game.player:
		return false
	return queue_step({"type": "move", "pos": [g.x, g.y]}, sp, g)

func context_tap(sp: Vector2, g: Vector2, e, node) -> bool:
	## Ordre contextuel des ouvriers sans Enchaîner : récolter ici, bâtir ce chantier, réparer.
	if context() != "workers":
		return false
	if e is SimWorld.Building and e.team == game.player and not e.complete:
		return _issue({"t": "build_assign", "building": e.id}, "Chantier assigné", sp)
	if e is SimWorld.Building and e.team == game.player and e.complete and e.hp < e.max_hp - 0.5:
		return _issue({"t": "repair", "building": e.id}, "Réparation", sp)
	if e is SimWorld.Building and e.team == game.player and e.type == "ferme" and e.complete:
		return _issue({"t": "gather", "node": e.id, "units": _ids().slice(0, 1)}, "Ferme exploitée", sp)
	if node != null:
		return _issue({"t": "gather", "node": node.id}, "Récolte : %s" % Rules.RES_LABEL[node.res].to_lower(), sp)
	return false
