class_name SpaceMapView
extends Node3D
## J10 : schéma spatial 3D léger ; les trajectoires sont déterminées par la simulation.
## Pas de physique de collision ni de simulation des mondes dans la scène visuelle.
const CENTER := Vector3(48.0, 0.0, 48.0)
var campaign: StarCampaign
var level: String = "system"
var center_body: String = "val"
var active_system: String = "sol"
var markers: Dictionary = {}
var flight_nodes: Array = []
var flight_mat_friend: StandardMaterial3D
var flight_mat_enemy: StandardMaterial3D
const MAX_VISIBLE_FLIGHTS: int = 64
var _last_refresh_tick: int = -1
var orbital_glyphs: Dictionary = {}
var _orbital_group: Node3D


func setup(c: StarCampaign, p_level: String, body_id: String) -> void:
	campaign = c
	level = p_level
	center_body = body_id if c.star_catalog.has_body(body_id) else c.active
	active_system = String(c.star_catalog.info(center_body)["system_id"])
	position = CENTER
	flight_mat_friend = _material(Color(0.18, 0.94, 0.96))
	flight_mat_enemy = _material(Color(1.0, 0.39, 0.33))
	_build_scene()
	_orbital_group = Node3D.new()
	add_child(_orbital_group)
	refresh_sim(true)

func _material(col: Color, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.75
	mat.metallic = 0.05
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _ball(parent: Node3D, pos: Vector3, radius: float, col: Color, key: String = "") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	node.mesh = sphere
	node.material_override = _material(col)
	node.position = pos
	parent.add_child(node)
	if key != "":
		markers[key] = node
		if campaign != null:
			var label3d := Label3D.new()
			label3d.text = String(campaign.star_catalog.info(key)["label"])
			label3d.font_size = 32
			label3d.pixel_size = 0.18
			label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label3d.position = Vector3(0.0, radius + 1.0, -5.0)
			node.add_child(label3d)
	return node

func _ring(center: Vector3, radius: float, color: Color) -> void:
	var mat: StandardMaterial3D = _material(color, true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	for index in 97:
		var a: float = TAU * float(index) / 96.0
		mesh.surface_add_vertex(center + Vector3(cos(a), 0.0, sin(a)) * radius)
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	add_child(node)

func _body_color(body: Dictionary) -> Color:
	if String(body["kind"]) == "moon":
		return Color(0.54, 0.58, 0.63)
	var gen := PlanetGenerator.new(int(body["seed"]))
	return gen.color_at(0.28, 0.15)

func _build_scene() -> void:
	if level == "orbit":
		var current: Dictionary = campaign.star_catalog.info(center_body)
		_ball(self, Vector3.ZERO, 10.0, _body_color(current), center_body)
		for other in campaign.star_catalog.orbit_for(center_body):
			if String(other["id"]) == center_body:
				continue
			var radius: float = float(other["orbit"]) * 2.8
			_ring(Vector3.ZERO, radius, Color(0.37, 0.58, 0.72, 0.50))
			var a: float = float(other["phase"])
			_ball(self, Vector3(cos(a) * radius, 0.0, sin(a) * radius), 2.4,
				_body_color(other), String(other["id"]))
		# Satellites visuels déjà possédés ; le compteur appartient à StarCampaign.
		for team in campaign.faction_ids():
			for index in int(campaign.satellites[team]):
				var a: float = TAU * float(index + 1 + team * 3) / 7.0
				_ball(self, Vector3(cos(a) * 15.0, 0.0, sin(a) * 15.0), 0.56,
					Color(0.21, 0.88, 0.93) if team == 0 else Color(1.0, 0.44, 0.34))
	else:
		var system_data: Dictionary = campaign.star_catalog.systems[active_system]
		_ball(self, Vector3.ZERO, 5.0, system_data["color"] as Color)
		for body in campaign.star_catalog.bodies_for_system(active_system):
			var orbit_radius: float = float(body["orbit"])
			_ring(Vector3.ZERO, orbit_radius, Color(0.46, 0.59, 0.70, 0.37))
			var pos: Vector2 = campaign.star_catalog.body_position(String(body["id"]), campaign.tick)
			_ball(self, Vector3(pos.x, 0.0, pos.y), maxf(1.1, float(body["size"])),
				_body_color(body), String(body["id"]))

func refresh_sim(force: bool = false) -> void:
	if campaign == null:
		return
	if not force and campaign.tick - _last_refresh_tick < 10:
		return
	_last_refresh_tick = campaign.tick
	_refresh_orbital_glyphs()
	if level == "orbit":
		for key in markers:
			if String(key) == center_body:
				continue
			var moon: Dictionary = campaign.star_catalog.info(String(key))
			var orbit: float = float(moon["orbit"]) * 2.8
			var angle: float = float(moon["phase"]) + float(campaign.tick) * 0.00032
			(markers[key] as MeshInstance3D).position = Vector3(cos(angle) * orbit, 0.0, sin(angle) * orbit)
	if level == "system":
		for key in markers:
			var data: Dictionary = campaign.star_catalog.info(String(key))
			var pos: Vector2 = campaign.star_catalog.body_position(String(key), campaign.tick)
			(markers[key] as MeshInstance3D).position = Vector3(pos.x, 0.0, pos.y)
	if level != "system":
		return
	var used: int=0
	for record in MovementFeed.records(campaign,0):
		if used>=MAX_VISIBLE_FLIGHTS:break
		if String(record["from_system"])!=active_system or String(record["to_system"])!=active_system:continue
		if not campaign.star_catalog.has_body(String(record["from"])) or not campaign.star_catalog.has_body(String(record["to"])):continue
		var from:Vector2=campaign.star_catalog.body_position(String(record["from"]),campaign.tick)
		var to:Vector2=campaign.star_catalog.body_position(String(record["to"]),campaign.tick)
		var progress:float=clampf(1.0-float(record["eta"])/float(record["duration"]),0,1)
		var node:MeshInstance3D
		if used<flight_nodes.size():node=flight_nodes[used]
		else:node=_ball(self,Vector3.ZERO,0.85,Color.WHITE);flight_nodes.append(node)
		node.position=Vector3(from.lerp(to,progress).x,0.6,from.lerp(to,progress).y)
		node.material_override=_material(MovementFeed.tint(record,0),true)
		node.visible=true;used+=1
	for i in range(used,flight_nodes.size()):flight_nodes[i].visible=false

func pick(camera: Camera3D, screen_point: Vector2) -> String:
	if camera == null:
		return ""
	var candidate: String = ""
	var best: float = 42.0
	for key in markers:
		var node: MeshInstance3D = markers[key]
		if camera.is_position_behind(node.global_position):
			continue
		var distance: float = camera.unproject_position(node.global_position).distance_to(screen_point)
		if distance < best:
			candidate = String(key)
			best = distance
	return candidate

func _refresh_orbital_glyphs() -> void:
	if _orbital_group == null:
		return
	var wanted: Dictionary = {}
	var bodies: Array = [center_body] if level == "orbit" else campaign.star_catalog.bodies_for_system(active_system)
	for element in bodies:
		var body: String = String(element) if level == "orbit" else String((element as Dictionary)["id"])
		for team in campaign.faction_ids():
			var id: String = OrbitalIndustry.key(team, body)
			var station: Dictionary = OrbitalIndustry.site(campaign, team, body)
			if station.is_empty():
				continue
			wanted[id] = true
			var node: Node3D = orbital_glyphs.get(id) as Node3D
			if node == null:
				# Silhouette métallique simplifiée, indépendante du terrain tactique.
				var age: int = campaign.planets.local_age(campaign, team, body)
				var asset: String = AssetLibrary.find("orbital_structure", "shipyard", maxi(9, age))
				node = AssetLibrary.instantiate_compact(asset, 1)
				if node != null:
					node.scale = Vector3.ONE * AssetLibrary.scale_for_cells(asset, 3.4 if level == "orbit" else 2.0)
					AssetLibrary.set_team_color(node, OrbitalTactics.color(int(team)))
				else:
					var fallback := MeshInstance3D.new()
					var mesh := BoxMesh.new()
					mesh.size = Vector3(2.8, 1.3, 1.6)
					fallback.mesh = mesh
					fallback.material_override = _material(OrbitalTactics.color(int(team)))
					node = fallback
				_orbital_group.add_child(node)
				orbital_glyphs[id] = node
			if level == "orbit":
				var angle: float = float(campaign.tick) * 0.0005 + float(team) * PI
				node.position = Vector3(cos(angle) * 14.0, 1.2, sin(angle) * 14.0)
			else:
				var body_pos: Vector2 = campaign.star_catalog.body_position(body, campaign.tick)
				node.position = Vector3(body_pos.x + 2.0 + float(team), 0.7, body_pos.y + 1.0)
			node.visible = true
	for id in orbital_glyphs.keys():
		if not wanted.has(id):
			(orbital_glyphs[id] as Node3D).visible = false

func select_marker(id:String)->void:
	for key in markers:
		(markers[key] as Node3D).scale=Vector3.ONE*(1.3 if String(key)==id else 1.0)
