class_name BuildingVisual
extends RefCounted
## Détails architecturaux non interactifs et dommages purement visuels.
## J2.1 D/E/F : zéro modification des points de vie ou du pathfinding.

static func _line(parent: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var d: Vector3 = b - a
	if d.length_squared() < 0.000001:
		return
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = width
	mesh.bottom_radius = width
	mesh.height = d.length()
	mesh.radial_segments = 5
	mi.mesh = mesh
	mi.material_override = material
	mi.position = (a + b) * 0.5
	mi.quaternion = Quaternion(Vector3.UP, d.normalized())
	parent.add_child(mi)

static func enhance(root: Node3D, kind: String, team: int, size: int) -> void:
	if root.get_node_or_null("Architecture") != null:
		return
	var detail := Node3D.new()
	detail.name = "Architecture"
	root.add_child(detail)
	var damage := Node3D.new()
	damage.name = "Damage"
	damage.visible = false
	root.add_child(damage)
	var stone: Material = Assets.mat("j21f_masonry", Color(0.44, 0.43, 0.40), 0.90, 0.0, true)
	var wood: Material = Assets.mat("j21f_wood", Color(0.25, 0.17, 0.10), 0.93, 0.0, true)
	var dark: Material = Assets.mat("j21f_shadow_slot", Color(0.07, 0.075, 0.065), 1.0)
	var glass: Material = Assets.mat("j21f_glass", Color(0.13, 0.21, 0.20), 0.19, 0.09)
	var metal: Material = Assets.mat("j21f_iron", Color(0.36, 0.40, 0.42), 0.38, 0.65)
	var clay: Material = Assets.mat("j21f_clay", Color(0.53, 0.27, 0.16), 0.91, 0.0, true)
	var s: float = float(size)
	if kind in ["maison", "centre", "caserne", "relais", "entrepot", "atelier", "marche"]:
		# Façade, seuil, embrasures et huisseries; pas d'éléments sélectionnables.
		var wall_z: float = s * (0.285 if kind == "centre" else 0.27)
		var wall_height: float = 1.25 if kind == "centre" else 0.82
		if kind == "caserne":
			wall_z = -s * 0.18
			wall_height = 0.92
		if kind == "atelier":
			wall_z = -s * 0.38
			wall_height = 0.70
		if kind != "atelier" and kind != "marche":
			Assets.box(detail, Vector3(0.48, wall_height * 0.83, 0.045), dark, Vector3(0, wall_height * 0.49, wall_z + 0.035))
			Assets.box(detail, Vector3(0.55, 0.055, 0.13), stone, Vector3(0, 0.075, wall_z + 0.10))
			for side in [-1, 1]:
				var x: float = float(side) * s * 0.16
				Assets.box(detail, Vector3(0.24, 0.32, 0.042), dark, Vector3(x, wall_height * 0.91, wall_z + 0.046))
				Assets.box(detail, Vector3(0.18, 0.26, 0.051), glass, Vector3(x, wall_height * 0.91, wall_z + 0.071))
				Assets.box(detail, Vector3(0.045, 0.36, 0.07), wood, Vector3(x - 0.145, wall_height * 0.91, wall_z + 0.08))
				Assets.box(detail, Vector3(0.045, 0.36, 0.07), wood, Vector3(x + 0.145, wall_height * 0.91, wall_z + 0.08))
			Assets.box(detail, Vector3(s * 0.68, 0.06, 0.13), wood, Vector3(0, wall_height + 0.35, wall_z))
		if kind in ["centre", "caserne", "entrepot", "atelier"]:
			for xval in [-1, 1]:
				var x: float = float(xval) * s * 0.32
				_line(detail, Vector3(x, 0.10, wall_z + 0.10), Vector3(x, 1.52, wall_z + 0.10), 0.035, wood)
				_line(detail, Vector3(x, 1.15, wall_z + 0.10), Vector3(x * 0.75, 1.52, wall_z + 0.10), 0.024, wood)
		if kind in ["maison", "relais", "entrepot"]:
			# Cheminée, faîtière et ventilation sous toiture.
			Assets.box(detail, Vector3(0.20, 0.50, 0.20), stone, Vector3(s * 0.20, 1.55, -s * 0.15))
			Assets.box(detail, Vector3(0.25, 0.06, 0.25), dark, Vector3(s * 0.20, 1.82, -s * 0.15))
			Assets.box(detail, Vector3(s * 0.65, 0.055, 0.055), wood, Vector3(0, 1.68, -0.01))
	if kind == "fort":
		# Détails de la porte, meurtrières, pierres de claveau et contreforts.
		Assets.box(detail, Vector3(0.75, 1.34, 0.17), dark, Vector3(0, 0.83, s * 0.412))
		for i in range(5):
			var x: float = -0.30 + float(i) * 0.15
			Assets.box(detail, Vector3(0.10, 1.25, 0.04), wood, Vector3(x, 0.82, s * 0.512))
			Assets.box(detail, Vector3(0.11, 0.045, 0.05), metal, Vector3(x, 0.47, s * 0.55))
			Assets.box(detail, Vector3(0.11, 0.045, 0.05), metal, Vector3(x, 1.04, s * 0.55))
		for side in [-1, 1]:
			Assets.box(detail, Vector3(0.33, 1.26, 0.28), stone, Vector3(float(side) * s * 0.25, 0.65, s * 0.44))
			Assets.box(detail, Vector3(0.10, 0.22, 0.06), dark, Vector3(float(side) * s * 0.18, 1.38, s * 0.558))
	elif kind == "palissade":
		for i in range(4):
			Assets.box(detail, Vector3(0.98, 0.07, 0.10), metal if i % 2 == 0 else wood, Vector3(0, 0.34 + i * 0.27, -0.09))
	elif kind == "ferme":
		var field: Material = Assets.mat("j21f_crop", Color(0.49, 0.56, 0.22), 1.0)
		for row in range(5):
			for col in range(3):
				var x: float = -s * 0.34 + float(col) * s * 0.31
				var z: float = -s * 0.38 + float(row) * s * 0.18
				Assets.box(detail, Vector3(0.045, 0.28, 0.06), field, Vector3(x, 0.26, z), float(row) * 0.08)
	# Dommages visuels sur le parement : activés sous 65% et 30% de santé.
	# Les deux groupes restent légers et ne modifient jamais la collision ni l'occupation.
	var charred: Material = Assets.mat("j21f_char", Color(0.09, 0.07, 0.06), 1.0)
	if kind != "comptoir" and kind != "ferme":
		var scorch := Node3D.new()
		scorch.name = "Scorch"
		damage.add_child(scorch)
		for i in 3:
			var px: float = -s * 0.28 + float(i) * s * 0.25
			Assets.box(scorch, Vector3(0.22 + 0.05 * float(i), 0.15, 0.02), charred, Vector3(px, 0.58 + float(i % 2) * 0.35, s * 0.30))
		var cracks := Node3D.new()
		cracks.name = "Cracks"
		damage.add_child(cracks)
		for i in range(3):
			var xx: float = -s * 0.3 + float(i) * s * 0.28
			_line(cracks, Vector3(xx, 0.30, s * 0.34), Vector3(xx + 0.10, 1.05, s * 0.345), 0.018, dark)
		cracks.visible = false

static func set_damage(model: Node3D, ratio: float) -> void:
	var damage: Node3D = model.get_node_or_null("Damage") as Node3D
	if damage == null:
		return
	var scorched: bool = ratio < 0.65
	damage.set_meta("has_damage", scorched)
	damage.visible = scorched
	var cracks: Node3D = damage.get_node_or_null("Cracks") as Node3D
	if cracks != null:
		cracks.visible = ratio < 0.30

static func set_lod(model: Node3D, detailed: bool) -> void:
	var evolution_detail: Node3D = model.get_node_or_null("EvolutionStyle") as Node3D
	if evolution_detail != null:
		evolution_detail.visible = detailed
	var architecture: Node3D = model.get_node_or_null("Architecture") as Node3D
	if architecture != null:
		architecture.visible = detailed
	var damage: Node3D = model.get_node_or_null("Damage") as Node3D
	if damage != null:
		damage.visible = detailed and bool(damage.get_meta("has_damage", false))

static func set_evolution(model: Node3D, level: int) -> void:
	TechAppearance.decorate(model, level, Vector3(0.0, 2.1, 0.0), 0.9)
