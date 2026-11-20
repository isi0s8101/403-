class_name CommandBars
extends PanelContainer
## 0.17 — Barres de héros et de pouvoirs de commandement (colonne droite, sous la mini-carte).
## Héros : portrait, vie, état (en service / en formation / tombé, rappel dans N s) ;
##   toucher = sélectionner, double toucher = sélectionner et centrer.
## Pouvoirs : points de commandement, pouvoirs débloqués avec anneau de recharge ;
##   toucher = mode ciblage avec aperçu du rayon au sol (Retour ou nouveau toucher pour annuler).
## Visible seulement quand l'évolution de la civilisation (0.16) est active.

var game
var points_label: Label
var hero_row: HBoxContainer
var power_row: HBoxContainer
var hero_tiles: Dictionary = {}
var power_tiles: Dictionary = {}
var _signature: String = ""
var _ready_seen: Dictionary = {}

func setup(p_game) -> void:
	game = p_game
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	points_label = Label.new()
	points_label.theme_type_variation = "MutedLabel"
	box.add_child(points_label)
	hero_row = HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 5)
	box.add_child(hero_row)
	power_row = HBoxContainer.new()
	power_row.add_theme_constant_override("separation", 5)
	box.add_child(power_row)
	for kind in CivRules.HEROES.keys():
		var tile := TouchTile.new()
		tile.custom_minimum_size = Vector2(52, 52)
		tile.tapped.connect(select_hero.bind(String(kind), false))
		tile.double_tapped.connect(select_hero.bind(String(kind), true))
		tile.visible = false
		hero_row.add_child(tile)
		hero_tiles[kind] = tile
	for key in CivRules.POWER_ORDER:
		var ptile := TouchTile.new()
		ptile.custom_minimum_size = Vector2(52, 52)
		ptile.caption = String((CivRules.POWERS[key] as Dictionary)["label"]).substr(0, 6)
		ptile.tapped.connect(arm_power.bind(String(key)))
		ptile.visible = false
		power_row.add_child(ptile)
		power_tiles[key] = ptile

func hero_unit(kind: String) -> SimWorld.Unit:
	for u in game.world.team_units(game.player, ""):
		if u.type == kind:
			return u
	return null

func select_hero(kind: String, center: bool) -> void:
	var u: SimWorld.Unit = hero_unit(kind)
	if u == null:
		game.hud.toast("Héros absent de ce secteur")
		return
	game.select_single(u.id)
	if center:
		game.focus(u.pos)

func arm_power(key: String) -> void:
	var wait: float = CivEvolution.power_wait(game.world, game.player, key)
	if wait > 0.0:
		game.hud.refusal("%s : prêt dans %d s" % [String((CivRules.POWERS[key] as Dictionary)["label"]), ceili(wait)], Vector2(-1, -1))
		return
	game.civ_power_key = key
	game.mode = "civ_power"
	game.power_preview = Vector2(game.cam_target.x, game.cam_target.z)
	game.hud.set_hint("%s : touchez ou glissez pour viser (rayon %d) · Retour pour annuler" % [String((CivRules.POWERS[key] as Dictionary)["label"]), int((CivRules.POWERS[key] as Dictionary)["radius"])])

func refresh() -> void:
	if not CivEvolution.enabled(game.world):
		visible = false
		return
	var civ: Dictionary = CivEvolution.state(game.world, game.player)
	var parts: PackedStringArray = PackedStringArray(["%d" % floori(float(civ["points"]))])
	var any: bool = false
	for kind in hero_tiles.keys():
		var record: Dictionary = (civ["heroes"] as Dictionary).get(kind, {}) as Dictionary
		var status: String = String(record.get("state", "none"))
		var u: SimWorld.Unit = hero_unit(kind) if status == "alive" else null
		var wait: int = ceili(CivEvolution.recall_wait(game.world, game.player, kind))
		parts.append("%s:%s:%d:%d" % [kind, status, int(10.0 * u.hp / u.max_hp) if u != null else -1, wait])
		any = any or status != "none"
	for key in power_tiles.keys():
		var unlocked: bool = (civ["powers"] as Dictionary).has(key)
		var wait_p: float = CivEvolution.power_wait(game.world, game.player, key) if unlocked else 0.0
		parts.append("%s:%s:%d:%s" % [key, str(unlocked), ceili(wait_p), str(game.mode == "civ_power" and game.civ_power_key == key)])
		any = any or unlocked
		if unlocked and wait_p <= 0.0 and not bool(_ready_seen.get(key, true)):
			game.hud.alerts.push("pouvoir", "Pouvoir prêt : %s" % String((CivRules.POWERS[key] as Dictionary)["label"]))
		_ready_seen[key] = unlocked and wait_p <= 0.0
	visible = any
	var signature: String = ",".join(parts)
	if signature == _signature:
		return
	_signature = signature
	points_label.text = "Commandement : %d points" % floori(float(civ["points"]))
	var age: int = game.world.teams[game.player].age
	for kind in hero_tiles.keys():
		var tile: TouchTile = hero_tiles[kind]
		var record: Dictionary = (civ["heroes"] as Dictionary).get(kind, {}) as Dictionary
		var status: String = String(record.get("state", "none"))
		tile.visible = status != "none"
		tile.icon = Portraits.unit(String(kind), age)
		var u: SimWorld.Unit = hero_unit(kind) if status == "alive" else null
		tile.gauge = u.hp / u.max_hp if u != null else -1.0
		tile.dimmed = status != "alive"
		var wait: int = ceili(CivEvolution.recall_wait(game.world, game.player, kind))
		tile.badge = {"alive": "", "queued": "…", "dead": ("%ds" % wait if wait > 0 else "!")}.get(status, "")
		tile.tooltip_text = "%s — %s" % [CivEvolution.hero_name(game.world, game.player, kind), {"alive": "en service", "queued": "en formation", "dead": ("tombé, rappel dans %d s" % wait if wait > 0 else "tombé, rappel possible")}.get(status, "")]
		tile.refresh_look()
	for key in power_tiles.keys():
		var ptile: TouchTile = power_tiles[key]
		var unlocked_p: bool = (civ["powers"] as Dictionary).has(key)
		ptile.visible = unlocked_p
		var cooldown: float = float((CivRules.POWERS[key] as Dictionary)["cooldown"])
		var wait_t: float = CivEvolution.power_wait(game.world, game.player, key) if unlocked_p else 0.0
		ptile.ring = 1.0 - wait_t / maxf(1.0, cooldown) if wait_t > 0.0 else -1.0
		ptile.badge = "%d" % ceili(wait_t) if wait_t > 0.0 else ""
		ptile.highlighted = game.mode == "civ_power" and game.civ_power_key == key
		ptile.tooltip_text = "%s — %s · recharge %d s" % [String((CivRules.POWERS[key] as Dictionary)["label"]), String((CivRules.POWERS[key] as Dictionary)["text"]), int(cooldown)]
		ptile.refresh_look()
