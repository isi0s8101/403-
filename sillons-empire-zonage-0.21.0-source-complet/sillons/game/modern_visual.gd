class_name ModernVisual
extends RefCounted
## Maillages originaux procéduraux : silhouettes mécaniques distinctes, sans asset tiers.
static func unit(kind: String, team: int) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var paint: Material = Assets.team_mat(team)
	var metal: Material = Assets.mat("modern_metal", Color(0.22, 0.26, 0.25), 0.45, 0.65)
	var rubber: Material = Assets.mat("modern_rubber", Color(0.065, 0.07, 0.075), 0.95)
	if kind in ["avion", "drone", "navette", "fregate"]:
		Assets.box(body, Vector3(0.30, 0.20, 1.75), paint, Vector3.ZERO)
		Assets.box(body, Vector3(2.3, 0.075, 0.40), metal, Vector3(0, 0, 0.1))
		Assets.box(body, Vector3(0.8, 0.06, 0.25), metal, Vector3(0, 0.12, -0.65))
		Assets.box(body, Vector3(0.08, 0.45, 0.30), paint, Vector3(0, 0.22, -0.65))
		if kind == "drone":
			body.scale = Vector3.ONE * 0.65
		elif kind in ["navette", "fregate"]:
			body.scale = Vector3(1.9, 1.8, 2.4) if kind == "fregate" else Vector3(1.3, 1.25, 1.5)
			Assets.box(body, Vector3(0.40, 0.26, 0.9), paint, Vector3(0, 0.10, -0.7))
			for wing in [-1.0, 1.0]:
				Assets.box(body, Vector3(0.60, 0.08, 0.32), paint, Vector3(wing * 0.94, 0, -0.45))
	else:
		var length: float = 2.0 if kind == "train" else 1.4
		Assets.box(body, Vector3(0.8, 0.40, length), paint, Vector3(0, 0.45, 0))
		for side in [-1.0, 1.0]:
			Assets.box(body, Vector3(0.22, 0.30, length), rubber, Vector3(side * 0.47, 0.22, 0))
			for z in [-0.45, 0.0, 0.45]:
				Assets.part(body, "wheel", metal, Vector3(side * 0.59, 0.24, z), Vector3(0, 0, PI / 2))
		var turret := Node3D.new()
		turret.name = "Barrel"
		body.add_child(turret)
		Assets.box(turret, Vector3(0.55, 0.30, 0.55), metal, Vector3(0, 0.78, 0))
		if kind in ["char", "obusier"]:
			Assets.box(turret, Vector3(0.11, 0.11, 1.15), metal, Vector3(0, 0.8, 0.7))
		elif kind in ["antiaerien", "lance_missiles"]:
			for x in [-0.2, 0.2]:
				var tube := Assets.box(turret, Vector3(0.14, 0.14, 0.95), metal, Vector3(x, 0.9, 0.2))
				tube.rotation.x = -0.55
		elif kind == "brouilleur":
			Assets.box(body, Vector3(0.05, 1.1, 0.05), metal, Vector3(0, 1.1, 0))
			Assets.box(body, Vector3(0.8, 0.10, 0.25), paint, Vector3(0, 1.6, 0))
		elif kind == "train":
			Assets.box(body, Vector3(0.65, 0.60, 0.7), metal, Vector3(0, 0.9, -0.4))
	root.scale = Vector3.ONE * Assets.UNIT_SCALE
	return root

static func building(kind: String, team: int, size: int) -> Node3D:
	var root := Node3D.new()
	var concrete: Material = Assets.mat("modern_concrete", Color(0.48, 0.5, 0.48), 0.9)
	var metal: Material = Assets.mat("modern_roof", Color(0.22, 0.28, 0.30), 0.48, 0.45)
	var paint: Material = Assets.team_mat(team)
	var s: float = float(size)
	Assets.box(root, Vector3(s * 0.95, 0.18, s * 0.95), concrete, Vector3(0, 0.09, 0))
	Assets.box(root, Vector3(s * 0.80, 1.2, s * 0.65), concrete, Vector3(0, 0.7, 0))
	Assets.box(root, Vector3(s * 0.86, 0.12, s * 0.72), metal, Vector3(0, 1.35, 0))
	Assets.box(root, Vector3(s * 0.4, 0.7, 0.04), metal, Vector3(0, 0.47, s * 0.33))
	Assets.box(root, Vector3(s * 0.8, 0.12, 0.05), paint, Vector3(0, 1.05, s * 0.34))
	if kind == "spatioport" or kind == "chantier_orbital":
		Assets.box(root, Vector3(s * 0.72, 0.14, s * 0.72), paint, Vector3(0, 1.53, 0))
		Assets.box(root, Vector3(s * 0.28, 1.95, s * 0.28), metal, Vector3(0, 2.35, 0))
		for side in [-1.0, 1.0]:
			Assets.box(root, Vector3(0.15, 2.8, 0.15), paint, Vector3(side * s * 0.36, 2.6, -s * 0.32))
		if kind == "chantier_orbital":
			Assets.box(root, Vector3(s * 0.62, 0.16, 0.20), metal, Vector3(0, 3.6, 0))
	elif kind == "usine":
		for x in [-0.3, 0.3]:
			Assets.box(root, Vector3(0.3, 2.8, 0.3), metal, Vector3(x * s, 1.5, -s * 0.22))
	elif kind == "radar" or kind == "intercepteur":
		Assets.box(root, Vector3(0.12, 1.3, 0.12), metal, Vector3(0, 1.9, 0))
		var dish := Assets.box(root, Vector3(1.5, 0.6, 0.12), paint, Vector3(0, 2.5, 0))
		dish.rotation.x = -0.4
	elif kind == "silo":
		for x in [-0.4, 0.4]:
			Assets.box(root, Vector3(0.5, 0.15, 1.0), paint, Vector3(x, 1.5, 0))
	elif kind == "gare":
		Assets.box(root, Vector3(s, 0.08, 0.7), metal, Vector3(0, 0.22, s * 0.4))
	elif kind == "aerodrome":
		for z in [-0.3, 0, 0.3]:
			Assets.box(root, Vector3(0.12, 0.03, 0.45), paint, Vector3(s * 0.44, 0.20, z * s))
	return root
