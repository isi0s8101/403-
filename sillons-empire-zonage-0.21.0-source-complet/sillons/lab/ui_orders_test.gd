extends "res://lab/ui_test_base.gd"
## 0.17 — Lot UI-2 : carte de commandes, ordres programmés A → B → C au pouce (bouton « Enchaîner »),
## étapes visibles et modifiables au sol, boucle, commandes du § 5.12 par boutons, pause active,
## ouvriers « bâtir A puis B puis C », pose en ligne, 0 ordre involontaire.

func result_key() -> String:
	return "UI_ORDERS_RESULT"

func run() -> void:
	var w: SimWorld = game.world
	var base: Vector2 = home() + Vector2(6, -7)
	var spears: Array = spawn("lancier", base, 4)
	game.focus(base + Vector2(3, 3))
	game.cam_zoom_goal = 30.0
	game.cam_dist = 30.0
	game._update_camera()
	await frames(4)
	var card: CommandCard = game.hud.command_card
	game.select_many(spears)
	await frames(14)
	check(card.visible and card.context() == "army", "O01 carte de commandes : contexte « troupes » affiché pour la sélection")
	# --- assaut en 2 touchers
	var before: int = touches_used
	await press(card.buttons["amove"])
	var target: Vector2 = base + Vector2(8, 0)
	await tap(ground(target))
	var unit: SimWorld.Unit = w.units[spears[0]]
	check(String(unit.order.get("type", "")) == "amove", "O02 « Assaut » puis toucher au sol : attaque-déplacement donnée")
	count_touches("assaut_vers_un_point", before, "2 touchers maximum")
	# --- trajet A → B → C avec Enchaîner
	await frames(14)
	before = touches_used
	await press(card.chain_btn)
	check(card.chain_active, "O03 « Enchaîner » basculé d'un toucher")
	var pts: Array = [base + Vector2(10, -2), base + Vector2(12, 6), base + Vector2(4, 9)]
	for p in pts:
		await tap(ground(p))
		await wait(0.4)
	check(unit.order_steps.size() == 3 and String(unit.order_steps[0]["type"]) == "move", "O04 trajet A → B → C : 3 étapes enregistrées (%d)" % unit.order_steps.size())
	count_touches("trajet_A_B_C", before, "1 bascule + 1 toucher par point")
	await frames(6)
	game.path_view.rebuild()
	check(game.path_view.points.size() == 3 and game.path_view.line_count > 0, "O05 étapes visibles au sol : 3 points numérotés reliés (%d lignes)" % game.path_view.line_count)
	var labels_visible: int = 0
	for l in game.path_view.labels:
		if (l as Label3D).visible: labels_visible += 1
	check(labels_visible >= 3, "O06 numéros 1, 2, 3 affichés au sol")
	await frames(14)
	check(card.chain_btn.text.contains("3/16"), "O07 le bouton affiche le nombre d'étapes (%s)" % card.chain_btn.text)
	# --- boucle et modification par la bulle
	await press(card.loop_btn)
	check(unit.order_loop, "O08 bascule « En boucle »")
	await press(card.chain_btn)
	check(not card.chain_active, "O09 « Enchaîner » désactivé d'un second toucher")
	game.path_view.rebuild()
	var second: Dictionary = {}
	for p in game.path_view.points:
		if int(p["index"]) == 1: second = p
	await tap(screen(second["pos"]))
	check(game.hud.queue_bubble.visible, "O10 toucher un point numéroté : bulle Déplacer / Supprimer / Insérer avant")
	await press(button("Supprimer"))
	check(unit.order_steps.size() == 2, "O11 « Supprimer » : l'étape est retirée (commande simulée)")
	game.path_view.rebuild()
	for p in game.path_view.points:
		if int(p["index"]) == 1: second = p
	await tap(screen(second["pos"]))
	await press(button("Déplacer"))
	var moved_to: Vector2 = base + Vector2(14, 2)
	await tap(ground(moved_to))
	check(unit.order_steps.size() == 2 and Vector2(float(unit.order_steps[1]["pos"][0]), float(unit.order_steps[1]["pos"][1])).distance_to(moved_to) < 1.5, "O12 « Déplacer » : l'étape va au nouveau point")
	game.path_view.rebuild()
	for p in game.path_view.points:
		if int(p["index"]) == 1: second = p
	await tap(screen(second["pos"]))
	await press(button("Insérer avant"))
	await tap(ground(base + Vector2(9, 5)))
	check(unit.order_steps.size() == 3, "O13 « Insérer avant » : une étape est insérée")
	await frames(14)
	await press(card.undo_btn)
	check(unit.order_steps.size() == 2, "O14 « Annuler la dernière étape »")
	# --- ordre sans Enchaîner : remplace la file
	await tap(ground(base + Vector2(2, -4)))
	check(unit.order_steps.is_empty() and String(unit.order.get("type", "")) == "move", "O15 ordre simple sans Enchaîner : la file est remplacée")
	# --- pause active : ordres donnés pendant la pause
	game.paused = false
	await press(game.hud.active_pause_btn)
	check(game.paused, "O16 pause active d'un toucher")
	var tick_before: int = w.tick
	await press(card.chain_btn)
	await tap(ground(base + Vector2(10, 0)))
	await wait(0.4)
	await tap(ground(base + Vector2(10, 8)))
	await frames(5)
	check(unit.order_steps.size() == 2 and w.tick == tick_before, "O17 ordres programmés pendant la pause (temps de jeu arrêté)")
	await press(card.chain_btn)
	await frames(14)
	await press(card.clear_btn)
	check(unit.order_steps.is_empty(), "O18 « Vider la file »")
	# --- commandes du § 5.12 par la carte
	game.select_squad(unit.squad_id)
	await frames(14)
	await press(card.buttons["stop"])
	var s: SimWorld.Squad = w.squads[unit.squad_id]
	check(String(s.order.get("type", "")) == "hold", "O19 « Arrêt » : l'escouade s'arrête")
	await frames(14)
	await press(card.buttons["hold"])
	check(unit.stance == "hold", "O20 « Tenir » : posture tenir")
	await frames(14)
	await press(card.buttons["more"])
	await frames(14)
	await press(card.buttons["formation"])
	check(s.formation == "line", "O21 « Formation » : ligne")
	await frames(14)
	await press(card.buttons["stance"])
	check(unit.stance == "passive", "O22 « Posture » : passe à la suivante (passive après tenir)")
	await frames(14)
	await press(card.buttons["priority"])
	check(unit.target_pref == "ranged", "O23 « Cible » : tireurs en priorité")
	await frames(14)
	await press(card.buttons["back"])
	await frames(14)
	var barracks: Dictionary = w.issue({"t": "lab_building", "team": 0, "type": "caserne", "cell": [int(base.x) + 6, int(base.y) + 10], "complete": true})
	var hall: SimWorld.Building = w.buildings[int(barracks["id"])]
	await frames(2)
	await press(card.buttons["garrison"])
	await tap(screen(hall.center))
	check(String(unit.order_steps[0]["type"]) == "garrison" if not unit.order_steps.is_empty() else false, "O24 « Garnison » puis toucher le bâtiment : ordre de garnison")
	game.select_squad(unit.squad_id)
	await frames(14)
	await press(card.buttons["retreat"])
	check(String(s.order.get("type", "")) == "move" and s.army_role == "Repli", "O25 « Repli » : retour vers la base")
	# --- refus lisible près du doigt, sans effet
	game.select_many(spears)
	await frames(14)
	var state_before: String = UnitCommands.state_text(w)
	await press(card.buttons["more"])
	await frames(14)
	await press(card.buttons["follow"])
	await tap(ground(base + Vector2(-8, -8)))
	check(game.hud.refusal_label.visible and UnitCommands.state_text(w) == state_before, "O26 ordre refusé : raison affichée, aucun effet (« %s »)" % game.hud.refusal_label.text)
	# --- ouvriers : bâtir A puis B puis C (Enchaîner + 3 poses)
	var workers: Array = spawn("ouvrier", base + Vector2(-4, 4), 2, false)
	w.teams[0].res = {"food": 9000.0, "wood": 9000.0, "ore": 9000.0}
	game.select_many(workers)
	await frames(14)
	check(card.context() == "workers", "O27 carte de commandes : contexte « ouvriers »")
	before = touches_used
	await press(card.chain_btn)
	game.start_placement("maison")
	await frames(3)
	var placed_cells: Array = []
	for dy in range(-10, 14):
		for dx in range(-14, 14):
			var c0: Vector2i = Vector2i(int(base.x) + dx, int(base.y) + dy)
			var free: bool = w.build_check(0, "maison", c0) == ""
			for other in placed_cells:
				free = free and (other as Vector2i).distance_to(c0) >= 3.0
			if free and placed_cells.size() < 3 and _on_screen(Vector2(c0) + Vector2(1, 1)):
				placed_cells.append(c0)
	for c in placed_cells:
		await tap(ground(Vector2(c) + Vector2(1.0, 1.0)))
		await frames(2)
	var worker_unit: SimWorld.Unit = w.units[workers[0]]
	var build_steps: int = 0
	for step in worker_unit.order_steps:
		if String(step["type"]) == "build": build_steps += 1
	check(build_steps == 3, "O28 Enchaîner + 3 poses : les ouvriers ont 3 chantiers à la suite (%d)" % build_steps)
	count_touches("trois_batiments_par_les_memes_ouvriers", before, "1 bascule + 3 poses")
	game.cancel_mode()
	await press(card.chain_btn)
	# --- pose en ligne : 1 glissé + 1 validation (palissades : âge II)
	w.teams[0].age = 2
	game.start_placement("palissade")
	await frames(3)
	await press(game.hud.line_btn)
	before = touches_used
	var a: Vector2 = base + Vector2(-14, 10)
	await swipe(ground(a), ground(a + Vector2(6, 0)))
	var foundations: int = w.buildings.size()
	await press(game.hud.place_ok)
	check(w.buildings.size() - foundations >= 4, "O29 pose en ligne : %d palissades en 1 glissé + 1 validation" % (w.buildings.size() - foundations))
	count_touches("ligne_de_murs", before, "1 glissé + 1 validation")
	game.cancel_mode()
	# --- Retour Android : ferme dans l'ordre (bulle, mode, Enchaîner)
	game.select_many(spears)
	await frames(14)
	await press(card.chain_btn)
	game._back_action()
	check(not card.chain_active, "O30 Retour : désactive « Enchaîner »")

func _on_screen(p: Vector2) -> bool:
	var sp: Vector2 = ground(p)
	return sp.x > 120 and sp.y > 120 and sp.x < 900 and sp.y < 420
