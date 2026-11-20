class_name PlanetGovernor
extends RefCounted
## J13 : gouverneur civil d'une planète à l'âge X LOCAL. Planification déterministe,
## bornée par cycle, exécutée par les MÊMES commandes que le joueur (coûts, terrain, budget).
## Il ne démolit jamais, ne touche ni aux réserves ni aux bâtiments manuels, ne change pas
## le ratio R/C/I choisi et s'arrête proprement en expliquant la cause.
## Ordre de sûreté : survie (eau, énergie) > secours > production > équilibre R/C/I > extension.

static func run(c: StarCampaign, pc: PlanetCampaign, p: Dictionary) -> void:
	var gov: Dictionary = p["governor"] as Dictionary
	var team: int = int(p["team"])
	var body: String = String(p["body"])
	# J13.1 : avec la chaîne d'approvisionnement, un camp piloté par l'IA confie ses zones à
	# l'intendant dès le départ (mêmes coûts), en gardant une réserve de matériaux pour son armée.
	var steward: bool = false
	if pc.supply_chain and c.worlds.has(body) and bool(((c.worlds[body] as SimWorld).teams[team] as SimWorld.Team).ai_controlled):
		var depot: Dictionary = pc._depot(c, team, body)
		steward = float(depot.get("wood", 0.0)) >= 100.0 and float(depot.get("ore", 0.0)) >= 60.0
	if String(p["status"]) == "lost" or not (steward or (bool(gov["enabled"]) and pc.local_age(c, team, body) >= 10)):
		return
	if c.evolutions_enabled and steward and not bool(gov["enabled"]) and pc.local_age(c, team, body) < 4:
		var residential: int = 0
		var shops: int = 0
		for cell in (p["cells"] as Dictionary).values():
			if String(cell["zone"]) == "R": residential += 1
			if String(cell["zone"]) == "C": shops += 1
		if residential >= 1 and (shops >= 1 or pc.local_age(c, team, body) == 1):
			_status(c, p, "réserve de progression : habitat initial suffisant")
			return
	var budget: float = float(gov["budget_cap"])
	for turn in J13Rules.GOVERNOR_ACTIONS:
		# Avant l'âge X, l'intendant d'une IA loge et fait commercer d'abord ; les secours attendent des crédits.
		var plan: Dictionary = decide(c, pc, p, 1 if steward and not bool(gov["enabled"]) and pc.credits(team) < 600.0 else 0)
		if plan.has("stop"):
			_status(c, p, String(plan["stop"]))
			return
		var result: Dictionary = _execute(c, pc, team, body, plan, budget)
		if not bool(result.get("ok", false)) and String(plan["action"]) == "civic":
			# Équipement hors de portée (crédits) : ne pas tout geler, poursuivre par le zonage
			# qui fera vivre la colonie ; l'équipement sera retenté au cycle suivant.
			var fallback: Dictionary = decide(c, pc, p, 2)
			if not fallback.has("stop"):
				var second: Dictionary = _execute(c, pc, team, body, fallback, budget)
				if bool(second.get("ok", false)):
					plan = fallback
					result = second
		if not bool(result.get("ok", false)):
			# Arrêt contrôlé : rien n'est débité, la cause est affichée, aucun contournement.
			_status(c, p, "en attente · %s (%s)" % [String(plan["why"]), String(result.get("reason", "refus"))])
			return
		budget -= _credits(plan, p)
		var journal: Array = gov["journal"] as Array
		journal.append({"tick": c.tick, "action": String(plan["action"]), "kind": String(plan.get("kind", "")), "id": int(plan["id"]), "why": String(plan["why"])})
		if journal.size() > J13Rules.JOURNAL_KEEP:
			journal.pop_front()
		gov["status"] = "actif · " + String(plan["why"])

static func _status(c: StarCampaign, p: Dictionary, text: String) -> void:
	var gov: Dictionary = p["governor"] as Dictionary
	if String(gov["status"]) != text:
		gov["status"] = text
		c._record_notice(int(p["team"]), "Gouverneur : " + text, String(p["body"]))

static func _credits(plan: Dictionary, p: Dictionary) -> float:
	match String(plan["action"]):
		"zone":
			return float((J13Rules.ZONE_COST[String(plan["kind"])] as Dictionary).get("credits", 0))
		"civic":
			return float(((J13Rules.FACILITIES[String(plan["kind"])] as Dictionary)["cost"] as Dictionary).get("credits", 0))
		"densify":
			return float(J13Rules.DENSIFY_CREDITS * int(((p["cells"] as Dictionary)[int(plan["id"])] as Dictionary)["density"]))
		"road":
			return float(J13Rules.LINK_COST["credits"])
	return 0.0

static func _execute(c: StarCampaign, pc: PlanetCampaign, team: int, body: String, plan: Dictionary, budget: float) -> Dictionary:
	var id: int = int(plan["id"])
	match String(plan["action"]):
		"road":
			return pc.build_road(c, team, body, id, budget)
		"repair":
			return pc.repair_road(c, team, body, id, budget)
		"zone":
			return pc.zone(c, team, body, id, String(plan["kind"]), budget, String(plan.get("recipe", "")))
		"civic":
			return pc.build_civic(c, team, body, id, String(plan["kind"]), budget)
		"densify":
			return pc.densify(c, team, body, id, budget)
	return PlanetCampaign.fail("invalid", "action inconnue")

static func _sites(c: StarCampaign, pc: PlanetCampaign, p: Dictionary, net: Dictionary) -> Dictionary:
	## free : districts reliés, vides et éligibles ; frontier : districts éligibles à raccorder.
	var cells: Dictionary = p["cells"] as Dictionary
	var ordered: Array = []
	for raw in net.keys():
		ordered.append([int(net[raw]), int(raw)])
	ordered.sort()
	var free: Array = []
	var frontier: Array = []
	var seen: Dictionary = {}
	for item in ordered:
		var id: int = int(item[1])
		if PlanetCampaign.cell_kind(cells[id] as Dictionary).is_empty() and pc.eligible(c, p, id):
			free.append(id)
		for n in PlanetCampaign.neighbors(id):
			if not cells.has(n) and not seen.has(n) and pc.eligible(c, p, int(n)):
				seen[n] = true
				frontier.append(int(n))
	if free.is_empty() and frontier.is_empty():
		# Plus de terre voisine : première étape d'une liaison maritime vers une terre éligible.
		var mask: PackedByteArray = PlanetCampaign.land_mask(pc._body_seed(c, String(p["body"])))
		var first: Dictionary = {}
		var queue: Array = []
		for item in ordered:
			queue.append(int(item[1]))
		while not queue.is_empty():
			var current: int = int(queue.pop_front())
			for n in PlanetCampaign.neighbors(current):
				var id: int = int(n)
				if cells.has(id) or first.has(id):
					continue
				var origin: int = id if not first.has(current) else int(first[current])
				if pc.eligible(c, p, id):
					frontier.append(origin)
					queue.clear()
					break
				if mask[id] == J13Rules.LAND_OCEAN:
					first[id] = origin
					queue.append(id)
	return {"free": free, "frontier": frontier}

static func _place(sites: Dictionary, action: String, kind: String, why: String) -> Dictionary:
	if not (sites["free"] as Array).is_empty():
		return {"action": action, "kind": kind, "id": int((sites["free"] as Array)[0]), "why": why}
	if not (sites["frontier"] as Array).is_empty():
		return {"action": "road", "id": int((sites["frontier"] as Array)[0]), "why": "route ou liaison vers un nouveau district (" + why + ")"}
	return {}

static func decide(c: StarCampaign, pc: PlanetCampaign, p: Dictionary, mode: int = 0) -> Dictionary:
	## mode 0 : plan complet ; 1 : sans les secours (intendant d'une IA peu fortunée) ; 2 : zonage seul.
	var zoning_only: bool = mode >= 2
	## Fonction pure sur un instantané de la colonie : même état, même décision.
	var team: int = int(p["team"])
	var body: String = String(p["body"])
	var cells: Dictionary = p["cells"] as Dictionary
	var net: Dictionary = pc.connected(p)
	var util: Dictionary = pc.utilities(p, net)
	var sites: Dictionary = _sites(c, pc, p, net)
	var plan: Dictionary = {}
	# 1. Survie : routes coupées, puis énergie et eau avec une marge avant toute extension.
	var ids: Array = cells.keys()
	ids.sort()
	for raw in ids:
		if bool((cells[raw] as Dictionary)["cut"]):
			return {"action": "repair", "id": int(raw), "why": "route coupée"}
	for utility in ["power", "water"]:
		if zoning_only:
			break
		if float(util[utility + "_ratio"]) < 1.0 or int(util[utility + "_free"]) < 2:
			plan = _place(sites, "civic", utility, "pénurie ou marge insuffisante : " + String(J13Rules.SERVICE_LABELS[utility]))
			if not plan.is_empty():
				return plan
	# 2. Secours : couverture réelle par la route et la capacité, prévue pour des logements PLEINS
	#    (sinon la population grandirait après coup dans des quartiers sans secours).
	var real_pop: int = int(p["pop"])
	p["pop"] = maxi(real_pop, _housing(pc, p))
	plan = {} if mode >= 1 else _service_plan(pc, p, sites)
	p["pop"] = real_pop
	if not plan.is_empty():
		return plan
	# 3. Une menace en orbite gèle l'extension (jamais les secours).
	var hostile: Dictionary = c.orbital_presence.get(OrbitalIndustry.key(1 - team, body), {}) as Dictionary
	if int(hostile.get("intercepteur", 0)) + int(hostile.get("fregate", 0)) > 0:
		return {"stop": "extension suspendue · escadre ennemie en orbite"}
	# 4. Équilibre R/C/I : la zone la plus en retard sur la cible du joueur.
	var shares: Dictionary = pc.zoning_shares(p)
	var kind: String = "R"
	var worst: float = -2.0
	for zone_kind in J13Rules.ZONES:
		if pc.local_age(c, team, body) < int(J13Rules.ZONE_MIN_AGE[zone_kind]):
			continue # zone pas encore connue à cet âge local : on ne l'attend pas
		var gap: float = float((p["target"] as Dictionary)[zone_kind]) - float(shares[zone_kind])
		if gap > worst + 0.0001:
			worst = gap
			kind = String(zone_kind)
	plan = _place(sites, "zone", kind, "zonage %s vers la cible" % String(J13Rules.ZONE_LABELS[kind]))
	if not plan.is_empty():
		if String(plan["action"]) == "zone" and kind == "I":
			plan["recipe"] = _recipe(pc.local_age(c, team, body), cells)
		elif String(plan["action"]) == "zone" and kind == "R":
			# Secours avant logements : si ce quartier, une fois plein, n'était pas couvert,
			# le terrain reçoit d'abord le poste manquant.
			var site: Dictionary = cells[int(plan["id"])] as Dictionary
			site["zone"] = "R"
			site["density"] = 1
			p["pop"] = maxi(real_pop, _housing(pc, p))
			var forecast: Dictionary = pc.service_report(p)
			site["zone"] = ""
			site["density"] = 0
			p["pop"] = real_pop
			for service in ["fire", "hospital", "police"]:
				if mode == 0 and float((forecast[service] as Dictionary)["coverage"]) < 0.999:
					return {"action": "civic", "kind": service, "id": int(plan["id"]), "why": "secours avant logements : " + String(J13Rules.SERVICE_LABELS[service])}
		return plan
	# 5. Plus aucun terrain éligible : densification tant que réseaux et secours suivent, puis fin de chantier.
	var limit: int = J13Rules.max_density(pc.local_age(c, team, body))
	for raw in ids:
		var cell: Dictionary = cells[raw] as Dictionary
		var zone_kind: String = String(cell["zone"])
		if zone_kind.is_empty() or int(cell["density"]) >= limit or bool(cell["manual"]):
			continue
		var need: int = int(J13Rules.UTILITY_NEED[zone_kind])
		if int(util["power_free"]) < need or int(util["water_free"]) < need:
			continue
		if zone_kind == "R":
			cell["density"] = int(cell["density"]) + 1
			p["pop"] = maxi(real_pop, _housing(pc, p))
			var report: Dictionary = pc.service_report(p)
			cell["density"] = int(cell["density"]) - 1
			p["pop"] = real_pop
			var covered: bool = true
			for service in J13Rules.MOBILE_SERVICES:
				if float((report[service] as Dictionary)["coverage"]) < 0.999:
					covered = false
			if not covered:
				continue
		return {"action": "densify", "id": int(raw), "why": "densification"}
	return {"stop": "périmètre éligible aménagé à %d %%" % int(pc.developed_ratio(c, p) * 100.0)}

static func _housing(pc: PlanetCampaign, p: Dictionary) -> int:
	var net: Dictionary = pc.connected(p)
	var total: int = 0
	for value in pc.housing_by_cell(p, net, pc.utilities(p, net)).values():
		total += int(value)
	return total

static func _service_plan(pc: PlanetCampaign, p: Dictionary, sites: Dictionary) -> Dictionary:
	if int(p["pop"]) <= 0:
		return {}
	var cells: Dictionary = p["cells"] as Dictionary
	var report: Dictionary = pc.service_report(p)
	for service in ["fire", "hospital", "police"]:
		var now: float = float((report[service] as Dictionary)["coverage"])
		if now >= 0.999:
			continue
		var best: int = -1
		var best_gain: float = now + 0.0001
		for candidate in sites["free"]:
			var cell: Dictionary = cells[candidate] as Dictionary
			cell["facility"] = service
			var gain: float = float((pc.service_report(p)[service] as Dictionary)["coverage"])
			cell["facility"] = ""
			if gain > best_gain:
				best_gain = gain
				best = int(candidate)
		if best >= 0:
			return {"action": "civic", "kind": service, "id": best, "why": "couverture %s %d %%" % [String(J13Rules.SERVICE_LABELS[service]), int(now * 100.0)]}
		if (sites["free"] as Array).is_empty() and not (sites["frontier"] as Array).is_empty():
			return {"action": "road", "id": int((sites["frontier"] as Array)[0]), "why": "accès routier pour " + String(J13Rules.SERVICE_LABELS[service])}
	return {}

static func _recipe(age: int, cells: Dictionary) -> String:
	## Chaînes complètes d'abord : la fonderie alimente presque toutes les autres recettes.
	var counts: Dictionary = {}
	for cell in cells.values():
		var name: String = String((cell as Dictionary)["recipe"])
		if not name.is_empty():
			counts[name] = int(counts.get(name, 0)) + 1
	var best: String = "fonderie"
	var best_load: float = INF
	for name in J13Rules.RECIPE_ORDER:
		if age < int((J13Rules.RECIPES[name] as Dictionary)["age"]):
			continue
		var load: float = float(counts.get(name, 0)) / (4.0 if name == "fonderie" else 1.0)
		if load < best_load:
			best_load = load
			best = String(name)
	return best
