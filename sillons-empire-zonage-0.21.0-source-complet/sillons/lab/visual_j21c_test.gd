extends SceneTree
## Recette automatisée VISUAL_J21C (Godot 4.4+ / moteur Mobile).
## godot --headless --path . -s res://lab/visual_j21c_test.gd
## N'altère pas la simulation et vérifie la visibilité des décorations.

var game
var frames: int = 0
var checks: int = 0
var failures: int = 0
var skipped: int = 0

func _initialize() -> void:
	GameConfig.mode = "lab"
	GameConfig.lab_path = "res://lab/scenarios/r04_delegation.json"
	change_scene_to_file("res://game/game.tscn")

func _check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s VISUAL_J21C %s" % ["PASS" if ok else "FAIL", name])

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 10:
		return false
	if game == null:
		game = current_scene
		if game == null:
			_check("scene_chargee", false)
			quit(1)
			return false
		game.paused = true
		return false
	var v: WorldView = game.view as WorldView
	_check("vue_de_monde", v != null)
	if v == null:
		quit(1)
		return false
	_check("terrain_pbr", v.terrain_mat != null and v.terrain_mat.shader != null)
	_check("eau", v.water_mat != null and v.water_mat.shader != null)
	_check("masque_terrain", v.ground_mask_tex != null)
	if v.ground_mask_tex != null:
		var im: Image = v.ground_mask_tex.get_image()
		_check("dimensions_masque", im.get_width() == Rules.MAP_SIZE and im.get_height() == Rules.MAP_SIZE)
	for key in ["grass_tex", "soil_tex", "sand_tex", "rock_tex", "normal_tex"]:
		var tex: Texture2D = v.terrain_mat.get_shader_parameter(key) as Texture2D
		_check("texture_" + key, tex != null and tex.get_width() == 1024 and tex.get_height() == 1024)
	_check("vegetation_multimesh", v.decor_meshes.has("grass") and v.decor_meshes.has("pebble"))
	var grass: MultiMeshInstance3D = v.decor_meshes.get("grass") as MultiMeshInstance3D
	if grass != null:
		_check("vegetation_instanciee", grass.multimesh != null and grass.multimesh.instance_count > 0)
		var ids: Array = v.decor_cells["grass"]
		var fog: PackedByteArray = game.world.teams[0].fog
		var found_hidden: bool = false
		var hidden_is_empty: bool = true
		for i in ids.size():
			var c: Vector2i = ids[i]
			if fog[game.world.idx(c)] == 0:
				found_hidden = true
				hidden_is_empty = absf(grass.multimesh.get_instance_transform(i).basis.determinant()) < 0.0001
				break
		# Le serveur de rendu Dummy ne fournit pas de readback MultiMesh (identité).
		# Détecter cette capacité sur une sentinelle ; ne pas valider artificiellement le masquage.
		var probe := MultiMesh.new()
		probe.transform_format = MultiMesh.TRANSFORM_3D
		probe.mesh = BoxMesh.new()
		probe.instance_count = 1
		probe.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		var readback_supported: bool = absf(probe.get_instance_transform(0).basis.determinant()) < 0.0001
		if readback_supported:
			_check("decor_ne_fuit_pas_le_brouillard", not found_hidden or hidden_is_empty)
		else:
			skipped += 1
			print("SKIP VISUAL_J21C decor_ne_fuit_pas_le_brouillard : readback MultiMesh indisponible, contrôle GPU requis")
		v.set_visual_lod(65.0)
		_check("lod_distant", not grass.visible)
		v.set_visual_lod(25.0)
		_check("lod_proche", grass.visible)
	var tick_before: int = int(game.world.tick)
	v._refresh_ground_details()
	_check("simulation_sans_effet_de_bord", game.world.tick == tick_before)
	print("VISUAL_J21C_RESULT %d/%d PASS ; %d SKIP" % [checks - failures, checks, skipped])
	quit(0 if failures == 0 else 1)
	return false
