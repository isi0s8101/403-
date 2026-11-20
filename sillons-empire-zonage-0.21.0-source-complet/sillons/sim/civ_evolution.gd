class_name CivEvolution
extends RefCounted
## 0.16 — Évolution de la civilisation, par composition avec SimWorld.
## Actif seulement si la règle de monde "civ_evolution" est vraie (nouvelles campagnes) : les scénarios et
## parties historiques gardent exactement leurs règles. Tout passe par des commandes simulées et le pas fixe ;
## un refus n'a aucun effet. L'état de chaque camp est dans Team.civ (sauvegardé avec le monde) et partagé
## par référence entre les mondes d'un même empire dans une campagne (StarCampaign.civ_states).
##
## Voies : un choix par époque (II, V, VIII) -> bonus permanent + unité spéciale.
## Monuments : pour passer à l'âge N, bâtir un des deux monuments de l'âge N ; son bonus dure tant qu'il est debout.
## Améliorations : lignes à trois niveaux (forge, centre, usine, aérodrome).
## Héros : un par époque, unique, aura sur les troupes proches, rappel après une attente.
## Pouvoirs : points gagnés en détruisant des forces ennemies, déblocage permanent, usage avec recharge.

const MOD_KEYS := ["attack_all", "attack_melee", "attack_ranged", "attack_siege", "attack_vehicle", "attack_air",
	"armor_military", "armor_infantry", "armor_cavalry", "armor_vehicle", "armor_building",
	"gather_all", "gather_food", "gather_wood", "gather_ore", "trade", "train_speed", "research_speed",
	"build_speed", "power_gain", "upgrade_discount"]
const MAX_JOBS: int = 32
const MAX_EFFECTS: int = 32

static func enabled(w: SimWorld) -> bool:
	return w != null and bool(w.rules.get("civ_evolution", false))

static func blank() -> Dictionary:
	return {"v": 1, "voies": {}, "upgrades": {}, "jobs": [], "monuments": {}, "heroes": {}, "points": 0.0, "earned": 0.0,
		"powers": {}, "effects": [], "log": []}

static func state(w: SimWorld, team: int) -> Dictionary:
	var t: SimWorld.Team = w.teams[team]
	if not t.civ.has("v"):
		var fresh: Dictionary = blank()
		for key in fresh.keys():
			t.civ[key] = fresh[key]
	return t.civ

static func sanitize(civ: Dictionary) -> void:
	## Remet un état chargé dans des bornes sûres (types, tailles) ; ne crée aucun avantage.
	var fresh: Dictionary = blank()
	for key in fresh.keys():
		if not civ.has(key) or typeof(civ[key]) != typeof(fresh[key]):
			civ[key] = fresh[key]
	for epoch in (civ["voies"] as Dictionary).keys():
		if not CivRules.VOIES.has(epoch) or not (CivRules.VOIES[epoch] as Dictionary).has(String(civ["voies"][epoch])):
			(civ["voies"] as Dictionary).erase(epoch)
	for key in (civ["upgrades"] as Dictionary).keys():
		if not CivRules.UPGRADES.has(key):
			(civ["upgrades"] as Dictionary).erase(key)
		else:
			civ["upgrades"][key] = clampi(int(civ["upgrades"][key]), 0, 3)
	for key in (civ["monuments"] as Dictionary).keys():
		if not CivRules.MONUMENTS.has(key):
			(civ["monuments"] as Dictionary).erase(key)
		else:
			civ["monuments"][key] = clampi(int(civ["monuments"][key]), 0, 16)
	for key in (civ["powers"] as Dictionary).keys():
		if not CivRules.POWERS.has(key) or not civ["powers"][key] is Dictionary:
			(civ["powers"] as Dictionary).erase(key)
	for key in (civ["heroes"] as Dictionary).keys():
		if not CivRules.HEROES.has(key) or not civ["heroes"][key] is Dictionary:
			(civ["heroes"] as Dictionary).erase(key)
	civ["points"] = clampf(float(civ["points"]), 0.0, CivRules.POINTS_MAX)
	if (civ["jobs"] as Array).size() > MAX_JOBS:
		civ["jobs"] = (civ["jobs"] as Array).slice(0, MAX_JOBS)
	if (civ["effects"] as Array).size() > MAX_EFFECTS:
		civ["effects"] = (civ["effects"] as Array).slice(0, MAX_EFFECTS)
	if (civ["log"] as Array).size() > 40:
		civ["log"] = (civ["log"] as Array).slice(-40)
	# Pas d'incrément de "v" : le cache des modificateurs vit dans SimWorld.civ_cache et repart vide au chargement.

static func _bump(civ: Dictionary) -> void:
	civ["v"] = int(civ.get("v", 1)) + 1

static func _log(w: SimWorld, civ: Dictionary, team: int, text: String) -> void:
	var log: Array = civ["log"] as Array
	log.append({"tick": w.tick, "text": text})
	if log.size() > 40:
		log.pop_front()
	w.emit("civilisation", team, text)

# ------------------------------------------------------------------ modificateurs
static func mods(w: SimWorld, team: int) -> Dictionary:
	var civ: Dictionary = state(w, team)
	var cache: Dictionary = w.civ_cache.get("mods", {}) as Dictionary
	var entry: Dictionary = cache.get(team, {}) as Dictionary
	if not entry.is_empty() and int(entry["v"]) == int(civ["v"]):
		return entry["m"] as Dictionary
	var m: Dictionary = {}
	for key in MOD_KEYS:
		m[key] = 0.0
	for epoch in (civ["voies"] as Dictionary).keys():
		var bonus: Dictionary = ((CivRules.VOIES[epoch] as Dictionary)[String(civ["voies"][epoch])] as Dictionary)["bonus"] as Dictionary
		for key in bonus.keys():
			m[key] = float(m[key]) + float(bonus[key])
	for monument in (civ["monuments"] as Dictionary).keys():
		if int(civ["monuments"][monument]) <= 0:
			continue
		var bonus: Dictionary = (CivRules.MONUMENTS[monument] as Dictionary)["bonus"] as Dictionary
		for key in bonus.keys():
			m[key] = float(m[key]) + float(bonus[key])
	for upgrade in (civ["upgrades"] as Dictionary).keys():
		var effect: Dictionary = (CivRules.UPGRADES[upgrade] as Dictionary)["effect"] as Dictionary
		for key in effect.keys():
			m[key] = float(m[key]) + float(effect[key]) * float(civ["upgrades"][upgrade])
	cache[team] = {"v": int(civ["v"]), "m": m}
	w.civ_cache["mods"] = cache
	return m

static func mod(w: SimWorld, team: int, key: String) -> float:
	if not enabled(w) or team < 0 or team >= w.teams.size() or team == SimWorld.TEAM_NEUTRAL:
		return 0.0
	return float(mods(w, team).get(key, 0.0))

static func _class(type: String) -> String:
	if Rules.unit_has(type, "air"):
		return "air"
	if Rules.unit_has(type, "vehicle"):
		return "vehicle"
	if Rules.unit_has(type, "siege"):
		return "siege"
	if Rules.unit_has(type, "ranged"):
		return "ranged"
	return "melee"

static func attack_mult(w: SimWorld, u: SimWorld.Unit, _target) -> float:
	if not enabled(w) or not Rules.unit_has(u.type, "military"):
		return 1.0
	var percent: float = mod(w, u.team, "attack_all") + mod(w, u.team, "attack_" + _class(u.type))
	percent += _hero_aura(w, u, "attack")
	percent += _effect_value(w, u.team, "cri", u.pos)
	return maxf(0.1, 1.0 + percent / 100.0)

static func defense_mult(w: SimWorld, target) -> float:
	if not enabled(w):
		return 1.0
	var team: int = int(target.team)
	if team < 0 or team >= w.teams.size() or team == SimWorld.TEAM_NEUTRAL:
		return 1.0
	var armor: float = 0.0
	if target is SimWorld.Unit:
		var u: SimWorld.Unit = target as SimWorld.Unit
		if not Rules.unit_has(u.type, "military"):
			return 1.0
		armor = mod(w, team, "armor_military") + _hero_aura(w, u, "armor")
		if Rules.unit_has(u.type, "vehicle"):
			armor += mod(w, team, "armor_vehicle")
		elif Rules.unit_has(u.type, "cavalry"):
			armor += mod(w, team, "armor_cavalry")
		elif Rules.unit_has(u.type, "infantry"):
			armor += mod(w, team, "armor_infantry")
	else:
		armor = mod(w, team, "armor_building") + _effect_value(w, team, "shield", (target as SimWorld.Building).center)
	return clampf(1.0 - armor / 100.0, 0.25, 1.0)

static func gather_mult(w: SimWorld, team: int, resource: String) -> float:
	if not enabled(w):
		return 1.0
	return 1.0 + (mod(w, team, "gather_all") + mod(w, team, "gather_" + resource)) / 100.0

static func speed_mult(w: SimWorld, team: int, key: String) -> float:
	## build_speed, train_speed, research_speed, trade, power_gain
	if not enabled(w):
		return 1.0
	return 1.0 + mod(w, team, key) / 100.0

static func _hero_aura(w: SimWorld, u: SimWorld.Unit, kind: String) -> float:
	if Rules.unit_has(u.type, "hero"):
		return 0.0
	var heroes: Array = (w.civ_cache.get("heroes", {}) as Dictionary).get(u.team, []) as Array
	for entry in heroes:
		if u.pos.distance_squared_to(entry["pos"]) <= float(entry["r2"]):
			return float(entry[kind])
	return 0.0

static func _effect_value(w: SimWorld, team: int, kind: String, pos: Vector2) -> float:
	var civ: Dictionary = state(w, team)
	var best: float = 0.0
	var sector: String = String(w.rules.get("sector", ""))
	for effect in civ["effects"]:
		if String(effect["kind"]) == kind and String(effect.get("sector", "")) == sector and int(effect.get("until", 0)) > w.tick:
			if pos.distance_squared_to(effect["pos"]) <= float(effect["radius"]) * float(effect["radius"]):
				best = maxf(best, float(effect["value"]))
	return best

# ------------------------------------------------------------------ règles de construction et de formation
static func civ_unit(kind: String) -> bool:
	return Rules.UNITS.has(kind) and bool((Rules.UNITS[kind] as Dictionary).get("civ", false))

static func civ_building(kind: String) -> bool:
	return Rules.BUILDINGS.has(kind) and bool((Rules.BUILDINGS[kind] as Dictionary).get("civ", false))

static func unit_voie(kind: String) -> Array:
	## [époque, voie] dont c'est l'unité spéciale, ou [] .
	for epoch in CivRules.VOIES.keys():
		for voie in (CivRules.VOIES[epoch] as Dictionary).keys():
			if String(((CivRules.VOIES[epoch] as Dictionary)[voie] as Dictionary)["unit"]) == kind:
				return [String(epoch), String(voie)]
	return []

static func visible_unit(w: SimWorld, team: int, kind: String) -> bool:
	## Pour l'interface : n'affiche une unité de voie que si cette voie est celle du camp (les héros restent visibles).
	if not civ_unit(kind):
		return true
	if not enabled(w):
		return false
	if CivRules.HEROES.has(kind):
		return true
	var origin: Array = unit_voie(kind)
	return not origin.is_empty() and String((state(w, team)["voies"] as Dictionary).get(origin[0], "")) == String(origin[1])

static func visible_building(w: SimWorld, team: int, kind: String) -> bool:
	if not UrbanCity.visible_building(w, team, kind): return false
	if not civ_building(kind):
		return true
	if not enabled(w):
		return false
	var target: int = int((Rules.BUILDINGS[kind] as Dictionary).get("monument", 0))
	return target == 0 or target == (w.teams[team] as SimWorld.Team).age + 1

static func train_lack(w: SimWorld, team: int, kind: String) -> String:
	if not civ_unit(kind):
		return ""
	if not enabled(w):
		return "réservé aux parties avec l'évolution de la civilisation"
	var civ: Dictionary = state(w, team)
	if CivRules.HEROES.has(kind):
		var record: Dictionary = (civ["heroes"] as Dictionary).get(kind, {}) as Dictionary
		var status: String = String(record.get("state", "none"))
		if status in ["alive", "queued"]:
			return "héros déjà en service : un seul à la fois"
		if status == "dead":
			var wait: float = recall_wait(w, team, kind)
			if wait > 0.0:
				return "rappel du héros possible dans %d s" % ceili(wait)
		return ""
	var origin: Array = unit_voie(kind)
	if origin.is_empty():
		return ""
	var chosen: String = String((civ["voies"] as Dictionary).get(origin[0], ""))
	if chosen != String(origin[1]):
		return "unité de la %s (%s)" % [String(CivRules.VOIE_LABEL[origin[1]]).to_lower(), String(CivRules.EPOCH_LABEL[origin[0]])]
	return ""

static func troop_upgrade_allowed(w: SimWorld, team: int, kind: String) -> bool:
	if not civ_unit(kind):
		return true
	if CivRules.HEROES.has(kind):
		return false
	return train_lack(w, team, kind).is_empty()

static func recall_wait(w: SimWorld, team: int, kind: String) -> float:
	var record: Dictionary = (state(w, team)["heroes"] as Dictionary).get(kind, {}) as Dictionary
	if String(record.get("state", "")) != "dead":
		return 0.0
	var delay: float = float((CivRules.HEROES[kind] as Dictionary)["recall"])
	if String((state(w, team)["voies"] as Dictionary).get(String((CivRules.HEROES[kind] as Dictionary)["epoch"]), "")) == "marchande":
		delay *= 0.5
	return maxf(0.0, delay - float(w.tick - int(record.get("dead_tick", 0))) / float(Rules.TICK_RATE))

static func hero_name(w: SimWorld, team: int, kind: String) -> String:
	var definition: Dictionary = CivRules.HEROES[kind] as Dictionary
	var voie: String = String((state(w, team)["voies"] as Dictionary).get(String(definition["epoch"]), ""))
	return String((definition["names"] as Dictionary).get(voie, (definition["names"] as Dictionary)[""]))

static func build_lack(w: SimWorld, team: int, kind: String) -> String:
	if not civ_building(kind):
		return ""
	if not enabled(w):
		return "réservé aux parties avec l'évolution de la civilisation"
	var target: int = int((Rules.BUILDINGS[kind] as Dictionary).get("monument", 0))
	if target == 0:
		return ""
	var t: SimWorld.Team = w.teams[team]
	if t.age >= target:
		return "âge %s déjà atteint" % J13Rules.roman(target)
	if t.age != target - 1:
		return "monument de l'âge %s : âge %s requis" % [J13Rules.roman(target), J13Rules.roman(target - 1)]
	if target > int(w.rule("max_age", 10)):
		return "âge maximal de la partie"
	if w.team_buildings(team, "centre", true).is_empty():
		return "centre de commandement achevé requis"
	if Rules.AGE_UP.has(target):
		var objective: String = String((w.rule("age_up_%d" % target, Rules.AGE_UP[target]) as Dictionary)["objective"])
		if not w.objective_done(team, objective):
			return "objectif : " + String(Rules.OBJECTIVE_LABEL.get(objective, objective))
	for other in CivRules.monuments_for(target):
		if not w.team_buildings(team, String(other)).is_empty():
			return "un seul monument par âge : %s déjà choisi" % String((Rules.BUILDINGS[other] as Dictionary)["label"])
	return ""

static func age_note(w: SimWorld, team: int) -> String:
	var target: int = (w.teams[team] as SimWorld.Team).age + 1
	var names: PackedStringArray = PackedStringArray()
	for key in CivRules.monuments_for(target):
		names.append(String((Rules.BUILDINGS[key] as Dictionary)["label"]).get_slice(" (", 0))
	if names.is_empty():
		return "âge maximal atteint"
	return "bâtir un monument : " + " ou ".join(names)

# ------------------------------------------------------------------ événements de la simulation
static func on_building_complete(w: SimWorld, b: SimWorld.Building) -> void:
	if not enabled(w) or b.team == SimWorld.TEAM_NEUTRAL or not CivRules.MONUMENTS.has(b.type):
		return
	var civ: Dictionary = state(w, b.team)
	civ["monuments"][b.type] = int((civ["monuments"] as Dictionary).get(b.type, 0)) + 1
	_bump(civ)
	var t: SimWorld.Team = w.teams[b.team]
	var target: int = int((CivRules.MONUMENTS[b.type] as Dictionary)["age"])
	var label: String = String((Rules.BUILDINGS[b.type] as Dictionary)["label"]).get_slice(" (", 0)
	if t.age == target - 1:
		t.age = target
		t.research = {}
		w.emit("age_atteint", b.team, "%s atteint l'âge %s grâce au monument : %s" % [t.name, Rules.AGES[t.age - 1]["name"], label], {"age": t.age})
	_log(w, civ, b.team, "Monument achevé : %s (%s)" % [label, String((CivRules.MONUMENTS[b.type] as Dictionary)["text"])])

static func on_building_lost(w: SimWorld, b: SimWorld.Building, by_team: int) -> void:
	if not enabled(w) or b.team == SimWorld.TEAM_NEUTRAL:
		return
	var civ: Dictionary = state(w, b.team)
	if b.complete and CivRules.MONUMENTS.has(b.type):
		civ["monuments"][b.type] = maxi(0, int((civ["monuments"] as Dictionary).get(b.type, 0)) - 1)
		_bump(civ)
		_log(w, civ, b.team, "Monument détruit : bonus perdu (l'âge reste acquis)")
	var sector: String = String(w.rules.get("sector", ""))
	for job in (civ["jobs"] as Array).duplicate():
		if int(job["building"]) == b.id and String(job.get("sector", "")) == sector:
			(civ["jobs"] as Array).erase(job)
			_log(w, civ, b.team, "Amélioration perdue : bâtiment détruit")
	for kind in b.queue:
		if CivRules.HEROES.has(String(kind)):
			((civ["heroes"] as Dictionary).get(String(kind), {}) as Dictionary)["state"] = "none"
	if by_team >= 0 and by_team < w.teams.size() and by_team != SimWorld.TEAM_NEUTRAL and w.factions.hostile(by_team, b.team):
		var value: float = CivRules.POINTS_PER_BUILDING * (3.0 if b.type == "centre" or CivRules.MONUMENTS.has(b.type) else 1.0)
		_gain(w, by_team, value)

static func on_unit_spawn(w: SimWorld, u: SimWorld.Unit) -> void:
	if not enabled(w) or not CivRules.HEROES.has(u.type):
		return
	var civ: Dictionary = state(w, u.team)
	civ["heroes"][u.type] = {"state": "alive", "dead_tick": 0}
	_log(w, civ, u.team, "Héros en service : %s" % hero_name(w, u.team, u.type))

static func on_train_queued(w: SimWorld, team: int, kind: String) -> void:
	if enabled(w) and CivRules.HEROES.has(kind):
		state(w, team)["heroes"][kind] = {"state": "queued", "dead_tick": 0}

static func on_train_cancelled(w: SimWorld, team: int, kind: String) -> void:
	if enabled(w) and CivRules.HEROES.has(kind):
		state(w, team)["heroes"][kind] = {"state": "none", "dead_tick": 0}

static func on_kill(w: SimWorld, u: SimWorld.Unit, by_team: int) -> void:
	if not enabled(w):
		return
	if CivRules.HEROES.has(u.type):
		var civ: Dictionary = state(w, u.team)
		civ["heroes"][u.type] = {"state": "dead", "dead_tick": w.tick}
		_log(w, civ, u.team, "Héros tombé : %s — rappel possible au centre après %d s" % [hero_name(w, u.team, u.type), ceili(recall_wait(w, u.team, u.type))])
	if by_team >= 0 and by_team < w.teams.size() and by_team != SimWorld.TEAM_NEUTRAL and w.factions.hostile(by_team, u.team):
		_gain(w, by_team, CivRules.POINTS_PER_POP * float(int(Rules.UNITS[u.type]["pop"])) * (3.0 if CivRules.HEROES.has(u.type) else 1.0))

static func _gain(w: SimWorld, team: int, base: float) -> void:
	var civ: Dictionary = state(w, team)
	var amount: float = base * speed_mult(w, team, "power_gain")
	civ["points"] = minf(CivRules.POINTS_MAX, float(civ["points"]) + amount)
	civ["earned"] = float(civ["earned"]) + amount

# ------------------------------------------------------------------ pas de simulation
static func step(w: SimWorld) -> void:
	if not enabled(w):
		return
	var sector: String = String(w.rules.get("sector", ""))
	var heroes: Dictionary = {}
	for u in w.units.values():
		if CivRules.HEROES.has(u.type):
			var definition: Dictionary = CivRules.HEROES[u.type] as Dictionary
			var voie: String = String((state(w, u.team)["voies"] as Dictionary).get(String(definition["epoch"]), ""))
			var radius: float = float(definition["aura"])
			var list: Array = heroes.get(u.team, []) as Array
			list.append({"pos": u.pos, "r2": radius * radius, "attack": float(CivRules.HERO_AURA["attack"]) + (10.0 if voie == "militaire" else 0.0),
				"armor": float(CivRules.HERO_AURA["armor"])})
			heroes[u.team] = list
			if voie == "savante" and w.tick % 10 == 0:
				for ally in w.units.values():
					if ally.team == u.team and ally != u and ally.hp < ally.max_hp and ally.pos.distance_squared_to(u.pos) <= radius * radius:
						ally.hp = minf(ally.max_hp, ally.hp + 2.0)
	w.civ_cache["heroes"] = heroes
	for team in w.faction_ids():
		if team == SimWorld.TEAM_NEUTRAL or (w.teams[team] as SimWorld.Team).eliminated:
			continue
		var civ: Dictionary = state(w, team)
		for job in (civ["jobs"] as Array).duplicate():
			if String(job.get("sector", "")) != sector:
				continue
			job["remaining"] = float(job["remaining"]) - Rules.DT * speed_mult(w, team, "research_speed")
			if float(job["remaining"]) <= 0.0:
				(civ["jobs"] as Array).erase(job)
				civ["upgrades"][String(job["key"])] = int(job["level"])
				_bump(civ)
				_log(w, civ, team, "Amélioration achevée : %s niveau %d" % [String((CivRules.UPGRADES[String(job["key"])] as Dictionary)["label"]), int(job["level"])])
		for effect in (civ["effects"] as Array).duplicate():
			if String(effect.get("sector", "")) != sector:
				continue
			if String(effect["kind"]) == "bomb" and int(effect["at"]) <= w.tick:
				(civ["effects"] as Array).erase(effect)
				_resolve_bombardment(w, team, effect)
			elif String(effect["kind"]) != "bomb" and int(effect.get("until", 0)) <= w.tick:
				(civ["effects"] as Array).erase(effect)

static func _resolve_bombardment(w: SimWorld, team: int, effect: Dictionary) -> void:
	var center: Vector2 = effect["pos"]
	var r2: float = float(effect["radius"]) * float(effect["radius"])
	var hit: int = 0
	for u in w.units.values().duplicate():
		if w.factions.hostile(team, u.team) and u.pos.distance_squared_to(center) <= r2:
			w._damage(u, float(effect["value"]), null)
			hit += 1
	for b in w.buildings.values().duplicate():
		if b.team != SimWorld.TEAM_NEUTRAL and w.factions.hostile(team, b.team) and b.center.distance_squared_to(center) <= r2 + float(b.size * b.size) * 0.25:
			w._damage(b, float(effect["value"]) * 0.5, null)
			hit += 1
	w.emit("civilisation", team, "Bombardement : %d cible(s) touchée(s)" % hit, {"pos": center})

# ------------------------------------------------------------------ commandes
static func command(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	if not enabled(w):
		return w._no("évolution de la civilisation inactive dans cette partie")
	var kind: String = String(cmd.get("t", ""))
	match kind:
		"civ_voie":
			return _choose_voie(w, team, String(cmd.get("epoch", "")), String(cmd.get("voie", "")))
		"civ_upgrade":
			return _start_upgrade(w, team, int(cmd.get("building", -1)), String(cmd.get("key", "")))
		"civ_unlock":
			return _unlock(w, team, String(cmd.get("power", "")))
		"civ_power":
			return _use_power(w, team, String(cmd.get("power", "")), cmd.get("pos", [-1, -1]))
	return w._no("ordre de civilisation inconnu")

static func pending_epoch(w: SimWorld, team: int) -> String:
	## Première époque atteinte dont la voie n'est pas encore choisie.
	if not enabled(w):
		return ""
	var civ: Dictionary = state(w, team)
	for epoch in CivRules.EPOCHS:
		if (w.teams[team] as SimWorld.Team).age >= int(CivRules.EPOCH_AGE[epoch]) and not (civ["voies"] as Dictionary).has(epoch):
			return String(epoch)
	return ""

static func _choose_voie(w: SimWorld, team: int, epoch: String, voie: String) -> Dictionary:
	if not CivRules.VOIES.has(epoch) or not (CivRules.VOIES[epoch] as Dictionary).has(voie):
		return w._no("voie inconnue")
	var civ: Dictionary = state(w, team)
	if (civ["voies"] as Dictionary).has(epoch):
		return w._no("voie de cette époque déjà choisie : choix définitif")
	if (w.teams[team] as SimWorld.Team).age < int(CivRules.EPOCH_AGE[epoch]):
		return w._no("âge %s requis pour choisir cette voie" % J13Rules.roman(int(CivRules.EPOCH_AGE[epoch])))
	civ["voies"][epoch] = voie
	_bump(civ)
	_log(w, civ, team, "%s : %s — %s" % [String(CivRules.EPOCH_LABEL[epoch]).get_slice(" (", 0), String(CivRules.VOIE_LABEL[voie]), String(((CivRules.VOIES[epoch] as Dictionary)[voie] as Dictionary)["text"])])
	return w._ok()

static func upgrade_status(w: SimWorld, team: int, b: SimWorld.Building, key: String) -> Dictionary:
	if not CivRules.UPGRADES.has(key):
		return {"ok": false, "reason": "amélioration inconnue"}
	var definition: Dictionary = CivRules.UPGRADES[key] as Dictionary
	if b == null or b.team != team or not b.complete or b.type != String(definition["building"]):
		return {"ok": false, "reason": "%s allié achevé requis" % String((Rules.BUILDINGS[String(definition["building"])] as Dictionary)["label"])}
	var civ: Dictionary = state(w, team)
	var level: int = int((civ["upgrades"] as Dictionary).get(key, 0)) + 1
	if level > 3:
		return {"ok": false, "reason": "niveau maximal", "level": 3}
	var sector: String = String(w.rules.get("sector", ""))
	for job in civ["jobs"]:
		if String(job["key"]) == key:
			return {"ok": false, "reason": "amélioration déjà en cours", "level": level}
		if int(job["building"]) == b.id and String(job.get("sector", "")) == sector:
			return {"ok": false, "reason": "ce bâtiment étudie déjà une amélioration", "level": level}
	var age_needed: int = int((definition["ages"] as Array)[level - 1])
	if (w.teams[team] as SimWorld.Team).age < age_needed:
		return {"ok": false, "reason": "âge %s requis" % J13Rules.roman(age_needed), "level": level}
	var cost: Dictionary = w.scaled_cost(CivRules.upgrade_cost(key, level, mod(w, team, "upgrade_discount")))
	if not w._can_pay(team, cost):
		return {"ok": false, "reason": w._missing_text(team, cost), "level": level, "cost": cost}
	return {"ok": true, "reason": "", "level": level, "cost": cost}

static func _start_upgrade(w: SimWorld, team: int, building_id: int, key: String) -> Dictionary:
	var b: SimWorld.Building = w.buildings.get(building_id) as SimWorld.Building
	var status: Dictionary = upgrade_status(w, team, b, key)
	if not bool(status["ok"]):
		return w._no(String(status["reason"]))
	var civ: Dictionary = state(w, team)
	if (civ["jobs"] as Array).size() >= MAX_JOBS:
		return w._no("trop d'améliorations en cours")
	w._pay(team, status["cost"])
	(civ["jobs"] as Array).append({"key": key, "level": int(status["level"]), "building": b.id, "sector": String(w.rules.get("sector", "")),
		"remaining": CivRules.upgrade_time(key, int(status["level"])), "total": CivRules.upgrade_time(key, int(status["level"]))})
	_log(w, civ, team, "Amélioration lancée : %s niveau %d" % [String((CivRules.UPGRADES[key] as Dictionary)["label"]), int(status["level"])])
	return w._ok()

static func unlock_status(w: SimWorld, team: int, power: String) -> Dictionary:
	if not CivRules.POWERS.has(power):
		return {"ok": false, "reason": "pouvoir inconnu"}
	var civ: Dictionary = state(w, team)
	if (civ["powers"] as Dictionary).has(power):
		return {"ok": false, "reason": "déjà débloqué"}
	var tier: int = int((CivRules.POWERS[power] as Dictionary)["tier"])
	if tier > 1:
		var below: bool = false
		for other in (civ["powers"] as Dictionary).keys():
			if int((CivRules.POWERS[other] as Dictionary)["tier"]) == tier - 1:
				below = true
		if not below:
			return {"ok": false, "reason": "débloquer d'abord un pouvoir de rang %d" % (tier - 1)}
	var price: float = float((CivRules.POWERS[power] as Dictionary)["unlock"])
	if float(civ["points"]) + 0.0001 < price:
		return {"ok": false, "reason": "%d points de commandement requis (%d disponibles)" % [ceili(price), floori(float(civ["points"]))]}
	return {"ok": true, "reason": ""}

static func _unlock(w: SimWorld, team: int, power: String) -> Dictionary:
	var status: Dictionary = unlock_status(w, team, power)
	if not bool(status["ok"]):
		return w._no(String(status["reason"]))
	var civ: Dictionary = state(w, team)
	civ["points"] = float(civ["points"]) - float((CivRules.POWERS[power] as Dictionary)["unlock"])
	civ["powers"][power] = {"ready_tick": 0}
	_log(w, civ, team, "Pouvoir débloqué : %s" % String((CivRules.POWERS[power] as Dictionary)["label"]))
	return w._ok()

static func power_wait(w: SimWorld, team: int, power: String) -> float:
	var record: Dictionary = (state(w, team)["powers"] as Dictionary).get(power, {}) as Dictionary
	return maxf(0.0, float(int(record.get("ready_tick", 0)) - w.tick) / float(Rules.TICK_RATE))

static func _use_power(w: SimWorld, team: int, power: String, raw_pos) -> Dictionary:
	var civ: Dictionary = state(w, team)
	if not CivRules.POWERS.has(power) or not (civ["powers"] as Dictionary).has(power):
		return w._no("pouvoir non débloqué")
	var wait: float = power_wait(w, team, power)
	if wait > 0.0:
		return w._no("pouvoir en recharge : %d s" % ceili(wait))
	if not (raw_pos is Array or raw_pos is Vector2):
		return w._no("cible invalide")
	var pos: Vector2 = w._v2(raw_pos)
	if not pos.is_finite() or pos.x < 0 or pos.y < 0 or pos.x >= w.map_size or pos.y >= w.map_size:
		return w._no("cible hors carte")
	var definition: Dictionary = CivRules.POWERS[power] as Dictionary
	var radius: float = float(definition["radius"])
	var sector: String = String(w.rules.get("sector", ""))
	var age: int = (w.teams[team] as SimWorld.Team).age
	match power:
		"ravitaillement":
			if not w.is_explored_by(team, pos):
				return w._no("zone inexplorée")
			var healed: int = 0
			for u in w.units.values():
				if u.team == team and u.hp < u.max_hp and u.pos.distance_squared_to(pos) <= radius * radius:
					u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.35)
					healed += 1
			if healed == 0:
				return w._no("aucune unité alliée blessée dans la zone")
			w.emit("civilisation", team, "Ravitaillement : %d unité(s) soignée(s)" % healed, {"pos": pos})
		"eclaireurs":
			w.orbital_scans.append({"team": team, "pos": pos, "until": w.tick + 300, "radius": radius})
			w.update_fog(true)
		"cri_ralliement":
			if not w.is_explored_by(team, pos):
				return w._no("zone inexplorée")
			if (civ["effects"] as Array).size() >= MAX_EFFECTS:
				return w._no("trop d'effets actifs")
			(civ["effects"] as Array).append({"kind": "cri", "sector": sector, "pos": pos, "radius": radius, "until": w.tick + 200, "value": 25.0})
		"renforts":
			var anchor = null
			for b in w.team_buildings(team, "", true):
				if b.center.distance_to(pos) <= radius:
					anchor = b
					break
			if anchor == null:
				return w._no("toucher près d'un de vos bâtiments achevés")
			var kind: String = CivRules.renfort_unit(age)
			var t: SimWorld.Team = w.teams[team]
			var spawned: int = 0
			for i in 4:
				if t.pop + int(Rules.UNITS[kind]["pop"]) > t.pop_cap:
					break
				if w.supply_gate != null:
					if String(w.supply_gate.call("lack", team, kind, true)) != "":
						break
					w.supply_gate.call("consume", team, kind, true)
				var spot: Vector2 = anchor.center + Vector2(cos(float(i) * 1.57), sin(float(i) * 1.57)) * (float(anchor.size) * 0.5 + 1.5)
				spot = Vector2(clampf(spot.x, 0.5, float(w.map_size) - 0.5), clampf(spot.y, 0.5, float(w.map_size) - 0.5))
				if not w.walkable(w.cell_of(spot)):
					spot = Vector2(w.nearest_walkable(w.cell_of(spot), spot)) + Vector2(0.5, 0.5)
				var u: SimWorld.Unit = w.spawn_unit(team, kind, spot)
				AgeProgression.apply_unit_level(u, 1)
				w._join_squad(u, null, i == 0)
				spawned += 1
			if spawned == 0:
				return w._no("population ou habitants insuffisants pour des renforts")
			w.emit("civilisation", team, "Renforts : %d %s" % [spawned, String(Rules.UNITS[kind]["label"]).to_lower()], {"pos": anchor.center})
		"bombardement":
			if not w.is_visible_to(team, pos):
				return w._no("cible actuellement visible requise")
			if (civ["effects"] as Array).size() >= MAX_EFFECTS:
				return w._no("trop d'effets actifs")
			(civ["effects"] as Array).append({"kind": "bomb", "sector": sector, "pos": pos, "radius": radius, "at": w.tick + 30, "value": 150.0 + 40.0 * float(age)})
			for enemy in w.faction_ids():
				if enemy != team and w.factions.hostile(team, enemy):
					w.emit("alerte_missile", enemy, "Bombardement en approche : impact dans 3 s", {"pos": pos})
		"bouclier":
			if (civ["effects"] as Array).size() >= MAX_EFFECTS:
				return w._no("trop d'effets actifs")
			(civ["effects"] as Array).append({"kind": "shield", "sector": sector, "pos": pos, "radius": radius, "until": w.tick + 300, "value": 50.0})
	civ["powers"][power] = {"ready_tick": w.tick + int(float(definition["cooldown"]) * Rules.TICK_RATE)}
	_log(w, civ, team, "Pouvoir utilisé : %s" % String(definition["label"]))
	return w._ok()

static func hash_text(w: SimWorld) -> String:
	if not enabled(w):
		return ""
	var parts: Array = []
	for team in w.faction_ids():
		if team != SimWorld.TEAM_NEUTRAL:
			var civ: Dictionary = state(w, team).duplicate(true)
			civ.erase("log")
			civ.erase("v")   # simple clé de cache des modificateurs, pas une donnée de partie
			parts.append(civ)
	return var_to_str(parts)
