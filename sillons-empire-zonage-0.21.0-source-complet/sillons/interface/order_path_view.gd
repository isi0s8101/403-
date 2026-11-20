class_name OrderPathView
extends Node3D
## 0.17 — Affichage au sol, en UN seul maillage de lignes réutilisé (un appel de dessin) :
## - étapes de la file des unités sélectionnées : points numérotés 1, 2, 3… reliés par des pointillés de la
##   couleur du type d'étape, étape en cours mise en valeur, étapes faites effacées, « ↻ » si la file boucle ;
## - aperçu du rayon d'un pouvoir de commandement pendant le ciblage ;
## - auras des héros et zones des pouvoirs actifs (cercles légers) ;
## - portées d'attaque de la sélection (bascule « Portées ») ;
## - barres de vie au-dessus des unités sélectionnées ou blessées : couleur selon la santé, doublée d'une
##   forme (unité adverse : petit triangle au-dessus de la barre ; alliée : barre seule).
## Lignes rafraîchies 10 fois par seconde ; barres à chaque image (≤ 80 quadrilatères, un second maillage).
## Aucun nœud par unité.

const MAX_LABELS := 24
const REFRESH := 0.1
const MAX_BARS := 80
var game
var mesh_instance: MeshInstance3D
var mesh: ImmediateMesh
var labels: Array = []
var points: Array = []            # [{pos: Vector2, index: int, units: Array}] — pour toucher un point et l'éditer
var show_ranges: bool = false
var _t: float = 0.0
var line_count: int = 0
var bars_mesh: ImmediateMesh
var bar_count: int = 0

func setup(p_game) -> void:
	game = p_game
	mesh = ImmediateMesh.new()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 4
	mesh_instance.material_override = material
	add_child(mesh_instance)
	bars_mesh = ImmediateMesh.new()
	var bars_instance := MeshInstance3D.new()
	bars_instance.mesh = bars_mesh
	bars_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bars_instance.material_override = material
	add_child(bars_instance)
	for i in MAX_LABELS:
		var label := Label3D.new()
		label.font = AgeTheme.font("FiraSans-SemiBold") # 0.18.1 : police livrée (« ∞ » et accents sur Android)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0009
		label.font_size = 30
		label.outline_size = 10
		label.render_priority = 5
		label.visible = false
		add_child(label)
		labels.append(label)

func tick(delta: float) -> void:
	_bars()
	_t += delta
	if _t < REFRESH:
		return
	_t = 0.0
	rebuild()

func rebuild() -> void:
	mesh.clear_surfaces()
	points.clear()
	line_count = 0
	var used: int = 0
	var lines: Array = []          # [a: Vector3, b: Vector3, color]
	used = _queues(lines, used)
	_circles(lines)
	if not lines.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for seg in lines:
			mesh.surface_set_color(seg[2])
			mesh.surface_add_vertex(seg[0])
			mesh.surface_set_color(seg[2])
			mesh.surface_add_vertex(seg[1])
		mesh.surface_end()
	line_count = lines.size()
	for i in range(used, MAX_LABELS):
		(labels[i] as Label3D).visible = false

func _v3(p: Vector2, y: float = 0.25) -> Vector3:
	return Vector3(p.x, y, p.y)

func _dashed(lines: Array, a: Vector2, b: Vector2, color: Color) -> void:
	var length: float = a.distance_to(b)
	if length < 0.05:
		return
	var dir: Vector2 = (b - a) / length
	var d: float = 0.0
	while d < length and lines.size() < 1800:
		var e: float = minf(length, d + 0.7)
		lines.append([_v3(a + dir * d), _v3(a + dir * e), color])
		d += 1.15

func _circle(lines: Array, center: Vector2, radius: float, color: Color, segments: int = 40) -> void:
	for i in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		lines.append([_v3(center + Vector2(cos(a0), sin(a0)) * radius, 0.18), _v3(center + Vector2(cos(a1), sin(a1)) * radius, 0.18), color])

func _step_pos(step: Dictionary) -> Vector2:
	if step.has("pos"):
		var raw = step["pos"]
		return Vector2(float(raw[0]), float(raw[1])) if raw is Array else raw
	for key in ["target", "building", "node"]:
		if step.has(key):
			var e = game.world.entity(int(step[key]))
			if e == null:
				e = game.world.nodes.get(int(step[key]))
			if e != null:
				return e.pos if e is SimWorld.Unit or e is SimWorld.ResNode else e.center
	return Vector2(-1, -1)

func _queues(lines: Array, used: int) -> int:
	var seen: Dictionary = {}
	for u in game.selected_units():
		if u.order_steps.is_empty():
			continue
		var key: String = "%d" % u.order_group if u.order_group != 0 else "u%d" % u.id
		if seen.has(key):
			(seen[key] as Array).append(u.id)
			continue
		seen[key] = [u.id]
		if seen.size() > 4:
			break
		var from: Vector2 = u.pos - u.order_offset if u.order_group != 0 else u.pos
		var first: int = 0 if u.order_loop else u.order_step
		var last_point: Vector2 = Vector2(-1, -1)
		for i in range(first, u.order_steps.size()):
			var step: Dictionary = u.order_steps[i]
			var p: Vector2 = _step_pos(step)
			if p.x < 0.0:
				continue
			var color: Color = AgeTheme.STEP_COLORS.get(String(step["type"]), AgeTheme.c("accent")) as Color
			var current: bool = i == u.order_step
			if i >= u.order_step or u.order_loop:
				_dashed(lines, from if i == u.order_step else last_point if last_point.x >= 0.0 else from, p, Color(color, 0.95 if current else 0.6))
			_circle(lines, p, 0.55 if current else 0.38, Color(color, 0.95), 16)
			points.append({"pos": p, "index": i, "units": seen[key]})
			if used < MAX_LABELS:
				var label: Label3D = labels[used]
				label.text = str(i + 1)
				label.position = _v3(p, 0.9)
				label.modulate = color if current else Color(color, 0.75)
				label.outline_modulate = AgeTheme.c("bg")
				label.font_size = 38 if current else 28
				label.visible = true
				used += 1
			last_point = p
		if u.order_loop and last_point.x >= 0.0:
			var start: Vector2 = _step_pos(u.order_steps[0])
			if start.x >= 0.0:
				_dashed(lines, last_point, start, Color(AgeTheme.c("accent"), 0.5))
			if used < MAX_LABELS:
				var loop_label: Label3D = labels[used]
				loop_label.text = "∞"
				loop_label.position = _v3(last_point + Vector2(0.9, -0.9), 1.0)
				loop_label.modulate = AgeTheme.c("accent")
				loop_label.font_size = 34
				loop_label.visible = true
				used += 1
	return used

func _circles(lines: Array) -> void:
	var w: SimWorld = game.world
	if String(game.mode) == "civ_power" and CivRules.POWERS.has(game.civ_power_key):
		var radius: float = float((CivRules.POWERS[game.civ_power_key] as Dictionary)["radius"])
		_circle(lines, game.power_preview, radius, Color(AgeTheme.c("accent"), 0.95), 56)
		_circle(lines, game.power_preview, 0.4, Color(AgeTheme.c("accent"), 0.95), 12)
	if CivEvolution.enabled(w):
		for u in w.team_units(game.player, ""):
			if CivRules.HEROES.has(u.type):
				_circle(lines, u.pos, float((CivRules.HEROES[u.type] as Dictionary)["aura"]), Color(AgeTheme.c("info"), 0.35), 40)
		for effect in (CivEvolution.state(w, game.player)["effects"] as Array):
			if effect is Dictionary and (effect as Dictionary).has("pos"):
				var raw = effect["pos"]
				var pos: Vector2 = Vector2(float(raw[0]), float(raw[1])) if raw is Array else raw
				_circle(lines, pos, float((effect as Dictionary).get("radius", 6.0)), Color(AgeTheme.c("warning"), 0.45), 40)
	if show_ranges:
		var count: int = 0
		for u in game.selected_units():
			var reach: float = float(Rules.UNITS[u.type]["range"])
			if reach > 0.5:
				_circle(lines, u.pos, reach, Color(AgeTheme.c("danger"), 0.4), 28)
			_circle(lines, u.pos, float(Rules.UNITS[u.type]["vision"]), Color(AgeTheme.c("info"), 0.18), 32)
			count += 1
			if count >= 12:
				break

func point_at(screen: Vector2, cam: Camera3D, radius_px: float = 30.0) -> Dictionary:
	## Point d'étape le plus proche du doigt (pour Déplacer / Supprimer / Insérer avant).
	var best: Dictionary = {}
	var bd: float = radius_px * radius_px
	for p in points:
		var wp: Vector3 = _v3(p["pos"], 0.3)
		if cam.is_position_behind(wp):
			continue
		var d: float = cam.unproject_position(wp).distance_squared_to(screen)
		if d < bd:
			bd = d
			best = p
	return best

func _bars() -> void:
	## Barres de vie (unités sélectionnées, unités blessées visibles), orientées vers la caméra.
	bars_mesh.clear_surfaces()
	bar_count = 0
	if game.planet_mode or game.space_mode != "" or game.cam == null:
		return
	var w: SimWorld = game.world
	var selected: Dictionary = {}
	for id in game.selected_ids():
		selected[int(id)] = true
	var basis: Basis = game.cam.global_transform.basis
	var right: Vector3 = basis.x.normalized()
	var up: Vector3 = basis.y.normalized()
	var alpha: float = clampf(game.acc / Rules.DT, 0.0, 1.0)
	var started: bool = false
	for u in w.units.values():
		if bar_count >= MAX_BARS:
			break
		if u.garrison_id != -1 or (u.hp >= u.max_hp - 0.01 and not selected.has(u.id)):
			continue
		if u.team != game.player and not w.is_visible_to(game.player, u.pos):
			continue
		var p2: Vector2 = u.prev_pos.lerp(u.pos, alpha)
		var top: Vector3 = Vector3(p2.x, 2.0, p2.y)
		if game.cam.is_position_behind(top) or not game.get_viewport().get_visible_rect().has_point(game.cam.unproject_position(top)):
			continue
		if not started:
			bars_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			started = true
		var ratio: float = clampf(u.hp / maxf(1.0, u.max_hp), 0.0, 1.0)
		var half: float = 0.55
		var height: float = 0.09
		var fill: Color = AgeTheme.c("success") if ratio > 0.6 else (AgeTheme.c("warning") if ratio > 0.3 else AgeTheme.c("danger"))
		_quad(top - right * (half + 0.03) - up * 0.03, right * ((half + 0.03) * 2.0), up * (height + 0.06), Color(AgeTheme.c("bg"), 0.85))
		_quad(top - right * half, right * (half * 2.0 * ratio), up * height, fill)
		if u.team != game.player:
			var apex: Vector3 = top + up * (height + 0.22)
			_tri(apex, top + up * (height + 0.06) - right * 0.12, top + up * (height + 0.06) + right * 0.12, AgeTheme.c("danger"))
		bar_count += 1
	if started:
		bars_mesh.surface_end()

func _quad(origin: Vector3, along: Vector3, high: Vector3, color: Color) -> void:
	_tri(origin, origin + along, origin + along + high, color)
	_tri(origin, origin + along + high, origin + high, color)

func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for v in [a, b, c]:
		bars_mesh.surface_set_color(color)
		bars_mesh.surface_add_vertex(v)
