class_name J13Save
extends RefCounted
## J13 : bloc « j13 » de la sauvegarde de campagne + migration 0.12.3.
## Un bloc absent = ancienne partie : états hérités créés UNE fois, trésorerie 0,
## aucune station ni ressource ajoutée. Un bloc falsifié fait refuser tout le fichier.

static func write(c: StarCampaign, out: Dictionary) -> void:
	var pc: PlanetCampaign = c.planets
	out["j13"] = {"schema": J13Rules.SCHEMA, "colonies": pc.colonies, "treasury": pc.treasury,
		"ledger": pc.ledger, "stations": pc.stations, "next_station": pc.next_station,
		"transports": pc.transports, "transport_log": pc.transport_log,
		"next_transport": pc.next_transport, "migrated_from": pc.migrated_from,
		"supply_chain": pc.supply_chain}

static func read(c: StarCampaign, data: Dictionary) -> bool:
	var pc := PlanetCampaign.new()
	c.planets = pc
	if not data.has("j13"):
		pc.bootstrap(c, false)
		pc.migrated_from = "0.12.3"
		return true
	var raw: Variant = data["j13"]
	if not raw is Dictionary or not _valid(c.star_catalog, raw as Dictionary):
		return false
	var block: Dictionary = (raw as Dictionary).duplicate(true)
	pc.colonies = block["colonies"]
	pc.treasury = block["treasury"]
	pc.ledger = block["ledger"]
	pc.stations = block["stations"]
	pc.next_station = int(block["next_station"])
	pc.transports = block["transports"]
	pc.transport_log = block["transport_log"]
	pc.next_transport = int(block["next_transport"])
	pc.migrated_from = String(block.get("migrated_from", ""))
	pc.supply_chain = bool(block.get("supply_chain", false))
	return pc.books_balanced(0) and pc.books_balanced(1)

static func _num(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _whole(value: Variant, low: int, high: int) -> bool:
	return value is int and int(value) >= low and int(value) <= high

static func _valid(catalog: StarSystemGenerator, block: Dictionary) -> bool:
	if not _whole(block.get("schema"), J13Rules.SCHEMA, J13Rules.SCHEMA):
		return false
	if block.has("supply_chain") and not block["supply_chain"] is bool:
		return false
	for field in ["colonies"]:
		if not block.get(field) is Dictionary:
			return false
	for field in ["treasury", "ledger", "stations", "transports", "transport_log"]:
		if not block.get(field) is Array:
			return false
	var count: int = J13Rules.GRID_W * J13Rules.GRID_H
	var colonies: Dictionary = block["colonies"] as Dictionary
	if colonies.size() > 2 * StarSystemGenerator.MAX_BODIES:
		return false
	for id in colonies.keys():
		var value: Variant = colonies[id]
		if not id is String or not value is Dictionary:
			return false
		var p: Dictionary = value as Dictionary
		if not _whole(p.get("team"), 0, 1) or not p.get("body") is String or not catalog.has_body(String(p["body"])):
			return false
		if PlanetCampaign.key(int(p["team"]), String(p["body"])) != id:
			return false
		if not _whole(p.get("local_age"), 1, 10) or not _whole(p.get("hq"), 0, count - 1) or not _whole(p.get("pop"), 0, 10000000):
			return false
		if not _whole(p.get("founded_tick"), 0, 2000000000) or not p.get("tracks_empire") is bool:
			return false
		if String(p.get("origin", "")) not in ["home", "legacy", "colony", "conquered"] or String(p.get("status", "")) not in ["integrated", "occupied", "lost"]:
			return false
		if not _num(p.get("reserve"), 0.0, 1.0e9):
			return false
		for field in ["cells", "stocks", "target", "governor", "research", "stats"]:
			if not p.get(field) is Dictionary:
				return false
		if not p.get("reserved") is Array or (p["reserved"] as Array).size() > count:
			return false
		for item in p["reserved"]:
			if not _whole(item, 0, count - 1):
				return false
		var cells: Dictionary = p["cells"] as Dictionary
		if cells.size() > count or not cells.has(p["hq"]):
			return false
		for cell_id in cells.keys():
			var cell_value: Variant = cells[cell_id]
			if not _whole(cell_id, 0, count - 1) or not cell_value is Dictionary:
				return false
			var cell: Dictionary = cell_value as Dictionary
			if String(cell.get("zone", "?")) not in ["", "R", "C", "I"] or not _whole(cell.get("density"), 0, 3):
				return false
			var facility: String = String(cell.get("facility", "?"))
			if facility not in ["", "hq"] and not J13Rules.FACILITIES.has(facility):
				return false
			var recipe: String = String(cell.get("recipe", "?"))
			if not recipe.is_empty() and not J13Rules.RECIPES.has(recipe):
				return false
			if not cell.get("road") is bool or not cell.get("cut") is bool or not cell.get("manual") is bool or not cell.get("halt") is String:
				return false
		var stocks: Dictionary = p["stocks"] as Dictionary
		if stocks.size() != J13Rules.GOODS.size():
			return false
		for good in J13Rules.GOODS:
			if not _num(stocks.get(good), 0.0, 1.0e7):
				return false
		var target: Dictionary = p["target"] as Dictionary
		var total: float = 0.0
		for zone in J13Rules.ZONES:
			if not _num(target.get(zone), J13Rules.TARGET_MIN, J13Rules.TARGET_MAX):
				return false
			total += float(target[zone])
		if absf(total - 1.0) > 0.001:
			return false
		var gov: Dictionary = p["governor"] as Dictionary
		for field in ["enabled", "granted", "suspended"]:
			if not gov.get(field) is bool:
				return false
		if not _num(gov.get("budget_cap"), 0.0, 1000000.0) or not gov.get("status") is String or not gov.get("journal") is Array:
			return false
		if (gov["journal"] as Array).size() > J13Rules.JOURNAL_KEEP:
			return false
		var research: Dictionary = p["research"] as Dictionary
		if not research.is_empty() and (not _whole(research.get("target"), 8, 10) or not _whole(research.get("remaining"), -40, 600)):
			return false
	var treasury: Array = block["treasury"] as Array
	if treasury.size() != 2:
		return false
	for account in treasury:
		if not account is Dictionary:
			return false
		for field in ["credits", "minted", "spent"]:
			if not _num((account as Dictionary).get(field), 0.0, 1.0e12):
				return false
		if not _whole((account as Dictionary).get("seq"), 0, 2000000000):
			return false
	if (block["ledger"] as Array).size() > J13Rules.LEDGER_KEEP or (block["transport_log"] as Array).size() > 40:
		return false
	for entry in block["ledger"]:
		if not entry is Dictionary or not _num((entry as Dictionary).get("amount"), 0.0, 1.0e12):
			return false
	var station_ids: Dictionary = {}
	if (block["stations"] as Array).size() > 4 * StarSystemGenerator.MAX_BODIES:
		return false
	for value in block["stations"]:
		if not value is Dictionary:
			return false
		var station: Dictionary = value as Dictionary
		if not _whole(station.get("id"), 1, 2000000000) or station_ids.has(station["id"]) or not _whole(station.get("team"), 0, 1):
			return false
		station_ids[station["id"]] = true
		if not station.get("body") is String or not catalog.has_body(String(station["body"])):
			return false
		if not _num(station.get("hp"), 0.001, J13Rules.STATION_HP) or not _whole(station.get("remaining"), 0, J13Rules.STATION_TICKS):
			return false
	if not _whole(block.get("next_station"), 1, 2000000000) or (not station_ids.is_empty() and int(block["next_station"]) <= int((station_ids.keys() as Array).max())):
		return false
	var transport_ids: Dictionary = {}
	if (block["transports"] as Array).size() > J13Rules.TRANSPORT_LIMIT:
		return false
	for group in [block["transports"], block["transport_log"]]:
		for value in group:
			if not value is Dictionary:
				return false
			var mission: Dictionary = value as Dictionary
			if not _whole(mission.get("id"), 1, 2000000000) or transport_ids.has(mission["id"]) or not _whole(mission.get("owner"), 0, 1):
				return false
			transport_ids[mission["id"]] = true
			for field in ["origin", "destination"]:
				if not mission.get(field) is String or not catalog.has_body(String(mission[field])):
					return false
			if String(mission["origin"]) == String(mission["destination"]):
				return false
			if not _whole(mission.get("passengers"), 0, J13Rules.TRANSPORT_SEATS) or not _whole(mission.get("eta"), 0, 100000):
				return false
			if String(mission.get("state", "")) not in ["en_route", "holding", "returning", "delivered", "returned", "lost"]:
				return false
			if String(mission.get("carrier", "")) not in ["navette", "lancement"]:
				return false
			if not mission.get("delivered_once") is bool or not mission.get("found") is bool or not mission.get("cargo") is Dictionary or not mission.get("failure_reason") is String:
				return false
			var load: int = 0
			for kind in (mission["cargo"] as Dictionary).keys():
				if not (J13Rules.GOODS.has(kind) or Rules.RESOURCES.has(kind)) or not _whole(mission["cargo"][kind], 1, J13Rules.TRANSPORT_HOLD):
					return false
				load += int(mission["cargo"][kind])
			if load > J13Rules.TRANSPORT_HOLD:
				return false
	for value in block["transports"]:
		# Un transport encore actif n'a jamais déjà livré : pas de seconde arrivée après reprise.
		if bool((value as Dictionary)["delivered_once"]) or String((value as Dictionary)["state"]) in ["delivered", "returned", "lost"]:
			return false
	if not _whole(block.get("next_transport"), 1, 2000000000) or (not transport_ids.is_empty() and int(block["next_transport"]) <= int((transport_ids.keys() as Array).max())):
		return false
	return true
