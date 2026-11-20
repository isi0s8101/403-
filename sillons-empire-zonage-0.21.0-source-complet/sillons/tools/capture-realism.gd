extends SceneTree
## Captures reproductibles du vrai moteur. Les dotations et déblocages sont réservés à cette fixture.
var frames: int = 0
var game
var mode_name: String = "tactical"
var age: int = 1
var out: String = ""

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	mode_name = args[0]
	age = clampi(int(args[1]), 1, 10)
	out = args[2]
	GameConfig.mode = "skirmish"
	GameConfig.seed_value = 4242
	GameConfig.visual_quality = 2
	GameConfig.show_perf = false
	GameConfig.adaptive_visuals = false
	change_scene_to_file("res://game/main_menu.tscn" if mode_name == "menu" else "res://game/game.tscn")

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 4 and mode_name != "menu":
		game = current_scene
		game.paused = true
		var c: StarCampaign = game.campaign
		c.ages[0] = age
		c._sync_all()
		var headquarters: SimWorld.Building = game.world.team_buildings(0, "centre", true)[0] as SimWorld.Building
		game.cam_target = Vector3(headquarters.center.x + 3, 0, headquarters.center.y - 2)
		game.cam_dist = 25.0
		game.cam_zoom_goal = 25.0
		game._update_camera()
		if mode_name == "showcase":
			# Isolated render fixture: completed buildings only, never part of normal starting resources.
			var examples: Array = ["maison", "caserne", "entrepot", "marche", "atelier", "usine", "depot", "maison"]
			for i in examples.size():
				var kind: String = String(examples[i])
				if int((Rules.BUILDINGS[kind] as Dictionary)["age"]) > age:
					continue
				var cell: Vector2i = headquarters.cell + Vector2i((i % 3) * 6 - 5, -7 - (i / 3) * 6)
				game.world.spawn_building(0, kind, cell, true)
			game.world.update_fog(true)
			game.cam_target = Vector3(headquarters.center.x + 2, 0, headquarters.center.y - 7)
			game.cam_dist = 43.0
			game.cam_zoom_goal = 43.0
			game._update_camera()
			game.hud.set_hint("Laboratoire graphique · bâtiments de l’âge " + str(age))
		elif mode_name == "wide":
			for i in 100:
				game.world.spawn_unit(0, "lancier", headquarters.center + Vector2(float(i % 10) * 0.6 + 4.0, floor(float(i) / 10.0) * 0.6 - 5.0))
			game.world.update_fog(true)
			game.cam_dist = 56.0
			game.cam_zoom_goal = 56.0
			game._update_camera()
			game.hud.set_hint("Laboratoire visuel · 100 renforts · rendu par lots")
		elif mode_name == "river":
			for point in [Vector2(44, 48), Vector2(52, 48), Vector2(48, 44), Vector2(48, 52)]:
				game.world.spawn_unit(0, "eclaireur", point)
			game.world.update_fog(true)
			game.cam_target = Vector3(48, 0, 48)
			game.cam_dist = 32.0
			game.cam_zoom_goal = 32.0
			game._update_camera()
		elif mode_name == "selection":
			var workers: Array = game.world.team_units(0, "worker")
			if not workers.is_empty():
				game.select_single((workers[0] as SimWorld.Unit).id)
		elif mode_name == "build":
			game.hud._toggle_build()
		elif mode_name == "pause":
			game.hud._toggle_menu()
		game.view.update_fog_texture()
		game.view._refresh_nodes()
		game.view._refresh_ground_details()
		if mode_name == "globe":
			for key in ViewTechnology.RESEARCH_ORDER:
				c.technologies[0][key] = true
			c.resources[0] = {"food": 90000.0, "wood": 90000.0, "ore": 90000.0}
			c.planets._mint(c, 0, "treasury", 10000.0, "capture de laboratoire")
			for kind in ["R", "R", "R", "C", "C", "I", "I", "power", "water", "hospital", "fire", "police"]:
				var cells: Dictionary = c.planets.colony(0, c.active)["cells"] as Dictionary
				var before: int = 0
				for cell in cells.values():
					if PlanetCampaign.cell_kind(cell as Dictionary) == kind:
						before += 1
				for _attempt in 24:
					var result: Dictionary = c.planets.quick_build(c, 0, c.active, kind)
					if not bool(result.get("ok", false)):
						print("CAPTURE_BUILD ", kind, " ", result)
						break
					var count: int = 0
					for cell in cells.values():
						if PlanetCampaign.cell_kind(cell as Dictionary) == kind:
							count += 1
					if count > before:
						break

			for _tick in 20:
				c.step()
			if game.can_open_view("planet"):
				game.enter_planet_overview()
			else:
				_show_locked_globe_fixture(c)
			var hq: int = int(c.planets.colony(0, c.active)["hq"])
			var ll: Vector2 = PlanetCampaign.district_ll(hq)
			game.planet_globe.globe.quaternion = Quaternion(PlanetGenerator.sphere_direction(ll.x, ll.y), Vector3(0.0, 0.08, 1.0).normalized())
	if frames == (150 if mode_name == "globe" else 32):
		if game != null:
			print("REALISM_RENDER_STATS=", JSON.stringify({"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "units": game.world.units.size(), "visual": game.view.visual_stats()}))
		var error: Error = root.get_texture().get_image().save_png(out)
		print("REALISM_CAPTURE=%s path=%s" % ["PASS" if error == OK else "FAIL", out])
		quit(0 if error == OK else 1)
	return false

func _show_locked_globe_fixture(c: StarCampaign) -> void:
	# Fixture graphique seulement : ne débloque aucune technologie ni commande de la partie.
	# L'atlas de l'âge I est inspecté directement comme dans une scène de laboratoire.
	game.planet_mode = true
	game._space_environment(true)
	game.view.visible = false
	game.hud.visible = false
	if game.strategic_hud != null:
		game.strategic_hud.visible = false
	if game.region_navigation != null:
		game.region_navigation.visible = false
	game.planet_globe = PlanetGlobeView.new()
	game.add_child(game.planet_globe)
	game.planet_globe.setup(int(game.world.rules.get("planet_master_seed", game.world.seed_value)))
	game.planet_globe.bind_campaign(c, 0)
	game.planet_hud = PlanetHud.new()
	game.add_child(game.planet_hud)
	game.planet_hud.setup(game)
	game.planet_hud.region_label.text = "Laboratoire visuel · âge I\nLe globe reste verrouillé en partie à cet âge."
	game._update_camera()
