class_name AndroidPerfFixture
extends RefCounted
## Charges synthétiques réservées au laboratoire, sans lecture de sauvegarde.
const SEED: int = 15101
const KINDS: Array[String] = ["large", "fronts", "orbit"]

static func build(kind: String) -> StarCampaign:
	assert(kind in KINDS)
	var campaign: StarCampaign = StarCampaign.new()
	CampaignSetup.create(campaign, SEED, false, 256)
	for world in campaign.worlds.values(): world.ai_controllers.clear()
	if kind == "large":
		(campaign.worlds["nemesis"] as SimWorld).ai_controllers.append(AiController.new(1))
	else:
		for body in StarCampaign.SECTORS:
			if kind == "fronts":
				_add_ground_front(campaign.worlds[body] as SimWorld)
			else:
				for team in [0, 1]:
					campaign.orbital_sites[OrbitalIndustry.key(team, body)] = OrbitalIndustry._new_site(team, body, 0)
					campaign.orbital_presence[OrbitalIndustry.key(team, body)] = {"intercepteur": 16, "fregate": 4}
		campaign.ages = [10, 10]
		campaign.orbital_initial_granted = [true, true]
		for team in [0, 1]:
			campaign.discovered_systems[team] = {"sol": true, "proxima": true}
			for technology in ViewTechnology.RESEARCH_ORDER: campaign.technologies[team][technology] = true
	OrbitalTactics.enable(campaign)
	if kind == "orbit":
		for body in StarCampaign.SECTORS:
			var actors: Dictionary = OrbitalTactics.map_for(campaign, body)["actors"] as Dictionary
			var indices: Dictionary = {0: 0, 1: 0}
			for actor in actors.values():
				if String(actor["role"]) != "unit": continue
				var team: int = int(actor["team"])
				var index: int = int(indices[team])
				actor["pos"] = Vector2(52.0 + float(index % 10) * 5.0, 33.0 + floorf(float(index) / 10.0) * 3.0 + float(team) * 9.0)
				actor["prev"] = actor["pos"]
				actor["order"] = {"type": "hold", "pos": actor["pos"]}
				indices[team] = index + 1
	return campaign

static func _add_ground_front(world: SimWorld) -> void:
	for team in [0, 1]:
		world.teams[team].pop_cap = 1000
		var ids: Array[int] = []
		for index in 60:
			var point: Vector2 = Vector2(24.5 + float(index % 10) * 1.4, 56.5 + floorf(float(index) / 10.0) * 1.4 + float(team) * 18.0)
			var unit: SimWorld.Unit = world.spawn_unit(team, "lancier" if index % 3 else "tireur", point)
			ids.append(unit.id)
		var target_cell: Vector2i = world.nearest_walkable(Vector2i(31, 70 if team == 0 else 62), Vector2(31, 66))
		world.issue({"t": "amove", "team": team, "units": ids, "pos": Vector2(target_cell) + Vector2.ONE * 0.5})
	world.update_fog(true)

static func counts(campaign: StarCampaign) -> Dictionary:
	var units: int = 0
	var ships: int = 0
	var ticks: Dictionary = {}
	for body in campaign.worlds:
		var world: SimWorld = campaign.worlds[body] as SimWorld
		units += world.units.size(); ticks[body] = world.tick
	for field in campaign.orbital_maps.values():
		for actor in field["actors"].values():
			if String(actor["role"]) == "unit": ships += 1
	return {"worlds": campaign.worlds.size(), "dimension": 256, "ground_units": units, "orbital_ships": ships, "world_ticks": ticks}
