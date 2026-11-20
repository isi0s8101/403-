class_name PlacementTool
extends Node3D
## 0.17 — Pose de bâtiments : simple (inchangée), EN LIGNE (glisser le doigt : palissades, maisons…) et
## MULTIPLE (le mode reste actif après chaque pose ; un toucher sur un emplacement valide pose aussitôt).
## La raison d'un refus est écrite au-dessus du fantôme. Rotation : toutes les emprises sont carrées,
## une rotation ne changerait rien (décision documentée).
## Chaque pose passe par la commande simulée « build » (coût, âge, emprise vérifiés par la simulation).

const MAX_LINE := 20
var game
var line_mode: bool = false
var multi_mode: bool = false
var dragging_line: bool = false
var start: Vector2 = Vector2(-1, -1)
var finish: Vector2 = Vector2(-1, -1)
var cells: Array = []
var multimesh_instance: MultiMeshInstance3D
var reason_label: Label3D
var last_report: String = ""

func setup(p_game) -> void:
	game = p_game
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = MAX_LINE
	mm.visible_instance_count = 0
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.multimesh = mm
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	multimesh_instance.material_override = material
	multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(multimesh_instance)
	reason_label = Label3D.new()
	reason_label.font = AgeTheme.font("FiraSans-SemiBold") # 0.18.1 : police livrée
	reason_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reason_label.no_depth_test = true
	reason_label.fixed_size = true
	reason_label.pixel_size = 0.0008
	reason_label.font_size = 30
	reason_label.outline_size = 10
	reason_label.render_priority = 6
	reason_label.visible = false
	add_child(reason_label)

func reset() -> void:
	line_mode = false
	dragging_line = false
	start = Vector2(-1, -1)
	finish = Vector2(-1, -1)
	cells.clear()
	multimesh_instance.multimesh.visible_instance_count = 0
	reason_label.visible = false

func line_cells(type: String, a: Vector2, b: Vector2) -> Array:
	## Cases d'une ligne de bâtiments d'emprise s, alignées sur l'axe dominant, espacées de s.
	var s: int = int(Rules.BUILDINGS[type]["size"])
	var origin: Vector2i = Vector2i(int(a.x - s * 0.5 + 0.5), int(a.y - s * 0.5 + 0.5))
	var delta: Vector2 = b - a
	var horizontal: bool = absf(delta.x) >= absf(delta.y)
	var length: float = absf(delta.x) if horizontal else absf(delta.y)
	var count: int = clampi(int(floor(length / float(s))) + 1, 1, MAX_LINE)
	var step: Vector2i = Vector2i(s * (1 if delta.x >= 0.0 else -1), 0) if horizontal else Vector2i(0, s * (1 if delta.y >= 0.0 else -1))
	var out: Array = []
	for i in count:
		out.append(origin + step * i)
	return out

func begin_line(g: Vector2) -> void:
	start = g
	finish = g
	dragging_line = true
	_update_cells()

func drag_line(g: Vector2) -> void:
	finish = g
	_update_cells()

func end_line() -> void:
	dragging_line = false

func _update_cells() -> void:
	if start.x < 0.0:
		cells.clear()
		return
	cells = line_cells(game.place_type, start, finish)
	if not cells.is_empty():
		game.place_cell = cells[0]

func refresh() -> void:
	## Fantômes (pose en ligne) et raison du refus écrite au-dessus de l'emplacement.
	var mm: MultiMesh = multimesh_instance.multimesh
	if game.mode != "place":
		mm.visible_instance_count = 0
		reason_label.visible = false
		return
	var s: int = int(Rules.BUILDINGS[game.place_type]["size"])
	var why: String = game.world.build_check(game.player, game.place_type, game.place_cell)
	if line_mode and cells.size() > 1:
		(mm.mesh as BoxMesh).size = Vector3(s, 1.2, s)
		mm.visible_instance_count = cells.size()
		for i in cells.size():
			var c: Vector2i = cells[i]
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(c.x + s * 0.5, 0.6, c.y + s * 0.5)))
			var ok: bool = game.world.build_check(game.player, game.place_type, c) == ""
			mm.set_instance_color(i, Color(AgeTheme.c("success"), 0.45) if ok else Color(AgeTheme.c("danger"), 0.45))
	else:
		mm.visible_instance_count = 0
	reason_label.visible = why != ""
	if why != "":
		reason_label.text = why
		reason_label.modulate = AgeTheme.c("danger")
		reason_label.outline_modulate = AgeTheme.c("bg")
		reason_label.position = Vector3(game.place_cell.x + s * 0.5, 2.4, game.place_cell.y + s * 0.5)

func confirm() -> int:
	## Pose toutes les cases de la ligne, dans l'ordre ; renvoie le nombre de fondations posées.
	var targets: Array = cells if line_mode and cells.size() > 1 else [game.place_cell]
	var placed: int = 0
	var refusals: Dictionary = {}
	var ids: Array = []
	for c in targets:
		var r: Dictionary = game.world.issue({"t": "build", "team": game.player, "type": game.place_type, "cell": [c.x, c.y]})
		if bool(r.get("ok", false)):
			placed += 1
			ids.append(int(r.get("id", -1)))
		else:
			var reason: String = String(r.get("reason", "refus"))
			refusals[reason] = int(refusals.get(reason, 0)) + 1
	var parts: PackedStringArray = PackedStringArray()
	for reason in refusals.keys():
		parts.append("%d × %s" % [int(refusals[reason]), reason])
	last_report = "%s : %d fondation(s) posée(s)%s" % [Rules.BUILDINGS[game.place_type]["label"], placed, (" · refus : " + ", ".join(parts)) if not parts.is_empty() else ""]
	if game.hud.command_card.chain_active:
		var workers: Array = []
		for u in game.selected_units():
			if Rules.unit_has(u.type, "worker"):
				workers.append(u.id)
		for id in ids:
			if id >= 0 and not workers.is_empty():
				game.world.issue({"t": "queue_append", "team": game.player, "units": workers, "orders": [{"type": "build", "building": id}]})
	cells.clear()
	start = Vector2(-1, -1)
	return placed
