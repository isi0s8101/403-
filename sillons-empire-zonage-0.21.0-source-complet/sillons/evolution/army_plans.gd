class_name ArmyPlans
extends RefCounted
static func issue(w: SimWorld, cmd: Dictionary) -> Dictionary:
	var team: int = int(cmd["team"])
	if String(cmd["t"]) == "plan_toggle":
		var id: int = int(cmd.get("plan", -1))
		if not w.army_plans.has(id) or int(w.army_plans[id]["team"]) != team: return w._no("plan allié introuvable")
		if not bool(w.army_plans[id]["enabled"]):
			for raw in w.army_plans[id]["buildings"]:
				if not w.buildings.has(int(raw)) or w.buildings[int(raw)].army_plan != id: return w._no("producteur perdu ou réaffecté")
		w.army_plans[id]["enabled"] = not bool(w.army_plans[id]["enabled"])
		return {"ok": true}
	if String(cmd["t"]) == "queue_orders":
		# 0.17 : files d'ordres étendues (OrderQueue) ; anciennes étapes inchangées.
		return OrderQueue.replace(w, cmd)
	var producers: Array = cmd.get("buildings", [])
	var target: Dictionary = cmd.get("composition", {})
	var pos: Vector2 = w._v2(cmd.get("pos", [0, 0]))
	if producers.is_empty() or target.is_empty() or not pos.is_finite() or not w.walkable(w.cell_of(pos)): return w._no("producteurs, composition et destination requis")
	var total: int = 0
	for kind in target:
		if not Rules.UNITS.has(kind) or not Rules.unit_has(kind, "military") or not target[kind] is int or int(target[kind]) < 0 or int(target[kind]) > 100: return w._no("composition invalide")
		total += int(target[kind])
	if total < 1 or total > 200: return w._no("composition de 1 à 200 soldats")
	var unique_producers: Dictionary = {}
	for raw in producers:
		if unique_producers.has(int(raw)): return w._no("producteur sélectionné deux fois")
		unique_producers[int(raw)] = true
		var b: SimWorld.Building = w.buildings.get(int(raw)) as SimWorld.Building
		if b == null or b.team != team or not b.complete: return w._no("producteur allié requis")
		if b.army_plan > 0 and w.army_plans.has(b.army_plan) and bool(w.army_plans[b.army_plan]["enabled"]): return w._no("producteur déjà réservé ; suspendez son plan")
	for kind in target:
		if int(target[kind]) == 0: continue
		var supported: bool = false
		for raw in producers:
			if (Rules.BUILDINGS[w.buildings[int(raw)].type].get("trains", []) as Array).has(kind): supported = true
		if not supported: return w._no("aucun producteur sélectionné pour " + String(Rules.UNITS[kind]["label"]))
	var id: int = w.next_plan_id
	w.next_plan_id += 1
	w.army_plans[id] = {"id": id, "team": team, "buildings": producers.duplicate(), "target": target.duplicate(), "pos": pos, "wave": clampi(int(cmd.get("wave", 6)), 1, total), "enabled": true, "status": "en préparation"}
	for raw in producers: w.buildings[int(raw)].army_plan = id
	return {"ok": true, "id": id}
static func on_spawn(w: SimWorld, u: SimWorld.Unit, b: SimWorld.Building) -> void:
	if b.army_plan <= 0 or not w.army_plans.has(b.army_plan) or not Rules.unit_has(u.type, "military"): return
	u.army_plan = b.army_plan
	u.army_origin = String(w.rules.get("sector", ""))
	u.wave_pending = true
	u.direct = true
	u.rally_contract = {}
	u.order = {"type": "hold", "pos": RallyService.nearest(w, b.center + Vector2(b.size + 2, 0))}
static func _activate(w: SimWorld, u: SimWorld.Unit) -> void:
	OrderQueue._activate(w, u)
static func step(w: SimWorld) -> void:
	OrderQueue.step(w)
	if w.tick % 10 != 0: return
	var ids: Array = w.army_plans.keys()
	ids.sort()
	for id in ids:
		var plan: Dictionary = w.army_plans[id]
		if not bool(plan["enabled"]): continue
		var counts: Dictionary = (w.external_plan_counts.get(id, {}) as Dictionary).duplicate(true)
		var waiting: Array = []
		for u in w.team_units(int(plan["team"]), "military"):
			if u.army_plan != id or u.army_origin != String(w.rules.get("sector", "")): continue
			counts[u.type] = int(counts.get(u.type, 0)) + 1
			if u.wave_pending: waiting.append(u)
		for raw in plan["buildings"]:
			var b: SimWorld.Building = w.buildings.get(int(raw)) as SimWorld.Building
			if b == null or b.team != int(plan["team"]) or b.army_plan != id: continue
			for kind in b.queue: counts[kind] = int(counts.get(kind, 0)) + 1
		plan["status"] = "composition atteinte"
		# Réservations séquentielles : le second producteur voit déjà la file du premier.
		for raw in plan["buildings"]:
			var b: SimWorld.Building = w.buildings.get(int(raw)) as SimWorld.Building
			if b == null or b.team != int(plan["team"]) or b.army_plan != id or b.queue.size() >= 2: continue
			for kind in plan["target"]:
				if int(counts.get(kind, 0)) >= int(plan["target"][kind]): continue
				if not (Rules.BUILDINGS[b.type].get("trains", []) as Array).has(kind): continue
				var result: Dictionary = w.issue({"t": "train", "team": int(plan["team"]), "building": b.id, "unit": kind})
				if bool(result.get("ok", false)): counts[kind] = int(counts.get(kind, 0)) + 1; plan["status"] = "recrutement"
				else: plan["status"] = result.get("reason", "en attente")
				break
		var desired: int = 0
		for amount in (plan["target"] as Dictionary).values(): desired += int(amount)
		var present: int = 0
		for amount in counts.values(): present += int(amount)
		if waiting.size() >= int(plan["wave"]) or (present >= desired and not waiting.is_empty() and String(plan["status"]) == "composition atteinte"):
			for u in waiting:
				u.wave_pending = false
				u.order = {"type": "amove", "pos": plan["pos"]}
