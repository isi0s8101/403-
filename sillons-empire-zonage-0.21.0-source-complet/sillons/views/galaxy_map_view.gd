class_name GalaxyMapView
extends Node3D
## J11 : carte stratégique galactique légère. La simulation reste StarCampaign.
const CENTER := Vector3(48.0, 0.0, 48.0)
const MAX_VISIBLE_TRANSITS: int = 48
# Le budget visuel ne réduit jamais le nombre de convois réellement simulés.
const MAX_VISIBLE_FREIGHT: int = 24
var campaign: StarCampaign
var player: int = 0
var markers: Dictionary = {}
var labels: Dictionary = {}
var flight_nodes: Array = []
var freight_nodes: Array = []
var _last_tick: int = -1
var refresh_tick_budget: int = 15
var _last_known_count: int = -1
var roads_node: MeshInstance3D
var _marker_materials: Dictionary = {}

func setup(c: StarCampaign, p_player: int) -> void:
	campaign = c
	player = p_player
	position = CENTER
	_build()
	refresh_sim(true)

func _material(col: Color) -> StandardMaterial3D:
	var cache_key: String = col.to_html()
	if _marker_materials.has(cache_key):
		return _marker_materials[cache_key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_materials[cache_key] = mat
	return mat

func _dot(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 12
	ball.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = ball
	node.material_override = _material(color)
	node.position = pos
	parent.add_child(node)
	return node

func _build() -> void:
	var graph: GalaxyGenerator = campaign.star_catalog.galaxy
	_build_roads()
	var ids: Array = graph.systems.keys()
	ids.sort()
	for key in ids:
		var node: Dictionary = graph.systems[key]
		var p: Vector2 = node["pos"]
		var star: MeshInstance3D = _dot(self, Vector3(p.x, 0.0, p.y), 1.8, Color(0.35, 0.41, 0.50))
		markers[key] = star
		var label := Label3D.new()
		label.font_size = 32
		label.pixel_size = 0.20
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, 2.5, -5.0)
		star.add_child(label)
		labels[key] = label

func _build_roads() -> void:
	var graph: GalaxyGenerator = campaign.star_catalog.galaxy
	if roads_node == null:
		roads_node = MeshInstance3D.new()
		add_child(roads_node)
	var roads := ImmediateMesh.new()
	roads.surface_begin(Mesh.PRIMITIVE_LINES, _material(Color(0.17, 0.35, 0.56)))
	for edge in graph.edges:
		var a: String = String(edge["a"])
		var b: String = String(edge["b"])
		if not campaign.system_known(player, a) and not campaign.system_known(player, b):
			continue
		var p1: Vector2 = graph.systems[a]["pos"]
		var p2: Vector2 = graph.systems[b]["pos"]
		roads.surface_add_vertex(Vector3(p1.x, -0.6, p1.y))
		roads.surface_add_vertex(Vector3(p2.x, -0.6, p2.y))
	roads.surface_end()
	roads_node.mesh = roads
	_last_known_count = (campaign.discovered_systems[player] as Dictionary).size()

func refresh_sim(force: bool = false) -> void:
	if campaign == null or (not force and campaign.tick - _last_tick < refresh_tick_budget):
		return
	_last_tick = campaign.tick
	if (campaign.discovered_systems[player] as Dictionary).size() != _last_known_count:
		_build_roads()
	for key in markers.keys():
		var known: bool = campaign.system_known(player, String(key))
		var owner: int = campaign.system_owner(String(key)) if known else -1
		var color: Color = Color(0.32, 0.38, 0.48)
		if known:
			color = campaign.star_catalog.galaxy.systems[key]["color"] as Color
			if owner == 0:
				color = Color(0.25, 0.90, 0.92)
			elif owner == 1:
				color = Color(0.99, 0.35, 0.28)
			elif owner == -2:
				color = Color(0.96, 0.68, 0.19)
		(markers[key] as MeshInstance3D).material_override = _material(color)
		(labels[key] as Label3D).text = String(campaign.star_catalog.galaxy.systems[key]["label"]) if known else "?"
	var used:int=0
	for record in MovementFeed.records(campaign,player):
		if used>=MAX_VISIBLE_TRANSITS:break
		var source:String=String(record["from_system"]);var target:String=String(record["to_system"])
		if not campaign.star_catalog.galaxy.systems.has(source) or not campaign.star_catalog.galaxy.systems.has(target):continue
		if source==target:continue
		var a:Vector2=campaign.star_catalog.galaxy.systems[source]["pos"]
		var b:Vector2=campaign.star_catalog.galaxy.systems[target]["pos"]
		var progress:float=clampf(1.0-float(record["eta"])/float(record["duration"]),0,1)
		var point:Vector2=a.lerp(b,progress)
		var node:MeshInstance3D
		if used<flight_nodes.size():node=flight_nodes[used]
		else:node=_dot(self,Vector3.ZERO,0.95,Color.WHITE);flight_nodes.append(node)
		node.position=Vector3(point.x,0.6,point.y)
		node.material_override=_material(MovementFeed.tint(record,player));node.visible=true;used+=1
	for i in range(used,flight_nodes.size()):flight_nodes[i].visible=false

func pick(camera: Camera3D, point: Vector2) -> String:
	if camera == null:
		return ""
	var best_id: String = ""
	var closest: float = 35.0
	for key in markers:
		var node: MeshInstance3D = markers[key]
		if camera.is_position_behind(node.global_position):
			continue
		var distance: float = camera.unproject_position(node.global_position).distance_to(point)
		if distance < closest:
			best_id = String(key)
			closest = distance
	return best_id

func select_marker(id:String)->void:
	for key in markers:
		(markers[key] as Node3D).scale=Vector3.ONE*(1.5 if String(key)==id else 1.0)
		(labels[key] as Label3D).modulate=MobileUI.ACCENT if String(key)==id else Color.WHITE
