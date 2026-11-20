class_name UrbanCity
extends RefCounted
## 0.18 — Ville de l'âge de l'électricité, au pas fixe de la simulation (toutes les UrbanRules.PERIOD ticks).
## Active après la recherche « Électricité », dans les parties avec l'évolution de la civilisation (ou la règle de
## laboratoire "urban"). Remplacement net : fermes, maisons et récolte s'arrêtent ; seules les zones produisent.
## État par bâtiment dans Building.city, par camp dans Team.city (sauvegardés avec la partie).
## Tirages déterministes par hachage (graine, pas, bâtiment) : aucun autre tirage de la partie n'est déplacé.

const ZONE_KEYS := ["police", "fire", "health", "waste"]

# ---------------------------------------------------------------- état et accès

static func enabled(w: SimWorld) -> bool:
	return w != null and (CivEvolution.enabled(w) or bool(w.rules.get("urban", false)))

static func active(w: SimWorld, team: int) -> bool:
	if not enabled(w) or team < 0 or team >= w.teams.size() or team == SimWorld.TEAM_NEUTRAL:
		return false
	return (w.teams[team] as SimWorld.Team).technologies.has(UrbanRules.TECH)

static func replaces_gathering(w: SimWorld, team: int) -> bool:
	return active(w, team)

const NEEDS_TECH := ["centrale", "centrale_solaire", "poste_electrique", "chateau_eau", "station_pompage"]

static func visible_building(w: SimWorld, team: int, kind: String) -> bool:
	if Rules.BUILDINGS.has(kind) and bool((Rules.BUILDINGS[kind] as Dictionary).get("zoned", false)):
		return false
	if UrbanRules.REPLACED.has(kind):
		return not active(w, team)
	if UrbanRules.is_urban(kind):
		return enabled(w) and (active(w, team) or not NEEDS_TECH.has(kind))
	return true

static func build_lack(w: SimWorld, team: int, kind: String, cell: Vector2i) -> String:
	if Rules.BUILDINGS.has(kind) and bool((Rules.BUILDINGS[kind] as Dictionary).get("zoned", false)):
		return "se développe seul sur les zones peintes (mode Zonage)" if kind != "ruine" else "ne se construit pas"
	if UrbanRules.REPLACED.has(kind) and active(w, team):
		return "remplacé par la ville (recherche Électricité)"
	if not UrbanRules.is_urban(kind):
		return ""
	if not enabled(w):
		return "réservé aux parties avec l'évolution de la civilisation"
	if NEEDS_TECH.has(kind) and not active(w, team):
		return "recherche Électricité requise (usine)"
	var near: int = int((UrbanRules.WATER_SOURCES.get(kind, {}) as Dictionary).get("near_water", 0))
	if near > 0 and not _near_water(w, cell, int(Rules.BUILDINGS[kind]["size"]), near):
		return "une station de pompage se bâtit à moins de %d cases de l'eau" % near
	return ""

static func tech_lack(w: SimWorld, key: String) -> String:
	if Rules.TECHNOLOGIES.has(key) and bool((Rules.TECHNOLOGIES[key] as Dictionary).get("civ", false)) and not enabled(w):
		return "réservé aux parties avec l'évolution de la civilisation"
	return ""

static func team_city(w: SimWorld, team: int) -> Dictionary:
	return (w.teams[team] as SimWorld.Team).city

static func _near_water(w: SimWorld, cell: Vector2i, size: int, reach: int) -> bool:
	for dy in range(-reach, size + reach):
		for dx in range(-reach, size + reach):
			var c: Vector2i = cell + Vector2i(dx, dy)
			if w.in_map(c) and w.terrain[w.idx(c)] == SimWorld.TERRAIN_WATER:
				return true
	return false

static func roll(w: SimWorld, id: int, salt: int) -> float:
	var h: int = hash([w.seed_value, w.tick, id, salt])
	return float(h & 0x7fffffff) / 2147483648.0

# ---------------------------------------------------------------- commandes

static func handles(kind: String) -> bool:
	return kind.begins_with("urban_") or UrbanZoning.handles(kind)

static func command(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	if UrbanZoning.handles(String(cmd.get("t", ""))):
		return UrbanZoning.command(w, team, cmd)
	if String(cmd.get("t", "")) != "urban_upgrade":
		return w._no("commande de ville inconnue")
	var b: SimWorld.Building = w.buildings.get(int(cmd.get("building", -1))) as SimWorld.Building
	var why: String = upgrade_lack(w, team, b)
	if why != "":
		return w._no(why)
	var level: int = int(b.city.get("level", 1))
	w._pay(team, w.scaled_cost(UrbanRules.UPGRADE_COST[level + 1]))
	b.city["level"] = level + 1
	if not bool(b.city.get("historic", false)):
		b.city["style_age"] = clampi((w.teams[team] as SimWorld.Team).age, 1, 10)
	w.emit("ville", team, "%s : niveau %s (%s)" % [String(Rules.BUILDINGS[b.type]["label"]), UrbanRules.roman(level + 1), UrbanRules.level_name(b.type, level + 1)], {"building": b.id, "pos": b.center})
	return w._ok()

static func upgrade_lack(w: SimWorld, team: int, b: SimWorld.Building) -> String:
	if b == null or b.team != team:
		return "zone alliée requise"
	if not UrbanRules.is_zone(b.type):
		return "seules les zones s'améliorent"
	if not enabled(w):
		return "réservé aux parties avec l'évolution de la civilisation"
	if not b.complete:
		return "zone en construction"
	if float(b.city.get("works", 0.0)) > 0.0:
		return "travaux déjà en cours"
	var level: int = int(b.city.get("level", 1))
	if level >= UrbanGrowth.level_cap(w, team, b):
		return "niveau maximal pour ce zonage et cet âge"
	var cost: Dictionary = w.scaled_cost(UrbanRules.UPGRADE_COST[level + 1])
	if not w._can_pay(team, cost):
		return w._missing_text(team, cost)
	return ""

static func upgrade_cost(w: SimWorld, b: SimWorld.Building) -> Dictionary:
	var level: int = int(b.city.get("level", 1))
	if level >= UrbanRules.kind_max(b.type):
		return {}
	return w.scaled_cost(UrbanRules.UPGRADE_COST[level + 1])

# ---------------------------------------------------------------- ouvriers (remplacement de la récolte)

static func stop_gather(w: SimWorld, u: SimWorld.Unit) -> bool:
	## Vrai si l'ouvrier est arrêté ; faux tant qu'il rapporte sa charge au dépôt.
	if u.carry_amt > 0.0:
		u.state = "to_drop"
		return false
	w._release_worker_job(u)
	u.task = ""
	u.state = "idle"
	u.blocked_reason = "récolte remplacée par la ville"
	return true

static func ready_for_switch(w: SimWorld, team: int) -> bool:
	## IA : ne lance la recherche que si le stock permet ensuite d'amorcer la ville (même règle pour tous, simple prudence).
	var t: SimWorld.Team = w.teams[team]
	var cost: Dictionary = w.scaled_cost((Rules.TECHNOLOGIES[UrbanRules.TECH] as Dictionary)["cost"])
	return float(t.res["wood"]) >= float(cost.get("wood", 0)) + 300.0 and float(t.res["ore"]) >= float(cost.get("ore", 0)) + 300.0

# ---------------------------------------------------------------- pas de simulation

## 0.20 — Échelle de temps du calcul en cours : 1 pour une ville détaillée, UrbanRules.FAR_EVERY pour une ville
## lointaine calculée moins souvent (mêmes règles, durées et probabilités ajustées : simulation abrégée).
static var time_scale: float = 1.0

static func period_s() -> float:
	return UrbanRules.PERIOD_S * time_scale

static func prob_scaled(p: float) -> float:
	## Probabilité par calcul : une chance p toutes les 2 s devient la chance d'au moins un tirage sur la durée couverte.
	var q: float = clampf(p, 0.0, 1.0)
	return q if time_scale <= 1.0 else 1.0 - pow(1.0 - q, time_scale)

static func ease_scaled(k: float) -> float:
	## Rapprochement d'une valeur vers sa cible (fraction par calcul), cumulé sur la durée couverte.
	return prob_scaled(k)

static func slot_of(w: SimWorld, team: int) -> int:
	## Tick de la période où le camp est calculé : les camps (et les mondes, par urban_phase) sont décalés pour que
	## les calculs ne tombent pas tous sur le même tick (pas de saccade cumulée).
	return 7 + w.urban_phase + (UrbanRules.TEAM_OFFSET if team % 2 == 1 else 0)

static func step(w: SimWorld) -> void:
	if not enabled(w):
		return
	var phase: int = posmod(w.tick, UrbanRules.PERIOD)
	if phase != 7 + w.urban_phase and phase != 7 + w.urban_phase + UrbanRules.TEAM_OFFSET:
		return
	# Monde lointain (hors de l'écran du joueur) : calcul abrégé une période sur FAR_EVERY.
	if w.urban_far and posmod(floori(float(w.tick) / float(UrbanRules.PERIOD)), UrbanRules.FAR_EVERY) != 0:
		return
	time_scale = float(UrbanRules.FAR_EVERY) if w.urban_far else 1.0
	UrbanZoning.road_layer(w)
	for actor in w.faction_ids():
		var team: int = int(actor)
		if team < 0 or team >= w.teams.size() or team == SimWorld.TEAM_NEUTRAL or slot_of(w, team) != phase:
			continue
		var t: SimWorld.Team = w.teams[team]
		if t.eliminated:
			continue
		if t.technologies.has(UrbanRules.TECH):
			if not bool(t.city.get("switched", false)):
				_switch(w, team)
		elif not _has_city(w, team):
			continue
		# 0.19 : la ville vit dès l'âge I dès qu'un camp a zoné ou bâti un bâtiment urbain (besoins d'époque).
		UrbanZoning.ensure(w, team)
		_update(w, team)
		UrbanEvents.step(w, team)
	time_scale = 1.0

static func _has_city(w: SimWorld, team: int) -> bool:
	if UrbanZoning.has_layers(w, team):
		return true
	for candidate in w.team_buildings(team):
		var kind: String = (candidate as SimWorld.Building).type
		if UrbanRules.is_urban(kind) or kind == "ruine":
			return true
	return false

static func _switch(w: SimWorld, team: int) -> void:
	var t: SimWorld.Team = w.teams[team]
	var houses: int = 0
	var farms: int = 0
	for b in _sorted(w.team_buildings(team)):
		if b.type == "maison":
			var ratio: float = b.hp / maxf(1.0, b.max_hp)
			if b.complete:
				t.pop_cap -= int(Rules.BUILDINGS["maison"].get("pop", 0))
			b.type = "zone_r"
			b.max_hp = float(Rules.BUILDINGS["zone_r"]["hp"])
			b.hp = maxf(1.0, b.max_hp * ratio)
			b.city = {"level": 1, "density": 1.0, "converted": true, "legacy": true, "zoned_once": true, "style_age": clampi(t.age, 1, 10)}
			var z: Dictionary = UrbanZoning.ensure(w, team)
			var zone: PackedByteArray = z["zone"]
			for dy in b.size:
				for dx in b.size:
					var c: Vector2i = b.cell + Vector2i(dx, dy)
					if w.in_map(c):
						zone[w.idx(c)] = 2
			z["zone"] = zone
			z["rev"] = int(z.get("rev", 0)) + 1
			houses += 1
		elif b.type == "ferme":
			b.farmer = -1
			b.city = {"retired": true}
			farms += 1
	t.city["switched"] = true
	t.city["switch_tick"] = w.tick
	w.emit("ville", team, "Électricité : la ville remplace fermes, maisons et récolte (%d maison(s) devenue(s) zones d'habitation)" % houses, {"houses": houses, "farms": farms})

static func _sorted(list: Array) -> Array:
	var out: Array = list.duplicate()
	out.sort_custom(func(a, b) -> bool: return int(a.id) < int(b.id))
	return out

static func _covers(nodes: Array, b: SimWorld.Building) -> bool:
	for n in nodes:
		var pair: Array = n as Array
		if (pair[0] as Vector2).distance_to(b.center) <= float(pair[1]) + float(b.size) * 0.5:
			return true
	return false

static func _priority(kind: String) -> int:
	var i: int = UrbanRules.PRIORITY.find(kind)
	return i if i >= 0 else UrbanRules.PRIORITY.size()

static func _need(b: SimWorld.Building, table: Dictionary) -> int:
	var base: int = int(table.get(b.type, 0))
	if UrbanRules.is_zone(b.type):
		return base * maxi(1, ceili(float(b.city.get("density", 1.0)) - 0.001))
	return base

static func _allocate(consumers: Array, nodes: Array, supply: int, table: Dictionary, flag: String) -> int:
	consumers.sort_custom(func(a, b) -> bool:
		var pa: int = _priority(a.type)
		var pb: int = _priority(b.type)
		return pa < pb or (pa == pb and int(a.id) < int(b.id)))
	var used: int = 0
	var demand: int = 0
	for c in consumers:
		var b: SimWorld.Building = c as SimWorld.Building
		var need: int = _need(b, table)
		demand += need
		var linked: bool = _covers(nodes, b)
		b.city[flag + "_grid"] = linked
		if linked and used + need <= supply:
			used += need
			b.city[flag] = true
		else:
			b.city[flag] = false
	return demand

static func _update(w: SimWorld, team: int) -> void:
	var t: SimWorld.Team = w.teams[team]
	var electric: bool = t.technologies.has(UrbanRules.TECH)
	var urban: Array = []
	var centres: Array = []
	var guards: Array = []
	for candidate in w.team_buildings(team):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if b.type == "centre" and b.complete:
			centres.append(b)
		elif UrbanRules.GUARD.has(b.type) and b.complete:
			guards.append(b)
		if UrbanRules.is_urban(b.type):
			urban.append(b)
	urban = _sorted(urban)
	centres = _sorted(centres)
	guards = _sorted(guards)
	var done: Array = []
	var counts: Dictionary = {}
	for candidate in urban:
		var b: SimWorld.Building = candidate as SimWorld.Building
		counts[b.type] = int(counts.get(b.type, 0)) + 1
		if not b.complete:
			continue
		if UrbanRules.is_zone(b.type) and not bool(b.city.get("ready", false)):
			b.city["level"] = maxi(1, int(b.city.get("level", 1)))
			b.city["density"] = 1.0 if bool(b.city.get("converted", false)) else UrbanRules.START_DENSITY
			b.city["ready"] = true
			b.city["crime"] = UrbanRules.CRIME_BASE
			b.city["health_v"] = 90.0
			b.city["happiness"] = 60.0
			b.city["wealth"] = 40.0
			if not b.city.has("style_age"):
				b.city["style_age"] = clampi(t.age, 1, 10)
			if not b.city.has("state"):
				b.city["state"] = "operational"
		done.append(b)

	# 1. Électricité (après la recherche) : sources, postes reliés en chaîne, délestage par priorité.
	var power_nodes: Array = []
	var power_supply: int = 0
	var power_consumers: Array = []
	var power_demand: int = 0
	if electric:
		for c in centres:
			var cb: SimWorld.Building = c as SimWorld.Building
			power_nodes.append([cb.center, float(UrbanRules.POWER_SOURCES["centre"]["reach"])])
			power_supply += int(UrbanRules.POWER_SOURCES["centre"]["power"])
		var relays: Array = []
		for candidate in done:
			var b: SimWorld.Building = candidate as SimWorld.Building
			if UrbanRules.POWER_SOURCES.has(b.type):
				power_nodes.append([b.center, float(UrbanRules.POWER_SOURCES[b.type]["reach"])])
				power_supply += int(UrbanRules.POWER_SOURCES[b.type]["power"])
				b.city["powered"] = true
			elif UrbanRules.RELAY.has(b.type):
				relays.append(b)
				b.city["powered"] = false
		var linked_any: bool = true
		while linked_any:
			linked_any = false
			for candidate in relays:
				var r: SimWorld.Building = candidate as SimWorld.Building
				if bool(r.city.get("powered", false)):
					continue
				if _covers(power_nodes, r):
					r.city["powered"] = true
					power_nodes.append([r.center, float(UrbanRules.RELAY[r.type])])
					linked_any = true
		for candidate in done:
			if UrbanRules.POWER_USE.has((candidate as SimWorld.Building).type):
				power_consumers.append(candidate)
		power_demand = _allocate(power_consumers, power_nodes, power_supply, UrbanRules.POWER_USE, "powered")
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not electric or not (UrbanRules.POWER_USE.has(b.type) or UrbanRules.POWER_SOURCES.has(b.type) or UrbanRules.RELAY.has(b.type)):
			b.city["powered"] = true
			b.city["powered_grid"] = true

	# 2. Eau : centre, puits (sans électricité) ; châteaux d'eau et stations de pompage ont besoin d'électricité.
	var water_nodes: Array = []
	var water_supply: int = 0
	for c in centres:
		var cb: SimWorld.Building = c as SimWorld.Building
		water_nodes.append([cb.center, float(UrbanRules.WATER_SOURCES["centre"]["reach"])])
		water_supply += int(UrbanRules.WATER_SOURCES["centre"]["water"])
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.WELL.has(b.type):
			water_nodes.append([b.center, float(UrbanRules.WELL[b.type]["reach"])])
			water_supply += int(UrbanRules.WELL[b.type]["water"])
		elif UrbanRules.WATER_SOURCES.has(b.type) and bool(b.city.get("powered", false)):
			water_nodes.append([b.center, float(UrbanRules.WATER_SOURCES[b.type]["reach"])])
			water_supply += int(UrbanRules.WATER_SOURCES[b.type]["water"])
	var water_consumers: Array = []
	for candidate in done:
		if UrbanRules.WATER_USE.has((candidate as SimWorld.Building).type):
			water_consumers.append(candidate)
	var water_demand: int = _allocate(water_consumers, water_nodes, water_supply, UrbanRules.WATER_USE, "watered")
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not UrbanRules.WATER_USE.has(b.type):
			b.city["watered"] = true

	# 3. Services : les plus proches d'abord, dans la limite de la capacité ; l'électricité est exigée après la recherche.
	# Avant les services modernes : la garde (casernes, forts) assure la sécurité, les puits luttent contre le feu.
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		for key in ZONE_KEYS:
			b.city[key] = false
		b.city["fire_station"] = false
		b.city["fire_well"] = false
		b.city["guard"] = false
		b.city["police_station"] = false
		b.city["waste_mult"] = 1.0
	var served_count: Dictionary = {}
	var providers: Array = []
	for candidate in done:
		var s: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.SERVICES.has(s.type) and (not electric or bool(s.city.get("powered", false))):
			var def: Dictionary = UrbanRules.SERVICES[s.type] as Dictionary
			providers.append([s, String(def["key"]), float(def["reach"]), int(def["capacity"]), float(def.get("pollution_mult", 1.0)), "station" if s.type == "caserne_pompiers" else ""])
		elif UrbanRules.WELL.has(s.type):
			providers.append([s, "fire", float(UrbanRules.WELL[s.type]["fire_reach"]), int(UrbanRules.WELL[s.type]["fire_capacity"]), 1.0, "well"])
	for candidate in guards:
		var g: SimWorld.Building = candidate as SimWorld.Building
		providers.append([g, "police", float(UrbanRules.GUARD[g.type]["reach"]), int(UrbanRules.GUARD[g.type]["capacity"]), 1.0, "guard"])
	for entry in providers:
		var s: SimWorld.Building = entry[0] as SimWorld.Building
		var key: String = String(entry[1])
		var reach: float = float(entry[2])
		var cap: int = int(entry[3])
		var mode: String = String(entry[5])
		var near: Array = []
		for other in done:
			var o: SimWorld.Building = other as SimWorld.Building
			if UrbanRules.RELAY.has(o.type) or (bool(o.city.get(key, false)) and not (mode == "station" and not bool(o.city.get("fire_station", false)))):
				continue
			var d: float = s.center.distance_to(o.center)
			if d <= reach + float(o.size) * 0.5:
				near.append([d, o])
		near.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1].id) < int(b[1].id)))
		var served: int = 0
		for pair in near:
			if served >= cap:
				break
			var o: SimWorld.Building = pair[1] as SimWorld.Building
			o.city[key] = true
			if mode == "station":
				o.city["fire_station"] = true
			elif mode == "well":
				o.city["fire_well"] = true
			elif mode == "guard":
				o.city["guard"] = true
			elif key == "police":
				o.city["police_station"] = true
			if key == "waste":
				o.city["waste_mult"] = minf(float(o.city.get("waste_mult", 1.0)), float(entry[4]))
			served += 1
		s.city["served"] = served
		s.city["capacity"] = cap
		served_count[key] = int(served_count.get(key, 0)) + served

	# 4. Pollution, atténuée par la gestion des déchets.
	var polluters: Array = []
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.POLLUTION.has(b.type):
			var amount: float = float(UrbanRules.POLLUTION[b.type])
			if UrbanRules.is_zone(b.type):
				amount *= float(b.city.get("density", 1.0))
			polluters.append([b.center, amount])
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		var p: float = 0.0
		for pair in polluters:
			var d: float = (pair[0] as Vector2).distance_to(b.center)
			if d < UrbanRules.POLLUTION_REACH:
				p += float(pair[1]) * (1.0 - d / UrbanRules.POLLUTION_REACH)
		b.city["pollution"] = clampf(p * float(b.city.get("waste_mult", 1.0)), 0.0, 100.0)

	# 5. Habitants, actifs et emplois (un bâtiment vide, brûlé ou en chantier n'abrite ni ne fait travailler personne).
	var habitants: int = 0
	var actifs: float = 0.0
	var jobs: int = 0
	var shop_jobs: int = 0
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		var state_mult: float = 1.0
		var state: String = String(b.city.get("state", "operational"))
		if state in ["abandoned", "burnt"] or float(b.city.get("burning", 0.0)) > 0.0:
			state_mult = 0.0
		elif state == "damaged":
			state_mult = 0.6
		if b.type == "zone_r":
			var h: int = int(round(float(b.city.get("density", 0.0)) * UrbanRules.HABITANTS_PER_LEVEL * state_mult))
			b.city["habitants"] = h
			habitants += h
			actifs += float(h) * UrbanRules.ACTIVE_SHARE * (0.6 + 0.4 * float(b.city.get("health_v", 90.0)) / 100.0)
		elif UrbanRules.JOBS_PER_LEVEL.has(b.type):
			var n: int = int(round(float(b.city.get("density", 0.0)) * float(UrbanRules.JOBS_PER_LEVEL[b.type]) * state_mult)) if bool(b.city.get("powered", false)) else 0
			b.city["jobs"] = n
			jobs += n
			if b.type == "zone_c":
				shop_jobs += n
	var fill: float = minf(1.0, actifs / float(jobs)) if jobs > 0 else 0.0
	var unemployment: float = maxf(0.0, actifs - float(jobs)) / actifs if actifs > 0.0 else 0.0
	var demand_c: float = minf(1.0, float(habitants) / (float(shop_jobs) * UrbanRules.CUSTOMERS_PER_SHOP_JOB)) if shop_jobs > 0 else 0.0
	var famine: bool = bool(t.city.get("famine", false))
	var danger: Dictionary = UrbanGrowth._danger_blocks(w, team)
	# Le chômage pèse peu dans un hameau (on y vit encore de la récolte) et pleinement dans une grande ville.
	var jobless: float = unemployment * clampf(float(habitants) / 100.0, 0.2, 1.0)

	# 6. Criminalité (chômage, pauvreté, bonheur, densité, sécurité, conflits, services), santé, bonheur, richesse.
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not UrbanRules.is_zone(b.type):
			continue
		var density: float = float(b.city.get("density", 1.0))
		var powered: bool = bool(b.city.get("powered", false))
		var watered: bool = bool(b.city.get("watered", false))
		var pollution: float = float(b.city["pollution"])
		var happiness: float = float(b.city.get("happiness", 60.0))
		var wealth: float = float(b.city.get("wealth", 40.0))
		var conflict: bool = danger.has((b.cell.y / UrbanGrowth.BLOCK) * 4096 + b.cell.x / UrbanGrowth.BLOCK)
		var crime_target: float = UrbanRules.CRIME_BASE + UrbanRules.CRIME_PER_LEVEL * density + maxf(0.0, 50.0 - happiness) * 0.3
		crime_target += maxf(0.0, 40.0 - wealth) * UrbanRules.CRIME_POVERTY
		if conflict:
			crime_target += UrbanRules.CRIME_CONFLICT
		if not (bool(b.city["police"]) or bool(b.city["health"]) or bool(b.city["fire"])):
			crime_target += UrbanRules.CRIME_NO_SERVICE
		if b.type == "zone_r" or b.type == "zone_c":
			crime_target += UrbanRules.CRIME_UNEMPLOYMENT * jobless
		else:
			crime_target *= 0.5
		if bool(b.city["police"]):
			crime_target *= UrbanRules.CRIME_POLICE_MULT if bool(b.city.get("police_station", false)) else 0.5
		var crime: float = float(b.city.get("crime", UrbanRules.CRIME_BASE))
		crime = clampf(crime + (crime_target - crime) * ease_scaled(UrbanRules.CRIME_EASE), 0.0, 100.0)
		b.city["crime"] = crime
		var no_water: float = (UrbanRules.HEALTH_NO_WATER if electric else UrbanRules.ERA_NO_WATER_HEALTH) if not watered else 0.0
		var health_target: float = 100.0 - pollution * UrbanRules.HEALTH_POLLUTION - no_water + (UrbanRules.HEALTH_HOSPITAL_BONUS if bool(b.city["health"]) else 0.0) - (15.0 if famine and b.type == "zone_r" else 0.0)
		b.city["health_v"] = clampf(float(b.city.get("health_v", 90.0)) + (clampf(health_target, 0.0, 100.0) - float(b.city.get("health_v", 90.0))) * ease_scaled(0.3), 0.0, 100.0)
		var coverage: float = 0.0
		var water_pen: float = (20.0 if electric else 6.0) if not watered else 0.0
		if b.type == "zone_r":
			coverage = 4.0 * float(int(b.city["police"]) + int(b.city["fire"]) + int(b.city["health"])) + 3.0 * float(int(b.city["waste"]))
			happiness = 70.0 - crime * 0.3 - pollution * 0.35 - (100.0 - float(b.city["health_v"])) * 0.25 - water_pen - (0.0 if powered else 25.0) - jobless * 20.0 + coverage - (20.0 if famine else 0.0)
		elif b.type == "zone_c":
			coverage = 4.0 * float(int(b.city["police"]) + int(b.city["fire"])) + 2.0 * float(int(b.city["waste"]))
			happiness = 70.0 - crime * 0.3 - pollution * 0.2 - (0.0 if powered else 40.0) - water_pen * 0.5 + coverage
		elif b.type == "zone_a":
			coverage = 4.0 * float(int(b.city["police"]) + int(b.city["fire"]))
			happiness = 72.0 - crime * 0.25 - pollution * 0.4 - water_pen * 0.5 + coverage
		else:
			coverage = 6.0 * float(int(b.city["fire"])) + 3.0 * float(int(b.city["police"]))
			happiness = 75.0 - crime * 0.2 - (0.0 if powered else 50.0) - water_pen * 0.5 + coverage
		b.city["happiness"] = clampf(happiness, 0.0, 100.0)
		var services_n: int = int(b.city["police"]) + int(b.city["fire"]) + int(b.city["health"]) + int(b.city["waste"])
		var target_wealth: float = 28.0 + 6.0 * float(services_n) + 6.0 * float(int(b.city.get("level", 1))) - pollution * 0.4 - crime * 0.25 + float(b.city["happiness"]) * 0.15 + (5.0 if watered else 0.0) + (5.0 if electric and powered else 0.0)
		if String(b.city.get("state", "")) == "degraded":
			target_wealth -= 10.0
		b.city["wealth"] = clampf(wealth + (clampf(target_wealth, 0.0, 100.0) - wealth) * ease_scaled(0.25), 0.0, 100.0)

	# 7. Développement automatique (densité jusqu'au niveau atteint) ; criminalité forte : les habitants partent.
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not UrbanRules.is_zone(b.type):
			continue
		var density: float = float(b.city["density"])
		var level: float = float(int(b.city.get("level", 1)))
		var happiness: float = float(b.city["happiness"])
		var powered: bool = bool(b.city.get("powered", false))
		var watered: bool = bool(b.city.get("watered", false)) or not electric
		var state: String = String(b.city.get("state", "operational"))
		var stuck: bool = state in ["abandoned", "burnt", "burning"]
		var grow: bool = false
		var decline: bool = false
		if b.type == "zone_r":
			grow = powered and watered and happiness >= UrbanRules.GROW_HAPPINESS and not famine and not stuck
			decline = not powered or not watered or happiness < UrbanRules.DECLINE_HAPPINESS or famine or stuck
		elif b.type == "zone_c":
			grow = powered and happiness >= 45.0 and fill >= 0.75 and demand_c >= 0.6 and not stuck
			decline = not powered or happiness < 25.0 or demand_c < 0.3 or stuck
		else:
			grow = powered and happiness >= 45.0 and fill >= 0.75 and not stuck
			decline = not powered or happiness < 25.0 or stuck
		if float(b.city.get("crime", 0.0)) >= UrbanRules.CRIME_MIGRATION:
			grow = false
			decline = true
		if grow and density < level:
			density = minf(level, density + UrbanRules.GROW_STEP * time_scale)
		elif decline and density > UrbanRules.MIN_DENSITY:
			density = maxf(UrbanRules.MIN_DENSITY, density - UrbanRules.DECLINE_STEP * time_scale)
		if density > level:
			density = level
		b.city["density"] = density

	# 8. Bien-être général et production des zones.
	var hap_sum: float = 0.0
	var hap_weight: float = 0.0
	var zone_hap: float = 0.0
	var zone_count: int = 0
	var crime_sum: float = 0.0
	var wealth_sum: float = 0.0
	var level_sum: float = 0.0
	var health_sum: float = 0.0
	var health_weight: float = 0.0
	var pollution_sum: float = 0.0
	var coverage_hits: int = 0
	var fire_cover: int = 0
	var burning: int = 0
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if float(b.city.get("burning", 0.0)) > 0.0:
			burning += 1
		if not UrbanRules.is_zone(b.type):
			continue
		zone_count += 1
		zone_hap += float(b.city["happiness"])
		crime_sum += float(b.city["crime"])
		wealth_sum += float(b.city.get("wealth", 40.0))
		level_sum += float(int(b.city.get("level", 1)))
		pollution_sum += float(b.city["pollution"])
		for key in ZONE_KEYS:
			if bool(b.city[key]):
				coverage_hits += 1
		if bool(b.city["fire"]):
			fire_cover += 1
		if b.type == "zone_r":
			var h: float = float(b.city.get("habitants", 0))
			hap_sum += float(b.city["happiness"]) * h
			hap_weight += h
			health_sum += float(b.city["health_v"]) * maxf(1.0, h)
			health_weight += maxf(1.0, h)
	var avg_hap: float = hap_sum / hap_weight if hap_weight > 0.0 else (zone_hap / float(zone_count) if zone_count > 0 else 50.0)
	var services_pct: float = 100.0 * float(coverage_hits) / float(zone_count * ZONE_KEYS.size()) if zone_count > 0 else 0.0
	var crime_avg: float = crime_sum / float(zone_count) if zone_count > 0 else 0.0
	var powered_n: int = 0
	for candidate in power_consumers:
		if bool((candidate as SimWorld.Building).city.get("powered", false)):
			powered_n += 1
	var watered_n: int = 0
	for candidate in water_consumers:
		if bool((candidate as SimWorld.Building).city.get("watered", false)):
			watered_n += 1
	var factors: Dictionary = {
		"securite": 100.0 - crime_avg,
		"incendies": (70.0 * float(fire_cover) / float(zone_count) if zone_count > 0 else 0.0) + 30.0 * (1.0 - float(burning) / float(maxi(1, done.size()))),
		"sante": health_sum / health_weight if health_weight > 0.0 else 100.0,
		"cadre": 100.0 - (pollution_sum / float(zone_count) if zone_count > 0 else 0.0),
		"eau": 100.0 * float(watered_n) / float(water_consumers.size()) if not water_consumers.is_empty() else 100.0,
		"electricite": (100.0 * float(powered_n) / float(power_consumers.size()) if not power_consumers.is_empty() else 100.0) if electric else 100.0,
		"services": services_pct,
	}
	var wellbeing: float = clampf(0.75 * avg_hap + 0.25 * services_pct, 0.0, 100.0)
	var productivity: float = UrbanRules.PRODUCTIVITY_MIN + UrbanRules.PRODUCTIVITY_SPAN * wellbeing / 100.0
	var tools: float = 1.25 if t.technologies.has("outillage") else 1.0
	var era: float = 1.0 if electric else UrbanRules.ERA_OUTPUT_MULT
	var produced: Dictionary = {"food": 0.0, "wood": 0.0, "ore": 0.0}
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not UrbanRules.OUTPUT.has(b.type):
			continue
		var out: Dictionary = {}
		b.city["employed"] = float(b.city.get("jobs", 0)) * fill
		var state_mult: float = float(UrbanRules.STATE_OUTPUT.get(String(b.city.get("state", "operational")), 1.0)) * UrbanEvents.output_mult(t, b)
		if bool(b.city.get("powered", false)) and float(b.city.get("burning", 0.0)) <= 0.0 and state_mult > 0.0:
			var factor: float = float(b.city["employed"]) * UrbanCity.period_s() * productivity * (0.5 + float(b.city["happiness"]) / 200.0) * w.labor(team) * tools * era * state_mult
			if b.type == "zone_c":
				factor *= demand_c * (1.0 - maxf(0.0, float(b.city["crime"]) - 40.0) * UrbanRules.CRIME_THEFT)
			else:
				factor *= 1.0 - minf(0.6, maxf(0.0, float(b.city["crime"]) - 50.0) * UrbanRules.CRIME_PRODUCTION)
			for res_value in (UrbanRules.OUTPUT[b.type] as Dictionary).keys():
				var res: String = String(res_value)
				var amount: float = maxf(0.0, factor * float(UrbanRules.OUTPUT[b.type][res]) * CivEvolution.gather_mult(w, team, res))
				t.res[res] = float(t.res[res]) + amount
				t.stats["gathered"][res] = float(t.stats["gathered"][res]) + amount
				produced[res] = float(produced[res]) + amount / UrbanCity.period_s()
				out[res] = amount / UrbanCity.period_s()
		b.city["out"] = out
	if electric and not centres.is_empty():
		for res_value in UrbanRules.CENTRE_TRICKLE.keys():
			var res: String = String(res_value)
			var amount: float = float(UrbanRules.CENTRE_TRICKLE[res]) * UrbanCity.period_s()
			t.res[res] = float(t.res[res]) + amount
			produced[res] = float(produced[res]) + amount / UrbanCity.period_s()
	# Nourriture des habitants (ressource réelle) ; stock vide : famine.
	var upkeep: float = float(habitants) * UrbanRules.FOOD_PER_HABITANT * UrbanCity.period_s()
	if float(t.res["food"]) >= upkeep:
		t.res["food"] = float(t.res["food"]) - upkeep
		if famine:
			w.emit("ville", team, "Fin de la famine : les habitants mangent de nouveau à leur faim", {})
		famine = false
	else:
		t.res["food"] = 0.0
		if not famine and habitants > 0:
			_alert(w, team, "famine", "Famine : plus de nourriture pour %d habitants — zones agricoles et commerces nécessaires" % habitants, {}, UrbanRules.ALERT_GAP)
		famine = habitants > 0
	t.city["famine"] = famine
	t.city["upkeep"] = upkeep / UrbanCity.period_s()
	# Pillages quand la criminalité de la ville est très forte (ressources réelles perdues).
	if zone_count > 0 and crime_avg >= UrbanRules.PILLAGE_CRIME and roll(w, team, 11) < prob_scaled(UrbanRules.PILLAGE_CHANCE):
		var stolen: Dictionary = {}
		for res in Rules.RESOURCES:
			var amount: float = float(t.res[res]) * UrbanRules.PILLAGE_SHARE
			t.res[res] = float(t.res[res]) - amount
			stolen[res] = amount
		t.city["pillages"] = int(t.city.get("pillages", 0)) + 1
		_alert(w, team, "pillage", "Pillage : %d vivres, %d bois, %d minerai volés — renforcez la sécurité" % [int(stolen.get("food", 0.0)), int(stolen.get("wood", 0.0)), int(stolen.get("ore", 0.0))], {}, 0)

	# 9. Émeutes : criminalité très forte et habitants malheureux ; la police ou l'armée y mettent fin.
	var riots: int = 0
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if b.type != "zone_r" or not w.buildings.has(b.id):
			continue
		var riot: String = String(b.city.get("riot", ""))
		var hot: bool = float(b.city.get("crime", 0.0)) >= UrbanRules.RIOT_CRIME and float(b.city.get("happiness", 100.0)) < UrbanRules.RIOT_HAPPINESS
		var calmed: bool = false
		if hot or riot != "":
			calmed = bool(b.city["police"]) or _army_near(w, team, b.center)
		if riot == "":
			# La tension monte tant que la misère dure et retombe lentement sinon.
			b.city["riot_t"] = float(b.city.get("riot_t", 0.0)) + UrbanCity.period_s() if hot else maxf(0.0, float(b.city.get("riot_t", 0.0)) - UrbanCity.period_s())
			if float(b.city["riot_t"]) >= UrbanRules.RIOT_TIME and not calmed:
				b.city["riot"] = "active"
				t.city["riots_total"] = int(t.city.get("riots_total", 0)) + 1
				_alert(w, team, "revolte", "Émeute dans un quartier : envoyez la police ou des soldats", {"building": b.id, "pos": b.center}, 0)
		else:
			riots += 1
			if not hot:
				b.city["riot_t"] = maxf(0.0, float(b.city.get("riot_t", 0.0)) - UrbanCity.period_s() * 2.0)
			if calmed or float(b.city.get("riot_t", 0.0)) <= 0.0:
				b.city["riot"] = ""
				b.city["riot_t"] = 0.0
				w.emit("ville", team, "Émeute terminée" + (" (forces de l'ordre)" if calmed else ""), {"building": b.id, "pos": b.center})
			else:
				# Une émeute abîme (vitrines, barricades) sans raser le quartier : la vie ne descend pas sous 40 %.
				b.hp = maxf(minf(b.hp, b.max_hp * 0.4), b.hp - b.max_hp * UrbanRules.RIOT_DAMAGE * time_scale)
				b.hit_tick = w.tick
				b.city["riot_hit"] = w.tick

	# 10. Incendies : intensité, matériaux, temps qu'il fait, densité, pompiers reliés par la route, puits, eau.
	var lost: Array = []
	var weather: float = UrbanGrowth.fire_weather(w)
	var layers: bool = UrbanZoning.has_layers(w, team)
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not w.buildings.has(b.id):
			continue
		var c: Dictionary = b.city
		var material: float = UrbanRules.material(int(c.get("style_age", clampi(t.age, 1, 10))))
		var fire_left: float = float(c.get("burning", 0.0))
		var station: bool = bool(c.get("fire_station", false)) and (not layers or not bool(c.get("grown", false)) or UrbanZoning.access(w, team, b.cell, b.size))
		if fire_left > 0.0:
			var intensity: float = float(c.get("fire_i", UrbanRules.FIRE_START_INTENSITY))
			var fight: float = (UrbanRules.FIRE_STATION_FIGHT if station else 0.0) + (UrbanRules.FIRE_WELL_FIGHT if bool(c.get("fire_well", false)) else 0.0)
			fight += (UrbanRules.FIRE_WATER_FIGHT if electric and bool(c.get("watered", false)) else 0.0) + (UrbanRules.FIRE_TECH_FIGHT if t.age >= 7 else 0.0)
			intensity = clampf(intensity + (UrbanRules.FIRE_GROWTH * material * weather / 1.2 - fight) * time_scale, 0.0, 1.0)
			c["fire_i"] = intensity
			b.hp -= b.max_hp * UrbanRules.FIRE_DAMAGE * intensity * UrbanCity.period_s()
			b.hit_tick = w.tick
			c["fire_tick"] = w.tick
			c["fire_hit"] = true
			if b.type == "zone_r":
				c["density"] = maxf(UrbanRules.MIN_DENSITY, float(c.get("density", 1.0)) - UrbanRules.FIRE_CASUALTY * intensity)
			fire_left -= UrbanCity.period_s()
			for other in done:
				var o: SimWorld.Building = other as SimWorld.Building
				if o == b or not w.buildings.has(o.id) or float(o.city.get("burning", 0.0)) > 0.0 or o.center.distance_to(b.center) > UrbanRules.FIRE_SPREAD_REACH + float(o.size + b.size) * 0.5:
					continue
				var o_material: float = UrbanRules.material(int(o.city.get("style_age", clampi(t.age, 1, 10))))
				var spread: float = UrbanRules.FIRE_SPREAD_CHANCE * intensity * o_material * weather * (1.0 + 0.3 * float(int(o.city.get("level", 1)) - 1)) * (UrbanRules.FIRE_COVERED_MULT if bool(o.city.get("fire_station", false)) else 1.0)
				if roll(w, o.id, 2) < prob_scaled(spread):
					o.city["burning"] = UrbanRules.FIRE_DURATION
					o.city["fire_i"] = UrbanRules.FIRE_START_INTENSITY
					o.city["fire_cause"] = "propagation"
			if b.hp <= 0.0:
				lost.append(b)
			elif intensity <= 0.0 or fire_left <= 0.0:
				fire_left = 0.0
				c["fire_i"] = 0.0
				if b.hp < b.max_hp * 0.25 and UrbanRules.is_zone(b.type):
					c["state"] = "burnt"
				w.emit("incendie_fin", team, "Incendie éteint : %s" % String(Rules.BUILDINGS[b.type]["label"]), {"building": b.id, "pos": b.center})
			c["burning"] = maxf(0.0, fire_left)
		else:
			var chance: float = UrbanRules.FIRE_CHANCE * maxf(1.0, float(c.get("density", 1.0))) * material * weather
			var cause: String = "accident"
			if b.type in ["zone_i", "centrale"]:
				chance *= UrbanRules.FIRE_INDUSTRY_MULT
				cause = "industrie"
			if b.hp < b.max_hp * 0.5:
				chance *= UrbanRules.FIRE_DAMAGED_MULT
			if electric and bool(c.get("powered_grid", false)) and not bool(c.get("powered", true)):
				chance *= UrbanRules.FIRE_DEFECT_MULT
				cause = "installation défectueuse"
			if bool(c.get("fire_station", false)):
				chance *= UrbanRules.FIRE_COVERED_MULT
			elif bool(c.get("fire_well", false)):
				chance *= 0.6
			if weather > 1.6 and cause == "accident":
				cause = "sécheresse"
			# Touché par les combats (pas par son propre incendie ni par une émeute) pendant le dernier calcul.
			var war_hit: bool = w.tick - b.hit_tick <= int(float(UrbanRules.PERIOD) * time_scale) and b.hit_tick > int(c.get("fire_tick", -999)) and int(c.get("riot_hit", -999)) != b.hit_tick and int(c.get("event_hit", -999)) != b.hit_tick and b.hp < b.max_hp
			var started: bool = roll(w, b.id, 1) < prob_scaled(chance)
			if not started and war_hit and roll(w, b.id, 4) < UrbanRules.FIRE_WAR_CHANCE:
				started = true
				cause = "combats"
			if started:
				c["burning"] = UrbanRules.FIRE_DURATION
				c["fire_i"] = UrbanRules.FIRE_START_INTENSITY
				c["fire_cause"] = cause
				t.city["fires_total"] = int(t.city.get("fires_total", 0)) + 1
				w.emit("incendie", team, "Incendie (%s) : %s%s" % [cause, String(Rules.BUILDINGS[b.type]["label"]), "" if bool(c.get("fire", false)) else " — aucun pompier à portée"], {"building": b.id, "pos": b.center})
	for candidate in lost:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not w.buildings.has(b.id):
			continue
		t.city["fire_losses"] = int(t.city.get("fire_losses", 0)) + 1
		w.emit("incendie_perte", team, "Incendie : %s détruit(e)" % String(Rules.BUILDINGS[b.type]["label"]), {"building": b.id, "pos": b.center})
		w._destroy_building(b, SimWorld.TEAM_NEUTRAL)
	# Bâtiments ruinés par une émeute.
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if w.buildings.has(b.id) and b.hp <= 0.0:
			w._destroy_building(b, SimWorld.TEAM_NEUTRAL)

	# 11. Épidémies dans les quartiers en mauvaise santé.
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if b.type != "zone_r" or not w.buildings.has(b.id) or float(b.city.get("health_v", 100.0)) >= UrbanRules.EPIDEMIC_HEALTH:
			continue
		var chance: float = UrbanRules.EPIDEMIC_CHANCE * (UrbanRules.EPIDEMIC_HOSPITAL_MULT if bool(b.city["health"]) else 1.0)
		if roll(w, b.id, 3) < prob_scaled(chance):
			b.city["density"] = maxf(UrbanRules.MIN_DENSITY, float(b.city["density"]) * (1.0 - UrbanRules.EPIDEMIC_LOSS))
			b.city["health_v"] = maxf(0.0, float(b.city["health_v"]) - 10.0)
			t.city["epidemics"] = int(t.city.get("epidemics", 0)) + 1
			_alert(w, team, "epidemie", "Épidémie dans un quartier%s" % ("" if bool(b.city["health"]) else " — aucun hôpital à portée"), {"building": b.id, "pos": b.center}, 0)

	# 12. Bilan du camp, places d'unités, alertes.
	var urban_pop: int = int(habitants / UrbanRules.POP_PER_UNIT)
	t.pop_cap += urban_pop - int(t.city.get("pop_bonus", 0))
	t.city["pop_bonus"] = urban_pop
	t.city["habitants"] = habitants
	t.city["actifs"] = int(round(actifs))
	t.city["jobs"] = jobs
	t.city["employed"] = int(round(float(jobs) * fill))
	t.city["unemployment"] = unemployment
	t.city["fill"] = fill
	t.city["demand_c"] = demand_c
	t.city["power"] = [power_supply, power_demand]
	t.city["water"] = [water_supply, water_demand]
	t.city["electric"] = electric
	t.city["wellbeing"] = wellbeing
	t.city["productivity"] = productivity
	t.city["factors"] = factors
	t.city["production"] = produced
	t.city["zones"] = zone_count
	t.city["burning"] = burning
	t.city["riots"] = riots
	t.city["served"] = served_count
	t.city["crime_avg"] = crime_avg
	t.city["wealth_avg"] = wealth_sum / float(zone_count) if zone_count > 0 else 0.0
	t.city["level_avg"] = level_sum / float(zone_count) if zone_count > 0 else 0.0
	t.city["tick"] = w.tick
	if electric and power_demand > power_supply:
		_alert(w, team, "panne_electrique", "Électricité insuffisante : %d / %d — bâtissez une centrale" % [power_supply, power_demand], {}, UrbanRules.ALERT_GAP)
	if electric and water_demand > water_supply:
		_alert(w, team, "penurie_eau", "Eau insuffisante : %d / %d — bâtissez un château d'eau" % [water_supply, water_demand], {}, UrbanRules.ALERT_GAP)
	if zone_count > 0 and float(factors["securite"]) < 40.0:
		_alert(w, team, "criminalite", "Criminalité élevée — %s" % ("bâtissez un commissariat" if t.age >= 3 else "une caserne ou un fort près des quartiers"), {}, UrbanRules.ALERT_GAP)
	# 13. Croissance des parcelles zonées, niveaux, états, ruines.
	UrbanGrowth.step(w, team, done, {"habitants": habitants, "actifs": actifs, "jobs": jobs, "shop_jobs": shop_jobs,
		"wellbeing": wellbeing, "crime_avg": crime_avg, "unemployment": unemployment, "counts": counts, "electric": electric,
		"power": [power_supply, power_demand], "produced": produced, "wealth_avg": float(t.city["wealth_avg"]), "level_avg": float(t.city["level_avg"])})

static func _army_near(w: SimWorld, team: int, p: Vector2) -> bool:
	for candidate in w.units.values():
		var u: SimWorld.Unit = candidate as SimWorld.Unit
		if u.team == team and u.garrison_id == -1 and not Rules.unit_has(u.type, "worker") and u.pos.distance_to(p) <= UrbanRules.RIOT_ARMY_REACH:
			return true
	return false

static func _alert(w: SimWorld, team: int, kind: String, text: String, extra: Dictionary, gap: int) -> void:
	var t: SimWorld.Team = w.teams[team]
	if not t.city.has("alerts"):
		t.city["alerts"] = {}
	var last: int = int((t.city["alerts"] as Dictionary).get(kind, -100000))
	if gap > 0 and w.tick - last < gap:
		return
	t.city["alerts"][kind] = w.tick
	w.emit(kind, team, text, extra)

# ---------------------------------------------------------------- lecture pour l'interface

static func zone_summary(b: SimWorld.Building) -> String:
	if b.type == "ruine":
		return "Ruines d'un bâtiment (%s, âge %s) — la ville reconstruira ici si la demande revient" % [String(UrbanRules.ZONE_LABEL.get(String(b.city.get("was", "")), "zone")).to_lower(), UrbanRules.roman(int(b.city.get("style_age", 1)))]
	if not UrbanRules.is_urban(b.type):
		return ""
	var c: Dictionary = b.city
	var parts: PackedStringArray = PackedStringArray()
	if UrbanRules.is_zone(b.type):
		var level: int = int(c.get("level", 1))
		parts.append("%s · Niveau %s · %s · densité %d %%" % [UrbanGrowth.state_label(String(c.get("state", "operational"))), UrbanRules.roman(level), UrbanRules.level_name(b.type, level), int(round(100.0 * float(c.get("density", 0.0)) / float(level)))])
		parts.append("architecture de l'âge %s%s" % [UrbanRules.roman(int(c.get("style_age", 1))), " (conservée)" if bool(c.get("historic", false)) else ""])
		var wealth: float = float(c.get("wealth", 0.0))
		parts.append("richesse %d (%s)" % [int(wealth), "aisé" if wealth >= 70.0 else ("populaire" if wealth <= 35.0 else "moyen")])
		if String(c.get("level_lack", "")) != "":
			parts.append("niveau suivant : " + String(c["level_lack"]))
		if String(c.get("riot", "")) != "":
			parts.append("ÉMEUTE")
		if b.type == "zone_r":
			parts.append("%d habitants" % int(c.get("habitants", 0)))
		else:
			parts.append("%d / %d emplois occupés" % [int(round(float(c.get("employed", 0.0)))), int(c.get("jobs", 0))])
	elif UrbanRules.SERVICES.has(b.type):
		parts.append("Dessert %d / %d bâtiments" % [int(c.get("served", 0)), int(c.get("capacity", int(UrbanRules.SERVICES[b.type]["capacity"])))])
	parts.append(("Électricité : oui" if bool(c.get("powered", false)) else ("Électricité : non (pénurie)" if bool(c.get("powered_grid", false)) else "Électricité : non (hors réseau)")) if UrbanRules.POWER_USE.has(b.type) or UrbanRules.RELAY.has(b.type) else "")
	if UrbanRules.WATER_USE.has(b.type):
		parts.append("Eau : oui" if bool(c.get("watered", false)) else ("Eau : non (pénurie)" if bool(c.get("watered_grid", false)) else "Eau : non (hors réseau)"))
	var out: PackedStringArray = PackedStringArray()
	for p in parts:
		if p != "":
			out.append(p)
	return " · ".join(out)

static func zone_indicators(b: SimWorld.Building) -> Array:
	## [libellé, valeur 0–100 (plus haut = mieux), texte] pour la fiche.
	var c: Dictionary = b.city
	if not UrbanRules.is_zone(b.type) or not bool(c.get("ready", false)):
		return []
	var rows: Array = []
	rows.append(["Bonheur" if b.type == "zone_r" else "Attractivité", float(c.get("happiness", 0.0)), "%d" % int(round(float(c.get("happiness", 0.0))))])
	rows.append(["Sécurité", 100.0 - float(c.get("crime", 0.0)), "criminalité %d" % int(round(float(c.get("crime", 0.0))))])
	if b.type == "zone_r":
		rows.append(["Santé", float(c.get("health_v", 0.0)), "%d" % int(round(float(c.get("health_v", 0.0))))])
	rows.append(["Air", 100.0 - float(c.get("pollution", 0.0)), "pollution %d" % int(round(float(c.get("pollution", 0.0))))])
	var have: PackedStringArray = PackedStringArray()
	var lack: PackedStringArray = PackedStringArray()
	for key in ZONE_KEYS:
		if bool(c.get(key, false)):
			have.append(String(UrbanRules.SERVICE_LABEL[key]))
		else:
			lack.append(String(UrbanRules.SERVICE_LABEL[key]))
	var cover_text: String = ", ".join(have) if not have.is_empty() else "aucun"
	if not lack.is_empty():
		cover_text += " · manque : " + ", ".join(lack)
	rows.append(["Services", 25.0 * float(int(c.get("police", false)) + int(c.get("fire", false)) + int(c.get("health", false)) + int(c.get("waste", false))), cover_text])
	return rows
