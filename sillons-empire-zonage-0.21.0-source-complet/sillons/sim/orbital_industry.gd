class_name OrbitalIndustry
extends RefCounted
## J12.3 : industrie spatiale DISTINCTE des bâtiments au sol.
## Le chantier naval est le centre orbital, avec un registre par monde et camp.
## Unités et modules sont sérialisés sans nœud 3D, à pas fixe et sans horloge système.

const BASE_HP: float = 2400.0
const BASE_CAP: int = 8
const START_TICKS: int = 180
const HUB_COST := {"wood": 350, "ore": 600}
const MAX_FLIGHTS: int = 64
const UNITS := {
	"drone": {"label": "Drone constructeur", "age": 9, "pop": 1, "cost": {"ore": 130}, "ticks": 120, "module": ""},
	"sonde": {"label": "Sonde de reconnaissance", "age": 9, "pop": 1, "cost": {"ore": 160}, "ticks": 110, "module": ""},
	"navette": {"label": "Navette spatiale", "age": 9, "pop": 2, "cost": {"food": 80, "ore": 310}, "ticks": 240, "module": ""},
	"intercepteur": {"label": "Intercepteur orbital", "age": 9, "pop": 2, "cost": {"food": 60, "ore": 220}, "ticks": 180, "module": "hangar"},
	"fregate": {"label": "Frégate spatiale", "age": 10, "pop": 4, "cost": {"food": 180, "ore": 650}, "ticks": 390, "module": "arsenal"},
}
const MODULES := {
	"habitat": {"label": "Habitat orbital (maison)", "age": 9, "cost": {"wood": 160, "ore": 180}, "ticks": 200, "limit": 4},
	"hydroponie": {"label": "Ferme hydroponique", "age": 9, "cost": {"wood": 130, "ore": 180}, "ticks": 210, "limit": 4},
	"extracteur": {"label": "Extracteur de minerai", "age": 9, "cost": {"wood": 100, "ore": 260}, "ticks": 240, "limit": 4},
	"depot": {"label": "Dépôt orbital (logistique)", "age": 9, "cost": {"wood": 190, "ore": 210}, "ticks": 220, "limit": 2},
	"hangar": {"label": "Hangar militaire (caserne)", "age": 9, "cost": {"wood": 200, "ore": 380}, "ticks": 310, "limit": 2},
	"radar": {"label": "Réseau de capteurs", "age": 9, "cost": {"wood": 110, "ore": 320}, "ticks": 250, "limit": 2},
	"batterie": {"label": "Batterie défensive (fort)", "age": 9, "cost": {"wood": 200, "ore": 400}, "ticks": 290, "limit": 4},
	"arsenal": {"label": "Arsenal stellaire (atelier)", "age": 10, "cost": {"wood": 340, "ore": 750}, "ticks": 420, "limit": 2},
}

static func key(team: int, body: String) -> String:
	return "%d:%s" % [team, body]

static func site(c: StarCampaign, team: int, body: String) -> Dictionary:
	return c.orbital_sites.get(key(team, body), {}) as Dictionary

static func presence(c: StarCampaign, team: int, body: String) -> Dictionary:
	var id: String = key(team, body)
	if not c.orbital_presence.has(id):
		c.orbital_presence[id] = {}
	return c.orbital_presence[id] as Dictionary

static func has_hub(c: StarCampaign, team: int, body: String) -> bool:
	var hub: Dictionary = site(c, team, body)
	return not hub.is_empty() and int(hub.get("remaining", 0)) == 0 and float(hub.get("hp", 0.0)) > 0.0

static func has_hub_in_system(c: StarCampaign, team: int, system_id: String) -> bool:
	for body in c.sector_keys():
		if String(c.info(String(body)).get("system_id", "")) == system_id and has_hub(c, team, String(body)):
			return true
	return false

static func _stock(c: StarCampaign, team: int, body: String) -> Dictionary:
	if c.evolutions_enabled: return c.local_resources(team, body)
	return c.system_resources(team, String(c.info(body).get("system_id", "sol")))

static func _can_pay(stock: Dictionary, costs: Dictionary) -> bool:
	for resource in costs.keys():
		if float(stock.get(resource, 0.0)) < float(costs[resource]):
			return false
	return true

static func _pay(stock: Dictionary, costs: Dictionary) -> void:
	for resource in costs.keys():
		stock[resource] = float(stock[resource]) - float(costs[resource])

static func _new_site(team: int, body: String, remaining: int) -> Dictionary:
	return {"team": team, "body": body, "remaining": remaining, "tier": 1,
		"hp": BASE_HP, "modules": {}, "job": {}, "unit_levels": {}, "built_tick": 0}

static func _first_site(c: StarCampaign, team: int) -> void:
	if c.orbital_initial_granted[team] or c.ages[team] < 9 or c.eliminated[team]:
		return
	var origins: Array = c.worlds.keys()
	origins.sort()
	# Capitale d'origine prioritaire, puis centre vivant sur un autre corps.
	if origins.has("val"):
		origins.erase("val")
		origins.push_front("val")
	for raw in origins:
		var body: String = String(raw)
		var w: SimWorld = c.worlds[body] as SimWorld
		if w.team_buildings(team, "centre", true).is_empty():
			continue
		c.orbital_initial_granted[team] = true
		c.orbital_sites[key(team, body)] = _new_site(team, body, START_TICKS)
		c._notice(team, "Âge IX : chantier naval initial en assemblage orbital", body)
		return

static func deploy(c: StarCampaign, team: int, body: String) -> Dictionary:
	# J13 : sur une colonie, c'est l'âge LOCAL qui autorise la station (jamais offerte par l'empire).
	if not c.valid_faction(team) or c.eliminated[team] or not c.star_catalog.has_body(body) or c.planets.local_age(c, team, body) < 9:
		return {"ok": false, "reason": "âge IX local et planète connue requis"}
	if not c.is_unlocked(team, body):
		return {"ok": false, "reason": "monde non accessible"}
	if not site(c, team, body).is_empty():
		return {"ok": false, "reason": "chantier orbital déjà présent"}
	var has_builder: bool = int(presence(c, team, body).get("drone", 0)) > 0
	var surface_port: bool = false
	if c.worlds.has(body):
		var w: SimWorld = c.worlds[body] as SimWorld
		for b in w.team_buildings(team, "", true):
			if b.type in ["spatioport", "chantier_orbital"]:
				surface_port = true
				break
	if not has_builder and not surface_port:
		return {"ok": false, "reason": "drone constructeur en orbite ou spatioport au sol requis"}
	var stock: Dictionary = _stock(c, team, body)
	if not _can_pay(stock, HUB_COST):
		return {"ok": false, "reason": "ressources insuffisantes dans le système"}
	_pay(stock, HUB_COST)
	c.orbital_sites[key(team, body)] = _new_site(team, body, START_TICKS)
	c._notice(team, "Construction d’un chantier naval orbital", body)
	return {"ok": true}

static func capacity(c: StarCampaign, team: int, body: String) -> int:
	var hub: Dictionary = site(c, team, body)
	var mods: Dictionary = hub.get("modules", {}) as Dictionary
	return BASE_CAP + 6 * int(mods.get("habitat", 0)) + 2 * (int(hub.get("tier", 1)) - 1)

static func population(c: StarCampaign, team: int, body: String) -> int:
	var units: Dictionary = presence(c, team, body)
	var current: int = 0
	for kind in UNITS.keys():
		current += int(units.get(kind, 0)) * int((UNITS[kind] as Dictionary)["pop"])
	return current

static func start(c: StarCampaign, team: int, body: String, mode: String, kind: String = "") -> Dictionary:
	if not c.valid_faction(team) or c.eliminated[team] or not has_hub(c, team, body):
		return {"ok": false, "reason": "chantier naval orbital allié opérationnel requis"}
	var hub: Dictionary = site(c, team, body)
	if not (hub["job"] as Dictionary).is_empty():
		return {"ok": false, "reason": "chantier occupé, patienter"}
	var work: Dictionary = {}
	if mode == "module":
		if not MODULES.has(kind):
			return {"ok": false, "reason": "module inconnu"}
		var definition: Dictionary = MODULES[kind] as Dictionary
		var mods: Dictionary = hub["modules"] as Dictionary
		if int(mods.get(kind, 0)) >= int(definition["limit"]):
			return {"ok": false, "reason": "nombre maximal de modules atteint"}
		if int(presence(c, team, body).get("drone", 0)) < 1:
			return {"ok": false, "reason": "produire un drone constructeur avant de bâtir"}
		work = {"mode": mode, "kind": kind, "ticks": int(definition["ticks"]), "cost": definition["cost"]}
	elif mode == "unit":
		if not UNITS.has(kind):
			return {"ok": false, "reason": "unité spatiale inconnue"}
		var definition: Dictionary = UNITS[kind] as Dictionary
		var required: String = String(definition["module"])
		if not required.is_empty() and int((hub["modules"] as Dictionary).get(required, 0)) < 1:
			return {"ok": false, "reason": "construire d’abord : %s" % String((MODULES[required] as Dictionary)["label"])}
		if population(c, team, body) + int(definition["pop"]) > capacity(c, team, body):
			return {"ok": false, "reason": "population orbitale saturée : construire un habitat"}
		work = {"mode": mode, "kind": kind, "ticks": int(definition["ticks"]), "cost": definition["cost"]}
	elif mode == "upgrade_hub":
		if int(hub["tier"]) >= 3:
			return {"ok": false, "reason": "chantier au niveau maximal"}
		var next_tier: int = int(hub["tier"]) + 1
		work = {"mode": mode, "kind": "", "ticks": 300 * next_tier, "cost": {"wood": 250 * next_tier, "ore": 370 * next_tier}}
	elif mode == "upgrade_unit":
		if not UNITS.has(kind):
			return {"ok": false, "reason": "unité spatiale inconnue"}
		var levels: Dictionary = hub["unit_levels"] as Dictionary
		var next_tier: int = int(levels.get(kind, 1)) + 1
		if next_tier > int(hub["tier"]) or next_tier > 3:
			return {"ok": false, "reason": "améliorer d’abord le chantier"}
		var raw: Dictionary = (UNITS[kind] as Dictionary)["cost"] as Dictionary
		var price: Dictionary = {}
		for resource in raw.keys():
			price[resource] = int(raw[resource]) * next_tier * 2
		work = {"mode": mode, "kind": kind, "ticks": 180 * next_tier, "cost": price}
	else:
		return {"ok": false, "reason": "commande spatiale inconnue"}
	var min_age: int = 10 if mode == "upgrade_unit" and int((hub["unit_levels"] as Dictionary).get(kind, 1)) >= 2 else 9
	if mode == "module":
		min_age = int((MODULES[kind] as Dictionary)["age"])
	elif mode == "unit":
		min_age = int((UNITS[kind] as Dictionary)["age"])
	elif mode == "upgrade_hub":
		min_age = 10 if int(hub["tier"]) >= 2 else 9
	# J13 : une frégate importée ne débloque pas l'arsenal d'une colonie plus jeune.
	if c.planets.local_age(c, team, body) < min_age:
		return {"ok": false, "reason": "âge local %d requis" % min_age}
	var stock: Dictionary = _stock(c, team, body)
	if not _can_pay(stock, work["cost"] as Dictionary):
		return {"ok": false, "reason": "ressources locales insuffisantes"}
	_pay(stock, work["cost"] as Dictionary)
	var ticks: int = int(work["ticks"])
	if mode == "unit":
		ticks = maxi(1, int(round(float(ticks) / (1.0 + 0.10 * float(int(hub["tier"]) - 1)))))
	hub["job"] = {"mode": mode, "kind": kind, "remaining": ticks}
	return {"ok": true, "eta": int(work["ticks"])}

static func send_fleet(c: StarCampaign, team: int, source: String, target: String, payload: Dictionary, selected_ids: Array = []) -> Dictionary:
	if not c.valid_faction(team) or c.eliminated[team] or c.ages[team] < 9:
		return {"ok": false, "reason": "âge IX requis"}
	if source == target or (not c.orbital_tactics and not has_hub(c, team, source)) or not c.is_unlocked(team, target):
		return {"ok": false, "reason": "source alliée et destination accessible requises"}
	if c.orbital_flights.size() >= MAX_FLIGHTS:
		return {"ok": false, "reason": "limite de missions spatiales atteinte"}
	var duration: int = StarCampaign.expected_flight_duration(c.star_catalog, source, target)
	if duration < 1 or (String(c.info(source)["system_id"]) != String(c.info(target)["system_id"]) and c.ages[team] < 10):
		return {"ok": false, "reason": "âge X ou route interstellaire directe requis"}
	if payload.is_empty() or payload.size() > UNITS.size():
		return {"ok": false, "reason": "cargaison vide ou invalide"}
	var garrison: Dictionary = presence(c, team, source)
	var count: int = 0
	for raw_kind in payload.keys():
		var kind: String = String(raw_kind)
		if not UNITS.has(kind) or not payload[raw_kind] is int or int(payload[raw_kind]) < 1:
			return {"ok": false, "reason": "composition de flotte incorrecte"}
		if int(payload[raw_kind]) > int(garrison.get(kind, 0)):
			return {"ok": false, "reason": "vaisseaux insuffisants au départ"}
		count += int(payload[raw_kind])
	if count > 12:
		return {"ok": false, "reason": "12 unités spatiales au maximum"}
	if int(payload.get("drone", 0)) > 0 and int(payload.get("navette", 0)) < 1:
		return {"ok": false, "reason": "transport des drones : une navette requise"}
	if String(c.info(source)["system_id"]) != String(c.info(target)["system_id"]) and int(payload.get("fregate", 0)) < 1:
		return {"ok": false, "reason": "voyage interstellaire : au moins une frégate"}
	if c.orbital_tactics:
		OrbitalTactics.reconcile(c)
		if not selected_ids.is_empty():
			var actors:Dictionary=OrbitalTactics.map_for(c,source)["actors"]
			var checked:Dictionary={}
			var counts:Dictionary={}
			for id in selected_ids:
				if not id is int or checked.has(id) or not actors.has(id):return {"ok":false,"reason":"identité de vaisseau invalide"}
				var a:Dictionary=actors[id]
				if int(a["team"])!=team or String(a["role"])!="unit":return {"ok":false,"reason":"sélection non alliée"}
				counts[a["type"]]=int(counts.get(a["type"],0))+1;checked[id]=true
			if counts!=payload:return {"ok":false,"reason":"manifeste différent de la sélection"}
	var manifest: Dictionary = {}
	for raw_kind in payload.keys():
		var kind: String = String(raw_kind)
		manifest[kind] = int(payload[raw_kind])
	# Retrait atomique uniquement après toutes les vérifications.
	for kind in manifest.keys():
		garrison[kind] = int(garrison.get(kind, 0)) - int(manifest[kind])
	var launch_levels: Dictionary = (site(c, team, source).get("unit_levels", {}) as Dictionary).duplicate(true)
	c.orbital_flights.append({"id": c.next_orbital_flight, "team": team, "from": source, "to": target,
		"eta": duration, "duration": duration, "units": manifest, "levels": launch_levels})
	if c.orbital_tactics: c.orbital_flights.back()["tactical_units"]=OrbitalTactics.detach(c,source,team,manifest,selected_ids)
	c.next_orbital_flight += 1
	c._notice(team, "Escadre orbitale envoyée vers %s" % String(c.info(target)["label"]), source)
	return {"ok": true, "eta": duration}

static func send_probe(c: StarCampaign, team: int, body: String, target_system: String) -> Dictionary:
	if not has_hub(c, team, body) or int(presence(c, team, body).get("sonde", 0)) < 1:
		return {"ok": false, "reason": "une sonde et un chantier naval sont requis"}
	var origin: String = String(c.info(body)["system_id"])
	var result: Dictionary = c.survey_system(team, origin, target_system)
	if bool(result.get("ok", false)):
		var units: Dictionary = presence(c, team, body)
		units["sonde"] = int(units.get("sonde", 0)) - 1
		OrbitalTactics.reconcile(c)
	return result

static func step(c: StarCampaign) -> void:
	for team in c.faction_ids():
		_first_site(c, team)
	var locations: Array = c.orbital_sites.keys()
	locations.sort()
	for id in locations:
		var hub: Dictionary = c.orbital_sites[id] as Dictionary
		var team: int = int(hub["team"])
		var body: String = String(hub["body"])
		if int(hub["remaining"]) > 0:
			hub["remaining"] = int(hub["remaining"]) - 1
			if int(hub["remaining"]) == 0:
				var units: Dictionary = presence(c, team, body)
				units["drone"] = int(units.get("drone", 0)) + 1
				c._notice(team, "Chantier naval orbital opérationnel · drone constructeur disponible", body)
			continue
		if not (hub["job"] as Dictionary).is_empty():
			var job: Dictionary = hub["job"] as Dictionary
			job["remaining"] = int(job["remaining"]) - 1
			if int(job["remaining"]) <= 0:
				_complete(c, hub)
		if c.tick % Rules.TICK_RATE == 0:
			var mods: Dictionary = hub["modules"] as Dictionary
			var stock: Dictionary = _stock(c, team, body)
			stock["food"] = float(stock.get("food", 0.0)) + 2.0 * int(mods.get("hydroponie", 0))
			stock["ore"] = float(stock.get("ore", 0.0)) + 1.0 * int(mods.get("extracteur", 0))
	for flight in c.orbital_flights.duplicate():
		flight["eta"] = maxi(0, int(flight["eta"]) - 1)
		if int(flight["eta"]) == 0:
			_arrive(c, flight)
			c.orbital_flights.erase(flight)

static func _complete(c: StarCampaign, hub: Dictionary) -> void:
	var job: Dictionary = hub["job"] as Dictionary
	var mode: String = String(job["mode"])
	var kind: String = String(job["kind"])
	var team: int = int(hub["team"])
	var body: String = String(hub["body"])
	if mode == "module":
		var modules: Dictionary = hub["modules"] as Dictionary
		modules[kind] = int(modules.get(kind, 0)) + 1
	elif mode == "unit":
		var units: Dictionary = presence(c, team, body)
		units[kind] = int(units.get(kind, 0)) + 1
	elif mode == "upgrade_hub":
		hub["tier"] = int(hub["tier"]) + 1
		hub["hp"] = float(hub["hp"]) + 400.0
	elif mode == "upgrade_unit":
		var levels: Dictionary = hub["unit_levels"] as Dictionary
		levels[kind] = int(levels.get(kind, 1)) + 1
	OrbitalTactics.completed(c, team, body, job)
	hub["job"] = {}
	c._notice(team, "Orbite : évolution achevée (%s %s)" % [mode, kind], body)

static func _arrive(c: StarCampaign, flight: Dictionary) -> void:
	var team: int = int(flight["team"])
	var target: String = String(flight["to"])
	var manifest: Dictionary = flight["units"] as Dictionary
	if c.orbital_tactics:
		OrbitalTactics.arrived(c, flight)
		return
	var enemy: int = c.planets.hostile_owner(c, team, target)
	# J13 : toutes les stations de commandement opérationnelles comptent ; une vague en attaque une.
	if c.planets.station_count(c, enemy, target) > 0:
		var strength: int = 0
		var upgrades: Dictionary = flight.get("levels", {}) as Dictionary
		for kind in ["intercepteur", "fregate"]:
			var tier: int = clampi(int(upgrades.get(kind, 1)), 1, 3)
			strength += int(manifest.get(kind, 0)) * (30 if kind == "intercepteur" else 65) * tier
		if strength <= 0:
			c._notice(team, "Escadre non armée repoussée en orbite ennemie", target)
			return
		var assault: Dictionary = c.planets.orbital_assault(c, team, target, strength)
		if not bool(assault["destroyed"]):
			c._notice(team, "Escadre perdue après attaque de la station orbitale ennemie", target)
			return
	var units: Dictionary = presence(c, team, target)
	for kind in manifest.keys():
		units[kind] = int(units.get(kind, 0)) + int(manifest[kind])
	c._notice(team, "Escadre arrivée en orbite de %s" % String(c.info(target)["label"]), target)

static func validate_state(catalog: StarSystemGenerator, data: Dictionary) -> bool:
	var sites: Variant = data.get("orbital_sites", {})
	var garrisons: Variant = data.get("orbital_presence", {})
	var flights: Variant = data.get("orbital_flights", [])
	var granted: Variant = data.get("orbital_initial_granted", [false, false])
	if not sites is Dictionary or not garrisons is Dictionary or not flights is Array or not granted is Array:
		return false
	if (granted as Array).size() != 2 or not granted[0] is bool or not granted[1] is bool:
		return false
	if (sites as Dictionary).size() > 2 * StarSystemGenerator.MAX_BODIES or (garrisons as Dictionary).size() > 2 * StarSystemGenerator.MAX_BODIES or (flights as Array).size() > MAX_FLIGHTS:
		return false
	for source in [sites, garrisons]:
		for raw in (source as Dictionary).keys():
			if not raw is String:
				return false
			var parts: PackedStringArray = String(raw).split(":", false, 1)
			if parts.size() != 2 or parts[0] not in ["0", "1"] or not catalog.has_body(parts[1]):
				return false
	for id in (sites as Dictionary).keys():
		var hub_value: Variant = sites[id]
		if not hub_value is Dictionary:
			return false
		var hub: Dictionary = hub_value as Dictionary
		if key(int(hub.get("team", -1)), String(hub.get("body", ""))) != id:
			return false
		if not hub.get("remaining") is int or int(hub["remaining"]) < 0 or int(hub["remaining"]) > START_TICKS:
			return false
		if not hub.get("tier") is int or int(hub["tier"]) not in [1, 2, 3]:
			return false
		if not (hub.get("hp") is int or hub.get("hp") is float) or not is_finite(float(hub["hp"])) or float(hub["hp"]) <= 0.0 or float(hub["hp"]) > BASE_HP + 800.0:
			return false
		for field in ["modules", "job", "unit_levels"]:
			if not hub.get(field) is Dictionary:
				return false
		var mods: Dictionary = hub["modules"] as Dictionary
		for kind in mods.keys():
			if not MODULES.has(kind) or not mods[kind] is int or int(mods[kind]) < 1 or int(mods[kind]) > int((MODULES[kind] as Dictionary)["limit"]):
				return false
		var levels: Dictionary = hub["unit_levels"] as Dictionary
		for kind in levels.keys():
			if not UNITS.has(kind) or not levels[kind] is int or int(levels[kind]) not in [2, 3]:
				return false
		var job: Dictionary = hub["job"] as Dictionary
		if not job.is_empty():
			if String(job.get("mode", "")) not in ["module", "unit", "upgrade_hub", "upgrade_unit"] or not job.get("remaining") is int or int(job["remaining"]) < 1 or int(job["remaining"]) > 1500:
				return false
			var mode: String = String(job["mode"])
			var kind: String = String(job.get("kind", ""))
			if (mode == "module" and not MODULES.has(kind)) or (mode in ["unit", "upgrade_unit"] and not UNITS.has(kind)):
				return false
	for id in (garrisons as Dictionary).keys():
		var raw_units: Variant = garrisons[id]
		if not raw_units is Dictionary or (raw_units as Dictionary).size() > UNITS.size():
			return false
		for kind in (raw_units as Dictionary).keys():
			if not UNITS.has(kind) or not raw_units[kind] is int or int(raw_units[kind]) < 0 or int(raw_units[kind]) > 10000:
				return false
	var ids: Dictionary = {}
	for raw_flight in flights:
		if not raw_flight is Dictionary:
			return false
		var flight: Dictionary = raw_flight as Dictionary
		for field in ["id", "team", "eta", "duration"]:
			if not flight.get(field) is int:
				return false
		if int(flight["id"]) < 1 or ids.has(flight["id"]) or int(flight["team"]) not in [0, 1]:
			return false
		ids[flight["id"]] = true
		var a: String = String(flight.get("from", ""))
		var b: String = String(flight.get("to", ""))
		if not catalog.has_body(a) or not catalog.has_body(b) or StarCampaign.expected_flight_duration(catalog, a, b) != int(flight["duration"]):
			return false
		if int(flight["eta"]) < 1 or int(flight["eta"]) > int(flight["duration"]):
			return false
		if not flight.get("units") is Dictionary or (flight["units"] as Dictionary).is_empty():
			return false
		if flight.has("levels"):
			if not flight["levels"] is Dictionary:
				return false
			for kind in (flight["levels"] as Dictionary).keys():
				if not UNITS.has(kind) or not flight["levels"][kind] is int or int(flight["levels"][kind]) not in [2, 3]:
					return false
		for kind in (flight["units"] as Dictionary).keys():
			if not UNITS.has(kind) or not flight["units"][kind] is int or int(flight["units"][kind]) < 1 or int(flight["units"][kind]) > 12:
				return false
	var next_id: Variant = data.get("next_orbital_flight", 1)
	if not next_id is int or int(next_id) < 1 or (not ids.is_empty() and int(next_id) <= int((ids.keys() as Array).max())):
		return false
	return true

static func logistics_bonus(c: StarCampaign, team: int, system_id: String) -> int:
	var total: int = 0
	for body in c.sector_keys():
		var body_id: String = String(body)
		if String(c.info(body_id).get("system_id", "")) == system_id and has_hub(c, team, body_id):
			var hub: Dictionary = site(c, team, body_id)
			total += int((hub["modules"] as Dictionary).get("depot", 0))
	return mini(3, total)
