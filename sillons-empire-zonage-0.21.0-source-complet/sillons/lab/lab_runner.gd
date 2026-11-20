extends SceneTree
## Exécution sans rendu des scénarios de laboratoire.
## godot --headless --path . -s res://lab/lab_runner.gd -- [all|nom_scenario ...] [--out=dossier] [--seed=N]
## Code de sortie : 0 si toutes les assertions passent, 1 sinon.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var names := []
	var out_dir := "user://lab_logs"
	var seed_override := -1
	for a in args:
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--seed="):
			seed_override = int(a.substr(7))
		else:
			names.append(a)
	if names.is_empty():
		names = ["all"]
	var files := LabScenario.list_scenarios()
	var selected := []
	for f in files:
		var base: String = f.get_file().get_basename()
		if names.has("all") or names.has(base):
			selected.append(f)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var all_ok := true
	var summary := PackedStringArray()
	summary.append("Laboratoire Sillons d'Empire — Godot %s — %s" % [Engine.get_version_info()["string"], Time.get_datetime_string_from_system(true)])
	for f in selected:
		var t0 := Time.get_ticks_msec()
		var sc := LabScenario.load_file(f)
		if sc == null:
			all_ok = false
			summary.append("FAIL %s : chargement impossible" % f)
			continue
		sc.build(seed_override)
		var ok := sc.run_headless()
		if bool(sc.data.get("check_determinism", false)):
			var h1 := sc.world.state_hash()
			var sc2 := LabScenario.load_file(f)
			sc2.build(seed_override)
			sc2.run_headless()
			var h2 := sc2.world.state_hash()
			var same := h1 == h2
			sc.results.append({"label": "déterminisme (2 exécutions)", "ok": same, "tick": sc.world.tick, "detail": "%s / %s" % [h1.substr(0, 16), h2.substr(0, 16)]})
			sc.log_lines.append("%s déterminisme : %s vs %s" % ["PASS" if same else "FAIL", h1, h2])
			ok = ok and same
		var ms := Time.get_ticks_msec() - t0
		var base: String = f.get_file().get_basename()
		var line := "%s %-34s %s — %d ticks en %d ms" % ["PASS" if ok else "FAIL", base, sc.summary(), sc.world.tick, ms]
		summary.append(line)
		print(line)
		for r in sc.results:
			print("    %s %s — %s" % ["PASS" if r["ok"] else "FAIL", r["label"], r["detail"]])
		var lf := FileAccess.open(out_dir.path_join(base + ".log"), FileAccess.WRITE)
		if lf:
			lf.store_string("\n".join(sc.log_lines) + "\n")
		all_ok = all_ok and ok
	summary.append("RÉSULTAT GLOBAL : %s" % ("PASS" if all_ok else "FAIL"))
	print(summary[summary.size() - 1])
	var sf := FileAccess.open(out_dir.path_join("resume.txt"), FileAccess.WRITE)
	if sf:
		sf.store_string("\n".join(summary) + "\n")
	quit(0 if all_ok else 1)
