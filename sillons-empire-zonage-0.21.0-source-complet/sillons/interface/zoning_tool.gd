class_name ZoningTool
extends Node3D
## 0.19 — Mode Zonage au doigt : pinceau (1 à 3 cases), rectangle glissé, parcelle (2×2 au toucher), gomme, routes
## (tracé au doigt), inspection d'un quartier, annuler. Tout passe par les commandes de la simulation
## ("zone_paint", "zone_clear", "road_paint", "road_remove") : aucune règle de jeu ici.

signal changed

const MAX_UNDO: int = 30
const TOOLS := ["brush", "rect", "parcel", "inspect"]

var game
var active: bool = false
var kind: int = 1                 # code de zone ; 0 = gomme ; -1 = route
var tool: String = "brush"
var brush: int = 1                # côté du pinceau en cases (1, 2 ou 3)
var undo_stack: Array = []
var last_result: String = ""
var inspected: Dictionary = {}
var _dragging: bool = false
var _start: Vector2i = Vector2i(-1, -1)
var _last: Vector2i = Vector2i(-1, -1)
var _stroke: Dictionary = {}      # cases déjà traitées pendant le geste (pinceau, route)
var _stroke_undo: Dictionary = {} # case -> ancien code, pour un seul « annuler » par geste
var _stroke_roads: Array = []
var preview: MeshInstance3D

func setup(p_game) -> void:
	game = p_game
	preview = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	preview.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = Color(1, 1, 1, 0.35)
	preview.material_override = mat
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.visible = false
	add_child(preview)

func open() -> void:
	active = true
	game.mode = "zone"
	game.view.set_overlay(1)
	changed.emit()

func close() -> void:
	active = false
	_dragging = false
	preview.visible = false
	inspected = {}
	if game.mode == "zone":
		game.mode = ""
	game.view.set_overlay(1 if game.city_overlay != null and game.city_overlay.view == "zoning" else 0)
	changed.emit()

func set_kind(code: int) -> void:
	kind = code
	if tool == "inspect":
		tool = "brush"
	changed.emit()

func set_tool(name: String) -> void:
	if name == "brush" and tool == "brush":
		brush = brush % 3 + 1     # un second toucher sur « Pinceau » change sa taille
	tool = name
	changed.emit()

func kind_color(code: int) -> Color:
	if code == -1:
		return UrbanZoning.ROAD_SWATCH
	if code == 0:
		return UrbanZoning.ERASE_SWATCH
	return (UrbanZoning.KINDS[code] as Dictionary)["color"] if UrbanZoning.KINDS.has(code) else Color.WHITE

# ---------------------------------------------------------------- gestes

func cell_at(ground: Vector2) -> Vector2i:
	return Vector2i(int(floor(ground.x)), int(floor(ground.y)))

func begin(ground: Vector2) -> void:
	_dragging = true
	_start = cell_at(ground)
	_last = _start
	_stroke.clear()
	_stroke_undo.clear()
	_stroke_roads.clear()
	if tool == "brush" or kind == -1:
		_paint_cells(_brush_cells(_start))
	_update_preview(_start, _start)

func drag(ground: Vector2) -> void:
	if not _dragging:
		return
	var c: Vector2i = cell_at(ground)
	if c == _last:
		return
	if tool == "brush" or kind == -1:
		# Trait continu : toutes les cases entre le dernier point et le nouveau (pas de trous si le doigt va vite).
		var cells: Array = []
		for p in _line(_last, c):
			cells.append_array(_brush_cells(p) if kind != -1 else [p])
		_paint_cells(cells)
	_last = c
	_update_preview(_start, c)

func end(ground: Vector2, moved: bool) -> void:
	if not _dragging:
		return
	_dragging = false
	var c: Vector2i = cell_at(ground)
	if tool == "rect" and kind != -1:
		var cells: Array = []
		for y in range(mini(_start.y, c.y), maxi(_start.y, c.y) + 1):
			for x in range(mini(_start.x, c.x), maxi(_start.x, c.x) + 1):
				cells.append(Vector2i(x, y))
		_paint_cells(cells)
	elif not moved and tool == "parcel" and kind != -1:
		var o: Vector2i = c
		_paint_cells([o, o + Vector2i(1, 0), o + Vector2i(0, 1), o + Vector2i(1, 1)])
	elif not moved and tool == "inspect":
		inspect(c)
	_commit_stroke()
	preview.visible = false
	changed.emit()

func cancel() -> void:
	_dragging = false
	preview.visible = false

func _brush_cells(c: Vector2i) -> Array:
	var out: Array = []
	var half: int = (brush - 1) / 2
	for dy in brush:
		for dx in brush:
			out.append(c + Vector2i(dx - half, dy - half))
	return out

func _line(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		out.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return out

# ---------------------------------------------------------------- commandes

func _paint_cells(cells: Array) -> void:
	var w: SimWorld = game.world
	var team: int = game.player
	var todo: Array = []
	for value in cells:
		var c: Vector2i = value
		var key: int = c.y * 65536 + c.x
		if not w.in_map(c) or _stroke.has(key):
			continue
		_stroke[key] = true
		todo.append([c.x, c.y])
		if kind != -1 and not _stroke_undo.has(key):
			_stroke_undo[key] = UrbanZoning.zone_at(w, team, c)
	if todo.is_empty():
		return
	var result: Dictionary
	if kind == -1:
		result = w.issue({"t": "road_paint", "team": team, "cells": todo})
		if bool(result.get("ok", false)):
			var last: Dictionary = (w.teams[team] as SimWorld.Team).zoning.get("last_roads", {}) as Dictionary
			_stroke_roads.append_array(last.get("cells", []) as Array)
	elif kind == 0:
		result = w.issue({"t": "zone_clear", "team": team, "cells": todo})
	else:
		result = w.issue({"t": "zone_paint", "team": team, "kind": kind, "cells": todo})
	last_result = "" if bool(result.get("ok", false)) else String(result.get("reason", ""))
	game.view.refresh_urban_layers(true)

func _commit_stroke() -> void:
	if not _stroke_roads.is_empty():
		undo_stack.append({"type": "road", "cells": _stroke_roads.duplicate()})
	elif not _stroke_undo.is_empty():
		var cells: Array = []
		for key in _stroke_undo.keys():
			cells.append([int(key) % 65536, int(key) / 65536, int(_stroke_undo[key])])
		undo_stack.append({"type": "zone", "cells": cells})
	while undo_stack.size() > MAX_UNDO:
		undo_stack.pop_front()
	_stroke_undo.clear()
	_stroke_roads.clear()

func undo() -> bool:
	## Annule le dernier geste : anciennes zones remises, routes retirées (remboursées en entier peu après le tracé).
	if undo_stack.is_empty():
		return false
	var entry: Dictionary = undo_stack.pop_back()
	var w: SimWorld = game.world
	var team: int = game.player
	if String(entry["type"]) == "road":
		w.issue({"t": "road_remove", "team": team, "cells": entry["cells"], "undo": true})
	else:
		var groups: Dictionary = {}
		for triple in entry["cells"] as Array:
			var code: int = int(triple[2])
			if not groups.has(code):
				groups[code] = []
			(groups[code] as Array).append([int(triple[0]), int(triple[1])])
		for code in groups.keys():
			if int(code) == 0:
				w.issue({"t": "zone_clear", "team": team, "cells": groups[code]})
			else:
				w.issue({"t": "zone_paint", "team": team, "kind": int(code), "cells": groups[code]})
	game.view.refresh_urban_layers(true)
	changed.emit()
	return true

func inspect(c: Vector2i) -> void:
	inspected = UrbanZoning.district_stats(game.world, game.player, c)
	inspected["at"] = c
	changed.emit()

# ---------------------------------------------------------------- aperçu au sol

func _update_preview(a: Vector2i, b: Vector2i) -> void:
	var x0: int = mini(a.x, b.x)
	var y0: int = mini(a.y, b.y)
	var x1: int = maxi(a.x, b.x)
	var y1: int = maxi(a.y, b.y)
	if tool == "brush" or kind == -1:
		var half: int = (brush - 1) / 2 if kind != -1 else 0
		var size: int = brush if kind != -1 else 1
		x0 = b.x - half
		y0 = b.y - half
		x1 = x0 + size - 1
		y1 = y0 + size - 1
	preview.scale = Vector3(float(x1 - x0 + 1), 1.0, float(y1 - y0 + 1))
	preview.position = Vector3(float(x0 + x1 + 1) * 0.5, 0.08, float(y0 + y1 + 1) * 0.5)
	var col: Color = kind_color(kind)
	(preview.material_override as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.4)
	preview.visible = true
