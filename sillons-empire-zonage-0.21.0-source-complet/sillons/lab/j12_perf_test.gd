extends SceneTree
## Tests déterministes du governor visuel, sans toucher à l'horloge de la simulation.
var errors: int = 0

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		errors += 1

func _initialize() -> void:
	var budget := MobilePerfBudget.new()
	for i in 150:
		budget.observe(0.05)
	check(budget.stage == 2 and budget.terrain_lod_bias == 14.0, "surcharge soutenue : LOD visuel réduit")
	check(budget.galaxy_refresh_ticks == 45, "rafraîchissement des marqueurs espacé")
	for i in 800: # deux paliers à remonter : 6 fenêtres de 2 s
		budget.observe(0.016)
	check(budget.stage == 0 and budget.terrain_lod_bias == 0.0, "récupération visuelle après stabilisation")
	var c := StarCampaign.new()
	c.create(2026)
	var before: String = c.state_hash()
	budget.observe(0.2)
	check(c.state_hash() == before, "governor sans effet sur simulation")
	print("J12_PERF_RESULT=%s failures=%d" % ["PASS" if errors == 0 else "FAIL", errors])
	quit(0 if errors == 0 else 1)
