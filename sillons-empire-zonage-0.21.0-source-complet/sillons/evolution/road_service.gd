class_name RoadService
extends RefCounted
static func preview(c: StarCampaign, team: int, body: String, path: Array) -> Dictionary:
	var pc: PlanetCampaign = c.planets
	var refusal: String = pc._guard(c, team, body)
	if not refusal.is_empty(): return PlanetCampaign.fail("colony", refusal)
	if path.is_empty() or path.size() > 144: return PlanetCampaign.fail("path", "tracé vide ou trop long")
	var p: Dictionary = pc.colony(team, body)
	var roads: Dictionary = {}
	for id in p["cells"]:
		if bool(p["cells"][id]["road"]): roads[id] = true
	var cost: Dictionary = {}
	var created: Array = []
	var previous: int = -1
	for raw in path:
		if not raw is int: return PlanetCampaign.fail("path", "district invalide")
		var id: int = int(raw)
		if id < 0 or id >= J13Rules.GRID_W * J13Rules.GRID_H: return PlanetCampaign.fail("land", "district hors carte")
		if previous >= 0 and previous != id and not PlanetCampaign.neighbors(previous).has(id): return PlanetCampaign.fail("continuity", "tracé discontinu")
		previous = id
		if roads.has(id): continue
		var sea: bool = pc.land_of(c, p, id) == J13Rules.LAND_OCEAN
		if not sea and not pc.eligible(c, p, id): return PlanetCampaign.fail("land", "district protégé ou relief non aménageable")
		var connected: bool = false
		for n in PlanetCampaign.neighbors(id):
			if roads.has(n): connected = true; break
		if not connected: return PlanetCampaign.fail("network", "commencez depuis un district relié")
		var price: Dictionary = J13Rules.LINK_COST if sea else J13Rules.ROAD_COST
		for res in price: cost[res] = float(cost.get(res, 0.0)) + float(price[res])
		created.append(id)
		roads[id] = true
	if created.is_empty(): return PlanetCampaign.fail("exists", "tracé déjà construit")
	var lack: String = pc.missing(c, team, body, cost)
	if not lack.is_empty(): return PlanetCampaign.fail("cost", "manque : " + lack)
	return {"ok": true, "cost": cost, "created_ids": created}
static func issue(c: StarCampaign, cmd: Dictionary) -> Dictionary:
	var path: Array = cmd.get("path", [])
	var team: int = int(cmd["team"])
	var body: String = String(cmd.get("body", ""))
	var result: Dictionary = preview(c, team, body, path)
	if not bool(result.get("ok", false)): return result
	c.planets._charge(c, team, body, result["cost"], "tracé routier validé")
	var p: Dictionary = c.planets.colony(team, body)
	for id in result["created_ids"]: p["cells"][id] = PlanetCampaign._new_cell()
	return result
