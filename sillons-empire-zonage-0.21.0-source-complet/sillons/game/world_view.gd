class_name WorldView
extends Node3D
## Références statiques : indispensables pour inclure les PNG dans l'export APK.
const GRASS_TEX = preload("res://game/realism/textures/grass_albedo.jpg")
const SOIL_TEX = preload("res://game/realism/textures/soil_albedo.jpg")
const SAND_TEX = preload("res://game/realism/textures/sand_albedo.jpg")
const ROCK_TEX = preload("res://game/realism/textures/stone_albedo.jpg")
const NORMAL_TEX = preload("res://game/realism/textures/grass_normal.jpg")
## Rendu 3D synchronisé sur la simulation (lecture seule de SimWorld).
## Interpole les positions entre deux ticks, applique le brouillard du camp observé.

var world: SimWorld
var observer := 0
var _network_node: MeshInstance3D
var _network_tick: int = -100
var unit_nodes := {}
var building_nodes := {}
var ghost_nodes := {}          # bâtiments ennemis mémorisés hors de vue
var fog_image: Image
var fog_tex: ImageTexture
var terrain_mat: ShaderMaterial
var terrain_streamer: TerrainChunkStreamer
var water_mat: ShaderMaterial
var ground_mask_tex: ImageTexture
var contact_tex: ImageTexture
var decor_sectors: Dictionary = {}
var decor_cells := {}              # kind -> Array[Vector2i], rendu décoratif seulement
var decor_meshes := {}             # kind -> MultiMeshInstance3D
var node_mm := {}              # kind -> MultiMeshInstance3D (plusieurs pour les arbres)
var node_index := {}           # kind -> Array d'ids de gisements
var _fog_timer := 0.0
var _visual_clock: float = 0.0
var _nodes_timer := 0.0
var selection_ids := {}        # id -> true
var _rings := []
var _ring_mat: StandardMaterial3D
var _ring_sel_mat: StandardMaterial3D
var _hp_mat_bg: StandardMaterial3D
var markers := []
var sector_ring: MeshInstance3D
var squad_labels := {}
var fx := []
const MAX_VISUAL_RIGS := 56
const MAX_VISUAL_FX := 72
const MAX_DETAILED_BUILDINGS := 48
var _detail_building_count: int = 0
var _detail_rig_count: int = 0
var _camera_zoom: float = 26.0
var _camera_focus := Vector2(48.0, 48.0)
var _last_build_tick: int = -1
var _last_build_count: int = -1
var _lod_dirty: bool = true
var _model_swaps: int = 0
var _far_pending: Dictionary = {}
var _far_batches: Dictionary = {}
var _far_meshes: Dictionary = {}
var _far_frame: int = 0
var _batched_units: int = 0
const MAX_FAR_BATCHES: int = 128
var _visual_quality: int = 2 # 0 économie, 1 équilibrée, 2 qualité

func setup(p_world: SimWorld, p_observer: int) -> void:
	world = p_world
	observer = p_observer
	fog_image = Image.create(world.map_size, world.map_size, false, Image.FORMAT_R8)
	fog_tex = ImageTexture.create_from_image(fog_image)
	_build_terrain()
	_build_nodes()
	_build_ground_details()
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(0.4, 1.0, 0.45)
	_ring_sel_mat = StandardMaterial3D.new()
	_ring_sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_sel_mat.albedo_color = Color(1.0, 0.85, 0.2)
	sector_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.96
	tm.outer_radius = 1.0
	tm.rings = 64
	tm.ring_segments = 3
	sector_ring.mesh = tm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.3, 0.75, 1.0, 0.8)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sector_ring.material_override = sm
	sector_ring.visible = false
	add_child(sector_ring)
	update_fog_texture()
	_refresh_nodes()

func _build_terrain() -> void:
	var ground := MeshInstance3D.new()
	# Flat tactical ground receives canopy/building shadows but never shadows itself.
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not bool(world.rules.get("planet_j9", false)) and world.map_size == 96:
		var res: Array = Assets.build_terrain(world)
		ground.mesh = res[0]
	ground_mask_tex = _make_ground_mask()
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = preload("res://game/realism/terrain.gdshader")
	terrain_mat.set_shader_parameter("fog_tex", fog_tex)
	terrain_mat.set_shader_parameter("ground_mask", ground_mask_tex)
	terrain_mat.set_shader_parameter("map_size", float(world.map_size))
	_setup_urban_layers()
	terrain_mat.set_shader_parameter("grass_tex", GRASS_TEX)
	terrain_mat.set_shader_parameter("soil_tex", SOIL_TEX)
	terrain_mat.set_shader_parameter("sand_tex", SAND_TEX)
	terrain_mat.set_shader_parameter("rock_tex", ROCK_TEX)
	terrain_mat.set_shader_parameter("normal_tex", NORMAL_TEX)
	for name in ["grass", "soil", "sand", "rock"]:
		var source: String = "stone" if name == "rock" else name
		terrain_mat.set_shader_parameter(name + "_orm", RealismAssets.texture(source, "orm"))
		if name != "grass":
			terrain_mat.set_shader_parameter(name + "_normal", RealismAssets.texture(source, "normal"))
	contact_tex = _make_contact_mask()
	terrain_mat.set_shader_parameter("contact_tex", contact_tex)
	if bool(world.rules.get("planet_j9", false)):
		var generator := PlanetGenerator.new(int(world.rules.get("planet_master_seed", world.seed_value)))
		var p: Dictionary = generator.sample(float(world.rules.get("planet_lon", 0.0)), float(world.rules.get("planet_lat", 0.0)))
		var biome: int = int(p["biome"])
		var tint: Color = Color(1.0, 1.0, 1.0)
		match biome:
			PlanetGenerator.COAST: tint = Color(1.0, 0.98, 0.81)
			PlanetGenerator.FOREST: tint = Color(0.78, 0.97, 0.77)
			PlanetGenerator.DESERT: tint = Color(1.15, 0.98, 0.70)
			PlanetGenerator.TUNDRA: tint = Color(0.82, 0.93, 1.05)
			PlanetGenerator.MOUNTAIN: tint = Color(0.91, 0.92, 0.98)
		terrain_mat.set_shader_parameter("biome_tint", Vector3(tint.r, tint.g, tint.b))
	if bool(world.rules.get("planet_j9", false)) or world.map_size > 96:
		terrain_streamer = TerrainChunkStreamer.new()
		add_child(terrain_streamer)
		terrain_streamer.setup(world, terrain_mat)
	else:
		ground.material_override = terrain_mat
		add_child(ground)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(world.map_size, world.map_size)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	water.mesh = pm
	water.position = Vector3(world.map_size * 0.5, -0.18, world.map_size * 0.5)
	water_mat = ShaderMaterial.new()
	water_mat.shader = preload("res://game/realism/water.gdshader")
	water_mat.set_shader_parameter("ripple_normal", RealismAssets.texture("soil", "normal"))
	water_mat.set_shader_parameter("fog_tex", fog_tex)
	water_mat.set_shader_parameter("ground_mask", ground_mask_tex)
	water_mat.set_shader_parameter("map_size", float(world.map_size))
	water.material_override = water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# sol extérieur sombre pour ne pas voir le vide
	var outer := MeshInstance3D.new()
	var om := PlaneMesh.new()
	om.size = Vector2(400, 400)
	outer.mesh = om
	outer.position = Vector3(world.map_size * 0.5, -1.6, world.map_size * 0.5)
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color.BLACK
	omat.disable_fog = true
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer.material_override = omat
	add_child(outer)
	# léger relief : la surface de la carte reste au-dessus du sol extérieur
	ground.position.y = 0.0
	if bool(world.rules.get("planet_j9", false)) or world.map_size > 96:
		ground.free()

func _make_ground_mask() -> ImageTexture:
	## Distance de berge par deux balayages (O(n²)), sans la recherche 9×9 par cellule.
	## Données purement graphiques : aucune modification de la carte de simulation.
	var n: int = world.map_size
	var wet := PackedByteArray()
	var shore := PackedFloat32Array()
	var worn := PackedFloat32Array()
	wet.resize(n * n)
	shore.resize(n * n)
	worn.resize(n * n)
	shore.fill(99.0)
	for i in n * n:
		wet[i] = 1 if int(world.terrain[i]) in [SimWorld.TERRAIN_WATER, SimWorld.TERRAIN_FORD] else 0
	for y in n:
		for x in n:
			var i: int = y * n + x
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var xx: int = x + d.x
				var yy: int = y + d.y
				if xx >= 0 and yy >= 0 and xx < n and yy < n and wet[yy * n + xx] != wet[i]:
					shore[i] = 1.0
	for reverse in [false, true]:
		for yy in n:
			var y: int = n - 1 - yy if reverse else yy
			for xx in n:
				var x: int = n - 1 - xx if reverse else xx
				var i: int = y * n + x
				for step in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]:
					var d: Vector2i = -step if reverse else step
					var px: int = x + d.x
					var py: int = y + d.y
					if px >= 0 and py >= 0 and px < n and py < n:
						shore[i] = minf(shore[i], shore[py * n + px] + (1.4142 if d.x != 0 and d.y != 0 else 1.0))
	for raw in world.buildings.values():
		var building: SimWorld.Building = raw as SimWorld.Building
		if building.team != observer and not world.is_visible_to(observer, building.center):
			continue
		var radius: int = ceili(float(building.size) * 1.2 + 2.0)
		for y in range(maxi(0, int(building.center.y) - radius), mini(n, int(building.center.y) + radius + 1)):
			for x in range(maxi(0, int(building.center.x) - radius), mini(n, int(building.center.x) + radius + 1)):
				var d: float = Vector2(x + 0.5, y + 0.5).distance_to(building.center)
				worn[y * n + x] = maxf(worn[y * n + x], 1.0 - smoothstep(float(building.size) * 0.55, float(radius), d))
	var pixels := PackedByteArray()
	pixels.resize(n * n * 4)
	for y in n:
		for x in n:
			var i: int = y * n + x
			var vein: float = sin(float(x) * 0.39 + float(world.seed_value) * 0.01) * sin(float(y) * 0.31)
			pixels[i * 4] = int(clampf((4.1 - shore[i]) / 3.7, 0.0, 0.95) * 255.0)
			pixels[i * 4 + 1] = int(worn[i] * 255.0) if wet[i] == 0 else 0
			pixels[i * 4 + 2] = int(clampf((vein - 0.78) * 2.4, 0.0, 0.50) * 255.0) if wet[i] == 0 else 0
			pixels[i * 4 + 3] = 255 if int(world.terrain[i]) == SimWorld.TERRAIN_WATER else (128 if wet[i] == 1 else 0)
	return ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, pixels))

func _build_ground_details() -> void:
	## Un seul draw call pour les brins d'herbe, un pour les pierres; pas de
	## collision, pas de Node3D par brin, pas de révélation hors du brouillard.
	var grasses: Array[Vector2i] = []
	var pebbles: Array[Vector2i] = []
	for y in world.map_size:
		for x in world.map_size:
			var c := Vector2i(x, y)
			if int(world.terrain[world.idx(c)]) != SimWorld.TERRAIN_GRASS:
				continue
			if world._occupied.has(c):
				continue
			var key: int = posmod(x * 7381 + y * 19319 + x * y * 31 + world.seed_value * 53, 10007)
			if key % 3 == 0:
				grasses.append(c)
			elif key % 67 == 0:
				pebbles.append(c)
	decor_cells = {"grass": grasses, "pebble": pebbles}
	if world.map_size > 96:
		for kind in decor_cells:
			var sectors: Dictionary = {}
			for cell in decor_cells[kind]:
				var sector: Vector2i = Vector2i(cell.x / 32, cell.y / 32)
				if not sectors.has(sector): sectors[sector] = []
				sectors[sector].append(cell)
			decor_sectors[kind] = sectors
	for kind in ["grass", "pebble"]:
		var mi := MultiMeshInstance3D.new()
		mi.name = "Decor_" + kind
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Assets.grass_detail_mesh() if kind == "grass" else Assets.mesh("rock")
		mm.instance_count = mini(4096, (decor_cells[kind] as Array).size()) if world.map_size > 96 else (decor_cells[kind] as Array).size()
		mm.custom_aabb = AABB(Vector3(0.0, -1.0, 0.0), Vector3(float(world.map_size), 4.0, float(world.map_size)))
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.roughness = 1.0
		m.vertex_color_use_as_albedo = true
		if kind == "grass":
			m.albedo_color = Color(0.52, 0.62, 0.34)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		else:
			m.albedo_color = Color(0.48, 0.46, 0.39)
		mi.material_override = RealismAssets.foliage(fog_tex, ground_mask_tex, true, world.map_size) if kind == "grass" else RealismAssets.material("rock")
		add_child(mi)
		decor_meshes[kind] = mi
	_refresh_ground_details()

func _refresh_ground_details() -> void:
	var fog: PackedByteArray = world.teams[observer].fog
	for kind in decor_cells.keys():
		var ids: Array = decor_cells[kind]
		if world.map_size > 96:
			ids = []
			var center: Vector2i = Vector2i(int(_camera_focus.x) / 32, int(_camera_focus.y) / 32)
			for dy in range(-2, 3):
				for dx in range(-2, 3): ids.append_array(decor_sectors[kind].get(center + Vector2i(dx, dy), []))
		var mm: MultiMesh = (decor_meshes[kind] as MultiMeshInstance3D).multimesh
		var cursor: int = 0
		for i in ids.size():
			var c: Vector2i = ids[i]
			var visible: int = int(fog[world.idx(c)])
			if visible == 0 or world._occupied.has(c) or (kind == "grass" and Vector2(c).distance_squared_to(_camera_focus) > 1156.0):
				if world.map_size == 96: mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
				continue
			var slot: int = cursor if world.map_size > 96 else i
			if slot >= mm.instance_count: break
			cursor += 1
			var n: int = posmod(hash(Vector3i(c.x, c.y, world.seed_value)), 65521)
			var f: float = float(n) / 65521.0
			var size_factor: float = (0.65 + f * 0.65) if kind == "grass" else (0.22 + f * 0.22)
			var b := Basis(Vector3.UP, f * TAU).scaled(Vector3.ONE * size_factor)
			var offset := Vector3(0.16 + f * 0.64, 0.015, 0.20 + float(posmod(n * 191, 65521)) / 65521.0 * 0.64)
			mm.set_instance_transform(slot, Transform3D(b, Vector3(c.x, 0, c.y) + offset))
			var lit: float = 1.0 if visible == 2 else 0.52
			mm.set_instance_color(slot, Color(lit * (0.75 + f * 0.25), lit, lit * 0.77))
		if world.map_size > 96: mm.visible_instance_count = cursor

func _build_nodes() -> void:
	var kinds := {"arbre": [], "baies": [], "minerai": []}
	for n in world.nodes.values():
		kinds[n.kind].append(n.id)
	for kind in kinds.keys():
		node_index[kind] = kinds[kind]
		var parts: Array = RealismAssets.resource_parts(kind)
		var mms := []
		for p in parts:
			var mmi := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = p[0] as Mesh
			mm.instance_count = kinds[kind].size()
			mmi.multimesh = mm
			var m: StandardMaterial3D = (p[1] as StandardMaterial3D).duplicate()
			m.vertex_color_use_as_albedo = true
			mmi.material_override = RealismAssets.foliage(fog_tex, ground_mask_tex, false, world.map_size) if m.resource_name == "realism_leaf" else m
			mmi.set_meta("variant", int(p[3]))
			mmi.set_meta("variants", int(p[4]))
			mmi.set_meta("offset", p[2])
			mmi.set_meta("stump", m.resource_name == "realism_bark")
			add_child(mmi)
			mms.append(mmi)
		node_mm[kind] = mms

func _refresh_nodes() -> void:
	# Compact only the observed instances: hidden trees consume neither triangles nor shadow passes.
	var fog: PackedByteArray = world.teams[observer].fog
	for kind in node_index:
		var ids: Array = node_index[kind] as Array
		for raw_mmi in node_mm[kind]:
			var mmi: MultiMeshInstance3D = raw_mmi as MultiMeshInstance3D
			var mm: MultiMesh = mmi.multimesh
			var cursor: int = 0
			for raw_id in ids:
				var resource: SimWorld.ResNode = world.nodes.get(raw_id) as SimWorld.ResNode
				if resource == null or fog[world.idx(resource.cell)] == 0 or (world.map_size > 96 and resource.pos.distance_squared_to(_camera_focus) > 10000.0):
					continue
				if posmod(resource.id, int(mmi.get_meta("variants", 1))) != int(mmi.get_meta("variant", 0)):
					continue
				var fraction: float = clampf(resource.amount / resource.max_amount, 0.0, 1.0)
				var variation: float = float(posmod(resource.id * 7919, 100)) / 100.0
				var size_factor: float = 0.85 + variation * 0.40 if kind == "arbre" else 0.55 + 0.6 * fraction
				var basis := Basis(Vector3.UP, variation * TAU).scaled(Vector3.ONE * size_factor)
				if resource.amount <= 0.0:
					if kind != "arbre" or not bool(mmi.get_meta("stump", false)):
						continue
					basis = Basis(Vector3.UP, variation * TAU).scaled(Vector3(1.1, 0.08, 1.1))
				mm.set_instance_transform(cursor, Transform3D(basis, Vector3(resource.pos.x, 0, resource.pos.y)))
				var brightness: float = 1.0 if fog[world.idx(resource.cell)] == 2 else 0.55
				mm.set_instance_color(cursor, Color(brightness, brightness, brightness))
				cursor += 1
			mm.visible_instance_count = cursor

func set_visual_lod(camera_distance: float, camera_focus: Vector2 = Vector2(48.0, 48.0)) -> void:
	## Zoom ET distance au centre de la vue : aucune unité hors écran n'est raffinée.
	if absf(_camera_zoom - camera_distance) > 0.35 or _camera_focus.distance_squared_to(camera_focus) > 0.5:
		_lod_dirty = true
	_camera_zoom = camera_distance
	_camera_focus = camera_focus
	if terrain_streamer != null:
		terrain_streamer.update_focus(camera_focus, camera_distance)
	var show_details: bool = camera_distance < (46.0 if _visual_quality > 0 else 31.0)
	for mesh in decor_meshes.values():
		(mesh as MultiMeshInstance3D).visible = show_details

func set_visual_quality(level: int) -> void:
	_visual_quality = clampi(level, 0, 2)
	_lod_dirty = true
	set_visual_lod(_camera_zoom, _camera_focus)

func visual_stats() -> Dictionary:
	var stats: Dictionary = {"rigs": _detail_rig_count, "rigs_limit": MAX_VISUAL_RIGS, "buildings": _detail_building_count,
		"effects": fx.size(), "quality": _visual_quality, "batched_units": _batched_units, "batches": _far_pending.size()}
	if terrain_streamer != null:
		stats["chunks"] = terrain_streamer.stats()
	return stats

func update_fog_texture() -> void:
	var fog: PackedByteArray = world.teams[observer].fog
	var data := PackedByteArray()
	data.resize(fog.size())
	for i in fog.size():
		data[i] = 255 if fog[i] == 2 else (110 if fog[i] == 1 else 0)
	fog_image.set_data(world.map_size, world.map_size, false, Image.FORMAT_R8, data)
	fog_tex.update(fog_image)

func world_pos(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)

func sync(alpha: float, delta: float) -> void:
	if world.tick - _network_tick >= 10:
		_sync_network()
	_visual_clock += maxf(0.0, delta)
	_fog_timer += delta
	_nodes_timer += delta
	if _fog_timer > 0.25:
		_fog_timer = 0.0
		update_fog_texture()
		refresh_urban_layers()
	elif delta <= 0.0:
		# Partie en pause : les routes et le zonage peints restent visibles tout de suite (comparaison de compteurs, coût nul).
		refresh_urban_layers()
	if _nodes_timer > 1.0:
		_nodes_timer = 0.0
		_refresh_nodes()
		_refresh_ground_details()
	_model_swaps = 0
	_far_pending.clear()
	_batched_units = 0
	_far_frame += 1
	_sync_units(alpha, delta)
	_flush_far_batches()
	if _last_build_tick != world.tick or _last_build_count != world.buildings.size() or _lod_dirty:
		_sync_buildings()
		_last_build_tick = world.tick
		_last_build_count = world.buildings.size()
		_lod_dirty = false
	_sync_selection(alpha)
	_sync_fx(delta)

func _sync_units(alpha: float, delta: float) -> void:
	var seen := {}
	_detail_rig_count = 0
	for u in world.units.values():
		var vis = u.team == observer or world.is_visible_to(observer, u.pos)
		if not vis or u.garrison_id != -1:
			continue
		seen[u.id] = true
		var node: Node3D = unit_nodes.get(u.id)
		var close_limit: int = 12 if _visual_quality == 0 else (24 if _visual_quality == 1 else 40)
		var close_enough: bool = _visual_quality > 0 and _camera_zoom < (45.0 if node != null and int(node.get_meta("library_lod", 1)) == 0 else 38.0) and u.pos.distance_squared_to(_camera_focus) < 900.0
		var wanted_lod: int = 0 if close_enough and _detail_rig_count < close_limit else 1
		var local_age: int = int(world.teams[u.team].age)
		if node != null and node.has_meta("library_asset") and (int(node.get_meta("library_age", local_age)) != local_age or int(node.get_meta("library_lod", 1)) != wanted_lod):
			if wanted_lod == 1 or _model_swaps < 4:
				var replacement: Node3D = TacticalModels.unit(u.type, u.team, local_age, wanted_lod)
				if replacement != null:
					node.queue_free()
					node = null
					unit_nodes[u.id] = replacement
					add_child(replacement)
					replacement.set_meta("facing", -u.facing + PI / 2)
					node = replacement
					_model_swaps += 1
		if node == null:
			node = TacticalModels.unit(u.type, u.team, local_age, wanted_lod if _model_swaps < 4 else 1)
			if node == null:
				node = Assets.build_unit(u.type, u.team)
			_model_swaps += 1
			add_child(node)
			unit_nodes[u.id] = node
			node.set_meta("facing", u.facing)
		if node.has_meta("library_asset"):
			if int(node.get_meta("library_lod", 1)) == 0:
				_detail_rig_count += 1
				TechAppearance.decorate(node.get_node("Body") as Node3D, u.evolution, Vector3(0.0, 1.03, 0.08), 0.45)
			var point: Vector2 = u.prev_pos.lerp(u.pos, alpha)
			node.position = world_pos(point, 2.8 if Rules.unit_has(u.type, "air") else _ground_y(point))
			var facing: float = float(node.get_meta("facing", 0.0))
			facing = lerp_angle(facing, -u.facing + PI / 2, 1.0 - exp(-14.0 * maxf(delta, 0.001)))
			node.set_meta("facing", facing)
			node.rotation.y = facing
			TacticalModels.animate(node, u.prev_pos.distance_squared_to(u.pos) > 0.0001, world.tick - u.attacking_tick < 3,
				u.state == "gather" or u.state == "build", u.prev_pos.distance_to(u.pos) / Rules.DT * GameConfig.sim_speed, delta > 0.0)
			if int(node.get_meta("library_lod", 1)) > 0:
				_queue_far_unit(node, u.team)
			continue
		# Le plafond protège les scènes de 200–400 unités : représentation détaillée
		# seulement près du cadrage, le modèle d'origine reste disponible en LOD.
		var in_detail_zone: bool = _camera_zoom < 43.0 and u.pos.distance_to(_camera_focus) < 29.0
		if _visual_quality > 0 and in_detail_zone and _detail_rig_count < (24 if _visual_quality == 1 else MAX_VISUAL_RIGS):
			if not bool(node.get_meta("detail_created", false)) and u.type != "caravane":
				UnitVisual.enhance(node, u.type, u.team)
				if node.get_node_or_null("Body/Figure/Rig") != null or node.get_node_or_null("Body/Crew/Rig") != null:
					_detail_rig_count += 1
					node.set_meta("detail_created", true)
		if bool(node.get_meta("detail_created", false)):
			UnitVisual.set_lod(node, in_detail_zone and _visual_quality > 0)
			if in_detail_zone:
				UnitVisual.set_evolution(node, u.evolution)
		var p: Vector2 = u.prev_pos.lerp(u.pos, alpha)
		node.position = world_pos(p, 2.8 if Rules.unit_has(u.type, "air") else _ground_y(p))
		var f: float = node.get_meta("facing")
		f = lerp_angle(f, -u.facing + PI / 2, 0.25)
		node.set_meta("facing", f)
		node.rotation.y = f
		var body: Node3D = node.get_node("Body")
		var moving: bool = u.prev_pos.distance_squared_to(u.pos) > 0.0001
		var t: float = _visual_clock
		var speed_now: float = clampf(u.prev_pos.distance_to(u.pos) / Rules.DT, 0.0, 8.0) if moving else 0.0
		var gait: float = float(node.get_meta("gait_phase", 0.0))
		if moving:
			gait += speed_now * maxf(0.0, delta) * (4.3 if Rules.unit_has(u.type, "cavalry") else 3.5)
			node.set_meta("gait_phase", fmod(gait, TAU))
		if bool(node.get_meta("detail_created", false)) and in_detail_zone:
			UnitVisual.animate(node, u.type, u.id, moving,
				world.tick - u.attacking_tick < 3, u.state == "gather" or u.state == "build", gait, t)
		body.position.y = absf(sin(gait + float(u.id) * 1.17)) * 0.055 if moving else 0.0
		var weapon := body.get_node_or_null("Figure/Weapon")
		if weapon:
			var since = world.tick - u.attacking_tick
			weapon.rotation.x = -1.1 * (1.0 - float(since) / 4.0) if since < 4 else 0.0
			if u.state == "gather" or u.state == "build":
				weapon.rotation.x = -0.9 * absf(sin(t * 5.0 + u.id))
		var barrel := body.get_node_or_null("Barrel")
		if barrel:
			# fût relevé pendant la mise en batterie, recul au tir
			var setup_t: float = float(Rules.UNITS[u.type].get("setup", 1.0))
			var k := clampf(u.deploy / maxf(0.1, setup_t), 0.0, 1.0)
			barrel.rotation.x = -0.32 * k
			var since_shot = world.tick - u.attacking_tick
			barrel.position.z = 0.05 - (0.18 * (1.0 - float(since_shot) / 5.0) if since_shot < 5 else 0.0)
		var carry := body.get_node_or_null("Figure/Carry")
		if carry:
			carry.visible = u.carry_amt > 0.5
		# éclat de dégât
		var hit = world.tick - u.hit_tick < 2
		node.scale = Vector3.ONE * Assets.UNIT_SCALE * (1.08 if hit else 1.0)
	for id in unit_nodes.keys():
		if not seen.has(id):
			var removed: Node3D = unit_nodes[id] as Node3D
			if not world.units.has(id) and _visual_quality > 0 and world.is_visible_to(observer, Vector2(removed.position.x, removed.position.z)):
				_spawn_death_fx(removed.position)
			if bool(removed.get_meta("detail_created", false)):
				_detail_rig_count = maxi(0, _detail_rig_count - 1)
			removed.queue_free()
			unit_nodes.erase(id)

func _queue_far_unit(node: Node3D, team: int) -> void:
	## Lots de 16×16 cases : le frustum peut éliminer une région, sans révéler les unités cachées.
	var visual: Node3D = node.get_node("Body/LibraryModel") as Node3D
	if visual.get_child_count() != 1 or not visual.get_child(0) is MeshInstance3D:
		return
	var mesh_node: MeshInstance3D = visual.get_child(0) as MeshInstance3D
	var chunk := Vector2i(floori(node.position.x / 16.0), floori(node.position.z / 16.0))
	var material_key: String = String(node.get_meta("library_asset")) + ":" + str(team)
	var key: String = material_key + ":" + str(chunk.x) + ":" + str(chunk.y)
	if not _far_pending.has(key):
		if _far_pending.size() >= MAX_FAR_BATCHES:
			mesh_node.visible = true # Repli complet, aucune unité supprimée pour tenir un budget graphique.
			return
		_far_pending[key] = {"template": mesh_node, "material_key": material_key, "chunk": chunk, "transforms": []}
	var bucket: Dictionary = _far_pending[key] as Dictionary
	(bucket["transforms"] as Array).append(node.transform * (node.get_node("Body") as Node3D).transform * visual.transform * mesh_node.transform)
	mesh_node.visible = false
	_batched_units += 1

func _flush_far_batches() -> void:
	for key in _far_pending:
		var bucket: Dictionary = _far_pending[key] as Dictionary
		var batch: MultiMeshInstance3D = _far_batches.get(key) as MultiMeshInstance3D
		if batch == null:
			if _far_batches.size() >= MAX_FAR_BATCHES:
				for stale in _far_batches.keys():
					if not _far_pending.has(stale):
						(_far_batches[stale] as MultiMeshInstance3D).queue_free()
						_far_batches.erase(stale)
						break
			var material_key: String = String(bucket["material_key"])
			var mesh: ArrayMesh = _far_meshes.get(material_key) as ArrayMesh
			if mesh == null:
				var template: MeshInstance3D = bucket["template"] as MeshInstance3D
				mesh = template.mesh.duplicate() as ArrayMesh
				for surface in mesh.get_surface_count():
					mesh.surface_set_material(surface, template.get_active_material(surface))
				if _far_meshes.size() >= MAX_FAR_BATCHES:
					_far_meshes.erase(_far_meshes.keys()[0])
				_far_meshes[material_key] = mesh
			batch = MultiMeshInstance3D.new()
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.mesh = mesh
			var chunk: Vector2i = bucket["chunk"] as Vector2i
			batch.multimesh.custom_aabb = AABB(Vector3(chunk.x * 16 - 3, -2, chunk.y * 16 - 3), Vector3(22, 14, 22))
			add_child(batch)
			_far_batches[key] = batch
		var transforms: Array = bucket["transforms"] as Array
		var mm: MultiMesh = batch.multimesh
		if mm.instance_count < transforms.size():
			mm.instance_count = maxi(transforms.size(), mm.instance_count * 2)
		mm.visible_instance_count = transforms.size()
		for index in transforms.size():
			mm.set_instance_transform(index, transforms[index] as Transform3D)
		batch.visible = true
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _visual_quality == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		batch.set_meta("used_frame", _far_frame)
	for key in _far_batches.keys():
		if not _far_pending.has(key):
			var unused: MultiMeshInstance3D = _far_batches[key] as MultiMeshInstance3D
			unused.visible = false
			if _far_frame - int(unused.get_meta("used_frame", 0)) > 120:
				unused.queue_free()
				_far_batches.erase(key)

func _ground_y(p: Vector2) -> float:
	var c := world.cell_of(p)
	var t := world.terrain[world.idx(c)]
	return -0.3 if t == SimWorld.TERRAIN_FORD else 0.0

func _sync_buildings() -> void:
	if _last_build_count != world.buildings.size() and ground_mask_tex != null:
		ground_mask_tex.update(_make_ground_mask().get_image())
	var seen := {}
	var mem: Dictionary = world.teams[observer].memory
	for b in world.buildings.values():
		var known = b.team == observer or world.is_visible_to(observer, b.center) or mem.has(b.id)
		if not known:
			continue
		seen[b.id] = true
		var node: Node3D = building_nodes.get(b.id)
		var urban_kind: bool = UrbanRules.is_zone(b.type) or b.type == "ruine"
		if node == null:
			node = Node3D.new()
			var model: Node3D = UrbanVisual.build(b) if urban_kind else TacticalModels.building(b.type, b.team, b.size, int(world.teams[b.team].age))
			if model == null:
				model = Assets.build_building(b.type, b.team, b.size)
			if urban_kind:
				node.set_meta("urban_sig", UrbanVisual.signature(b))
			node.set_meta("model_age", int(world.teams[b.team].age))
			node.set_meta("model_kind", b.type)
			model.name = "Model"
			node.add_child(model)
			var scaff := Assets.box(node, Vector3(b.size * 0.95, 0.08, b.size * 0.95), Assets.mat("found", Color(0.5, 0.42, 0.3), 1.0), Vector3(0, 0.04, 0))
			scaff.name = "Foundation"
			node.position = world_pos(b.center)
			if b.team == 1:
				node.rotation.y = PI
			add_child(node)
			building_nodes[b.id] = node
		var model: Node3D = node.get_node("Model")
		# 0.19 : un bâtiment de zone change de silhouette avec son niveau, son âge de construction et son état
		# (transformation progressive : pas de conversion de toute la ville au changement d'âge).
		if urban_kind and (b.team == observer or world.is_visible_to(observer, b.center)) and String(node.get_meta("urban_sig", "")) != UrbanVisual.signature(b):
			var rebuilt: Node3D = UrbanVisual.build(b)
			node.remove_child(model)
			model.queue_free()
			rebuilt.name = "Model"
			node.add_child(rebuilt)
			model = rebuilt
			node.set_meta("urban_sig", UrbanVisual.signature(b))
			node.set_meta("model_kind", b.type)
		# Seuls les bâtiments actuellement observés changent de style : pas d'information par le brouillard.
		if not urban_kind and (b.team == observer or world.is_visible_to(observer, b.center)) and (int(node.get_meta("model_age", 0)) != int(world.teams[b.team].age) or String(node.get_meta("model_kind", b.type)) != b.type):
			var evolved: Node3D = TacticalModels.building(b.type, b.team, b.size, int(world.teams[b.team].age))
			if evolved != null:
				node.remove_child(model)
				model.queue_free()
				evolved.name = "Model"
				node.add_child(evolved)
				model = evolved
				node.set_meta("model_age", int(world.teams[b.team].age))
				node.set_meta("model_kind", b.type)
				node.set_meta("detail_created", false)
		var detail_near: bool = _visual_quality > 0 and _camera_zoom < 44.0 and b.center.distance_to(_camera_focus) < 36.0
		if not urban_kind and detail_near and _detail_building_count < (24 if _visual_quality == 1 else MAX_DETAILED_BUILDINGS) and not bool(node.get_meta("detail_created", false)):
			BuildingVisual.enhance(model, b.type, b.team, b.size)
			node.set_meta("detail_created", true)
			_detail_building_count += 1
		if b.team == observer or world.is_visible_to(observer, b.center):
			BuildingVisual.set_damage(model, b.hp / maxf(1.0, b.max_hp))
		BuildingVisual.set_lod(model, detail_near)
		if not urban_kind and detail_near and bool(node.get_meta("detail_created", false)):
			BuildingVisual.set_evolution(model, b.tier)
		var prog: float = b.progress if not b.complete else 1.0
		# 0.19 : la silhouette des zones vient de leur niveau (UrbanVisual) ; un chantier monte avec son avancement.
		model.scale = Vector3(1, max(0.08, prog), 1)
		var seen_now: bool = b.team == observer or world.is_visible_to(observer, b.center)
		var on_fire: bool = float(b.city.get("burning", 0.0)) > 0.0 and seen_now
		var intensity: float = float(b.city.get("fire_i", 1.0))
		var flames: Node3D = node.get_node_or_null("Fire") as Node3D
		var smoke: Node3D = node.get_node_or_null("Smoke") as Node3D
		# Début d'incendie : fumée ; feu déclaré : flammes et fumée ; après : fumée légère sur un bâtiment brûlé.
		var smoking: bool = seen_now and (on_fire or String(b.city.get("state", "")) == "burnt")
		if on_fire and intensity >= 0.35 and flames == null:
			flames = _make_fire(b.size)
			node.add_child(flames)
		if smoking and smoke == null:
			smoke = _make_smoke(b.size)
			node.add_child(smoke)
		if flames != null:
			flames.visible = on_fire and intensity >= 0.35
			if flames.visible:
				var flick: float = 0.85 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.018 + float(b.id))
				flames.scale = Vector3(1.0, flick * clampf(0.6 + intensity * 0.5, 0.6, 1.1), 1.0)
		if smoke != null:
			smoke.visible = smoking
			if smoking:
				var rise: float = fmod(float(Time.get_ticks_msec()) * 0.0004 + float(b.id) * 0.13, 1.0)
				smoke.position.y = rise * 0.6
				smoke.scale = Vector3.ONE * (0.6 + (intensity if on_fire else 0.25) * 0.6)
		node.get_node("Foundation").visible = not b.complete
		var hit = world.tick - b.hit_tick < 2
		model.position.x = (0.04 if hit and world.tick % 2 == 0 else 0.0)
	for id in building_nodes.keys():
		if not seen.has(id):
			var ruins: Node3D = building_nodes[id] as Node3D
			if bool(ruins.get_meta("detail_created", false)):
				_detail_building_count = maxi(0, _detail_building_count - 1)
			if not world.buildings.has(id) and _visual_quality > 0 and fx.size() < MAX_VISUAL_FX - 5 and world.is_visible_to(observer, Vector2(ruins.position.x, ruins.position.z)):
				_spawn_death_fx(ruins.position, 2.5)
				# L'animation de ruine est conservée en scène < 1,4 seconde, sans
				# collision ni bâtiment réintroduit dans la simulation.
				fx.append({"node": ruins, "t": 0.0, "dur": 1.35, "kind": "collapse", "base": ruins.position.y})
			else:
				ruins.queue_free()
			building_nodes.erase(id)

# ---------------------------------------------------------------- 0.19 : routes et calques du zonage

var road_layer_tex: ImageTexture
var zone_layer_tex: ImageTexture
var filter_layer_tex: ImageTexture
var _urban_sig: String = ""
var _zone_sig: String = ""
var overlay_mode: int = 0          # 0 rien, 1 zonage, 2 filtre (valeurs fournies par set_filter_values)

func _setup_urban_layers() -> void:
	var n: int = world.map_size
	road_layer_tex = ImageTexture.create_from_image(Image.create(n, n, false, Image.FORMAT_L8))
	zone_layer_tex = ImageTexture.create_from_image(Image.create(n, n, false, Image.FORMAT_L8))
	filter_layer_tex = ImageTexture.create_from_image(Image.create(n, n, false, Image.FORMAT_L8))
	terrain_mat.set_shader_parameter("road_tex", road_layer_tex)
	terrain_mat.set_shader_parameter("zone_tex", zone_layer_tex)
	terrain_mat.set_shader_parameter("filter_tex", filter_layer_tex)
	var colors: Array = [Color(0, 0, 0, 0)]
	for code in range(1, 9):
		if UrbanZoning.KINDS.has(code):
			var col: Color = (UrbanZoning.KINDS[code] as Dictionary)["color"]
			colors.append(Color(col.r, col.g, col.b, 0.62))
		else:
			colors.append(Color(0, 0, 0, 0))
	terrain_mat.set_shader_parameter("zone_colors", colors)
	terrain_mat.set_shader_parameter("overlay_strength", 0.0)
	terrain_mat.set_shader_parameter("overlay_mode", 0)
	refresh_urban_layers(true)

func _road_color(age: int) -> Color:
	## Chemin de terre, pavés, bitume, revêtement clair des âges avancés.
	if age <= 3:
		return Color(0.47, 0.39, 0.28)
	if age <= 6:
		return Color(0.46, 0.45, 0.43)
	if age <= 8:
		return Color(0.23, 0.24, 0.26)
	return Color(0.62, 0.66, 0.72)

func refresh_urban_layers(force: bool = false) -> void:
	## Met à jour les textures quand les routes ou le zonage changent (rien à faire sinon).
	if road_layer_tex == null:
		return
	var sig: String = ""
	for team in world.teams.size():
		var z: Dictionary = (world.teams[team] as SimWorld.Team).zoning
		sig += "%d:%d," % [int(z.get("road_rev", 0)), int(z.get("rev", 0))]
	if not force and sig == _urban_sig:
		return
	_urban_sig = sig
	var roads: PackedByteArray = UrbanZoning.road_layer(world) if UrbanZoning._any_layers(world) else PackedByteArray()
	var n: int = world.map_size
	if roads.size() == n * n:
		road_layer_tex.update(Image.create_from_data(n, n, false, Image.FORMAT_L8, roads))
		terrain_mat.set_shader_parameter("road_on", 1.0)
		terrain_mat.set_shader_parameter("road_color", _road_color(int(world.teams[observer].age)))
	else:
		terrain_mat.set_shader_parameter("road_on", 0.0)
	if UrbanZoning.has_layers(world, observer):
		zone_layer_tex.update(Image.create_from_data(n, n, false, Image.FORMAT_L8, (world.teams[observer] as SimWorld.Team).zoning["zone"]))

func set_overlay(mode: int) -> void:
	## Calque du zonage ou d'un filtre : visible seulement quand le joueur le demande (pas de couche permanente).
	overlay_mode = mode
	if terrain_mat == null:
		return
	terrain_mat.set_shader_parameter("overlay_mode", mode)
	terrain_mat.set_shader_parameter("overlay_strength", 1.0 if mode > 0 else 0.0)
	refresh_urban_layers(true)

func set_filter_values(values: PackedByteArray) -> void:
	## Valeurs d'un filtre (0 = rien, 1 à 255 = du mieux au pire), une par case.
	if filter_layer_tex == null or values.size() != world.map_size * world.map_size:
		return
	filter_layer_tex.update(Image.create_from_data(world.map_size, world.map_size, false, Image.FORMAT_L8, values))

func _make_smoke(size: int) -> Node3D:
	## Fumée simple (trois sphères grises semi-transparentes, sans particules) : lisible de loin, coût négligeable.
	var root := Node3D.new()
	root.name = "Smoke"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.32, 0.31, 0.30, 0.55)
	for i in 3:
		var puff := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.22 * float(size)
		m.height = 0.44 * float(size)
		m.radial_segments = 8
		m.rings = 4
		puff.mesh = m
		puff.material_override = mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = Vector3((float(i) - 1.0) * 0.2 * float(size), 1.5 * float(size) + 0.35 * float(i), 0.1 * float(i))
		root.add_child(puff)
	return root

func _make_fire(size: int) -> Node3D:
	## Flammes simples (trois cônes émissifs, sans particules ni lumière) : lisibles de loin, coût négligeable.
	var root := Node3D.new()
	root.name = "Fire"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.05)
	for i in 3:
		var cone := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 0.18 * float(size)
		m.height = 0.9 * float(size)
		m.radial_segments = 8
		cone.mesh = m
		cone.material_override = mat
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.position = Vector3((float(i) - 1.0) * 0.28 * float(size), 0.9 * float(size) + 0.3, (0.2 if i == 1 else -0.15) * float(size))
		root.add_child(cone)
	return root

func _sync_selection(alpha: float) -> void:
	var i := 0
	for id in selection_ids.keys():
		var e = world.entity(id)
		if e == null:
			continue
		if i >= _rings.size():
			var r := MeshInstance3D.new()
			r.mesh = Assets.mesh("ring")
			r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(r)
			_rings.append(r)
		var ring: MeshInstance3D = _rings[i]
		ring.visible = true
		ring.material_override = _ring_sel_mat if selection_ids[id] else _ring_mat
		if e is SimWorld.Unit:
			var p: Vector2 = e.prev_pos.lerp(e.pos, alpha)
			ring.position = world_pos(p, 0.05 + _ground_y(p))
			ring.scale = Vector3.ONE * (1.4 if Rules.unit_has(e.type, "cavalry") or e.type == "caravane" else 1.0)
		else:
			ring.position = world_pos(e.center, 0.06)
			ring.scale = Vector3.ONE * e.size * 0.85
		i += 1
	for j in range(i, _rings.size()):
		_rings[j].visible = false
	# secteur de défense délégué
	var army: Dictionary = world.teams[observer].army
	if army.is_empty():
		sector_ring.visible = false
	else:
		sector_ring.visible = true
		sector_ring.position = world_pos(army["pos"], 0.12)
		sector_ring.scale = Vector3(army["radius"], 1, army["radius"])
	# repères d'escouade
	var seen := {}
	for s in world.team_squads(observer):
		var c := world._squad_center(s)
		if c == Vector2.ZERO:
			continue
		seen[s.id] = true
		var l: Label3D = squad_labels.get(s.id)
		if l == null:
			l = Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.font_size = 64
			l.pixel_size = 0.01
			l.outline_size = 12
			l.no_depth_test = true
			add_child(l)
			squad_labels[s.id] = l
		l.text = str(s.number) + ("•" if s.direct else "")
		l.modulate = Color(1, 0.9, 0.3) if s.direct else Color(0.85, 0.95, 1.0)
		l.position = world_pos(c, 2.3)
	for id in squad_labels.keys():
		if not seen.has(id):
			squad_labels[id].queue_free()
			squad_labels.erase(id)

func add_marker(p: Vector2, color: Color) -> void:
	if fx.size() >= MAX_VISUAL_FX:
		return
	var r := MeshInstance3D.new()
	r.mesh = Assets.mesh("ring")
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r.material_override = m
	r.position = world_pos(p, 0.1)
	add_child(r)
	fx.append({"node": r, "t": 0.0, "dur": 0.7, "kind": "marker"})

func _spawn_death_fx(pos: Vector3, scale_f: float = 1.0) -> void:
	if fx.size() >= MAX_VISUAL_FX:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Assets.mesh("rock")
	mi.scale = Vector3.ONE * (0.52 * scale_f)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.4, 0.35, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.3, 0)
	add_child(mi)
	fx.append({"node": mi, "t": 0.0, "dur": 0.8, "kind": "dust", "base_scale": 0.52 * scale_f})

func shot_fx(from: Vector2, to: Vector2, siege: bool = false) -> void:
	if _visual_quality == 0 or fx.size() >= MAX_VISUAL_FX - 4:
		return
	if from.distance_to(_camera_focus) > 42.0 and to.distance_to(_camera_focus) > 42.0:
		return
	if siege:
		_siege_fx(from, to)
		return
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.04, 0.04, 1.0)
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.9, 0.6)
	mi.material_override = m
	var a := world_pos(from, 1.5)
	var c := world_pos(to, 0.6)
	add_child(mi)
	mi.look_at_from_position(a, c, Vector3.UP)
	fx.append({"node": mi, "t": 0.0, "dur": 0.25, "kind": "shot", "a": a, "b": c})

func _siege_fx(from: Vector2, to: Vector2) -> void:
	## Boulet en cloche, fumée à la bouche du canon et poussière à l'impact (lisible de loin).
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 8
	sm.rings = 4
	ball.mesh = sm
	ball.material_override = Assets.mat("iron", Color(0.2, 0.21, 0.22), 0.45, 0.7)
	add_child(ball)
	var a := world_pos(from, 0.9)
	var c := world_pos(to, 0.5)
	var dur := clampf(from.distance_to(to) / 14.0, 0.35, 0.9)
	fx.append({"node": ball, "t": 0.0, "dur": dur, "kind": "ball", "a": a, "b": c, "h": 1.5 + from.distance_to(to) * 0.25})
	var smoke := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.35
	sp.height = 0.7
	sp.radial_segments = 8
	sp.rings = 4
	smoke.mesh = sp
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.85, 0.82, 0.45)
	smoke.material_override = m
	smoke.position = a + (c - a).normalized() * 0.7
	add_child(smoke)
	fx.append({"node": smoke, "t": 0.0, "dur": 0.8, "kind": "dust"})

func _siege_impact(pos: Vector3) -> void:
	## Éclats et onde de choc bornés. Aucun dégât physique supplémentaire.
	if _visual_quality == 0 or fx.size() > MAX_VISUAL_FX - 6:
		return
	var ring := MeshInstance3D.new()
	ring.mesh = Assets.mesh("ring")
	ring.material_override = Assets.mat("j21f_impact", Color(0.72, 0.51, 0.23), 0.78)
	ring.position = Vector3(pos.x, 0.12, pos.z)
	add_child(ring)
	fx.append({"node": ring, "t": 0.0, "dur": 0.45, "kind": "impact_ring"})
	for i in 3:
		var stone := MeshInstance3D.new()
		stone.mesh = Assets.mesh("rock")
		stone.material_override = Assets.mat("j21f_debris", Color(0.33, 0.30, 0.26), 0.94)
		stone.scale = Vector3.ONE * (0.17 + 0.07 * float(i))
		stone.position = Vector3(pos.x, 0.22, pos.z)
		add_child(stone)
		var angle: float = float(i) * TAU / 3.0 + pos.x * 0.73
		fx.append({"node": stone, "t": 0.0, "dur": 0.65, "kind": "debris", "origin": stone.position,
			"direction": Vector3(cos(angle), 0, sin(angle)) * (1.8 + float(i) * 0.3)})

func _sync_fx(delta: float) -> void:
	for f in fx.duplicate():
		f["t"] += delta
		var k: float = f["t"] / f["dur"]
		var n: Node3D = f["node"]
		if k >= 1.0:
			n.queue_free()
			fx.erase(f)
			continue
		match f["kind"]:
			"collapse":
				var collapse_scale: Vector3 = n.scale
				collapse_scale.y = maxf(0.025, 1.0 - k * k)
				n.scale = collapse_scale
				n.position.y = float(f["base"]) - k * 0.35
				n.rotation.z = k * 0.14
			"impact_ring":
				n.scale = Vector3.ONE * (0.35 + k * 2.2)
			"debris":
				var origin: Vector3 = f["origin"]
				var direction: Vector3 = f["direction"]
				n.position = origin + direction * k
				n.position.y = origin.y + sin(k * PI) * 0.82 - 0.18 * k
				n.rotation = Vector3(k * 4.0, k * 3.0, k * 1.7)
			"marker":
				n.scale = Vector3.ONE * (1.0 - k * 0.6)
			"dust":
				n.scale = Vector3.ONE * (float(f.get("base_scale", 1.0)) * (1.0 + k * 1.5))
				n.position.y += delta * 0.6
			"shot":
				n.position = f["a"].lerp(f["b"], k)
			"ball":
				var p: Vector3 = f["a"].lerp(f["b"], k)
				p.y += sin(k * PI) * float(f["h"])
				n.position = p
				if k + delta / f["dur"] >= 1.0:
					_spawn_death_fx(f["b"], 1.6)
					_siege_impact(f["b"])

func _sync_network() -> void:
	_network_tick = world.tick
	if _network_node == null:
		_network_node = MeshInstance3D.new()
		add_child(_network_node)
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	var begun: bool = false
	for link in world.modern["rail_links"]:
		var b: SimWorld.Building = world.buildings.get(int(link["a"])) as SimWorld.Building
		if b == null or b.team != observer:
			continue
		var route: PackedVector2Array = link["path"]
		var previous: Vector2 = link["start"]
		for point in route:
			if world.is_explored_by(observer, point) and world.is_explored_by(observer, previous):
				if not begun:
					mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
					begun = true
				mesh.surface_set_color(Color(0.95, 0.75, 0.35) if link["rail"] else Color(0.25, 0.65, 0.8))
				mesh.surface_add_vertex(world_pos(previous, _ground_y(previous) + 0.10))
				mesh.surface_add_vertex(world_pos(point, _ground_y(point) + 0.10))
			previous = point
	if begun:
		mesh.surface_end()
	_network_node.mesh = mesh

func _make_contact_mask() -> ImageTexture:
	# Analytic ground contact, independent of screen-space effects unsupported on Mobile.
	var image := Image.create(world.map_size, world.map_size, false, Image.FORMAT_R8)
	image.fill(Color.WHITE)
	for raw in world.nodes.values():
		var resource: SimWorld.ResNode = raw as SimWorld.ResNode
		if resource.amount <= 0 or not world.is_explored_by(observer, resource.pos):
			continue
		var radius: int = 2 if resource.kind == "arbre" else 1
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var c: Vector2i = resource.cell + Vector2i(dx, dy)
				if not world.in_map(c):
					continue
				var distance: float = Vector2(c).distance_to(resource.pos)
				var value: float = 1.0 - 0.35 * exp(-distance * distance / 1.8)
				image.set_pixel(c.x, c.y, Color(minf(image.get_pixel(c.x, c.y).r, value), 0, 0))
	return ImageTexture.create_from_image(image)

var rally_flag: Node3D
func show_rally_flag(point: Vector2, enabled: bool) -> void:
	if rally_flag == null and enabled:
		rally_flag = Node3D.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.12, 0.85, 0.72)
		material.emission_enabled = true
		material.emission = Color(0.02, 0.25, 0.16)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var pole := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.035
		cylinder.bottom_radius = 0.05
		cylinder.height = 2.8
		cylinder.radial_segments = 8
		pole.mesh = cylinder
		pole.position.y = 1.4
		pole.material_override = material
		rally_flag.add_child(pole)
		var cloth := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.25, 0.7)
		cloth.mesh = quad
		cloth.position = Vector3(0.625, 2.35, 0)
		cloth.material_override = material
		rally_flag.add_child(cloth)
		add_child(rally_flag)
	if rally_flag != null:
		rally_flag.visible = enabled
		if enabled: rally_flag.position = Vector3(point.x, 0.1, point.y)
