extends "res://lab/ui_test_base.gd"
## 0.17 — Lot UI-1 : sélection au pouce dans la vraie scène (double appui, rectangle sans bouton, sélection
## additive, barre de sélection, inactifs, armée, héros, groupes de contrôle) et absence d'ordre involontaire.

func result_key() -> String:
	return "UI_SELECTION_RESULT"

func run() -> void:
	var w: SimWorld = game.world
	var base: Vector2 = home() + Vector2(6, -7)
	var spears: Array = spawn("lancier", base, 6)
	var archers: Array = spawn("tireur", base + Vector2(0, 4), 4)
	var workers: Array = spawn("ouvrier", base + Vector2(6, 2), 3, false)
	var hero: Array = spawn("heros_antique", base + Vector2(-3, 1), 1, false)
	game.focus(base + Vector2(2, 2))
	game.cam_zoom_goal = 28.0
	game.cam_dist = 28.0
	game._update_camera()
	await frames(6)
	var spear: SimWorld.Unit = w.units[spears[2]]
	# --- toucher simple puis double appui
	await tap(screen(spear.pos))
	check(game.sel_squad == spear.squad_id, "S01 toucher une unité : son escouade est sélectionnée")
	await wait(0.45)
	var before: int = touches_used
	await tap(screen(spear.pos))
	await tap(screen(spear.pos))
	var spear_count: int = 0
	for u in game.selected_units():
		if u.type == "lancier": spear_count += 1
	check(spear_count >= 6 and game.selected_units().size() == spear_count, "S02 double appui : tous les lanciers visibles à l'écran (%d)" % spear_count)
	count_touches("tous_les_memes_a_l_ecran", before, "1 à 2 touchers")
	# --- rectangle sans bouton : glissé démarré sur une unité alliée
	await wait(0.45)
	game.clear_selection()
	var archer: SimWorld.Unit = w.units[archers[0]]
	var corner: Vector2 = screen(w.units[archers[3]].pos) + Vector2(40, 40)
	var cam_before: Vector3 = game.cam_target
	await swipe(screen(archer.pos), corner)
	var archers_selected: int = 0
	for u in game.selected_units():
		if u.type == "tireur": archers_selected += 1
	check(archers_selected >= 3 and game.cam_target.is_equal_approx(cam_before), "S03 glissé depuis une unité alliée : rectangle de sélection, caméra immobile (%d tireurs)" % archers_selected)
	# --- rectangle par appui long puis glissé, depuis le sol
	game.clear_selection()
	var empty_start: Vector2 = screen(base + Vector2(-2, -3))
	touch(0, empty_start, true)
	await wait(0.65)
	var end: Vector2 = screen(base + Vector2(5, 6))
	var last: Vector2 = empty_start
	for i in range(1, 9):
		var p: Vector2 = empty_start.lerp(end, float(i) / 8.0)
		drag(0, p, p - last)
		last = p
		await frames(1)
	touch(0, end, false)
	await frames(3)
	check(game.selected_units().size() >= 8 and game.cam_target.is_equal_approx(cam_before), "S04 appui long puis glissé : rectangle sans bouton (%d unités)" % game.selected_units().size())
	# --- glisser depuis le sol (sans appui long) : la caméra bouge, aucune sélection ni ordre
	var selected_before: Array = game.selected_ids()
	var orders_before: String = UnitCommands.state_text(w)
	await swipe(screen(base + Vector2(-6, 8)), screen(base + Vector2(-6, 8)) + Vector2(-160, 0))
	check(not game.cam_target.is_equal_approx(cam_before) and game.selected_ids() == selected_before and UnitCommands.state_text(w) == orders_before, "S05 glisser au sol : caméra déplacée, sélection et ordres inchangés")
	game.focus(base + Vector2(2, 2))
	await frames(3)
	# --- pincement : aucun ordre
	touch(0, Vector2(500, 300), true)
	touch(1, Vector2(700, 300), true)
	await frames(1)
	for i in 6:
		drag(0, Vector2(500 - i * 12, 300), Vector2(-12, 0))
		drag(1, Vector2(700 + i * 12, 300), Vector2(12, 0))
		await frames(1)
	touch(1, Vector2(772, 300), false)
	touch(0, Vector2(428, 300), false)
	await frames(3)
	check(UnitCommands.state_text(w) == orders_before and game.selected_ids() == selected_before, "S06 pincement à deux doigts : aucun ordre involontaire")
	game.focus(base + Vector2(2, 2))
	game.cam_zoom_goal = 28.0
	game.cam_dist = 28.0
	game._update_camera()
	await frames(3)
	# --- sélection additive
	game.select_squad(spear.squad_id)
	await press(game.hud.add_btn)
	check(game.add_mode, "S07 bouton ＋ : sélection additive active")
	await tap(screen(w.units[archers[1]].pos))
	check(game.selected_ids().has(archers[1]) and game.selected_ids().has(spears[0]), "S08 toucher en mode additif : l'unité s'ajoute à la sélection")
	await wait(0.45)
	await tap(screen(w.units[archers[1]].pos))
	check(not game.selected_ids().has(archers[1]), "S09 second toucher : l'unité est retirée")
	await press(game.hud.add_btn)
	# --- barre de sélection : garder un type, retirer un type
	game.select_many(spears + archers)
	await frames(14)
	var tiles: Array = game.hud.selection_bar.get_children()
	check(tiles.size() == 2, "S10 barre de sélection : un portrait par type (%d)" % tiles.size())
	var archer_tile: TouchTile = null
	for t in tiles:
		if String(t.get_meta("type", "")) == "tireur": archer_tile = t
	if archer_tile != null:
		await hold(center_of(archer_tile), 0.65)
	check(game.selected_units().size() == 6, "S11 appui long sur un portrait : ce type est retiré")
	game.select_many(spears + archers)
	await frames(14)
	for t in game.hud.selection_bar.get_children():
		if String(t.get_meta("type", "")) == "tireur": archer_tile = t
	await press(archer_tile)
	check(game.selected_units().size() == 4, "S12 toucher un portrait : ne garder que ce type")
	# --- ouvriers inactifs, armée, héros
	for id in workers:
		var wk: SimWorld.Unit = w.units[id]
		w._release_worker_job(wk)
		wk.task = ""
		wk.direct = false
		wk.manual = false
	game.hud._refresh_t = 1.0
	await frames(14)
	before = touches_used
	await press(game.hud.idle_btn)
	var idle_selected: int = 0
	for u in game.selected_units():
		if Rules.unit_has(u.type, "worker"): idle_selected += 1
	check(idle_selected >= 3, "S13 « Inactifs » : tous les ouvriers inactifs sélectionnés en 1 toucher (%d)" % idle_selected)
	count_touches("ouvriers_inactifs", before, "1 toucher")
	var cam_first: Vector3 = game.cam_target
	await press(game.hud.idle_btn)
	check(not game.cam_target.is_equal_approx(cam_first) or idle_selected == 1, "S14 toucher suivant : la caméra suit l'ouvrier inactif suivant")
	before = touches_used
	await press(game.hud.army_select_btn)
	var military: int = 0
	for u in game.selected_units():
		if Rules.unit_has(u.type, "military"): military += 1
	check(military >= 10 and military == game.selected_units().size(), "S15 « Armée » : toute l'armée en 1 toucher (%d)" % military)
	count_touches("toute_l_armee", before, "1 à 2 touchers")
	await press(game.hud.hero_btn)
	check(game.selected_ids() == hero, "S16 « Héros » : le héros est sélectionné")
	# --- groupes de contrôle
	game.select_many(archers)
	var slot: TouchTile = game.hud.control_groups.tiles[0]
	await hold(center_of(slot), 0.65)
	check((game.hud.control_groups.groups[0]["units"] as Array).size() == 4, "S17 appui long sur un groupe : sélection enregistrée")
	game.clear_selection()
	await frames(14)
	before = touches_used
	await press(slot)
	check(game.selected_ids().size() == 4 and game.selected_ids().has(archers[0]), "S18 toucher le groupe : sélection rappelée en 1 toucher")
	count_touches("rappel_groupe", before, "1 toucher")
	game.focus(base + Vector2(-30, 20))
	await wait(0.45)
	await tap(center_of(slot))
	await tap(center_of(slot))
	check(game.cam_target.distance_to(Vector3(w.units[archers[0]].pos.x, 0, w.units[archers[0]].pos.y)) < 6.0, "S19 double toucher : rappel et caméra centrée sur le groupe")
	game.hud.control_groups.save(w.seed_value, w.tick)
	game.hud.control_groups.groups[0] = {"world": "", "squad": -1, "units": []}
	check(game.hud.control_groups.load_for(w.seed_value, w.tick) and (game.hud.control_groups.groups[0]["units"] as Array).size() == 4, "S20 groupes enregistrés avec la sauvegarde et relus à l'identique")
	check(not game.hud.control_groups.load_for(w.seed_value, w.tick + 1), "S21 groupes ignorés pour une autre sauvegarde (même graine, autre tick)")
	# --- panneau ouvert : aucun ordre sous lui
	game.select_squad(spear.squad_id)
	await frames(2)
	orders_before = UnitCommands.state_text(w)
	game.civ_panel.open()
	await frames(4)
	await tap(center_of(game.civ_panel))
	check(UnitCommands.state_text(w) == orders_before, "S22 panneau ouvert : un toucher dessus ne donne aucun ordre au terrain")
	game.civ_panel.hide()
	# --- cibles tactiles ≥ 48 px dans les nouveaux éléments
	var small: Array = []
	for node in [game.hud.quick_panel, game.hud.command_card, game.hud.control_groups, game.hud.command_bars]:
		for b in (node as Node).find_children("*", "Control", true, false):
			if (b is Button or b is TouchTile) and (b as Control).is_visible_in_tree():
				var s: Vector2 = (b as Control).size
				if s.x < 47.5 or s.y < 47.5:
					small.append("%s %s" % [(b as Control).name, str(s)])
	check(small.is_empty(), "S23 nouvelles cibles tactiles ≥ 48 px (%s)" % ", ".join(small))
	# --- barres de vie au-dessus des unités sélectionnées ou blessées (doublées d'une forme pour l'ennemi)
	game.focus(base + Vector2(2, 2))
	await frames(3)
	game.clear_selection()
	(w.units[spears[0]] as SimWorld.Unit).hp *= 0.5
	game.path_view._bars()
	var wounded_only: int = game.path_view.bar_count
	game.select_many(archers)
	game.path_view._bars()
	check(wounded_only >= 1 and game.path_view.bar_count >= wounded_only + 4, "S24 barres de vie : unité blessée et unités sélectionnées (%d puis %d)" % [wounded_only, game.path_view.bar_count])
	# --- suivi caméra de la sélection
	game.hud.command_card.run("center")
	check(game.follow_selection, "S25 « Suivi » : la caméra suit la sélection")
	game.hud.command_card.run("center")
	check(not game.follow_selection, "S26 second toucher : suivi arrêté")
