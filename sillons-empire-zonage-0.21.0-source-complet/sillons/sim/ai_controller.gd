class_name AiController
extends RefCounted
## IA adverse. Elle n'utilise que les informations de son camp :
## ses propres entités, les ennemis actuellement visibles (brouillard) et sa mémoire des structures vues.
## Elle agit exclusivement par SimWorld.issue(), comme le joueur.
## État exposé au laboratoire : debug = {objective, target, info, abandon, opening}.

var team: int
var debug := {"objective": "Démarrage", "target": "—", "info": [], "abandon": "", "opening": "", "history": []}
var _phase_attack := false
var _attack_start_count := 0
var _attack_target_pos := Vector2(-1, -1)
var _attack_target_label := ""
var _cooldown_until := 0
var _scout_points: Array = []
var _scout_idx := 0
var _last_prio := {}
var _blocked_targets: Array = []
var _attack_ids: Array = []
var _siege_target := -1           # structure qui bloque le passage, en cours de siège
var _rally_fort_id := -1
var _rally_fort_pos := Vector2.ZERO
var _rally_issued := Vector2(-999, -999)
var _siege_since := -1            # tick du premier siège de l'attaque en cours
var _siege_losses0 := 0.0         # pertes au début du siège
var _want_siege := false          # passage bloqué par une structure trop solide sans artillerie
var _route_note := ""
var _attacks_launched := 0
var attack_threshold := 9
var trade_attack_threshold := 14
var think_offset := 3

func _init(p_team: int) -> void:
	team = p_team
	think_offset = 3 + p_team * 5

func _set_objective(w: SimWorld, obj: String, target: String, info: Array) -> void:
	if obj != debug["objective"] or target != debug["target"]:
		debug["history"].append("t=%ds %s → %s" % [w.tick / Rules.TICK_RATE, obj, target])
		if debug["history"].size() > 30:
			debug["history"].pop_front()
		w.emit("ia", team, "IA : %s (%s)" % [obj, target], {"objective": obj, "target": target, "info": info})
	debug["objective"] = obj
	debug["target"] = target
	debug["info"] = info

func _abandon(w: SimWorld, reason: String) -> void:
	debug["abandon"] = "t=%ds %s" % [w.tick / Rules.TICK_RATE, reason]
	w.emit("ia_abandon", team, "IA : abandon — " + reason, {"reason": reason})

func think(w: SimWorld) -> void:
	if w.tick % 10 != think_offset % 10:
		return
	var t: SimWorld.Team = w.teams[team]
	if t.eliminated:
		return
	if _scout_points.is_empty():
		_init_scout_points(w)
	var ccs := w.team_buildings(team, "centre")
	var cc_done := w.team_buildings(team, "centre", true)
	var home: Vector2 = cc_done[0].center if not cc_done.is_empty() else (ccs[0].center if not ccs.is_empty() else w._probe_pos(team))
	if ccs.is_empty():
		_rebuild_center(w, home)
	_economy(w, t, cc_done, home)
	_scout(w)
	_age(w, t)
	if CivEvolution.enabled(w):
		CivAI.think(w, self, t, home)
	if t.age >= 2:
		_opening(w, t, home)
		_fortify(w, t, home)
	_modern(w, t, home)
	if t.age >= 4 and w.tick % 100 == think_offset:
		_local_evolution(w, t)
	_military(w, t, home)

func _local_evolution(w: SimWorld, t: SimWorld.Team) -> void:
	# Évolution prudente : une seule décision au maximum par 10 s ; le budget
	# de reconstruction et de passage d'âge reste prioritaire. Aucun privilège IA.
	var reserve: Dictionary = w.scaled_cost({"food": 300, "wood": 250, "ore": 230})
	for kind in ["caserne", "atelier", "usine", "aerodrome", "spatioport", "chantier_orbital"]:
		for candidate in w.team_buildings(team, kind, true):
			var b: SimWorld.Building = candidate as SimWorld.Building
			if b == null or not b.upgrade_job.is_empty():
				continue
			if b.tier < 3:
				var status: Dictionary = AgeProgression.upgrade_status(w, team, b, "building")
				if bool(status["ok"]) and _evolution_budget(t, status["cost"], reserve):
					w.issue({"t": "upgrade_building", "team": team, "building": b.id})
					return
			for unit_kind in Rules.BUILDINGS[kind].get("trains", []):
				var target_level: int = int(b.unit_evolutions.get(unit_kind, 1)) + 1
				if target_level > b.tier or target_level > 3:
					continue
				var status: Dictionary = AgeProgression.upgrade_status(w, team, b, "troop", String(unit_kind))
				if bool(status["ok"]) and _evolution_budget(t, status["cost"], reserve):
					w.issue({"t": "upgrade_troop", "team": team, "building": b.id, "unit": String(unit_kind)})
					return

func _evolution_budget(t: SimWorld.Team, cost: Dictionary, reserve: Dictionary) -> bool:
	for resource in Rules.RESOURCES:
		if float(t.res[resource]) - float(cost.get(resource, 0.0)) < float(reserve.get(resource, 0.0)):
			return false
	return true

# ------------------------------------------------------------------ économie

func _economy(w: SimWorld, t: SimWorld.Team, cc_done: Array, home: Vector2) -> void:
	var workers := w.team_units(team, "worker").size()
	var target_workers := 13 if t.age == 1 else (20 if t.opening == "commerce" else 16)
	for cc in cc_done:
		if cc.queue.is_empty() and workers < target_workers and t.pop < t.pop_cap:
			_train(w, cc, "ouvrier")
	if UrbanCity.replaces_gathering(w, team):
		UrbanAI.think(w, self, t, home)
		if workers >= 8 and w.team_buildings(team, "caserne").is_empty():
			_place(w, "caserne", home, 6, 12)
		return
	# 0.20 : avant l'électricité, un petit quartier zoné sur les surplus (mêmes commandes que le joueur).
	UrbanAI.think_early(w, self, t, home)
	# maisons
	var pending_house := false
	for b in w.team_buildings(team, "maison"):
		if not b.complete:
			pending_house = true
	if not pending_house and t.pop_cap - t.pop <= 3 and t.pop_cap < 80:
		_place(w, "maison", home, 6, 12)
	# ferme si la nourriture sauvage manque
	var farms := w.team_buildings(team, "ferme").size()
	var farms_pending := farms - w.team_buildings(team, "ferme", true).size()
	var wild_food := 0.0
	for n in w.nodes.values():
		if n.res == "food" and w.is_explored_by(team, n.pos) and n.pos.distance_to(home) < 25.0:
			wild_food += n.amount
	var max_farms := 3 if t.age == 1 else 8
	if farms_pending == 0 and farms < max_farms and (not t.res_access["food"] or wild_food < 400.0 + farms * 200.0):
		_place(w, "ferme", home, 5, 11)
	if workers >= 7:
		_build_drop_sites(w, home)
	# caserne
	if workers >= 8 and w.team_buildings(team, "caserne").is_empty():
		_place(w, "caserne", home, 6, 12)
	# priorités de ressources selon le besoin courant
	var need := _current_need(w, t)
	var prio := {}
	for r in Rules.RESOURCES:
		var deficit: float = float(need.get(r, 0)) - t.res[r]
		prio[r] = 3 if deficit > 150 else (2 if deficit > 0 else (1 if deficit > -250 else 0))
	if prio != _last_prio:
		for r in Rules.RESOURCES:
			if int(_last_prio.get(r, -1)) != prio[r]:
				w.issue({"t": "set_priority", "team": team, "res": r, "value": prio[r]})
		_last_prio = prio

func _train(w: SimWorld, b, ut: String) -> bool:
	var t: SimWorld.Team = w.teams[team]
	if (t.age >= 3 or (bool(w.rules.get("evolutions", false)) and t.age >= 2)) and t.age < int(w.rule("max_age", 8)) and Rules.AGE_UP.has(t.age + 1) and w.team_units(team, "military").size() >= 12 and w.objective_done(team, String(Rules.AGE_UP[t.age + 1]["objective"])) and t.research.is_empty():
		var reserved: Dictionary = w.scaled_cost(Rules.AGE_UP[t.age + 1]["cost"])
		var cost: Dictionary = w.scaled_cost(Rules.UNITS[ut]["cost"])
		for resource in cost:
			if float(t.res[resource]) < float(reserved.get(resource, 0.0)) + float(cost[resource]):
				return false
	if w.train_check(team, b, ut) != "":
		return false
	return w.issue({"t": "train", "team": team, "building": b.id, "unit": ut})["ok"]

func _build_drop_sites(w: SimWorld, home: Vector2) -> void:
	## Entrepôt près des gisements éloignés (bois, minerai) quand le trajet dépasse 9 cases.
	if w.team_buildings(team, "entrepot").size() >= 3:
		return
	for b in w.team_buildings(team, "entrepot"):
		if not b.complete:
			return
	for r in ["wood", "ore"]:
		var n = w._find_node(team, r, home)
		if n == null:
			continue
		var drop = w._nearest_drop(team, n.pos)
		if drop == null or drop.center.distance_to(n.pos) > 9.0:
			if _place(w, "entrepot", n.pos, 2, 5):
				return

func _ready_for_age3(w: SimWorld, t: SimWorld.Team) -> bool:
	if t.age != 2 or not Rules.AGE_UP.has(3) or int(w.rule("max_age", 3)) < 3:
		return false
	if w.team_units(team, "worker").size() < 14:
		return false
	if bool(w.rules.get("evolutions", false)): return true
	if t.opening == "commerce":
		return w.team_units(team, "caravan").size() >= 3
	# assaut : on ne détourne pas les ressources de l'armée avant la première attaque
	return _attacks_launched >= 1 and not _phase_attack

func _current_need(w: SimWorld, t: SimWorld.Team) -> Dictionary:
	if _ready_for_age3(w, t):
		var c3: Dictionary = Rules.AGE_UP[3]["cost"].duplicate()
		return {"food": c3.get("food", 0) + 100, "wood": c3.get("wood", 0) + 100, "ore": c3.get("ore", 0) + 50}
	if t.age >= 3:
		return {"food": 400, "wood": 400, "ore": 400}
	if t.age == 1:
		var c: Dictionary = Rules.AGE_UP[2]["cost"].duplicate()
		c["wood"] = c.get("wood", 0) + 150
		return c
	if t.opening == "commerce":
		if w.team_buildings(team, "marche").is_empty() or w.team_buildings(team, "relais").is_empty():
			return {"food": 150, "wood": 450, "ore": 80}
		return {"food": 350, "wood": 250, "ore": 200}
	return {"food": 500, "wood": 150, "ore": 350}

func _place(w: SimWorld, type: String, around: Vector2, rmin: int, rmax: int) -> bool:
	var size := int(Rules.BUILDINGS[type]["size"])
	var dir := Vector2(-1, 1).normalized() if team == 1 else Vector2(1, -1).normalized()
	for r in range(rmin, rmax + 1):
		for k in 16:
			var ang := float(k) / 16.0 * TAU
			var p := around + Vector2(cos(ang), sin(ang)) * r - dir * 2.0
			var cell := Vector2i(int(p.x - size * 0.5), int(p.y - size * 0.5))
			if w.has_margin(cell, size) and w.build_check(team, type, cell) == "":
				w.issue({"t": "build", "team": team, "type": type, "cell": [cell.x, cell.y]})
				return true
	return false

func _rebuild_center(w: SimWorld, home: Vector2) -> void:
	var cap := w.rebuild_capacity(team)
	_set_objective(w, "Rebâtir le centre", "près de (%d,%d)" % [home.x, home.y], ["capacité : " + cap["reason"]])
	_place(w, "centre", home, 0, 10)

# ------------------------------------------------------------------ exploration

func _init_scout_points(w: SimWorld) -> void:
	var pts := [Vector2(48, 20), Vector2(20, 48), Vector2(20, 12), Vector2(10, 22), Vector2(76, 84), Vector2(86, 72),
		Vector2(48, 76), Vector2(76, 48), Vector2(30, 30), Vector2(66, 66), Vector2(14, 82), Vector2(82, 14)]
	if team == 0:
		var mirrored := []
		for p in pts:
			mirrored.append(Vector2(p.y, p.x))
		pts = mirrored
	if w.map_size > 96:
		var own: Vector2 = w._probe_pos(team)
		pts = [own + Vector2(-7, -15), own + Vector2(15, -8), own + Vector2(10, 10)] + WorldLayout.fords(w)
		for index in pts.size(): pts[index] = (pts[index] as Vector2).clamp(Vector2.ONE * 2.0, Vector2.ONE * (w.map_size - 3.0))
	_scout_points = pts

func _scout(w: SimWorld) -> void:
	var scouts := w.team_units(team, "scout")
	if scouts.is_empty():
		return
	var s: SimWorld.Unit = scouts[0]
	if s.state == "move":
		return
	var tries := 0
	while tries < _scout_points.size():
		var p: Vector2 = _scout_points[_scout_idx % _scout_points.size()]
		_scout_idx += 1
		tries += 1
		if not w.is_explored_by(team, p) or _scout_idx > _scout_points.size():
			if w.issue({"t": "move", "team": team, "units": [s.id], "pos": [p.x, p.y]})["ok"]:
				return
	return

# ------------------------------------------------------------------ âges et ouvertures

func _age(w: SimWorld, t: SimWorld.Team) -> void:
	var st := w.age_up_status(team)
	if st["possible"]:
		w.issue({"t": "age_up", "team": team})

func _opening(w: SimWorld, t: SimWorld.Team, home: Vector2) -> void:
	if t.opening == "":
		# Évaluation sur informations propres : comptoir connu et sûr -> commerce ; sinon assaut précoce
		var post = _best_post(w, home)
		var seen_mil := 0
		for u in w.ai_visible_enemies(team):
			if Rules.unit_has(u.type, "military"):
				seen_mil += 1
		if post != null and seen_mil < 3 and w.rng.randf() < 0.6:
			t.opening = "commerce"
		else:
			t.opening = "assaut"
		debug["opening"] = t.opening
		w.emit("ia", team, "IA : ouverture choisie — %s" % t.opening, {"opening": t.opening, "post_known": post != null, "seen_military": seen_mil})
	debug["opening"] = t.opening
	var casernes := w.team_buildings(team, "caserne", true)
	if t.opening == "commerce":
		if w.team_buildings(team, "relais").is_empty():
			var post = _best_post(w, home)
			if post != null:
				_place_relais(w, post)
		if w.team_buildings(team, "marche").is_empty() and not w.team_buildings(team, "relais").is_empty():
			_place(w, "marche", home, 6, 12)
		var markets := w.team_buildings(team, "marche", true)
		var caravans := 0
		for u in w.team_units(team, "caravan"):
			caravans += 1
		if not markets.is_empty() and not w.team_buildings(team, "relais", true).is_empty():
			if caravans < 5 and markets[0].queue.is_empty():
				_train(w, markets[0], "caravane")
		# commerce : on choisit la ressource la plus en déficit
		var need := _current_need(w, t)
		var best_r := "food"
		var best_d := -INF
		for r in Rules.RESOURCES:
			var d: float = float(need[r]) - t.res[r]
			if d > best_d:
				best_d = d
				best_r = r
		if t.trade_res != best_r:
			w.issue({"t": "trade_res", "team": team, "res": best_r})
		for c in casernes:
			if c.queue.size() < 1 and caravans >= 3:
				_train(w, c, "tireur" if (w.tick / 10) % 2 == 0 else "lancier")
	else:
		if casernes.size() < 2 and w.team_buildings(team, "caserne").size() < 2:
			_place(w, "caserne", home, 7, 13)
		var mix := ["tireur", "lancier", "cavalier", "tireur"]
		for c in casernes:
			if c.queue.size() < 2:
				var ut: String = mix[(w.tick / 10 + c.id) % mix.size()]
				if not _train(w, c, ut):
					_train(w, c, "lancier")

func _own_ford(w: SimWorld, home: Vector2) -> Vector2:
	## Gué le plus proche de la base, et point de défense de notre côté de la rivière.
	var best: Vector2 = WorldLayout.fords(w)[0]
	for f in WorldLayout.fords(w):
		if f.distance_to(home) < best.distance_to(home):
			best = f
	var side := Vector2(1, -1).normalized() if team == 1 else Vector2(-1, 1).normalized()
	return best + side * 6.0

func _fortify(w: SimWorld, t: SimWorld.Team, home: Vector2) -> void:
	## Âge II : objectif « tenir un gué » ; âge III : fort au gué, atelier et canons.
	var guard := _own_ford(w, home)
	if t.age == 2 and _ready_for_age3(w, t) and not w.objective_done(team, Rules.AGE_UP[3]["objective"]):
		if w.team_buildings(team, "palissade").is_empty():
			_place(w, "palissade", guard, 0, 3)
	if t.age >= 3:
		if w.team_buildings(team, "atelier").is_empty():
			_place(w, "atelier", home, 6, 13)
		if w.team_buildings(team, "fort").is_empty() and t.res["ore"] > 200:
			_place(w, "fort", guard, 0, 4)
		var canons := w.team_units(team, "siege").size()
		var want := 4 if _want_siege else 2
		for a in w.team_buildings(team, "atelier", true):
			if a.queue.is_empty() and canons < want:
				_train(w, a, "canon")

func _best_post(w: SimWorld, home: Vector2):
	var best = null
	var bd := INF
	for id in w.teams[team].discovered_posts:
		var b = w.buildings.get(id)
		if b == null:
			continue
		var taken = w._relais_at(b)
		if taken != null and taken.team != team:
			continue
		var d: float = b.center.distance_to(home)
		if d < bd:
			bd = d
			best = b
	return best

func _place_relais(w: SimWorld, post) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var cell := Vector2i(int(post.center.x) + dx, int(post.center.y) + dy)
			if w.build_check(team, "relais", cell) == "":
				w.issue({"t": "build", "team": team, "type": "relais", "cell": [cell.x, cell.y]})
				return

# ------------------------------------------------------------------ militaire

func _army_units(w: SimWorld) -> Array:
	return w.team_units(team, "military")

func _military(w: SimWorld, t: SimWorld.Team, home: Vector2) -> void:
	var army := _army_units(w)
	var squads := w.team_squads(team)
	var visible := w.ai_visible_enemies(team)
	# 1. Défense : ennemis visibles près de nos bâtiments
	var threats := []
	for e in visible:
		for b in w.team_buildings(team):
			if e.pos.distance_to(b.center) < 14.0:
				threats.append(e)
				break
	var threat_mil := 0
	for e in threats:
		if Rules.unit_has(e.type, "military") or Rules.unit_has(e.type, "scout"):
			threat_mil += 1
	if threat_mil > 0 and not _phase_attack:
		var nearest = threats[0]
		for e in threats:
			if e.pos.distance_squared_to(home) < nearest.pos.distance_squared_to(home):
				nearest = e
		_set_objective(w, "Défendre la base", "%s ennemi en (%d,%d)" % [Rules.UNITS[nearest.type]["label"], nearest.pos.x, nearest.pos.y],
			["ennemis visibles près de la base : %d" % threats.size(), "armée disponible : %d" % army.size()])
		for s in squads:
			w.issue({"t": "attack", "team": team, "squad": s.id, "target": nearest.id})
		return
	if _phase_attack:
		_follow_attack(w, army, squads, visible, home)
		return
	var threshold := trade_attack_threshold if t.opening == "commerce" else attack_threshold
	var aggression: float = float(w.rule("ai_attack_mult", 1.0))
	threshold = 100000 if aggression <= 0.0 else maxi(3, int(round(float(threshold) * aggression)))
	if t.age < 2:
		threshold = 99
	if w.tick < _cooldown_until:
		threshold = 99
	if _want_siege and w.team_units(team, "siege").is_empty():
		threshold = 99
	if army.size() >= threshold:
		var tgt := _pick_target(w, home)
		if tgt.is_empty():
			_explore_with_army(w, squads, home)
			return
		_phase_attack = true
		_attack_start_count = army.size()
		_attack_ids = []
		for u in army:
			_attack_ids.append(u.id)
		_attack_target_pos = tgt["pos"]
		_attack_target_label = tgt["label"]
		_siege_target = -1
		_siege_since = -1
		_attacks_launched += 1
		_route_note = ""
		var info: Array = tgt["info"].duplicate()
		info.append(_route_text(w, army))
		_set_objective(w, "Attaquer", tgt["label"], info)
		for s in squads:
			w.issue({"t": "amove", "team": team, "squad": s.id, "pos": [_attack_target_pos.x, _attack_target_pos.y]})
		return
	# Regroupement défensif délégué (même mécanisme que le joueur)
	var army_task: Dictionary = t.army
	var rally := home + (Vector2(-1, 1) if team == 1 else Vector2(1, -1)).normalized() * 7.0
	var forts := w.team_buildings(team, "fort", true)
	if not forts.is_empty():
		# point de ralliement au fort : calculé une fois par fort (recherche de chemin coûteuse)
		if _rally_fort_id != forts[0].id:
			_rally_fort_id = forts[0].id
			_rally_fort_pos = w.approach_point(home, forts[0].center, 3.0)
			if _rally_fort_pos.x < 0:
				_rally_fort_pos = forts[0].center
		rally = _rally_fort_pos
	# ne réémettre l'ordre que si le point de ralliement change (sinon toutes les escouades recalculent leur chemin)
	if army_task.is_empty() or (army_task["pos"].distance_to(rally) > 1.0 and _rally_issued.distance_to(rally) > 1.0):
		w.issue({"t": "army_defend", "team": team, "pos": [rally.x, rally.y], "radius": 14.0})
		_rally_issued = rally
	for s in squads:
		if s.direct:
			w.issue({"t": "release_squad", "team": team, "squad": s.id})
	var obj := "Développer l'économie" if t.age == 1 else ("Commerce et défense" if t.opening == "commerce" else "Masser une armée d'assaut")
	if not forts.is_empty():
		obj += " — tenir le fort du gué"
	if _want_siege and w.team_units(team, "siege").is_empty():
		obj = "Préparer l'artillerie (passage fortifié)"
	_set_objective(w, obj, "seuil d'attaque %d (armée %d)" % [threshold, army.size()] if threshold < 99 else "—",
		["âge %d" % t.age, "ouvriers %d" % w.team_units(team, "worker").size(), "structures ennemies connues : %d" % _known_enemy_structures(w)])

func _known_enemy_structures(w: SimWorld) -> int:
	var n := 0
	for id in w.ai_memory(team).keys():
		var m: Dictionary = w.ai_memory(team)[id]
		if m["team"] != team and m["team"] != SimWorld.TEAM_NEUTRAL:
			n += 1
	return n

func _pick_target(w: SimWorld, home: Vector2) -> Dictionary:
	## Cible issue uniquement de la mémoire du camp (structures vues).
	var mem := w.ai_memory(team)
	var best := {}
	var bd := INF
	for id in mem.keys():
		var m: Dictionary = mem[id]
		if m["team"] == team or m["team"] == SimWorld.TEAM_NEUTRAL:
			continue
		var skip := false
		for bp in _blocked_targets:
			if bp.distance_to(m["pos"]) < 1.0:
				skip = true
		if skip:
			continue
		var d: float = m["pos"].distance_to(home)
		# une palissade n'est pas un objectif : elle se contourne ou s'assiège quand elle bloque la route
		if Rules.BUILDINGS[m["type"]].get("wall", false):
			d += 200.0
		if m["type"] == "relais":
			d *= 0.7
		if m["type"] == "centre":
			d *= 0.85
		if d < bd:
			bd = d
			best = {"pos": m["pos"], "label": "%s ennemi (%d,%d)" % [Rules.BUILDINGS[m["type"]]["label"], m["pos"].x, m["pos"].y],
				"info": ["souvenir : %s vu à t=%ds" % [Rules.BUILDINGS[m["type"]]["label"], m["tick"] / Rules.TICK_RATE],
				"structures ennemies connues : %d" % _known_enemy_structures(w)], "id": id}
	return best

func _explore_with_army(w: SimWorld, squads: Array, home: Vector2) -> void:
	var p: Vector2 = Vector2(14, 82) if team == 1 else Vector2(82, 14)
	for sp in _scout_points:
		if not w.is_explored_by(team, sp):
			p = sp
			break
	_set_objective(w, "Chercher l'ennemi", "zone inexplorée (%d,%d)" % [p.x, p.y], ["aucune structure ennemie en mémoire"])
	for s in squads:
		# ordre identique déjà en cours : ne pas le réémettre (évite de recalculer tous les chemins)
		if s.direct and s.order.get("type", "") == "amove" and s.order.get("pos", Vector2(-99, -99)).distance_to(p) < 0.5:
			continue
		w.issue({"t": "amove", "team": team, "squad": s.id, "pos": [p.x, p.y]})

func _army_center(army: Array) -> Vector2:
	## Position de l'unité la plus proche du barycentre (le barycentre peut tomber dans l'eau).
	var c := Vector2.ZERO
	for u in army:
		c += u.pos
	c /= max(1, army.size())
	var best := c
	var bd := INF
	for u in army:
		var d: float = u.pos.distance_squared_to(c)
		if d < bd:
			bd = d
			best = u.pos
	return best

func _route_text(w: SimWorld, army: Array) -> String:
	if army.is_empty():
		return "route : —"
	var c := _army_center(army)
	var ap := w.approach_point(c, _attack_target_pos, 2.5)
	if ap.x < 0:
		return "route : cible sans accès"
	var rep := w.route_report(c, ap)
	match rep["status"]:
		"detour":
			var txt := "route alternative : détour de %d %% (passage direct bloqué)" % int((rep["ratio"] - 1.0) * 100)
			if _route_note == "":
				w.emit("ia_route", team, "IA : " + txt, {"ratio": rep["ratio"]})
			_route_note = txt
			return txt
		"directe":
			return "route : directe"
		"bloquee":
			return "route : bloquée par une structure"
	return "route : impossible par le terrain"

func _follow_attack(w: SimWorld, army: Array, squads: Array, visible: Array, home: Vector2) -> void:
	var alive := 0
	for id in _attack_ids:
		if w.units.has(id):
			alive += 1
	var losses := 1.0 - float(alive) / float(max(1, _attack_start_count))
	var info := ["armée au départ : %d" % _attack_start_count, "armée actuelle : %d" % alive, "pertes : %d %%" % int(losses * 100)]
	if losses >= 0.6 or alive <= 2:
		_abandon(w, "attaque échouée sur %s (pertes %d %%)" % [_attack_target_label, int(losses * 100)])
		_retreat(w, squads, home, info, "pertes")
		return
	var center := _army_center(army)
	# Siège sans artillerie sous le feu : budget de temps et de pertes, puis réévaluation
	if _siege_since >= 0 and w.team_units(team, "siege").is_empty():
		var siege_s := float(w.tick - _siege_since) * Rules.DT
		if siege_s > 75.0 or losses - _siege_losses0 >= 0.3:
			_siege_target = -1
			_siege_since = -1
			_want_siege = true
			_abandon(w, "siège sans artillerie trop coûteux (%d s, pertes %d %%)" % [int(siege_s), int(losses * 100)])
			_retreat(w, squads, home, info, "pertes")
			return
	# Siège en cours : on continue tant que la structure tient
	if _siege_target != -1:
		var sb = w.buildings.get(_siege_target)
		if sb != null:
			info.append("siège : %s %d/%d PV" % [Rules.BUILDINGS[sb.type]["label"], int(sb.hp), int(sb.max_hp)])
			info.append("artillerie : %d canon(s)" % w.team_units(team, "siege").size())
			_set_objective(w, "Siège : ouvrir le passage", "%s (%d,%d)" % [Rules.BUILDINGS[sb.type]["label"], sb.center.x, sb.center.y], info)
			for s in squads:
				if s.order.get("type", "") != "attack" or int(s.order.get("target", -1)) != sb.id:
					if w.is_visible_to(team, sb.center):
						w.issue({"t": "attack", "team": team, "squad": s.id, "target": sb.id})
					else:
						w.issue({"t": "amove", "team": team, "squad": s.id, "pos": [sb.center.x, sb.center.y]})
			return
		_siege_target = -1
		w.emit("ia", team, "IA : passage ouvert, reprise de la marche", {})
		for s in squads:
			w.issue({"t": "amove", "team": team, "squad": s.id, "pos": [_attack_target_pos.x, _attack_target_pos.y]})
	var ap := w.approach_point(center, _attack_target_pos, 2.5)
	var blocked := ap.x < 0 or (w.find_path(center, ap).is_empty() and center.distance_to(ap) > 2.0)
	if blocked:
		var blocker = w.blocking_structure(team, center, ap if ap.x >= 0 else _attack_target_pos)
		var canons := w.team_units(team, "siege").size()
		if blocker != null and (canons > 0 or blocker.type == "palissade"):
			_siege_target = blocker.id
			if _siege_since < 0:
				_siege_since = w.tick
				_siege_losses0 = losses
			w.emit("ia", team, "IA : passage bloqué par %s — siège" % Rules.BUILDINGS[blocker.type]["label"], {"blocker": blocker.id})
			info.append("route : bloquée par %s, siège lancé" % Rules.BUILDINGS[blocker.type]["label"])
			_set_objective(w, "Siège : ouvrir le passage", "%s (%d,%d)" % [Rules.BUILDINGS[blocker.type]["label"], blocker.center.x, blocker.center.y], info)
			for s in squads:
				w.issue({"t": "amove", "team": team, "squad": s.id, "pos": [blocker.center.x, blocker.center.y]})
			return
		if blocker != null:
			_want_siege = true
			_abandon(w, "passage bloqué par %s : artillerie nécessaire" % Rules.BUILDINGS[blocker.type]["label"])
		else:
			_abandon(w, "passage bloqué vers %s" % _attack_target_label)
			_blocked_targets.append(_attack_target_pos)
		_retreat(w, squads, home, info, "passage")
		return
	info.append(_route_text(w, army))
	var mem := w.ai_memory(team)
	var still := false
	for id in mem.keys():
		if mem[id]["pos"].distance_to(_attack_target_pos) < 0.5:
			still = true
	if not still:
		var nt := _pick_target(w, home)
		if nt.is_empty():
			_explore_with_army(w, squads, home)
			return
		_attack_target_pos = nt["pos"]
		_attack_target_label = nt["label"]
		for s in squads:
			w.issue({"t": "amove", "team": team, "squad": s.id, "pos": [_attack_target_pos.x, _attack_target_pos.y]})
	_set_objective(w, "Attaquer", _attack_target_label, info)
	for s in squads:
		if s.order.get("type", "") == "hold" and not s.direct:
			w.issue({"t": "amove", "team": team, "squad": s.id, "pos": [_attack_target_pos.x, _attack_target_pos.y]})

func _retreat(w: SimWorld, squads: Array, home: Vector2, info: Array, cause: String) -> void:
	_phase_attack = false
	_cooldown_until = w.tick + 60 * Rules.TICK_RATE
	for s in squads:
		w.issue({"t": "move", "team": team, "squad": s.id, "pos": [home.x, home.y + (-4 if team == 1 else 4)]})
	# Réévaluation : seuil relevé, et bascule d'ouverture si l'assaut échoue face à une défense supérieure
	if cause == "pertes":
		attack_threshold += 4
		trade_attack_threshold += 3
	else:
		_cooldown_until = w.tick + 10 * Rules.TICK_RATE
	var new_obj := "Consolider : économie et défense"
	if cause == "passage":
		new_obj = "Contourner : chercher un autre passage"
	info.append("réévaluation : seuil d'attaque porté à %d" % attack_threshold)
	_set_objective(w, new_obj, "base", info)
	debug["history"].append("réévaluation (%s) : %s" % [cause, new_obj])

func _modern(w: SimWorld, t: SimWorld.Team, home: Vector2) -> void:
	if t.age < 4:
		return
	for kind in ["usine", "academie", "depot", "gare", "aerodrome", "radar", "intercepteur", "silo", "spatioport", "chantier_orbital"]:
		if t.age >= int(Rules.BUILDINGS[kind]["age"]) and w.team_buildings(team, kind).is_empty():
			if _place(w, kind, home, 5, 20):
				break
	if t.age >= 6 and w.team_buildings(team, "gare").size() < 2:
		_place(w, "gare", home, 14, 23)
	for b in w.team_buildings(team, "", true):
		if b.type == "gare" and b.queue.is_empty() and w.team_units(team, "rail").is_empty() and w.team_buildings(team, "gare", true).size() >= 2:
			_train(w, b, "train")
		if b.type == "usine" and b.queue.is_empty() and t.pop < t.pop_cap - 4:
			var options: Array = ["fusilier", "obusier"]
			if t.age >= 5:
				options.append("grenadier")
			if t.age >= 6:
				options.append_array(["char", "antiaerien"])
			if t.age >= 7:
				options.append("lance_missiles")
			if t.age >= 8:
				options.append("brouilleur")
			_train(w, b, String(options[(w.tick / 10) % options.size()]))
		if b.type == "aerodrome" and b.queue.is_empty() and w.team_units(team, "air").size() < 4:
			_train(w, b, "drone" if t.age >= 8 else "avion")
		if b.type in ["spatioport", "chantier_orbital"] and b.queue.is_empty() and w.team_units(team, "orbital").size() < 2:
			_train(w, b, "fregate" if b.type == "chantier_orbital" else "navette")
		for key in Rules.TECHNOLOGIES:
			var d: Dictionary = Rules.TECHNOLOGIES[key]
			if (key == UrbanRules.TECH and (not UrbanCity.enabled(w) or not UrbanCity.ready_for_switch(w, team))) or UrbanCity.tech_lack(w, key) != "": continue
			if b.type == d["building"] and t.age >= int(d["age"]) and not t.technologies.has(key) and t.tech_research.is_empty() and w._can_pay(team, w.scaled_cost(d["cost"])):
				w.issue({"t": "technology", "team": team, "building": b.id, "key": key})
		if b.type == "silo" and b.cd <= 0.0 and w._can_pay(team, w.scaled_cost({"ore": 250})):
			var targets: Array = w.ai_visible_enemies(team)
			if not targets.is_empty():
				var pos: Vector2 = targets[0].pos
				w.issue({"t": "missile", "team": team, "building": b.id, "pos": [pos.x, pos.y]})
