extends "res://lab/ui_test_base.gd"
## 0.18 — Ville de l'âge de l'électricité dans la vraie scène : recherche depuis la fiche de l'usine, maisons converties
## (et redessinées), menu Bâtir de la ville, pose d'une zone au toucher, fiche de zone et amélioration, panneau Ville,
## vues au sol, rayon d'action pendant la pose, alertes d'incendie, puces de ressources « ville ».

func result_key() -> String:
	return "UI_CITY_RESULT"

func open_cell(size: int, near: Vector2) -> Vector2i:
	## Emplacement libre (sans contrôle de coût ni d'approvisionnement) pour installer un décor de recette.
	for r in range(2, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c: Vector2i = Vector2i(int(near.x) + dx, int(near.y) + dy)
				if game.world.footprint_free(c, size) and game.world.has_margin(c, size):
					return c
	return Vector2i(-1, -1)

func step_world(n: int) -> void:
	for i in n:
		game.world.step()

func run() -> void:
	var w: SimWorld = game.world
	check(UrbanCity.enabled(w) and game.city_panel != null and game.city_overlay != null, "C01 partie avec évolution de la civilisation : panneau Ville et vues au sol présents")
	w.teams[0].res = {"food": 20000.0, "wood": 20000.0, "ore": 20000.0}
	w.teams[0].age = 4
	w.teams[0].pop_cap = 200
	if w.supply_gate != null:
		var colony: Dictionary = w.supply_gate._colony(0)
		if not colony.is_empty():
			for good in ["concrete", "alloy", "electronics"]:
				(colony["stocks"] as Dictionary)[good] = 5000.0
	var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
	var house_cell: Vector2i = free_cell("maison", cc.center + Vector2(-6, 5))
	var house: SimWorld.Building = w.spawn_building(0, "maison", house_cell, true)
	var factory_cell: Vector2i = open_cell(4, cc.center + Vector2(8, -8))
	var factory: SimWorld.Building = w.spawn_building(0, "usine", factory_cell, true)
	game.focus(factory.center)
	await frames(4)
	var city_btn: Button = game.hud.city_btn
	check(city_btn != null and city_btn.is_visible_in_tree(), "C02 bouton « Ville » dans la barre du haut")
	await press(city_btn)
	await frames(4)
	check(game.city_panel.visible and game.city_panel.content.get_child_count() >= 1, "C03 avant la recherche : le panneau explique comment ouvrir la ville")
	await press(button("Fermer"))
	await frames(2)
	# Recherche depuis la fiche de l'usine (onglet Évolutions).
	game.sel_building = factory.id
	game.hud.selection_changed()
	await frames(6)
	var drawer: BuildingDrawer = game.hud.building_drawer
	drawer.active_tab = "Évolutions"
	drawer._signature = ""
	drawer.refresh()
	await frames(4)
	var card: DataCard = null
	for c in drawer.cards:
		if String(c.key) == "tech:" + UrbanRules.TECH:
			card = c
	check(card != null, "C04 carte « Électricité » dans la fiche de l'usine")
	if card == null:
		return
	await press(card.picture if card.picture != null else card)
	check(not w.teams[0].tech_research.is_empty() and String(w.teams[0].tech_research.get("key", "")) == UrbanRules.TECH, "C05 recherche lancée d'un toucher")
	w.teams[0].tech_research["remaining"] = 0.05
	step_world(30)
	await frames(10)
	check(w.teams[0].technologies.has(UrbanRules.TECH) and house.type == "zone_r", "C06 recherche achevée : la maison est devenue une zone d'habitation")
	var node: Node3D = game.view.building_nodes.get(house.id) as Node3D
	check(node != null and String(node.get_meta("model_kind", "")) == "zone_r", "C07 la vue a redessiné la maison en zone d'habitation")
	check((game.hud.res_chips["food"] as Object).get("city") == true, "C08 puces de ressources en mode « ville » (plus d'ouvriers par ressource)")
	# Menu Bâtir : zones et services, plus de maison.
	game.sel_building = cc.id
	game.hud.selection_changed()
	await frames(6)
	drawer.active_tab = "Bâtiments"
	drawer._signature = ""
	drawer.refresh()
	await frames(4)
	var keys: Array = []
	for c in drawer.cards:
		keys.append(String(c.key))
	# 0.19 (décision de l'auteur) : les zones se peignent (mode Zonage) ; le menu Bâtir ne propose plus que les services.
	check(not keys.has("zone_r") and not keys.has("zone_c") and not keys.has("zone_i") and keys.has("centrale") and keys.has("caserne_pompiers") and keys.has("hopital"), "C09 menu Bâtir : services proposés, zones retirées (zonage)")
	check(not keys.has("maison") and not keys.has("ferme") and not keys.has("entrepot"), "C10 menu Bâtir : maison, ferme et entrepôt retirés")
	# Pose d'une centrale : le rayon d'action apparaît sous le fantôme.
	var plant_card: DataCard = null
	for c in drawer.cards:
		if String(c.key) == "centrale":
			plant_card = c
	drawer.scroll.ensure_control_visible(plant_card)
	await frames(3)
	await press(plant_card.picture)
	await frames(3)
	check(String(game.mode) == "place" and String(game.place_type) == "centrale", "C11 carte « Centrale » : pose lancée")
	game.city_overlay.rebuild()
	check(game.city_overlay.circles >= 1, "C12 rayon d'action visible sous le fantôme pendant la pose (%d cercle(s))" % game.city_overlay.circles)
	var plant_cell: Vector2i = free_cell("centrale", cc.center + Vector2(10, 6), 40)
	game.focus(Vector2(plant_cell) + Vector2(1.5, 1.5))
	await frames(4)
	await tap(ground(Vector2(plant_cell) + Vector2(1.5, 1.5)))
	await frames(3)
	var placed_before: int = w.team_buildings(0, "centrale").size()
	await press(game.hud.place_ok)
	await frames(3)
	check(w.team_buildings(0, "centrale").size() == placed_before + 1, "C13 centrale posée au toucher (fondation) %s %s" % [str(game.place_cell), str(plant_cell)])
	# 0.19 (décision de l'auteur) : la zone commerciale est peinte (commande du mode Zonage) et son bâtiment pousse
	# sur la parcelle ; le geste du mode Zonage est éprouvé par la recette ui_zoning. Ici, on suit la fiche de zone.
	var zc_cell: Vector2i = open_cell(2, cc.center + Vector2(-2, 8))
	var painted: Dictionary = w.issue({"t": "zone_paint", "team": 0, "kind": 4, "from": [zc_cell.x, zc_cell.y], "to": [zc_cell.x + 1, zc_cell.y + 1]})
	var zc: SimWorld.Building = w.spawn_building(0, "zone_c", zc_cell, false)
	zc.city = {"grown": true, "level": 1, "density": 0.0, "style_age": 4, "variant": 3, "rot": 1, "state": "construction"}
	check(bool(painted.get("ok", false)) and zc != null and UrbanZoning.zone_at(w, 0, zc_cell) == 4, "C14 zone commerciale peinte, son bâtiment pousse sur la parcelle")
	if zc == null:
		return
	for b in w.team_buildings(0):
		if not b.complete:
			b.progress = 1.0
			w._complete_building(b)
	step_world(UrbanRules.PERIOD * 4)
	await frames(6)
	# Fiche de zone : état et amélioration.
	game.sel_building = zc.id
	game.hud.selection_changed()
	await frames(8)
	check(drawer.visible and drawer.queue_label.text.contains("Niveau I") and drawer.queue_label.text.contains("Électricité"), "C15 fiche de zone : niveau, emplois, électricité, eau, indicateurs")
	var upgrade: Button = null
	for n in drawer.action_bar.get_children():
		if n is Button and bool((n as Button).get_meta("urban_upgrade", false)):
			upgrade = n
	check(upgrade != null and upgrade.text.contains("niveau II"), "C16 bouton « Améliorer : niveau II » avec son coût")
	if upgrade != null:
		await press(upgrade)
		await frames(3)
	check(int(zc.city.get("level", 1)) == 2, "C17 amélioration appliquée d'un toucher")
	# Panneau Ville et vues au sol.
	await press(city_btn)
	await frames(6)
	check(game.city_panel.visible and game.city_panel.content.get_child_count() > 8, "C18 panneau Ville : bien-être, facteurs, population, réseaux, production, conseils")
	var power_view: Button = null
	for b in game.city_panel.views.get_children():
		if String((b as Button).get_meta("view")) == "power":
			power_view = b
	await press(power_view)
	await frames(3)
	game.city_overlay.rebuild()
	check(String(game.city_view) == "power" and game.city_overlay.quads >= 2, "C19 vue « Électricité » : bâtiments teintés au sol (%d)" % game.city_overlay.quads)
	check(game.city_panel.legend.text.contains("alimenté"), "C20 légende de la vue affichée")
	await press(button("Fermer"))
	await frames(2)
	check(not game.city_panel.visible and String(game.city_view) == "power", "C21 la vue reste au sol panneau fermé")
	game.city_panel.set_view("")
	game.city_overlay.rebuild()
	check(game.city_overlay.quads == 0, "C22 vue « Aucune » : rien au sol")
	# Incendie : alerte et flammes.
	zc.city["burning"] = UrbanRules.FIRE_DURATION
	w.emit("incendie", 0, "Incendie : Zone commerciale", {"building": zc.id, "pos": zc.center})
	game._consume_events()
	step_world(1)
	await frames(4)
	var fire_alert: bool = false
	for a in game.hud.alerts.alerts:
		if String(a["kind"]) == "feu":
			fire_alert = true
	check(fire_alert, "C23 alerte « Incendie » dans la file d'alertes")
	var zone_node: Node3D = game.view.building_nodes.get(zc.id) as Node3D
	check(zone_node != null and zone_node.get_node_or_null("Fire") != null and (zone_node.get_node("Fire") as Node3D).visible, "C24 flammes visibles sur le bâtiment en feu")
	# Récolte refusée aux ouvriers, avec la raison.
	var worker: SimWorld.Unit = w.team_units(0, "worker")[0]
	var r: Dictionary = w.issue({"t": "gather", "team": 0, "units": [worker.id], "node": -1})
	check(not bool(r["ok"]) and String(r["reason"]).contains("ville"), "C25 ordre de récolte refusé : %s" % String(r["reason"]))
