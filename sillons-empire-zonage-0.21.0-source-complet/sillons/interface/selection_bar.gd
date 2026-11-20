class_name SelectionBar
extends HBoxContainer
## 0.17 — Barre de sélection : un portrait par type d'unité sélectionné, avec effectif et santé moyenne.
## Toucher un portrait = ne garder que ce type ; appui long = retirer ce type de la sélection.
## Mise à jour incrémentale : les tuiles sont réutilisées, reconstruites seulement si la signature change.

var game
var _signature: String = ""

func setup(p_game) -> void:
	game = p_game
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(0, 58)

func groups() -> Array:
	## [{type, ids, hp, max_hp}] trié par effectif décroissant puis par nom (ordre stable).
	var by_type: Dictionary = {}
	for u in game.selected_units():
		var entry: Dictionary = by_type.get(u.type, {"type": u.type, "ids": [], "hp": 0.0, "max_hp": 0.0}) as Dictionary
		(entry["ids"] as Array).append(u.id)
		entry["hp"] = float(entry["hp"]) + u.hp
		entry["max_hp"] = float(entry["max_hp"]) + u.max_hp
		by_type[u.type] = entry
	var out: Array = by_type.values()
	out.sort_custom(func(a, b): return (a["ids"] as Array).size() > (b["ids"] as Array).size() or ((a["ids"] as Array).size() == (b["ids"] as Array).size() and String(a["type"]) < String(b["type"])))
	return out

func refresh() -> void:
	var data: Array = groups()
	var parts: PackedStringArray = PackedStringArray()
	for g in data:
		parts.append("%s:%d:%d" % [g["type"], (g["ids"] as Array).size(), int(10.0 * float(g["hp"]) / maxf(1.0, float(g["max_hp"])))])
	var signature: String = ",".join(parts)
	if signature == _signature:
		return
	_signature = signature
	while get_child_count() < data.size():
		var tile := TouchTile.new()
		tile.tapped.connect(_keep.bind(tile))
		tile.long_pressed.connect(_drop.bind(tile))
		add_child(tile)
	while get_child_count() > data.size():
		var extra: Node = get_child(get_child_count() - 1)
		remove_child(extra)
		extra.queue_free()
	var age: int = game.world.teams[game.player].age
	for i in data.size():
		var g: Dictionary = data[i]
		var tile: TouchTile = get_child(i) as TouchTile
		tile.set_meta("type", String(g["type"]))
		tile.icon = Portraits.unit(String(g["type"]), age)
		tile.badge = "×%d" % (g["ids"] as Array).size()
		tile.gauge = float(g["hp"]) / maxf(1.0, float(g["max_hp"]))
		tile.tooltip_text = "%s · %d unité(s) · santé %d %%\nToucher : garder ce type · appui long : le retirer" % [String(Rules.UNITS[String(g["type"])]["label"]), (g["ids"] as Array).size(), int(100.0 * tile.gauge)]
		tile.refresh_look()

func _keep(tile: TouchTile) -> void:
	game.filter_selection(String(tile.get_meta("type", "")), true)

func _drop(tile: TouchTile) -> void:
	game.filter_selection(String(tile.get_meta("type", "")), false)
