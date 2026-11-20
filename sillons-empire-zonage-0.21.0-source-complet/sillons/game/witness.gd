extends Node3D
## Zone témoin : quelques unités et bâtiments à l'échelle et au zoom de jeu,
## pour juger la lisibilité et mesurer le coût de rendu (FPS, temps d'image, appels, primitives, mémoire).
## Les mesures sont enregistrées dans user://mesures/temoin_<date>.json.

var cam: Camera3D
var sun: DirectionalLight3D
var cam_dist := 24.0
var label: Label
var result_label: Label
var extra := []
var density := 1
var measuring := false
var m_t := 0.0
var m_frames: Array = []
var m_draw: Array = []
var m_prim: Array = []
var scale3d := 1.0
var msaa := 1

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.52, 0.72)
	sm.sky_horizon_color = Color(0.72, 0.76, 0.78)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -39, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 62.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_texture = preload("res://game/textures/grass_pbr.png") as Texture2D
	ground_mat.uv1_scale = Vector3(12.0, 12.0, 1.0)
	ground_mat.roughness = 0.92
	ground.material_override = ground_mat
	add_child(ground)
	cam = Camera3D.new()
	cam.fov = 45
	add_child(cam)
	_populate(Vector3.ZERO)
	_update_cam()
	_build_ui()

func _populate(o: Vector3) -> void:
	var items := []
	var b := Assets.build_building("centre", 0, 4)
	b.position = o + Vector3(-6, 0, -4)
	items.append(b)
	for d in [["maison", 2, Vector3(-1, 0, -6)], ["caserne", 3, Vector3(4, 0, -5)], ["marche", 3, Vector3(-7, 0, 3)], ["ferme", 3, Vector3(7, 0, 3)], ["relais", 2, Vector3(1, 0, 6)]]:
		var n := Assets.build_building(d[0], 0 if d[0] != "relais" else 1, d[1])
		n.position = o + d[2]
		items.append(n)
	var types := ["lancier", "lancier", "lancier", "tireur", "tireur", "tireur", "cavalier", "eclaireur", "ouvrier", "ouvrier", "ouvrier", "caravane"]
	for i in types.size():
		var u := Assets.build_unit(types[i], 0 if i % 4 != 3 else 1)
		u.position = o + Vector3(-3 + (i % 6) * 1.2, 0, 0.5 + (i / 6) * 1.5)
		u.rotation.y = 0.4 * i
		items.append(u)
	for i in 10:
		var t := Node3D.new()
		Assets.part(t, "trunk", Assets.mat("bark", Color(0.3, 0.21, 0.13), 0.95, 0.0, true), Vector3(0, 0.5, 0))
		Assets.part(t, "canopy", Assets.mat("leaves", Color(0.16, 0.3, 0.13), 0.9), Vector3(0, 1.75, 0))
		t.position = o + Vector3(10 + (i % 3) * 1.4, 0, -6 + i * 1.1)
		items.append(t)
	for n in items:
		add_child(n)
	return

func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var p := PanelContainer.new()
	p.position = Vector2(8, 8)
	cl.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	v.add_child(label)
	var h := HFlowContainer.new()
	h.custom_minimum_size = Vector2(600, 0)
	v.add_child(h)
	for d in [["Mesurer 10 s", _measure], ["Ombres", func(): sun.shadow_enabled = not sun.shadow_enabled],
			["Échelle 3D", _cycle_scale], ["MSAA", _cycle_msaa], ["Densité x4", _densify],
			["Zoom -", func(): cam_dist = min(70, cam_dist * 1.2); _update_cam()], ["Zoom +", func(): cam_dist = max(10, cam_dist / 1.2); _update_cam()],
			["Menu", func(): get_tree().change_scene_to_file("res://game/main_menu.tscn")]]:
		var b := Button.new()
		b.text = d[0]
		b.custom_minimum_size = Vector2(110, 52)
		b.pressed.connect(d[1])
		h.add_child(b)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 14)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(600, 0)
	v.add_child(result_label)

func _update_cam() -> void:
	var pitch := deg_to_rad(lerpf(48.0, 62.0, (cam_dist - 12.0) / 58.0))
	cam.position = Vector3(0, sin(pitch), cos(pitch)) * cam_dist
	cam.look_at(Vector3.ZERO, Vector3.UP)

func _cycle_scale() -> void:
	scale3d = 0.75 if scale3d == 1.0 else (0.5 if scale3d == 0.75 else 1.0)
	get_viewport().scaling_3d_scale = scale3d

func _cycle_msaa() -> void:
	msaa = (msaa + 1) % 3
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][msaa]

func _densify() -> void:
	density += 1
	_populate(Vector3(0, 0, -14 * (density - 1)))

func _measure() -> void:
	measuring = true
	m_t = 0.0
	m_frames.clear()
	m_draw.clear()
	m_prim.clear()
	result_label.text = "Mesure en cours (10 s) — ne touchez pas l'écran…"

func _process(delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var vmem := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	label.text = "Zone témoin · FPS %d · appels %d · primitives %d · VRAM %.0f Mo · ombres %s · échelle 3D %.2f · MSAA %s · densité x%d · zoom %.0f" % [
		fps, draws, prims, vmem, "oui" if sun.shadow_enabled else "non", scale3d, ["non", "2x", "4x"][msaa], density, cam_dist]
	if measuring:
		m_t += delta
		m_frames.append(delta * 1000.0)
		m_draw.append(draws)
		m_prim.append(prims)
		if m_t >= 10.0:
			measuring = false
			_finish(vmem)

func _finish(vmem: float) -> void:
	var sorted := m_frames.duplicate()
	sorted.sort()
	var avg := 0.0
	for f in m_frames:
		avg += f
	avg /= max(1, m_frames.size())
	var p95: float = sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0
	var res := {
		"date": Time.get_datetime_string_from_system(),
		"version": ProjectSettings.get_setting("application/config/version"),
		"moteur": Engine.get_version_info()["string"],
		"os": OS.get_name() + " " + OS.get_version(),
		"appareil": OS.get_model_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"rendu": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"resolution": str(get_viewport().get_visible_rect().size) + " / fenêtre " + str(DisplayServer.window_get_size()),
		"duree_s": m_t, "images": m_frames.size(),
		"temps_image_moyen_ms": avg, "temps_image_p95_ms": p95, "fps_moyen": 1000.0 / max(0.001, avg),
		"appels_moyens": _mean(m_draw), "primitives_moyennes": _mean(m_prim), "vram_mo": vmem,
		"memoire_statique_mo": OS.get_static_memory_usage() / 1048576.0,
		"ombres": sun.shadow_enabled, "echelle_3d": scale3d, "msaa": msaa, "densite": density, "zoom": cam_dist,
	}
	DirAccess.make_dir_recursive_absolute("user://mesures")
	var path := "user://mesures/temoin_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(res, "  "))
	result_label.text = "Résultat : %.1f ms/image en moyenne (p95 %.1f ms, %.0f FPS), %d appels, VRAM %.0f Mo.\nEnregistré : %s\n(%s)" % [
		avg, p95, 1000.0 / max(0.001, avg), int(_mean(m_draw)), vmem, path, ProjectSettings.globalize_path(path)]

func _mean(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / max(1, a.size())
