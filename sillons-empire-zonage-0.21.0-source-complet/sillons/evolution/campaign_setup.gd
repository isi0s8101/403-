class_name CampaignSetup
extends RefCounted
## Origines symétriques, physiquement séparées ; aucun cadeau à l'IA.
static func create(c: StarCampaign, seed: int, player_ai: bool = false, dimension: int = 256) -> void:
	c.evolutions_enabled = true
	c.orbital_tactics = true
	c._initial_seed = maxi(1, seed)
	c.star_catalog = StarSystemGenerator.new(c._initial_seed)
	c.factions = FactionRegistry.new()
	c.factions.records[1]["home"] = "nemesis"
	c.homes = {0: "val", 1: "nemesis"}
	c.discovered_systems = [{"sol": true}, {"proxima": true}]
	c.worlds.clear()
	c.raw_stocks.clear()
	c.planets = PlanetCampaign.new()
	c.active = "val"
	c.tick = 0
	for i in StarCampaign.SECTORS.size():
		var body: String = StarCampaign.SECTORS[i]
		var owner: int = 0 if body == "val" else (1 if body == "nemesis" else -1)
		var w := SimWorld.new()
		w.setup(c._initial_seed + i * 100003, GameConfig.merge_rules({"campaign": true, "sector": body, "evolutions": true, "map_size": dimension, "home_team": owner, "max_age": 10, "civ_evolution": GameConfig.civ_evolution}))
		w.factions = c.factions
		if owner >= 0:
			w.start_standard()
			c.raw_stocks[PlanetCampaign.key(owner, body)] = w.teams[owner].res.duplicate(true)
			if owner == 1 or player_ai:
				w.teams[owner].ai_controlled = true
				w.ai_controllers.append(AiController.new(owner))
		c.worlds[body] = w
	for team in [0, 1]:
		c.resources[team] = c.local_resources(team, String(c.homes[team]))
		c.planets.found(c, team, String(c.homes[team]), "home", 0)
		c.planets._mint(c, team, "treasury", J13Rules.SCENARIO_CREDITS, "dotation initiale identique")
	c._sync_all()
