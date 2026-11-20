class_name ControlGroups
extends PanelContainer
## 0.17 — Groupes de contrôle (6 emplacements, bord gauche, pouce gauche).
## Appui long = enregistrer la sélection ; toucher = la rappeler ; double toucher = la rappeler et centrer.
## Badge : effectif encore en vie ; jauge : santé moyenne.
## Persistance (décision documentée) : les groupes sont gardés pendant toute la partie, y compris au passage
## terrain → globe → orbite → système → galaxie, et enregistrés avec la sauvegarde dans un fichier compagnon
## (user://sillons-groupes.cfg) relu uniquement avec cette même sauvegarde (même graine, même tick).

const SLOTS := 6
const FILE := "user://sillons-groupes.cfg"
var game
var tiles: Array = []
var groups: Array = []          # [{world, squad, units}]
var _signature: String = ""

func setup(p_game) -> void:
	game = p_game
	for i in SLOTS:
		groups.append({"world": "", "squad": -1, "units": []})
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	for i in SLOTS:
		var tile := TouchTile.new()
		tile.custom_minimum_size = Vector2(52, 52)
		tile.caption = str(i + 1)
		tile.tapped.connect(recall.bind(i, false))
		tile.double_tapped.connect(recall.bind(i, true))
		tile.long_pressed.connect(assign.bind(i))
		tile.tooltip_text = "Groupe %d — appui long : enregistrer la sélection · toucher : rappeler · double toucher : rappeler et centrer" % (i + 1)
		box.add_child(tile)
		tiles.append(tile)

func _world_key() -> String:
	return String(game.campaign.active) if game.campaign != null else "single"

func assign(slot: int) -> void:
	var ids: Array = []
	for u in game.selected_units():
		ids.append(u.id)
	if ids.is_empty():
		groups[slot] = {"world": "", "squad": -1, "units": []}
		game.hud.toast("Groupe %d vidé (aucune unité sélectionnée)" % (slot + 1))
	else:
		groups[slot] = {"world": _world_key(), "squad": game.sel_squad, "units": ids}
		game.hud.toast("Groupe %d : %d unité(s) enregistrée(s)" % [slot + 1, ids.size()], AgeTheme.c("success"))
		UIFeedback.pulse(tiles[slot])
	_signature = ""
	refresh()

func alive(slot: int) -> Array:
	var g: Dictionary = groups[slot]
	var out: Array = []
	if String(g["world"]) != _world_key():
		return out
	for raw in g["units"]:
		var u: SimWorld.Unit = game.world.units.get(int(raw)) as SimWorld.Unit
		if u != null and u.team == game.player:
			out.append(u)
	return out

func recall(slot: int, center: bool) -> void:
	var members: Array = alive(slot)
	if members.is_empty():
		game.hud.toast("Groupe %d vide : appui long pour y enregistrer la sélection" % (slot + 1))
		return
	var g: Dictionary = groups[slot]
	var squad: SimWorld.Squad = game.world.squads.get(int(g["squad"])) as SimWorld.Squad
	if squad != null and squad.team == game.player and squad.units.size() == members.size():
		game.select_squad(squad.id)
	else:
		var ids: Array = []
		for u in members:
			ids.append(u.id)
		game.select_many(ids)
	if center:
		game.focus(game.selection_world_center())

func refresh() -> void:
	var parts: PackedStringArray = PackedStringArray()
	var data: Array = []
	for i in SLOTS:
		var members: Array = alive(i)
		var hp: float = 0.0
		var max_hp: float = 0.0
		for u in members:
			hp += u.hp
			max_hp += u.max_hp
		data.append([members.size(), hp / maxf(1.0, max_hp)])
		parts.append("%d:%d" % [members.size(), int(10.0 * hp / maxf(1.0, max_hp))])
	var signature: String = ",".join(parts)
	if signature == _signature:
		return
	_signature = signature
	for i in SLOTS:
		var tile: TouchTile = tiles[i]
		var count: int = int(data[i][0])
		tile.badge = str(count) if count > 0 else ""
		tile.gauge = float(data[i][1]) if count > 0 else -1.0
		tile.dimmed = count == 0
		tile.refresh_look()

func save(seed_value: int, tick: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("groupes", "cle", "%d:%d" % [seed_value, tick])
	cfg.set_value("groupes", "donnees", var_to_str(groups))
	cfg.save(FILE)

func load_for(seed_value: int, tick: int) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return false
	if String(cfg.get_value("groupes", "cle", "")) != "%d:%d" % [seed_value, tick]:
		return false
	var parsed = str_to_var(String(cfg.get_value("groupes", "donnees", "")))
	if not parsed is Array or (parsed as Array).size() != SLOTS:
		return false
	for i in SLOTS:
		var entry = (parsed as Array)[i]
		if not entry is Dictionary or not (entry as Dictionary).has("units") or not entry["units"] is Array:
			return false
	groups = parsed
	_signature = ""
	refresh()
	return true
