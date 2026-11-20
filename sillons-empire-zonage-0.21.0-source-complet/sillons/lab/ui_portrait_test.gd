extends "res://lab/ui_test_base.gd"
## 0.18 — Paysage et portrait dans la vraie scène : orientation capteur, base d'échelle selon le sens de l'écran,
## aucun élément hors écran ni chevauchement des barres principales, sélection et commandes au toucher en portrait,
## panneaux (Bâtir, pose, fiche, Civilisation, Ville), rotation en cours de partie sans fermer les panneaux ni toucher
## à la simulation, téléphone 740×1600 et 1110×2400, tablette, main gauche, échelle 130 %, globe, système, galaxie,
## orbite et menu principal. 0.18.1 : mini-carte carrée, bouton « + » lisible.

const PHONE_L := Vector2i(1600, 740)
const PHONE_P := Vector2i(740, 1600)
const PHONE_P_HI := Vector2i(1110, 2400)
const TABLET_L := Vector2i(2560, 1600)
const TABLET_P := Vector2i(1600, 2560)

func result_key() -> String:
	return "UI_PORTRAIT_RESULT"

func resize(size: Vector2i) -> void:
	get_root().size = size
	await frames(6)

func viewport_size() -> Vector2:
	return game.hud.root.get_viewport_rect().size

func _in_scroll(node: Node, stop: Node) -> bool:
	var n: Node = node.get_parent()
	while n != null and n != stop:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false

func overflow(root_control: Control) -> Array:
	## Éléments visibles qui débordent de l'écran : enfants directs du HUD et tous les boutons hors zones défilantes.
	var bad: Array = []
	if root_control == null or not root_control.is_visible_in_tree():
		return bad
	var vp: Vector2 = root_control.get_viewport_rect().size
	var nodes: Array = root_control.get_children()
	nodes.append_array(root_control.find_children("*", "Button", true, false))
	for node in nodes:
		var c: Control = node as Control
		if c == null or not c.is_visible_in_tree() or c.size.x < 1.0 or c.size.y < 1.0:
			continue
		if _in_scroll(c, root_control):
			continue
		if ResponsiveLayout.outside(c, vp):
			bad.append("%s %s %s" % [c.name, (c as Button).text if c is Button else "", str(c.get_global_rect())])
	return bad

func overlap(a: Control, b: Control) -> bool:
	if a == null or b == null or not a.is_visible_in_tree() or not b.is_visible_in_tree():
		return false
	## Contenus qui se chevauchent (les cadres décoratifs, 10 points de marge intérieure, peuvent se toucher).
	return a.get_global_rect().grow(-10.0).intersects(b.get_global_rect().grow(-10.0))

func main_bars_overlap() -> Array:
	var h = game.hud
	var named: Array = [["haut", h.top_panel], ["mini-carte", h.minimap_panel], ["groupes", h.groups_panel],
		["Bâtir", h._root_child(h.build_btn)], ["rangée rapide", h.quick_panel], ["sélection", h.sel_panel],
		["commandes", h.command_card], ["héros/pouvoirs", h.command_bars], ["armées", h._root_child(h.squad_toggle)]]
	var bad: Array = []
	for i in named.size():
		for j in range(i + 1, named.size()):
			if overlap(named[i][1] as Control, named[j][1] as Control):
				bad.append("%s/%s" % [named[i][0], named[j][0]])
	return bad

func layout_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var h = game.hud
	for c in [h.top_panel, h.minimap_panel, h.groups_panel, h.quick_panel, h.sel_panel, h.command_card, h.command_bars]:
		var k: Control = c as Control
		parts.append("%s:%.0f,%.0f,%.0f,%.0f|%.2f,%.2f,%.2f,%.2f" % [k.name, k.offset_left, k.offset_top, k.offset_right, k.offset_bottom, k.anchor_left, k.anchor_top, k.anchor_right, k.anchor_bottom])
	return ";".join(parts)

func ground_hit(screen_pos: Vector2) -> Vector2:
	var cam: Camera3D = game.cam
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	if dir.y >= -0.0001:
		return Vector2(-9999, -9999)
	var t: float = -from.y / dir.y
	var p: Vector3 = from + dir * t
	return Vector2(p.x, p.z)

func run() -> void:
	var w: SimWorld = game.world
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)) == DisplayServer.SCREEN_SENSOR, "R01 orientation « capteur » : paysage et portrait autorisés")

	# --- paysage de référence
	await resize(PHONE_L)
	check(game.hud.portrait_mode == 0 and get_root().content_scale_size == ResponsiveLayout.LANDSCAPE_BASE, "R02 téléphone en paysage : base 1280×600")
	var landscape_sig: String = layout_signature()
	check(overflow(game.hud.root).is_empty(), "R03 paysage : aucun élément hors écran %s" % str(overflow(game.hud.root)))
	var mm: TextureRect = game.hud.minimap
	check(absf(mm.size.x - mm.size.y) < 1.5, "R03b paysage : mini-carte carrée (%s)" % str(mm.size))
	check(game.hud.add_btn.text == "+", "R03c bouton d'ajout : « + » des polices livrées (le « ＋ » pleine chasse s'affichait en carré sur Android)")

	# --- portrait
	await resize(PHONE_P)
	var vp: Vector2 = viewport_size()
	check(game.hud.portrait_mode == 1 and get_root().content_scale_size == ResponsiveLayout.PORTRAIT_BASE and vp.x < vp.y, "R04 téléphone en portrait : base 600×1280, interface à la même taille physique (%s)" % str(vp))
	check(overflow(game.hud.root).is_empty(), "R05 portrait : aucun élément hors écran %s" % str(overflow(game.hud.root)))
	check(main_bars_overlap().is_empty(), "R06 portrait : barres principales sans chevauchement %s" % str(main_bars_overlap()))
	check(absf(mm.size.x - mm.size.y) < 1.5 and mm.size.x >= 150.0, "R06b portrait : mini-carte carrée et plus grande (%s)" % str(mm.size))
	await tap(center_of(mm))
	await frames(2)
	var map_mid := Vector2(w.map_size * 0.5, w.map_size * 0.5)
	check(Vector2(game.cam_target.x, game.cam_target.z).distance_to(map_mid) < w.map_size * 0.08, "R06c portrait : toucher le centre de la mini-carte centre la vue sur la carte (%s)" % str(game.cam_target))
	var min_h: float = 999.0
	for node in game.hud.root.find_children("*", "Button", true, false):
		var b: Button = node as Button
		if b.is_visible_in_tree() and b.text != "":
			min_h = minf(min_h, b.size.y)
	check(min_h >= 44.0, "R07 portrait : boutons d'au moins 44 points de haut (%.0f)" % min_h)

	# vue du terrain : centre de l'écran et haut de la zone de jeu sur la carte (pas de vide au-dessus du terrain)
	game.cam_target = Vector3(w.map_size * 0.5, 0.0, w.map_size * 0.5)
	game._update_camera()
	await frames(2)
	var mid: Vector2 = ground_hit(vp * 0.5)
	var upper: Vector2 = ground_hit(Vector2(vp.x * 0.5, vp.y * 0.32))
	var inside := func(p: Vector2) -> bool: return p.x >= 0.0 and p.y >= 0.0 and p.x <= w.map_size and p.y <= w.map_size
	check(inside.call(mid) and inside.call(upper), "R08 portrait : vue plus plongeante, le terrain remplit la zone de jeu (%s, %s)" % [str(mid), str(upper)])

	# sélection et commandes au toucher en portrait
	var at: Vector2 = home() + Vector2(5, 4)
	var ids: Array = spawn("lancier", at, 4)
	await frames(2)
	game.cam_target = Vector3(at.x, 0.0, at.y)
	game._update_camera()
	await frames(4)
	var before: int = touches_used
	await tap(screen(game.world.units[int(ids[0])].pos))
	await wait(0.3)
	check(game.selected_ids().size() >= 1 and game.hud.command_card.visible and game.hud.sel_panel.visible, "R09 portrait : un toucher sélectionne, fiche de sélection et carte de commandes affichées (%d toucher ; sel=%s carte=%s fiche=%s point=%s)" % [touches_used - before, str(game.selected_ids()), str(game.hud.command_card.visible), str(game.hud.sel_panel.visible), str(screen(game.world.units[int(ids[0])].pos))])
	check(overflow(game.hud.root).is_empty() and main_bars_overlap().is_empty(), "R10 portrait avec sélection : rien hors écran, rien ne se chevauche %s %s" % [str(overflow(game.hud.root)), str(main_bars_overlap())])
	var card_rect: Rect2 = game.hud.command_card.get_global_rect()
	check(card_rect.size.x >= vp.x - 20.0 and card_rect.end.y >= vp.y - 12.0, "R11 portrait : carte de commandes pleine largeur, en bas, sous le pouce")
	var marcher: Button = button("Marcher")
	if marcher != null:
		await press(marcher)
		await frames(2)
		var goal: Vector2 = at + Vector2(6, -3)
		await tap(ground(goal))
		await frames(3)
		var u: SimWorld.Unit = game.world.units[int(ids[0])]
		var squad_order: String = String((game.world.squads[u.squad_id] as SimWorld.Squad).order.get("type", "")) if game.world.squads.has(u.squad_id) else ""
		check(String(u.order.get("type", "")) == "move" or squad_order == "move", "R12 portrait : Marcher puis toucher au sol donne l'ordre (%s / %s)" % [String(u.order.get("type", "")), squad_order])
	else:
		check(false, "R12 bouton Marcher introuvable en portrait")
	game.clear_selection()
	await frames(3)

	# Bâtir et pose
	await press(game.hud.build_btn)
	await frames(4)
	check(game.hud.build_panel.visible and overflow(game.hud.root).is_empty(), "R13 portrait : panneau Bâtir entièrement à l'écran %s" % str(overflow(game.hud.root)))
	var house_btn: Button = null
	for node in game.hud.build_grid.get_children():
		var bb: Button = node as Button
		if bb != null and bb.visible and not bb.disabled:
			house_btn = bb
			break
	if house_btn != null:
		await press(house_btn)
		await frames(3)
		var cell: Vector2i = free_cell(String(house_btn.get_meta("type")), home() + Vector2(-6, 6))
		if cell.x >= 0:
			await tap(ground(Vector2(cell) + Vector2.ONE))
			await frames(3)
		check(game.hud._root_child(game.hud.place_bar).visible and overflow(game.hud.root).is_empty(), "R14 portrait : barre de pose (Valider, Ligne, Plusieurs) à l'écran %s" % str(overflow(game.hud.root)))
		game._back_action()
		await frames(2)
	else:
		check(false, "R14 aucun bâtiment disponible")

	# fiche de bâtiment
	var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
	game.sel_building = cc.id
	game.hud.selection_changed()
	await frames(4)
	check(game.hud.building_drawer.visible and overflow(game.hud.root).is_empty(), "R15 portrait : fiche du centre à l'écran %s" % str(overflow(game.hud.root)))
	var drawer_rect: Rect2 = game.hud.building_drawer.get_global_rect()
	check(drawer_rect.size.x >= vp.x - 20.0, "R16 portrait : la fiche devient un panneau du bas, pleine largeur")

	# rotation pendant que la fiche est ouverte : fiche toujours ouverte, simulation intacte
	var state_before: String = UnitCommands.state_text(w)
	await resize(PHONE_L)
	check(game.hud.building_drawer.visible and game.hud.portrait_mode == 0, "R17 rotation vers paysage : fiche toujours ouverte")
	check(UnitCommands.state_text(w) == state_before, "R18 rotation : simulation inchangée")
	check(layout_signature() == landscape_sig, "R19 retour en paysage : disposition d'origine retrouvée à l'identique")
	await resize(PHONE_P)
	game.sel_building = -1
	game.hud.selection_changed()
	await frames(3)

	# panneaux plein écran
	for entry in [["Civilisation", game.civ_panel], ["Ville", game.city_panel]]:
		var panel = entry[1]
		if panel == null:
			check(false, "R20 panneau %s absent" % entry[0])
			continue
		panel.open()
		await frames(4)
		var pr: Rect2 = (panel as Control).get_global_rect()
		check((panel as Control).visible and pr.position.x >= 0.0 and pr.end.x <= vp.x + 1.0 and pr.end.y <= vp.y + 1.0 and pr.size.x >= vp.x - 20.0, "R20 portrait : panneau %s en pleine largeur, à l'écran" % entry[0])
		await resize(PHONE_L)
		check((panel as Control).visible, "R21 rotation : panneau %s resté ouvert" % entry[0])
		await resize(PHONE_P)
		(panel as Control).hide()
		await frames(3)

	# armée mêlée (plusieurs types) : la fiche de sélection s'allonge sans recouvrir la rangée rapide
	var mixed: Array = spawn("lancier", at + Vector2(2, -4), 2)
	for kind in ["archer", "eclaireur", "ouvrier"]:
		if Rules.UNITS.has(kind):
			mixed.append_array(spawn(kind, at + Vector2(3, -5), 2, false))
	game.clear_selection()
	for id in mixed:
		if int(id) >= 0:
			game.sel_units.append(int(id))
	game.hud.selection_changed()
	await wait(0.3)
	check(game.hud.sel_panel.visible and main_bars_overlap().is_empty() and overflow(game.hud.root).is_empty(), "R10b portrait, sélection de plusieurs types : rien ne se chevauche %s %s" % [str(main_bars_overlap()), str(overflow(game.hud.root))])
	game.clear_selection()
	await frames(2)

	# grand téléphone, tablette
	for size in [PHONE_P_HI, TABLET_L, TABLET_P]:
		await resize(size)
		var spawned: Array = spawn("lancier", at + Vector2(-3, 2), 2)
		game.select_squad((game.world.units[int(spawned[0])] as SimWorld.Unit).squad_id)
		await wait(0.3)
		check(overflow(game.hud.root).is_empty() and main_bars_overlap().is_empty(), "R22 %d×%d : rien hors écran, rien ne se chevauche %s %s" % [size.x, size.y, str(overflow(game.hud.root)), str(main_bars_overlap())])
		game.clear_selection()
		await frames(2)

	# main gauche et échelle 130 % en portrait
	await resize(PHONE_P)
	GameConfig.left_handed = true
	game.hud._apply_ui_preferences()
	await frames(4)
	var mm_rect: Rect2 = game.hud.minimap_panel.get_global_rect()
	check(overflow(game.hud.root).is_empty() and mm_rect.position.x < viewport_size().x * 0.5, "R23 portrait main gauche : barres en miroir, rien hors écran %s" % str(overflow(game.hud.root)))
	GameConfig.left_handed = false
	GameConfig.ui_scale = 1.3
	game.hud._apply_ui_preferences()
	await frames(6)
	check(is_equal_approx(get_root().content_scale_factor, ResponsiveLayout.PORTRAIT_SCALE_MAX), "R24 portrait : échelle 130 %% ramenée à 115 %% (%.2f)" % get_root().content_scale_factor)
	var spawned_big: Array = spawn("lancier", at + Vector2(-2, 3), 2)
	game.select_squad((game.world.units[int(spawned_big[0])] as SimWorld.Unit).squad_id)
	await wait(0.3)
	check(overflow(game.hud.root).is_empty() and main_bars_overlap().is_empty(), "R25 portrait grande échelle, sélection : rien hors écran, rien ne se chevauche %s %s" % [str(overflow(game.hud.root)), str(main_bars_overlap())])
	game.clear_selection()
	await resize(PHONE_L)
	check(is_equal_approx(get_root().content_scale_factor, 1.3), "R26 retour en paysage : échelle 130 % rétablie")
	await resize(PHONE_P)
	GameConfig.ui_scale = 1.0
	game.hud._apply_ui_preferences()
	await frames(4)

	# globe, système, galaxie, orbite
	var c = game.campaign
	c.ages[0] = 10
	for tech in ViewTechnology.RESEARCH_ORDER:
		(c.technologies[0] as Dictionary)[tech] = true
	game.enter_planet_overview()
	await frames(8)
	check(game.planet_mode and game.planet_hud != null and overflow(game.planet_hud.root).is_empty(), "R27 globe en portrait : rien hors écran %s" % (str(overflow(game.planet_hud.root)) if game.planet_hud != null else "sans HUD"))
	for level in ["system", "galaxy", "orbit"]:
		game.enter_space_overview(level)
		await frames(8)
		var hud_root: Control = null
		if level == "orbit" and game.orbit_hud != null:
			hud_root = game.orbit_hud.root
		elif level == "galaxy" and game.galaxy_hud != null:
			hud_root = game.galaxy_hud.root
		elif game.space_hud != null:
			hud_root = game.space_hud.root
		check(game.space_mode == level and hud_root != null and overflow(hud_root).is_empty(), "R28 vue %s en portrait : rien hors écran %s" % [level, str(overflow(hud_root)) if hud_root != null else "sans HUD"])
	game.leave_space_overview(true)
	await frames(8)
	check(not game.planet_mode and game.space_mode == "" and overflow(game.hud.root).is_empty(), "R29 retour au terrain en portrait : interface en place")

	# menu principal
	var menu: Control = (load("res://game/main_menu.tscn") as PackedScene).instantiate() as Control
	get_root().add_child(menu)
	await frames(6)
	check(overflow(menu).is_empty(), "R30 menu principal en portrait : colonnes empilées, rien hors écran %s" % str(overflow(menu)))
	menu._toggle_settings()
	await frames(4)
	check(overflow(menu).is_empty(), "R30b réglages en portrait : rien hors écran %s" % str(overflow(menu)))
	menu._toggle_settings()
	menu._toggle_laboratory()
	await frames(4)
	check(overflow(menu).is_empty(), "R30c laboratoire en portrait : rien hors écran %s" % str(overflow(menu)))
	menu._toggle_laboratory()
	await frames(2)
	await resize(PHONE_L)
	check(overflow(menu).is_empty(), "R31 menu principal en paysage : rien hors écran %s" % str(overflow(menu)))
	menu.queue_free()
	await frames(2)
