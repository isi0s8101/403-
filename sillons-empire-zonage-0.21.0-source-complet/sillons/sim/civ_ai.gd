class_name CivAI
extends RefCounted
## 0.16 — Décisions d'évolution de l'IA : mêmes commandes, mêmes coûts et mêmes informations que le joueur.
## Appelé par AiController.think (déjà cadencé) ; aucune ressource ni visibilité supplémentaire.

const VOIES := ["marchande", "militaire", "savante"]
const UPGRADE_ORDER := ["charrues", "outils_bucheron", "armes_melee", "armures_infanterie", "armes_tir", "pioches", "batisseurs",
	"armures_cavalerie", "balistique", "blindage_avance", "aerodynamique"]

static func think(w: SimWorld, ai: AiController, t: SimWorld.Team, home: Vector2) -> void:
	var team: int = ai.team
	var civ: Dictionary = CivEvolution.state(w, team)
	_voie(w, team, t)
	if _monument(w, ai, t, home):
		return
	var reserve: Dictionary = _reserve(w, team, t)
	# La forge est bon marché et ouvre toutes les améliorations : elle passe avant la réserve du monument.
	if t.age >= 2 and w.team_buildings(team, "forge").is_empty() and w.team_units(team, "worker").size() >= 9 and _affordable(t, w.scaled_cost(Rules.BUILDINGS["forge"]["cost"]), {}):
		ai._place(w, "forge", home, 6, 16)
		return
	if w.tick % 50 == ai.think_offset % 50:
		_upgrade(w, team, t, reserve)
	_hero(w, ai, team, t, reserve)
	_special(w, ai, team, t, civ)
	_powers(w, team, civ, home)

static func _voie(w: SimWorld, team: int, t: SimWorld.Team) -> void:
	var epoch: String = CivEvolution.pending_epoch(w, team)
	if epoch.is_empty():
		return
	var base: int = (posmod(hash([team, w.seed_value]), 3))
	if t.opening == "commerce":
		base = 0
	elif t.opening == "assaut":
		base = 1
	var shift: int = CivRules.EPOCHS.find(epoch) if posmod(hash([team, epoch, w.seed_value]), 3) == 0 else 0
	w.issue({"t": "civ_voie", "team": team, "epoch": epoch, "voie": VOIES[posmod(base + shift, 3)]})

static func latest_voie(w: SimWorld, team: int) -> String:
	var voies: Dictionary = CivEvolution.state(w, team)["voies"] as Dictionary
	for i in range(CivRules.EPOCHS.size() - 1, -1, -1):
		if voies.has(CivRules.EPOCHS[i]):
			return String(voies[CivRules.EPOCHS[i]])
	return ""

static func _monument(w: SimWorld, ai: AiController, t: SimWorld.Team, home: Vector2) -> bool:
	var team: int = ai.team
	var target: int = t.age + 1
	var options: Array = CivRules.monuments_for(target)
	if options.is_empty() or target > int(w.rule("max_age", 10)):
		return false
	for kind in options:
		if not w.team_buildings(team, String(kind)).is_empty():
			return false   # déjà en chantier : les ouvriers s'en chargent
	var leaning: String = latest_voie(w, team)
	if leaning.is_empty():
		leaning = "marchande" if t.opening == "commerce" else ("militaire" if t.opening == "assaut" else VOIES[posmod(hash([team, w.seed_value]), 3)])
	options.sort_custom(func(a, b): return String((CivRules.MONUMENTS[a] as Dictionary)["leaning"]) == leaning and String((CivRules.MONUMENTS[b] as Dictionary)["leaning"]) != leaning)
	for kind in options:
		var key: String = String(kind)
		if CivEvolution.build_lack(w, team, key) != "":
			continue
		if not w._can_pay(team, w.scaled_cost(Rules.BUILDINGS[key]["cost"])):
			return false
		if ai._place(w, key, home, 7, 22):
			return true
	return false

static func _reserve(w: SimWorld, team: int, t: SimWorld.Team) -> Dictionary:
	## Garde de côté le coût du prochain monument dès que son objectif est rempli.
	var target: int = t.age + 1
	if not Rules.AGE_UP.has(target) or target > int(w.rule("max_age", 10)):
		return {}
	var objective: String = String((w.rule("age_up_%d" % target, Rules.AGE_UP[target]) as Dictionary)["objective"])
	if not w.objective_done(team, objective):
		return {}
	return w.scaled_cost(Rules.AGE_UP[target]["cost"])

static func _affordable(t: SimWorld.Team, cost: Dictionary, reserve: Dictionary) -> bool:
	for resource in Rules.RESOURCES:
		if float(t.res[resource]) - float(cost.get(resource, 0.0)) < float(reserve.get(resource, 0.0)):
			return false
	return true

static func _upgrade(w: SimWorld, team: int, t: SimWorld.Team, reserve: Dictionary) -> void:
	## Les améliorations économiques ne gardent que la moitié de la réserve du monument ; les militaires la gardent entière.
	var half: Dictionary = {}
	for resource in reserve.keys():
		half[resource] = float(reserve[resource]) * 0.5
	for key in UPGRADE_ORDER:
		var definition: Dictionary = CivRules.UPGRADES[key] as Dictionary
		var keep: Dictionary = half if String(definition["building"]) == "centre" else reserve
		for candidate in w.team_buildings(team, String(definition["building"]), true):
			var b: SimWorld.Building = candidate as SimWorld.Building
			var status: Dictionary = CivEvolution.upgrade_status(w, team, b, String(key))
			if bool(status["ok"]) and _affordable(t, status["cost"] as Dictionary, keep):
				w.issue({"t": "civ_upgrade", "team": team, "building": b.id, "key": key})
				return

static func _hero(w: SimWorld, ai: AiController, team: int, t: SimWorld.Team, reserve: Dictionary) -> void:
	if w.team_units(team, "military").size() < 6:
		return
	for kind in ["heros_spatial", "heros_industriel", "heros_antique"]:
		if t.age < int(Rules.UNITS[kind]["age"]) or CivEvolution.train_lack(w, team, kind) != "":
			continue
		if not _affordable(t, w.scaled_cost(Rules.UNITS[kind]["cost"]), reserve):
			return
		for cc in w.team_buildings(team, "centre", true):
			if cc.queue.size() < 2 and ai._train(w, cc, kind):
				return
		return

static func _special(w: SimWorld, ai: AiController, team: int, t: SimWorld.Team, civ: Dictionary) -> void:
	if w.tick % 40 != ai.think_offset % 40 or t.pop >= t.pop_cap - 3:
		return
	for epoch in CivRules.EPOCHS:
		if not (civ["voies"] as Dictionary).has(epoch):
			continue
		var kind: String = String(((CivRules.VOIES[epoch] as Dictionary)[String(civ["voies"][epoch])] as Dictionary)["unit"])
		if t.age < int(Rules.UNITS[kind]["age"]) or (epoch != CivRules.EPOCHS[0] and t.age >= int(CivRules.EPOCH_AGE[epoch]) + 3):
			continue
		for key in Rules.BUILDINGS.keys():
			if not (Rules.BUILDINGS[key].get("trains", []) as Array).has(kind):
				continue
			for b in w.team_buildings(team, String(key), true):
				if b.queue.is_empty() and ai._train(w, b, kind):
					return

static func _powers(w: SimWorld, team: int, civ: Dictionary, home: Vector2) -> void:
	var leaning: String = latest_voie(w, team)
	var wanted: Array = ["ravitaillement", "renforts" if leaning == "militaire" else "cri_ralliement", "bombardement", "eclaireurs", "cri_ralliement", "renforts", "bouclier"]
	for power in wanted:
		if bool(CivEvolution.unlock_status(w, team, String(power))["ok"]):
			w.issue({"t": "civ_unlock", "team": team, "power": power})
			break
	var powers: Dictionary = civ["powers"] as Dictionary
	if powers.is_empty() or w.tick % 20 != 0:
		return
	var enemies: Array = []
	for enemy in w.ai_visible_enemies(team):
		if Rules.unit_has(enemy.type, "military"):
			enemies.append(enemy)
	var army: Array = w.team_units(team, "military")
	if _ready(w, team, powers, "ravitaillement"):
		for u in army:
			if u.hp < u.max_hp * 0.55:
				var hurt: int = 0
				for other in army:
					if other.hp < other.max_hp * 0.8 and other.pos.distance_squared_to(u.pos) <= 49.0:
						hurt += 1
				if hurt >= 3 and bool(w.issue({"t": "civ_power", "team": team, "power": "ravitaillement", "pos": [u.pos.x, u.pos.y]})["ok"]):
					return
	if enemies.is_empty():
		return
	var cluster: Vector2 = Vector2(-1, -1)
	var best: int = 0
	for e in enemies:
		var near: int = 0
		for other in enemies:
			if other.pos.distance_squared_to(e.pos) <= 16.0:
				near += 1
		if near > best:
			best = near
			cluster = e.pos
	if best >= 3 and _ready(w, team, powers, "bombardement") and bool(w.issue({"t": "civ_power", "team": team, "power": "bombardement", "pos": [cluster.x, cluster.y]})["ok"]):
		return
	if _ready(w, team, powers, "renforts") and cluster.distance_to(home) < 20.0 and bool(w.issue({"t": "civ_power", "team": team, "power": "renforts", "pos": [home.x, home.y]})["ok"]):
		return
	if _ready(w, team, powers, "cri_ralliement"):
		for u in army:
			if u.pos.distance_squared_to(cluster) <= 100.0:
				if bool(w.issue({"t": "civ_power", "team": team, "power": "cri_ralliement", "pos": [u.pos.x, u.pos.y]})["ok"]):
					return
				break
	if _ready(w, team, powers, "bouclier"):
		for b in w.team_buildings(team, "", true):
			if w.tick - int(b.hit_tick) < 30 and b.center.distance_to(cluster) < 14.0:
				w.issue({"t": "civ_power", "team": team, "power": "bouclier", "pos": [b.center.x, b.center.y]})
				return

static func _ready(w: SimWorld, team: int, powers: Dictionary, power: String) -> bool:
	return powers.has(power) and CivEvolution.power_wait(w, team, power) <= 0.0
