extends SceneTree
## Comparaison de réglages sur la même graine (J2) : budget de recherches de chemin par tick.
## Pour chaque valeur : recette de siège R12 (tick d'ouverture du passage, tick du premier franchissement,
## empreinte finale) et front A du test deux fronts à 400 unités (temps de simulation moyen et pic).
## Usage : godot --headless --path . -s res://lab/compare_settings.gd
## Résultat : game-studio/preuves/comparaison_reglages.txt (ou user://).

const BUDGETS := [9999, 48, 24, 12]

func _initialize() -> void:
	var lines := PackedStringArray()
	lines.append("Comparaison du budget de recherches de chemin (path_budget) — même graine, mêmes ordres")
	lines.append("budget | R12 statut | R12 passage ouvert (s) | R12 1er franchissement (s) | front A 400 u. : sim moy / pic (ms) sur 300 ticks")
	for b in BUDGETS:
		# Recette de siège R12
		var sc := LabScenario.load_file("res://lab/scenarios/r12_siege.json")
		sc.data["rules"] = {"path_budget": b}
		sc.quiet = true
		sc.build()
		var opened := -1
		var crossed := -1
		while not sc.finished:
			sc.step()
			var w: SimWorld = sc.world
			if opened < 0:
				for e in w.event_log.slice(maxi(0, w.event_log.size() - 8)):
					if e["type"] == "ia" and String(e["text"]).contains("passage ouvert"):
						opened = int(e["tick"])
			if crossed < 0 and w.tick % 10 == 0:
				for u in w.team_units(1, "military"):
					if u.pos.y - u.pos.x > 6:
						crossed = w.tick
						break
		# Charge : front A à 400 unités
		var fa := LabScenario.load_file(Theater.FRONT_FILES[0])
		fa.data["rules"] = {"path_budget": b}
		fa.quiet = true
		var base := Theater._base_units(fa.data)
		fa.load_scale = float(400 - int(base["base"])) / float(int(base["scalable"]))
		fa.build()
		var tot := 0.0
		var pk := 0.0
		for i in 300:
			var t0 := Time.get_ticks_usec()
			fa.step()
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			tot += ms
			pk = maxf(pk, ms)
		lines.append("%6s | %s | %s | %s | %.1f / %.1f" % ["illimité" if b >= 9999 else str(b), "PASS" if sc.all_passed() else "FAIL",
			"%.1f" % (opened / 10.0) if opened >= 0 else "—", "%.1f" % (crossed / 10.0) if crossed >= 0 else "—", tot / 300.0, pk])
		print(lines[lines.size() - 1])
	var dir := ProjectSettings.globalize_path("res://game-studio/preuves")
	var f := FileAccess.open(dir + "/comparaison_reglages.txt", FileAccess.WRITE)
	if f == null:
		f = FileAccess.open("user://comparaison_reglages.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	quit()
