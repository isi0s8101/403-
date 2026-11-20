class_name PoliticalState
extends RefCounted
const VERSION: int = 1
const STAGES := ["stable", "discontent", "protest", "demands", "agreement", "revolt", "occupation"]
static func ensure(p: Dictionary) -> void:
	if p.has("politics"): return
	p["politics"] = {"version": VERSION, "wellbeing": 65.0, "loyalty": 70.0,
		"tax": 0.2, "budget": 1.0, "autonomy": 0.0, "mobilization": 0.0,
		"stage": "stable", "stress": 0, "stable_ticks": 0, "grace_until": 0,
		"deadline": -1, "terms": {}, "accepted": false, "factors": {},
		"sovereign": true, "service_paid": 1.0, "occupation": 0, "districts": {}}
static func productivity(p: Dictionary) -> float:
	if p.is_empty(): return 1.0
	ensure(p)
	return clampf(0.75 + 0.005 * float(p["politics"]["wellbeing"]), 0.75, 1.15)
static func issue(c: StarCampaign, cmd: Dictionary) -> Dictionary:
	var team: int = int(cmd.get("team", -1))
	var body: String = String(cmd.get("body", ""))
	var p: Dictionary = c.planets.colony(team, body)
	if p.is_empty() or String(p["status"]) == "lost": return PlanetCampaign.fail("colony", "administration absente")
	ensure(p)
	var ps: Dictionary = p["politics"]
	if String(cmd["t"]) == "policy":
		var field: String = String(cmd.get("field", ""))
		if field not in ["tax", "budget", "autonomy", "mobilization"]: return PlanetCampaign.fail("policy", "politique inconnue")
		var raw: Variant = cmd.get("value")
		if not (raw is int or raw is float) or not is_finite(float(raw)) or float(raw) < 0.0 or float(raw) > (2.0 if field == "budget" else 1.0): return PlanetCampaign.fail("value", "valeur hors limites")
		ps[field] = float(raw)
		return {"ok": true}
	if String(ps["stage"]) not in ["demands", "agreement"]: return PlanetCampaign.fail("crisis", "aucune revendication en cours")
	match String(cmd.get("answer", "")):
		"accept":
			ps["accepted"] = true
			ps["stage"] = "agreement"
		"counter":
			if bool(ps["accepted"]): return PlanetCampaign.fail("terms", "un accord signé garde ses conditions")
			ps["terms"] = {"max_tax": 0.15, "min_autonomy": 0.6, "min_food": 5.0}
			ps["deadline"] = c.tick + 900
			ps["accepted"] = true
			ps["stage"] = "agreement"
		"refuse":
			ps["deadline"] = mini(int(ps["deadline"]), c.tick + 100)
		_: return PlanetCampaign.fail("answer", "réponse inconnue")
	return {"ok": true, "deadline": ps["deadline"]}
static func terms_met(c: StarCampaign, p: Dictionary) -> bool:
	var ps: Dictionary = p["politics"]
	var terms: Dictionary = ps["terms"]
	return not terms.is_empty() and float(ps["tax"]) <= float(terms["max_tax"]) + 0.00001 and float(ps["autonomy"]) >= float(terms["min_autonomy"]) and float(c.local_resources(int(p["team"]), String(p["body"])).get("food", 0.0)) >= float(terms["min_food"])
static func _factors(c: StarCampaign, p: Dictionary) -> Dictionary:
	var team: int = int(p["team"])
	var body: String = String(p["body"])
	var age: int = c.planets.local_age(c, team, body)
	var ps: Dictionary = p["politics"]
	var stats: Dictionary = p["stats"]
	var w: SimWorld = c.worlds.get(body) as SimWorld
	var pop: float = float(p["pop"])
	var factors: Dictionary = {}
	var food: float = float(c.local_resources(team, body).get("food", 0.0))
	factors["Subsistance"] = {"value": clampf(food / maxf(20.0, pop * 0.5), 0.0, 1.0), "weight": 3.0}
	var housing: float = 1.0
	if pop > 0.0 and age >= 7: housing = clampf(float(stats.get("housing", pop)) / pop, 0.0, 1.0)
	elif w != null: housing = clampf(float(w.teams[team].pop_cap) / maxf(1.0, float(w.teams[team].pop)), 0.0, 1.0)
	factors["Habitat"] = {"value": housing, "weight": 2.0}
	factors["Fiscalité"] = {"value": clampf(1.0 - float(ps["tax"]) * 1.4, 0.0, 1.0), "weight": 2.0}
	factors["Mobilisation"] = {"value": 1.0 - float(ps["mobilization"]), "weight": 1.0}
	var safety: float = 1.0
	if w != null:
		for u in w.team_units(team):
			if u.hit_tick > w.tick - 100: safety = 0.3; break
	factors["Sécurité"] = {"value": safety, "weight": 1.0}
	if pop > 0.0 and age >= 4:
		var employed: float = float(stats.get("employed", 0.0))
		var workers: float = float(stats.get("workers", 0.0))
		factors["Activité"] = {"value": clampf(employed / maxf(1.0, workers), 0.0, 1.0), "weight": 1.0}
		var pollution: float = 0.0
		for cell in (p["cells"] as Dictionary).values():
			if String(cell["zone"]) == "I": pollution += 0.05 * float(cell["density"])
		factors["Environnement"] = {"value": maxf(0.2, 1.0 - pollution), "weight": 1.0}
	# Les services macro ne sont exigés que sur des quartiers habités, dès leur âge disponible.
	if pop > 0 and age >= 7:
		factors["Eau"] = {"value": float(stats.get("water", 0.0)), "weight": 2.0}
		factors["Énergie"] = {"value": float(stats.get("power", 0.0)), "weight": 2.0}
		factors["Services"] = {"value": clampf(float(stats.get("hospital", 0.0)) * float(ps["service_paid"]), 0.0, 1.0), "weight": 1.0}
	return factors
static func step(c: StarCampaign) -> void:
	var ids: Array = c.planets.colonies.keys()
	ids.sort()
	var revolts: Array = []
	for id in ids:
		var p: Dictionary = c.planets.colonies[id]
		if String(p["status"]) == "lost": continue
		ensure(p)
		var ps: Dictionary = p["politics"]
		var team: int = int(p["team"])
		var body: String = String(p["body"])
		var charge: float = float(p["pop"]) * 0.01 * float(ps["budget"])
		var account: Dictionary = c.planets.treasury[team]
		var paid: float = minf(float(account["credits"]), charge)
		account["credits"] = float(account["credits"]) - paid
		account["spent"] = float(account["spent"]) + paid
		ps["service_paid"] = 0.0 if float(ps["budget"]) == 0.0 else minf(1.0, float(ps["budget"]) * (1.0 if charge == 0.0 else paid / charge))
		ps["factors"] = _factors(c, p)
		var total: float = 0.0
		var weights: float = 0.0
		for factor in (ps["factors"] as Dictionary).values():
			total += float(factor["value"]) * float(factor["weight"])
			weights += float(factor["weight"])
		var target: float = districts(c, p, clampf(total * 100.0 / maxf(1.0, weights), 0.0, 100.0))
		ps["wellbeing"] = move_toward(float(ps["wellbeing"]), target, 4.0)
		var legitimacy: float = clampf(float(ps["wellbeing"]) * 0.7 + 20.0 + float(ps["autonomy"]) * 25.0 - float(ps["tax"]) * 25.0 - float(ps["mobilization"]) * 20.0, 0.0, 100.0)
		ps["loyalty"] = move_toward(float(ps["loyalty"]), legitimacy, 0.8)
		var poor: bool = float(ps["wellbeing"]) < 35.0 or float(ps["loyalty"]) < 30.0
		for district in (ps["districts"] as Dictionary).values():
			if float(district["population"]) >= 10.0 and float(district["wellbeing"]) < 25.0: poor = true
		var stage: String = String(ps["stage"])
		if stage == "occupation":
			ps["occupation"] = int(ps["occupation"]) + 50
			if int(ps["occupation"]) >= 600 and not poor:
				ps["stage"] = "stable"
				ps["grace_until"] = c.tick + 1200
			continue
		if stage in ["demands", "agreement"]:
			if terms_met(c, p): ps["stable_ticks"] = int(ps["stable_ticks"]) + 50
			else: ps["stable_ticks"] = 0
			if int(ps["stable_ticks"]) >= 300:
				ps["stage"] = "stable"
				ps["stress"] = 0
				ps["grace_until"] = c.tick + 1200
				ps["loyalty"] = minf(100.0, float(ps["loyalty"]) + 10.0)
				ps["terms"] = {}
				c._record_notice(team, "Accord respecté : crise stabilisée", body)
			elif c.tick >= int(ps["deadline"]) and not terms_met(c, p): revolts.append(id)
			continue
		if c.tick < int(ps["grace_until"]) or String(c.factions.records[team]["kind"]) == "rebel": continue
		ps["stress"] = maxi(0, int(ps["stress"]) + (50 if poor else -100))
		var stress: int = int(ps["stress"])
		ps["stage"] = "protest" if stress >= 600 else ("discontent" if stress >= 300 else "stable")
		if stress >= 900:
			ps["stage"] = "demands"
			ps["accepted"] = false
			ps["stable_ticks"] = 0
			ps["deadline"] = c.tick + 600
			ps["terms"] = {"max_tax": 0.1, "min_autonomy": 0.4, "min_food": 10.0}
			c._record_notice(team, "Ultimatum civil : fiscalité ≤ 10 %, autonomie ≥ 40 %, réserve alimentaire ≥ 10. Délai 60 s.", body)
		elif stage != String(ps["stage"]): c._record_notice(team, "Situation politique : " + String(ps["stage"]), body)
		# IA : mêmes décisions publiques et mêmes stocks, jamais de rétablissement gratuit.
		if team != 0 and String(ps["stage"]) == "demands":
			c.issue_evolution({"t": "crisis", "team": team, "body": body, "answer": "accept"})
			c.issue_evolution({"t": "policy", "team": team, "body": body, "field": "tax", "value": 0.1})
			c.issue_evolution({"t": "policy", "team": team, "body": body, "field": "autonomy", "value": 0.4})
	for id in revolts:
		if c.planets.colonies.has(id): RevoltTransaction.apply(c, c.planets.colonies[id])

static func districts(c: StarCampaign, p: Dictionary, fallback: float) -> float:
	var ps: Dictionary = p["politics"]
	var population: float = float(p["pop"])
	ps["districts"] = {}
	if population <= 0: return fallback
	var pc: PlanetCampaign = c.planets
	var net: Dictionary = pc.connected(p)
	var util: Dictionary = pc.utilities(p, net)
	var service: Dictionary = pc.service_report(p)
	var housing: Dictionary = pc.housing_by_cell(p, net, util)
	var weights: Dictionary = {int(p["hq"]): 16.0}
	var total_capacity: float = 16.0
	for id in p["cells"]:
		if String(p["cells"][id]["zone"]) == "R":
			var capacity: float = float(J13Rules.HOUSING * int(p["cells"][id]["density"]))
			weights[id] = capacity
			total_capacity += capacity
	var weighted: float = 0.0
	for id in weights:
		var residents: float = population * float(weights[id]) / total_capacity
		var factors: Dictionary = ps["factors"].duplicate(true)
		factors["Habitat"]["value"] = clampf(float(housing.get(id, 0)) / maxf(1.0, residents), 0.0, 1.0)
		if factors.has("Eau"): factors["Eau"]["value"] = 1.0 if util["water"].has(id) else 0.0
		if factors.has("Énergie"): factors["Énergie"]["value"] = 1.0 if util["power"].has(id) else 0.0
		if factors.has("Services"): factors["Services"]["value"] = 0.0 if service["hospital"]["uncovered"].has(id) else float(ps["service_paid"])
		var sum: float = 0.0
		var weight: float = 0.0
		for factor in factors.values():
			sum += float(factor["value"]) * float(factor["weight"])
			weight += float(factor["weight"])
		var score: float = clampf(sum / maxf(1.0, weight) * 100.0, 0.0, 100.0)
		ps["districts"][id] = {"population": residents, "wellbeing": score, "connected": net.has(id), "factors": factors}
		weighted += score * residents
	return weighted / population
