extends SceneTree
func _initialize() -> void:
	print("MODELS=", RealismAssets.info("human_ouvrier"))
	var human: Node3D = RealismAssets.instantiate("human_ouvrier")
	if human != null:
		for raw in human.find_children("*", "AnimationPlayer", true, false):
			var p: AnimationPlayer = raw as AnimationPlayer
			print("ANIMATIONS=", p.get_animation_list())
		for raw in human.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = raw as MeshInstance3D
			print("MESH=", m.name, " surfaces=", m.mesh.get_surface_count())
		human.free()
	quit()
