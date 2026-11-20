extends SceneTree
## Captures réelles de l'interface (avant / après 0.17) :
## xvfb-run -a -s "-screen 0 1600x740x24" godot --rendering-driver opengl3 --path . --resolution 1600x740 \
##   --script res://tools/capture-ui-017.gd -- <mode> <sortie.png> [âge]
## Modes : debut, armee, caserne, placement, civilisation, bataille, globe, file, planche, planche_civ, ville, ville_vue, ville_panneau (0.18).
## [âge] (1..10) : force l'âge de la civilisation et le thème correspondant (planche des 10 âges).
var frames: int = 0
var mode: String = "debut"
var output: String = ""
var age_override: int = 0
var game

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "debut"
	output = args[1] if args.size() > 1 else "user://capture.png"
	age_override = int(args[2]) if args.size() > 2 else 0
	GameConfig.mode = "empire"
	GameConfig.seed_value = 15001
	GameConfig.reduce_motion = true
	GameConfig.visual_quality = 2
	GameConfig.adaptive_visuals = false
	var c := StarCampaign.new()
	CampaignSetup.create(c, 15001, false, 96)
	for w in c.worlds.values():
		w.ai_controllers.clear()
	if mode == "globe":
		c.ages[0] = 10
		for key in ViewTechnology.RESEARCH_ORDER:
			c.technologies[0][key] = true
	GameConfig.loaded_campaign = c
	change_scene_to_file("res://game/game.tscn")

func _open_cell(w: SimWorld, size: int, near: Vector2) -> Vector2i:
	for r in range(2, 30):
		for k in 24:
			var ang: float = float(k) / 24.0 * TAU
			var p: Vector2 = near + Vector2(cos(ang), sin(ang)) * float(r)
			var c: Vector2i = Vector2i(int(p.x) - size / 2, int(p.y) - size / 2)
			if w.footprint_free(c, size) and w.has_margin(c, size):
				return c
	return Vector2i(-1, -1)

func _build_city(w: SimWorld, cc: SimWorld.Building) -> SimWorld.Building:
	## 0.18 : petite ville réelle (simulation complète) autour du centre, pour les captures.
	w.teams[0].age = maxi(4, w.teams[0].age)
	if game.campaign != null:
		game.campaign.ages[0] = w.teams[0].age
	w.teams[0].technologies[UrbanRules.TECH] = true
	var first: SimWorld.Building = null
	for kind in ["centrale", "chateau_eau", "zone_r", "zone_r", "zone_c", "zone_r", "zone_i", "zone_r", "zone_c", "commissariat", "caserne_pompiers", "zone_i", "zone_r", "hopital", "zone_r", "zone_c"]:
		var size: int = int(Rules.BUILDINGS[kind]["size"])
		var cell: Vector2i = _open_cell(w, size, cc.center + Vector2(3, 3))
		if cell.x < 0:
			continue
		var b: SimWorld.Building = w.spawn_building(0, kind, cell, true)
		if first == null and kind == "zone_c":
			first = b
	for i in 900:
		w.step()
	return first

func _spawn_squad(w: SimWorld, team: int, kind: String, at: Vector2, count: int) -> Array:
	var ids: Array = []
	for i in count:
		var r: Dictionary = w.issue({"t": "lab_spawn", "team": team, "unit": kind, "pos": [at.x + float(i % 4) * 1.1, at.y + float(i / 4) * 1.1], "new_squad": i == 0})
		ids.append(int(r.get("id", -1)))
	return ids

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		game = current_scene
		game.paused = true
		var w: SimWorld = game.world
		var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
		w.teams[0].res = {"food": 4200.0, "wood": 3100.0, "ore": 1800.0}
		if age_override > 0:
			w.teams[0].age = age_override
			if game.campaign != null:
				game.campaign.ages[0] = age_override
			GameConfig.theme_mode = age_override
			AgeTheme.apply(age_override)
		match mode:
			"armee", "bataille", "file":
				var ids: Array = _spawn_squad(w, 0, "lancier", cc.center + Vector2(5, -6), 8)
				if mode == "bataille":
					_spawn_squad(w, 1, "lancier", cc.center + Vector2(9, -9), 6)
					for i in 25:
						w.step()
				var u: SimWorld.Unit = w.units.get(int(ids[0])) as SimWorld.Unit
				if u != null:
					game.select_squad(u.squad_id)
					game.focus(u.pos)
				if mode == "file" and u != null:
					var orders: Array = [{"type": "move", "pos": [u.pos.x + 6, u.pos.y]}, {"type": "amove", "pos": [u.pos.x + 6, u.pos.y - 6]}, {"type": "move", "pos": [u.pos.x, u.pos.y - 6]}]
					w.issue({"t": "queue_orders", "team": 0, "units": ids, "orders": orders, "loop": true})
					game.select_many(ids)
			"caserne", "planche":
				var r: Dictionary = w.issue({"t": "lab_building", "team": 0, "type": "caserne", "cell": [int(cc.center.x) + 4, int(cc.center.y) - 8], "complete": true})
				game.sel_building = int(r.get("id", cc.id))
				game.hud.selection_changed()
				game.focus(cc.center + Vector2(5, -6))
			"placement":
				game.start_placement("maison")
			"civilisation", "planche_civ":
				if game.civ_panel != null:
					game.civ_panel.open()
			"globe":
				game.enter_planet_overview()
			"ages":
				# 0.20 : la même parcelle aux 10 âges (habitat et commerce niveau IV), de gauche à droite.
				var focus_ages: Vector2 = _build_ages_row(w, cc)
				for i in w.teams[0].fog.size():
					w.teams[0].fog[i] = 2
				for m in game.view.decor_meshes.values():
					(m as Node3D).visible = false
				game.view.sync(1.0, 0.0)
				game.view.update_fog_texture()
				game.view._refresh_nodes()
				game.cam_zoom_goal = 27.0
				game.focus(focus_ages)
			"filtre":
				# 0.20 : filtre « État » sur le quartier préparé (vert : en état, orange : dégradé, rouge : brûlé, ruine).
				var focus_f: Vector2 = _build_zoned_city(w, cc)
				w.step()
				game.city_view = "state"
				game.city_overlay.set_view("state")
				game.city_overlay.rebuild()
				game.cam_zoom_goal = 22.0
				game.focus(focus_f)
			"zonage", "quartier":
				# 0.19 : quartier zoné, routes, bâtiments de niveaux, âges et états variés (mêmes règles que le jeu).
				var focus: Vector2 = _build_zoned_city(w, cc)
				if mode == "zonage":
					game.hud.toggle_zoning()
					game.zoning_tool.set_kind(2)
					game.zoning_tool.inspect(Vector2i(int(cc.cell.x), int(cc.cell.y + cc.size + 2)))
				game.cam_zoom_goal = 20.0 if mode == "quartier" else 30.0
				game.focus(focus + (Vector2(-9.0, 3.0) if mode == "zonage" else Vector2.ZERO))
			"ville", "ville_vue", "ville_panneau":
				var zone: SimWorld.Building = _build_city(w, cc)
				if mode == "ville" and zone != null:
					game.sel_building = zone.id
					game.hud.selection_changed()
				if mode == "ville_vue":
					game.city_view = "happiness"
					game.city_overlay.set_view("happiness")
				if mode == "ville_panneau" and game.city_panel != null:
					game.city_panel.open()
				game.focus(cc.center + Vector2(4, 4))
	if frames == 14 and mode in ["planche", "planche_civ"] and game != null:
		var w2: SimWorld = game.world
		var center: Vector2 = (w2.team_buildings(0, "centre", true)[0] as SimWorld.Building).center
		game.hud.alerts.push("attaque", "Attaque près de vos troupes ou bâtiments", center + Vector2(10, 4))
		game.hud.alerts.push("fini", "Recherche achevée : Outils", center)
		game.hud.toast("Âge %s — %s" % [Hud.ROMAN[maxi(1, age_override)], AgeTheme.age_name(maxi(1, age_override))], AgeTheme.c("info"))
	if frames == 30:
		get_root().get_texture().get_image().save_png(output)
		print("UI_CAPTURE=PASS ", mode, " ", output)
		quit()
	return false


func _build_zoned_city(w: SimWorld, cc: SimWorld.Building) -> Vector2:
	var x0: int = cc.cell.x
	var y0: int = cc.cell.y + cc.size
	for y in range(y0 - 1, y0 + 18):
		for x in range(x0 - 8, x0 + 14):
			var c := Vector2i(x, y)
			if not w.in_map(c):
				continue
			w.set_terrain(c, SimWorld.TERRAIN_GRASS)
			if w._node_cells.has(c):
				w.nodes.erase(int(w._node_cells[c]))
				w._node_cells.erase(c)
			if w._occupied.has(c) and w.buildings.has(int(w._occupied[c])) and (w.buildings[int(w._occupied[c])] as SimWorld.Building).type != "centre":
				w._destroy_building(w.buildings[int(w._occupied[c])], -1)
	w.teams[0].res = {"food": 9000.0, "wood": 9000.0, "ore": 9000.0}
	w.issue({"t": "lab_reveal", "team": 0})
	var road: Array = []
	for y in range(y0 - 1, y0 + 17):
		road.append([x0 - 1, y])
	for x in range(x0 - 7, x0 + 13):
		road.append([x, y0 + 8])
	w.issue({"t": "road_paint", "team": 0, "cells": road})
	var specs: Array = [
		# [code, bâtiment, case, âge, niveau, état]
		[1, "zone_r", Vector2i(x0, y0), 1, 1, "operational"], [1, "zone_r", Vector2i(x0 + 2, y0), 2, 2, "prosperous"],
		[2, "zone_r", Vector2i(x0, y0 + 2), 3, 3, "operational"], [2, "zone_r", Vector2i(x0 + 2, y0 + 2), 4, 3, "degraded"],
		[3, "zone_r", Vector2i(x0, y0 + 4), 5, 4, "operational"], [3, "zone_r", Vector2i(x0 + 2, y0 + 4), 7, 5, "prosperous"],
		[3, "zone_r", Vector2i(x0, y0 + 6), 9, 6, "operational"], [2, "zone_r", Vector2i(x0 + 2, y0 + 6), 2, 1, "abandoned"],
		[4, "zone_c", Vector2i(x0 - 3, y0), 2, 1, "operational"], [4, "zone_c", Vector2i(x0 - 3, y0 + 2), 4, 2, "operational"],
		[4, "zone_c", Vector2i(x0 - 3, y0 + 4), 6, 4, "prosperous"], [4, "zone_c", Vector2i(x0 - 3, y0 + 6), 8, 5, "operational"],
		[5, "zone_i", Vector2i(x0 + 4, y0 + 9), 3, 2, "operational"], [5, "zone_i", Vector2i(x0 + 6, y0 + 9), 5, 4, "operational"],
		[5, "zone_i", Vector2i(x0 + 8, y0 + 9), 8, 5, "operational"], [6, "zone_a", Vector2i(x0 - 6, y0 + 9), 1, 1, "operational"],
		[6, "zone_a", Vector2i(x0 - 4, y0 + 9), 4, 2, "operational"], [6, "zone_a", Vector2i(x0 - 6, y0 + 11), 7, 3, "operational"],
		[2, "zone_r", Vector2i(x0, y0 + 9), 3, 2, "burnt"], [2, "zone_r", Vector2i(x0 + 2, y0 + 9), 3, 2, "operational"],
	]
	var burning: SimWorld.Building = null
	for spec in specs:
		var cell: Vector2i = spec[2]
		w.issue({"t": "zone_paint", "team": 0, "kind": int(spec[0]), "from": [cell.x, cell.y], "to": [cell.x + 1, cell.y + 1]})
		var b: SimWorld.Building = w.spawn_building(0, String(spec[1]), cell, true)
		b.city = {"grown": true, "zoned_once": true, "level": int(spec[4]), "density": float(spec[4]), "style_age": int(spec[3]),
			"variant": cell.x * 7 + cell.y * 3, "rot": (cell.x + cell.y) % 4, "state": String(spec[5]), "ready": true}
		if String(spec[5]) == "burnt":
			b.hp = b.max_hp * 0.2
		if b.cell == Vector2i(x0 + 2, y0 + 9):
			burning = b
	# Un chantier, des ruines, un incendie en cours.
	w.issue({"t": "zone_paint", "team": 0, "kind": 2, "from": [x0 + 4, y0 + 2], "to": [x0 + 5, y0 + 3]})
	var site: SimWorld.Building = w.spawn_building(0, "zone_r", Vector2i(x0 + 4, y0 + 2), false)
	site.city = {"grown": true, "level": 1, "density": 0.0, "style_age": 4, "variant": 5, "rot": 1, "state": "construction"}
	site.progress = 0.45
	var ruin: SimWorld.Building = w.spawn_building(0, "ruine", Vector2i(x0 + 4, y0 + 4), true)
	ruin.city = {"was": "zone_r", "level": 2, "style_age": 3}
	if burning != null:
		burning.city["burning"] = 30.0
		burning.city["fire_i"] = 0.8
	return Vector2(float(x0) + 2.0, float(y0) + 7.0)


func _build_ages_row(w: SimWorld, cc: SimWorld.Building) -> Vector2:
	var x0: int = cc.cell.x - 9
	var y0: int = cc.cell.y + cc.size + 2
	for y in range(y0 - 10, y0 + 14):
		for x in range(x0 - 4, x0 + 34):
			var c := Vector2i(x, y)
			if not w.in_map(c):
				continue
			w.set_terrain(c, SimWorld.TERRAIN_GRASS)
			if w._node_cells.has(c):
				w.nodes.erase(int(w._node_cells[c]))
				w._node_cells.erase(c)
			if w._occupied.has(c) and w.buildings.has(int(w._occupied[c])) and (w.buildings[int(w._occupied[c])] as SimWorld.Building).type != "centre":
				w._destroy_building(w.buildings[int(w._occupied[c])], -1)
	w.teams[0].res = {"food": 9000.0, "wood": 9000.0, "ore": 9000.0}
	w.issue({"t": "lab_reveal", "team": 0})
	var road: Array = []
	for x in range(x0 - 1, x0 + 21):
		road.append([x, y0 + 2])
	w.issue({"t": "road_paint", "team": 0, "cells": road})
	for age in range(1, 11):
		var cell := Vector2i(x0 + (age - 1) * 2, y0)
		w.issue({"t": "zone_paint", "team": 0, "kind": 3, "from": [cell.x, cell.y], "to": [cell.x + 1, cell.y + 1]})
		var b: SimWorld.Building = w.spawn_building(0, "zone_r", cell, true)
		b.city = {"grown": true, "zoned_once": true, "level": 4, "density": 4.0, "style_age": age, "variant": 3, "rot": 0, "state": "operational", "ready": true}
		var cell2 := Vector2i(x0 + (age - 1) * 2, y0 + 3)
		w.issue({"t": "zone_paint", "team": 0, "kind": 4, "from": [cell2.x, cell2.y], "to": [cell2.x + 1, cell2.y + 1]})
		var s: SimWorld.Building = w.spawn_building(0, "zone_c", cell2, true)
		s.city = {"grown": true, "zoned_once": true, "level": 4, "density": 4.0, "style_age": age, "variant": 5, "rot": 2, "state": "operational", "ready": true}
	return Vector2(float(x0) + 10.0, float(y0) + 2.5)
