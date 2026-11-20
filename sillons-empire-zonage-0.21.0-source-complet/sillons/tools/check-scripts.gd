extends SceneTree
## 0.17 — Contrôle de compilation : charge chaque script GDScript du projet et signale ceux qui échouent.
## godot --headless --path . --script res://tools/check-scripts.gd
var failed: int = 0
var total: int = 0

func _walk(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_walk(dir_path.path_join(sub))
	for file in dir.get_files():
		if file.ends_with(".gd"):
			total += 1
			var script: GDScript = load(dir_path.path_join(file)) as GDScript
			if script == null or not script.can_instantiate():
				failed += 1
				print("SCRIPT_FAIL ", dir_path.path_join(file))

func _initialize() -> void:
	for folder in ["res://sim", "res://game", "res://interface", "res://evolution", "res://views", "res://orbit", "res://procgen", "res://streaming"]:
		_walk(folder)
	print("SCRIPTS_RESULT=%s total=%d failed=%d" % ["PASS" if failed == 0 else "FAIL", total, failed])
	quit(0 if failed == 0 else 1)
