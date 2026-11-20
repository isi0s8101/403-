class_name RevoltTransaction
extends RefCounted
const CIVIL_BUILDINGS := ["maison", "ferme", "entrepot", "relais", "comptoir", "marche", "scierie", "mine"]
static func apply(c: StarCampaign, p: Dictionary) -> Dictionary:
	var old: int = int(p.get("team", -1))
	var body: String = String(p.get("body", ""))
	if not c.valid_faction(old) or not c.worlds.has(body) or not c.planets.has_colony(old, body): return PlanetCampaign.fail("transaction", "administration introuvable")
	if not p.has("politics"): return PlanetCampaign.fail("transaction", "état civil manquant")
	var ps: Dictionary = p["politics"]
	var w: SimWorld = c.worlds[body]
	var existing: int = int(c.factions.rebels.get(body, -1))
	if existing == old or (existing >= 0 and c.planets.has_colony(existing, body)): return PlanetCampaign.fail("transaction", "souveraineté déjà transférée")
	var raw: Dictionary = c.local_resources(old, body)
	for value in raw.values():
		if not is_finite(float(value)) or float(value) < 0: return PlanetCampaign.fail("transaction", "stock incohérent")
	var actors: Array = []
	for u in w.team_units(old):
		if Rules.unit_has(u.type, "worker") or (u.allegiance == "local" and u.home_body == body): actors.append(u)
	var civil: Array = []
	for b in w.team_buildings(old):
		if b.type in CIVIL_BUILDINGS: civil.append(b)
	# Tout le plan est validé avant allocation et mutation. Pas de yield dans la transaction.
	var rebel: int = c.factions.allocate("Commune de " + String(c.info(body).get("label", body)), body, "rebel")
	c.ensure_faction(rebel)
	w.ensure_faction(rebel)
	c.homes[rebel] = body
	c.ages[rebel] = c.planets.local_age(c, old, body)
	c.orbital_initial_granted[rebel] = true
	c.lost_centers_at[rebel] = -1
	c.technologies[rebel] = c.technologies[old].duplicate(true)
	c.discovered_systems[rebel] = {c._system_of(body): true}
	c.raw_stocks[PlanetCampaign.key(rebel, body)] = raw
	c.raw_stocks[PlanetCampaign.key(old, body)] = {"food": 0.0, "wood": 0.0, "ore": 0.0}
	c.planets.colonies.erase(PlanetCampaign.key(old, body))
	p["team"] = rebel
	p["tracks_empire"] = false
	p["origin"] = "secession"
	p["local_age"] = c.ages[rebel]
	p["status"] = "integrated"
	ps["stage"] = "revolt"
	ps["former_owner"] = old
	var capital: Vector2 = w.team_buildings(old, "centre")[0].center if not w.team_buildings(old, "centre").is_empty() else Vector2(w.map_size * 0.5, w.map_size * 0.5)
	ps["capital_pos"] = capital
	ps["loyalty"] = 60.0
	ps["tax"] = 0.1
	ps["autonomy"] = 1.0
	c.planets.colonies[PlanetCampaign.key(rebel, body)] = p
	_transfer_reserve(c, old, rebel, float(p["reserve"]))
	for u in actors:
		w.teams[old].pop -= int(Rules.UNITS[u.type]["pop"])
		w.teams[rebel].pop += int(Rules.UNITS[u.type]["pop"])
		if w.squads.has(u.squad_id): w.squads[u.squad_id].units.erase(u.id)
		u.team = rebel
		u.squad_id = -1
		u.target_id = -1
		u.path = PackedVector2Array()
		u.order = {}
		u.task = ""
		u.direct = false
	for b in civil:
		var cap: int = int(Rules.BUILDINGS[b.type].get("pop", 0)) if b.complete else 0
		w.teams[old].pop_cap -= cap
		w.teams[rebel].pop_cap += cap
		b.team = rebel
		b.forming_squad = -1
		b.rally_contract = {}
	w.teams[rebel].fog = w.teams[old].fog.duplicate()
	w.teams[rebel].ai_controlled = true
	var has_ai: bool = false
	for ai in w.ai_controllers:
		if ai.team == rebel: has_ai = true
	if not has_ai: w.ai_controllers.append(AiController.new(rebel))
	c.factions.set_relation(old, rebel, "war")
	c.eliminated[rebel] = false
	c._sync_all()
	w.update_fog(true)
	c._record_notice(old, "Sécession : la planète devient indépendante. Armée régulière et orbite conservent leur allégeance.", body)
	return {"ok": true, "faction": rebel, "civilians": actors.size(), "buildings": civil.size()}
static func _transfer_reserve(c: StarCampaign, source: int, target: int, amount: float) -> void:
	# Les contreparties sont des transferts comptables, pas une création monétaire.
	var a: Dictionary = c.planets.treasury[source]
	var b: Dictionary = c.planets.treasury[target]
	a["transferred_out"] = float(a.get("transferred_out", 0.0)) + amount
	b["transferred_in"] = float(b.get("transferred_in", 0.0)) + amount
	c.planets._entry(c, source, "reserve", "cession", amount, "réserve locale transférée")
	c.planets._entry(c, target, "cession", "reserve", amount, "réserve locale reçue")
static func reintegrate(c: StarCampaign, p: Dictionary, target: int, occupation: bool) -> Dictionary:
	var old: int = int(p["team"])
	var body: String = String(p["body"])
	var enclave: Dictionary = c.planets.colony(target, body)
	if not enclave.is_empty():
		for cell in enclave["cells"]:
			if p["cells"].has(cell) and p["cells"][cell] != enclave["cells"][cell]: return PlanetCampaign.fail("enclave", "régler le conflit de districts avant l'intégration")
		if not (enclave["research"] as Dictionary).is_empty() and not (p["research"] as Dictionary).is_empty(): return PlanetCampaign.fail("research", "attendre la fin d'une recherche locale avant l'intégration")
	var w: SimWorld = c.worlds[body]
	c.planets.colonies.erase(PlanetCampaign.key(old, body))
	p["team"] = target
	p["status"] = "occupied" if occupation else "integrated"
	p["founded_tick"] = c.tick
	p["tracks_empire"] = false
	p["origin"] = "conquered" if occupation else "reunified"
	p["politics"]["stage"] = "occupation" if occupation else "stable"
	p["politics"]["occupation"] = 0
	p["politics"]["grace_until"] = c.tick + 1200
	p["politics"]["loyalty"] = 35.0 if occupation else 65.0
	c.planets.colonies[PlanetCampaign.key(target, body)] = p
	_transfer_reserve(c, old, target, float(p["reserve"]))
	if not enclave.is_empty():
		p["pop"] = int(p["pop"]) + int(enclave["pop"])
		p["reserve"] = float(p["reserve"]) + float(enclave["reserve"])
		for good in J13Rules.GOODS: p["stocks"][good] = float(p["stocks"][good]) + float(enclave["stocks"][good])
		(p["cells"] as Dictionary).merge(enclave["cells"], false)
		if (p["research"] as Dictionary).is_empty(): p["research"] = enclave["research"].duplicate(true)
		for id in enclave["reserved"]:
			if not p["reserved"].has(id): p["reserved"].append(id)
	var dest: Dictionary = c.local_resources(target, body)
	var source: Dictionary = c.local_resources(old, body)
	for res in Rules.RESOURCES:
		dest[res] = float(dest[res]) + float(source[res])
		source[res] = 0.0
	for b in w.team_buildings(old):
		if b.type in CIVIL_BUILDINGS:
			var cap: int = int(Rules.BUILDINGS[b.type].get("pop", 0)) if b.complete else 0
			w.teams[old].pop_cap -= cap
			w.teams[target].pop_cap += cap
			b.team = target
	for u in w.team_units(old):
		if Rules.unit_has(u.type, "worker"):
			w.teams[old].pop -= int(Rules.UNITS[u.type]["pop"])
			w.teams[target].pop += int(Rules.UNITS[u.type]["pop"])
			u.team = target
			u.task = ""
			u.direct = false
			u.order = {}
	c._sync_all()
	return {"ok": true}
