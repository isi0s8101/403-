extends SceneTree
## 0.17 — Mesure comparable avant/après de l'interface (même scène, même armée, même caméra) :
## xvfb-run -a -s "-screen 0 1600x740x24" godot --rendering-driver opengl3 --path . --resolution 1600x740 \
##   --script res://tools/perf-ui-017.gd
## Imprime : temps de traitement par image (moyenne, p95), appels de dessin et primitives (moyenne).
var frames: int = 0
var game
var process_ms: Array = []
var draw_calls: Array = []
var primitives: Array = []

func _initialize() -> void:
	GameConfig.mode = "empire"
	GameConfig.seed_value = 15001
	GameConfig.reduce_motion = true
	GameConfig.visual_quality = 1
	GameConfig.adaptive_visuals = false
	var c := StarCampaign.new()
	CampaignSetup.create(c, 15001, false, 96)
	for w in c.worlds.values():
		w.ai_controllers.clear()
	GameConfig.loaded_campaign = c
	change_scene_to_file("res://game/game.tscn")

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 10:
		game = current_scene
		var w: SimWorld = game.world
		var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
		var ids: Array = []
		for i in 24:
			var r: Dictionary = w.issue({"t": "lab_spawn", "team": 0, "unit": "lancier", "pos": [cc.center.x + 4.0 + float(i % 6), cc.center.y - 6.0 - float(i / 6)], "new_squad": i % 8 == 0})
			ids.append(int(r.get("id", -1)))
		game.select_many(ids)
		game.focus(cc.center + Vector2(5, -6))
	if frames > 60 and frames <= 360:
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if frames == 361:
		var sorted: Array = process_ms.duplicate()
		sorted.sort()
		var avg: float = 0.0
		for v in process_ms: avg += float(v)
		avg /= float(process_ms.size())
		var dc: float = 0.0
		for v in draw_calls: dc += float(v)
		var pr: float = 0.0
		for v in primitives: pr += float(v)
		print("UI_PERF process_ms_moyen=%.3f process_ms_p95=%.3f appels_dessin=%.1f primitives=%.0f images=%d" % [avg, float(sorted[int(sorted.size() * 0.95)]), dc / float(draw_calls.size()), pr / float(primitives.size()), process_ms.size()])
		quit()
	return false
