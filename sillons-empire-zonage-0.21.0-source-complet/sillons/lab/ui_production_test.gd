extends "res://lab/ui_test_base.gd"
## 0.17 — Lot UI-3 : production (×5, appui maintenu, production répétée, file annulable élément par élément,
## production globale) et ralliement des ouvriers sur une ressource, dans la vraie scène.

func result_key() -> String:
	return "UI_PRODUCTION_RESULT"

func run() -> void:
	var w: SimWorld = game.world
	w.teams[0].res = {"food": 20000.0, "wood": 20000.0, "ore": 20000.0}
	w.teams[0].pop_cap = 200
	var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
	var cell: Vector2i = free_cell("caserne", cc.center + Vector2(6, -8))
	var r: Dictionary = w.issue({"t": "lab_building", "team": 0, "type": "caserne", "cell": [cell.x, cell.y], "complete": true})
	var barracks: SimWorld.Building = w.buildings[int(r["id"])]
	game.focus(barracks.center)
	await frames(3)
	game.sel_building = barracks.id
	game.hud.selection_changed()
	await frames(6)
	var drawer: BuildingDrawer = game.hud.building_drawer
	check(drawer.visible and not drawer.cards.is_empty(), "P01 fiche de la caserne ouverte avec ses cartes d'unités")
	# --- ×5 : un toucher pour cinq unités
	var batch_button: Button = in_drawer("×1")
	await press(batch_button)
	check(drawer.batch == 5, "P02 bascule ×5")
	var before: int = touches_used
	await press(drawer.cards[0].picture)
	check(barracks.queue.size() == 5, "P03 ×5 : cinq unités en file en 1 toucher (%d)" % barracks.queue.size())
	count_touches("former_5_unites_x5", before, "1 toucher")
	await frames(16)
	check(drawer.cards[0].caption.text.contains("5 en file"), "P04 badge « 5 en file » sur la carte de l'unité")
	# --- file visible, annulation d'un élément précis avec remboursement
	await frames(8)
	check(drawer.queue_row.get_child_count() == 5, "P05 file visible : un élément par unité en formation")
	var food_before: float = float(w.teams[0].res["food"])
	await press(drawer.queue_row.get_child(2))
	check(barracks.queue.size() == 4 and float(w.teams[0].res["food"]) > food_before, "P06 toucher un élément de la file : annulé et remboursé")
	barracks.queue.clear()
	drawer._queue_signature = ""
	await press(in_drawer("×5"))
	check(drawer.batch == 1, "P07 retour à ×1")
	# --- appui maintenu : formation en continu
	before = touches_used
	await hold(center_of(drawer.cards[0].picture), 2.3)
	check(barracks.queue.size() >= 4, "P08 appui maintenu : formation en continu (%d en file)" % barracks.queue.size())
	count_touches("former_5_unites_appui_maintenu", before, "1 toucher")
	barracks.queue.clear()
	# --- production répétée
	await frames(8)
	await press(in_drawer("Répéter : non"))
	check(barracks.repeat_unit != "", "P09 production répétée activée depuis la fiche (%s)" % barracks.repeat_unit)
	game.paused = false
	await wait(1.5)
	game.paused = true
	check(not barracks.queue.is_empty(), "P10 la caserne relance seule la production (file non vide)")
	await frames(8)
	var repeat_button: Button = in_drawer("Répéter", true)
	while repeat_button != null and barracks.repeat_unit != "":
		await press(repeat_button)
		await frames(8)
		repeat_button = in_drawer("Répéter", true)
	check(barracks.repeat_unit == "", "P11 production répétée désactivée en parcourant les choix")
	barracks.queue.clear()
	# --- production globale
	game.clear_selection()
	await frames(14)
	await press(game.hud.produce_btn)
	check(game.hud.production_panel.visible, "P12 « Former » : panneau de production globale")
	await frames(14)
	var spear_card: DataCard = null
	for card in game.hud.production_panel.list.get_children():
		if card is DataCard and (card as DataCard).key == "lancier":
			spear_card = card
	check(spear_card != null, "P13 l'unité « lancier » est proposée sans chercher la caserne")
	if spear_card != null:
		(spear_card.get_parent().get_parent() as ScrollContainer).ensure_control_visible(spear_card)
		await frames(3)
		await press(spear_card.picture)
	var queued_spears: int = 0
	for b in w.team_buildings(0, "", true):
		queued_spears += b.queue.count("lancier")
	check(queued_spears == 1, "P14 formée dans le producteur le moins chargé qui l'accepte (1 lancier en file)")
	await press(game.hud.production_panel.find_children("*", "Button", true, false).back())
	# --- ralliement des ouvriers sur une ressource
	var tree: SimWorld.ResNode = null
	for n in w.nodes.values():
		if n.res == "wood" and n.amount > 0.0 and w.is_explored_by(0, n.pos):
			if tree == null or n.pos.distance_to(cc.center) < tree.pos.distance_to(cc.center):
				tree = n
	game.sel_building = cc.id
	game.hud.selection_changed()
	await frames(10)
	var rally_button: Button = in_drawer("Ouvriers → ressource")
	check(rally_button != null, "P15 bouton « Ouvriers → ressource » sur le centre")
	if rally_button != null and tree != null:
		await press(rally_button)
		game.focus(tree.pos)
		await frames(3)
		await tap(screen(tree.pos))
	check(tree != null and cc.rally_node == tree.id, "P16 ralliement des ouvriers sur la ressource touchée")

func in_drawer(text: String, prefix: bool = false) -> Button:
	for node in game.hud.building_drawer.find_children("*", "Button", true, false):
		var b: Button = node as Button
		if b.is_visible_in_tree() and (b.text == text or (prefix and b.text.begins_with(text))):
			return b
	return null
