extends SceneTree
func _initialize() -> void:
	var failures: int = 0
	var count: int = 0
	for kind in Rules.UNITS:
		var d: Dictionary = Rules.UNITS[kind]
		if int(d["age"]) < 4 or bool(d.get("civ", false)):
			continue   # 0.16 : unités de voie et héros vérifiés par lab/civ_evolution_test.gd
		var w := SimWorld.new()
		w.setup(345)
		w.start_standard()
		w.teams[0].res = {"food": 20000.0, "wood": 20000.0, "ore": 20000.0}
		w.teams[0].pop_cap = 200
		var producer: String = ""
		for key in Rules.BUILDINGS:
			if Rules.BUILDINGS[key].get("trains", []).has(kind):
				producer = key
		var b := w.spawn_building(0, producer, Vector2i(20, 78), true)
		w.teams[0].age = int(d["age"]) - 1
		var locked: bool = not w.issue({"t": "train", "team": 0, "building": b.id, "unit": kind})["ok"]
		w.teams[0].age = int(d["age"])
		var accepted: bool = w.issue({"t": "train", "team": 0, "building": b.id, "unit": kind})["ok"]
		for tick in int(float(d["time"]) * 10) + 5:
			w.step()
		var found: bool = false
		for u in w.team_units(0):
			if u.type == kind:
				found = true
		var ok: bool = locked and accepted and found
		count += 1
		if not ok:
			failures += 1
		print(("PASS " if ok else "FAIL ") + "âge et production : " + kind)
	print("CATALOG_TEST: %d/%d PASS" % [count - failures, count])
	quit(1 if failures else 0)
