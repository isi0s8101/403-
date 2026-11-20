class_name UnitVisual
extends RefCounted
## Silhouette humaine articulée de proximité : procédurale, originale, sans asset tiers.
## Rendue uniquement; aucune animation n'écrit dans SimWorld.
## Unités éloignées: reprise du modèle J2, pour limiter les appels de rendu.

static func _pivot(parent: Node3D, name: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = name
	p.position = pos
	parent.add_child(p)
	return p

static func _human(parent: Node3D, kind: String, team: int, mounted: bool) -> Node3D:
	var rig := _pivot(parent, "Rig", Vector3.ZERO)
	var cloth: Material = Assets.mat("j21f_cloth", Color(0.27, 0.31, 0.29), 0.94)
	var leather: Material = Assets.mat("j21f_leather", Color(0.25, 0.15, 0.09), 0.82)
	var skin: Material = Assets.mat("j21f_skin", Color(0.72, 0.52, 0.38), 0.79)
	var metal: Material = Assets.mat("j21f_steel", Color(0.45, 0.49, 0.48), 0.38, 0.68)
	var team_color: Material = Assets.team_mat(team)
	var dark: Material = Assets.mat("j21f_dark", Color(0.11, 0.12, 0.11), 0.89)
	var helmet: bool = kind in ["lancier", "cavalier", "tireur"]
	var armor: bool = kind in ["lancier", "cavalier"]
	# Silhouette : jambes à deux articulations, torse, épaules, avant-bras et visage.
	var chest := _pivot(rig, "Chest", Vector3(0.0, 0.70, 0.0))
	Assets.part(chest, "capsule", metal if armor else cloth, Vector3(0, 0, 0), Vector3.ZERO, Vector3(1.18, 1.13, 0.94))
	Assets.box(chest, Vector3(0.34, 0.10, 0.31), leather, Vector3(0, -0.18, 0))
	Assets.box(chest, Vector3(0.25, 0.13, 0.032), team_color, Vector3(0, 0.05, 0.165))
	if armor:
		Assets.box(chest, Vector3(0.21, 0.22, 0.055), metal, Vector3(0, 0.04, 0.175))
	var neck := _pivot(chest, "Neck", Vector3(0, 0.245, 0))
	Assets.part(neck, "head", skin, Vector3(0, 0.10, 0), Vector3.ZERO, Vector3(1.1, 1.12, 0.98))
	var details := _pivot(rig, "MicroDetail", Vector3.ZERO)
	Assets.box(details, Vector3(0.055, 0.054, 0.058), skin, Vector3(0, 1.054, 0.116)) # nez
	Assets.box(details, Vector3(0.075, 0.017, 0.015), dark, Vector3(-0.055, 1.095, 0.104))
	Assets.box(details, Vector3(0.075, 0.017, 0.015), dark, Vector3(0.055, 1.095, 0.104))
	if helmet:
		Assets.part(neck, "helmet", metal if kind != "tireur" else dark, Vector3(0, 0.19, 0), Vector3.ZERO, Vector3(1.2, 0.92, 1.2))
		Assets.box(neck, Vector3(0.22, 0.035, 0.19), metal if kind != "tireur" else dark, Vector3(0, 0.18, 0.045))
	else:
		Assets.part(neck, "helmet", dark, Vector3(0, 0.19, -0.01), Vector3.ZERO, Vector3(1.05, 0.45, 1.0))
	# Les pivots d'épaule et de hanche permettent des animations sans squelette CPU lourd.
	for side in [-1, 1]:
		var side_name: String = "Left" if side < 0 else "Right"
		var shoulder := _pivot(chest, "Arm" + side_name, Vector3(float(side) * 0.205, 0.125, 0))
		Assets.part(shoulder, "leg", cloth, Vector3(0, -0.16, 0), Vector3.ZERO, Vector3(1.20, 1.05, 1.15))
		var elbow := _pivot(shoulder, "Elbow", Vector3(0, -0.29, 0))
		Assets.part(elbow, "leg", cloth, Vector3(0, -0.115, 0.008), Vector3.ZERO, Vector3(1.05, 0.81, 1.05))
		Assets.part(elbow, "head", skin, Vector3(0, -0.255, 0.005), Vector3.ZERO, Vector3(0.40, 0.52, 0.44))
		if armor:
			Assets.part(shoulder, "helmet", metal, Vector3(0, -0.005, 0), Vector3.ZERO, Vector3(0.8, 0.75, 0.95))
		if not mounted:
			var hip := _pivot(rig, "Leg" + side_name, Vector3(float(side) * 0.105, 0.48, 0))
			Assets.part(hip, "leg", cloth, Vector3(0, -0.135, 0), Vector3.ZERO, Vector3(1.24, 0.97, 1.15))
			var knee := _pivot(hip, "Knee", Vector3(0, -0.265, 0))
			Assets.part(knee, "leg", cloth, Vector3(0, -0.115, 0), Vector3.ZERO, Vector3(1.02, 0.77, 1.04))
			Assets.box(knee, Vector3(0.115, 0.085, 0.19), leather, Vector3(0, -0.258, 0.035))
	# L'outil/arme détaillé suit le coude droit : le modèle J2 reste présent
	# mais est masqué tant que le rig de proximité est affiché.
	var arm_right: Node3D = chest.get_node("ArmRight/Elbow") as Node3D
	if kind == "ouvrier":
		Assets.part(arm_right, "spear", leather, Vector3(0, -0.10, 0.18), Vector3(0.25, 0, 0), Vector3(0.76, 0.43, 0.76))
		Assets.box(arm_right, Vector3(0.19, 0.09, 0.20), metal, Vector3(0, -0.03, 0.52))
	elif kind == "lancier":
		Assets.part(arm_right, "spear", Assets.mat("j21f_wood", Color(0.25, 0.17, 0.10), 0.93), Vector3(0, 0.34, 0.11))
		Assets.part(arm_right, "bundle", metal, Vector3(0, 1.00, 0.11), Vector3.ZERO, Vector3(0.24, 0.66, 0.18))
	elif kind == "tireur":
		Assets.part(arm_right, "musket", leather, Vector3(0, -0.22, 0.37), Vector3(0.13, 0, 0))
		Assets.part(arm_right, "musket", metal, Vector3(0, -0.19, 0.67), Vector3(0.13, 0, 0), Vector3(0.62, 0.72, 0.62))
	elif kind == "cavalier":
		Assets.part(arm_right, "spear", leather, Vector3(0, -0.10, 0.48), Vector3(1.15, 0, 0))
	# Rôle, équipement et finitions (désactivables au LOD).
	if kind == "ouvrier":
		Assets.box(details, Vector3(0.23, 0.06, 0.12), leather, Vector3(0.0, 0.52, -0.17))
		Assets.box(details, Vector3(0.16, 0.16, 0.10), leather, Vector3(-0.19, 0.45, 0.0))
	elif kind == "lancier":
		Assets.box(details, Vector3(0.22, 0.26, 0.052), team_color, Vector3(-0.26, 0.61, 0.22))
	elif kind == "tireur":
		Assets.box(details, Vector3(0.19, 0.12, 0.06), leather, Vector3(-0.17, 0.60, 0.19))
	elif mounted:
		Assets.box(details, Vector3(0.35, 0.065, 0.35), leather, Vector3(0, 0.46, 0))
	return rig

static func enhance(root: Node3D, kind: String, team: int) -> void:
	var body: Node3D = root.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var mounted: bool = kind in ["cavalier", "eclaireur"]
	if kind == "canon":
		# Servant de pièce : même articulation mais à proximité du canon.
		var crew: Node3D = body.get_node_or_null("Crew") as Node3D
		if crew == null or crew.get_node_or_null("Rig") != null:
			return
		_human(crew, "tireur", team, false)
		for child in crew.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false
		return
	var figure: Node3D = body.get_node_or_null("Figure") as Node3D
	if figure == null or figure.get_node_or_null("Rig") != null:
		return
	_human(figure, "tireur" if kind in ["fusilier", "grenadier"] else kind, team, mounted)
	set_lod(root, true)

static func set_lod(root: Node3D, detailed: bool) -> void:
	var figure: Node3D = root.get_node_or_null("Body/Figure") as Node3D
	if figure == null:
		figure = root.get_node_or_null("Body/Crew") as Node3D
	if figure == null:
		return
	var rig: Node3D = figure.get_node_or_null("Rig") as Node3D
	if rig == null:
		return
	if rig.visible == detailed and bool(figure.get_meta("lod_configured", false)):
		return
	rig.visible = detailed
	var evolution_detail: Node3D = root.get_node_or_null("Body/EvolutionStyle") as Node3D
	if evolution_detail != null:
		evolution_detail.visible = detailed
	figure.set_meta("lod_configured", true)
	for c in figure.get_children():
		if c is MeshInstance3D and c.name != "Carry":
			(c as MeshInstance3D).visible = not detailed
		elif c.name == "Weapon":
			(c as Node3D).visible = not detailed
	# Le modèle et l'arme J2 sont préservés comme LOD éloigné.

static func animate(root: Node3D, kind: String, id: int, moving: bool, attacking: bool, working: bool, phase: float, clock: float) -> void:
	var rig: Node3D = root.get_node_or_null("Body/Figure/Rig") as Node3D
	if kind == "canon":
		rig = root.get_node_or_null("Body/Crew/Rig") as Node3D
	if rig == null or not rig.visible:
		return
	var cycle: float = phase + float(id) * 1.17
	var stride: float = 0.62 if moving else 0.0
	var chest: Node3D = rig.get_node("Chest") as Node3D
	chest.rotation.x = (0.045 + 0.035 * sin(cycle * 2.0)) if moving else 0.0
	if attacking or working:
		chest.rotation.x = -0.15
	for side in ["Left", "Right"]:
		var signv: float = 1.0 if side == "Left" else -1.0
		var arm: Node3D = chest.get_node("Arm" + side) as Node3D
		arm.rotation.x = sin(cycle) * stride * signv
		if attacking:
			arm.rotation.x = -0.70 if side == "Right" else 0.32
		elif working:
			arm.rotation.x = -0.6 + 0.5 * sin(clock * 5.0 + float(id)) if side == "Right" else 0.30
		var elbow: Node3D = arm.get_node("Elbow") as Node3D
		elbow.rotation.x = -0.17 if moving else 0.0
		var leg: Node3D = rig.get_node_or_null("Leg" + side) as Node3D
		if leg != null:
			leg.rotation.x = sin(cycle) * stride * -signv
			var knee: Node3D = leg.get_node("Knee") as Node3D
			knee.rotation.x = maxf(0.0, -sin(cycle) * signv) * 0.47 if moving else 0.0


static func set_evolution(root: Node3D, level: int) -> void:
	var body: Node3D = root.get_node_or_null("Body") as Node3D
	if body != null:
		TechAppearance.decorate(body, level, Vector3(0.0, 1.03, 0.08), 0.45)
