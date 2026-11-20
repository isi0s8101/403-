class_name ModernSystems
extends RefCounted
## J3-J5. Toutes les horloges utilisent les ticks, jamais l'horloge système.

static func command(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var kind: String = String(cmd.get("t", ""))
	var b: SimWorld.Building = w.buildings.get(int(cmd.get("building", -1))) as SimWorld.Building
	if b == null or b.team != team or not b.complete:
		return w._no("bâtiment allié achevé requis")
	var t: SimWorld.Team = w.teams[team]
	if kind == "technology":
		if bool(w.rules.get("campaign", false)) and String(w.rules.get("sector", "val")) != "val":
			return w._no("recherche globale centralisée depuis le secteur Val")
		var key: String = String(cmd.get("key", ""))
		if not Rules.TECHNOLOGIES.has(key):
			return w._no("technologie inconnue")
		var d: Dictionary = Rules.TECHNOLOGIES[key]
		if UrbanCity.tech_lack(w, key) != "": return w._no(UrbanCity.tech_lack(w, key))
		if t.age < int(d["age"]) or b.type != String(d["building"]):
			return w._no("âge ou bâtiment requis manquant")
		for requirement_value in d.get("requires", []):
			var prerequisite: String = String(requirement_value)
			if not t.technologies.has(prerequisite):
				return w._no("recherche préalable requise : " + String(Rules.TECHNOLOGIES[prerequisite]["label"]))
		if t.technologies.has(key) or not t.tech_research.is_empty():
			return w._no("technologie acquise ou recherche déjà en cours")
		var cost: Dictionary = w.scaled_cost(d["cost"])
		if not w._can_pay(team, cost):
			return w._no(w._missing_text(team, cost))
		w._pay(team, cost)
		t.tech_research = {"key": key, "building": b.id, "remaining": float(d["time"])}
		return w._ok()
	if b.type != "silo" or t.age < 7 or b.cd > 0.0:
		return w._no("silo prêt d'âge VII requis (recharge 60 s)")
	var pos: Vector2 = w._v2(cmd.get("pos", [-1, -1]))
	if not pos.is_finite() or pos.x < 0 or pos.y < 0 or pos.x >= w.map_size or pos.y >= w.map_size:
		return w._no("cible hors carte")
	if not w.is_visible_to(team, pos):
		return w._no("cible actuellement visible requise")
	var cost: Dictionary = w.scaled_cost({"ore": 250})
	if not w._can_pay(team, cost):
		return w._no(w._missing_text(team, cost))
	w._pay(team, cost)
	b.cd = 60.0
	w.modern["missiles"].append({"team": team, "pos": pos, "remaining": 50, "from": b.center})
	w.emit("alerte_missile", 1 - team, "Missile en approche : impact dans 5 s", {"pos": pos})
	return w._ok()

static func can_target(u: SimWorld.Unit, target) -> bool:
	if target is SimWorld.Unit and Rules.unit_has(target.type, "air"):
		return Rules.unit_has(u.type, "air") or Rules.unit_has(u.type, "anti_air")
	return true

static func efficiency(w: SimWorld, u: SimWorld.Unit) -> float:
	var factor: float = 0.5 if u.supply <= 0.0 else 1.0
	if Rules.unit_has(u.type, "air") and w.teams[u.team].technologies.has("propulsion_orbitale"):
		factor *= 1.2
	if Rules.unit_has(u.type, "electronic"):
		for enemy in w.units.values():
			if w.factions.hostile(u.team, enemy.team) and Rules.unit_has(enemy.type, "jammer") and enemy.pos.distance_squared_to(u.pos) <= 100.0:
				factor *= 0.85 if w.teams[u.team].technologies.has("contre_mesures") else 0.5
				break
	return factor

static func step(w: SimWorld) -> void:
	for t in w.teams:
		if t.id >= 2 or t.tech_research.is_empty():
			continue
		var source: SimWorld.Building = w.buildings.get(int(t.tech_research["building"])) as SimWorld.Building
		if source == null:
			w.emit("recherche_perdue", t.id, "Recherche perdue : bâtiment détruit")
			t.tech_research = {}
			continue
		t.tech_research["remaining"] -= Rules.DT * CivEvolution.speed_mult(w, t.id, "research_speed")
		if float(t.tech_research["remaining"]) <= 0.0:
			var key: String = String(t.tech_research["key"])
			t.technologies[key] = true
			t.tech_research = {}
			w.emit("technologie", t.id, "Recherche achevée : " + String(Rules.TECHNOLOGIES[key]["label"]))
	for b in w.buildings.values():
		if b.complete and b.type in ["silo", "intercepteur"]:
			b.cd = maxf(0.0, b.cd - Rules.DT)
	if w.tick % 10 == 0:
		_network(w)
		for b in w.buildings.values():
			if b.team == SimWorld.TEAM_NEUTRAL or not b.complete or b.type != "usine":
				continue
			# Transformation limitée par le bois : aucune création gratuite de minerai.
			var stock: Dictionary = w.teams[b.team].res
			var throughput: float = w.labor(b.team)
			if float(stock["wood"]) >= 2.0 * throughput:
				stock["wood"] -= 2.0 * throughput
				stock["ore"] += 1.5 * throughput
		for u in w.units.values():
			if not (Rules.unit_has(u.type, "vehicle") or Rules.unit_has(u.type, "air")):
				continue
			var fed: bool = false
			for b in w.team_buildings(u.team, "", true):
				if b.type in ["centre", "depot", "gare", "aerodrome"] and w.modern["connected"].has(b.id) and u.pos.distance_squared_to(b.center) <= 144.0:
					fed = true
					break
			for tr in w.team_units(u.team, "rail"):
				if tr.state == "rail" and tr.pos.distance_squared_to(u.pos) <= 64.0:
					fed = true
			if fed:
				var food: float = float(w.teams[u.team].res["food"])
				if food >= 1.0:
					w.teams[u.team].res["food"] -= 1.0
					u.supply = minf(100.0, u.supply + 10.0)
				else:
					u.supply = maxf(0.0, u.supply - 1.0)
			else:
				u.supply = maxf(0.0, u.supply - 1.0)
	for missile in w.modern["missiles"].duplicate():
		missile["remaining"] -= 1
		var intercepted: bool = false
		for b in w.buildings.values():
			if b.complete and w.factions.hostile(int(missile["team"]), b.team) and b.type == "intercepteur" and b.cd <= 0.0 and b.center.distance_squared_to(missile["pos"]) <= 196.0:
				b.cd = 20.0
				intercepted = true
				w.emit("interception", b.team, "Missile intercepté", {"pos": missile["pos"]})
				break
		if intercepted:
			w.modern["missiles"].erase(missile)
		elif int(missile["remaining"]) <= 0:
			var source := SimWorld.Unit.new()
			source.team = int(missile["team"])
			# Pas de riposte vers un id inexistant : les dégâts utilisent une source bâtiment.
			var proxy := SimWorld.Building.new()
			proxy.team = source.team
			for e in w.units.values() + w.buildings.values():
				if e.team == SimWorld.TEAM_NEUTRAL:
					continue
				var distance: float = w.entity_pos(e).distance_to(missile["pos"])
				if distance < 5.0:
					w._damage(e, 450.0 * (1.0 - distance / 5.0), proxy)
			w.emit("tir", source.team, "Impact missile", {"from": missile["from"], "to": missile["pos"], "siege": true})
			w.modern["missiles"].erase(missile)

static func _network(w: SimWorld) -> void:
	var connected: Array = []
	var links: Array = []
	for team in w.faction_ids():
		var hubs: Array = []
		for b in w.team_buildings(team, "", true):
			if b.type in ["centre", "depot", "gare", "aerodrome"]:
				hubs.append(b)
				if b.type == "centre":
					connected.append(b.id)
		# Liens automatiques courts, terrain et obstacles réels pris en compte.
		for i in hubs.size():
			for j in range(i + 1, hubs.size()):
				var a: SimWorld.Building = hubs[i]
				var b: SimWorld.Building = hubs[j]
				if a.center.distance_squared_to(b.center) > 576.0:
					continue
				var start: Vector2 = w.approach_point(b.center, a.center, a.size * 0.5 + 1.0)
				var end: Vector2 = w.approach_point(start, b.center, b.size * 0.5 + 1.0)
				if start.x < 0 or end.x < 0:
					continue
				var route: PackedVector2Array = w.find_path(start, end)
				if route.is_empty() or w.path_length(route, start) > 32.0:
					continue
				links.append({"a": a.id, "b": b.id, "path": route, "start": start, "end": end, "rail": a.type == "gare" and b.type == "gare"})
		for iteration in hubs.size():
			var changed: bool = false
			for link in links:
				if connected.has(link["a"]) and not connected.has(link["b"]):
					connected.append(link["b"])
					changed = true
				if connected.has(link["b"]) and not connected.has(link["a"]):
					connected.append(link["a"])
					changed = true
			if not changed:
				break
	w.modern["rail_links"] = links
	w.modern["connected"] = connected

static func train_step(w: SimWorld, u: SimWorld.Unit) -> void:
	var route: Dictionary = {}
	for link in w.modern["rail_links"]:
		if not bool(link["rail"]) or not w.modern["connected"].has(link["a"]):
			continue
		var a: SimWorld.Building = w.buildings[int(link["a"])]
		if a.team != u.team:
			continue
		if u.rail_a == int(link["a"]) and u.rail_b == int(link["b"]):
			route = link
			break
		if route.is_empty() and u.pos.distance_to(a.center) < 10.0:
			route = link
	if route.is_empty():
		u.state = "idle"
		u.blocked_reason = "deux gares reliées au centre requises (24 cases max)"
		return
	u.rail_a = int(route["a"])
	u.rail_b = int(route["b"])
	u.blocked_reason = ""
	u.state = "rail"
	var destination: Vector2 = route["end"] if u.trade_leg == 0 else route["start"]
	if w._move_towards(u, destination, 0.4):
		u.trade_leg = 1 - u.trade_leg
