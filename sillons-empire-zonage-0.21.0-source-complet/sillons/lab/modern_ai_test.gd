extends SceneTree
func _initialize() -> void:
	var w := SimWorld.new()
	w.setup(345, {"max_age": 8})
	w.start_standard()
	for b in w.team_buildings(0, "centre"):
		b.hp = 1000000000.0 # Isoler la progression : empêcher une victoire prématurée.
		b.max_hp = b.hp
	w.teams[1].age = 6
	w.teams[1].res = {"food": 50000.0, "wood": 50000.0, "ore": 50000.0}
	w.teams[1].pop_cap = 200
	w.ai_controllers.append(AiController.new(1))
	for tick in 4000:
		w.step()
	var modern_units: int = 0
	for e in w.event_log:
		if e["type"] == "unite" and e["team"] == 1:
			var u = w.units.get(int(e.get("unit", -1)))
			if u != null and int(Rules.UNITS[u.type]["age"]) >= 4:
				modern_units += 1
	for b in w.team_buildings(1):
		print("BUILD ", b.type, " ", b.progress)
	print("AGE_STATUS ", w.age_up_status(1), " RES ", w.teams[1].res)
	var ok: bool = w.teams[1].age == 8 and modern_units > 0 and not w.teams[1].technologies.is_empty()
	print("MODERN_AI: age=%d modern_units_alive=%d technologies=%s %s" % [w.teams[1].age, modern_units, w.teams[1].technologies, "PASS" if ok else "FAIL"])
	quit(0 if ok else 1)
