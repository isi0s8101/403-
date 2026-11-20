class_name UrbanGrowth
extends RefCounted
## 0.19 — Croissance organique de la ville sur les parcelles zonées : demande tirée de la vraie économie, chantiers
## sans ouvrier payés en ressources réelles, niveaux par catégorie selon l'âge, densification, états des bâtiments,
## ruines et reconstruction. Appelé par UrbanCity._update toutes les UrbanRules.PERIOD ticks, pour chaque camp.
## Tirages déterministes (UrbanCity.roll) : la partie reste reproductible à graine égale.

# ---------------------------------------------------------------- temps qu'il fait (déterministe)

static func dryness(w: SimWorld) -> float:
	## 0 = humide, 1 = très sec. Cycle lent, décalé par la graine, petites variations par fenêtre de 60 s.
	var phase: float = float(absi(w.seed_value) % 997) / 997.0 * TAU
	var base: float = 0.5 + 0.4 * sin(TAU * float(w.tick) / float(UrbanRules.WEATHER_CYCLE) + phase)
	var jitter: float = float(hash([w.seed_value, w.tick / 600]) & 0xffff) / 65535.0 - 0.5
	return clampf(base + 0.2 * jitter, 0.0, 1.0)

static func weather_label(w: SimWorld) -> String:
	var d: float = dryness(w)
	if d < 0.3:
		return "humide"
	if d < 0.65:
		return "tempéré"
	if d < 0.85:
		return "sec"
	return "sécheresse"

static func fire_weather(w: SimWorld) -> float:
	return 0.4 + 1.6 * dryness(w)

# ---------------------------------------------------------------- demande

static func demand(w: SimWorld, team: int, ctx: Dictionary) -> Dictionary:
	## Demande de chaque catégorie entre -1 et 1, à partir de l'économie réelle du camp (stocks, emplois, habitants,
	## bien-être, criminalité, électricité, nourriture). Aucune ressource fictive.
	var t: SimWorld.Team = w.teams[team]
	var habitants: float = float(ctx.get("habitants", 0))
	var actifs: float = float(ctx.get("actifs", 0.0))
	var jobs: float = float(ctx.get("jobs", 0))
	var shop_jobs: float = float(ctx.get("shop_jobs", 0))
	var wellbeing: float = float(ctx.get("wellbeing", 50.0))
	var crime: float = float(ctx.get("crime_avg", 0.0))
	var unemployment: float = float(ctx.get("unemployment", 0.0))
	var counts: Dictionary = ctx.get("counts", {}) as Dictionary
	var food: float = float(t.res.get("food", 0.0))
	var famine: bool = bool(t.city.get("famine", false))
	var out: Dictionary = {}
	# Habitation : emplois libres, bien-être, nourriture, place pour l'armée, sécurité.
	var r: float = 0.3 + (wellbeing - 50.0) / 150.0 - crime / 250.0
	if habitants < 30.0:
		r += 0.1                       # premiers habitants : ils vivent encore de la récolte et de l'artisanat
	elif actifs > 0.0:
		r += clampf((jobs - actifs) / maxf(8.0, actifs), -0.6, 0.6)
	elif jobs > 0.0:
		r += 0.5
	if t.pop >= t.pop_cap - 2:
		r += 0.3
	r += 0.1 if food > 100.0 else (-0.6 if famine else -0.1)
	if int(counts.get("zone_r", 0)) == 0:
		r = maxf(r, 0.6)
	out["zone_r"] = clampf(r, -1.0, 1.0)
	# Commerce : clients (habitants) au-delà de la capacité des boutiques, richesse, sécurité.
	var c: float = -0.2
	if habitants >= 8.0:
		var capacity: float = shop_jobs * UrbanRules.CUSTOMERS_PER_SHOP_JOB
		c = clampf((habitants - capacity) / maxf(20.0, habitants), -1.0, 1.0) + float(ctx.get("wealth_avg", 40.0)) / 400.0 - crime / 250.0
	out["zone_c"] = clampf(c, -1.0, 1.0)
	# Industrie : chômage, besoin de minerai, électricité disponible (après la recherche), sécurité.
	var i: float = -0.2
	if habitants >= 10.0:
		i = unemployment * 1.2 + (0.3 if float(t.res.get("ore", 0.0)) < 200.0 else 0.0) - crime / 300.0
		if int(counts.get("zone_i", 0)) == 0:
			i += 0.25
		if bool(ctx.get("electric", false)):
			var power: Array = ctx.get("power", [0, 0]) as Array
			if int(power[0]) - int(power[1]) < 2:
				i -= 0.5
	out["zone_i"] = clampf(i, -1.0, 1.0)
	# Agriculture : nourriture produite face à la consommation des habitants, stock bas.
	var upkeep: float = habitants * UrbanRules.FOOD_PER_HABITANT
	var food_made: float = float((ctx.get("produced", {}) as Dictionary).get("food", 0.0))
	var a: float = (0.5 if food_made < upkeep * 1.2 else -0.2) + (0.3 if food < 100.0 else 0.0)
	if int(counts.get("zone_a", 0)) == 0 and habitants >= 4.0:
		a += 0.2
	if bool(ctx.get("electric", false)):
		a -= 0.1
	out["zone_a"] = clampf(a, -1.0, 1.0)
	# 0.20 : événements en cours (crise, vague de migration…).
	for key in out.keys():
		out[key] = clampf(float(out[key]) + UrbanEvents.demand_bias(t, String(key)), -1.0, 1.0)
	return out

# ---------------------------------------------------------------- pas de croissance

static func step(w: SimWorld, team: int, done: Array, ctx: Dictionary) -> void:
	var t: SimWorld.Team = w.teams[team]
	if not UrbanZoning.has_layers(w, team):
		return
	var dem: Dictionary = demand(w, team, ctx)
	t.city["demand"] = dem
	var sites: int = _progress_sites(w, team)
	_update_states(w, team, done, ctx)
	_level_ups(w, team, done, dem, ctx)
	_new_sites(w, team, dem, sites, ctx)
	t.city["weather"] = weather_label(w)
	var hab: int = int(ctx.get("habitants", 0))
	var name: String = "Campement"
	for pair in UrbanRules.SETTLEMENTS:
		if hab >= int(pair[0]):
			name = String(pair[1])
	if t.age >= 8 and float(ctx.get("level_avg", 0.0)) >= 4.0 and hab >= 600:
		name = "Ville technologique"
	t.city["settlement"] = name

static func _progress_sites(w: SimWorld, team: int) -> int:
	## Chantiers de la ville (sans ouvrier) : avancent seuls, payés au lancement. Renvoie le nombre de chantiers ouverts.
	var open: int = 0
	for candidate in UrbanCity._sorted(w.team_buildings(team)):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not UrbanRules.is_zone(b.type) or b.complete or not bool(b.city.get("grown", false)):
			continue
		open += 1
		var level: int = int(b.city.get("level", 1))
		var duration: float = UrbanRules.BUILD_TIME + UrbanRules.BUILD_TIME_PER_LEVEL * float(level - 1)
		b.progress = minf(1.0, b.progress + UrbanCity.period_s() / duration)
		b.hp = maxf(b.hp, b.max_hp * maxf(0.1, b.progress))
		if b.progress >= 1.0:
			b.hp = b.max_hp
			w._complete_building(b)
			b.city["state"] = "operational"
			open -= 1
	return open

static func _required(b: SimWorld.Building, level: int, electric: bool) -> String:
	## Service manquant pour atteindre `level` (vide si tout est là).
	for key in UrbanRules.LEVEL_NEEDS.get(level, []) as Array:
		var k: String = String(key)
		if k == "power":
			if electric and not bool(b.city.get("powered", false)):
				return "électricité"
			if not electric:
				return "électricité (recherche Électricité)"
		elif k == "water":
			if not bool(b.city.get("watered", false)):
				return "eau"
		elif not bool(b.city.get(k, false)):
			return String(UrbanRules.SERVICE_LABEL.get(k, k)).to_lower()
	return ""

static func level_cap(w: SimWorld, team: int, b: SimWorld.Building) -> int:
	var code: int = UrbanZoning.parcel_code(w, team, b.cell)
	var zoned_cap: int = int((UrbanZoning.KINDS[code] as Dictionary)["cap"]) if code != 0 else UrbanRules.kind_max(b.type)
	return mini(zoned_cap, mini(UrbanRules.kind_max(b.type), UrbanRules.age_cap((w.teams[team] as SimWorld.Team).age)))

static func level_lack(w: SimWorld, team: int, b: SimWorld.Building, dem: Dictionary, electric: bool) -> String:
	## Ce qui empêche le niveau suivant (vide si possible). Même règle pour le joueur, l'IA et la croissance seule.
	var level: int = int(b.city.get("level", 1))
	if level >= level_cap(w, team, b):
		return "niveau maximal pour ce zonage et cet âge"
	var state: String = String(b.city.get("state", "operational"))
	if not state in ["operational", "prosperous"]:
		return "bâtiment %s" % state_label(state).to_lower()
	if float(b.city.get("density", 0.0)) < float(level) - 0.05:
		return "densité insuffisante"
	if float(b.city.get("happiness", 0.0)) < 52.0 + 3.0 * float(level):
		return "habitants pas assez satisfaits"
	if float(b.city.get("wealth", 0.0)) < 18.0 + 10.0 * float(level):
		return "quartier pas assez riche"
	if float(dem.get(b.type, 0.0)) <= 0.0:
		return "pas de demande"
	if not UrbanZoning.access(w, team, b.cell, b.size):
		return "aucune route reliée au centre"
	var need: String = _required(b, level + 1, electric)
	if need != "":
		return "service manquant : " + need
	return ""

static func _level_ups(w: SimWorld, team: int, done: Array, dem: Dictionary, ctx: Dictionary) -> void:
	var electric: bool = bool(ctx.get("electric", false))
	var t: SimWorld.Team = w.teams[team]
	var period: int = w.tick / UrbanRules.PERIOD
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not UrbanRules.is_zone(b.type) or not w.buildings.has(b.id):
			continue
		# Travaux de niveau en cours.
		if float(b.city.get("works", 0.0)) > 0.0:
			b.city["works"] = maxf(0.0, float(b.city["works"]) - UrbanCity.period_s())
			if float(b.city["works"]) <= 0.0:
				var target: int = int(b.city.get("works_to", int(b.city.get("level", 1)) + 1))
				b.city["level"] = target
				if not bool(b.city.get("historic", false)):
					b.city["style_age"] = clampi(t.age, 1, 10)
				b.city.erase("works_to")
				w.emit("ville", team, "%s : niveau %s (%s)" % [String(Rules.BUILDINGS[b.type]["label"]), UrbanRules.roman(target), UrbanRules.level_name(b.type, target)], {"building": b.id, "pos": b.center})
			continue
		if (period + b.id) % UrbanRules.LEVEL_CHECK_EVERY != 0:
			continue
		var why: String = level_lack(w, team, b, dem, electric)
		b.city["level_lack"] = why
		if why != "":
			continue
		var cost: Dictionary = w.scaled_cost(UrbanRules.UPGRADE_COST[int(b.city.get("level", 1)) + 1])
		if not w._can_pay(team, cost):
			b.city["level_lack"] = w._missing_text(team, cost)
			continue
		w._pay(team, cost)
		b.city["works"] = UrbanRules.LEVEL_WORKS
		b.city["works_to"] = int(b.city.get("level", 1)) + 1

# ---------------------------------------------------------------- états des bâtiments

const STATE_LABELS := {"construction": "En construction", "operational": "Opérationnel", "prosperous": "Prospère",
	"degraded": "Dégradé", "damaged": "Endommagé", "burning": "En feu", "burnt": "Incendié", "abandoned": "Abandonné",
	"reconstruction": "En travaux", "dezoned": "Zone retirée"}

static func state_label(state: String) -> String:
	return String(STATE_LABELS.get(state, state))

static func _update_states(w: SimWorld, team: int, done: Array, ctx: Dictionary) -> void:
	var t: SimWorld.Team = w.teams[team]
	var remove: Array = []
	var to_ruin: Array = []
	for candidate in done:
		var b: SimWorld.Building = candidate as SimWorld.Building
		if not UrbanRules.is_zone(b.type) or not w.buildings.has(b.id):
			continue
		var c: Dictionary = b.city
		# Zone retirée ou changée de catégorie : le bâtiment se vide puis disparaît (pas de ruine).
		var code: int = UrbanZoning.parcel_code(w, team, b.cell)
		var matches: bool = code != 0 and String((UrbanZoning.KINDS[code] as Dictionary)["building"]) == b.type
		if matches:
			c["zoned_once"] = true
		# Un bâtiment qui n'a jamais été sur une parcelle zonée (pose de laboratoire) n'est pas géré par le zonage.
		var managed: bool = managed_by_zoning(b)
		if not matches and not managed:
			matches = true
		if not matches:
			c["dezoned"] = float(c.get("dezoned", 0.0)) + UrbanCity.period_s()
			if float(c["dezoned"]) >= UrbanRules.DEZONE_DELAY:
				remove.append(b)
				continue
		else:
			c.erase("dezoned")
		# Zonage abaissé (habitat moins dense) : le bâtiment redescend d'un niveau par délai.
		if matches and int(c.get("level", 1)) > level_cap(w, team, b) and float(c.get("works", 0.0)) <= 0.0:
			c["over_cap"] = float(c.get("over_cap", 0.0)) + UrbanCity.period_s()
			if float(c["over_cap"]) >= UrbanRules.DEZONE_DELAY:
				c["level"] = int(c["level"]) - 1
				c["density"] = minf(float(c.get("density", 1.0)), float(c["level"]))
				c["over_cap"] = 0.0
		var ratio: float = b.hp / maxf(1.0, b.max_hp)
		var crime: float = float(c.get("crime", 0.0))
		c["crime_t"] = float(c.get("crime_t", 0.0)) + UrbanCity.period_s() if crime >= UrbanRules.CRIME_DEGRADE else 0.0
		var happiness: float = float(c.get("happiness", 60.0))
		var lonely: bool = bool(c.get("grown", false)) and not UrbanZoning.access(w, team, b.cell, b.size)
		var miserable: bool = bool(c.get("grown", false)) and (happiness < 15.0 or (b.type == "zone_r" and bool(t.city.get("famine", false)) and happiness < 30.0))
		if not matches or lonely or miserable:
			c["abandon_t"] = float(c.get("abandon_t", 0.0)) + UrbanCity.period_s()
		else:
			c["abandon_t"] = maxf(0.0, float(c.get("abandon_t", 0.0)) - UrbanCity.period_s() * 2.0)
		# Bâtiment brûlé : réparé si le camp peut payer, sinon il tombe en ruine.
		if String(c.get("state", "")) == "burnt" and float(c.get("burning", 0.0)) <= 0.0:
			var repair: Dictionary = w.scaled_cost(UrbanRules.REPAIR_COST)
			if w._can_pay(team, repair):
				w._pay(team, repair)
				b.hp = maxf(b.hp, b.max_hp * 0.6)
				c["works"] = maxf(float(c.get("works", 0.0)), UrbanRules.LEVEL_WORKS * 0.5)
				c["works_to"] = int(c.get("level", 1))
				c.erase("burnt_t")
			else:
				c["burnt_t"] = float(c.get("burnt_t", 0.0)) + UrbanCity.period_s()
				if float(c["burnt_t"]) >= UrbanRules.BURNT_REPAIR_DELAY:
					to_ruin.append(b)
					continue
		# Petits dégâts : réparation lente payée en bois.
		elif ratio < 1.0 and float(c.get("burning", 0.0)) <= 0.0 and String(c.get("riot", "")) == "" and w.tick - b.hit_tick > UrbanRules.PERIOD * 3:
			var wood_cost: float = 1.0 * float(w.rule("cost_mult", 1.0))
			if float(t.res["wood"]) >= wood_cost:
				t.res["wood"] = float(t.res["wood"]) - wood_cost
				b.hp = minf(b.max_hp, b.hp + b.max_hp * 0.02)
		if float(c.get("abandon_t", 0.0)) >= UrbanRules.ABANDON_DELAY and matches:
			to_ruin.append(b)
			continue
		c["state"] = _state_of(b, ratio)
	for candidate in remove:
		var b: SimWorld.Building = candidate as SimWorld.Building
		b.city["no_ruin"] = true
		w.emit("ville", team, "Zone changée : %s démoli(e)" % String(Rules.BUILDINGS[b.type]["label"]), {"building": b.id, "pos": b.center})
		w._destroy_building(b, team)
	for candidate in to_ruin:
		var b: SimWorld.Building = candidate as SimWorld.Building
		w.emit("ville", team, "%s tombé(e) en ruine" % String(Rules.BUILDINGS[b.type]["label"]), {"building": b.id, "pos": b.center})
		w._destroy_building(b, SimWorld.TEAM_NEUTRAL)

static func managed_by_zoning(b: SimWorld.Building) -> bool:
	return bool(b.city.get("grown", false)) or bool(b.city.get("zoned_once", false))

static func _state_of(b: SimWorld.Building, ratio: float) -> String:
	var c: Dictionary = b.city
	if not b.complete:
		return "construction"
	if float(c.get("burning", 0.0)) > 0.0:
		return "burning"
	if String(c.get("state", "")) == "burnt" and ratio < 0.6:
		return "burnt"
	if ratio < 0.25 and bool(c.get("fire_hit", false)):
		return "burnt"
	if float(c.get("works", 0.0)) > 0.0:
		return "reconstruction"
	if float(c.get("abandon_t", 0.0)) >= UrbanRules.PERIOD_S * 5.0 or c.has("dezoned"):
		return "abandoned"
	if ratio < 0.5:
		return "damaged"
	if float(c.get("crime_t", 0.0)) >= UrbanRules.CRIME_DEGRADE_TIME or float(c.get("wealth", 50.0)) < 15.0:
		return "degraded"
	if float(c.get("happiness", 0.0)) >= 75.0 and float(c.get("wealth", 0.0)) >= 60.0 and float(c.get("density", 0.0)) >= float(int(c.get("level", 1))) - 0.05:
		return "prosperous"
	return "operational"

static func on_destroyed(w: SimWorld, b: SimWorld.Building, by_team: int) -> void:
	## Un bâtiment de zone détruit par le feu, une émeute ou l'ennemi laisse des ruines persistantes (pas s'il est
	## démoli par son camp ou retiré par le zonage).
	if not UrbanRules.is_zone(b.type) or bool(b.city.get("no_ruin", false)) or by_team == b.team or not b.complete:
		return
	if b.team < 0 or b.team >= w.teams.size() or b.team == SimWorld.TEAM_NEUTRAL:
		return
	if not w.footprint_free(b.cell, int(Rules.BUILDINGS["ruine"]["size"])):
		return
	var ruin: SimWorld.Building = w.spawn_building(b.team, "ruine", b.cell, true)
	ruin.city = {"was": b.type, "level": int(b.city.get("level", 1)), "style_age": int(b.city.get("style_age", 1)), "since": w.tick}
	var t: SimWorld.Team = w.teams[b.team]
	t.city["ruins_total"] = int(t.city.get("ruins_total", 0)) + 1

# ---------------------------------------------------------------- nouveaux chantiers

static func enemy_near(w: SimWorld, team: int, p: Vector2, reach: float) -> bool:
	## Une unité armée d'un camp ennemi à moins de `reach` cases (guerre, insécurité).
	var enemies: Array = w.enemies_of(team)
	if enemies.is_empty():
		return false
	for candidate in w.units.values():
		var u: SimWorld.Unit = candidate as SimWorld.Unit
		if u.garrison_id != -1 or not enemies.has(u.team) or Rules.unit_has(u.type, "worker"):
			continue
		if u.pos.distance_to(p) <= reach:
			return true
	return false

const BLOCK: int = 4                      # cases par bloc de la grille de voisinage
const SCAN_PER_KIND: int = 96             # parcelles examinées au plus par catégorie et par calcul (tour à tour)

static func _danger_blocks(w: SimWorld, team: int) -> Dictionary:
	## Blocs de BLOCK cases où se trouve une unité armée ennemie (avec leur voisinage) : un seul passage par calcul.
	var out: Dictionary = {}
	var enemies: Array = w.enemies_of(team)
	if enemies.is_empty():
		return out
	var r: int = ceili(UrbanRules.ENEMY_REACH / float(BLOCK))
	for candidate in w.units.values():
		var u: SimWorld.Unit = candidate as SimWorld.Unit
		if u.garrison_id != -1 or not enemies.has(u.team) or Rules.unit_has(u.type, "worker"):
			continue
		var bx: int = int(u.pos.x) / BLOCK
		var by: int = int(u.pos.y) / BLOCK
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				out[(by + dy) * 4096 + bx + dx] = true
	return out

static func _neighbour_grid(built: Array) -> Dictionary:
	## Par bloc : [bâtiments de zone, somme des criminalités, bâtiments achevés].
	var grid: Dictionary = {}
	for candidate in built:
		var b: SimWorld.Building = candidate as SimWorld.Building
		var key: int = (int(b.center.y) / BLOCK) * 4096 + int(b.center.x) / BLOCK
		var cell: Array = grid.get(key, [0, 0.0, 0]) as Array
		cell[0] = int(cell[0]) + 1
		if b.complete:
			cell[1] = float(cell[1]) + float(b.city.get("crime", 0.0))
			cell[2] = int(cell[2]) + 1
		grid[key] = cell
	return grid

static func _neighbourhood(grid: Dictionary, center: Vector2) -> Array:
	var bx: int = int(center.x) / BLOCK
	var by: int = int(center.y) / BLOCK
	var count: int = 0
	var crime: float = 0.0
	var done: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell: Array = grid.get((by + dy) * 4096 + bx + dx, []) as Array
			if cell.is_empty():
				continue
			count += int(cell[0])
			crime += float(cell[1])
			done += int(cell[2])
	return [count, crime / float(done) if done > 0 else 0.0]

static func site_lack(w: SimWorld, team: int, origin: Vector2i, local_crime: float, danger: Dictionary) -> String:
	## Pourquoi une parcelle zonée ne peut pas accueillir de chantier (vide si elle le peut).
	var size: int = UrbanRules.PARCEL
	var ruin: SimWorld.Building = _ruin_at(w, team, origin)
	if ruin == null and not w.footprint_free(origin, size):
		return "parcelle occupée"
	if not UrbanZoning.access(w, team, origin, size):
		return "aucune route reliée au centre"
	if local_crime >= UrbanRules.UNSAFE_CRIME:
		return "voisinage trop dangereux"
	if danger.has((origin.y / BLOCK) * 4096 + origin.x / BLOCK):
		return "ennemi à proximité"
	return ""

static func _ruin_at(w: SimWorld, team: int, origin: Vector2i) -> SimWorld.Building:
	var id: int = int(w._occupied.get(origin, -1))
	if id < 0 or not w.buildings.has(id):
		return null
	var b: SimWorld.Building = w.buildings[id] as SimWorld.Building
	if b.type == "ruine" and b.team == team and b.cell == origin:
		return b
	return null

static func _new_sites(w: SimWorld, team: int, dem: Dictionary, open_sites: int, ctx: Dictionary) -> void:
	var t: SimWorld.Team = w.teams[team]
	var max_sites: int = mini(UrbanRules.MAX_SITES, UrbanRules.MAX_SITES_BASE + int(ctx.get("habitants", 0)) / UrbanRules.HABITANTS_PER_SITE)
	var free: int = max_sites - open_sites
	t.city["sites"] = [open_sites, max_sites]
	if free <= 0:
		return
	var list: PackedInt32Array = UrbanZoning.parcels(w, team)
	if list.is_empty():
		return
	# Voisinage : bâtiments de zone (regroupement organique) et criminalité locale, par blocs ; ennemis proches.
	var built: Array = []
	for candidate in w.team_buildings(team):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.is_zone(b.type):
			built.append(b)
	var grid: Dictionary = _neighbour_grid(built)
	var danger: Dictionary = _danger_blocks(w, team)
	var centres: Array = w.team_buildings(team, "centre", true)
	var period: int = w.tick / UrbanRules.PERIOD
	var kinds: Array = ["zone_r", "zone_c", "zone_i", "zone_a"]
	kinds.sort_custom(func(a, b) -> bool: return float(dem.get(a, 0.0)) > float(dem.get(b, 0.0)))
	var lacks: Dictionary = {}
	for kind_value in kinds:
		if free <= 0:
			break
		var kind: String = String(kind_value)
		if float(dem.get(kind, 0.0)) < UrbanRules.DEMAND_MIN:
			lacks[kind] = "pas de demande"
			continue
		var best_score: float = -INF
		var best: Vector2i = Vector2i(-1, -1)
		var best_ruin: bool = false
		var last_lack: String = "aucune parcelle zonée"
		var scanned: int = 0
		var start: int = (period * 37) % list.size()
		for k in list.size():
			if scanned >= SCAN_PER_KIND:
				break
			var idx: int = list[(start + k) % list.size()]
			var origin: Vector2i = Vector2i(idx % w.map_size, idx / w.map_size)
			var code: int = UrbanZoning.parcel_code(w, team, origin)
			if code == 0 or String((UrbanZoning.KINDS[code] as Dictionary)["building"]) != kind:
				continue
			scanned += 1
			var center: Vector2 = Vector2(origin) + Vector2.ONE * float(UrbanRules.PARCEL) * 0.5
			var near: Array = _neighbourhood(grid, center)
			var why: String = site_lack(w, team, origin, float(near[1]), danger)
			if why != "":
				last_lack = why
				continue
			var hub: float = 99.0
			for cc in centres:
				hub = minf(hub, (cc as SimWorld.Building).center.distance_to(center))
			var ruin: bool = _ruin_at(w, team, origin) != null
			var score: float = float(int(near[0])) * 2.0 - minf(hub, 30.0) * 0.08 + UrbanCity.roll(w, idx, 7) * 3.0 + (1.5 if ruin else 0.0)
			if score > best_score:
				best_score = score
				best = origin
				best_ruin = ruin
		if best.x < 0:
			lacks[kind] = last_lack
			continue
		var cost: Dictionary = w.scaled_cost(UrbanRules.GROW_COST[kind] as Dictionary)
		if best_ruin:
			for res in cost.keys():
				cost[res] = float(cost[res]) * UrbanRules.REBUILD_COST_MULT
		if not w._can_pay(team, cost):
			lacks[kind] = w._missing_text(team, cost)
			continue
		w._pay(team, cost)
		var reconstruction: bool = false
		if best_ruin:
			var ruin_b: SimWorld.Building = _ruin_at(w, team, best)
			ruin_b.city["no_ruin"] = true
			w._destroy_building(ruin_b, team)
			reconstruction = true
		var b: SimWorld.Building = w.spawn_building(team, kind, best, false)
		var h: int = hash([w.seed_value, best.x, best.y, w.tick])
		b.city = {"grown": true, "level": 1, "density": 0.0, "style_age": clampi(t.age, 1, 10), "variant": h & 0xff,
			"rot": (h >> 8) & 3, "state": "construction", "rebuilt": reconstruction, "born": w.tick}
		free -= 1
		t.city["built_total"] = int(t.city.get("built_total", 0)) + 1
		lacks[kind] = ""
	t.city["grow_lack"] = lacks
