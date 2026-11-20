class_name UnitCommands
extends RefCounted
## 0.17 — Commandes classiques des grands RTS ajoutées à la carte tactique (règles de jeu, pas fixe) :
## arrêt, tenir, postures, formations, repli, garnison, réparation, ordres manuels aux ouvriers, démolition,
## cible prioritaire, suivre, exploration automatique, production répétée, ralliement sur ressource,
## annulation d'un élément précis de la file, et files d'ordres (OrderQueue).
## Chaque commande : validation complète, refus sans aucun effet, état sauvegardé (variables de script),
## mêmes conditions pour le joueur et pour l'IA.

const COMMANDS := ["stop", "hold", "stance", "formation", "retreat", "garrison", "ungarrison", "repair", "build_assign",
	"gather", "return_drop", "worker_auto", "demolish", "target_priority", "follow", "explore", "repeat_train",
	"rally_resource", "cancel_train_at", "queue_append", "queue_edit", "queue_clear"]
const STANCES := ["aggressive", "defensive", "hold", "passive"]
const STANCE_LABELS := {"aggressive": "Agressive", "defensive": "Défensive", "hold": "Tenir", "passive": "Passive"}
const FORMATIONS := ["grid", "line", "column", "box", "spread"]
const FORMATION_LABELS := {"grid": "Bloc", "line": "Ligne", "column": "Colonne", "box": "Carré", "spread": "Dispersée"}
const PRIORITIES := ["", "ranged", "cavalry", "infantry", "siege", "vehicle", "worker", "building"]
const PRIORITY_LABELS := {"": "La plus proche", "ranged": "Tireurs", "cavalry": "Cavaliers", "infantry": "Fantassins", "siege": "Machines de siège", "vehicle": "Véhicules", "worker": "Ouvriers", "building": "Bâtiments"}
## Places de garnison par bâtiment achevé (PROVISOIRE, à équilibrer en partie réelle).
const GARRISON := {"centre": 12, "fort": 10, "caserne": 6, "academie": 6, "usine": 6, "gare": 6, "entrepot": 4, "marche": 4, "depot": 4, "maison": 3, "relais": 3}
## Réparation : un ouvrier rend la totalité des PV en deux fois le temps de construction ; coût = 40 % du prix, au prorata.
const REPAIR_TIME_FACTOR := 2.0
const REPAIR_COST_SHARE := 0.4
const DEMOLISH_REFUND := 0.5          # chantier inachevé : la moitié du coût revient ; bâtiment achevé : rien.
const SPACING := 1.3

static func handles(kind: String) -> bool:
	return COMMANDS.has(kind)

# ---------------------------------------------------------------- outils

static func _selection(w: SimWorld, team: int, cmd: Dictionary) -> Array:
	## Unités désignées par `units` ou `squad`. Tableau vide = désignation invalide (aucun effet).
	var out: Array = []
	if cmd.has("squad"):
		var s: SimWorld.Squad = w.squads.get(int(cmd["squad"])) as SimWorld.Squad
		if s == null or s.team != team:
			return []
		return w._squad_members(s)
	var raw = cmd.get("units", [])
	if not raw is Array or (raw as Array).size() > OrderQueue.MAX_UNITS:
		return []
	var seen: Dictionary = {}
	for value in raw:
		if not (value is int or value is float):
			return []
		var u: SimWorld.Unit = w.units.get(int(value)) as SimWorld.Unit
		if u == null or u.team != team or seen.has(u.id):
			return []
		seen[u.id] = true
		out.append(u)
	return out

static func _squad_of(w: SimWorld, team: int, cmd: Dictionary) -> SimWorld.Squad:
	if not cmd.has("squad"):
		return null
	var s: SimWorld.Squad = w.squads.get(int(cmd["squad"])) as SimWorld.Squad
	return s if s != null and s.team == team else null

static func ids_of(units: Array) -> Array:
	var out: Array = []
	for u in units:
		out.append((u as SimWorld.Unit).id)
	return out

static func capacity(b: SimWorld.Building) -> int:
	return int(GARRISON.get(b.type, 0))

static func occupants(w: SimWorld, b: SimWorld.Building) -> Array:
	var out: Array = []
	for u in w.units.values():
		if u.garrison_id == b.id:
			out.append(u)
	return out

static func can_garrison(u: SimWorld.Unit) -> bool:
	if Rules.unit_has(u.type, "worker"):
		return true
	return Rules.unit_has(u.type, "infantry") and not Rules.unit_has(u.type, "vehicle") and not Rules.unit_has(u.type, "air")

static func resource_target(w: SimWorld, team: int, id: int, worker: SimWorld.Unit = null):
	## Gisement exploré et non épuisé, ou ferme alliée achevée et libre.
	var node: SimWorld.ResNode = w.nodes.get(id) as SimWorld.ResNode
	if node != null:
		return node if node.amount > 0.0 and w.is_explored_by(team, node.pos) else null
	var farm: SimWorld.Building = w.buildings.get(id) as SimWorld.Building
	if farm != null and farm.type == "ferme" and farm.team == team and farm.complete:
		if farm.farmer == -1 or not w.units.has(farm.farmer) or (worker != null and farm.farmer == worker.id):
			return farm
		var occupant: SimWorld.Unit = w.units.get(farm.farmer) as SimWorld.Unit
		if occupant != null and occupant.node_id != farm.id:
			return farm
	return null

static func group_offsets(w: SimWorld, units: Array) -> Array:
	## Décalages de formation conservés par une file de groupe (les membres gardent leur place relative).
	var out: Array = []
	var n: int = units.size()
	if n <= 1:
		for i in n: out.append(Vector2.ZERO)
		return out
	var squad: SimWorld.Squad = null
	var same_squad: bool = true
	for u in units:
		if u.squad_id == -1 or (squad != null and squad.id != u.squad_id):
			same_squad = false
		elif squad == null:
			squad = w.squads.get(u.squad_id) as SimWorld.Squad
	var kind: String = squad.formation if same_squad and squad != null and squad.formation != "" else "grid"
	var facing: Vector2 = squad.facing if same_squad and squad != null else Vector2.ZERO
	var order: Array = units.duplicate()
	order.sort_custom(func(a, b): return a.id < b.id)
	var index_of: Dictionary = {}
	for i in order.size():
		index_of[(order[i] as SimWorld.Unit).id] = i
	for u in units:
		out.append(formation_offset(kind, int(index_of[u.id]), n, facing))
	return out

static func formation_offset(kind: String, i: int, n: int, facing: Vector2) -> Vector2:
	var off: Vector2 = Vector2.ZERO
	match kind:
		"line":
			off = Vector2((float(i) - float(n - 1) * 0.5) * SPACING, 0.0)
		"column":
			off = Vector2(0.0, (float(i) - float(n - 1) * 0.5) * SPACING)
		"box":
			var side: int = 2
			while 4 * (side - 1) < n:
				side += 1
			var per: int = side - 1
			var edge: int = i / per
			var k: int = i % per
			var half: float = float(side - 1) * 0.5
			match edge:
				0: off = Vector2(float(k) - half, -half)
				1: off = Vector2(half, float(k) - half)
				2: off = Vector2(half - float(k), half)
				_: off = Vector2(-half, half - float(k))
			off *= SPACING
		"spread":
			var cols_s: int = int(ceil(sqrt(float(n))))
			off = Vector2((float(i % cols_s) - float(cols_s - 1) * 0.5) * SPACING * 2.0, (float(i / cols_s) - float((n - 1) / cols_s) * 0.5) * SPACING * 2.0)
		_:
			var cols: int = int(ceil(sqrt(float(n))))
			off = Vector2((float(i % cols) - float(cols - 1) * 0.5) * SPACING, (float(i / cols) - float((n - 1) / cols) * 0.5) * SPACING)
	if facing != Vector2.ZERO and kind in ["line", "column", "box"]:
		off = off.rotated(facing.angle() - PI * 0.5)
	return off

static func formation_slot(w: SimWorld, s: SimWorld.Squad, u: SimWorld.Unit) -> Vector2:
	## Remplace la grille fixe de SimWorld.formation_slot quand une formation a été choisie.
	return formation_offset(s.formation, maxi(0, s.units.find(u.id)), s.units.size(), s.facing)

static func on_squad_order(w: SimWorld, s: SimWorld.Squad, order: Dictionary) -> void:
	## Orientation automatique de la formation vers la destination.
	if not order.has("pos"):
		return
	var center: Vector2 = w._squad_center(s)
	var dir: Vector2 = (w._v2(order["pos"]) - center)
	if dir.length() > 0.5:
		s.facing = dir.normalized()

static func on_spawn(w: SimWorld, u: SimWorld.Unit, b: SimWorld.Building) -> void:
	## Recrue : hérite de la posture de son escouade ; ouvrier : ralliement direct sur une ressource.
	if u.squad_id != -1 and w.squads.has(u.squad_id):
		var s: SimWorld.Squad = w.squads[u.squad_id]
		if s.stance != "": u.stance = s.stance
		if s.target_pref != "": u.target_pref = s.target_pref
	if b.rally_node != -1 and Rules.unit_has(u.type, "worker"):
		var target = resource_target(w, u.team, b.rally_node, u)
		if target == null:
			b.rally_node = -1
			return
		u.order_steps = [{"type": "gather", "node": b.rally_node}]
		u.order_step = 0
		OrderQueue._activate(w, u)

# ---------------------------------------------------------------- commandes

static func command(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var kind: String = String(cmd.get("t", ""))
	match kind:
		"queue_append": return OrderQueue.append(w, cmd)
		"queue_edit": return OrderQueue.edit(w, cmd)
		"queue_clear": return OrderQueue.clear(w, cmd)
		"stop", "hold": return _stop(w, team, cmd, kind == "hold")
		"stance": return _stance(w, team, cmd)
		"formation": return _formation(w, team, cmd)
		"retreat": return _retreat(w, team, cmd)
		"garrison": return _garrison(w, team, cmd)
		"ungarrison": return _ungarrison(w, team, cmd)
		"repair", "build_assign", "gather", "return_drop": return _worker_job(w, team, cmd, kind)
		"worker_auto": return _worker_auto(w, team, cmd)
		"demolish": return _demolish(w, team, cmd)
		"target_priority": return _priority(w, team, cmd)
		"follow": return _follow(w, team, cmd)
		"explore": return _explore(w, team, cmd)
		"repeat_train": return _repeat(w, team, cmd)
		"rally_resource": return _rally_resource(w, team, cmd)
		"cancel_train_at": return _cancel_at(w, team, cmd)
	return w._no("ordre inconnu")

static func _stop(w: SimWorld, team: int, cmd: Dictionary, hold: bool) -> Dictionary:
	var units: Array = _selection(w, team, cmd)
	if units.is_empty():
		return w._no("aucune unité alliée désignée")
	var squad: SimWorld.Squad = _squad_of(w, team, cmd)
	for u in units:
		OrderQueue.finish(w, u, true)
		if Rules.unit_has(u.type, "worker"):
			w._release_worker_job(u)
			u.task = ""
			u.state = "idle"
			u.manual = false
			u.direct = true
		elif squad == null:
			u.direct = true
		if hold:
			u.stance = "hold"
	if squad != null:
		squad.order = {"type": "hold", "pos": w._squad_center(squad)}
		squad.direct = true
		squad.army_role = "Ordre direct"
		for u in units:
			u.direct = false
		if hold:
			squad.stance = "hold"
	w.emit("ordre", team, ("Tenir la position" if hold else "Arrêt") + " : %d unité(s)" % units.size(), {"count": units.size()})
	return w._ok()

static func _stance(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var value: String = String(cmd.get("value", ""))
	if not STANCES.has(value):
		return w._no("posture inconnue")
	var units: Array = _selection(w, team, cmd)
	if units.is_empty():
		return w._no("aucune unité alliée désignée")
	for u in units:
		if not Rules.unit_has(u.type, "military") and not Rules.unit_has(u.type, "scout"):
			return w._no("posture réservée aux troupes")
	for u in units:
		u.stance = "" if value == "aggressive" else value
		if value == "passive":
			u.target_id = -1
	var squad: SimWorld.Squad = _squad_of(w, team, cmd)
	if squad != null:
		squad.stance = "" if value == "aggressive" else value
	return w._ok()

static func _formation(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var value: String = String(cmd.get("value", ""))
	if not FORMATIONS.has(value):
		return w._no("formation inconnue")
	var squads: Array = []
	var squad: SimWorld.Squad = _squad_of(w, team, cmd)
	if squad != null:
		squads.append(squad)
	else:
		for u in _selection(w, team, cmd):
			if u.squad_id != -1 and w.squads.has(u.squad_id) and not squads.has(w.squads[u.squad_id]):
				squads.append(w.squads[u.squad_id])
	if squads.is_empty():
		return w._no("formation réservée aux escouades")
	for s in squads:
		s.formation = "" if value == "grid" else value
	return w._ok()

static func refuge(w: SimWorld, team: int, from: Vector2) -> Vector2:
	var best: Vector2 = Vector2(-1, -1)
	var bd: float = INF
	for b in w.team_buildings(team, "centre", true) + w.team_buildings(team, "fort", true):
		var d: float = from.distance_squared_to(b.center)
		if d < bd:
			bd = d
			best = w.approach_point(from, b.center, b.size * 0.5 + 1.5)
	return best

static func _retreat(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var units: Array = _selection(w, team, cmd)
	if units.is_empty():
		return w._no("aucune unité alliée désignée")
	var center: Vector2 = Vector2.ZERO
	for u in units:
		center += u.pos
	center /= float(units.size())
	var home: Vector2 = refuge(w, team, center)
	if home.x < 0.0:
		return w._no("aucun centre ni fort où se replier")
	var squad: SimWorld.Squad = _squad_of(w, team, cmd)
	if squad != null:
		for u in units:
			OrderQueue.finish(w, u, false)
			u.direct = false
			u.target_id = -1
		squad.order = {"type": "move", "pos": home}
		squad.direct = true
		squad.army_role = "Repli"
	else:
		var result: Dictionary = OrderQueue.replace(w, {"team": team, "units": ids_of(units), "orders": [{"type": "move", "pos": [home.x, home.y]}]})
		if not bool(result.get("ok", false)):
			return result
	w.emit("ordre", team, "Repli vers la base : %d unité(s)" % units.size(), {"pos": home})
	return w._ok()

static func _garrison(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var b: SimWorld.Building = w.buildings.get(int(cmd.get("building", -1))) as SimWorld.Building
	if b == null or b.team != team or not b.complete:
		return w._no("bâtiment allié achevé requis")
	if capacity(b) <= 0:
		return w._no("ce bâtiment n'accueille pas de garnison")
	var units: Array = _selection(w, team, cmd)
	if units.is_empty():
		return w._no("aucune unité alliée désignée")
	for u in units:
		if not can_garrison(u):
			return w._no("%s ne peut pas entrer en garnison" % Rules.UNITS[u.type]["label"])
	var inside: int = occupants(w, b).size()
	var newcomers: int = 0
	for u in units:
		if u.garrison_id != b.id: newcomers += 1
	if inside + newcomers > capacity(b):
		return w._no("garnison pleine (%d/%d)" % [inside, capacity(b)])
	return OrderQueue.replace(w, {"team": team, "units": ids_of(units), "orders": [{"type": "garrison", "building": b.id}]})

static func enter_garrison(w: SimWorld, u: SimWorld.Unit, b: SimWorld.Building) -> bool:
	if occupants(w, b).size() >= capacity(b):
		return false
	w._release_worker_job(u)
	u.garrison_id = b.id
	u.pos = b.center
	u.prev_pos = b.center
	u.path = PackedVector2Array()
	u.target_id = -1
	u.state = "garrison"
	w.emit("garnison", u.team, "%s en garnison : %s" % [Rules.UNITS[u.type]["label"], Rules.BUILDINGS[b.type]["label"]], {"unit": u.id, "building": b.id})
	return true

static func leave_garrison(w: SimWorld, u: SimWorld.Unit) -> void:
	if u.garrison_id == -1:
		return
	var b: SimWorld.Building = w.buildings.get(u.garrison_id) as SimWorld.Building
	var origin: Vector2 = b.center if b != null else u.pos
	var radius: float = b.size * 0.5 + 0.8 if b != null else 0.5
	var exit: Vector2 = w.approach_point(origin + Vector2(0.0, radius), origin, radius)
	if exit.x < 0.0:
		exit = Vector2(w.nearest_walkable(w.cell_of(origin), origin)) + Vector2(0.5, 0.5)
	u.garrison_id = -1
	u.pos = exit
	u.prev_pos = exit
	u.state = "idle"
	u.order = {"type": "hold", "pos": exit}
	if Rules.unit_has(u.type, "worker"):
		u.manual = false
		u.direct = false
		u.task = ""

static func _ungarrison(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var leaving: Array = []
	if cmd.has("building"):
		var b: SimWorld.Building = w.buildings.get(int(cmd["building"])) as SimWorld.Building
		if b == null or b.team != team:
			return w._no("bâtiment allié requis")
		leaving = occupants(w, b)
	else:
		for u in _selection(w, team, cmd):
			if u.garrison_id != -1: leaving.append(u)
	if leaving.is_empty():
		return w._no("aucune unité en garnison")
	for u in leaving:
		OrderQueue.finish(w, u, false)
		leave_garrison(w, u)
	return w._ok()

static func _worker_job(w: SimWorld, team: int, cmd: Dictionary, kind: String) -> Dictionary:
	var units: Array = _selection(w, team, cmd)
	if units.is_empty():
		return w._no("aucun ouvrier allié désigné")
	for u in units:
		if not Rules.unit_has(u.type, "worker"):
			return w._no("ordre réservé aux ouvriers")
	var step: Dictionary = {}
	match kind:
		"repair": step = {"type": "repair", "building": int(cmd.get("building", -1))}
		"build_assign": step = {"type": "build", "building": int(cmd.get("building", -1))}
		"gather": step = {"type": "gather", "node": int(cmd.get("node", -1))}
		"return_drop":
			var loaded: bool = false
			for u in units:
				loaded = loaded or u.carry_amt > 0.01
			if not loaded:
				return w._no("aucun ouvrier ne transporte de ressource")
			if w._nearest_drop(team, units[0].pos) == null:
				return w._no("aucun dépôt (centre, entrepôt, marché)")
			step = {"type": "return"}
	if kind == "gather":
		if UrbanCity.replaces_gathering(w, team): return w._no("récolte remplacée par la ville (électricité)")
		for u in units:
			if resource_target(w, team, int(cmd.get("node", -1)), u) == null:
				return w._no("ressource épuisée, inexplorée ou ferme occupée")
		if units.size() > 1 and w.buildings.has(int(cmd.get("node", -1))):
			return w._no("une ferme n'accueille qu'un ouvrier")
	return OrderQueue.replace(w, {"team": team, "units": ids_of(units), "orders": [step]})

static func _worker_auto(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var units: Array = _selection(w, team, cmd)
	if units.is_empty():
		return w._no("aucun ouvrier allié désigné")
	for u in units:
		if not Rules.unit_has(u.type, "worker"):
			return w._no("ordre réservé aux ouvriers")
	for u in units:
		OrderQueue.finish(w, u, true)
		if u.garrison_id != -1:
			leave_garrison(w, u)
		w._release_worker_job(u)
		u.manual = false
		u.direct = false
		u.task = ""
		u.state = "idle"
		u.order = {}
	return w._ok()

static func update_repair(w: SimWorld, u: SimWorld.Unit) -> void:
	## Appelé par SimWorld._update_worker pour la tâche « repair ».
	var b: SimWorld.Building = w.buildings.get(u.build_id) as SimWorld.Building
	if b == null or not b.complete or b.team != u.team or b.hp >= b.max_hp - 0.01:
		u.task = ""
		u.build_id = -1
		u.state = "idle"
		return
	var ap: Vector2 = w.goal_for(u, b.id, b.center, b.size * 0.5 + 0.3)
	if ap.x < 0:
		u.blocked_reason = "chantier inaccessible"
		u.task = ""
		return
	if u.pos.distance_to(b.center) <= b.size * 0.5 + 1.6:
		var duration: float = float(Rules.BUILDINGS[b.type]["time"]) * REPAIR_TIME_FACTOR / CivEvolution.speed_mult(w, u.team, "build_speed")
		var gain: float = minf(b.max_hp - b.hp, b.max_hp * Rules.DT / duration)
		var cost: Dictionary = {}
		var base: Dictionary = w.scaled_cost(Rules.BUILDINGS[b.type]["cost"])
		for r in base.keys():
			cost[r] = float(base[r]) * REPAIR_COST_SHARE * gain / b.max_hp
		if not w._can_pay(u.team, cost):
			u.state = "idle"
			u.blocked_reason = "ressources insuffisantes pour réparer"
			return
		w._pay(u.team, cost)
		u.state = "build"
		u.blocked_reason = ""
		b.hp = minf(b.max_hp, b.hp + gain)
	else:
		u.state = "to_build"
		if not w._move_towards(u, ap, 0.3) and u.path.is_empty() and not u.waiting_path and u.pos.distance_to(ap) > 0.5:
			u.blocked_reason = "chantier inaccessible"
			u.task = ""

static func _demolish(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var b: SimWorld.Building = w.buildings.get(int(cmd.get("building", -1))) as SimWorld.Building
	if b == null or b.team != team:
		return w._no("bâtiment allié requis")
	if b.type == "centre" and b.complete and w.team_buildings(team, "centre", true).size() <= 1:
		return w._no("dernier centre de commandement : démolition refusée")
	var refund: Dictionary = {}
	if not b.complete:
		var base: Dictionary = w.scaled_cost(Rules.BUILDINGS[b.type]["cost"])
		for r in base.keys():
			refund[r] = float(base[r]) * DEMOLISH_REFUND
	for u in occupants(w, b):
		OrderQueue.finish(w, u, false)
		leave_garrison(w, u)
	for queued in b.queue:
		w._refund(team, w.scaled_cost(Rules.UNITS[queued]["cost"]))
		CivEvolution.on_train_cancelled(w, team, String(queued))
	b.queue.clear()
	w._destroy_building(b, -1)
	w._refund(team, refund)
	return {"ok": true, "refund": refund}

static func _priority(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var value: String = String(cmd.get("value", ""))
	if not PRIORITIES.has(value):
		return w._no("priorité de cible inconnue")
	var units: Array = _selection(w, team, cmd)
	if units.is_empty():
		return w._no("aucune unité alliée désignée")
	for u in units:
		if not Rules.unit_has(u.type, "military"):
			return w._no("priorité réservée aux troupes")
	for u in units:
		u.target_pref = value
	var squad: SimWorld.Squad = _squad_of(w, team, cmd)
	if squad != null:
		squad.target_pref = value
	return w._ok()

static func _follow(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var units: Array = _selection(w, team, cmd)
	if units.is_empty():
		return w._no("aucune unité alliée désignée")
	for u in units:
		if u.id == int(cmd.get("target", -1)):
			return w._no("une unité ne peut pas se suivre elle-même")
	return OrderQueue.replace(w, {"team": team, "units": ids_of(units), "orders": [{"type": "follow", "target": int(cmd.get("target", -1))}]})

static func _explore(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var units: Array = _selection(w, team, cmd)
	if units.is_empty():
		return w._no("aucune unité alliée désignée")
	for u in units:
		if explore_target(w, u, {}).x < 0.0:
			return w._no("aucune zone inexplorée accessible")
		break
	return OrderQueue.replace(w, {"team": team, "units": ids_of(units), "orders": [{"type": "explore"}]})

static func explore_target(w: SimWorld, u: SimWorld.Unit, step: Dictionary) -> Vector2:
	## Case inexplorée praticable la plus proche (grille de 4 cases, ordre fixe : déterministe).
	var fog: PackedByteArray = w.teams[u.team].fog
	var skipped: Array = step.get("skip", []) as Array
	var best: Vector2 = Vector2(-1, -1)
	var bd: float = INF
	var stride: int = 4
	for y in range(2, w.map_size, stride):
		for x in range(2, w.map_size, stride):
			var c: Vector2i = Vector2i(x, y)
			if fog[w.idx(c)] != 0 or not w.walkable(c):
				continue
			var p: Vector2 = Vector2(c) + Vector2(0.5, 0.5)
			var rejected: bool = false
			for raw in skipped:
				if p.distance_to(Vector2(float(raw[0]), float(raw[1]))) < 6.0:
					rejected = true
					break
			if rejected:
				continue
			var d: float = u.pos.distance_squared_to(p)
			if d < bd:
				bd = d
				best = p
	return best

static func _repeat(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var b: SimWorld.Building = w.buildings.get(int(cmd.get("building", -1))) as SimWorld.Building
	if b == null or b.team != team or not b.complete:
		return w._no("producteur allié achevé requis")
	var kind: String = String(cmd.get("unit", ""))
	if kind == "":
		b.repeat_unit = ""
		return w._ok()
	if not (Rules.BUILDINGS[b.type].get("trains", []) as Array).has(kind):
		return w._no("ce bâtiment ne forme pas cette unité")
	if w.teams[team].age < int(Rules.UNITS[kind]["age"]):
		return w._no("nécessite l'âge %s" % Rules.AGES[int(Rules.UNITS[kind]["age"]) - 1]["name"])
	var lack: String = CivEvolution.train_lack(w, team, kind)
	if lack != "":
		return w._no(lack)
	if CivRules.HEROES.has(kind):
		return w._no("un héros est unique : production répétée impossible")
	b.repeat_unit = kind
	return w._ok()

static func _rally_resource(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var b: SimWorld.Building = w.buildings.get(int(cmd.get("building", -1))) as SimWorld.Building
	if b == null or b.team != team or not b.complete:
		return w._no("producteur allié achevé requis")
	if not (Rules.BUILDINGS[b.type].get("trains", []) as Array).has("ouvrier"):
		return w._no("ce bâtiment ne forme pas d'ouvriers")
	if UrbanCity.replaces_gathering(w, team): return w._no("récolte remplacée par la ville (électricité)")
	var id: int = int(cmd.get("node", -1))
	if id == -1:
		b.rally_node = -1
		return w._ok()
	if resource_target(w, team, id) == null:
		return w._no("ressource épuisée, inexplorée ou indisponible")
	b.rally_node = id
	return w._ok()

static func _cancel_at(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var b: SimWorld.Building = w.buildings.get(int(cmd.get("building", -1))) as SimWorld.Building
	if b == null or b.team != team:
		return w._no("bâtiment allié requis")
	var index: int = int(cmd.get("index", -1))
	if index < 0 or index >= b.queue.size():
		return w._no("élément de file introuvable")
	var kind: String = String(b.queue[index])
	b.queue.remove_at(index)
	w._refund(team, w.scaled_cost(Rules.UNITS[kind]["cost"]))
	CivEvolution.on_train_cancelled(w, team, kind)
	if index == 0:
		b.prod_timer = 0.0
		b.prod_blocked = ""
	return {"ok": true, "refund": w.scaled_cost(Rules.UNITS[kind]["cost"])}

# ---------------------------------------------------------------- comportement au combat (crochets)

static func acquire(w: SimWorld, u: SimWorld.Unit, radius: float):
	## Posture et cible prioritaire. Sans posture ni priorité : strictement SimWorld._acquire.
	if u.stance == "" and u.target_pref == "":
		return w._acquire(u, radius)
	if u.stance == "passive":
		return null
	var reach: float = radius
	if u.stance == "hold":
		reach = minf(radius, float(Rules.UNITS[u.type]["range"]) + 0.8)
	if u.target_pref != "":
		var preferred = _preferred(w, u, reach)
		if preferred != null:
			return preferred
	return w._acquire(u, reach)

static func _preferred(w: SimWorld, u: SimWorld.Unit, radius: float):
	var best = null
	var bd: float = radius * radius
	if u.target_pref == "building":
		for b in w.buildings.values():
			if not w.factions.hostile(u.team, b.team) or not w.is_visible_to(u.team, b.center):
				continue
			var db: float = u.pos.distance_squared_to(b.center)
			if db < bd:
				bd = db
				best = b
		return best
	var ids: Array = w.units.keys()
	ids.sort()
	for id in ids:
		var o: SimWorld.Unit = w.units[id]
		if o.garrison_id != -1 or not w.factions.hostile(u.team, o.team) or not Rules.unit_has(o.type, u.target_pref):
			continue
		if not ModernSystems.can_target(u, o) or not w.is_visible_to(u.team, o.pos):
			continue
		var d: float = u.pos.distance_squared_to(o.pos)
		if d < bd:
			bd = d
			best = o
	return best

static func keep_target(w: SimWorld, u: SimWorld.Unit, tgt, order: Dictionary) -> bool:
	## Posture défensive : riposte, puis revient à son poste ; passive : ne poursuit jamais.
	if u.stance == "passive":
		return false
	if u.stance == "defensive":
		var anchor: Vector2 = order.get("pos", u.pos) if order.has("pos") else u.pos
		return anchor.distance_to(w.entity_pos(tgt)) <= float(Rules.UNITS[u.type]["vision"]) * 0.9
	return true

static func may_chase(w: SimWorld, u: SimWorld.Unit) -> bool:
	## Posture « tenir » : ne quitte pas sa place pour poursuivre, sauf ordre d'attaque explicite.
	if u.stance != "hold":
		return true
	var order: Dictionary = u.order
	if not u.direct and u.squad_id != -1 and w.squads.has(u.squad_id):
		order = (w.squads[u.squad_id] as SimWorld.Squad).order
	return String(order.get("type", "")) == "attack"

# ---------------------------------------------------------------- pas fixe

static func step(w: SimWorld) -> void:
	for u in w.units.values():
		if u.garrison_id == -1:
			continue
		var b: SimWorld.Building = w.buildings.get(u.garrison_id) as SimWorld.Building
		if b == null or b.team != u.team:
			leave_garrison(w, u)
			continue
		if u.cd > 0.0:
			u.cd -= Rules.DT
			continue
		var def: Dictionary = Rules.UNITS[u.type]
		if float(def["atk"]) <= 0.0 or u.stance == "passive":
			continue
		var reach: float = float(def["range"]) + b.size * 0.5 + 1.0
		var tgt = w._acquire(u, reach)
		if tgt == null or not (tgt is SimWorld.Unit):
			continue
		u.cd = float(def["cd"])
		u.attacking_tick = w.tick
		w.emit("tir", u.team, "", {"from": b.center, "to": tgt.pos})
		w._damage(tgt, w._damage_value(u, tgt), u)
	if w.tick % 10 != 3:
		return
	var ids: Array = w.buildings.keys()
	ids.sort()
	for id in ids:
		var b: SimWorld.Building = w.buildings[id]
		if b.repeat_unit == "" or not b.complete or b.team == SimWorld.TEAM_NEUTRAL or b.queue.size() >= 2:
			continue
		var t: SimWorld.Team = w.teams[b.team]
		var queued_pop: int = 0
		for kind in b.queue:
			queued_pop += int(Rules.UNITS[kind]["pop"])
		if t.pop + queued_pop + int(Rules.UNITS[b.repeat_unit]["pop"]) > t.pop_cap:
			continue
		if w.train_check(b.team, b, b.repeat_unit) == "":
			w._cmd_train(b.team, b.id, b.repeat_unit)

static func release(w: SimWorld, u: SimWorld.Unit) -> void:
	OrderQueue.finish(w, u, false)
	if Rules.unit_has(u.type, "worker"):
		w._release_worker_job(u)
		u.manual = false
		u.direct = false
		u.task = ""
		u.order = {}
		return
	u.direct = false
	u.order = {}
	u.target_id = -1

static func state_text(w: SimWorld) -> String:
	## Empreinte étendue (recettes) : empreinte de simulation + champs de commandement 0.17.
	var parts: PackedStringArray = PackedStringArray([w.state_hash()])
	var ids: Array = w.units.keys()
	ids.sort()
	for id in ids:
		var u: SimWorld.Unit = w.units[id]
		parts.append("%d:%s:%d:%s:%s:%d:%s:%d:%s:%s" % [u.id, var_to_str(u.order_steps), u.order_step, str(u.order_loop), u.stance, u.garrison_id, u.target_pref, int(u.manual), str(u.direct), var_to_str(u.order)])
	var bids: Array = w.buildings.keys()
	bids.sort()
	for id in bids:
		var b: SimWorld.Building = w.buildings[id]
		parts.append("b%d:%s:%s:%d" % [b.id, var_to_str(b.queue), b.repeat_unit, b.rally_node])
	var sids: Array = w.squads.keys()
	sids.sort()
	for id in sids:
		var s: SimWorld.Squad = w.squads[id]
		parts.append("s%d:%s:%s:%s:%s" % [s.id, s.formation, s.stance, var_to_str(s.order), str(s.direct)])
	return "|".join(parts).sha256_text()
