class_name RallyService
extends RefCounted
static func issue(w: SimWorld, cmd: Dictionary) -> Dictionary:
	var team: int = int(cmd.get("team", -1))
	var ids: Array = cmd.get("buildings", [int(cmd.get("building", -1))]) as Array
	if ids.is_empty() or ids.size() > 64: return w._no("sélectionnez 1 à 64 producteurs")
	if cmd.has("pos"):
		var raw_position: Variant = cmd["pos"]
		if not raw_position is Vector2:
			if not raw_position is Array or raw_position.size() != 2: return w._no("deux coordonnées requises")
			for value in raw_position:
				if not (value is int or value is float): return w._no("coordonnées numériques requises")
	var position: Vector2 = w._v2(cmd.get("pos", [])) if cmd.has("pos") else Vector2(-1, -1)
	var target: int = int(cmd.get("target", -1))
	var kind: String = String(cmd.get("kind", "point"))
	if kind not in ["point", "unit", "squad"]: return w._no("cible de ralliement invalide")
	if kind == "unit":
		var u: SimWorld.Unit = w.units.get(target) as SimWorld.Unit
		if u == null or u.team != team or not Rules.unit_has(u.type, "military"): return w._no("armée mobile alliée requise")
		position = u.pos
	elif kind == "squad":
		var s: SimWorld.Squad = w.squads.get(target) as SimWorld.Squad
		if s == null or s.team != team or s.units.is_empty(): return w._no("escouade alliée requise")
		position = w._squad_center(s)
	if not position.is_finite() or not w.in_map(w.cell_of(position)) or not w.walkable(w.cell_of(position)): return w._no("point terrestre libre requis dans la carte")
	var producers: Array = []
	var unique: Dictionary = {}
	for raw in ids:
		var b: SimWorld.Building = w.buildings.get(int(raw)) as SimWorld.Building
		if b == null or b.team != team or not b.complete or (Rules.BUILDINGS[b.type].get("trains", []) as Array).is_empty(): return w._no("producteur allié achevé requis")
		if not unique.has(b.id): producers.append(b); unique[b.id] = true
	for b in producers:
		b.rally_revision += 1
		b.rally = position
		b.rally_contract = {"kind": kind, "target": target, "pos": position, "revision": b.rally_revision}
		# Ne jamais réutiliser le contrat d'une escouade déjà partie.
		b.forming_squad = -1
	return {"ok": true, "count": producers.size()}
static func assign(w: SimWorld, u: SimWorld.Unit, b: SimWorld.Building) -> void:
	if Rules.unit_has(u.type, "worker") or not Rules.unit_has(u.type, "military"): return
	if b.rally_contract.is_empty(): return
	u.rally_contract = b.rally_contract.duplicate(true)
	u.rally_contract["producer"] = b.id
	u.rally_contract["alerted"] = false
	u.rally_contract["fallback"] = RallyService.nearest(w, b.center + Vector2(b.size + 1, 0))
	u.direct = true
	u.order_steps = []
	u.order = {"type": "move", "pos": b.rally}
static func step(w: SimWorld) -> void:
	for u in w.units.values():
		if u.rally_contract.is_empty(): continue
		var contract: Dictionary = u.rally_contract
		if String(u.order.get("type", "")) != "move" and not bool(contract.get("waiting", false)):
			u.rally_contract = {}
			continue
		var point: Vector2 = contract["pos"]
		var lost: bool = false
		if String(contract["kind"]) == "unit":
			var target: SimWorld.Unit = w.units.get(int(contract["target"])) as SimWorld.Unit
			if target == null or target.team != u.team: lost = true
			else: point = target.pos
		elif String(contract["kind"]) == "squad":
			var s: SimWorld.Squad = w.squads.get(int(contract["target"])) as SimWorld.Squad
			if s == null or s.team != u.team or s.units.is_empty(): lost = true
			else: point = w._squad_center(s)
		if lost or u.path_failed or not w.walkable(w.cell_of(point)):
			point = contract["fallback"]
			if not bool(contract["alerted"]):
				var notice_id: String = "%d:%d:%d" % [u.team, int(contract["producer"]), int(contract["revision"])]
				if not w.rally_notices.has(notice_id):
					w.emit("rally", u.team, "Renforts en attente locale : destination perdue ou trajet inaccessible", {"unit": u.id})
					w.rally_notices[notice_id] = true
					if w.rally_notices.size() > 512: w.rally_notices.erase(w.rally_notices.keys()[0])
				contract["alerted"] = true
			contract["waiting"] = true
			contract["kind"] = "point"
			contract["pos"] = point
		u.order = {"type": "move", "pos": point}
		if u.pos.distance_to(point) < 1.0:
			u.order = {"type": "hold", "pos": point}
			u.rally_contract = {}
static func nearest(w: SimWorld, point: Vector2) -> Vector2:
	for radius in range(1, 12):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var cell: Vector2i = w.cell_of(point) + Vector2i(x, y)
				if w.walkable(cell): return Vector2(cell) + Vector2(0.5, 0.5)
	return point
