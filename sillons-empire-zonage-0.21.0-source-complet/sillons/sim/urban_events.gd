class_name UrbanEvents
extends RefCounted
## 0.20 — Événements urbains extensibles : séisme, inondation, tempête, crise économique, vague de migration.
## Chaque événement est décrit par des données (zone touchée, dégâts, feu, inondation, production, demande, densité,
## durée) : ajouter un événement revient à ajouter une entrée dans EVENTS, sans nouveau code. Tirage déterministe
## (graine, tick, camp), mêmes règles pour le joueur et l'IA ; effets sur l'état réel (vie des bâtiments, feu,
## production, demande, habitants). Valeurs PROVISOIRES.

const CHECK_EVERY: int = 15            # un tirage toutes les 15 périodes (30 s de jeu)
const MIN_BUILDINGS: int = 6           # une ville de moins de 6 bâtiments de zone n'est pas concernée
const MAX_ACTIVE: int = 2
const GRACE_TICKS: int = 9000          # aucun événement tiré pendant les 15 premières minutes de la partie

## Vocabulaire des effets :
##  area      "epicentre" (autour d'un bâtiment tiré au sort), "water" (bâtiments à moins de `near_water` cases de
##            l'eau), "all" (toute la ville), "homes" (habitat seulement)
##  radius    rayon de la zone touchée (epicentre, water)
##  damage    part de la vie perdue (atténuée avec la distance à l'épicentre ; × matériau si material = true)
##  fire      chance qu'un bâtiment touché prenne feu
##  extinguish  éteint les incendies en cours
##  flood     secondes de production arrêtée pour les bâtiments touchés
##  output    multiplicateur de production pour `kinds` pendant `duration`
##  demand    décalage de la demande pour `kinds` pendant `duration`
##  density   changement immédiat de densité de l'habitat touché (habitants qui arrivent ou partent)
##  condition "always", "water" (la ville touche l'eau), "crime" (criminalité moyenne ≥ 35), "growth" (demande
##            d'habitat positive)
const EVENTS := {
	"seisme": {"label": "Séisme", "min_age": 1, "chance": 0.006, "area": "epicentre", "radius": 7.0, "damage": 0.35,
		"fire": 0.15, "condition": "always", "advice": "réparez vite et gardez des pompiers ou des puits près des quartiers"},
	"inondation": {"label": "Inondation", "min_age": 1, "chance": 0.010, "area": "water", "radius": 6.0, "near_water": 3,
		"damage": 0.10, "flood": 40.0, "condition": "water", "advice": "les bâtiments au bord de l'eau reprennent après la décrue"},
	"tempete": {"label": "Tempête", "min_age": 1, "chance": 0.010, "area": "all", "damage": 0.08, "material": true,
		"extinguish": true, "condition": "always", "advice": "les maisons de bois souffrent le plus ; les feux sont éteints"},
	"crise": {"label": "Crise économique", "min_age": 3, "chance": 0.007, "area": "none", "duration": 120.0,
		"output": 0.7, "demand": -0.5, "kinds": ["zone_c", "zone_i"], "condition": "always",
		"advice": "commerce et industrie ralentissent pendant 2 minutes"},
	"migration": {"label": "Vague de migration", "min_age": 2, "chance": 0.010, "area": "homes", "density": 0.5,
		"duration": 60.0, "demand": 0.3, "kinds": ["zone_r"], "condition": "growth",
		"advice": "de nouveaux habitants arrivent : prévoyez emplois et nourriture"},
	"exode": {"label": "Exode", "min_age": 2, "chance": 0.010, "area": "homes", "density": -0.6, "condition": "crime",
		"advice": "des habitants fuient l'insécurité : police et emplois"},
}

static func active(t: SimWorld.Team) -> Array:
	return t.city.get("events", []) as Array

static func step(w: SimWorld, team: int) -> void:
	## Appelé après le calcul de la ville du camp (même cadence, mêmes échelles de temps).
	var t: SimWorld.Team = w.teams[team]
	if t.city.is_empty():
		return
	var list: Array = active(t)
	var kept: Array = []
	for raw in list:
		var e: Dictionary = raw as Dictionary
		e["left"] = float(e.get("left", 0.0)) - UrbanCity.period_s()
		if float(e["left"]) > 0.0:
			kept.append(e)
		else:
			w.emit("ville", team, "Fin : %s" % String((EVENTS.get(String(e["key"]), {}) as Dictionary).get("label", e["key"])), {})
	t.city["events"] = kept
	_tick_floods(w, team)
	var period: int = floori(float(w.tick) / float(UrbanRules.PERIOD))
	var scale: float = float(w.rule("events_scale", 1.0))
	if scale <= 0.0:
		return
	if posmod(period, CHECK_EVERY) != posmod(team * 5, CHECK_EVERY) and not (w.urban_far and posmod(period, CHECK_EVERY) < UrbanRules.FAR_EVERY):
		return
	if w.tick < GRACE_TICKS or kept.size() >= MAX_ACTIVE or _zone_count(w, team) < MIN_BUILDINGS:
		return
	var keys: Array = EVENTS.keys()
	keys.sort()
	for index in keys.size():
		var key: String = String(keys[index])
		var def: Dictionary = EVENTS[key] as Dictionary
		if t.age < int(def.get("min_age", 1)) or _running(t, key) or not _condition(w, team, def):
			continue
		var draw: float = float(hash([w.seed_value, team, period, index, 7121]) & 0xffffff) / float(0xffffff)
		if draw < float(def["chance"]) * float(CHECK_EVERY) / 15.0 * scale:
			start(w, team, key)
			return

static func start(w: SimWorld, team: int, key: String, at: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	## Déclenche l'événement (tirage ou recette). Renvoie le bilan : bâtiments touchés, feux allumés, densité.
	var def: Dictionary = EVENTS.get(key, {}) as Dictionary
	var t: SimWorld.Team = w.teams[team]
	if def.is_empty():
		return {}
	var hit: Array = _targets(w, team, def, at)
	var fires: int = 0
	var moved: float = 0.0
	for pair in hit:
		var b: SimWorld.Building = pair[0] as SimWorld.Building
		var weight: float = float(pair[1])
		var c: Dictionary = b.city
		var damage: float = float(def.get("damage", 0.0)) * weight
		if bool(def.get("material", false)):
			damage *= UrbanRules.material(int(c.get("style_age", clampi(t.age, 1, 10))))
		if damage > 0.0:
			# Un événement abîme sans raser d'un coup : le bâtiment garde au moins 10 % de sa vie.
			b.hp = maxf(minf(b.hp, b.max_hp * 0.1), b.hp - b.max_hp * damage)
			b.hit_tick = w.tick
			c["event_hit"] = w.tick
		if float(def.get("fire", 0.0)) > 0.0 and float(c.get("burning", 0.0)) <= 0.0 and b.complete:
			if UrbanCity.roll(w, b.id, 31) < float(def["fire"]) * weight:
				c["burning"] = UrbanRules.FIRE_DURATION
				c["fire_i"] = UrbanRules.FIRE_START_INTENSITY
				c["fire_tick"] = w.tick
				c["fire_cause"] = String(def["label"]).to_lower()
				t.city["fires_total"] = int(t.city.get("fires_total", 0)) + 1
				fires += 1
		if bool(def.get("extinguish", false)) and float(c.get("burning", 0.0)) > 0.0:
			c["burning"] = 0.0
		if float(def.get("flood", 0.0)) > 0.0:
			c["flooded"] = maxf(float(c.get("flooded", 0.0)), float(def["flood"]))
		if absf(float(def.get("density", 0.0))) > 0.0 and b.type == "zone_r" and b.complete:
			var before: float = float(c.get("density", 1.0))
			var level: float = float(int(c.get("level", 1)))
			var after: float = clampf(before + float(def["density"]), UrbanRules.MIN_DENSITY, level)
			c["density"] = after
			moved += after - before
	if float(def.get("duration", 0.0)) > 0.0:
		var list: Array = active(t)
		list.append({"key": key, "left": float(def["duration"]), "since": w.tick})
		t.city["events"] = list
	t.city["events_total"] = int(t.city.get("events_total", 0)) + 1
	t.city["last_event"] = {"key": key, "tick": w.tick, "hit": hit.size(), "fires": fires}
	var text: String = "%s : %d bâtiment(s) touché(s)%s — %s" % [String(def["label"]), hit.size(), (", %d incendie(s)" % fires) if fires > 0 else "", String(def.get("advice", ""))]
	if hit.is_empty() and float(def.get("duration", 0.0)) > 0.0:
		text = "%s — %s" % [String(def["label"]), String(def.get("advice", ""))]
	var pos: Vector2 = (hit[0][0] as SimWorld.Building).center if not hit.is_empty() else Vector2(-1, -1)
	w.emit("evenement_urbain", team, text, {"event": key, "pos": pos} if pos.x >= 0.0 else {"event": key})
	return {"key": key, "hit": hit.size(), "fires": fires, "density": moved}

static func output_mult(t: SimWorld.Team, b: SimWorld.Building) -> float:
	## Production d'un bâtiment sous l'effet des événements en cours (crise, inondation).
	if float(b.city.get("flooded", 0.0)) > 0.0:
		return 0.0
	var mult: float = 1.0
	for raw in active(t):
		var def: Dictionary = EVENTS.get(String((raw as Dictionary)["key"]), {}) as Dictionary
		if def.has("output") and (def.get("kinds", []) as Array).has(b.type):
			mult *= float(def["output"])
	return mult

static func demand_bias(t: SimWorld.Team, kind: String) -> float:
	var bias: float = 0.0
	for raw in active(t):
		var def: Dictionary = EVENTS.get(String((raw as Dictionary)["key"]), {}) as Dictionary
		if def.has("demand") and (def.get("kinds", []) as Array).has(kind):
			bias += float(def["demand"])
	return bias

static func labels(t: SimWorld.Team) -> String:
	var out: Array = []
	for raw in active(t):
		var e: Dictionary = raw as Dictionary
		out.append("%s (%d s)" % [String((EVENTS.get(String(e["key"]), {}) as Dictionary).get("label", e["key"])), int(ceilf(float(e["left"])))])
	return ", ".join(out)

# ---------------------------------------------------------------- détails

static func _running(t: SimWorld.Team, key: String) -> bool:
	for raw in active(t):
		if String((raw as Dictionary)["key"]) == key:
			return true
	return false

static func _zones(w: SimWorld, team: int) -> Array:
	var out: Array = []
	for candidate in UrbanCity._sorted(w.team_buildings(team)):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.is_zone(b.type):
			out.append(b)
	return out

static func _zone_count(w: SimWorld, team: int) -> int:
	return _zones(w, team).size()

static func _water_near(w: SimWorld, b: SimWorld.Building, reach: int) -> bool:
	for dy in range(-reach, b.size + reach):
		for dx in range(-reach, b.size + reach):
			var c: Vector2i = b.cell + Vector2i(dx, dy)
			if w.in_map(c) and w.terrain[w.idx(c)] == SimWorld.TERRAIN_WATER:
				return true
	return false

static func _condition(w: SimWorld, team: int, def: Dictionary) -> bool:
	var t: SimWorld.Team = w.teams[team]
	match String(def.get("condition", "always")):
		"water":
			for candidate in _zones(w, team):
				if _water_near(w, candidate as SimWorld.Building, int(def.get("near_water", 3))):
					return true
			return false
		"crime":
			return float(t.city.get("crime_avg", 0.0)) >= 35.0
		"growth":
			return float((t.city.get("demand", {}) as Dictionary).get("zone_r", 0.0)) > 0.0 and not bool(t.city.get("famine", false))
	return true

static func _targets(w: SimWorld, team: int, def: Dictionary, at: Vector2i) -> Array:
	## [bâtiment, poids 0–1] des bâtiments touchés, dans l'ordre des identifiants (déterministe).
	var zones: Array = _zones(w, team)
	var out: Array = []
	match String(def.get("area", "none")):
		"all":
			for candidate in zones:
				out.append([candidate, 1.0])
		"homes":
			for candidate in zones:
				if (candidate as SimWorld.Building).type == "zone_r":
					out.append([candidate, 1.0])
		"epicentre", "water":
			var pool: Array = []
			for candidate in zones:
				if String(def["area"]) == "epicentre" or _water_near(w, candidate as SimWorld.Building, int(def.get("near_water", 3))):
					pool.append(candidate)
			if pool.is_empty():
				return out
			var centre: Vector2 = Vector2(at) + Vector2(0.5, 0.5)
			if at.x < 0:
				var pick: int = int(hash([w.seed_value, team, w.tick, 4409]) & 0x7fffffff) % pool.size()
				centre = (pool[pick] as SimWorld.Building).center
			var radius: float = float(def.get("radius", 6.0))
			for candidate in zones:
				var b: SimWorld.Building = candidate as SimWorld.Building
				var d: float = b.center.distance_to(centre)
				if d <= radius and (String(def["area"]) == "epicentre" or pool.has(b)):
					out.append([b, clampf(1.0 - d / (radius + 1.0), 0.2, 1.0)])
	return out

static func _tick_floods(w: SimWorld, team: int) -> void:
	for candidate in _zones(w, team):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if float(b.city.get("flooded", 0.0)) > 0.0:
			b.city["flooded"] = maxf(0.0, float(b.city["flooded"]) - UrbanCity.period_s())
			if float(b.city["flooded"]) <= 0.0:
				b.city.erase("flooded")
