extends SceneTree
func _initialize() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = 1
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	mm.set_instance_transform(0, hidden)
	print("MULTIMESH_PROBE sent_determinant=", hidden.basis.determinant(), " read_determinant=", mm.get_instance_transform(0).basis.determinant(), " adapter=", RenderingServer.get_video_adapter_name())
	quit()
