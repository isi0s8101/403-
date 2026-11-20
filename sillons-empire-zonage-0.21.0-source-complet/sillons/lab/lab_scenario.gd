class_name LabScenario
extends RefCounted
## Scénario de laboratoire : carte et graine connues, ressources et âges réglables par camp,
## placement d'unités, rejeu d'une suite d'ordres datés (en ticks) et assertions.
## Utilisé sans rendu (lab_runner.gd) et avec rendu (mode Laboratoire du menu).

var data: Dictionary = {}
var world: SimWorld
var refs := {}
var log_lines := PackedStringArray()
var results: Array = []      # {label, ok, tick, detail}
var _orders: Array = []
var _asserts: Array = []
var _event_cursor := 0
var _ai_snapshot_every := 300
var finished := false
var path := ""
## Charge du test deux fronts : multiplicateur appliqué aux "spawn_group" marqués "scalable".
var load_scale := 1.0
var quiet := false              # pas de journal texte (mesures de performance)

static func load_file(p: String) -> LabScenario:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_error("Scénario introuvable : " + p)
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON invalide : " + p)
		return null
	var s := LabScenario.new()
	s.data = parsed
	s.path = p
	return s

static func list_scenarios(dir_path: String = "res://lab/scenarios") -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(dir_path + "/" + f)
	out.sort()
	return out

func ticks_total() -> int:
	return int(data.get("ticks", 600))

func build(seed_override: int = -1) -> SimWorld:
	world = SimWorld.new()
	var sd := int(data.get("seed", 1)) if seed_override < 0 else seed_override
	world.setup(sd, data.get("rules", {}))
	_log("=== Scénario %s — graine %d ===" % [data.get("name", path), sd])
	_log(String(data.get("description", "")))
	if bool(data.get("standard_start", true)):
		world.start_standard()
	var teams_cfg: Array = data.get("teams", [])
	for i in teams_cfg.size():
		var tc: Dictionary = teams_cfg[i]
		var t: SimWorld.Team = world.teams[i]
		if tc.has("res"):
			for r in tc["res"].keys():
				t.res[r] = float(tc["res"][r])
		if tc.has("age"):
			t.age = int(tc["age"])
		if tc.has("priorities"):
			for r in tc["priorities"].keys():
				t.priorities[r] = int(tc["priorities"][r])
		if tc.has("opening"):
			t.opening = String(tc["opening"])
		if bool(tc.get("ai", false)):
			var ai := AiController.new(i)
			if tc.has("attack_threshold"):
				ai.attack_threshold = int(tc["attack_threshold"])
			if tc.has("trade_attack_threshold"):
				ai.trade_attack_threshold = int(tc["trade_attack_threshold"])
			t.ai_controlled = true
			world.ai_controllers.append(ai)
	refs["cc0"] = _first_id(0, "centre")
	refs["cc1"] = _first_id(1, "centre")
	for cmd in data.get("setup", []):
		_run_cmd(cmd, null)
	world.update_fog(true)
	_orders = data.get("orders", []).duplicate(true)
	_orders.sort_custom(func(a, b): return int(a["tick"]) < int(b["tick"]))
	_asserts = data.get("asserts", []).duplicate(true)
	_asserts.sort_custom(func(a, b): return int(a["tick"]) < int(b["tick"]))
	return world

func _free_spot(q: Vector2) -> Vector2:
	## Case praticable la plus proche (placement des grands groupes du test deux fronts).
	var c := world.cell_of(q)
	if world.in_map(c) and world.walkable(c):
		return q
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if world.in_map(n) and world.walkable(n):
					return Vector2(n.x + 0.5, n.y + 0.5)
	return q

func _first_id(team: int, type: String) -> int:
	var bs := world.team_buildings(team, type)
	return bs[0].id if not bs.is_empty() else -1

func _log(s: String) -> void:
	if quiet:
		return
	log_lines.append(s)

func _ts() -> String:
	return "[t=%6.1fs]" % (world.tick / float(Rules.TICK_RATE))

func _subst(v):
	if v is String and v.begins_with("$"):
		var k: String = v.substr(1)
		if refs.has(k):
			return refs[k]
		return -1
	if v is Array:
		var out := []
		for x in v:
			out.append(_subst(x))
		return out
	if v is Dictionary:
		var out := {}
		for k in v.keys():
			out[k] = _subst(v[k])
		return out
	return v

func _run_cmd(raw: Dictionary, entry) -> Dictionary:
	var cmd: Dictionary = _subst(raw)
	var res := {"ok": true}
	match String(cmd.get("t", "")):
		"ref_node":
			var near := Vector2(float(cmd["near"][0]), float(cmd["near"][1]))
			var best = null
			var bd := INF
			for n in world.nodes.values():
				if n.kind == String(cmd["kind"]) and n.pos.distance_to(near) < bd:
					bd = n.pos.distance_to(near)
					best = n
			refs[String(cmd["as"])] = best.id if best != null else -1
		"ref_squad_of":
			var u = world.units.get(int(cmd["unit"]))
			refs[String(cmd["as"])] = u.squad_id if u != null else -1
		"ref_building":
			refs[String(cmd["as"])] = _first_id(int(cmd["team"]), String(cmd["type"]))
		"ref_unit":
			var us := world.team_units(int(cmd["team"]))
			var k := 0
			for u in us:
				if u.type == String(cmd["unit"]):
					if k == int(cmd.get("index", 0)):
						refs[String(cmd["as"])] = u.id
						break
					k += 1
		"deplete_kind":
			var center := Vector2(float(cmd["near"][0]), float(cmd["near"][1])) if cmd.has("near") else Vector2(48, 48)
			var radius := float(cmd.get("radius", 999))
			var n_done := 0
			for n in world.nodes.values():
				if n.kind == String(cmd["kind"]) and n.pos.distance_to(center) <= radius:
					if cmd.has("except") and int(cmd["except"]) == n.id:
						continue
					n.amount = float(cmd.get("amount", 0.0))
					n_done += 1
			_log("%s LABO épuisement de %d gisement(s) %s" % [_ts(), n_done, cmd["kind"]])
		"spawn_group":
			var p := Vector2(float(cmd["pos"][0]), float(cmd["pos"][1]))
			var ids := []
			var first_new := true
			var count := int(cmd["count"])
			if bool(cmd.get("scalable", false)):
				count = maxi(1, int(round(count * load_scale)))
			var cols := int(cmd.get("cols", 3))
			if cols <= 0:
				cols = maxi(3, int(ceil(sqrt(float(count)))))
			for i in count:
				var off := Vector2((i % cols) * 1.1, (i / cols) * 1.1)
				if bool(cmd.get("scalable", false)):
					off = _free_spot(p + off) - p
				var r := world.issue({"t": "lab_spawn", "team": int(cmd["team"]), "unit": String(cmd["unit"]),
					"pos": [p.x + off.x, p.y + off.y], "new_squad": first_new and bool(cmd.get("new_squad", true))})
				first_new = false
				ids.append(r["id"])
			if cmd.has("as"):
				refs[String(cmd["as"])] = ids[0]
			_log("%s LABO placement : %d × %s camp %d en (%d,%d)" % [_ts(), ids.size(), cmd["unit"], cmd["team"], p.x, p.y])
		"set_ai_threshold":
			for ai in world.ai_controllers:
				if ai.team == int(cmd["team"]):
					ai.attack_threshold = int(cmd["value"])
					ai.trade_attack_threshold = int(cmd["value"])
		"note":
			_log("%s NOTE %s" % [_ts(), cmd.get("text", "")])
		_:
			res = world.issue(cmd)
			if cmd.has("as") and res.has("id"):
				refs[String(cmd["as"])] = res["id"]
			_log("%s ORDRE %s -> %s" % [_ts(), JSON.stringify(cmd), "OK" if res["ok"] else "REFUS (%s)" % res.get("reason", "")])
	if entry != null and entry.has("expect"):
		var exp_ok := bool(entry["expect"])
		var ok: bool = res["ok"] == exp_ok
		if ok and entry.has("reason_contains"):
			ok = String(res.get("reason", "")).find(String(entry["reason_contains"])) >= 0
		_record(String(entry.get("label", "résultat d'ordre")), ok, "attendu %s, obtenu %s %s" % [
			"OK" if exp_ok else "REFUS", "OK" if res["ok"] else "REFUS", res.get("reason", "")])
	return res

func _record(label: String, ok: bool, detail: String) -> void:
	results.append({"label": label, "ok": ok, "tick": world.tick, "detail": detail})
	_log("%s %s %s — %s" % [_ts(), "PASS" if ok else "FAIL", label, detail])

func step() -> void:
	## Un tick : ordres prévus, simulation, assertions, journal des événements.
	if finished:
		return
	while not _orders.is_empty() and int(_orders[0]["tick"]) <= world.tick:
		var o: Dictionary = _orders.pop_front()
		_run_cmd(o["cmd"], o)
	world.step()
	while _event_cursor < world.event_log.size():
		var e: Dictionary = world.event_log[_event_cursor]
		_event_cursor += 1
		if e["type"] in ["tir"]:
			continue
		if e["text"] != "" and not quiet:
			_log("[t=%6.1fs] EVT %s camp %d : %s" % [e["tick"] / float(Rules.TICK_RATE), e["type"], e["team"], e["text"]])
	if not quiet and not world.ai_controllers.is_empty() and world.tick % _ai_snapshot_every == 0:
		for ai in world.ai_controllers:
			_log("%s IA camp %d | objectif : %s | cible : %s | infos : %s | abandon : %s" % [_ts(), ai.team,
				ai.debug["objective"], ai.debug["target"], "; ".join(ai.debug["info"]), ai.debug["abandon"]])
	while not _asserts.is_empty() and int(_asserts[0]["tick"]) <= world.tick:
		_check(_asserts.pop_front())
	if world.tick >= ticks_total() or (world.game_over and bool(data.get("stop_on_game_over", true)) and _asserts.is_empty()):
		while not _asserts.is_empty():
			_check(_asserts.pop_front())
		finished = true
		_log("%s FIN — %s" % [_ts(), summary()])

func run_headless() -> bool:
	while not finished:
		step()
	return all_passed()

func all_passed() -> bool:
	for r in results:
		if not r["ok"]:
			return false
	return results.size() > 0

func summary() -> String:
	var p := 0
	for r in results:
		if r["ok"]:
			p += 1
	return "%d/%d assertions PASS — empreinte %s" % [p, results.size(), world.state_hash().substr(0, 16)]

func _cmp(a: float, op: String, b: float) -> bool:
	match op:
		">=": return a >= b
		"<=": return a <= b
		">": return a > b
		"<": return a < b
		"==": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
	return false

func _check(a: Dictionary) -> void:
	var c: Dictionary = _subst(a)
	var label: String = c.get("label", c["check"])
	var team := int(c.get("team", 0))
	var op: String = c.get("op", ">=")
	match String(c["check"]):
		"res":
			var v: float = world.teams[team].res[c["res"]]
			_record(label, _cmp(v, op, float(c["value"])), "%s camp %d = %.0f (%s %s)" % [c["res"], team, v, op, c["value"]])
		"income":
			var t: SimWorld.Team = world.teams[team]
			var other: SimWorld.Team = world.teams[int(c["other"])]
			var a1: float = t.stats["gathered"]["food"] + t.stats["gathered"]["wood"] + t.stats["gathered"]["ore"] + t.stats["trade"]
			var a2: float = other.stats["gathered"]["food"] + other.stats["gathered"]["wood"] + other.stats["gathered"]["ore"] + other.stats["trade"]
			_record(label, _cmp(a1, op, a2), "revenu cumulé camp %d = %.0f (dont commerce %.0f) ; camp %d = %.0f (dont commerce %.0f)" % [team, a1, t.stats["trade"], int(c["other"]), a2, other.stats["trade"]])
		"stat":
			var v: float = float(world.teams[team].stats[c["stat"]])
			_record(label, _cmp(v, op, float(c["value"])), "stat %s camp %d = %.0f" % [c["stat"], team, v])
		"stat_vs":
			var v1: float = float(world.teams[team].stats[c["stat"]])
			var v2: float = float(world.teams[int(c["other"])].stats[c["stat"]])
			_record(label, _cmp(v1, op, v2), "%s : camp %d = %.0f, camp %d = %.0f" % [c["stat"], team, v1, int(c["other"]), v2])
		"age":
			var v = world.teams[team].age
			_record(label, v == int(c["value"]), "âge camp %d = %d (attendu %d)" % [team, v, int(c["value"])])
		"eliminated":
			var v = world.teams[team].eliminated
			_record(label, v == bool(c["value"]), "camp %d éliminé = %s ; capacité : %s" % [team, v, world.rebuild_capacity(team)["reason"]])
		"winner":
			_record(label, world.winner == int(c["value"]), "vainqueur = %d" % world.winner)
		"task_count":
			var n := 0
			for u in world.team_units(team, "worker"):
				if u.task == String(c["task"]):
					n += 1
			_record(label, _cmp(n, op, float(c["value"])), "ouvriers en tâche %s = %d (%s %s)" % [c["task"], n, op, c["value"]])
		"count":
			var n := 0
			for u in world.team_units(team):
				if (c.has("unit") and u.type == String(c["unit"])) or (c.has("tag") and Rules.unit_has(u.type, String(c["tag"]))):
					n += 1
			_record(label, _cmp(n, op, float(c["value"])), "unités = %d (%s %s)" % [n, op, c["value"]])
		"building_count":
			var n := world.team_buildings(team, String(c["type"]), bool(c.get("complete", true))).size()
			_record(label, _cmp(n, op, float(c["value"])), "%s = %d (%s %s)" % [c["type"], n, op, c["value"]])
		"event":
			var found := false
			var since := int(c.get("since", 0))
			for e in world.event_log:
				if e["tick"] >= since and e["type"] == String(c["type"]) and (not c.has("team") or e["team"] == team) \
						and (not c.has("contains") or String(e["text"]).find(String(c["contains"])) >= 0):
					found = true
					break
			var want := bool(c.get("value", true))
			_record(label, found == want, "événement %s %s" % [c["type"], "trouvé" if found else "absent"])
		"unit_field":
			var u = world.units.get(int(c["unit"]))
			if u == null:
				_record(label, false, "unité introuvable")
			else:
				var v = u.get(String(c["field"]))
				var ok := str(v) == str(c["value"]) if not c.has("contains") else str(v).find(String(c["contains"])) >= 0
				_record(label, ok, "%s = %s" % [c["field"], str(v)])
		"unit_near":
			var u = world.units.get(int(c["unit"]))
			var p := Vector2(float(c["pos"][0]), float(c["pos"][1]))
			var d: float = u.pos.distance_to(p) if u != null else INF
			_record(label, d <= float(c["dist"]), "distance = %.1f (≤ %s)" % [d, c["dist"]])
		"no_worker_on_node":
			var bad := 0
			for u in world.team_units(team, "worker"):
				if u.node_id == int(c["node"]):
					bad += 1
			_record(label, bad == 0, "ouvriers affectés au gisement = %d" % bad)
		"squad_roles":
			var roles := []
			for s in world.team_squads(team):
				if not s.direct:
					roles.append(s.army_role)
			var distinct := {}
			for r in roles:
				distinct[r] = true
			var ok := roles.size() >= int(c.get("min", 2)) and (not bool(c.get("distinct", true)) or distinct.size() == roles.size())
			if c.has("contains"):
				ok = ok and roles.has(String(c["contains"]))
			_record(label, ok, "rôles : %s" % ", ".join(roles))
		"squad_field":
			var s = world.squads.get(int(c["squad"]))
			var v = s.get(String(c["field"])) if s != null else null
			var ok := str(v) == str(c["value"]) if not c.has("contains") else str(v).find(String(c["contains"])) >= 0
			_record(label, ok, "%s = %s" % [c["field"], str(v)])
		"ai":
			var ai = null
			for x in world.ai_controllers:
				if x.team == team:
					ai = x
			var v := ""
			if ai != null:
				var raw = ai.debug.get(String(c["field"]), "")
				v = "; ".join(raw) if raw is Array else str(raw)
			_record(label, v.find(String(c["contains"])) >= 0, "IA %s = %s" % [c["field"], v])
		"age_status_missing":
			var st := world.age_up_status(team)
			var j := "; ".join(st["missing"])
			_record(label, j.find(String(c["contains"])) >= 0, "manques : %s" % j)
		"count_side":
			# camp sud-ouest : y - x > 6 ; nord-est : x - y > 6
			var n := 0
			for u in world.team_units(team):
				var dxy: float = u.pos.y - u.pos.x
				if (String(c["side"]) == "sw" and dxy > 6.0) or (String(c["side"]) == "ne" and dxy < -6.0):
					if not c.has("unit") or u.type == String(c["unit"]):
						n += 1
			_record(label, _cmp(n, op, float(c["value"])), "unités du camp %d côté %s = %d (%s %s)" % [team, c["side"], n, op, c["value"]])
		"building_hp":
			var b = world.buildings.get(int(c["building"]))
			var v: float = b.hp if b != null else 0.0
			_record(label, _cmp(v, op, float(c["value"])), "PV = %.0f (%s %s)%s" % [v, op, c["value"], "" if b != null else " (détruit)"])
		"building_alive":
			var alive: bool = world.buildings.has(int(c["building"]))
			_record(label, alive == bool(c.get("value", true)), "bâtiment %s" % ("debout" if alive else "détruit"))
		"squad_role_sub":
			var roles := []
			var found := false
			for s2 in world.team_squads(team):
				roles.append(s2.army_role)
				if String(s2.army_role).find(String(c["contains"])) >= 0:
					found = true
			_record(label, found, "rôles : %s" % ", ".join(roles))
		"game_over":
			_record(label, world.game_over == bool(c.get("value", true)), "fin de partie = %s, vainqueur %d, t=%ds" % [world.game_over, world.winner, world.tick / Rules.TICK_RATE])
		_:
			_record(label, false, "contrôle inconnu " + String(c["check"]))
