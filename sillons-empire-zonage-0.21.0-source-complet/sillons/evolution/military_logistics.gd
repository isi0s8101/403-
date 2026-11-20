class_name MilitaryLogistics
extends RefCounted
static func issue(c: StarCampaign, cmd: Dictionary) -> Dictionary:
	var team: int = int(cmd["team"])
	var source: String = String(cmd.get("source", c.active))
	var target: String = String(cmd.get("target", ""))
	var id: int = int(cmd.get("plan", -1))
	if source == target or not c.worlds.has(source) or not c.is_unlocked(team, target): return PlanetCampaign.fail("route", "destination connue et accessible requise")
	if c.planets.landing_blocked(c, team, target) > 0 or not TreatyService.can_land(c, team, target): return PlanetCampaign.fail("access", "orbite ou accès diplomatique bloqué")
	var w: SimWorld = c.worlds[source]
	if not w.army_plans.has(id) or int(w.army_plans[id]["team"]) != team: return PlanetCampaign.fail("army", "plan de renfort allié requis")
	var port: int = -1
	var interstellar: bool = c._system_of(source) != c._system_of(target)
	for b in w.team_buildings(team, "", true):
		if b.type == "chantier_orbital" or (not interstellar and b.type == "spatioport"): port = b.id; break
	if port < 0 or c.ages[team] < (10 if interstellar else 9): return PlanetCampaign.fail("port", "âge IX et spatioport, ou âge X et plateforme stellaire requis")
	for mission in c.reinforcements:
		if String(mission["source"]) == source and int(mission["plan"]) == id: return PlanetCampaign.fail("mission", "plan déjà affecté à une mission")
	var dest: SimWorld = c.materialize(target)
	if dest == null: return PlanetCampaign.fail("world", "destination indisponible")
	var position: Vector2 = RallyService.nearest(dest, Vector2(WorldLayout.base_cell(dest, team)) + Vector2(7, 7))
	if cmd.has("pos"): position = dest._v2(cmd["pos"])
	if not position.is_finite() or not dest.walkable(dest.cell_of(position)): return PlanetCampaign.fail("point", "zone d'arrivée terrestre libre requise")
	var rally: Vector2 = RallyService.nearest(w, w.buildings[port].center + Vector2(7, 0))
	w.army_plans[id]["pos"] = rally
	c.reinforcements.append({"team": team, "source": source, "target": target, "plan": id, "port": port, "pos": position, "status": "regroupement au port", "sent": 0})
	return {"ok": true}
static func step(c: StarCampaign) -> void:
	if c.tick % 50 != 0: return
	for mission in c.reinforcements:
		var team: int = int(mission["team"])
		var w: SimWorld = c.worlds[mission["source"]]
		var port: SimWorld.Building = w.buildings.get(int(mission["port"])) as SimWorld.Building
		if port == null or port.team != team: mission["status"] = "port perdu"; continue
		var plan: Dictionary = w.army_plans.get(int(mission["plan"]), {})
		if plan.is_empty() or not bool(plan["enabled"]): mission["status"] = "plan suspendu"; continue
		var cargo: Array = []
		var dest: SimWorld = c.worlds[mission["target"]]
		if dest.team_buildings(team, "centre", true).is_empty():
			for worker in w.team_units(team, "worker"):
				if worker.pos.distance_to(port.center) < 20:
					cargo.append(worker.id)
					break
			if cargo.is_empty(): mission["status"] = "un bâtisseur doit rejoindre le port"; continue
		for u in w.team_units(team, "military"):
			if u.army_plan != int(mission["plan"]) or u.army_origin != String(mission["source"]) or u.wave_pending: continue
			if u.pos.distance_to(port.center) < 20 and cargo.size() < 6: cargo.append(u.id)
		if cargo.is_empty() or (cargo.size() == 1 and Rules.unit_has(w.units[cargo[0]].type, "worker")): mission["status"] = "renforts en regroupement"; continue
		var result: Dictionary = c.dispatch(team, String(mission["source"]), port.id, String(mission["target"]), cargo)
		if bool(result.get("ok", false)):
			c.flights.back()["reinforcement_pos"] = mission["pos"]
			mission["sent"] = int(mission["sent"]) + cargo.size()
			mission["status"] = "transport réel en route"
		else: mission["status"] = result.get("reason", "en attente")
static func external_counts(c: StarCampaign, source: String) -> Dictionary:
	var out: Dictionary = {}
	for body in c.worlds:
		if String(body) == source: continue
		for u in c.worlds[body].units.values():
			if u.army_origin == source and u.army_plan > 0:
				_count(out, u.army_plan, u.type)
	for flight in c.flights:
		for unit in flight["units"]:
			var meta: Dictionary = unit.get("identity", {})
			if String(meta.get("army_origin", "")) == source and int(meta.get("army_plan", -1)) > 0: _count(out, int(meta["army_plan"]), String(unit["type"]))
	return out
static func _count(counts: Dictionary, plan: int, kind: String) -> void:
	if not counts.has(plan): counts[plan] = {}
	counts[plan][kind] = int(counts[plan].get(kind, 0)) + 1
