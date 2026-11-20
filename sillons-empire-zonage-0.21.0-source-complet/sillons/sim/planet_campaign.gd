class_name PlanetCampaign
extends RefCounted
## J13 : couche planétaire composée avec StarCampaign (aucune réécriture du RTS).
## - âge LOCAL par colonie (une colonie fondée naît à l'âge VII) ;
## - districts d'aire égale, zonage R/C/I, population, industrie, commerce ;
## - services par graphe routier et capacité (jamais par simple rayon) ;
## - trésorerie impériale par écritures, ressources physiques localisées ;
## - transports auditables (une seule livraison) ;
## - stations de commandement et verrou orbital des débarquements hostiles.
## Tout est simulé à pas fixe depuis StarCampaign.step(), jamais depuis une vue.

var colonies: Dictionary = {}      # "camp:corps" -> état de colonie
var treasury: Array = []           # par camp : {credits, minted, spent, seq}
var ledger: Array = []             # dernières écritures (audit)
var stations: Array = []           # stations de commandement supplémentaires
var next_station: int = 1
var transports: Array = []
var transport_log: Array = []
var next_transport: int = 1
var migrated_from: String = ""
# J13.1 : troupes issues des habitants, équipements et matériaux issus de l'industrie.
var supply_chain: bool = false

static var _land_cache: Dictionary = {}
static var _reach_cache: Dictionary = {}

func _init() -> void:
	treasury = [_new_account(), _new_account()]

static func _new_account() -> Dictionary:
	return {"credits": 0.0, "minted": 0.0, "spent": 0.0, "seq": 0}

static func key(team: int, body: String) -> String:
	return "%d:%s" % [team, body]

static func fail(code: String, reason: String) -> Dictionary:
	return {"ok": false, "reason_code": code, "reason": reason}

# ------------------------------------------------------------------ territoire
static func neighbors(id: int) -> Array:
	var col: int = id % J13Rules.GRID_W
	var row: int = id / J13Rules.GRID_W
	var out: Array = [row * J13Rules.GRID_W + posmod(col - 1, J13Rules.GRID_W), row * J13Rules.GRID_W + posmod(col + 1, J13Rules.GRID_W)]
	if row > 0:
		out.append(id - J13Rules.GRID_W)
	if row < J13Rules.GRID_H - 1:
		out.append(id + J13Rules.GRID_W)
	out.sort()
	return out

static func district_ll(id: int) -> Vector2:
	var col: int = id % J13Rules.GRID_W
	var row: int = id / J13Rules.GRID_W
	var s: float = 1.0 - 2.0 * (float(row) + 0.5) / float(J13Rules.GRID_H)
	return Vector2(-PI + TAU * (float(col) + 0.5) / float(J13Rules.GRID_W), asin(clampf(s, -1.0, 1.0)))

static func land_mask(seed: int) -> PackedByteArray:
	## Masque géographique immuable, recalculé depuis la graine : jamais sauvegardé.
	if _land_cache.has(seed):
		return _land_cache[seed] as PackedByteArray
	var count: int = J13Rules.GRID_W * J13Rules.GRID_H
	var mask := PackedByteArray()
	mask.resize(count)
	var atlas := PlanetGenerator.new(seed)
	for id in count:
		var ll: Vector2 = district_ll(id)
		var biome: int = int(atlas.sample(ll.x, ll.y)["biome"])
		var kind: int = J13Rules.LAND_BUILDABLE
		if biome == PlanetGenerator.OCEAN:
			kind = J13Rules.LAND_OCEAN
		elif biome == PlanetGenerator.MOUNTAIN:
			kind = J13Rules.LAND_RELIEF
		elif posmod(hash([seed, id, "reserve"]), 11) == 0:
			kind = J13Rules.LAND_PROTECTED
		mask[id] = kind
	# Garantie de progression : un site de fondation et un voisin constructibles.
	var best: int = -1
	var best_score: int = -1
	for id in count:
		if mask[id] != J13Rules.LAND_BUILDABLE:
			continue
		var score: int = 0
		for n in neighbors(id):
			if mask[int(n)] == J13Rules.LAND_BUILDABLE:
				score += 1
		if score > best_score:
			best_score = score
			best = id
	if best < 0 or best_score < 1:
		best = (J13Rules.GRID_H / 2) * J13Rules.GRID_W + J13Rules.GRID_W / 2
		mask[best] = J13Rules.LAND_BUILDABLE
		mask[best + 1] = J13Rules.LAND_BUILDABLE
	if _land_cache.size() > 64:
		_land_cache.clear()
	_land_cache[seed] = mask
	return mask

static func home_district(seed: int, avoid: int = -1) -> int:
	## Site de fondation : dans la plus grande terre constructible d'un seul tenant,
	## à distance du commandement adverse quand deux camps partagent le monde.
	var mask: PackedByteArray = land_mask(seed)
	var size_of: Dictionary = {}
	for start in mask.size():
		if mask[start] != J13Rules.LAND_BUILDABLE or size_of.has(start):
			continue
		var group: Array = [start]
		var queue: Array = [start]
		size_of[start] = 0
		while not queue.is_empty():
			var current: int = int(queue.pop_front())
			for n in neighbors(current):
				if mask[int(n)] == J13Rules.LAND_BUILDABLE and not size_of.has(n):
					size_of[n] = 0
					group.append(int(n))
					queue.append(int(n))
		for member in group:
			size_of[member] = group.size()
	var banned: Dictionary = {}
	if avoid >= 0:
		banned[avoid] = true
		for n in neighbors(avoid):
			banned[n] = true
			for m in neighbors(int(n)):
				banned[m] = true
	var best: int = -1
	var best_score: int = -1
	for id in mask.size():
		if mask[id] != J13Rules.LAND_BUILDABLE or banned.has(id):
			continue
		var score: int = int(size_of[id]) * 10
		for n in neighbors(id):
			if mask[int(n)] == J13Rules.LAND_BUILDABLE:
				score += 1
		if score > best_score:
			best_score = score
			best = id
	return best if best >= 0 else home_district(seed)

# ------------------------------------------------------------------ colonies
func colony(team: int, body: String) -> Dictionary:
	return colonies.get(key(team, body), {}) as Dictionary

func has_colony(team: int, body: String) -> bool:
	return colonies.has(key(team, body))

func local_age(c: StarCampaign, team: int, body: String) -> int:
	## Âge qui gouverne la PRODUCTION sur ce monde. Sans colonie : âge impérial (hérité).
	var p: Dictionary = colony(team, body)
	if p.is_empty() or bool(p["tracks_empire"]):
		return int(c.ages[team])
	return mini(int(p["local_age"]), 10)

func note_world_age(c: StarCampaign, team: int, body: String, age: int) -> void:
	## Passage d'âge obtenu au centre tactique : il reste LOCAL sur une colonie.
	var p: Dictionary = colony(team, body)
	if p.is_empty() or bool(p["tracks_empire"]):
		c.ages[team] = maxi(int(c.ages[team]), age)
	elif age > int(p["local_age"]):
		_set_local_age(c, p, mini(age, 10))

func _set_local_age(c: StarCampaign, p: Dictionary, age: int) -> void:
	p["local_age"] = age
	c._record_notice(int(p["team"]), "%s : âge local %s atteint" % [String(c.info(String(p["body"])).get("label", p["body"])), J13Rules.roman(age)], String(p["body"]))
	_governor_gate(c, p)

func _governor_gate(c: StarCampaign, p: Dictionary) -> void:
	var gov: Dictionary = p["governor"] as Dictionary
	if local_age(c, int(p["team"]), String(p["body"])) >= 10 and not bool(gov["granted"]):
		gov["granted"] = true
		gov["enabled"] = true
		c._record_notice(int(p["team"]), "Âge X local : gouverneur civil activé (suspendable à tout moment)", String(p["body"]))

func _body_seed(c: StarCampaign, body: String) -> int:
	return int(c.info(body).get("seed", c._initial_seed))

func found(c: StarCampaign, team: int, body: String, origin: String, settlers: int) -> Dictionary:
	## Crée l'état planétaire. origin : home | legacy (suivent l'âge impérial), colony, conquered.
	var id: String = key(team, body)
	if colonies.has(id):
		return colonies[id] as Dictionary
	var seed: int = _body_seed(c, body)
	var other: Dictionary = {}
	for actor in c.faction_ids():
		if int(actor) != team and has_colony(int(actor), body):
			other = colony(int(actor), body)
			break
	var hq: int = home_district(seed, -1 if other.is_empty() else int(other["hq"]))
	var age: int = int(c.ages[team])
	if origin == "colony":
		age = mini(age, J13Rules.COLONY_START_AGE)
	elif origin == "conquered" and not other.is_empty():
		age = mini(age, local_age(c, int(other["team"]), body))
	var stocks: Dictionary = {}
	for good in J13Rules.GOODS:
		stocks[good] = 0.0
	var p: Dictionary = {"team": team, "body": body, "origin": origin,
		"tracks_empire": origin in ["home", "legacy"], "local_age": age, "founded_tick": c.tick,
		"hq": hq, "cells": {hq: _new_cell("hq")}, "pop": maxi(0, settlers), "stocks": stocks,
		"target": J13Rules.DEFAULT_TARGET.duplicate(true), "reserve": 0.0,
		"governor": {"enabled": false, "granted": false, "suspended": false, "budget_cap": 400.0, "status": "", "journal": []},
		"reserved": [], "research": {}, "status": "occupied" if origin == "conquered" else "integrated",
		"stats": {}}
	colonies[id] = p
	_governor_gate(c, p)
	_refresh_stats(c, p)
	return p

static func _new_cell(facility: String = "") -> Dictionary:
	return {"zone": "", "density": 0, "facility": facility, "road": true, "cut": false, "manual": true, "recipe": "", "halt": ""}

func bootstrap(c: StarCampaign, scenario_credits: bool) -> void:
	## Nouvelle partie ou migration : un état « hérité » par monde où le camp commande déjà.
	for raw in c.worlds.keys():
		var body: String = String(raw)
		for team in c.faction_ids():
			if not (c.worlds[body] as SimWorld).team_buildings(team, "centre", true).is_empty():
				found(c, team, body, "home" if body == "val" else "legacy", 0)
	for team in c.faction_ids():
		if not c.evolutions_enabled and not has_colony(team, "val") and c.worlds.has("val"):
			found(c, team, "val", "home", 0)
		if scenario_credits:
			_mint(c, team, "treasury", J13Rules.SCENARIO_CREDITS, "dotation initiale de scénario")

# ------------------------------------------------------------------ trésorerie
func credits(team: int) -> float:
	return float((treasury[team] as Dictionary)["credits"])

func _entry(c: StarCampaign, team: int, debit: String, credit: String, amount: float, memo: String) -> void:
	var account: Dictionary = treasury[team] as Dictionary
	account["seq"] = int(account["seq"]) + 1
	ledger.append({"seq": int(account["seq"]), "tick": c.tick, "team": team, "debit": debit, "credit": credit, "amount": amount, "memo": memo})
	if ledger.size() > J13Rules.LEDGER_KEEP:
		ledger.pop_front()

func _mint(c: StarCampaign, team: int, account_name: String, amount: float, memo: String) -> void:
	var account: Dictionary = treasury[team] as Dictionary
	account["credits"] = float(account["credits"]) + amount
	account["minted"] = float(account["minted"]) + amount
	_entry(c, team, "monde", account_name, amount, memo)

func books_balanced(team: int) -> bool:
	## Invariant comptable : trésorerie + réserves locales = créé - dépensé.
	var account: Dictionary = treasury[team] as Dictionary
	var held: float = float(account["credits"])
	for p in colonies.values():
		if int((p as Dictionary)["team"]) == team:
			held += float((p as Dictionary)["reserve"])
	return absf(held - (float(account["minted"]) + float(account.get("transferred_in", 0.0)) - float(account["spent"]) - float(account.get("transferred_out", 0.0)))) < 0.01

func transfer_credits(c: StarCampaign, team: int, body: String, amount: float) -> Dictionary:
	## Trésorerie impériale -> réserve d'exploitation d'une colonie (écriture équilibrée).
	var p: Dictionary = colony(team, body)
	if p.is_empty() or not is_finite(amount) or amount <= 0.0:
		return fail("invalid", "colonie ou montant invalide")
	if credits(team) < amount:
		return fail("credits", "trésorerie insuffisante")
	(treasury[team] as Dictionary)["credits"] = credits(team) - amount
	p["reserve"] = float(p["reserve"]) + amount
	_entry(c, team, "treasury", "reserve:" + body, amount, "dotation coloniale")
	return {"ok": true}

# ------------------------------------------------------------------ coûts
func _depot(c: StarCampaign, team: int, body: String) -> Dictionary:
	if c.evolutions_enabled: return c.local_resources(team, body)
	return c.system_resources(team, c._system_of(body))

func missing(c: StarCampaign, team: int, body: String, cost: Dictionary, budget: float = -1.0) -> String:
	## Chaîne vide si tout est disponible ; sinon la première ressource manquante.
	var p: Dictionary = colony(team, body)
	var depot: Dictionary = _depot(c, team, body)
	for raw in cost.keys():
		var kind: String = String(raw)
		var amount: float = float(cost[raw])
		if kind == "credits":
			if budget >= 0.0 and amount > budget:
				return "budget du gouverneur"
			if credits(team) < amount:
				return "crédits"
		elif Rules.RESOURCES.has(kind):
			if float(depot.get(kind, 0.0)) < amount:
				return kind
		elif p.is_empty() or float((p["stocks"] as Dictionary).get(kind, 0.0)) < amount:
			return String(J13Rules.GOOD_LABELS.get(kind, kind))
	return ""

func _charge(c: StarCampaign, team: int, body: String, cost: Dictionary, memo: String) -> void:
	var p: Dictionary = colony(team, body)
	var depot: Dictionary = _depot(c, team, body)
	for raw in cost.keys():
		var kind: String = String(raw)
		var amount: float = float(cost[raw])
		if kind == "credits":
			var account: Dictionary = treasury[team] as Dictionary
			account["credits"] = float(account["credits"]) - amount
			account["spent"] = float(account["spent"]) + amount
			_entry(c, team, "treasury", "monde", amount, memo)
		elif Rules.RESOURCES.has(kind):
			depot[kind] = float(depot[kind]) - amount
		else:
			(p["stocks"] as Dictionary)[kind] = float((p["stocks"] as Dictionary)[kind]) - amount

# ------------------------------------------------------------------ graphe
func land_of(c: StarCampaign, p: Dictionary, id: int) -> int:
	return int(land_mask(_body_seed(c, String(p["body"])))[id])

func reachable(c: StarCampaign, p: Dictionary) -> Dictionary:
	## Districts que le réseau peut atteindre depuis le commandement, par la terre constructible
	## ou par liaison maritime. Un relief interdit ou une réserve naturelle ne se traverse pas.
	var seed: int = _body_seed(c, String(p["body"]))
	var cache_key: String = "%d:%d" % [seed, int(p["hq"])]
	if _reach_cache.has(cache_key):
		return _reach_cache[cache_key] as Dictionary
	var mask: PackedByteArray = land_mask(seed)
	var out: Dictionary = {int(p["hq"]): true}
	var queue: Array = [int(p["hq"])]
	while not queue.is_empty():
		var current: int = int(queue.pop_front())
		for n in neighbors(current):
			if not out.has(n) and mask[int(n)] in [J13Rules.LAND_BUILDABLE, J13Rules.LAND_OCEAN]:
				out[n] = true
				queue.append(int(n))
	if _reach_cache.size() > 128:
		_reach_cache.clear()
	_reach_cache[cache_key] = out
	return out

func eligible(c: StarCampaign, p: Dictionary, id: int) -> bool:
	## Périmètre « 100 % » : constructible, accessible, non protégé, non réservé, non tenu par l'adversaire.
	if id < 0 or id >= J13Rules.GRID_W * J13Rules.GRID_H or land_of(c, p, id) != J13Rules.LAND_BUILDABLE:
		return false
	if (p["reserved"] as Array).has(id) or not reachable(c, p).has(id):
		return false
	var other: Dictionary = colony(1 - int(p["team"]), String(p["body"]))
	return other.is_empty() or not (other["cells"] as Dictionary).has(id)

func connected(p: Dictionary) -> Dictionary:
	## Districts reliés au commandement par des routes praticables : id -> nombre d'étapes.
	return hops_from(p, int(p["hq"]))

static func hops_from(p: Dictionary, start: int) -> Dictionary:
	var cells: Dictionary = p["cells"] as Dictionary
	var out: Dictionary = {}
	if not cells.has(start) or not bool((cells[start] as Dictionary)["road"]) or bool((cells[start] as Dictionary)["cut"]):
		return out
	out[start] = 0
	var queue: Array = [start]
	while not queue.is_empty():
		var current: int = int(queue.pop_front())
		for n in neighbors(current):
			var id: int = int(n)
			if out.has(id) or not cells.has(id):
				continue
			var cell: Dictionary = cells[id] as Dictionary
			if not bool(cell["road"]) or bool(cell["cut"]):
				continue
			out[id] = int(out[current]) + 1
			queue.append(id)
	return out

static func cell_kind(cell: Dictionary) -> String:
	return String(cell["zone"]) if not String(cell["zone"]).is_empty() else String(cell["facility"])

func utilities(p: Dictionary, net: Dictionary) -> Dictionary:
	## Réseaux eau/électricité : capacité réelle, délestage par priorité, uniquement sur le réseau relié.
	var cells: Dictionary = p["cells"] as Dictionary
	var consumers: Array = []
	var ids: Array = net.keys()
	ids.sort()
	for raw in ids:
		var cell: Dictionary = cells[raw] as Dictionary
		var kind: String = cell_kind(cell)
		if kind.is_empty():
			continue
		var need: int = int(J13Rules.UTILITY_NEED.get(kind, 0)) * maxi(1, int(cell["density"]))
		consumers.append([J13Rules.UTILITY_PRIORITY.find(kind) if J13Rules.UTILITY_PRIORITY.has(kind) else 99, int(raw), kind, need])
	consumers.sort()
	var result: Dictionary = {"power": {}, "water": {}, "power_ratio": 1.0, "water_ratio": 1.0, "power_free": 0, "water_free": 0}
	for pass_name in ["power", "water"]:
		var supply: int = J13Rules.HQ_AUTONOMY
		for raw in ids:
			var cell: Dictionary = cells[raw] as Dictionary
			if String(cell["facility"]) == pass_name and (pass_name == "power" or (result["power"] as Dictionary).has(int(raw))):
				supply += int((J13Rules.FACILITIES[pass_name] as Dictionary)["capacity"])
		var total: int = 0
		var served: int = 0
		for item in consumers:
			var kind: String = String(item[2])
			var need: int = int(item[3])
			if pass_name == "power" and kind == "power":
				(result["power"] as Dictionary)[int(item[1])] = true
				continue
			if pass_name == "water" and kind == "water":
				(result["water"] as Dictionary)[int(item[1])] = true
				continue
			total += need
			if need <= supply:
				supply -= need
				served += need
				(result[pass_name] as Dictionary)[int(item[1])] = true
		result[pass_name + "_ratio"] = 1.0 if total == 0 else float(served) / float(total)
		result[pass_name + "_free"] = supply
	return result

func housing_by_cell(p: Dictionary, net: Dictionary, util: Dictionary) -> Dictionary:
	var out: Dictionary = {int(p["hq"]): 16}
	var cells: Dictionary = p["cells"] as Dictionary
	for raw in net.keys():
		var cell: Dictionary = cells[raw] as Dictionary
		if String(cell["zone"]) != "R":
			continue
		var capacity: int = J13Rules.HOUSING * int(cell["density"])
		# Sans eau ou sans électricité, un quartier ne loge que la moitié de sa capacité.
		if not (util["power"] as Dictionary).has(int(raw)) or not (util["water"] as Dictionary).has(int(raw)):
			capacity /= 2
		out[int(raw)] = capacity
	return out

func service_report(p: Dictionary) -> Dictionary:
	## served(district) = accessible par la route ET temps <= seuil ET capacité allouée >= demande.
	var net: Dictionary = connected(p)
	var util: Dictionary = utilities(p, net)
	var housing: Dictionary = housing_by_cell(p, net, util)
	var total_housing: int = 0
	for value in housing.values():
		total_housing += int(value)
	var pop: float = float(p["pop"])
	var cells: Dictionary = p["cells"] as Dictionary
	var report: Dictionary = {}
	for service in J13Rules.MOBILE_SERVICES:
		var definition: Dictionary = J13Rules.FACILITIES[service] as Dictionary
		var posts: Array = []
		var ids: Array = cells.keys()
		ids.sort()
		for raw in ids:
			if String((cells[raw] as Dictionary)["facility"]) == service and net.has(raw) and (util["power"] as Dictionary).has(int(raw)):
				posts.append({"id": int(raw), "left": float(definition["capacity"]), "hops": hops_from(p, int(raw))})
		var covered: float = 0.0
		var uncovered: Dictionary = {}
		var demand_ids: Array = housing.keys()
		demand_ids.sort()
		for raw in demand_ids:
			var demand: float = 0.0 if total_housing == 0 else pop * float(housing[raw]) / float(total_housing)
			if demand <= 0.0:
				continue
			var cause: String = "aucun poste" if posts.is_empty() else "hors d'atteinte par la route"
			var chosen: int = -1
			var best: int = 9999
			for index in posts.size():
				var post: Dictionary = posts[index] as Dictionary
				var hops: Dictionary = post["hops"] as Dictionary
				if not hops.has(raw) or int(hops[raw]) > int(definition["reach"]):
					continue
				if float(post["left"]) < demand:
					cause = "poste saturé"
					continue
				if int(hops[raw]) < best:
					best = int(hops[raw])
					chosen = index
			if chosen >= 0:
				(posts[chosen] as Dictionary)["left"] = float((posts[chosen] as Dictionary)["left"]) - demand
				covered += demand
			else:
				uncovered[int(raw)] = cause
		report[service] = {"coverage": 1.0 if pop <= 0.0 else clampf(covered / pop, 0.0, 1.0), "uncovered": uncovered}
	return report

func zoning_shares(p: Dictionary) -> Dictionary:
	var counts: Dictionary = {"R": 0, "C": 0, "I": 0}
	for cell in (p["cells"] as Dictionary).values():
		var zone: String = String((cell as Dictionary)["zone"])
		if counts.has(zone):
			counts[zone] = int(counts[zone]) + 1
	var total: int = int(counts["R"]) + int(counts["C"]) + int(counts["I"])
	var out: Dictionary = {"count": total}
	for zone in J13Rules.ZONES:
		out[zone] = 0.0 if total == 0 else float(counts[zone]) / float(total)
	return out

func balance(p: Dictionary) -> float:
	var shares: Dictionary = zoning_shares(p)
	if int(shares["count"]) == 0:
		return 0.0
	var gap: float = 0.0
	for zone in J13Rules.ZONES:
		gap += absf(float(shares[zone]) - float((p["target"] as Dictionary)[zone]))
	return maxf(0.0, 1.0 - gap / 2.0)

func developed_ratio(c: StarCampaign, p: Dictionary) -> float:
	## Part du périmètre ÉLIGIBLE occupée utilement (zone, service ou commandement). Jamais l'océan.
	var total: int = 0
	var done: int = 0
	var cells: Dictionary = p["cells"] as Dictionary
	for id in J13Rules.GRID_W * J13Rules.GRID_H:
		if not eligible(c, p, id):
			continue
		total += 1
		if cells.has(id) and not cell_kind(cells[id] as Dictionary).is_empty():
			done += 1
	return 1.0 if total == 0 else float(done) / float(total)

# ------------------------------------------------------------------ commandes civiles
func _guard(c: StarCampaign, team: int, body: String) -> String:
	if not c.valid_faction(team) or bool(c.eliminated[team]):
		return "camp indisponible"
	var p: Dictionary = colony(team, body)
	if p.is_empty():
		return "aucune colonie de ce camp sur ce monde"
	if String(p["status"]) == "lost":
		return "colonie perdue : reprendre un centre de commandement"
	return ""

func build_road(c: StarCampaign, team: int, body: String, id: int, budget: float = -1.0) -> Dictionary:
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var p: Dictionary = colony(team, body)
	var cells: Dictionary = p["cells"] as Dictionary
	if id < 0 or id >= J13Rules.GRID_W * J13Rules.GRID_H:
		return fail("land", "district hors carte")
	# Sur l'océan : liaison maritime plus chère, jamais constructible ensuite.
	var sea: bool = land_of(c, p, id) == J13Rules.LAND_OCEAN
	if not sea and not eligible(c, p, id):
		return fail("land", "terrain non aménageable : " + String(J13Rules.LAND_LABELS[land_of(c, p, id)]))
	var road_cost: Dictionary = J13Rules.LINK_COST if sea else J13Rules.ROAD_COST
	if cells.has(id) and bool((cells[id] as Dictionary)["road"]):
		return fail("exists", "route déjà présente")
	var linked: bool = false
	for n in neighbors(id):
		if cells.has(n) and bool((cells[n] as Dictionary)["road"]):
			linked = true
	if not linked:
		return fail("network", "route à raccorder à un district déjà desservi")
	var lack: String = missing(c, team, body, road_cost, budget)
	if not lack.is_empty():
		return fail("cost", "manque : " + lack)
	_charge(c, team, body, road_cost, "liaison maritime" if sea else "route")
	var cell: Dictionary = _new_cell()
	cell["manual"] = budget < 0.0
	cells[id] = cell
	return {"ok": true, "created_ids": [id]}

func _buildable_cell(c: StarCampaign, p: Dictionary, id: int) -> String:
	var cells: Dictionary = p["cells"] as Dictionary
	if not eligible(c, p, id):
		return "terrain non aménageable"
	if not cells.has(id) or not connected(p).has(id):
		return "district sans accès routier au commandement"
	if not cell_kind(cells[id] as Dictionary).is_empty():
		return "district déjà occupé"
	return ""

func zone(c: StarCampaign, team: int, body: String, id: int, kind: String, budget: float = -1.0, recipe: String = "") -> Dictionary:
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	if not J13Rules.ZONES.has(kind):
		return fail("invalid", "zone inconnue")
	var p: Dictionary = colony(team, body)
	var age: int = local_age(c, team, body)
	if age < int(J13Rules.ZONE_MIN_AGE[kind]):
		return fail("age", "âge local %s requis" % J13Rules.roman(int(J13Rules.ZONE_MIN_AGE[kind])))
	refusal = _buildable_cell(c, p, id)
	if not refusal.is_empty():
		return fail("site", refusal)
	var chosen: String = ""
	if kind == "I":
		chosen = recipe if not recipe.is_empty() else "fonderie"
		if not J13Rules.RECIPES.has(chosen) or age < int((J13Rules.RECIPES[chosen] as Dictionary)["age"]):
			return fail("recipe", "recette indisponible à cet âge local")
	var cost: Dictionary = J13Rules.ZONE_COST[kind] as Dictionary
	var lack: String = missing(c, team, body, cost, budget)
	if not lack.is_empty():
		return fail("cost", "manque : " + lack)
	_charge(c, team, body, cost, "zone " + kind)
	var cell: Dictionary = (p["cells"] as Dictionary)[id] as Dictionary
	cell["zone"] = kind
	cell["density"] = 1
	cell["recipe"] = chosen
	cell["manual"] = budget < 0.0
	return {"ok": true, "created_ids": [id]}

func densify(c: StarCampaign, team: int, body: String, id: int, budget: float = -1.0) -> Dictionary:
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var p: Dictionary = colony(team, body)
	var cells: Dictionary = p["cells"] as Dictionary
	if not cells.has(id) or String((cells[id] as Dictionary)["zone"]).is_empty():
		return fail("site", "aucune zone à densifier")
	var cell: Dictionary = cells[id] as Dictionary
	var level: int = int(cell["density"]) + 1
	if level > J13Rules.max_density(local_age(c, team, body)):
		return fail("age", "densité maximale pour cet âge local")
	var cost: Dictionary = {"credits": J13Rules.DENSIFY_CREDITS * level, "concrete": J13Rules.DENSIFY_CONCRETE * (level - 1)}
	var lack: String = missing(c, team, body, cost, budget)
	if not lack.is_empty():
		return fail("cost", "manque : " + lack)
	_charge(c, team, body, cost, "densification")
	cell["density"] = level
	return {"ok": true}

func build_civic(c: StarCampaign, team: int, body: String, id: int, kind: String, budget: float = -1.0) -> Dictionary:
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	if not J13Rules.FACILITIES.has(kind):
		return fail("invalid", "équipement inconnu")
	var p: Dictionary = colony(team, body)
	refusal = _buildable_cell(c, p, id)
	if not refusal.is_empty():
		return fail("site", refusal)
	var cost: Dictionary = (J13Rules.FACILITIES[kind] as Dictionary)["cost"] as Dictionary
	var lack: String = missing(c, team, body, cost, budget)
	if not lack.is_empty():
		return fail("cost", "manque : " + lack)
	_charge(c, team, body, cost, String((J13Rules.FACILITIES[kind] as Dictionary)["label"]))
	var cell: Dictionary = (p["cells"] as Dictionary)[id] as Dictionary
	cell["facility"] = kind
	cell["manual"] = budget < 0.0
	return {"ok": true, "created_ids": [id]}

func quick_build(c: StarCampaign, team: int, body: String, kind: String, recipe: String = "") -> Dictionary:
	## Bouton tactile : prochain district libre relié ; sinon la route (ou liaison maritime) qui y mène.
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var p: Dictionary = colony(team, body)
	var sites: Dictionary = PlanetGovernor._sites(c, self, p, connected(p))
	if (sites["free"] as Array).is_empty():
		if (sites["frontier"] as Array).is_empty():
			return fail("site", "plus aucun district éligible sur ce monde")
		var road: Dictionary = build_road(c, team, body, int((sites["frontier"] as Array)[0]))
		if bool(road.get("ok", false)):
			road["note"] = "Route ouverte vers un nouveau district : appuyer de nouveau pour bâtir"
		return road
	var id: int = int((sites["free"] as Array)[0])
	if J13Rules.ZONES.has(kind):
		return zone(c, team, body, id, kind, -1.0, (recipe if not recipe.is_empty() else PlanetGovernor._recipe(local_age(c, team, body), p["cells"] as Dictionary)) if kind == "I" else "")
	return build_civic(c, team, body, id, kind)

func quick_densify(c: StarCampaign, team: int, body: String, kind: String, recipe: String = "") -> Dictionary:
	## Bouton tactile : passe le premier district de ce type au niveau supérieur (maisons -> immeubles...).
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var cells: Dictionary = colony(team, body)["cells"] as Dictionary
	var ids: Array = cells.keys()
	ids.sort()
	var last: Dictionary = fail("site", "aucun district %s à densifier" % String(J13Rules.ZONE_LABELS.get(kind, kind)).to_lower())
	for raw in ids:
		var cell: Dictionary = cells[raw] as Dictionary
		if String(cell["zone"]) == kind and int(cell["density"]) < 3:
			last = densify(c, team, body, int(raw))
			if bool(last.get("ok", false)):
				last["note"] = String((J13Rules.DENSITY_LABELS[kind] as Array)[int(cell["density"]) - 1])
			return last
	return last

func set_recipe(c: StarCampaign, team: int, body: String, id: int, recipe: String) -> Dictionary:
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var cells: Dictionary = colony(team, body)["cells"] as Dictionary
	if not cells.has(id) or String((cells[id] as Dictionary)["zone"]) != "I" or not J13Rules.RECIPES.has(recipe):
		return fail("invalid", "district industriel et recette connus requis")
	if local_age(c, team, body) < int((J13Rules.RECIPES[recipe] as Dictionary)["age"]):
		return fail("age", "recette indisponible à cet âge local")
	(cells[id] as Dictionary)["recipe"] = recipe
	return {"ok": true}

func demolish(c: StarCampaign, team: int, body: String, id: int) -> Dictionary:
	## Démolition volontaire du joueur (jamais du gouverneur). La route reste.
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var p: Dictionary = colony(team, body)
	var cells: Dictionary = p["cells"] as Dictionary
	if not cells.has(id) or id == int(p["hq"]) or cell_kind(cells[id] as Dictionary).is_empty():
		return fail("site", "rien à démolir ici")
	var cell: Dictionary = cells[id] as Dictionary
	cell["zone"] = ""
	cell["density"] = 0
	cell["facility"] = ""
	cell["recipe"] = ""
	cell["halt"] = ""
	return {"ok": true}

func damage_road(team: int, body: String, id: int) -> bool:
	## Événement (combat, catastrophe) : la route coupée interrompt réellement services et production.
	var p: Dictionary = colony(team, body)
	if p.is_empty() or not (p["cells"] as Dictionary).has(id) or id == int(p["hq"]):
		return false
	((p["cells"] as Dictionary)[id] as Dictionary)["cut"] = true
	return true

func repair_road(c: StarCampaign, team: int, body: String, id: int, budget: float = -1.0) -> Dictionary:
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var cells: Dictionary = colony(team, body)["cells"] as Dictionary
	if not cells.has(id) or not bool((cells[id] as Dictionary)["cut"]):
		return fail("site", "aucune route coupée ici")
	var lack: String = missing(c, team, body, J13Rules.REPAIR_COST, budget)
	if not lack.is_empty():
		return fail("cost", "manque : " + lack)
	_charge(c, team, body, J13Rules.REPAIR_COST, "réparation de route")
	(cells[id] as Dictionary)["cut"] = false
	return {"ok": true}

func set_target(c: StarCampaign, team: int, body: String, r: float, commerce: float, industry: float) -> Dictionary:
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	for value in [r, commerce, industry]:
		if not is_finite(value) or value < J13Rules.TARGET_MIN or value > J13Rules.TARGET_MAX:
			return fail("bounds", "chaque part doit rester entre 5 % et 90 %")
	if absf(r + commerce + industry - 1.0) > 0.001:
		return fail("sum", "la somme R + C + I doit valoir 100 %")
	colony(team, body)["target"] = {"R": r, "C": commerce, "I": industry}
	return {"ok": true}

func set_governor(c: StarCampaign, team: int, body: String, enabled: bool, budget_cap: float = -1.0) -> Dictionary:
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var gov: Dictionary = colony(team, body)["governor"] as Dictionary
	if enabled and local_age(c, team, body) < 10:
		return fail("age", "gouverneur civil : âge X local requis")
	if budget_cap >= 0.0:
		if not is_finite(budget_cap) or budget_cap > 1000000.0:
			return fail("bounds", "plafond de budget invalide")
		gov["budget_cap"] = budget_cap
	if enabled:
		gov["granted"] = true
	gov["enabled"] = enabled
	gov["suspended"] = not enabled
	return {"ok": true}

func set_reserved(c: StarCampaign, team: int, body: String, id: int, reserved: bool) -> Dictionary:
	## « Protéger cette région » : exclue du périmètre, jamais aménagée par le gouverneur.
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var p: Dictionary = colony(team, body)
	if id < 0 or id >= J13Rules.GRID_W * J13Rules.GRID_H:
		return fail("invalid", "district inconnu")
	var list: Array = p["reserved"] as Array
	if reserved and not list.has(id):
		if (p["cells"] as Dictionary).has(id) and not cell_kind((p["cells"] as Dictionary)[id] as Dictionary).is_empty():
			return fail("site", "district déjà occupé")
		list.append(id)
	elif not reserved:
		list.erase(id)
	return {"ok": true}

func advance_colony_age(c: StarCampaign, team: int, body: String) -> Dictionary:
	var refusal: String = _guard(c, team, body)
	if not refusal.is_empty():
		return fail("colony", refusal)
	var p: Dictionary = colony(team, body)
	if bool(p["tracks_empire"]):
		return fail("home", "monde fondateur : passage d'âge au centre de commandement")
	if not (p["research"] as Dictionary).is_empty():
		return fail("busy", "passage d'âge déjà en cours")
	var target: int = int(p["local_age"]) + 1
	if target > int(c.ages[team]):
		return fail("empire", "l'âge local ne dépasse pas l'âge de l'empire")
	if not J13Rules.AGE_UP.has(target):
		return fail("age", "avant l'âge VII : passage d'âge au centre de commandement")
	var rule: Dictionary = J13Rules.AGE_UP[target] as Dictionary
	var industry: int = 0
	for cell in (p["cells"] as Dictionary).values():
		if String((cell as Dictionary)["zone"]) == "I":
			industry += 1
	if industry < int(rule["industry"]):
		return fail("industry", "%d districts industriels requis" % int(rule["industry"]))
	if rule.has("power") and float((p["stats"] as Dictionary).get("power", 0.0)) < float(rule["power"]):
		return fail("power", "réseau électrique insuffisant")
	if rule.has("station") and station_count(c, team, body) < 1:
		return fail("station", "station de commandement orbitale locale requise")
	var cost: Dictionary = (rule["goods"] as Dictionary).duplicate(true)
	cost["credits"] = int(rule["credits"])
	var lack: String = missing(c, team, body, cost)
	if not lack.is_empty():
		return fail("cost", "manque : " + lack)
	_charge(c, team, body, cost, "âge local %s" % J13Rules.roman(target))
	p["research"] = {"target": target, "remaining": int(rule["ticks"])}
	return {"ok": true, "eta": int(rule["ticks"])}

# ------------------------------------------------------------------ pas économique
func step(c: StarCampaign) -> void:
	_step_stations(c)
	_step_transports(c)
	if c.tick % J13Rules.ECON_PERIOD == 0:
		var ids: Array = colonies.keys()
		ids.sort()
		for id in ids:
			var p: Dictionary = colonies[id] as Dictionary
			_refresh_status(c, p)
			if String(p["status"]) != "lost":
				_economy(c, p)
	if c.tick % J13Rules.GOVERNOR_PERIOD == 0:
		var ids: Array = colonies.keys()
		ids.sort()
		for id in ids:
			PlanetGovernor.run(c, self, colonies[id] as Dictionary)

func _refresh_status(c: StarCampaign, p: Dictionary) -> void:
	var team: int = int(p["team"])
	var body: String = String(p["body"])
	_governor_gate(c, p)
	if not c.worlds.has(body):
		return
	var holds: bool = (c.evolutions_enabled and p.has("politics") and bool(p["politics"].get("sovereign", false))) or not (c.worlds[body] as SimWorld).team_buildings(team, "centre", true).is_empty() or station_count(c, team, body) > 0
	if body == "val" and c.planet_regions != null and not holds:
		for region in c.planet_regions.worlds_in_play():
			if not (region as SimWorld).team_buildings(team, "centre", true).is_empty():
				holds = true
	if not holds and String(p["status"]) != "lost":
		p["status"] = "lost"
		c._record_notice(team, "Colonie perdue : plus de commandement sur %s" % String(c.info(body).get("label", body)), body)
	elif holds and String(p["status"]) == "lost":
		p["status"] = "occupied"
		p["founded_tick"] = c.tick
	elif String(p["status"]) == "occupied" and c.tick - int(p["founded_tick"]) >= 600:
		p["status"] = "integrated"

func _refresh_stats(c: StarCampaign, p: Dictionary) -> void:
	var net: Dictionary = connected(p)
	var util: Dictionary = utilities(p, net)
	var report: Dictionary = service_report(p)
	var shares: Dictionary = zoning_shares(p)
	var stats: Dictionary = p["stats"] as Dictionary
	stats["power"] = float(util["power_ratio"])
	stats["water"] = float(util["water_ratio"])
	for service in J13Rules.MOBILE_SERVICES:
		stats[service] = float((report[service] as Dictionary)["coverage"])
	for zone_kind in J13Rules.ZONES:
		stats[zone_kind] = float(shares[zone_kind])
	stats["balance"] = balance(p)
	stats["developed"] = developed_ratio(c, p)

func _economy(c: StarCampaign, p: Dictionary) -> void:
	var team: int = int(p["team"])
	var body: String = String(p["body"])
	var cells: Dictionary = p["cells"] as Dictionary
	var stats: Dictionary = p["stats"] as Dictionary
	var depot: Dictionary = _depot(c, team, body)
	var stocks: Dictionary = p["stocks"] as Dictionary
	var net: Dictionary = connected(p)
	var util: Dictionary = utilities(p, net)
	var powered: Dictionary = util["power"] as Dictionary
	var watered: Dictionary = util["water"] as Dictionary
	var housing: int = 0
	for value in housing_by_cell(p, net, util).values():
		housing += int(value)
	var pop: int = int(p["pop"])
	# Vivres : consommés une seule fois, dans le dépôt physique du système.
	var food_need: float = float(pop) * J13Rules.FOOD_PER_HEAD
	var food_paid: float = minf(food_need, maxf(0.0, float(depot.get("food", 0.0))))
	depot["food"] = float(depot.get("food", 0.0)) - food_paid
	var food_access: float = 1.0 if food_need <= 0.0 else food_paid / food_need
	# Les soldats présents sur ce monde sont réellement retirés de la main-d'œuvre civile.
	var recruited: int = 0
	# Chaîne complète : les recrues ont déjà quitté la population à l'entraînement.
	if c.worlds.has(body) and not supply_chain:
		for u in (c.worlds[body] as SimWorld).team_units(team, "military"):
			recruited += int(Rules.UNITS[u.type]["pop"])
	var working_age: int = int(float(pop) * 0.6)
	recruited = mini(recruited, working_age)
	var workers: int = working_age - recruited
	if c.evolutions_enabled and p.has("politics"): workers = maxi(0, workers - int(float(working_age) * float(p["politics"]["mobilization"])))
	var jobs: int = 0
	var ids: Array = net.keys()
	ids.sort()
	for raw in ids:
		var cell: Dictionary = cells[raw] as Dictionary
		var kind: String = String(cell["zone"])
		if J13Rules.JOBS.has(kind) and powered.has(int(raw)) and watered.has(int(raw)):
			jobs += int(J13Rules.JOBS[kind]) * int(cell["density"])
	var employed: int = mini(workers, jobs)
	var staff: float = 0.0 if jobs == 0 else float(employed) / float(jobs)
	# Industrie : une usine sans eau, énergie, personnel ou intrants ne produit rien et dit pourquoi.
	for raw in cells.keys():
		if String((cells[raw] as Dictionary)["zone"]) == "I":
			(cells[raw] as Dictionary)["halt"] = "hors réseau routier"
	for raw in ids:
		var cell: Dictionary = cells[raw] as Dictionary
		if String(cell["zone"]) != "I":
			continue
		var recipe: Dictionary = J13Rules.RECIPES.get(String(cell["recipe"]), {}) as Dictionary
		var halt: String = ""
		if recipe.is_empty():
			halt = "aucune recette"
		elif not powered.has(int(raw)):
			halt = "électricité"
		elif not watered.has(int(raw)):
			halt = "eau"
		elif staff <= 0.0:
			halt = "main-d'œuvre"
		var scale: float = float(cell["density"]) * staff * (PoliticalState.productivity(p) if c.evolutions_enabled else 1.0)
		if halt.is_empty():
			for input in (recipe["in"] as Dictionary).keys():
				var have: float = float(depot.get(input, 0.0)) if Rules.RESOURCES.has(String(input)) else float(stocks.get(input, 0.0))
				if have < float(recipe["in"][input]) * scale:
					halt = "intrants : " + String(J13Rules.GOOD_LABELS.get(input, input))
					break
		if halt.is_empty():
			for output in (recipe["out"] as Dictionary).keys():
				if float(stocks[output]) + float(recipe["out"][output]) * scale > J13Rules.STOCK_CAP:
					halt = "entrepôt plein"
		if halt.is_empty():
			for input in (recipe["in"] as Dictionary).keys():
				var amount: float = float(recipe["in"][input]) * scale
				if Rules.RESOURCES.has(String(input)):
					depot[input] = float(depot[input]) - amount
				else:
					stocks[input] = float(stocks[input]) - amount
			for output in (recipe["out"] as Dictionary).keys():
				stocks[output] = float(stocks[output]) + float(recipe["out"][output]) * scale
		cell["halt"] = halt
	# Commerce : pas de produit ou pas de client = pas de crédit.
	var demand: float = float(pop) * J13Rules.DEMAND_PER_HEAD * (0.0 if workers <= 0 else float(employed) / float(workers))
	var revenue: float = 0.0
	var shops: int = 0
	var shop_staff: float = 0.0
	for raw in ids:
		var cell: Dictionary = cells[raw] as Dictionary
		if String(cell["zone"]) != "C" or not powered.has(int(raw)) or not watered.has(int(raw)):
			continue
		shops += 1
		shop_staff += float(J13Rules.JOBS["C"]) * float(cell["density"]) * staff
		var reach: float = float(cell["density"]) * staff
		var sold: float = minf(minf(J13Rules.SHOP_GOODS_RATE * reach, float(stocks["consumer_goods"])), demand)
		stocks["consumer_goods"] = float(stocks["consumer_goods"]) - sold
		demand -= sold
		revenue += sold * J13Rules.GOODS_PRICE
		var provisions: float = minf(minf(J13Rules.SHOP_FOOD_RATE * reach, maxf(0.0, float(depot.get("food", 0.0)) - J13Rules.FOOD_SALE_FLOOR)), demand)
		depot["food"] = float(depot.get("food", 0.0)) - provisions
		demand -= provisions
		revenue += provisions * J13Rules.FOOD_PRICE
	var charges: float = J13Rules.PAYROLL * shop_staff + J13Rules.SHOP_MAINTENANCE * float(shops)
	var account: Dictionary = treasury[team] as Dictionary
	if revenue > 0.0:
		p["reserve"] = float(p["reserve"]) + revenue
		account["minted"] = float(account["minted"]) + revenue
	var paid: float = minf(charges, float(p["reserve"]))
	p["reserve"] = float(p["reserve"]) - paid
	account["spent"] = float(account["spent"]) + paid
	stats["arrears"] = charges - paid
	stats["sales"] = revenue
	stats["profit"] = revenue - charges
	# Démographie agrégée : chaque naissance, arrivée ou perte n'est comptée qu'une fois.
	if food_access < 0.999:
		pop -= mini(pop, maxi(1, int(float(pop) * 0.02 * (1.0 - food_access))))
	elif pop > housing:
		pop -= mini(pop - housing, maxi(1, pop / 20))
	elif pop < housing:
		# Sans emploi suffisant la croissance ralentit, mais les logements se remplissent :
		# les habitants sans emploi forment la réserve de recrues et de colons.
		var idle: bool = pop >= 12 and workers - employed > maxi(6, int(float(workers) * 0.3))
		pop += mini(housing - pop, 1 if idle else maxi(1, pop / 50))
	p["pop"] = pop
	stats["housing"] = housing
	stats["jobs"] = jobs
	stats["workers"] = workers
	stats["employed"] = employed
	stats["recruited"] = recruited
	stats["food_access"] = food_access
	_refresh_stats(c, p)
	# Passage d'âge local en cours.
	var research: Dictionary = p["research"] as Dictionary
	if not research.is_empty():
		research["remaining"] = int(research["remaining"]) - J13Rules.ECON_PERIOD
		if int(research["remaining"]) <= 0:
			var target: int = int(research["target"])
			p["research"] = {}
			_set_local_age(c, p, target)
	# Seul le bénéfice net au-delà de la réserve d'exploitation remonte, à cadence discrète.
	if c.tick % J13Rules.TRANSFER_PERIOD == 0 and String(p["status"]) == "integrated":
		var surplus: float = float(p["reserve"]) - J13Rules.RESERVE_FLOOR
		if c.evolutions_enabled and p.has("politics"): surplus *= clampf(float(p["politics"]["tax"]) / 0.2 * (1.0 - float(p["politics"]["autonomy"])), 0.0, 1.0)
		if surplus > 0.0:
			p["reserve"] = float(p["reserve"]) - surplus
			account["credits"] = float(account["credits"]) + surplus
			_entry(c, team, "reserve:" + body, "treasury", surplus, "bénéfice net")

# ------------------------------------------------------------------ stations et verrou orbital
func station_count(c: StarCampaign, team: int, body: String) -> int:
	## Stations de commandement OPÉRATIONNELLES du camp au-dessus de ce monde (chantier naval compris).
	var count: int = 1 if OrbitalIndustry.has_hub(c, team, body) else 0
	for station in stations:
		if int(station["team"]) == team and String(station["body"]) == body and int(station["remaining"]) == 0:
			count += 1
	return count

func landing_blocked(c: StarCampaign, attacker: int, body: String) -> int:
	## Nombre de stations ennemies opérationnelles qui interdisent un débarquement hostile.
	## Jamais hostile : le monde fondateur du camp, ou un monde où il tient lui-même l'orbite.
	if not c.valid_faction(attacker):
		return 0
	var blocking: int = 0
	for enemy in c.factions.enemies(attacker): blocking += station_count(c, int(enemy), body)
	if blocking == 0:
		return 0
	var own: Dictionary = colony(attacker, body)
	if not c.evolutions_enabled and not own.is_empty() and String(own["origin"]) == "home":
		return 0
	if not c.evolutions_enabled and station_count(c, attacker, body) > 0:
		return 0
	return blocking

func lock_text(c: StarCampaign, attacker: int, body: String) -> String:
	var blocking: int = landing_blocked(c, attacker, body)
	if blocking == 0:
		return ""
	return "INVASION BLOQUÉE : %d STATION%s DE COMMANDEMENT ENNEMIE%s" % [blocking, "S" if blocking > 1 else "", "S" if blocking > 1 else ""]

func start_station(c: StarCampaign, team: int, body: String) -> Dictionary:
	## Première station = chantier naval 0.12.3 (jamais offert à une colonie) ; suivantes = stations de commandement.
	if not c.valid_faction(team) or bool(c.eliminated[team]) or not c.star_catalog.has_body(body):
		return fail("invalid", "camp ou monde invalide")
	if has_colony(team, body) and local_age(c, team, body) < 9:
		return fail("age", "âge IX local requis pour une station orbitale")
	if OrbitalIndustry.site(c, team, body).is_empty():
		var first: Dictionary = OrbitalIndustry.deploy(c, team, body)
		if not bool(first.get("ok", false)):
			first["reason_code"] = "deploy"
		return first
	if not OrbitalIndustry.has_hub(c, team, body):
		return fail("busy", "chantier naval encore en assemblage")
	var existing: int = 1
	for station in stations:
		if int(station["team"]) == team and String(station["body"]) == body:
			existing += 1
	if existing >= J13Rules.STATION_LIMIT:
		return fail("limit", "nombre maximal de stations atteint")
	if int(OrbitalIndustry.presence(c, team, body).get("drone", 0)) < 1:
		return fail("drone", "drone constructeur en orbite requis")
	if c.ages[team] < 9:
		return fail("age", "âge IX requis")
	var payer: String = body
	var lack: String = ""
	var cost: Dictionary = J13Rules.STATION_COST
	var depot: Dictionary = _depot(c, team, body)
	for raw in cost.keys():
		if String(raw) == "credits":
			if credits(team) < float(cost[raw]):
				lack = "crédits"
		elif float(depot.get(raw, 0.0)) < float(cost[raw]):
			lack = String(raw)
	if not lack.is_empty():
		return fail("cost", "manque : " + lack)
	for raw in cost.keys():
		if String(raw) == "credits":
			var account: Dictionary = treasury[team] as Dictionary
			account["credits"] = float(account["credits"]) - float(cost[raw])
			account["spent"] = float(account["spent"]) + float(cost[raw])
			_entry(c, team, "treasury", "monde", float(cost[raw]), "station de commandement " + payer)
		else:
			depot[raw] = float(depot[raw]) - float(cost[raw])
	stations.append({"id": next_station, "team": team, "body": body, "hp": J13Rules.STATION_HP, "remaining": J13Rules.STATION_TICKS})
	next_station += 1
	c._notice(team, "Station de commandement orbitale en assemblage", body)
	return {"ok": true, "created_ids": [next_station - 1], "eta": J13Rules.STATION_TICKS}

func _step_stations(c: StarCampaign) -> void:
	for station in stations:
		if int(station["remaining"]) > 0:
			station["remaining"] = int(station["remaining"]) - 1
			if int(station["remaining"]) == 0:
				c._notice(int(station["team"]), "Station de commandement orbitale opérationnelle", String(station["body"]))

func orbital_assault(c: StarCampaign, attacker: int, body: String, strength: int) -> Dictionary:
	## Une vague attaque UNE station : les stations supplémentaires d'abord, le chantier naval en dernier.
	## Résolution canonique unique, identique dans toutes les vues.
	var defender: int = hostile_owner(c, attacker, body)
	var hub: Dictionary = OrbitalIndustry.site(c, defender, body)
	var battery: int = int((hub.get("modules", {}) as Dictionary).get("batterie", 0)) if OrbitalIndustry.has_hub(c, defender, body) else 0
	var damage: float = float(strength) * 9.0 / (1.0 + float(battery) * 0.2)
	var target: Dictionary = {}
	for station in stations:
		if int(station["team"]) == defender and String(station["body"]) == body and int(station["remaining"]) == 0:
			if target.is_empty() or int(station["id"]) < int(target["id"]):
				target = station
	var destroyed: bool = false
	if not target.is_empty():
		target["hp"] = maxf(0.0, float(target["hp"]) - damage)
		if float(target["hp"]) <= 0.0:
			stations.erase(target)
			destroyed = true
	elif OrbitalIndustry.has_hub(c, defender, body):
		hub["hp"] = maxf(0.0, float(hub["hp"]) - damage)
		if float(hub["hp"]) <= 0.0:
			c.orbital_sites.erase(OrbitalIndustry.key(defender, body))
			destroyed = true
	var left: int = station_count(c, defender, body)
	if destroyed:
		c._notice(defender, "Station de commandement orbitale détruite", body)
		c._notice(attacker, "Station ennemie détruite · %s" % ("débarquement ouvert" if left == 0 else "%d station(s) restante(s) : invasion toujours bloquée" % left), body)
	else:
		c._notice(defender, "Station orbitale endommagée par une escadre ennemie", body)
	return {"destroyed": destroyed, "remaining": left}

func attack_station(c: StarCampaign, team: int, body: String) -> Dictionary:
	if c.orbital_tactics:
		OrbitalTactics.reconcile(c)
		var state: Dictionary = OrbitalTactics.map_for(c,body)
		var ids: Array = []
		var target: int = -1
		for actor in state["actors"].values():
			if int(actor["team"])==team and String(actor["role"])=="unit" and float(OrbitalTactics.SPECS[actor["type"]]["damage"])>0: ids.append(int(actor["id"]))
			if String(actor["role"]) in ["hub","command"] and c.factions.hostile(team,int(actor["team"])) and OrbitalTactics.visible(c,body,team,actor): target=int(actor["id"])
		if ids.is_empty() or target<0: return fail("orbit","flotte armée et station ennemie visible requises sur la carte orbitale")
		var result: Dictionary=c.issue_orbit({"team":team,"body":body,"action":"attack","units":ids,"target":target})
		result["destroyed"]=false
		result["pending"]=true
		return result
	## Escadre déjà en orbite : nouvel assaut contre la station suivante.
	if not c.valid_faction(team) or bool(c.eliminated[team]):
		return fail("invalid", "camp indisponible")
	if station_count(c, hostile_owner(c, team, body), body) == 0:
		return fail("target", "aucune station ennemie opérationnelle ici")
	var fleet: Dictionary = OrbitalIndustry.presence(c, team, body)
	var strength: int = int(fleet.get("intercepteur", 0)) * 30 + int(fleet.get("fregate", 0)) * 65
	if strength <= 0:
		return fail("fleet", "intercepteurs ou frégates requis en orbite")
	var result: Dictionary = orbital_assault(c, team, body, strength)
	if not bool(result["destroyed"]):
		fleet["intercepteur"] = 0
		fleet["fregate"] = 0
		c._notice(team, "Escadre perdue après l'assaut de la station ennemie", body)
	result["ok"] = true
	return result

func ai_orbital(c: StarCampaign, team: int) -> String:
	## IA stratégique : face à un verrou orbital, elle assiège la station par les mêmes commandes
	## et les mêmes coûts que le joueur (hangar, intercepteurs, escadre, assaut). Jamais de débarquement caché.
	## Elle ne vise que des mondes qu'elle connaît. Renvoie l'action entreprise (journal de recette).
	var targets: Array = []
	for raw in c.sector_keys():
		var body: String = String(raw)
		if c.is_unlocked(team, body) and landing_blocked(c, team, body) > 0:
			targets.append(body)
	if targets.is_empty():
		return ""
	targets.sort()
	for body in targets:
		var fleet: Dictionary = OrbitalIndustry.presence(c, team, String(body))
		if int(fleet.get("intercepteur", 0)) + int(fleet.get("fregate", 0)) >= 6:
			if bool(attack_station(c, team, String(body)).get("ok", false)):
				return "assaut:" + String(body)
	var hubs: Array = []
	for raw in c.sector_keys():
		if OrbitalIndustry.has_hub(c, team, String(raw)):
			hubs.append(String(raw))
	hubs.sort()
	for hub in hubs:
		var garrison: Dictionary = OrbitalIndustry.presence(c, team, String(hub))
		var armed: int = int(garrison.get("intercepteur", 0))
		var need_frigate: bool = false
		if armed >= 6:
			for body in targets:
				var manifest: Dictionary = {"intercepteur": mini(armed, 11)}
				if c._system_of(String(hub)) != c._system_of(String(body)):
					# Une escadre ne change de système qu'avec une frégate réelle.
					if int(garrison.get("fregate", 0)) < 1:
						need_frigate = true
						continue
					manifest["fregate"] = 1
				if bool(OrbitalIndustry.send_fleet(c, team, String(hub), String(body), manifest).get("ok", false)):
					return "escadre:" + String(body)
		var site: Dictionary = OrbitalIndustry.site(c, team, String(hub))
		var module: String = "arsenal" if need_frigate else "hangar"
		var ship: String = "fregate" if need_frigate else "intercepteur"
		if int((site["modules"] as Dictionary).get(module, 0)) < 1:
			if bool(OrbitalIndustry.start(c, team, String(hub), "module", module).get("ok", false)):
				return module + ":" + String(hub)
		elif bool(OrbitalIndustry.start(c, team, String(hub), "unit", ship).get("ok", false)):
			return ship + ":" + String(hub)
		elif bool(OrbitalIndustry.start(c, team, String(hub), "module", "habitat").get("ok", false)):
			return "habitat:" + String(hub)
	return ""

func has_command(c: StarCampaign, team: int) -> bool:
	for station in stations:
		if int(station["team"]) == team and int(station["remaining"]) == 0:
			return true
	return false

func assembling(team: int) -> bool:
	for station in stations:
		if int(station["team"]) == team and int(station["remaining"]) > 0:
			return true
	return false

# ------------------------------------------------------------------ transports auditables
func send_transport(c: StarCampaign, team: int, origin: String, destination: String, manifest: Dictionary) -> Dictionary:
	## Colons et fret : réservés puis retirés du départ, livrés UNE fois à l'arrivée.
	## manifest = {"colonists": int, "goods": {nom: int}, "found": bool}
	var refusal: String = _guard(c, team, origin)
	if not refusal.is_empty():
		return fail("colony", refusal)
	if transports.size() >= J13Rules.TRANSPORT_LIMIT:
		return fail("limit", "limite de transports atteinte")
	if origin == destination or not c.star_catalog.has_body(destination) or not c.is_unlocked(team, destination):
		return fail("destination", "destination distincte, connue et accessible requise")
	var duration: int = StarCampaign.expected_flight_duration(c.star_catalog, origin, destination)
	var same_system: bool = c._system_of(origin) == c._system_of(destination)
	if duration < 1 or (not same_system and int(c.ages[team]) < 10):
		return fail("route", "âge X ou route stellaire directe requis")
	var founding: bool = bool(manifest.get("found", false))
	var colonists_value: Variant = manifest.get("colonists", 0)
	var goods_value: Variant = manifest.get("goods", {})
	if not colonists_value is int or not goods_value is Dictionary:
		return fail("invalid", "manifeste invalide")
	var colonists: int = int(colonists_value)
	var goods: Dictionary = {}
	var load: int = 0
	for raw in (goods_value as Dictionary).keys():
		var kind: String = String(raw)
		var amount: Variant = (goods_value as Dictionary)[raw]
		if not (J13Rules.GOODS.has(kind) or Rules.RESOURCES.has(kind)) or not amount is int or int(amount) < 1:
			return fail("invalid", "marchandise ou quantité invalide")
		if Rules.RESOURCES.has(kind) and same_system and not c.evolutions_enabled:
			return fail("depot", "vivres, bois et minerai sont déjà dans le dépôt commun de ce système")
		goods[kind] = int(amount)
		load += int(amount)
	if colonists < 0 or colonists > J13Rules.TRANSPORT_SEATS or load > J13Rules.TRANSPORT_HOLD or (colonists == 0 and load == 0):
		return fail("capacity", "capacité : %d passagers et %d unités de fret" % [J13Rules.TRANSPORT_SEATS, J13Rules.TRANSPORT_HOLD])
	var p: Dictionary = colony(team, origin)
	if colonists > int(p["pop"]):
		return fail("colonists", "population insuffisante au départ")
	if founding:
		if has_colony(team, destination) or colonists < J13Rules.COLONY_COLONISTS:
			return fail("found", "fondation : %d colons vers un monde sans colonie du camp" % J13Rules.COLONY_COLONISTS)
	elif not has_colony(team, destination) or String(colony(team, destination)["status"]) == "lost":
		return fail("destination", "aucune colonie d'accueil : cocher la fondation")
	var block: String = lock_text(c, team, destination)
	if not block.is_empty():
		return fail("orbital_lock", block)
	# Porteur : une navette réelle en orbite, sinon un lancement payant depuis un port au sol.
	var cost: Dictionary = goods.duplicate(true)
	var carrier: String = ""
	if OrbitalIndustry.has_hub(c, team, origin) and int(OrbitalIndustry.presence(c, team, origin).get("navette", 0)) > 0:
		carrier = "navette"
	else:
		var port: bool = false
		if c.worlds.has(origin):
			for b in (c.worlds[origin] as SimWorld).team_buildings(team, "", true):
				if b.type in ["spatioport", "chantier_orbital"]:
					port = true
		if not port:
			return fail("carrier", "navette en orbite ou spatioport au sol requis")
		carrier = "lancement"
		for raw in J13Rules.SURFACE_LAUNCH_COST.keys():
			cost[raw] = int(cost.get(raw, 0)) + int(J13Rules.SURFACE_LAUNCH_COST[raw])
	if founding:
		for raw in StarCampaign.COLONY_COST.keys():
			cost[raw] = int(cost.get(raw, 0)) + int(StarCampaign.COLONY_COST[raw])
	var lack: String = missing(c, team, origin, cost)
	if not lack.is_empty():
		return fail("cost", "manque au départ : " + lack)
	# Tous les contrôles précèdent le premier retrait : un refus n'a aucun effet.
	_charge(c, team, origin, cost, "transport")
	p["pop"] = int(p["pop"]) - colonists
	if carrier == "navette":
		var fleet: Dictionary = OrbitalIndustry.presence(c, team, origin)
		fleet["navette"] = int(fleet["navette"]) - 1
	var mission: Dictionary = {"id": next_transport, "owner": team, "origin": origin, "destination": destination,
		"cargo": goods, "passengers": colonists, "found": founding, "carrier": carrier,
		"reserved_capacity": {"seats": J13Rules.TRANSPORT_SEATS, "hold": J13Rules.TRANSPORT_HOLD},
		"route": [origin, destination], "state": "en_route", "departure_tick": c.tick,
		"arrival_tick": c.tick + duration, "eta": duration, "failure_reason": "", "delivered_once": false}
	transports.append(mission)
	next_transport += 1
	c._notice(team, "Transport n°%d : %s → %s (%d colons, %d fret)" % [int(mission["id"]), origin, destination, colonists, load], origin)
	return {"ok": true, "created_ids": [int(mission["id"])], "eta": duration}

func destroy_transport(c: StarCampaign, id: int, reason: String) -> bool:
	## Perte explicite (interception, accident) : passagers et fret perdus, jamais livrés ensuite.
	for mission in transports:
		if int(mission["id"]) == id:
			mission["state"] = "lost"
			mission["failure_reason"] = reason
			_archive(mission)
			c._notice(int(mission["owner"]), "Transport n°%d perdu : %s" % [id, reason], String(mission["origin"]))
			return true
	return false

func _archive(mission: Dictionary) -> void:
	transports.erase(mission)
	transport_log.append(mission)
	if transport_log.size() > 40:
		transport_log.pop_front()

func _step_transports(c: StarCampaign) -> void:
	for mission in transports.duplicate():
		if int(mission["eta"]) > 0:
			mission["eta"] = int(mission["eta"]) - 1
			if int(mission["eta"]) > 0:
				continue
		var team: int = int(mission["owner"])
		var returning: bool = String(mission["state"]) == "returning"
		var target: String = String(mission["origin"]) if returning else String(mission["destination"])
		if not returning:
			var block: String = lock_text(c, team, target)
			if c.evolutions_enabled and not TreatyService.can_land(c, team, target): block = "accès diplomatique non accordé"
			if not block.is_empty():
				_hold(c, mission, block)
				continue
			if bool(mission["found"]) and not has_colony(team, target):
				if not _found_on_arrival(c, team, target):
					_hold(c, mission, "site de fondation indisponible")
					continue
				mission["passengers_landed"] = true
				colony(team, target)["pop"] = int(mission["passengers"])
			elif not has_colony(team, target) or String(colony(team, target)["status"]) == "lost":
				# Colonie d'accueil disparue : retour sécurisé, aucune perte ni duplication.
				mission["state"] = "returning"
				mission["failure_reason"] = "colonie d'accueil perdue"
				mission["eta"] = maxi(1, StarCampaign.expected_flight_duration(c.star_catalog, String(mission["destination"]), String(mission["origin"])))
				c._notice(team, "Transport n°%d : retour, colonie d'accueil perdue" % int(mission["id"]), target)
				continue
		if bool(mission["delivered_once"]):
			continue
		mission["delivered_once"] = true
		var p: Dictionary = colony(team, target)
		if not p.is_empty():
			if not bool(mission.get("passengers_landed", false)):
				p["pop"] = int(p["pop"]) + int(mission["passengers"])
			var depot: Dictionary = _depot(c, team, target)
			for raw in (mission["cargo"] as Dictionary).keys():
				if Rules.RESOURCES.has(String(raw)):
					depot[raw] = float(depot.get(raw, 0.0)) + float(mission["cargo"][raw])
				else:
					(p["stocks"] as Dictionary)[raw] = float((p["stocks"] as Dictionary)[raw]) + float(mission["cargo"][raw])
		if String(mission["carrier"]) == "navette":
			var fleet: Dictionary = OrbitalIndustry.presence(c, team, target)
			fleet["navette"] = int(fleet.get("navette", 0)) + 1
		mission["state"] = "returned" if returning else "delivered"
		_archive(mission)
		c._notice(team, "Transport n°%d %s : %s" % [int(mission["id"]), "revenu" if returning else "livré", String(c.info(target).get("label", target))], target)

func _hold(c: StarCampaign, mission: Dictionary, reason: String) -> void:
	if String(mission["state"]) != "holding" or String(mission["failure_reason"]) != reason:
		c._notice(int(mission["owner"]), "Transport n°%d en attente en orbite : %s" % [int(mission["id"]), reason], String(mission["destination"]))
	mission["state"] = "holding"
	mission["failure_reason"] = reason

func _found_on_arrival(c: StarCampaign, team: int, body: String) -> bool:
	var w: SimWorld = c.materialize(body)
	if w == null:
		return false
	if w.team_buildings(team, "centre", true).is_empty():
		var site: Vector2i = c._landing_cell(w, team)
		if site.x < 0:
			return false
		w.spawn_building(team, "centre", site, true)
		w.update_fog(true)
	var origin: String = "conquered" if has_hostile_colony(c, team, body) else "colony"
	found(c, team, body, origin, 0)
	c._notice(team, "Colonie fondée sur %s · âge local %s" % [String(c.info(body).get("label", body)), J13Rules.roman(local_age(c, team, body))], body)
	return true

# ------------------------------------------------------------------ lecture pour les vues
func summary(c: StarCampaign, team: int, body: String) -> Dictionary:
	## Modèle de lecture seule pour le HUD : aucune vue ne modifie l'état directement.
	var p: Dictionary = colony(team, body)
	if p.is_empty():
		return {}
	var out: Dictionary = (p["stats"] as Dictionary).duplicate(true)
	out["local_age"] = local_age(c, team, body)
	out["empire_age"] = int(c.ages[team])
	out["pop"] = int(p["pop"])
	out["reserve"] = float(p["reserve"])
	out["credits"] = credits(team)
	out["target"] = (p["target"] as Dictionary).duplicate(true)
	out["governor"] = (p["governor"] as Dictionary).duplicate(true)
	out["stocks"] = (p["stocks"] as Dictionary).duplicate(true)
	out["status"] = String(p["status"])
	out["origin"] = String(p["origin"])
	out["research"] = (p["research"] as Dictionary).duplicate(true)
	out["stations"] = station_count(c, team, body)
	out["enemy_stations"] = station_count(c, hostile_owner(c, team, body), body)
	out["lock"] = lock_text(c, team, body)
	return out

func hash_text() -> String:
	return var_to_str([colonies, treasury, stations, next_station, transports, next_transport, supply_chain])

func hostile_owner(c: StarCampaign, team: int, body: String) -> int:
	for enemy in c.factions.enemies(team):
		if station_count(c, int(enemy), body) > 0 or has_colony(int(enemy), body): return int(enemy)
	return 1 - team if not c.evolutions_enabled and team in [0, 1] else -1

func has_hostile_colony(c: StarCampaign, team: int, body: String) -> bool:
	for enemy in c.factions.enemies(team):
		if has_colony(int(enemy), body): return true
	return false
