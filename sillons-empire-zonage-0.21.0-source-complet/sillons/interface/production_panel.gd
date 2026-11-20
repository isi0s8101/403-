class_name ProductionPanel
extends PanelContainer
## 0.17 — Production globale : former une unité depuis n'importe où, sans chercher le bâtiment sur la carte.
## Liste compacte des unités formables par vos producteurs achevés ; un toucher forme l'unité dans le
## producteur le moins chargé qui l'accepte (commande « train » ordinaire : coût, âge, file vérifiés).

var game
var list: GridContainer
var title: Label
var _signature: String = ""

func setup(p_game) -> void:
	game = p_game
	visible = false
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 12
	offset_top = -470
	offset_bottom = -150
	var box := VBoxContainer.new()
	add_child(box)
	title = Label.new()
	title.theme_type_variation = "HeaderLabel"
	title.text = "Former depuis n'importe où"
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list = GridContainer.new()
	list.columns = 2
	list.add_theme_constant_override("h_separation", 6)
	list.add_theme_constant_override("v_separation", 6)
	scroll.add_child(list)
	var close := Button.new()
	close.text = "Fermer"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(func(): UIMotion.conceal(self))
	box.add_child(close)

func producers() -> Dictionary:
	## {unité: [bâtiments]} pour les producteurs achevés du joueur sur la carte courante.
	var out: Dictionary = {}
	for b in game.world.team_buildings(game.player, "", true):
		for kind in Rules.BUILDINGS[b.type].get("trains", []):
			if not CivEvolution.visible_unit(game.world, game.player, String(kind)):
				continue
			var entry: Array = out.get(kind, []) as Array
			entry.append(b)
			out[kind] = entry
	return out

func best_producer(kind: String) -> SimWorld.Building:
	var best: SimWorld.Building = null
	for b in producers().get(kind, []):
		if game.world.train_check(game.player, b, kind) != "":
			continue
		if best == null or b.queue.size() < best.queue.size() or (b.queue.size() == best.queue.size() and b.id < best.id):
			best = b
	return best

func train(kind: String) -> bool:
	var b: SimWorld.Building = best_producer(kind)
	if b == null:
		var any: Array = producers().get(kind, []) as Array
		game.hud.refusal(game.world.train_check(game.player, any[0], kind) if not any.is_empty() else "aucun producteur", Vector2(-1, -1))
		return false
	var r: Dictionary = game.world.issue({"t": "train", "team": game.player, "building": b.id, "unit": kind})
	if bool(r.get("ok", false)):
		game.hud.toast("%s en formation : %s" % [String(Rules.UNITS[kind]["label"]), String(Rules.BUILDINGS[b.type]["label"])], AgeTheme.c("success"))
		_signature = ""
		return true
	game.hud.refusal(String(r.get("reason", "refus")), Vector2(-1, -1))
	return false

func open() -> void:
	_signature = ""
	refresh()
	UIMotion.reveal(self)

func refresh() -> void:
	if not visible:
		return
	var data: Dictionary = producers()
	var kinds: Array = data.keys()
	kinds.sort()
	var parts: PackedStringArray = PackedStringArray()
	for kind in kinds:
		var b: SimWorld.Building = best_producer(String(kind))
		parts.append("%s:%d:%d" % [kind, (data[kind] as Array).size(), -1 if b == null else b.queue.size()])
	var signature: String = ",".join(parts) + str(game.world.teams[game.player].age)
	if signature == _signature:
		return
	_signature = signature
	UIMotion.clear(list)
	var age: int = game.world.teams[game.player].age
	for kind in kinds:
		var definition: Dictionary = Rules.UNITS[kind]
		var card := DataCard.new()
		card.key = String(kind)
		card.setup(String(definition["label"]), Portraits.unit(String(kind), age), "%s · %d producteur(s)" % [Rules.cost_text(definition["cost"]), (data[kind] as Array).size()], train.bind(String(kind)))
		card.custom_minimum_size = Vector2(200, 140)
		var b: SimWorld.Building = best_producer(String(kind))
		var any: Array = data[kind] as Array
		card.availability("" if b != null else game.world.train_check(game.player, any[0], String(kind)))
		list.add_child(card)
	if kinds.is_empty():
		var empty := Label.new()
		empty.text = "Aucun producteur achevé sur cette carte."
		list.add_child(empty)
