class_name PlanetGlobeView
extends Node3D
## J9-C : globe 3D procédural ; ne modifie jamais SimWorld.
## Représentation globale simplifiée, non simulée au niveau de chaque cellule.
const RADIUS: float = 19.0
const LON_SEGMENTS: int = 72
const LAT_SEGMENTS: int = 36
var generator: PlanetGenerator
var globe: MeshInstance3D
var marker: MeshInstance3D
var _next_lat_band: int = 0
var _mesh_stream: ArrayMesh
var selected_lon: float = 0.0
var selected_lat: float = 0.0
# J13.2 : districts de la colonie affichés avec les modèles de la bibliothèque d'assets (lecture seule).
var districts_root: Node3D
var district_nodes: Dictionary = {}     # district -> identifiant d'asset affiché
var _district_signature: String = ""
var _campaign: StarCampaign = null
var _team: int = 0
var overlay_mode: String = "zones"
var district_markers: Dictionary = {}
var _district_sites: Dictionary = {}
var _markers_root: Node3D
var _bands_merged: bool = false
static var _surface_cache: Dictionary = {}
static var _sphere_cache: Dictionary = {}
var _surface_image: Image
var _surface_texture: ImageTexture
var _next_texture_row: int = 0
const TEXTURE_W: int = 1024
const TEXTURE_H: int = 512
const ZONE_CATEGORY := {"R": "residential", "C": "commercial", "I": "industrial"}
const FACILITY_FAMILY := {"hq": "command_center", "power": "power_plant", "water": "water_works", "hospital": "hospital", "fire": "fire_station", "police": "police"}
const ROAD_ERAS := [[9, "future"], [7, "highway"], [5, "asphalt"], [4, "cobble"], [2, "paved"], [1, "dirt"]]

func setup(seed: int) -> void:
	generator = PlanetGenerator.new(seed)
	position = Vector3(48.0, 0.0, 48.0)
	globe = MeshInstance3D.new()
	if _sphere_cache.has(seed):
		_mesh_stream = _sphere_cache[seed] as ArrayMesh
		_next_lat_band = LAT_SEGMENTS
		_bands_merged = true
	else:
		_mesh_stream = ArrayMesh.new()
	globe.mesh = _mesh_stream
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/realism/planet.gdshader")
	if _surface_cache.has(seed):
		_surface_texture = _surface_cache[seed] as ImageTexture
		_next_texture_row = TEXTURE_H
	else:
		_surface_image = Image.create(TEXTURE_W, TEXTURE_H, false, Image.FORMAT_RGB8)
		_surface_image.fill(Color("183c52"))
		_surface_texture = ImageTexture.create_from_image(_surface_image)
	material.set_shader_parameter("surface_texture", _surface_texture)
	globe.material_override = material
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(globe)
	var halo := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS * 1.014
	sphere.height = RADIUS * 2.028
	sphere.radial_segments = 32
	sphere.rings = 16
	halo.mesh = sphere
	var atm := ShaderMaterial.new()
	atm.shader = preload("res://game/realism/atmosphere.gdshader")
	halo.material_override = atm
	add_child(halo)
	var clouds := MeshInstance3D.new()
	clouds.name = "CloudLayer"
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = RADIUS * 1.025
	cloud_mesh.height = RADIUS * 2.05
	cloud_mesh.radial_segments = 72
	cloud_mesh.rings = 36
	clouds.mesh = cloud_mesh
	var cloud_material := ShaderMaterial.new()
	cloud_material.shader = preload("res://game/realism/clouds.gdshader")
	clouds.material_override = cloud_material
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	globe.add_child(clouds)
	marker = MeshInstance3D.new()
	var sphere_marker := SphereMesh.new()
	sphere_marker.radius = 0.65
	sphere_marker.height = 1.30
	marker.mesh = sphere_marker
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.77, 0.19)
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_mat
	globe.add_child(marker)
	select(0.0, 0.0)

func _process(_delta: float) -> void:
	# Deux bandes par frame : aucun calcul intensif lors du changement de caméra.
	for _k in 2:
		if _next_lat_band >= LAT_SEGMENTS:
			break
		_build_band(_next_lat_band)
		_next_lat_band += 1
	# Couleur indépendante des triangles : quatre lignes de texture par image, sans pic d'import.
	for _row in 4:
		if _next_texture_row >= TEXTURE_H:
			break
		var lat: float = (float(_next_texture_row) + 0.5) / float(TEXTURE_H) * PI - PI * 0.5
		for x in TEXTURE_W:
			var lon: float = (float(x) + 0.5) / float(TEXTURE_W) * TAU - PI
			_surface_image.set_pixel(x, _next_texture_row, generator.color_at(lon, lat))
		_next_texture_row += 1
	if _surface_image != null:
		_surface_texture.update(_surface_image)
	if _next_lat_band >= LAT_SEGMENTS:
		if not _bands_merged:
			var stream := SurfaceTool.new()
			stream.begin(Mesh.PRIMITIVE_TRIANGLES)
			for surface in _mesh_stream.get_surface_count():
				stream.append_from(_mesh_stream, surface, Transform3D.IDENTITY)
			_mesh_stream = stream.commit()
			globe.mesh = _mesh_stream
			_bands_merged = true
		if _next_texture_row >= TEXTURE_H:
			if _surface_cache.size() >= 3 and not _surface_cache.has(generator.seed):
				_surface_cache.erase(_surface_cache.keys()[0])
			if _sphere_cache.size() >= 3 and not _sphere_cache.has(generator.seed):
				_sphere_cache.erase(_sphere_cache.keys()[0])
			_surface_cache[generator.seed] = _surface_texture
			_sphere_cache[generator.seed] = _mesh_stream
			set_process(false)

func _build_band(j: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lat0: float = -PI * 0.5 + float(j) / float(LAT_SEGMENTS) * PI
	var lat1: float = -PI * 0.5 + float(j + 1) / float(LAT_SEGMENTS) * PI
	for i in LON_SEGMENTS:
		var lon0: float = -PI + float(i) / float(LON_SEGMENTS) * TAU
		var lon1: float = -PI + float(i + 1) / float(LON_SEGMENTS) * TAU
		# Un maillage indexé n'est pas nécessaire à cette résolution mobile.
		for ll in [Vector2(lon0, lat0), Vector2(lon1, lat1), Vector2(lon0, lat1), Vector2(lon0, lat0), Vector2(lon1, lat0), Vector2(lon1, lat1)]:
			var info: Dictionary = generator.sample(ll.x, ll.y)
			var p: Vector3 = PlanetGenerator.sphere_direction(ll.x, ll.y)
			var rad: float = RADIUS + maxf(0.0, float(info["height"])) * 0.55
			st.set_normal(p)
			st.set_color(generator.color_at(ll.x, ll.y))
			st.set_uv(Vector2((ll.x + PI) / TAU, (ll.y + PI * 0.5) / PI))
			st.add_vertex(p * rad)
	_mesh_stream.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())

func select(lon: float, lat: float) -> void:
	selected_lon = wrapf(lon, -PI, PI)
	selected_lat = clampf(lat, -PI * 0.5, PI * 0.5)
	if marker != null:
		marker.position = PlanetGenerator.sphere_direction(selected_lon, selected_lat) * (RADIUS + 1.05)

func drag_rotate(rel: Vector2) -> void:
	globe.rotate_y(-rel.x * 0.0055)
	globe.rotate_object_local(Vector3.RIGHT, -rel.y * 0.003)

func pick(camera: Camera3D, screen_pos: Vector2) -> Dictionary:
	if globe == null or camera == null:
		return {"hit": false}
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var to_center: Vector3 = origin - global_position
	var b: float = to_center.dot(direction)
	var c: float = to_center.length_squared() - RADIUS * RADIUS
	var discr: float = b * b - c
	if discr < 0.0:
		return {"hit": false}
	var t: float = -b - sqrt(discr)
	if t < 0.0:
		return {"hit": false}
	var hit_global: Vector3 = origin + direction * t
	var local: Vector3 = globe.to_local(hit_global).normalized()
	var lon: float = atan2(local.z, local.x)
	var lat: float = asin(clampf(local.y, -1.0, 1.0))
	select(lon, lat)
	var sample_data: Dictionary = generator.sample(lon, lat)
	return {"hit": true, "lon": lon, "lat": lat, "biome": int(sample_data["biome"]), "height": float(sample_data["height"])}

# ------------------------------------------------------------------ J13.2 : districts en 3D sur le globe
func bind_campaign(c: StarCampaign, team: int) -> void:
	## La vue relit l'état de la colonie par minuterie ; elle ne décide rien et n'écrit rien.
	_campaign = c
	_team = team
	var timer := Timer.new()
	timer.wait_time = 0.7
	timer.autostart = true
	timer.timeout.connect(func(): show_districts(_campaign, _team, _campaign.active))
	add_child(timer)
	show_districts(c, team, c.active)

func _surface_frame(lon: float, lat: float) -> Transform3D:
	var up: Vector3 = PlanetGenerator.sphere_direction(lon, lat)
	var east: Vector3 = Vector3.UP.cross(up)
	east = Vector3.RIGHT if east.length() < 0.001 else east.normalized()
	var height: float = maxf(0.0, float(generator.sample(lon, lat)["height"])) * 0.55
	return Transform3D(Basis(east, up, east.cross(up)), up * (RADIUS + height + 0.03))

static func district_asset(kind: String, age: int, sea: bool) -> String:
	## Modèle d'un district : zone R/C/I de l'âge local, équipement, ou route de l'époque (pont sur l'océan).
	if ZONE_CATEGORY.has(kind):
		return AssetLibrary.find("building_" + String(ZONE_CATEGORY[kind]), String(ZONE_CATEGORY[kind]), age)
	if FACILITY_FAMILY.has(kind):
		return AssetLibrary.find("building_special", String(FACILITY_FAMILY[kind]), age)
	for era in ROAD_ERAS:
		if age >= int(era[0]):
			return "road.%s.%s" % [String(era[1]), "bridge" if sea else "straight"]
	return ""

func show_districts(c: StarCampaign, team: int, body: String) -> int:
	## Reconstruit l'affichage seulement quand la colonie a changé. Renvoie le nombre de districts affichés.
	if c == null or globe == null:
		return 0
	var p: Dictionary = c.planets.colony(team, body)
	var age: int = c.planets.local_age(c, team, body) if not p.is_empty() else 0
	var signature: String = body + ":" + str(team) + ":" + str(age) + ":" + overlay_mode
	var coverage: Dictionary = {}
	if not overlay_mode in ["zones", "none"] and not p.is_empty():
		if overlay_mode in ["power", "water"]:
			coverage = c.planets.utilities(p, c.planets.connected(p)).get(overlay_mode, {}) as Dictionary
		else:
			var report: Dictionary = c.planets.service_report(p).get(overlay_mode, {}) as Dictionary
			var missing: Dictionary = report.get("uncovered", {}) as Dictionary
			var net: Dictionary = c.planets.connected(p)
			for raw_id in (p.get("cells", {}) as Dictionary):
				if net.has(raw_id) and not missing.has(raw_id):
					coverage[raw_id] = true
		signature += ":" + str(coverage.keys())
	var cells: Dictionary = p.get("cells", {}) as Dictionary
	var ids: Array = cells.keys()
	ids.sort()
	for raw in ids:
		var cell: Dictionary = cells[raw] as Dictionary
		signature += "|%d%s%d%s" % [int(raw), PlanetCampaign.cell_kind(cell), int(cell["density"]), "x" if bool(cell["cut"]) else ""]
	if signature == _district_signature and districts_root != null:
		return district_nodes.size()
	_district_signature = signature
	if districts_root != null:
		globe.remove_child(districts_root)
		districts_root.queue_free()
	districts_root = Node3D.new()
	districts_root.name = "districts"
	globe.add_child(districts_root)
	district_nodes.clear()
	district_markers.clear()
	if _markers_root != null:
		globe.remove_child(_markers_root)
		_markers_root.queue_free()
	_markers_root = Node3D.new()
	_markers_root.name = "DistrictOverlays"
	globe.add_child(_markers_root)
	var batches: Dictionary = {}
	if p.is_empty():
		return 0
	var mask: PackedByteArray = PlanetCampaign.land_mask(c.planets._body_seed(c, body))
	for raw in ids:
		var id: int = int(raw)
		var cell: Dictionary = cells[raw] as Dictionary
		var kind: String = PlanetCampaign.cell_kind(cell)
		var asset: String = district_asset(kind, age, mask[id] == J13Rules.LAND_OCEAN)
		if asset.is_empty() or (kind.is_empty() and bool(cell["cut"])):
			continue
		var ll: Vector2 = _district_site(id, mask[id] == J13Rules.LAND_OCEAN and kind.is_empty())
		var frame: Transform3D = _surface_frame(ll.x, ll.y)
		# Un quartier se lit de loin comme un groupe de bâtiments : 3 au niveau 1, un de plus par niveau de densité.
		var copies: int = 2 + maxi(1, int(cell["density"])) if ZONE_CATEGORY.has(kind) else 1
		var footprint: float = 3.4 if kind == "hq" else (2.6 if kind.is_empty() else (1.5 if copies > 1 else 2.8))
		for k in copies:
			# Niveau de détail intermédiaire et couleurs franches des GLB : plus lisible de loin que les textures.
			var node: Node3D = AssetLibrary.instantiate_compact(asset, 1)
			if node == null:
				node = AssetLibrary.instantiate(asset, 1, true)
			if node == null:
				continue
			var offset: Vector3 = Vector3.ZERO
			if copies > 1:
				var angle: float = TAU * float(k) / float(copies) + float(id)
				offset = (frame.basis.x * cos(angle) + frame.basis.z * sin(angle)) * 1.25
			var s: float = AssetLibrary.scale_for_cells(asset, footprint)
			node.transform = Transform3D(frame.basis.rotated(frame.basis.y, float(id % 4) * PI * 0.5).scaled(Vector3(s, s, s)), frame.origin + offset)
			node.name = "district_%d_%d" % [id, k]
			if kind == "hq":
				AssetLibrary.set_team_color(node, Color(0.2, 0.45, 0.95) if team == 0 else Color(0.85, 0.2, 0.18))
			districts_root.add_child(node)
		district_nodes[id] = asset
		if overlay_mode != "none" and not kind.is_empty():
			var color: Color = MobileUI.ZONE_COLORS.get(kind, Color("b9c9d4")) as Color
			if not overlay_mode in ["zones", "none"]:
				color = Color("63d3a2") if coverage.has(id) else Color("f07968")
				if overlay_mode in ["hospital", "fire", "police"] and not kind in ["R", "hq"]:
					color = Color("8897a0")
			var shape: int = 3 if kind == "R" else (4 if kind == "C" else (6 if kind == "I" else 12))
			var batch_key: String = color.to_html() + ":" + str(shape)
			if not batches.has(batch_key):
				batches[batch_key] = {"color": color, "shape": shape, "transforms": []}
			var transforms: Array = (batches[batch_key] as Dictionary)["transforms"] as Array
			transforms.append(Transform3D(frame.basis, frame.origin + frame.basis.y * 0.025))
			district_markers[id] = {"color": color, "kind": kind, "shape": shape}
	for key in batches:
		var batch: Dictionary = batches[key] as Dictionary
		var transforms: Array = batch["transforms"] as Array
		var mesh := TorusMesh.new()
		mesh.inner_radius = 2.48
		mesh.outer_radius = 2.62
		mesh.rings = int(batch["shape"])
		mesh.ring_segments = 3
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = transforms.size()
		for index in transforms.size():
			instances.set_instance_transform(index, transforms[index] as Transform3D)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = instances
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_color = batch["color"] as Color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.roughness = 1.0
		mi.material_override = material
		_markers_root.add_child(mi)
	return district_nodes.size()

func set_overlay(mode_name: String) -> void:
	if not mode_name in ["zones", "power", "water", "hospital", "fire", "police", "none"]:
		return
	overlay_mode = mode_name
	_district_signature = ""
	if _campaign != null:
		show_districts(_campaign, _team, _campaign.active)

func _district_site(id: int, sea: bool) -> Vector2:
	# Placement de rendu à l'intérieur du district : préférer la terre au centre océanique abstrait.
	# Les coordonnées métier, l'emprise, les accès et la simulation restent inchangés.
	var center: Vector2 = PlanetCampaign.district_ll(id)
	if sea:
		return center
	if _district_sites.has(id):
		return _district_sites[id] as Vector2
	var best: Vector2 = center
	var best_cost: float = 99.0
	for dx in [-0.36, -0.18, 0.0, 0.18, 0.36]:
		for dy in [-0.36, -0.18, 0.0, 0.18, 0.36]:
			var location := Vector2(wrapf(center.x + float(dx) * TAU / 12.0, -PI, PI),
				asin(clampf(sin(center.y) + float(dy) * 2.0 / 6.0, -1.0, 1.0)))
			var cost: float = float(dx) * float(dx) + float(dy) * float(dy)
			if int(generator.sample(location.x, location.y)["biome"]) != PlanetGenerator.OCEAN and cost < best_cost:
				best = location
				best_cost = cost
	_district_sites[id] = best
	return best
