extends SceneTree
## J13 : le tableau de colonie existe dans la vraie scène et passe par les commandes métier.
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
	c.ages[0] = 10
	for key in ViewTechnology.RESEARCH_ORDER:
		c.technologies[0][key] = true # Fixture de recette, pas un déblocage joueur.
	c.resources[0] = {"food": 9000.0, "wood": 9000.0, "ore": 9000.0}
	c._sync_all()
	game.enter_planet_overview()
	var panel: ColonyPanel = game.planet_hud.colony_panel
	var shown: bool = panel != null and panel.info.text.contains("colonie X")
	var cells: Dictionary = c.planets.colony(0, c.active)["cells"] as Dictionary
	var before: int = cells.size()
	panel._build("R")
	panel._build("R")
	var built: bool = cells.size() > before and c.planets.zoning_shares(c.planets.colony(0, c.active))["count"] >= 1
	c.resources[0]["wood"] = 0.0
	c.resources[0]["ore"] = 0.0
	var size_now: int = cells.size()
	panel._build("power")
	panel._build("power")
	var refused: bool = panel.feedback.text.begins_with("Refusé") and cells.size() <= size_now + 0 and c.planets.books_balanced(0)
	panel._cycle_ratio()
	var ratio: bool = is_equal_approx(float((c.planets.colony(0, c.active)["target"] as Dictionary)["R"]), 0.60)
	panel._toggle_governor()
	var gov: Dictionary = c.planets.colony(0, c.active)["governor"] as Dictionary
	var toggled: bool = bool(gov["enabled"]) and panel.feedback.text == "Gouverneur actif"
	var ok: bool = shown and built and refused and ratio and toggled
	print("J13_UI_RESULT=%s shown=%s built=%s refused=%s ratio=%s governor=%s" % ["PASS" if ok else "FAIL", shown, built, refused, ratio, toggled])
	quit(0 if ok else 1)
	return false
