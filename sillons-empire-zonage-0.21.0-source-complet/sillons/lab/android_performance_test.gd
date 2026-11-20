extends SceneTree
var failures: int = 0
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void:
	var stats: Dictionary = AndroidPerfRecorder.distribution(PackedFloat64Array([40, 10, 30, 20]))
	check(stats["p50_ms"] == 20.0 and stats["p95_ms"] == 40.0, "percentiles par rang")
	check(AndroidPerfRecorder.distribution(PackedFloat64Array())["p95_ms"] == null, "absence de mesure explicite")
	check(AndroidPerfRecorder.save_report({}, "user://sauvegarde.save") == ERR_INVALID_PARAMETER, "rapports confinés au dossier mesures")
	var recorder: AndroidPerfRecorder = AndroidPerfRecorder.new()
	recorder.begin({"fixture": true}); recorder.record_tick(NAN); recorder.record_tick(4.0)
	var empty: Dictionary = recorder.finish()
	check(int(empty["tick"]["count"]) == 1 and empty["metadata"]["thermal_status"] == null, "mesure absente distincte de zéro")
	for kind in AndroidPerfFixture.KINDS:
		var left: StarCampaign = AndroidPerfFixture.build(kind)
		var right: StarCampaign = AndroidPerfFixture.build(kind)
		check(left.state_hash() == right.state_hash(), "charge reproductible : " + kind)
		var counts: Dictionary = AndroidPerfFixture.counts(left)
		check(int(counts["worlds"]) == 3 and left.current().map_size == 256, "trois grandes cartes : " + kind)
		if kind == "fronts": check(int(counts["ground_units"]) >= 360, "360 soldats répartis sur trois mondes")
		if kind == "orbit": check(int(counts["orbital_ships"]) == 120 and OrbitalTactics.validate(left), "120 vaisseaux physiques valides")
		for tick in 12:
			left.step(); right.step()
		check(left.state_hash() == right.state_hash(), "simulation indépendante du rendu : " + kind)
		var progressed: bool = true
		for world in left.worlds.values(): progressed = progressed and world.tick == 12
		check(progressed, "mondes hors écran actifs : " + kind)
	print("ANDROID_PERFORMANCE_RESULT checks=", checks, " failures=", failures, " DEVICE=NOT_RUN")
	quit(0 if failures == 0 else 1)
