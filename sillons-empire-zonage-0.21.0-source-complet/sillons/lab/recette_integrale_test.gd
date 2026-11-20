extends SceneTree
## Même suite de recette que sur Android, exécutable sans rendu :
## godot --headless --path . --script res://lab/recette_integrale_test.gd
var suite: RecetteSuite = RecetteSuite.new()

func _initialize() -> void:
	suite.start()

func _process(_delta: float) -> bool:
	if suite.running:
		suite.advance(30)
		return false
	for item in suite.results:
		print("%s [%s] %s" % ["PASS" if item["ok"] else "FAIL", item["group"], item["label"]])
	print("RECETTE_AUTO_RESULT=%s checks=%d fails=%d ticks=%d" % ["PASS" if suite.is_pass() else "FAIL", suite.count_ok + suite.count_fail, suite.count_fail, suite.ticks_executed])
	quit(0 if suite.is_pass() else 1)
	return false
