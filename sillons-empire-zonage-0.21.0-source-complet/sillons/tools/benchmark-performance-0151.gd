extends SceneTree
## CPU isolé de la campagne complète, sans rendu ni attente de temps réel.
func _initialize() -> void:
	var results: Array[Dictionary] = []
	for kind in AndroidPerfFixture.KINDS:
		var started: int = Time.get_ticks_usec()
		var campaign: StarCampaign = AndroidPerfFixture.build(kind)
		var startup_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		var initial: Dictionary = AndroidPerfFixture.counts(campaign)
		var durations: PackedFloat64Array = PackedFloat64Array()
		var first_ticks: PackedFloat64Array = PackedFloat64Array()
		for tick in 500:
			var before: int = Time.get_ticks_usec()
			campaign.step()
			var ms: float = float(Time.get_ticks_usec() - before) / 1000.0
			durations.append(ms)
			if tick < 100: first_ticks.append(ms)
		var result: Dictionary = {"scenario": kind, "seed": AndroidPerfFixture.SEED,
			"platform": OS.get_name(), "cpu": OS.get_processor_name(), "cores": OS.get_processor_count(),
			"godot": Engine.get_version_info()["string"], "headless": true, "rendering": "excluded",
			"ticks": 500, "startup_cpu_ms": startup_ms, "initial_counts": initial,
			"final_counts": AndroidPerfFixture.counts(campaign), "tick": AndroidPerfRecorder.distribution(durations),
			"first_100_ticks": AndroidPerfRecorder.distribution(first_ticks), "process_rss_mib": AndroidPerfRecorder.process_rss_mib(),
			"godot_static_mib": float(OS.get_static_memory_usage()) / 1048576.0,
			"thermal": null, "android_device": "NOT_RUN"}
		results.append(result); print("ANDROID_CPU_BENCHMARK ", JSON.stringify(result))
	for result in results:
		for value in (result["final_counts"]["world_ticks"] as Dictionary).values():
			if int(value) != 500: quit(1); return
	print("ANDROID_CPU_BENCHMARK_RESULT=PASS cases=3 ANDROID_DEVICE=NOT_RUN")
	quit()
