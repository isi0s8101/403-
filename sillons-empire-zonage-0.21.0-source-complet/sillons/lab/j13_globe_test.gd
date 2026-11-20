extends SceneTree
## J13.2 : les districts de la colonie apparaissent sur le globe avec les modèles 3D de la bibliothèque,
## au bon âge, et l'affichage suit la simulation sans jamais la modifier.
var frames: int = 0
var done: bool = false

func _initialize() -> void:
	GameConfig.mode = "planet_j9"
	GameConfig.seed_value = 1102026
	change_scene_to_file("res://game/game.tscn")

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 12 or done:
		return false
	done = true
	var game = current_scene
	game.paused = true
	var c: StarCampaign = game.campaign
	c.ages[0] = 6
	for key in ViewTechnology.RESEARCH_ORDER:
		c.technologies[0][key] = true # Fixture de recette, pas un déblocage joueur.
	c.resources[0] = {"food": 90000.0, "wood": 90000.0, "ore": 90000.0}
	c.planets._mint(c, 0, "treasury", 5000.0, "dotation de laboratoire")
	c._sync_all()
	game.enter_planet_overview()
	var globe: PlanetGlobeView = game.planet_globe
	var panel: ColonyPanel = game.planet_hud.colony_panel
	var fails: Array = []
	var hq: int = int(c.planets.colony(0, c.active)["hq"])
	if not (globe.districts_root != null and String(globe.district_nodes.get(hq, "")) == "bld.special.command_center.a06"):
		fails.append("commandement absent du globe : %s" % str(globe.district_nodes))
	for kind in ["R", "R", "C", "I", "power", "hospital"]:
		panel._build(kind)
		panel._build(kind)
	var before: String = c.state_hash()
	var shown: int = globe.show_districts(c, 0, c.active)
	if c.state_hash() != before:
		fails.append("l'affichage a modifié la simulation")
	var cells: Dictionary = c.planets.colony(0, c.active)["cells"] as Dictionary
	var expected: Dictionary = {"R": "bld.residential.a06", "C": "bld.commercial.a06", "I": "bld.industrial.a06", "power": "bld.special.power_plant.a06", "hospital": "bld.special.hospital.a06"}
	var seen: Dictionary = {}
	for id in cells.keys():
		var kind: String = PlanetCampaign.cell_kind(cells[id] as Dictionary)
		if expected.has(kind):
			seen[kind] = true
			if String(globe.district_nodes.get(id, "")) != String(expected[kind]):
				fails.append("district %s : modèle %s au lieu de %s" % [kind, String(globe.district_nodes.get(id, "")), String(expected[kind])])
	if seen.size() != expected.size():
		fails.append("zones construites incomplètes : %s" % str(seen.keys()))
	if shown != cells.size() or globe.districts_root.get_child_count() < shown:
		fails.append("districts affichés %d / %d" % [shown, cells.size()])
	var first: Node3D = globe.districts_root.get_child(0) as Node3D
	var radius: float = first.position.length()
	if radius < PlanetGlobeView.RADIUS or radius > PlanetGlobeView.RADIUS + 2.0 or first.scale.x <= 0.0 or first.scale.x > 1.0:
		fails.append("modèle mal posé sur la sphère (rayon %.2f, échelle %.3f)" % [radius, first.scale.x])
	# Changement d'âge : les mêmes zones changent de modèle ; densité : un immeuble de plus.
	c.ages[0] = 9
	c._sync_all()
	globe.show_districts(c, 0, c.active)
	var aged: bool = false
	for id in cells.keys():
		if PlanetCampaign.cell_kind(cells[id] as Dictionary) == "R" and String(globe.district_nodes.get(id, "")) == "bld.residential.a09":
			aged = true
	if not aged:
		fails.append("le modèle ne suit pas l'âge local")
	var count_before: int = globe.districts_root.get_child_count()
	(c.planets.colony(0, c.active)["stocks"] as Dictionary)["concrete"] = 500.0
	panel._densify("R")
	globe.show_districts(c, 0, c.active)
	if globe.districts_root.get_child_count() != count_before + 1:
		fails.append("la densité n'ajoute pas de bâtiment (%d -> %d)" % [count_before, globe.districts_root.get_child_count()])
	if globe.show_districts(c, 1, c.active) < 1 or String(globe.district_nodes.values()[0]) != "bld.special.command_center.a01":
		fails.append("colonie adverse à l'âge I mal représentée")
	for line in fails:
		print("FAIL " + String(line))
	print("J13_GLOBE_RESULT=%s districts=%d modeles=%d" % ["PASS" if fails.is_empty() else "FAIL", shown, count_before])
	quit(0 if fails.is_empty() else 1)
	return false
