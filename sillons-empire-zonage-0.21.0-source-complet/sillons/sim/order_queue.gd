class_name OrderQueue
extends RefCounted
## 0.17 — Files d'ordres programmées (A → B → C…), pour les militaires, les ouvriers et les éclaireurs.
## Étend `queue_orders` (ArmyPlans, 0.14) sans changer le sens des anciennes étapes (move, amove, wait,
## defend, patrol, escort). Tout passe par des commandes validées : un refus ne modifie rien.
## Les champs utilisés (Unit.order_steps, order_step, order_loop, order_group, order_offset, step_arrived)
## sont des variables de script : ils sont sauvegardés et rechargés avec chaque monde.

const MAX_STEPS := 16
const MAX_UNITS := 128
const GROUP_TIMEOUT := 200          # ticks (20 s) : attente maximale des retardataires à chaque point
const BLOCKED_SKIP := 40            # ticks sans chemin avant de sauter une étape de déplacement
const MILITARY_STEPS := ["move", "amove", "wait", "defend", "patrol", "escort", "attack", "garrison", "release", "follow", "explore"]
const WORKER_STEPS := ["move", "wait", "build", "gather", "return", "repair", "garrison", "release", "follow"]
const SCOUT_STEPS := ["move", "wait", "follow", "explore", "release"]
const STEP_LABELS := {"move": "Marcher", "amove": "Assaut", "wait": "Attendre", "defend": "Tenir la zone", "patrol": "Patrouille",
	"escort": "Escorter", "attack": "Attaquer", "build": "Bâtir", "gather": "Récolter", "return": "Déposer", "repair": "Réparer",
	"garrison": "Garnison", "release": "Rendre à l'armée", "follow": "Suivre", "explore": "Explorer"}
const MOVING := ["move", "amove"]

# ---------------------------------------------------------------- capacités

static func allowed_steps(u: SimWorld.Unit) -> Array:
	if Rules.unit_has(u.type, "military"):
		return MILITARY_STEPS
	if Rules.unit_has(u.type, "worker"):
		return WORKER_STEPS
	if Rules.unit_has(u.type, "scout"):
		return SCOUT_STEPS
	return []

static func can_queue(u: SimWorld.Unit, kind: String) -> bool:
	return allowed_steps(u).has(kind)

# ---------------------------------------------------------------- validation

static func _units(w: SimWorld, team: int, cmd: Dictionary) -> Array:
	var raw_ids = cmd.get("units", [])
	if not raw_ids is Array:
		return []
	var ids: Array = raw_ids
	var out: Array = []
	var seen: Dictionary = {}
	for raw in ids:
		if not (raw is int or raw is float):
			return []
		var u: SimWorld.Unit = w.units.get(int(raw)) as SimWorld.Unit
		if u == null or u.team != team or seen.has(u.id):
			return []
		seen[u.id] = true
		out.append(u)
	return out

static func validate_step(w: SimWorld, team: int, step) -> String:
	if not step is Dictionary:
		return "étape invalide"
	var kind: String = String((step as Dictionary).get("type", ""))
	if not STEP_LABELS.has(kind):
		return "étape invalide"
	var s: Dictionary = step
	if kind in ["escort", "follow"]:
		var target_unit: SimWorld.Unit = w.units.get(int(s.get("target", -1))) as SimWorld.Unit
		if target_unit == null or target_unit.team != team:
			return "cible d'escorte alliée requise" if kind == "escort" else "unité alliée à suivre requise"
	if kind == "attack":
		var foe = w.entity(int(s.get("target", -1)))
		if foe == null:
			return "cible introuvable"
		if not w.factions.hostile(team, foe.team):
			return "cible non hostile"
		if not w.is_visible_to(team, w.entity_pos(foe)):
			return "cible hors de vue"
	if kind in ["build", "repair", "garrison"]:
		var b: SimWorld.Building = w.buildings.get(int(s.get("building", -1))) as SimWorld.Building
		if b == null or b.team != team:
			return "bâtiment allié requis"
		if kind == "build" and b.complete:
			return "ce bâtiment est déjà achevé"
		if kind == "repair" and (not b.complete or b.hp >= b.max_hp - 0.01):
			return "rien à réparer"
		if kind == "garrison" and (not b.complete or UnitCommands.capacity(b) <= 0):
			return "ce bâtiment n'accueille pas de garnison"
	if kind == "gather":
		var target = UnitCommands.resource_target(w, team, int(s.get("node", -1)))
		if target == null:
			return "ressource épuisée, inexplorée ou indisponible"
	if kind == "wait":
		var ticks = s.get("ticks", 10)
		if not (ticks is int or ticks is float) or int(ticks) < 1 or int(ticks) > 36000:
			return "durée d'attente invalide"
	if s.has("pos"):
		if not s["pos"] is Array and not s["pos"] is Vector2:
			return "destination inaccessible"
		if s["pos"] is Array and (s["pos"] as Array).size() < 2:
			return "destination inaccessible"
		var pos: Vector2 = w._v2(s["pos"])
		if not pos.is_finite() or not w.walkable(w.cell_of(pos)):
			return "destination inaccessible"
	if s.has("back"):
		var back: Vector2 = w._v2(s["back"])
		if not back.is_finite() or not w.walkable(w.cell_of(back)):
			return "destination inaccessible"
	if kind in ["move", "amove", "defend", "patrol"] and not s.has("pos"):
		return "destination requise"
	return ""

static func _validate(w: SimWorld, team: int, units: Array, orders: Array) -> String:
	if units.is_empty() or units.size() > MAX_UNITS or orders.is_empty() or orders.size() > MAX_STEPS:
		return "1 à 16 étapes, 128 unités maximum"
	for order in orders:
		var why: String = validate_step(w, team, order)
		if why != "":
			return why
	for u in units:
		if allowed_steps(u).is_empty():
			return "unité militaire alliée requise"
		for order in orders:
			if not can_queue(u, String((order as Dictionary)["type"])):
				return "étape « %s » impossible pour : %s" % [STEP_LABELS[String((order as Dictionary)["type"])], Rules.UNITS[u.type]["label"]]
	return ""

# ---------------------------------------------------------------- commandes

static func replace(w: SimWorld, cmd: Dictionary) -> Dictionary:
	## `queue_orders` : remplace la file (comportement 0.14 conservé pour les anciennes étapes).
	var team: int = int(cmd["team"])
	var units: Array = _units(w, team, cmd)
	var raw_orders = cmd.get("orders", [])
	var orders: Array = raw_orders if raw_orders is Array else []
	var raw_ids = cmd.get("units", [])
	if units.is_empty() and raw_ids is Array and not (raw_ids as Array).is_empty():
		return w._no("unité militaire alliée requise")
	var why: String = _validate(w, team, units, orders)
	if why != "":
		return w._no(why)
	_install(w, units, orders, bool(cmd.get("loop", false)), false)
	return {"ok": true, "steps": orders.size()}

static func append(w: SimWorld, cmd: Dictionary) -> Dictionary:
	## `queue_append` : ajoute des étapes à la fin de la file existante (mode « Enchaîner »).
	var team: int = int(cmd["team"])
	var units: Array = _units(w, team, cmd)
	var raw_orders = cmd.get("orders", [])
	var orders: Array = raw_orders if raw_orders is Array else []
	var why: String = _validate(w, team, units, orders)
	if why != "":
		return w._no(why)
	for u in units:
		var remaining: int = u.order_steps.size() if not u.order_steps.is_empty() else 0
		if remaining + orders.size() > MAX_STEPS:
			return w._no("file pleine : %d étapes au plus" % MAX_STEPS)
	_install(w, units, orders, bool(cmd.get("loop", false)), true)
	return {"ok": true, "steps": (units[0] as SimWorld.Unit).order_steps.size()}

static func edit(w: SimWorld, cmd: Dictionary) -> Dictionary:
	## `queue_edit` : remove / move / insert / loop / undo, appliqué à toutes les unités désignées.
	var team: int = int(cmd["team"])
	var units: Array = _units(w, team, cmd)
	if units.is_empty():
		return w._no("aucune unité alliée désignée")
	var op: String = String(cmd.get("op", ""))
	var index: int = int(cmd.get("index", -1))
	for u in units:
		if u.order_steps.is_empty():
			return w._no("aucune file d'ordres à modifier")
	match op:
		"remove", "move":
			for u in units:
				if index < 0 or index >= u.order_steps.size():
					return w._no("étape introuvable")
			if op == "move":
				var probe: Dictionary = {"type": "move", "pos": cmd.get("pos", [])}
				var why: String = validate_step(w, team, probe)
				if why != "":
					return w._no(why)
				for u in units:
					if not (u.order_steps[index] as Dictionary).has("pos"):
						return w._no("cette étape n'a pas de destination")
		"insert":
			var why_insert: String = validate_step(w, team, cmd.get("step", {}))
			if why_insert != "":
				return w._no(why_insert)
			for u in units:
				if index < 0 or index > u.order_steps.size():
					return w._no("position d'insertion invalide")
				if u.order_steps.size() >= MAX_STEPS:
					return w._no("file pleine : %d étapes au plus" % MAX_STEPS)
				if not can_queue(u, String((cmd["step"] as Dictionary)["type"])):
					return w._no("étape impossible pour cette unité")
		"loop":
			if not cmd.get("value", false) is bool:
				return w._no("valeur de boucle invalide")
		"undo":
			pass
		_:
			return w._no("modification inconnue")
	for u in units:
		match op:
			"remove":
				u.order_steps.remove_at(index)
				_after_removal(w, u, index)
			"undo":
				var last: int = u.order_steps.size() - 1
				u.order_steps.remove_at(last)
				_after_removal(w, u, last)
			"move":
				(u.order_steps[index] as Dictionary)["pos"] = [float(w._v2(cmd["pos"]).x), float(w._v2(cmd["pos"]).y)]
				if index == u.order_step:
					_activate(w, u)
			"insert":
				u.order_steps.insert(index, (cmd["step"] as Dictionary).duplicate(true))
				if index < u.order_step:
					u.order_step += 1
				elif index == u.order_step:
					_activate(w, u)
			"loop":
				u.order_loop = bool(cmd["value"])
	return w._ok()

static func clear(w: SimWorld, cmd: Dictionary) -> Dictionary:
	var team: int = int(cmd["team"])
	var units: Array = _units(w, team, cmd)
	if units.is_empty():
		return w._no("aucune unité alliée désignée")
	for u in units:
		finish(w, u, true)
	return w._ok()

static func _after_removal(w: SimWorld, u: SimWorld.Unit, removed: int) -> void:
	if u.order_steps.is_empty():
		finish(w, u, true)
		return
	if removed < u.order_step:
		u.order_step -= 1
	elif removed == u.order_step:
		if u.order_step >= u.order_steps.size():
			u.order_step = 0 if u.order_loop else u.order_steps.size()
		_activate(w, u)

static func _install(w: SimWorld, units: Array, orders: Array, loop: bool, appending: bool) -> void:
	var group: int = 0
	if units.size() > 1:
		var lowest: int = 1 << 30
		for u in units:
			lowest = mini(lowest, u.id)
		group = w.tick * 4096 + (lowest % 4096) + 1
	var offsets: Array = UnitCommands.group_offsets(w, units)
	for i in units.size():
		var u: SimWorld.Unit = units[i]
		if u.garrison_id != -1:
			UnitCommands.leave_garrison(w, u)
		u.rally_contract = {}
		u.order_group = group
		u.order_offset = offsets[i]
		if appending and not u.order_steps.is_empty():
			for order in orders:
				u.order_steps.append((order as Dictionary).duplicate(true))
			u.order_loop = u.order_loop or loop
			continue
		u.order_steps = orders.duplicate(true)
		u.order_step = 0
		u.order_loop = loop
		u.step_since = w.tick
		if Rules.unit_has(u.type, "military") or Rules.unit_has(u.type, "scout"):
			u.direct = true
		_activate(w, u)

static func finish(w: SimWorld, u: SimWorld.Unit, hold: bool) -> void:
	## Fin ou abandon de file : l'unité reste sur place (militaire : contrôle direct conservé).
	var was_worker_job: bool = Rules.unit_has(u.type, "worker") and u.manual
	u.order_steps = []
	u.order_step = 0
	u.order_loop = false
	u.order_group = 0
	u.order_offset = Vector2.ZERO
	u.step_arrived = -1
	if hold:
		u.order = {"type": "hold", "pos": u.pos}
		u.target_id = -1
		u.path = PackedVector2Array()
		u.path_goal = Vector2(-999, -999)
	if was_worker_job and not u.direct:
		u.manual = false

# ---------------------------------------------------------------- exécution (pas fixe)

static func _goal(w: SimWorld, u: SimWorld.Unit, pos: Vector2) -> Vector2:
	var shifted: Vector2 = pos + u.order_offset
	if u.order_offset != Vector2.ZERO and w.walkable(w.cell_of(shifted)):
		return shifted
	return pos

static func _activate(w: SimWorld, u: SimWorld.Unit) -> void:
	if u.order_step >= u.order_steps.size():
		if u.order_loop and u.order_steps.size() >= 2:
			u.order_step = 0
		else:
			_complete(w, u)
			return
	var step: Dictionary = u.order_steps[u.order_step]
	var kind: String = String(step["type"])
	u.step_since = w.tick
	u.step_arrived = -1
	var worker: bool = Rules.unit_has(u.type, "worker")
	if kind in ["move", "amove", "wait", "defend", "patrol", "escort"]:
		if worker:
			_worker_manual(w, u, true)
		var base: Vector2 = w._v2(step.get("pos", [u.pos.x, u.pos.y]))
		var target_pos: Vector2 = _goal(w, u, base) if step.has("pos") else base
		u.order = {"type": "amove" if kind in ["defend", "patrol", "escort"] else ("hold" if kind == "wait" else kind), "pos": target_pos}
		return
	match kind:
		"follow":
			if worker:
				_worker_manual(w, u, true)
			var leader: SimWorld.Unit = w.units.get(int(step.get("target", -1))) as SimWorld.Unit
			u.order = {"type": "move", "pos": leader.pos + u.order_offset + Vector2(1.2, 0.0) if leader != null else u.pos}
		"attack":
			u.order = {"type": "attack", "target": int(step["target"])}
			u.target_id = -1
		"build", "repair":
			_worker_manual(w, u, false)
			u.task = "build" if kind == "build" else "repair"
			u.build_id = int(step["building"])
			u.state = "to_build"
			u.path_goal = Vector2(-999, -999)
		"gather":
			_worker_manual(w, u, false)
			var target = UnitCommands.resource_target(w, u.team, int(step["node"]))
			if target != null:
				u.task = String(target.res) if target is SimWorld.ResNode else "food"
				u.node_id = target.id
				if target is SimWorld.Building:
					target.farmer = u.id
				u.state = "to_node"
				u.path_goal = Vector2(-999, -999)
		"return":
			_worker_manual(w, u, false)
			if u.carry_amt > 0.01:
				u.task = u.carry_res
				u.state = "to_drop"
		"garrison":
			if worker:
				_worker_manual(w, u, true)
			var b: SimWorld.Building = w.buildings.get(int(step["building"])) as SimWorld.Building
			if b != null:
				u.order = {"type": "move", "pos": w.approach_point(u.pos, b.center, b.size * 0.5 + 0.6)}
		"explore":
			var spot: Vector2 = UnitCommands.explore_target(w, u, step)
			u.order = {"type": "move", "pos": spot if spot.x >= 0.0 else u.pos}
		"release":
			pass

static func _worker_manual(w: SimWorld, u: SimWorld.Unit, moving: bool) -> void:
	w._release_worker_job(u)
	u.manual = true
	u.direct = moving
	if moving:
		u.task = ""
		u.state = "idle"

static func _complete(w: SimWorld, u: SimWorld.Unit) -> void:
	var last: String = String((u.order_steps[u.order_steps.size() - 1] as Dictionary)["type"]) if not u.order_steps.is_empty() else ""
	u.order_steps = []
	u.order_step = 0
	u.order_group = 0
	u.step_arrived = -1
	if Rules.unit_has(u.type, "worker"):
		if last in ["build", "repair", "return", "gather"]:
			u.manual = false
			u.direct = false
			u.task = "" if last != "gather" else u.task
		else:
			u.manual = false

static func _advance(w: SimWorld, u: SimWorld.Unit) -> void:
	u.order_step += 1
	_activate(w, u)

static func _skip(w: SimWorld, u: SimWorld.Unit, reason: String) -> void:
	w.emit("file", u.team, "%s #%d : étape %d sautée (%s)" % [Rules.UNITS[u.type]["label"], u.id, u.order_step + 1, reason], {"unit": u.id, "pos": u.pos})
	_advance(w, u)

static func step(w: SimWorld) -> void:
	# Instantané des groupes : chaque membre décide sur le même état (déterminisme, avancée commune).
	var groups: Dictionary = {}
	for u in w.units.values():
		if u.order_steps.is_empty() or u.order_group == 0:
			continue
		var key: String = "%d:%d" % [u.order_group, u.order_step]
		var entry: Array = groups.get(key, [0, 0, 1 << 30]) as Array
		entry[0] = int(entry[0]) + 1
		if u.step_arrived >= 0:
			entry[1] = int(entry[1]) + 1
			entry[2] = mini(int(entry[2]), u.step_arrived)
		groups[key] = entry
	for u in w.units.values():
		if u.order_steps.is_empty():
			continue
		if u.order_step >= u.order_steps.size():
			_activate(w, u)
			continue
		var action: Dictionary = u.order_steps[u.order_step]
		var kind: String = String(action["type"])
		match kind:
			"escort":
				var target: SimWorld.Unit = w.units.get(int(action.get("target", -1))) as SimWorld.Unit
				if target != null and target.team == u.team: u.order["pos"] = target.pos + Vector2(2, 0)
				else: _advance(w, u)
			"follow":
				var leader: SimWorld.Unit = w.units.get(int(action.get("target", -1))) as SimWorld.Unit
				if leader == null or leader.team != u.team:
					_advance(w, u)
				elif w.tick % 5 == 0:
					var spot: Vector2 = leader.pos + u.order_offset + Vector2(1.2, 0.0)
					u.order = {"type": "move" if u.pos.distance_to(spot) > 1.4 else "hold", "pos": spot if w.walkable(w.cell_of(spot)) else leader.pos}
			"wait":
				if w.tick - u.step_since >= clampi(int(action.get("ticks", 10)), 1, 36000): _advance(w, u)
			"defend":
				pass
			"attack":
				var foe = w.entity(int(action.get("target", -1)))
				if foe == null or not w.factions.hostile(u.team, foe.team):
					_advance(w, u)
				elif String(u.order.get("type", "")) != "attack":
					u.order = {"type": "attack", "target": foe.id}
			"build", "repair":
				var site: SimWorld.Building = w.buildings.get(int(action.get("building", -1))) as SimWorld.Building
				if site == null or site.team != u.team:
					_skip(w, u, "bâtiment détruit")
				elif (kind == "build" and site.complete) or (kind == "repair" and site.hp >= site.max_hp - 0.01):
					_advance(w, u)
				elif u.task != kind or u.build_id != site.id:
					if u.blocked_reason == "chantier inaccessible":
						_skip(w, u, "chantier inaccessible")
					else:
						_activate(w, u)
			"gather":
				var spot_target = UnitCommands.resource_target(w, u.team, int(action.get("node", -1)))
				if spot_target == null:
					_skip(w, u, "ressource épuisée")
				elif u.task == "" and u.carry_amt < 0.01:
					_activate(w, u)
			"return":
				if u.carry_amt <= 0.01:
					_advance(w, u)
			"garrison":
				var hall: SimWorld.Building = w.buildings.get(int(action.get("building", -1))) as SimWorld.Building
				if hall == null or hall.team != u.team:
					_skip(w, u, "bâtiment perdu")
				elif u.garrison_id == hall.id:
					pass
				elif u.pos.distance_to(hall.center) <= hall.size * 0.5 + 1.7:
					if not UnitCommands.enter_garrison(w, u, hall):
						_skip(w, u, "garnison pleine")
				elif w.tick - u.step_since > 30 and u.path_failed:
					_skip(w, u, "bâtiment inaccessible")
			"release":
				UnitCommands.release(w, u)
			"explore":
				if u.pos.distance_to(u.order.get("pos", u.pos)) < 1.5 or (u.path_failed and w.tick - u.step_since > 20) or w.tick - u.step_since > 600:
					if u.path_failed:
						var skipped: Array = action.get("skip", []) as Array
						skipped.append([float(u.order["pos"].x), float(u.order["pos"].y)])
						while skipped.size() > 32: skipped.remove_at(0)
						action["skip"] = skipped
					var spot_explore: Vector2 = UnitCommands.explore_target(w, u, action)
					if spot_explore.x < 0.0:
						w.emit("file", u.team, "%s #%d : plus aucune zone inexplorée accessible" % [Rules.UNITS[u.type]["label"], u.id], {"unit": u.id, "pos": u.pos})
						_advance(w, u)
					else:
						u.step_since = w.tick
						u.order = {"type": "move", "pos": spot_explore}
			_:
				# Déplacements : arrivée, attente du groupe, ou étape sautée si la destination est inaccessible.
				if u.path_failed and w.tick - u.step_since > BLOCKED_SKIP and u.pos.distance_to(u.order.get("pos", u.pos)) >= 1.0:
					_skip(w, u, "destination inaccessible")
					continue
				var arrived: bool = u.pos.distance_to(u.order.get("pos", u.pos)) < 1.0
				if kind == "patrol":
					if arrived:
						var back: Vector2 = w._v2(action.get("back", [u.pos.x, u.pos.y]))
						var ahead: Vector2 = w._v2(action["pos"])
						u.order["pos"] = back if u.pos.distance_to(ahead) < 1.0 else ahead
						u.order["type"] = "amove"
					continue
				if not arrived and u.step_arrived < 0:
					continue
				if u.order_group == 0:
					_advance(w, u)
					continue
				if u.step_arrived < 0:
					u.step_arrived = w.tick
				var entry: Array = groups.get("%d:%d" % [u.order_group, u.order_step], [1, 1, w.tick]) as Array
				if int(entry[1]) >= int(entry[0]) or w.tick - int(entry[2]) >= GROUP_TIMEOUT:
					_advance(w, u)

# ---------------------------------------------------------------- lecture pour l'interface

static func describe(u: SimWorld.Unit) -> Array:
	## Étapes lisibles (pour l'affichage au sol et la carte de commandes) : [{type, label, pos?, current}].
	var out: Array = []
	for i in u.order_steps.size():
		var s: Dictionary = u.order_steps[i]
		var entry: Dictionary = {"type": String(s["type"]), "label": String(STEP_LABELS.get(String(s["type"]), "?")), "index": i, "current": i == u.order_step, "done": i < u.order_step}
		if s.has("pos"):
			entry["pos"] = Vector2(float((s["pos"] as Array)[0]), float((s["pos"] as Array)[1])) if s["pos"] is Array else s["pos"]
		out.append(entry)
	return out
