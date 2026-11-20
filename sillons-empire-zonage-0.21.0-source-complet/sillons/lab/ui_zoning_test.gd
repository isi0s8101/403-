extends "res://lab/ui_test_base.gd"
## 0.19 — Mode Zonage dans la vraie scène, au doigt : bouton Zones, calque visible seulement pendant le mode, route
## tracée d'un glissé, pinceau (taille 1 à 3), rectangle, parcelle, gomme, annuler, rezonage, pincement sans effet,
## inspection d'un quartier, croissance visible (modèles composés), changement de silhouette avec le niveau,
## fiche d'un bâtiment de zone et quartier historique, retour Android, portrait.

func result_key() -> String:
	return "UI_ZONING_RESULT"

func step_world(n: int) -> void:
	for i in n:
		game.world.step()

func clear_area(a: Vector2i, b: Vector2i) -> void:
	## Terrain dégagé pour la recette (gisements et décor retirés) : les gestes sont éprouvés, pas la carte.
	var w: SimWorld = game.world
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var c := Vector2i(x, y)
			if not w.in_map(c):
				continue
			w.set_terrain(c, SimWorld.TERRAIN_GRASS)
			if w._node_cells.has(c):
				var id: int = int(w._node_cells[c])
				w._node_cells.erase(c)
				w.nodes.erase(id)
			if w._occupied.has(c):
				var bid: int = int(w._occupied[c])
				if w.buildings.has(bid) and (w.buildings[bid] as SimWorld.Building).type != "centre":
					w._destroy_building(w.buildings[bid], -1)

func type_button(code: int) -> Button:
	return game.hud.zoning_panel.type_buttons[code]

func tool_button(key: String) -> Button:
	return game.hud.zoning_panel.tool_buttons[key]

func run() -> void:
	var w: SimWorld = game.world
	w.teams[0].res = {"food": 20000.0, "wood": 20000.0, "ore": 20000.0}
	var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
	var x0: int = cc.cell.x
	var y0: int = cc.cell.y + cc.size
	clear_area(Vector2i(x0 - 8, y0), Vector2i(x0 + 10, y0 + 16))
	game.cam_target = Vector3(float(x0) + 1.0, 0.0, float(y0) + 6.0)
	game.cam_zoom_goal = 30.0
	game._update_camera()
	await frames(6)
	check(UrbanCity.enabled(w) and game.hud.zones_btn.is_visible_in_tree(), "A01 bouton « Zones » dans la rangée Bâtir (partie avec la civilisation)")
	check(game.view.overlay_mode == 0, "A02 hors du mode Zonage : aucun calque coloré sur le terrain")
	var before: int = touches_used
	await press(game.hud.zones_btn)
	await frames(4)
	check(game.zoning_tool.active and String(game.mode) == "zone" and game.hud.zoning_panel.visible and game.view.overlay_mode == 1, "A03 un toucher : mode Zonage, barre et calque affichés (%d toucher)" % (touches_used - before))
	# Route d'un glissé, depuis le bord du centre vers le bas.
	await press(type_button(-1))
	await frames(2)
	var road_before: int = 0
	before = touches_used
	await swipe(screen(Vector2(x0 - 0.5, y0 - 1.5)), screen(Vector2(x0 - 0.5, y0 + 11.5)), 18)
	await frames(3)
	var roads: int = 0
	for y in range(y0 - 2, y0 + 13):
		if UrbanZoning.team_road_at(w, 0, Vector2i(x0 - 1, y)):
			roads += 1
	check(roads >= 10 and roads > road_before, "A04 route tracée d'un seul glissé (%d cases)" % roads)
	var link: PackedByteArray = UrbanZoning.linked(w, 0)
	check(link[w.idx(Vector2i(x0 - 1, y0 + 10))] != 0, "A05 route reliée au centre")
	check(float(game.view.terrain_mat.get_shader_parameter("road_on")) > 0.5, "A06 route dessinée par le terrain (sans géométrie en plus)")
	# Pinceau : habitat moyen le long de la route.
	await press(type_button(2))
	await frames(2)
	check(game.zoning_tool.tool == "brush" and game.zoning_tool.brush == 1, "A06b outil par défaut : pinceau d'une case")
	await swipe(screen(Vector2(x0 + 0.5, y0 + 0.5)), screen(Vector2(x0 + 0.5, y0 + 9.5)), 14)
	await frames(2)
	check(UrbanZoning.zone_at(w, 0, Vector2i(x0, y0 + 5)) == 2 and UrbanZoning.zone_at(w, 0, Vector2i(x0, y0 + 9)) == 2, "A07 pinceau : habitat peint au doigt")
	await press(tool_button("brush"))
	await frames(2)
	check(game.zoning_tool.brush == 2 and tool_button("brush").text.contains("2"), "A08 second toucher sur « Pinceau » : taille 2")
	await swipe(screen(Vector2(x0 + 1.5, y0 + 0.5)), screen(Vector2(x0 + 1.5, y0 + 9.5)), 14)
	await frames(2)
	check(UrbanZoning.zone_at(w, 0, Vector2i(x0 + 2, y0 + 4)) == 2, "A09 pinceau de 2 cases")
	# Rectangle : commerce de l'autre côté de la route.
	await press(type_button(4))
	await press(tool_button("rect"))
	await frames(2)
	await swipe(screen(Vector2(x0 - 2.5, y0 + 0.5)), screen(Vector2(x0 - 1.6 - 0.9, y0 + 3.5)), 8)
	await frames(2)
	var commerce: int = 0
	for y in range(y0, y0 + 4):
		if UrbanZoning.zone_at(w, 0, Vector2i(x0 - 3, y)) == 4:
			commerce += 1
	check(commerce >= 3, "A10 rectangle glissé : commerce peint (%d cases)" % commerce)
	# Parcelle : agriculture d'un toucher.
	await press(type_button(6))
	await press(tool_button("parcel"))
	await frames(2)
	await tap(screen(Vector2(x0 - 2.5, y0 + 6.5)))
	await frames(2)
	check(UrbanZoning.zone_at(w, 0, Vector2i(x0 - 3, y0 + 6)) == 6 and UrbanZoning.zone_at(w, 0, Vector2i(x0 - 2, y0 + 7)) == 6, "A11 parcelle : 2 × 2 cases d'un toucher")
	# Gomme puis annuler.
	await press(type_button(0))
	await frames(2)
	await tap(screen(Vector2(x0 + 0.5, y0 + 8.5)))
	await frames(2)
	check(UrbanZoning.zone_at(w, 0, Vector2i(x0, y0 + 8)) == 0, "A12 gomme : zone retirée")
	await press(button("Annuler"))
	await frames(2)
	check(UrbanZoning.zone_at(w, 0, Vector2i(x0, y0 + 8)) == 2, "A13 annuler : zone rétablie")
	# Rezonage : habitat dense en rectangle sur une partie du quartier.
	await press(type_button(3))
	await press(tool_button("rect"))
	await frames(2)
	await swipe(screen(Vector2(x0 + 0.5, y0 + 0.5)), screen(Vector2(x0 + 1.5, y0 + 1.5)), 6)
	await frames(2)
	check(UrbanZoning.zone_at(w, 0, Vector2i(x0, y0)) == 3, "A14 rezonage : habitat dense")
	# Pincement : aucun coup de pinceau.
	var rev: int = int(w.teams[0].zoning.get("rev", 0))
	await press(tool_button("brush"))
	touch(0, screen(Vector2(x0 + 4.5, y0 + 12.5)), true)
	touch(1, screen(Vector2(x0 + 7.5, y0 + 12.5)), true)
	await frames(2)
	drag(1, screen(Vector2(x0 + 9.5, y0 + 12.5)), Vector2(40, 0))
	await frames(2)
	touch(1, screen(Vector2(x0 + 9.5, y0 + 12.5)), false)
	touch(0, screen(Vector2(x0 + 4.5, y0 + 12.5)), false)
	await frames(3)
	check(UrbanZoning.zone_at(w, 0, Vector2i(x0 + 7, y0 + 12)) == 0, "A15 pincement à deux doigts : la caméra bouge, on ne peint pas plus loin")
	# Inspecter un quartier.
	await press(tool_button("inspect"))
	await frames(2)
	await tap(screen(Vector2(x0 + 0.5, y0 + 4.5)))
	await frames(3)
	check(not game.zoning_tool.inspected.is_empty() and game.hud.zoning_panel.info.text.contains("Habitat"), "A16 inspecter : fiche du quartier (%s)" % game.hud.zoning_panel.info.text.get_slice("\n", 0))
	# Croissance visible.
	step_world(UrbanRules.PERIOD * 30)
	await frames(8)
	var grown: SimWorld.Building = null
	for candidate in w.team_buildings(0):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.is_zone(b.type) and bool(b.city.get("grown", false)) and b.complete:
			grown = b
	check(grown != null, "A17 des bâtiments poussent sur les zones peintes")
	if grown == null:
		return
	game.focus(grown.center)
	await frames(6)
	var node: Node3D = game.view.building_nodes.get(grown.id) as Node3D
	check(node != null and node.get_node_or_null("Model") != null and String(node.get_meta("urban_sig", "")) == UrbanVisual.signature(grown), "A18 modèle composé selon catégorie, niveau, âge et état")
	var sig: String = String(node.get_meta("urban_sig", ""))
	grown.city["level"] = int(grown.city.get("level", 1)) + 1
	step_world(2)
	await frames(4)
	check(String(node.get_meta("urban_sig", "")) != sig, "A19 niveau suivant : la silhouette est reconstruite")
	# 0.20 — Filtres de la carte : un toucher passe au filtre suivant, sans quitter le mode Zonage.
	var panel: ZoningPanel = game.hud.zoning_panel
	await press(panel.filter_btn)
	await frames(3)
	check(String(game.city_view) == "zoning" and panel.filter_btn.text.contains("zonage") and game.view.overlay_mode == 1, "F01 « Filtre » : zonage (%s)" % panel.filter_btn.text)
	await press(panel.filter_btn)
	await frames(2)
	game.city_overlay.rebuild()
	check(String(game.city_view) == "population" and game.city_overlay.quads > 0 and panel.info.text.contains("Population"), "F02 filtre population : quartiers teintés (%d) et légende" % game.city_overlay.quads)
	var shown: Array = []
	for i in CityOverlay.FILTERS.size() - 3:
		await press(panel.filter_btn)
		await frames(1)
		game.city_overlay.rebuild()
		if game.city_overlay.quads > 0:
			shown.append(String(game.city_view))
	check(shown.size() >= 6, "F03 filtres densité, criminalité, prospérité, production, pollution, état, incidents, infrastructures : %s" % ", ".join(shown))
	await press(panel.filter_btn)
	await frames(2)
	game.city_overlay.rebuild()
	check(String(game.city_view) == "" and game.city_overlay.quads == 0 and panel.filter_btn.text.contains("aucun"), "F04 dernier toucher : plus aucun filtre")
	# Filtre « Zonage » hors du mode Zonage : le calque reste, puis disparaît quand on retire le filtre.
	panel.set_filter("zoning")
	game.zoning_tool.close()
	await frames(2)
	check(game.view.overlay_mode == 1, "F05 filtre « Zonage » hors du mode : calque coloré conservé")
	panel.set_filter("")
	await frames(2)
	check(game.view.overlay_mode == 0, "F06 filtre retiré : terrain normal")
	game.hud.toggle_zoning()
	await frames(2)
	# 0.20 — Villes lointaines : une ville dans un autre monde du camp apparaît dans le panneau Ville (calcul abrégé).
	var far_key: String = ""
	for key in game.campaign.worlds.keys():
		if String(key) != String(game.campaign.active):
			far_key = String(key)
	if far_key != "":
		var fw: SimWorld = game.campaign.worlds[far_key]
		var fcc: Array = fw.team_buildings(0, "centre", true)
		if fcc.is_empty():
			fw.spawn_building(0, "centre", Vector2i(20, 20), true)
		var spot: Vector2i = (fw.team_buildings(0, "centre", true)[0] as SimWorld.Building).cell + Vector2i(0, 5)
		var fb: SimWorld.Building = fw.spawn_building(0, "zone_r", spot, true)
		fb.city = {"grown": true, "level": 1, "density": 1.0, "style_age": 1, "variant": 1, "rot": 0, "state": "operational"}
		fw.teams[0].city["habitants"] = 12
		for i in UrbanRules.PERIOD * UrbanRules.FAR_EVERY * 2:
			game.campaign.step()
		var empire: Dictionary = UrbanAbstract.empire(game.campaign, 0)
		check((empire["worlds"] as Array).size() >= 2 and int(empire["far"]) >= 1, "M20 toutes les villes du camp : %d monde(s), %d en calcul abrégé" % [(empire["worlds"] as Array).size(), int(empire["far"])])
		game.city_panel.open()
		await frames(3)
		var text: String = ""
		for node_l in game.city_panel.content.find_children("*", "Label", true, false):
			text += (node_l as Label).text + "\n"
		check(text.contains("TOUTES VOS VILLES") and text.contains("calcul abrégé") and text.contains(UrbanAbstract.world_label(far_key)), "M21 panneau Ville : liste des villes de chaque monde (%s)" % UrbanAbstract.world_label(far_key))
		game.city_panel.hide()
		await frames(2)
	else:
		check(false, "M20 un second monde existe dans la campagne de recette")
	# Fermer, puis fiche d'un bâtiment de zone et quartier historique.
	before = touches_used
	await press(button("Fermer"))
	await frames(3)
	check(not game.zoning_tool.active and String(game.mode) == "" and game.view.overlay_mode == 0, "A20 « Fermer » : calque retiré, jeu normal")
	await press(game.hud.zones_btn)
	await frames(2)
	game._back_action()
	await frames(3)
	check(not game.zoning_tool.active and not game.hud.zoning_panel.visible, "A21 retour Android : mode Zonage fermé")
	game.sel_building = grown.id
	game.hud.selection_changed()
	await frames(6)
	var drawer: BuildingDrawer = game.hud.building_drawer
	check(drawer.visible and drawer.queue_label.text.contains("Niveau") and drawer.queue_label.text.contains("architecture"), "A22 fiche : état, niveau, architecture, richesse")
	var keep: Button = button("Conserver l'architecture")
	if keep != null:
		await press(keep)
		await frames(3)
	check(bool(grown.city.get("historic", false)), "A23 « Conserver l'architecture » : quartier historique")
	game.clear_selection()
	await frames(3)
	# Portrait : la barre du mode Zonage tient à l'écran.
	get_root().size = Vector2i(740, 1600)
	await frames(6)
	await press(game.hud.zones_btn)
	await frames(4)
	var vp: Vector2 = game.hud.root.get_viewport_rect().size
	var rect: Rect2 = game.hud.zoning_panel.get_global_rect()
	check(game.hud.zoning_panel.visible and rect.position.x >= 0.0 and rect.end.x <= vp.x + 1.0 and rect.position.y >= 0.0 and rect.end.y <= vp.y + 1.0, "A24 portrait : barre du mode Zonage entièrement à l'écran (%s dans %s)" % [str(rect), str(vp)])
	var min_h: float = 999.0
	for node_b in game.hud.zoning_panel.find_children("*", "Button", true, false):
		if (node_b as Button).is_visible_in_tree():
			min_h = minf(min_h, (node_b as Button).size.y)
	check(min_h >= 44.0, "A25 boutons du zonage d'au moins 44 points (%.0f)" % min_h)
	await press(button("Fermer"))
	get_root().size = Vector2i(1280, 1280)
	await frames(4)
