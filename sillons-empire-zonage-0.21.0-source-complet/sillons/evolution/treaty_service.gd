class_name TreatyService
extends RefCounted
static func issue(c: StarCampaign, cmd: Dictionary) -> Dictionary:
	var team: int = int(cmd["team"])
	var target: int = int(cmd.get("target", -1))
	var body: String = String(cmd.get("body", ""))
	var p: Dictionary = c.planets.colony(target, body)
	if p.is_empty() or target == team or not c.valid_faction(target): return PlanetCampaign.fail("target", "administration indépendante absente")
	PoliticalState.ensure(p)
	if not c.system_known(team, c._system_of(body)): return PlanetCampaign.fail("knowledge", "monde inconnu")
	var kind: String = String(cmd.get("kind", ""))
	var ps: Dictionary = p["politics"]
	for treaty in c.treaties:
		if int(treaty["team"]) == team and String(treaty["body"]) == body and String(treaty["state"]) == "pending": return PlanetCampaign.fail("pending", "engagement déjà en cours")
	var source_body: String = String(cmd.get("source", c.homes.get(team, "")))
	if not cmd.has("source") and not c.planets.has_colony(team, source_body):
		var candidates: Array = c.planets.colonies.keys()
		candidates.sort()
		for id in candidates:
			var owned: Dictionary = c.planets.colonies[id]
			if int(owned["team"]) == team and String(owned["status"]) != "lost":
				source_body = String(owned["body"])
				break
	if not c.worlds.has(source_body): return PlanetCampaign.fail("source", "monde de départ absent")
	if not c.planets.has_colony(team, source_body) and c.worlds[source_body].team_buildings(team, "centre", true).is_empty(): return PlanetCampaign.fail("source", "dépôt de départ indisponible")
	var common: Dictionary = {"team": team, "target": target, "body": body, "kind": kind, "state": "pending", "since": c.tick, "progress": 0, "delivered": false, "source": source_body, "goods": {}, "access": {"fire": false, "landing": false, "military_passage": false, "trade": false}}
	match kind:
		"aid":
			var stock: Dictionary = c.local_resources(team, source_body)
			if float(stock["food"]) < 100.0: return PlanetCampaign.fail("cost", "100 vivres requis dans le dépôt de départ")
			# Délais et portes spatiales existants. Aucune téléportation d'aide.
			if source_body != body:
				if int(c.ages[team]) < 9 or not c.system_has_port(team, c._system_of(source_body)): return PlanetCampaign.fail("route", "spatioport et âge IX requis pour une aide interplanétaire")
				if c._system_of(source_body) != c._system_of(body) and int(c.ages[team]) < 10: return PlanetCampaign.fail("age", "âge X requis entre systèmes")
			common["carrier"] = "distribution"
			if source_body != body:
				var fleet: Dictionary = OrbitalIndustry.presence(c, team, source_body)
				if int(fleet.get("navette", 0)) > 0:
					common["carrier"] = "navette"
				else:
					for res in J13Rules.SURFACE_LAUNCH_COST:
						var required: float = float(J13Rules.SURFACE_LAUNCH_COST[res]) + (100.0 if res == "food" else 0.0)
						if float(stock.get(res, 0.0)) < required: return PlanetCampaign.fail("carrier", "navette indisponible et ressources insuffisantes pour le lancement")
					common["carrier"] = "lancement"
				if common["carrier"] == "navette": fleet["navette"] = int(fleet["navette"]) - 1
				else:
					for res in J13Rules.SURFACE_LAUNCH_COST: stock[res] = float(stock[res]) - float(J13Rules.SURFACE_LAUNCH_COST[res])
			stock["food"] = float(stock["food"]) - 100.0
			common["goods"] = {"food": 100.0}
			common["duration"] = 100 if source_body == body else StarCampaign.expected_flight_duration(c.star_catalog, source_body, body)
			common["access"]["trade"] = true
			c.factions.set_relation(team, target, "truce")
		"autonomy", "federation":
			if float(ps["wellbeing"]) < 45.0 or float(ps.get("trust", 0.0)) < 25.0: return PlanetCampaign.fail("refusal", "refus : bien-être ≥ 45 et confiance ≥ 25 nécessaires ; livrez une aide et maintenez les engagements")
			common["duration"] = 600
			common["access"]["trade"] = true
			c.factions.set_relation(team, target, "truce")
		"vote":
			if float(ps.get("trust", 0.0)) < 50.0 or float(ps["wellbeing"]) < 60.0: return PlanetCampaign.fail("refusal", "vote refusé : confiance ≥ 50 et bien-être ≥ 60 requis")
			common["duration"] = 900
		"protection":
			var threatened: bool = false
			for enemy in c.factions.enemies(target):
				if int(enemy) != team and c.worlds[body].team_units(int(enemy), "military").size() > 0: threatened = true
			if not threatened or c.worlds[body].team_units(team, "military").size() < 3: return PlanetCampaign.fail("protection", "menace extérieure et trois défenseurs réguliers présents requis")
			common["duration"] = 600
			c.factions.set_relation(team, target, "truce")
		"occupation":
			if c.planets.landing_blocked(c, team, body) > 0: return PlanetCampaign.fail("orbit", "station orbitale ennemie encore opérationnelle")
			if not c.factions.hostile(team, target): return PlanetCampaign.fail("war", "aucun état de guerre")
			common["duration"] = 300
		_: return PlanetCampaign.fail("kind", "offre inconnue")
	c.treaties.append(common)
	return {"ok": true, "duration": common["duration"]}
static func step(c: StarCampaign) -> void:
	for t in c.treaties:
		if String(t["state"]) == "returning":
			t["progress"] = int(t["progress"]) + 1
			if int(t["progress"]) >= int(t["duration"]):
				var depot: Dictionary = c.local_resources(int(t["team"]), String(t["source"]))
				for res in t["goods"]: depot[res] = float(depot.get(res, 0.0)) + float(t["goods"][res])
				t["goods"] = {}
				if String(t.get("carrier", "")) == "navette":
					var fleet: Dictionary = OrbitalIndustry.presence(c, int(t["team"]), String(t["source"]))
					fleet["navette"] = int(fleet.get("navette", 0)) + 1
				t["state"] = "returned"
			continue
		if String(t["state"]) != "pending": continue
		var p: Dictionary = c.planets.colony(int(t["target"]), String(t["body"]))
		if p.is_empty():
			t["state"] = "returning" if String(t["kind"]) == "aid" and not bool(t["delivered"]) else "cancelled"
			t["progress"] = 0
			continue
		var ps: Dictionary = p["politics"]
		var kind: String = String(t["kind"])
		var condition: bool = true
		if kind == "occupation":
			var w: SimWorld = c.worlds[t["body"]]
			var defenders_near: int = 0
			var capital: Vector2 = ps.get("capital_pos", Vector2(w.map_size * 0.5, w.map_size * 0.5))
			for u in w.team_units(int(t["team"]), "military"):
				if u.pos.distance_to(capital) <= 20.0: defenders_near += 1
			condition = defenders_near >= 3 and w.team_buildings(int(t["target"]), "centre", true).is_empty() and w.team_units(int(t["target"]), "military").is_empty() and w.team_units(int(t["team"]), "military").size() >= 3 and c.planets.landing_blocked(c, int(t["team"]), String(t["body"])) == 0
		elif kind in ["autonomy", "federation", "vote"]: condition = float(ps["wellbeing"]) >= (60.0 if kind == "vote" else 45.0)
		if condition: t["progress"] = int(t["progress"]) + 1
		else: t["progress"] = 0
		if int(t["progress"]) < int(t["duration"]): continue
		if kind == "aid" and not bool(t["delivered"]):
			var stock: Dictionary = c.local_resources(int(t["target"]), String(t["body"]))
			stock["food"] = float(stock["food"]) + float(t["goods"]["food"])
			t["delivered"] = true
			t["goods"] = {}
			if String(t.get("carrier", "")) == "navette":
				var fleet: Dictionary = OrbitalIndustry.presence(c, int(t["team"]), String(t["body"]))
				fleet["navette"] = int(fleet.get("navette", 0)) + 1
			ps["trust"] = minf(100.0, float(ps.get("trust", 0.0)) + 30.0)
		elif kind == "federation": c.factions.set_relation(int(t["team"]), int(t["target"]), "federated")
		elif kind == "autonomy":
			ps["autonomy"] = 0.7
			ps["protector"] = int(t["team"])
			c.factions.set_relation(int(t["team"]), int(t["target"]), "autonomous")
		elif kind == "protection":
			ps["trust"] = minf(100.0, float(ps.get("trust", 0.0)) + 25.0)
			c.factions.set_relation(int(t["team"]), int(t["target"]), "allied")
		elif kind in ["vote", "occupation"]:
			var result: Dictionary = RevoltTransaction.reintegrate(c, p, int(t["team"]), kind == "occupation")
			if not bool(result["ok"]): t["state"] = "refused"; continue
			if kind == "vote": c.factions.set_relation(int(t["team"]), int(t["target"]), "allied")
		t["state"] = "fulfilled"
		c._record_notice(int(t["team"]), "Engagement achevé : " + kind, String(t["body"]))

static func can_land(c: StarCampaign, team: int, body: String) -> bool:
	for p in c.planets.colonies.values():
		var owner: int = int(p["team"])
		if String(p["body"]) != body or owner == team or String(p["status"]) == "lost": continue
		if c.factions.hostile(team, owner): continue
		var allowed: bool = false
		for treaty in c.treaties:
			if int(treaty["team"]) == team and int(treaty["target"]) == owner and String(treaty["body"]) == body and String(treaty["state"]) == "fulfilled" and bool(treaty["access"].get("landing", false)): allowed = true
		if not allowed: return false
	return true
