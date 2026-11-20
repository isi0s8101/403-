class_name EvolutionCampaign
extends RefCounted

static func sync(c: StarCampaign) -> void:
	for id in c.factions.actors():
		c.ensure_faction(int(id))
	for body in c.worlds.keys():
		var w: SimWorld = c.worlds[body]
		w.factions = c.factions
		w.external_plan_counts = MilitaryLogistics.external_counts(c, String(body))
		if c.planets.supply_chain and w.supply_gate == null: w.supply_gate = ColonyGate.new(c, String(body))
		for id in c.factions.actors():
			w.ensure_faction(int(id))
			var t: SimWorld.Team = w.teams[id]
			t.res = c.local_resources(int(id), String(body))
			t.age = c.planets.local_age(c, int(id), String(body))
			t.technologies = c.technologies[id]
			if CivEvolution.enabled(w): t.civ = c.civ_state(int(id))
			t.eliminated = c.eliminated[id]
			var p: Dictionary = c.planets.colony(int(id), String(body))
			if not p.is_empty(): PoliticalState.ensure(p)
			w.labor_factors[id] = PoliticalState.productivity(p)
	for id in c.factions.actors():
		c.resources[id] = c.local_resources(int(id), String(c.homes.get(id, "val")))

static func step(c: StarCampaign) -> void:
	sync(c)
	var keys: Array = c.worlds.keys()
	keys.sort()
	# Budget global équitable et déterministe ; les mondes hors écran ont la même part.
	var count: int = maxi(1, keys.size())
	for index in keys.size():
		var body: String = String(keys[index])
		var w: SimWorld = c.worlds[body]
		w.navigation_quota = 2 + (1 if posmod(c.tick, count) == index else 0)
		# 0.20 : ville détaillée à l'écran, abrégée dans les mondes lointains ; calculs décalés d'un monde à l'autre.
		w.urban_far = body != String(c.active)
		w.urban_phase = posmod(index, 3)
		if w.units.is_empty() and w.buildings.is_empty() and w.orbital_scans.is_empty(): w.tick += 1
		else: w.step()
		for team in c.factions.actors():
			c.planets.note_world_age(c, int(team), body, w.teams[team].age)
		if body != c.active:
			for event in w.events:
				if String(event.get("type", "")) in StarCampaign.OFFSCREEN_ALERT_TYPES:
					c._record_notice(int(event.get("team", -1)), String(event.get("text", "Alerte")), body)
			w.events.clear()
	c._tick_flights()
	c._tick_surveys()
	c._tick_freight()
	OrbitalIndustry.step(c)
	c.planets.step(c)
	OrbitalTactics.step(c)
	if c.tick % 50 == 0: PoliticalState.step(c)
	TreatyService.step(c)
	MilitaryLogistics.step(c)
	if c.tick % 10 == 0: c._ai_expansion()
	if c.tick % 100 == 0: _defeat(c)
	sync(c)
	c.tick += 1

static func _defeat(c: StarCampaign) -> void:
	for team in c.factions.actors():
		var capable: bool = c.planets.has_command(c, int(team)) or c.planets.assembling(int(team))
		for w in c.worlds.values():
			if not w.team_buildings(int(team), "centre", true).is_empty() or not w.team_units(int(team), "builder").is_empty(): capable = true
		for flight in c.flights:
			if int(flight["team"]) == team: capable = true
		for body in c.sector_keys():
			if OrbitalIndustry.has_hub(c, int(team), String(body)): capable = true
		if capable: c.lost_centers_at[team] = -1
		elif int(c.lost_centers_at[team]) < 0: c.lost_centers_at[team] = c.tick
		elif c.tick - int(c.lost_centers_at[team]) > int(Rules.REBUILD_TIMEOUT * Rules.TICK_RATE): c.eliminated[team] = true
	var foes_alive: bool = false
	for enemy in c.factions.enemies(0):
		if not bool(c.eliminated[enemy]): foes_alive = true
	if bool(c.eliminated[0]) or not foes_alive:
		c.game_over = true
		c.winner = -1 if bool(c.eliminated[0]) else 0
		for w in c.worlds.values():
			w.game_over = true
			w.winner = c.winner
