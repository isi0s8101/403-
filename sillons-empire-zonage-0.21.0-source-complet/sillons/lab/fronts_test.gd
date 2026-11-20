extends SceneTree
## Test d'invariance du laboratoire « deux fronts » (J2).
## Compare, tick par tick, l'état des deux simulations :
##   A — sans aucune vue (simulation pure) ;
##   B — avec les deux vues 3D créées, une seule attachée à l'arbre, bascule tous les 100 ticks ;
##   C — idem B, bascule tous les 37 ticks et synchronisation des deux vues (pire cas).
## Critères : empreinte d'état identique à chaque tick, journal d'événements identique,
## état individuel identique de chaque unité en fin de run. Code de sortie 0 = PASS, 1 = FAIL.
## Usage : godot --headless --path . -s res://lab/fronts_test.gd [-- <niveau> <ticks>]

var report := PackedStringArray()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var plan := [[100, 1500], [400, 300]]
	if args.size() >= 2:
		plan = [[int(args[0]), int(args[1])]]
	var all_ok := true
	var results := []
	for p in plan:
		var lvl: int = p[0]
		var ticks: int = p[1]
		var a := _run(lvl, ticks, 0, false)
		if lvl == plan[0][0]:
			_save_orders(a, lvl, ticks)
		var b := _run(lvl, ticks, 100, false)
		var c := _run(lvl, ticks, 37, true)
		for pair in [["B", b], ["C", c]]:
			var r := _compare(a, pair[1])
			r["niveau"] = lvl
			r["ticks"] = ticks
			r["variante"] = pair[0]
			r["bascules"] = pair[1]["switches"]
			r["unites_fin"] = a["units0"]
			results.append(r)
			all_ok = all_ok and r["ok"]
			_line("%s niveau %d u./front, %d ticks, A (sans vue) contre %s (%d bascules) : %s" % [
				"PASS" if r["ok"] else "FAIL", lvl, ticks, pair[0], pair[1]["switches"], r["detail"]])
	# Contrôle négatif : une perturbation minime doit être détectée, sinon le test ne prouve rien.
	var lvl0: int = plan[0][0]
	var n0: int = mini(plan[0][1], 600)
	var ref := _run(lvl0, n0, 0, false)
	var bad := _run(lvl0, n0, 100, false, n0 / 2)
	var rn := _compare(ref, bad)
	var detected: bool = not rn["ok"]
	all_ok = all_ok and detected
	results.append({"variante": "contrôle négatif", "niveau": lvl0, "ticks": n0, "ok": detected, "detail": rn["detail"]})
	_line("%s contrôle négatif (décalage de 0,001 case au tick %d) : %s" % ["PASS" if detected else "FAIL", n0 / 2,
		("divergence détectée — " + rn["detail"]) if detected else "AUCUNE divergence détectée : le test est aveugle"])
	_line("RÉSULTAT GLOBAL : %s" % ("PASS" if all_ok else "FAIL"))
	_save(results, all_ok)
	quit(0 if all_ok else 1)

func _line(s: String) -> void:
	print(s)
	report.append(s)

func _run(lvl: int, ticks: int, switch_every: int, sync_both: bool, perturb_tick: int = -1) -> Dictionary:
	var th := Theater.new()
	th.build(lvl)
	var views: Array = []
	var active := 0
	var switches := 0
	if switch_every > 0:
		for i in 2:
			var wv := WorldView.new()
			root.add_child(wv)
			wv.setup(th.world(i), 0)
			views.append(wv)
		root.remove_child(views[1])
	var hashes := [PackedStringArray(), PackedStringArray()]
	var t0 := Time.get_ticks_msec()
	for t in ticks:
		if t == perturb_tick:
			# contrôle négatif : décale une unité d'un millième de case
			var ids: Array = th.world(0).units.keys()
			ids.sort()
			th.world(0).units[ids[ids.size() / 2]].pos.x += 0.001
		th.step()
		for i in 2:
			var ev := th.take_events(i)
			if not views.is_empty() and (i == active or sync_both):
				for e in ev:
					if e["type"] == "tir":
						views[i].shot_fx(e["from"], e["to"], bool(e.get("siege", false)))
			hashes[i].append(th.state_hash(i))
		if not views.is_empty():
			views[active].sync(0.5, Rules.DT)
			if sync_both:
				views[1 - active].sync(0.5, Rules.DT)
			if (t + 1) % switch_every == 0:
				root.remove_child(views[active])
				active = 1 - active
				root.add_child(views[active])
				views[active].sync(1.0, 0.0)
				views[active].update_fog_texture()
				switches += 1
	var out := {"hashes": hashes, "events": [th.event_signature(0), th.event_signature(1)],
		"dump": [th.unit_dump(0), th.unit_dump(1)], "switches": switches,
		"replay": [JSON.stringify(th.world(0).replay), JSON.stringify(th.world(1).replay)],
		"orders": [th.world(0).replay.size(), th.world(1).replay.size()],
		"final": [th.state_hash(0), th.state_hash(1)], "ms": Time.get_ticks_msec() - t0,
		"units0": [th.fronts[0].world.units.size(), th.fronts[1].world.units.size()]}
	for v in views:
		if v.get_parent() != null:
			v.get_parent().remove_child(v)
		v.free()
	return out

func _compare(a: Dictionary, b: Dictionary) -> Dictionary:
	var ok := true
	var detail := PackedStringArray()
	for i in 2:
		var ha: PackedStringArray = a["hashes"][i]
		var hb: PackedStringArray = b["hashes"][i]
		var first := -1
		for t in mini(ha.size(), hb.size()):
			if ha[t] != hb[t]:
				first = t
				break
		if first >= 0 or ha.size() != hb.size():
			ok = false
			detail.append("front %s : divergence au tick %d" % ["AB"[i], first])
		if a["replay"][i] != b["replay"][i]:
			ok = false
			detail.append("front %s : suites d'ordres différentes" % "AB"[i])
		if a["events"][i] != b["events"][i]:
			ok = false
			detail.append("front %s : journaux d'événements différents" % "AB"[i])
		var da: PackedStringArray = a["dump"][i]
		var db: PackedStringArray = b["dump"][i]
		var diff := 0
		for k in mini(da.size(), db.size()):
			if da[k] != db[k]:
				diff += 1
		diff += absi(da.size() - db.size())
		if diff > 0:
			ok = false
			detail.append("front %s : %d unités à l'état différent" % ["AB"[i], diff])
	if ok:
		detail.append("%d+%d empreintes identiques, journaux identiques, %d+%d unités identiques ; empreintes finales %s / %s" % [
			a["hashes"][0].size(), a["hashes"][1].size(), a["dump"][0].size(), a["dump"][1].size(),
			a["final"][0].substr(0, 16), a["final"][1].substr(0, 16)])
	if ok:
		detail.append("suites d'ordres identiques (%d + %d ordres)" % [a["orders"][0], a["orders"][1]])
	return {"ok": ok, "detail": " ; ".join(detail), "ordres": a["orders"],
		"empreinte_ordres": [a["replay"][0].sha256_text(), a["replay"][1].sha256_text()], "empreinte_finale": a["final"], "empreinte_finale_variante": b["final"],
		"evenements": a["events"], "duree_ms": [a["ms"], b["ms"]]}

func _proof_dir() -> String:
	# Les recettes ne modifient pas les preuves historiques ni le manifeste du paquet.
	var dir := ProjectSettings.globalize_path("user://preuves/deux_fronts")
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		push_error("Impossible de créer le dossier de preuves utilisateur : " + dir)
	return dir

func _save_orders(a: Dictionary, lvl: int, ticks: int) -> void:
	## Archive les suites d'ordres (émis par les IA et le scénario) du run de référence, pour rejeu et comparaison.
	for i in 2:
		var f := FileAccess.open(_proof_dir() + "/ordres_front_%s_niveau%d_%dticks.json" % ["AB"[i], lvl, ticks], FileAccess.WRITE)
		if f != null:
			f.store_string(a["replay"][i])

func _save(results: Array, ok: bool) -> void:
	var dir := _proof_dir()
	var f := FileAccess.open(dir + "/invariance.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"test": "invariance_deux_fronts", "statut": "PASS" if ok else "FAIL",
			"version": ProjectSettings.get_setting("application/config/version"), "resultats": results}, "  "))
	var g := FileAccess.open(dir + "/invariance.txt", FileAccess.WRITE)
	if g != null:
		g.store_string("\n".join(report) + "\n")
	print("Preuves : ", dir)
