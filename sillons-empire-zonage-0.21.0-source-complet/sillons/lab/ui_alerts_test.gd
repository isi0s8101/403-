extends "res://lab/ui_test_base.gd"
## 0.17 — Lot UI-4 : file d'alertes cliquables (regroupement, « Voir », dernière alerte), signal d'attaque sur
## la mini-carte, barre de héros, barre de pouvoirs avec aperçu du rayon au sol (2 touchers), Retour.

func result_key() -> String:
	return "UI_ALERTS_RESULT"

func run() -> void:
	var w: SimWorld = game.world
	var alerts: AlertFeed = game.hud.alerts
	var base: Vector2 = home() + Vector2(8, -6)
	# --- alertes regroupées et cliquables
	w.emit("penurie", 0, "Aucun gisement de bois accessible", {"res": "wood"})
	w.emit("penurie", 0, "Aucun gisement de bois accessible", {"res": "wood"})
	w.emit("detruit", 0, "Bâtiment détruit : Maison", {"building": -1, "btype": "maison", "pos": base + Vector2(20, 10)})
	await frames(3)
	check(alerts.alerts.size() == 2, "A01 deux genres d'alerte, la pénurie répétée est regroupée (%d lignes)" % alerts.alerts.size())
	var shortage: Dictionary = {}
	for a in alerts.alerts:
		if String(a["kind"]) == "penurie": shortage = a
	check(int(shortage.get("count", 0)) == 2, "A02 compteur ×2 au lieu d'un second message")
	game.focus(base + Vector2(-30, 30))
	await frames(2)
	var row: PanelContainer = null
	for a in alerts.alerts:
		if String(a["kind"]) == "detruit": row = a["row"]
	var go: Button = row.get_node("Row/Go") as Button
	var before: int = touches_used
	await press(go)
	check(Vector2(game.cam_target.x, game.cam_target.z).distance_to(base + Vector2(20, 10)) < 0.5, "A03 « Voir » : la caméra va sur l'alerte en 1 toucher")
	count_touches("aller_a_la_derniere_alerte", before, "1 toucher")
	# --- attaque : alerte + signal sur la mini-carte (événement « tir » d'un camp hostile, visible)
	var spot: Vector2 = home() + Vector2(4, 4)
	w.events.append({"type": "tir", "team": 1, "text": "", "from": spot + Vector2(3, 0), "to": spot})
	await frames(3)
	var attack: bool = false
	for a in alerts.alerts:
		attack = attack or String(a["kind"]) == "attaque"
	check(attack and alerts.pings.size() == 1, "A04 attaque repérée : alerte et signal sur la mini-carte")
	game.focus(base + Vector2(-30, 30))
	check(alerts.go_last() and Vector2(game.cam_target.x, game.cam_target.z).distance_to(spot) < 0.5, "A05 « aller à la dernière alerte »")
	game.hud._update_minimap()
	var cell: Vector2i = w.cell_of(spot)
	var pixel: Color = game.hud.mini_img.get_pixelv(cell)
	check(pixel.r > 0.8 and pixel.g < 0.7, "A06 la mini-carte montre le signal d'attaque")
	# --- barre de héros
	var hero_ids: Array = spawn("heros_antique", base, 1, false)
	CivEvolution.state(w, 0)["heroes"]["heros_antique"] = {"state": "alive", "dead_tick": 0}
	game.hud._bars_t = 1.0
	await frames(14)
	var bars: CommandBars = game.hud.command_bars
	var hero_tile: TouchTile = bars.hero_tiles["heros_antique"]
	check(bars.visible and hero_tile.visible and hero_tile.gauge > 0.9, "A07 barre de héros : portrait, vie, en service")
	game.focus(base + Vector2(-30, 30))
	await press(hero_tile)
	check(game.selected_ids() == hero_ids, "A08 toucher le héros : sélectionné")
	await wait(0.45)
	await tap(center_of(hero_tile))
	await tap(center_of(hero_tile))
	check(Vector2(game.cam_target.x, game.cam_target.z).distance_to((w.units[hero_ids[0]] as SimWorld.Unit).pos) < 0.5, "A09 double toucher : héros centré")
	w.issue({"t": "lab_kill", "team": 0, "id": hero_ids[0]})
	CivEvolution.state(w, 0)["heroes"]["heros_antique"] = {"state": "dead", "dead_tick": w.tick}
	game.hud._bars_t = 1.0
	await frames(14)
	check(hero_tile.dimmed and hero_tile.badge.ends_with("s"), "A10 héros tombé : rappel dans N s affiché (%s)" % hero_tile.badge)
	# --- barre de pouvoirs : 2 touchers, aperçu du rayon
	CivEvolution.state(w, 0)["powers"]["eclaireurs"] = {"ready_tick": 0}
	game.hud._bars_t = 1.0
	await frames(14)
	var power_tile: TouchTile = bars.power_tiles["eclaireurs"]
	check(power_tile.visible, "A11 pouvoir débloqué visible dans la barre")
	game.focus(base)
	await frames(3)
	before = touches_used
	await press(power_tile)
	check(game.mode == "civ_power" and game.civ_power_key == "eclaireurs", "A12 toucher le pouvoir : mode ciblage")
	game.path_view.rebuild()
	check(game.path_view.line_count >= 56, "A13 aperçu du rayon au sol pendant le ciblage (%d segments)" % game.path_view.line_count)
	var cast_at: Vector2 = base + Vector2(4, 2)
	await tap(ground(cast_at))
	var used: bool = CivEvolution.power_wait(w, 0, "eclaireurs") > 0.0
	check(used and game.mode == "", "A14 toucher la cible : pouvoir lancé (2 touchers au total)")
	count_touches("lancer_un_pouvoir", before, "2 touchers")
	game.hud._bars_t = 1.0
	await frames(14)
	check(power_tile.ring >= 0.0 and power_tile.ring < 1.0, "A15 anneau de recharge affiché")
	# --- Retour annule le ciblage
	CivEvolution.state(w, 0)["powers"]["ravitaillement"] = {"ready_tick": 0}
	game.hud._bars_t = 1.0
	await frames(14)
	await press(bars.power_tiles["ravitaillement"])
	game._back_action()
	check(game.mode == "", "A16 Retour : ciblage annulé sans lancer le pouvoir")
	check(CivEvolution.power_wait(w, 0, "ravitaillement") <= 0.0, "A17 aucun pouvoir dépensé par l'annulation")
