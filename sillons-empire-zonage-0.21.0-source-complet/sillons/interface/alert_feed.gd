class_name AlertFeed
extends VBoxContainer
## 0.17 — File d'alertes (côté gauche, sous la barre du haut) : attaque, pénurie, recherche ou monument
## terminé, âge possible, héros tombé, pouvoir prêt, unité perdue, population bloquée.
## Chaque alerte : repère de forme + couleur, texte court, bouton « Voir » qui centre la caméra.
## Les alertes du même genre se regroupent (compteur ×N) : pas de pluie de messages.

const MAX_ROWS := 3
const LIFETIME := 14.0
const GROUP_WINDOW := 12.0
const KINDS := {
	# 0.18.1 : formes prises dans les polices livrées (un symbole absent s'affichait en carré sur Android).
	"attaque": {"shape": "!", "color": "danger"}, "perte": {"shape": "×", "color": "danger"}, "detruit": {"shape": "×", "color": "danger"},
	"penurie": {"shape": "↓", "color": "warning"}, "pop": {"shape": "↑", "color": "warning"}, "heros": {"shape": "†", "color": "danger"},
	"fini": {"shape": "√", "color": "success"}, "age": {"shape": "∆", "color": "info"}, "pouvoir": {"shape": "◊", "color": "info"},
	"file": {"shape": "→", "color": "warning"},
	# 0.18 : ville
	"feu": {"shape": "≈", "color": "danger"}, "ville": {"shape": "#", "color": "warning"}, "sante": {"shape": "+", "color": "danger"},
}
var game
var alerts: Array = []            # [{kind, text, pos, count, t, row}]
var pings: Array = []             # positions d'attaque récentes pour la mini-carte [{pos, t}]
var last_pos: Vector2 = Vector2(-1, -1)
var _clock: float = 0.0

func setup(p_game) -> void:
	game = p_game
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func push(kind: String, text: String, pos: Vector2 = Vector2(-1, -1)) -> void:
	if pos.x >= 0.0:
		last_pos = pos
	for a in alerts:
		if String(a["kind"]) == kind and _clock - float(a["t"]) < GROUP_WINDOW:
			a["count"] = int(a["count"]) + 1
			a["text"] = text
			a["t"] = _clock
			if pos.x >= 0.0:
				a["pos"] = pos
			_render(a)
			UIFeedback.pulse(a["row"] as Control, 0.25)
			return
	var entry: Dictionary = {"kind": kind, "text": text, "pos": pos, "count": 1, "t": _clock, "row": null}
	alerts.push_front(entry)
	var row: PanelContainer = _make_row(entry)
	add_child(row)
	move_child(row, 0)
	entry["row"] = row
	_render(entry)
	UIFeedback.pulse(row, 0.45)
	if game.hud != null and game.hud.feedback != null and kind in ["attaque", "heros", "perte", "detruit"]:
		game.hud.feedback.play("alert")
		AgeTheme.haptic(30)
	while alerts.size() > MAX_ROWS:
		var old: Dictionary = alerts.pop_back()
		(old["row"] as Node).queue_free()

func _make_row(entry: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(300, 0)
	var h := HBoxContainer.new()
	h.name = "Row"
	h.add_theme_constant_override("separation", 6)
	row.add_child(h)
	var shape := Label.new()
	shape.name = "Shape"
	shape.custom_minimum_size = Vector2(22, 0)
	shape.add_theme_font_size_override("font_size", 18)
	h.add_child(shape)
	var text := Label.new()
	text.name = "Text"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(170, 0)
	text.add_theme_font_size_override("font_size", 13)
	h.add_child(text)
	var go := Button.new()
	go.name = "Go"
	go.text = "Voir"
	go.custom_minimum_size = Vector2(56, 48)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(_go.bind(entry))
	if game.hud != null and game.hud.feedback != null:
		game.hud.feedback.decorate(go)
	h.add_child(go)
	return row

func _render(entry: Dictionary) -> void:
	var row: PanelContainer = entry["row"] as PanelContainer
	if row == null:
		return
	var spec: Dictionary = KINDS.get(String(entry["kind"]), {"shape": "•", "color": "info"}) as Dictionary
	var shape: Label = row.get_node("Row/Shape") as Label
	shape.text = String(spec["shape"])
	shape.add_theme_color_override("font_color", AgeTheme.c(String(spec["color"])))
	(row.get_node("Row/Text") as Label).text = String(entry["text"]) + (" ×%d" % int(entry["count"]) if int(entry["count"]) > 1 else "")
	(row.get_node("Row/Go") as Button).visible = (entry["pos"] as Vector2).x >= 0.0

func _go(entry: Dictionary) -> void:
	var p: Vector2 = entry["pos"]
	if p.x >= 0.0:
		game.focus(p)

func go_last() -> bool:
	## « Aller à la dernière alerte » : un toucher.
	if last_pos.x < 0.0:
		game.hud.toast("Aucune alerte localisée")
		return false
	game.focus(last_pos)
	return true

func note_attack(pos: Vector2) -> void:
	for p in pings:
		if (p["pos"] as Vector2).distance_to(pos) < 8.0:
			p["t"] = _clock
			return
	pings.append({"pos": pos, "t": _clock})
	push("attaque", "Attaque près de vos troupes ou bâtiments", pos)

func tick(delta: float) -> void:
	_clock += delta
	for a in alerts.duplicate():
		if _clock - float(a["t"]) > LIFETIME:
			alerts.erase(a)
			(a["row"] as Node).queue_free()
	for p in pings.duplicate():
		if _clock - float(p["t"]) > 10.0:
			pings.erase(p)

func retheme(_age: int) -> void:
	for a in alerts:
		_render(a)

func on_event(e: Dictionary) -> void:
	## Traduction des événements de simulation du joueur en alertes localisées.
	var mine: bool = int(e["team"]) == game.player
	var kind: String = String(e["type"])
	match kind:
		"penurie":
			if mine: push("penurie", String(e["text"]))
		"pop":
			if mine:
				var b: SimWorld.Building = game.world.buildings.get(int(e.get("building", -1))) as SimWorld.Building
				push("pop", "Population pleine : construisez une %s" % ("zone d'habitation" if UrbanCity.active(game.world, game.player) else "maison"), b.center if b != null else Vector2(-1, -1))
		"technologie":
			if mine: push("fini", String(e["text"]))
		"evolution":
			if mine and String(e["text"]).contains("amélioré") or mine and String(e["text"]).contains("disponible"):
				var site: SimWorld.Building = game.world.buildings.get(int(e.get("building", -1))) as SimWorld.Building
				push("fini", String(e["text"]), site.center if site != null else Vector2(-1, -1))
		"age_atteint":
			if mine: push("age", String(e["text"]))
		"detruit":
			if mine: push("detruit", String(e["text"]), e.get("pos", Vector2(-1, -1)))
		"mort":
			if mine:
				if CivRules.HEROES.has(String(e.get("utype", ""))):
					push("heros", "Héros tombé : rappel possible plus tard", e.get("pos", Vector2(-1, -1)))
				else:
					push("perte", "Unités perdues", e.get("pos", Vector2(-1, -1)))
		"file":
			if mine: push("file", String(e["text"]), e.get("pos", Vector2(-1, -1)))
		"incendie", "incendie_perte":
			if mine: push("feu", String(e["text"]), e.get("pos", Vector2(-1, -1)))
		"epidemie":
			if mine: push("sante", String(e["text"]), e.get("pos", Vector2(-1, -1)))
		"panne_electrique", "penurie_eau", "criminalite":
			if mine: push("ville", String(e["text"]))
		"ville":
			if mine: push("fini" if String(e["text"]).contains("niveau") else "age", String(e["text"]), e.get("pos", Vector2(-1, -1)))
		"tir":
			if not mine and game.world.factions.hostile(game.player, int(e["team"])):
				var to: Vector2 = e.get("to", Vector2(-1, -1))
				if to.x >= 0.0 and game.world.is_visible_to(game.player, to):
					note_attack(to)
