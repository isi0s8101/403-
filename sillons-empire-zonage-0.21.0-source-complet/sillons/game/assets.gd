class_name Assets
extends RefCounted
## Assets 3D procéduraux du projet (aucun fichier externe, aucune licence tierce).
## Tous PROVISOIRES sauf la zone témoin, qui sert de référence de lecture et de coût de rendu.

const TEAM_COLORS := [Color(0.16, 0.36, 0.78), Color(0.72, 0.16, 0.12), Color(0.75, 0.68, 0.45)]
const UNIT_SCALE := 1.5   # légère exagération des silhouettes pour la lecture au tactile

const SURFACE_NORMAL = preload("res://game/textures/terrain_normal.png")
const SURFACE_DETAIL = preload("res://game/textures/surface_detail.png")

static var _mats := {}
static var _meshes := {}

static func mat(key: String, color: Color, rough: float = 0.85, metal: float = 0.0, noise: bool = false) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if noise:
		m.albedo_texture = SURFACE_DETAIL
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.6, 0.6, 0.6)
		m.normal_enabled = true
		m.normal_texture = SURFACE_NORMAL
		m.normal_scale = 0.25
	_mats[key] = m
	return m

static func team_mat(team: int) -> StandardMaterial3D:
	return mat("team%d" % team, TEAM_COLORS[team], 0.75)

static func mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match key:
		"capsule":
			var c := CapsuleMesh.new()
			c.radius = 0.16
			c.height = 0.62
			c.radial_segments = 10
			c.rings = 3
			m = c
		"head":
			var s := SphereMesh.new()
			s.radius = 0.11
			s.height = 0.22
			s.radial_segments = 10
			s.rings = 5
			m = s
		"leg":
			var b := BoxMesh.new()
			b.size = Vector3(0.09, 0.32, 0.1)
			m = b
		"spear":
			var c := CylinderMesh.new()
			c.top_radius = 0.012
			c.bottom_radius = 0.018
			c.height = 1.25
			c.radial_segments = 5
			m = c
		"musket":
			var b := BoxMesh.new()
			b.size = Vector3(0.05, 0.05, 0.85)
			m = b
		"helmet":
			var s := SphereMesh.new()
			s.radius = 0.125
			s.height = 0.14
			s.is_hemisphere = true
			s.radial_segments = 10
			s.rings = 3
			m = s
		"horse":
			var c := CapsuleMesh.new()
			c.radius = 0.17
			c.height = 0.85
			c.radial_segments = 10
			c.rings = 3
			m = c
		"horse_head":
			var b := BoxMesh.new()
			b.size = Vector3(0.12, 0.32, 0.14)
			m = b
		"horse_leg":
			var c := CylinderMesh.new()
			c.top_radius = 0.035
			c.bottom_radius = 0.03
			c.height = 0.42
			c.radial_segments = 5
			m = c
		"cart":
			var b := BoxMesh.new()
			b.size = Vector3(0.55, 0.28, 0.85)
			m = b
		"wheel":
			var c := CylinderMesh.new()
			c.top_radius = 0.17
			c.bottom_radius = 0.17
			c.height = 0.06
			c.radial_segments = 10
			m = c
		"bundle":
			var b := BoxMesh.new()
			b.size = Vector3(0.22, 0.16, 0.18)
			m = b
		"ring":
			var t := TorusMesh.new()
			t.inner_radius = 0.42
			t.outer_radius = 0.5
			t.rings = 20
			t.ring_segments = 4
			m = t
		"hpbar":
			var q := QuadMesh.new()
			q.size = Vector2(0.7, 0.07)
			m = q
		"trunk":
			var c := CylinderMesh.new()
			c.top_radius = 0.07
			c.bottom_radius = 0.12
			c.height = 1.0
			c.radial_segments = 6
			m = c
		"canopy":
			var c := SphereMesh.new()
			c.radius = 0.79
			c.height = 1.35
			c.radial_segments = 9
			c.rings = 5
			m = c
		"canopy2":
			var s := SphereMesh.new()
			s.radius = 0.52
			s.height = 0.87
			s.radial_segments = 8
			s.rings = 4
			m = s
		"bush":
			var s := SphereMesh.new()
			s.radius = 0.38
			s.height = 0.5
			s.radial_segments = 8
			s.rings = 4
			m = s
		"rock":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 0.7
			s.radial_segments = 6
			s.rings = 3
			m = s
		_:
			var b := BoxMesh.new()
			m = b
	_meshes[key] = m
	return m

static func part(parent: Node3D, mesh_key: String, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(mesh_key)
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, material: Material, pos: Vector3, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

static func roof(parent: Node3D, size: Vector3, material: Material, pos: Vector3, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = size
	mi.mesh = p
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

# ------------------------------------------------------------------ unités

static func build_unit(type: String, team: int) -> Node3D:
	if type in ["char", "avion", "antiaerien", "train", "lance_missiles", "drone", "brouilleur", "obusier", "navette", "fregate"]:
		return ModernVisual.unit(type, team)
	if type in ["fusilier", "grenadier"]:
		return build_unit("tireur", team)
	## Silhouettes distinctes par rôle : outil/charge (ouvrier), lance longue (lancier),
	## arme d'épaule + casque (tireur), cheval (éclaireur, cavalier), chariot (caravane).
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var tm := team_mat(team)
	var skin := mat("skin", Color(0.78, 0.6, 0.47), 0.7)
	var cloth := mat("cloth", Color(0.42, 0.36, 0.28), 0.95)
	var wood := mat("wood", Color(0.42, 0.29, 0.17), 0.9, 0.0, true)
	var steel := mat("steel", Color(0.62, 0.64, 0.66), 0.35, 0.8)
	var horse := mat("horse", Color(0.36, 0.24, 0.15), 0.8)
	var mounted := type == "eclaireur" or type == "cavalier"
	var base_y := 0.0
	if mounted:
		var h := Node3D.new()
		h.name = "Horse"
		body.add_child(h)
		part(h, "horse", horse, Vector3(0, 0.62, 0), Vector3(PI / 2, 0, 0))
		part(h, "horse_head", horse, Vector3(0, 0.88, 0.5), Vector3(-0.5, 0, 0))
		for lx in [-0.1, 0.1]:
			for lz in [-0.3, 0.3]:
				part(h, "horse_leg", horse, Vector3(lx, 0.22, lz))
		base_y = 0.55
	if type == "caravane":
		part(body, "cart", wood, Vector3(0, 0.36, -0.15))
		part(body, "bundle", tm, Vector3(0, 0.6, -0.15), Vector3.ZERO, Vector3(2.0, 1.4, 3.0))
		for wx in [-0.31, 0.31]:
			part(body, "wheel", wood, Vector3(wx, 0.17, -0.15), Vector3(0, 0, PI / 2))
		var ox := Node3D.new()
		body.add_child(ox)
		part(ox, "horse", horse, Vector3(0, 0.45, 0.62), Vector3(PI / 2, 0, 0), Vector3(1.1, 0.8, 1.0))
		part(ox, "horse_head", horse, Vector3(0, 0.55, 1.02), Vector3(-1.0, 0, 0))
		root.scale = Vector3.ONE * UNIT_SCALE
		return root
	if type == "canon":
		# affût à deux roues, flèche au sol, fût orientable (« Barrel ») et un servant
		var iron := mat("iron", Color(0.2, 0.21, 0.22), 0.45, 0.7)
		box(body, Vector3(0.36, 0.16, 0.9), wood, Vector3(0, 0.34, -0.1))
		var trail := box(body, Vector3(0.14, 0.08, 0.7), wood, Vector3(0, 0.16, -0.75))
		trail.rotation.x = 0.25
		for wx in [-0.28, 0.28]:
			part(body, "wheel", wood, Vector3(wx, 0.3, 0.05), Vector3(0, 0, PI / 2), Vector3(1.7, 1.0, 1.7))
		var barrel := Node3D.new()
		barrel.name = "Barrel"
		barrel.position = Vector3(0, 0.5, 0.05)
		body.add_child(barrel)
		var bm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.11
		cm.height = 1.05
		cm.radial_segments = 10
		bm.mesh = cm
		bm.material_override = iron
		bm.rotation.x = PI / 2
		bm.position.z = 0.25
		barrel.add_child(bm)
		var crew := Node3D.new()
		crew.name = "Crew"
		crew.position = Vector3(0.45, 0, -0.45)
		body.add_child(crew)
		part(crew, "leg", cloth, Vector3(-0.06, 0.16, 0))
		part(crew, "leg", cloth, Vector3(0.06, 0.16, 0))
		part(crew, "capsule", tm, Vector3(0, 0.6, 0))
		part(crew, "head", skin, Vector3(0, 1.0, 0))
		part(crew, "helmet", mat("hat", Color(0.15, 0.13, 0.12), 0.9), Vector3(0, 1.06, 0), Vector3.ZERO, Vector3(1.4, 0.8, 1.4))
		root.scale = Vector3.ONE * UNIT_SCALE
		return root
	var figure := Node3D.new()
	figure.name = "Figure"
	figure.position.y = base_y
	body.add_child(figure)
	if not mounted:
		part(figure, "leg", cloth, Vector3(-0.06, 0.16, 0))
		part(figure, "leg", cloth, Vector3(0.06, 0.16, 0))
	part(figure, "capsule", tm if type != "ouvrier" else cloth, Vector3(0, 0.6, 0))
	if type == "ouvrier":
		part(figure, "capsule", tm, Vector3(0, 0.66, 0), Vector3.ZERO, Vector3(1.05, 0.35, 1.05))
	part(figure, "head", skin, Vector3(0, 1.0, 0))
	var weapon := Node3D.new()
	weapon.name = "Weapon"
	weapon.position = Vector3(0.2, 0.62, 0.05)
	figure.add_child(weapon)
	match type:
		"ouvrier":
			part(weapon, "spear", wood, Vector3(0, 0.1, 0.1), Vector3(0.6, 0, 0), Vector3(1.2, 0.45, 1.2))
			part(weapon, "bundle", steel, Vector3(0, 0.36, 0.28), Vector3.ZERO, Vector3(0.6, 0.4, 0.5))
			var carry := part(figure, "bundle", wood, Vector3(0, 0.75, -0.2))
			carry.name = "Carry"
			carry.visible = false
		"lancier":
			part(weapon, "spear", wood, Vector3(0, 0.25, 0))
			part(weapon, "bundle", steel, Vector3(0, 0.9, 0), Vector3.ZERO, Vector3(0.18, 0.6, 0.18))
			part(figure, "helmet", steel, Vector3(0, 1.04, 0))
			var shield := box(figure, Vector3(0.05, 0.38, 0.3), tm, Vector3(-0.2, 0.62, 0.05))
			shield.name = "Shield"
		"tireur":
			part(weapon, "musket", wood, Vector3(0, 0.05, 0.25), Vector3(0.15, 0, 0))
			part(weapon, "musket", steel, Vector3(0, 0.08, 0.55), Vector3(0.15, 0, 0), Vector3(0.6, 0.6, 0.5))
			part(figure, "helmet", mat("hat", Color(0.15, 0.13, 0.12), 0.9), Vector3(0, 1.06, 0), Vector3.ZERO, Vector3(1.4, 0.8, 1.4))
		"cavalier":
			part(weapon, "spear", wood, Vector3(0, 0.1, 0.35), Vector3(1.2, 0, 0), Vector3(1, 1.1, 1))
			part(figure, "helmet", steel, Vector3(0, 1.04, 0))
		"eclaireur":
			part(figure, "helmet", mat("hood", Color(0.3, 0.38, 0.22), 0.95), Vector3(0, 1.03, 0), Vector3.ZERO, Vector3(1.1, 1.3, 1.1))
	root.scale = Vector3.ONE * UNIT_SCALE
	return root

# ------------------------------------------------------------------ bâtiments

static func build_building(type: String, team: int, size: int) -> Node3D:
	if int(Rules.BUILDINGS[type]["age"]) >= 4 and int(Rules.BUILDINGS[type]["age"]) <= 10:
		return ModernVisual.building(type, team, size)
	var root := Node3D.new()
	var tm := team_mat(team)
	var stone := mat("stone", Color(0.55, 0.53, 0.5), 0.92, 0.0, true)
	var plaster := mat("plaster", Color(0.86, 0.82, 0.72), 0.95, 0.0, true)
	var timber := mat("timber", Color(0.33, 0.22, 0.13), 0.9, 0.0, true)
	var roof_m := mat("roof", Color(0.45, 0.2, 0.14), 0.85, 0.0, true)
	var thatch := mat("thatch", Color(0.62, 0.52, 0.3), 1.0, 0.0, true)
	var s := float(size)
	match type:
		"centre":
			box(root, Vector3(s * 0.95, 0.35, s * 0.95), stone, Vector3(0, 0.17, 0))
			box(root, Vector3(s * 0.7, 1.6, s * 0.55), plaster, Vector3(0, 1.15, 0))
			roof(root, Vector3(s * 0.78, 1.1, s * 0.62), roof_m, Vector3(0, 2.5, 0), 0)
			box(root, Vector3(0.9, 2.8, 0.9), stone, Vector3(s * 0.32, 1.75, s * 0.28))
			roof(root, Vector3(1.1, 0.9, 1.1), roof_m, Vector3(s * 0.32, 3.6, s * 0.28))
			for x in [-0.3, -0.1, 0.1, 0.3]:
				box(root, Vector3(0.08, 1.6, 0.05), timber, Vector3(x * s, 1.15, s * 0.28))
			_banner(root, tm, Vector3(-s * 0.32, 0, -s * 0.25), 3.6)
		"maison":
			box(root, Vector3(s * 0.8, 0.2, s * 0.8), stone, Vector3(0, 0.1, 0))
			box(root, Vector3(s * 0.62, 0.9, s * 0.5), plaster, Vector3(0, 0.65, 0))
			roof(root, Vector3(s * 0.72, 0.75, s * 0.58), thatch, Vector3(0, 1.47, 0))
			box(root, Vector3(0.15, 0.6, 0.15), stone, Vector3(s * 0.2, 1.7, 0))
			box(root, Vector3(0.25, 0.08, s * 0.52), tm, Vector3(0, 1.1, 0))
		"entrepot":
			box(root, Vector3(s * 0.85, 0.15, s * 0.85), stone, Vector3(0, 0.07, 0))
			box(root, Vector3(s * 0.7, 0.8, s * 0.6), timber, Vector3(0, 0.55, 0))
			roof(root, Vector3(s * 0.8, 0.5, s * 0.7), roof_m, Vector3(0, 1.2, 0))
			for i in 3:
				box(root, Vector3(0.3, 0.3, 0.3), mat("crate", Color(0.55, 0.42, 0.25), 0.9), Vector3(-0.5 + i * 0.35, 0.3, s * 0.42))
			_banner(root, tm, Vector3(s * 0.38, 0, -s * 0.35), 1.6)
		"ferme":
			var soil := mat("soil", Color(0.36, 0.27, 0.17), 1.0, 0.0, true)
			var crop := mat("crop", Color(0.72, 0.64, 0.28), 1.0)
			box(root, Vector3(s * 0.95, 0.06, s * 0.95), soil, Vector3(0, 0.03, 0))
			for i in 5:
				box(root, Vector3(s * 0.85, 0.18, 0.18), crop, Vector3(0, 0.12, -s * 0.38 + i * s * 0.19))
			box(root, Vector3(0.6, 0.5, 0.5), timber, Vector3(s * 0.38, 0.25, s * 0.38))
			_banner(root, tm, Vector3(-s * 0.45, 0, -s * 0.45), 1.2)
		"caserne":
			box(root, Vector3(s * 0.95, 0.25, s * 0.95), stone, Vector3(0, 0.12, 0))
			box(root, Vector3(s * 0.8, 1.1, s * 0.45), stone, Vector3(0, 0.8, -s * 0.18))
			roof(root, Vector3(s * 0.85, 0.7, s * 0.52), roof_m, Vector3(0, 1.7, -s * 0.18))
			for x in [-0.4, -0.2, 0.0, 0.2, 0.4]:
				box(root, Vector3(0.12, 0.9, 0.12), timber, Vector3(x * s, 0.7, s * 0.4))
			box(root, Vector3(s * 0.9, 0.08, 0.12), timber, Vector3(0, 1.15, s * 0.4))
			_banner(root, tm, Vector3(s * 0.42, 0, s * 0.1), 2.6)
			_banner(root, tm, Vector3(-s * 0.42, 0, s * 0.1), 2.6)
		"marche":
			box(root, Vector3(s * 0.95, 0.12, s * 0.95), stone, Vector3(0, 0.06, 0))
			for i in 3:
				var cx := -s * 0.3 + i * s * 0.3
				var awn := mat("awning%d" % i, [Color(0.75, 0.6, 0.25), Color(0.55, 0.62, 0.35), Color(0.7, 0.4, 0.3)][i], 0.9)
				for px in [-0.35, 0.35]:
					for pz in [-0.35, 0.35]:
						box(root, Vector3(0.06, 0.9, 0.06), timber, Vector3(cx + px, 0.5, pz + 0.2))
				roof(root, Vector3(0.9, 0.25, 0.9), awn, Vector3(cx, 1.05, 0.2))
				box(root, Vector3(0.6, 0.35, 0.4), mat("crate", Color(0.55, 0.42, 0.25), 0.9), Vector3(cx, 0.25, 0.2))
			box(root, Vector3(s * 0.6, 0.9, 0.6), plaster, Vector3(0, 0.5, -s * 0.35))
			_banner(root, tm, Vector3(s * 0.42, 0, -s * 0.42), 2.2)
		"relais":
			box(root, Vector3(s * 0.85, 0.15, s * 0.85), stone, Vector3(0, 0.07, 0))
			box(root, Vector3(s * 0.55, 0.9, s * 0.55), timber, Vector3(0, 0.6, 0))
			roof(root, Vector3(s * 0.65, 0.55, s * 0.65), roof_m, Vector3(0, 1.32, 0))
			_banner(root, tm, Vector3(s * 0.4, 0, s * 0.4), 2.2)
		"palissade":
			# pieux taillés serrés, liés par une traverse
			for i in 5:
				var px := -0.4 + i * 0.2
				var h := 1.25 + 0.12 * sin(i * 2.3)
				box(root, Vector3(0.16, h, 0.16), timber, Vector3(px, h * 0.5, 0), 0.1 * sin(i * 1.7))
				roof(root, Vector3(0.16, 0.18, 0.16), timber, Vector3(px, h + 0.09, 0))
			box(root, Vector3(1.0, 0.08, 0.06), wood_band(), Vector3(0, 0.75, 0.1))
			box(root, Vector3(0.08, 0.3, 0.12), tm, Vector3(0, 0.95, 0.12))
		"fort":
			# enceinte de pierre, quatre tours d'angle et donjon
			box(root, Vector3(s * 0.98, 0.3, s * 0.98), stone, Vector3(0, 0.15, 0))
			for side in 4:
				var r := side * PI / 2
				var off := Vector3(0, 0, s * 0.4).rotated(Vector3.UP, r)
				box(root, Vector3(s * 0.8, 1.3, 0.3), stone, off + Vector3(0, 0.95, 0), r)
				for k in 4:
					var cren := Vector3(-s * 0.3 + k * s * 0.2, 0, 0).rotated(Vector3.UP, r)
					box(root, Vector3(0.2, 0.22, 0.32), stone, off + cren + Vector3(0, 1.7, 0), r)
			for cx in [-1, 1]:
				for cz in [-1, 1]:
					var tp := Vector3(cx * s * 0.42, 0, cz * s * 0.42)
					box(root, Vector3(0.7, 2.1, 0.7), stone, tp + Vector3(0, 1.05, 0))
					roof(root, Vector3(0.85, 0.7, 0.85), roof_m, tp + Vector3(0, 2.45, 0))
			box(root, Vector3(1.1, 2.6, 1.1), stone, Vector3(0, 1.3, 0))
			roof(root, Vector3(1.3, 0.9, 1.3), roof_m, Vector3(0, 3.05, 0))
			_banner(root, tm, Vector3(0, 2.6, 0), 1.6)
		"atelier":
			# hangar ouvert, poutre de levage et fût en cours d'assemblage
			box(root, Vector3(s * 0.95, 0.15, s * 0.95), stone, Vector3(0, 0.07, 0))
			for px in [-0.42, 0.42]:
				for pz in [-0.35, 0.35]:
					box(root, Vector3(0.14, 1.4, 0.14), timber, Vector3(px * s, 0.75, pz * s))
			roof(root, Vector3(s * 0.98, 0.6, s * 0.85), roof_m, Vector3(0, 1.75, 0))
			box(root, Vector3(s * 0.8, 1.1, 0.12), timber, Vector3(0, 0.7, -s * 0.38))
			box(root, Vector3(0.12, 0.12, s * 0.9), timber, Vector3(0, 1.4, 0))
			var bar := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.1
			cyl.bottom_radius = 0.15
			cyl.height = 1.3
			cyl.radial_segments = 10
			bar.mesh = cyl
			bar.material_override = mat("iron", Color(0.2, 0.21, 0.22), 0.45, 0.7)
			bar.rotation.z = PI / 2
			bar.position = Vector3(0, 0.45, 0.1)
			root.add_child(bar)
			box(root, Vector3(0.5, 0.3, 0.4), timber, Vector3(-0.5, 0.2, 0.1))
			box(root, Vector3(0.5, 0.3, 0.4), timber, Vector3(0.5, 0.2, 0.1))
			_banner(root, tm, Vector3(s * 0.45, 0, s * 0.45), 2.4)
		"comptoir":
			var tent := mat("tent", Color(0.82, 0.76, 0.6), 0.95)
			box(root, Vector3(s * 0.9, 0.1, s * 0.9), stone, Vector3(0, 0.05, 0))
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = s * 0.45
			cm.height = 1.4
			cm.radial_segments = 8
			c.mesh = cm
			c.material_override = tent
			c.position.y = 0.8
			root.add_child(c)
			for i in 4:
				box(root, Vector3(0.3, 0.3, 0.3), mat("crate", Color(0.55, 0.42, 0.25), 0.9), Vector3(cos(i * 1.7) * 0.9, 0.2, sin(i * 1.7) * 0.9))
			_banner(root, mat("neutral", Color(0.85, 0.75, 0.3), 0.8), Vector3(0, 0, 0), 2.4)
	return root

static func wood_band() -> StandardMaterial3D:
	return mat("band", Color(0.28, 0.2, 0.12), 0.9)

static func _banner(parent: Node3D, m: Material, pos: Vector3, h: float) -> void:
	var pole := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.025
	c.bottom_radius = 0.03
	c.height = h
	c.radial_segments = 5
	pole.mesh = c
	pole.material_override = mat("wood", Color(0.42, 0.29, 0.17), 0.9, 0.0, true)
	pole.position = pos + Vector3(0, h * 0.5, 0)
	parent.add_child(pole)
	box(parent, Vector3(0.03, 0.4, 0.55), m, pos + Vector3(0, h - 0.25, 0.28))

# ------------------------------------------------------------------ terrain

static func terrain_shader() -> Shader:
	## Textures PBR originales, masque de berges/usure et brouillard de guerre existant.
	## Une seule couche spatiale; aucune lumière ni post-process supplémentaire.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back, fog_disabled;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D ground_mask : filter_linear, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float map_size = 96.0;
uniform vec3 biome_tint = vec3(1.0, 1.0, 1.0);
varying vec3 wpos;
float hash12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0,0.0)), f.x),
               mix(hash12(i + vec2(0.0,1.0)), hash12(i + vec2(1.0,1.0)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 uv = clamp(wpos.xz / map_size, vec2(0.001), vec2(0.999));
    vec3 terrain = texture(ground_mask, uv).rgb;
    vec2 tiled = wpos.xz * 0.21;
    vec4 grass = texture(grass_tex, tiled);
    vec4 soil = texture(soil_tex, tiled * 0.85);
    vec4 sand = texture(sand_tex, tiled * 0.9);
    vec4 rock = texture(rock_tex, tiled * 1.16);
    float macro = texture(grass_tex, wpos.xz * 0.017 + vec2(0.19)).g;
    float bare = clamp(terrain.g * 0.80 + smoothstep(0.35, 0.52, macro) * 0.32, 0.0, 0.88);
    float rocky = clamp(terrain.b * 0.7, 0.0, 0.75);
    float bank = clamp(terrain.r, 0.0, 0.96);
    vec4 layer = mix(grass, soil, bare);
    layer = mix(layer, rock, rocky);
    layer = mix(layer, sand, bank);
    // Brouillard identique au J2: le contenu inconnu reste réellement invisible.
    float fog = texture(fog_tex, uv).r;
    float visible = clamp(fog * fog * 1.35, 0.0, 1.0);
    ALBEDO = layer.rgb * biome_tint * mix(0.89, 1.09, clamp(macro * 2.0, 0.0, 1.0)) * visible;
    ROUGHNESS = clamp(layer.a, 0.65, 1.0);
    METALLIC = 0.0;
    SPECULAR = 0.20 * visible;
    NORMAL_MAP = texture(normal_tex, tiled).rgb;
    NORMAL_MAP_DEPTH = 0.28;
}
"""
	return sh

static func water_shader() -> Shader:
	## Vagues à deux échelles, écume légère et lecture des gués; sans réfraction écran.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back, depth_draw_opaque, fog_disabled;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D ground_mask : filter_linear, repeat_disable;
uniform float map_size = 96.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 uv = clamp(wpos.xz / map_size, vec2(0.001), vec2(0.999));
    vec4 mask = texture(ground_mask, uv);
    float w1 = sin(wpos.x * 2.4 + wpos.z * 0.9 + TIME * 1.2);
    float w2 = sin(wpos.z * 3.1 - wpos.x * 0.7 - TIME * 0.8);
    float ripple = (w1 + w2) * 0.5;
    float shallow = clamp(mask.r * 0.85 + mask.a * 0.25, 0.0, 1.0);
    vec3 deep = vec3(0.055, 0.19, 0.25);
    vec3 surface = vec3(0.19, 0.33, 0.30);
    vec3 col = mix(deep, surface, clamp(0.35 + 0.5 * shallow + ripple * 0.065, 0.0, 1.0));
    float foam = smoothstep(0.72, 0.96, shallow) * max(0.0, ripple) * 0.08;
    col += vec3(foam);
    float fog = texture(fog_tex, uv).r;
    float visible = clamp(fog * fog * 1.35, 0.0, 1.0);
    ALBEDO = col * visible;
    ROUGHNESS = 0.25;
    METALLIC = 0.02;
    SPECULAR = 0.45 * visible;
    // Surface opaque : le lit et le masque donnent les faibles profondeurs sans surtransparence.
}
"""
	return sh

static func grass_detail_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var a: float = float(i) * 2.399
		var d := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-d.z, 0.0, d.x) * 0.025
		var base: Vector3 = d * float(i % 3) * 0.07
		var mid: Vector3 = base + Vector3.UP * (0.17 + float(i % 4) * 0.025) + d * 0.035
		var tip: Vector3 = mid + Vector3.UP * 0.12 + d * 0.09
		st.set_normal((Vector3.UP + d * 0.4).normalized())
		st.set_color(Color(0.70 + float(i % 3) * 0.10, 0.82, 0.66))
		for point in [base-side, base+side, mid+side*.55, base-side, mid+side*.55, mid-side*.55, mid-side*.55, mid+side*.55, tip]:
			st.add_vertex(point)
	return st.commit()

static func build_terrain(w: SimWorld) -> Array:
	## Maillage du sol (hauteurs dérivées de la grille : lit de rivière abaissé, gués peu profonds).
	var n := w.map_size
	var heights := PackedFloat32Array()
	heights.resize((n + 1) * (n + 1))
	for vy in n + 1:
		for vx in n + 1:
			var water := 0.0
			var ford := 0.0
			var cnt := 0.0
			for oy in [-1, 0]:
				for ox in [-1, 0]:
					var c := Vector2i(clampi(vx + ox, 0, n - 1), clampi(vy + oy, 0, n - 1))
					var t := w.terrain[w.idx(c)]
					cnt += 1.0
					if t == SimWorld.TERRAIN_WATER:
						water += 1.0
					elif t == SimWorld.TERRAIN_FORD:
						ford += 1.0
			var h := 0.0
			h -= (water / cnt) * 0.9 + (ford / cnt) * 0.32
			h += (sin(vx * 0.21) * cos(vy * 0.17)) * 0.08
			heights[vy * (n + 1) + vx] = h
	# Normales douces dérivées des hauteurs, coordonnées UV stables, tangentes PBR.
	var norms := PackedVector3Array()
	norms.resize((n + 1) * (n + 1))
	for vy in n + 1:
		for vx in n + 1:
			var dx: float = heights[vy * (n + 1) + mini(vx + 1, n)] - heights[vy * (n + 1) + maxi(vx - 1, 0)]
			var dz: float = heights[mini(vy + 1, n) * (n + 1) + vx] - heights[maxi(vy - 1, 0) * (n + 1) + vx]
			norms[vy * (n + 1) + vx] = Vector3(-dx, 2.0, -dz).normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vy in n:
		for vx in n:
			var p00 := Vector3(vx, heights[vy * (n + 1) + vx], vy)
			var p10 := Vector3(vx + 1, heights[vy * (n + 1) + vx + 1], vy)
			var p01 := Vector3(vx, heights[(vy + 1) * (n + 1) + vx], vy + 1)
			var p11 := Vector3(vx + 1, heights[(vy + 1) * (n + 1) + vx + 1], vy + 1)
			for point in [p00, p10, p11, p00, p11, p01]:
				var ix: int = int(point.x)
				var iz: int = int(point.z)
				st.set_normal(norms[iz * (n + 1) + ix])
				st.set_uv(Vector2(point.x, point.z) * 0.21)
				st.add_vertex(point)
	st.generate_tangents()
	var ground := st.commit()
	# bordure : jupe sombre autour de la carte
	return [ground, heights]
