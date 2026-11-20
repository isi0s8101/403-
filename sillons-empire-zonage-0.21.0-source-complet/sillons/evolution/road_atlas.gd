class_name RoadAtlas
extends Control
var campaign: StarCampaign
var team: int
var body: String
var path: Array = []
var dragging: bool = false
func setup(c: StarCampaign, actor: int, planet: String) -> void:
	campaign = c
	team = actor
	body = planet
	mouse_filter = Control.MOUSE_FILTER_STOP
func _cell(pos: Vector2) -> int:
	return clampi(int(pos.y / maxf(1, size.y) * J13Rules.GRID_H), 0, J13Rules.GRID_H - 1) * J13Rules.GRID_W + clampi(int(pos.x / maxf(1, size.x) * J13Rules.GRID_W), 0, J13Rules.GRID_W - 1)
func _extend(id: int) -> void:
	if path.is_empty(): path.append(id)
	var previous: int = int(path.back())
	var x: int = previous % J13Rules.GRID_W
	var y: int = previous / J13Rules.GRID_W
	var tx: int = id % J13Rules.GRID_W
	var ty: int = id / J13Rules.GRID_W
	while x != tx or y != ty:
		if x != tx: x += 1 if tx > x else -1
		elif y != ty: y += 1 if ty > y else -1
		if path.size() >= 144: break
		path.append(y * J13Rules.GRID_W + x)
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging: path = []; _extend(_cell(event.position))
		accept_event()
	elif event is InputEventMouseMotion and dragging: _extend(_cell(event.position)); accept_event()
	elif event is InputEventScreenTouch:
		dragging = event.pressed
		if dragging: path = []; _extend(_cell(event.position))
		accept_event()
	elif event is InputEventScreenDrag and dragging: _extend(_cell(event.position)); accept_event()
func _draw() -> void:
	if campaign == null: return
	var p: Dictionary = campaign.planets.colony(team, body)
	var cell_size: Vector2 = size / Vector2(J13Rules.GRID_W, J13Rules.GRID_H)
	var mask: PackedByteArray = PlanetCampaign.land_mask(campaign.planets._body_seed(campaign, body))
	for id in J13Rules.GRID_W * J13Rules.GRID_H:
		var color := Color(0.16, 0.29, 0.22)
		if mask[id] == J13Rules.LAND_OCEAN: color = Color(0.1, 0.21, 0.35)
		elif mask[id] != J13Rules.LAND_BUILDABLE: color = Color(0.33, 0.29, 0.25)
		if p["cells"].has(id) and bool(p["cells"][id]["road"]): color = Color(0.36, 0.66, 0.59)
		if path.has(id): color = Color(0.97, 0.77, 0.3)
		draw_rect(Rect2(Vector2(id % J13Rules.GRID_W, id / J13Rules.GRID_W) * cell_size, cell_size - Vector2.ONE * 2), color)
	if not path.is_empty():
		var report: Dictionary = RoadService.preview(campaign, team, body, path)
		var caption: String = Rules.cost_text(report["cost"]) if bool(report.get("ok", false)) else String(report.get("reason", "Refus"))
		draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 8), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 16, Color.WHITE)
func commit() -> Dictionary:
	var result: Dictionary = campaign.issue_evolution({"t": "roads", "team": team, "body": body, "path": path.duplicate()})
	if bool(result.get("ok", false)): path = []; queue_redraw()
	return result
