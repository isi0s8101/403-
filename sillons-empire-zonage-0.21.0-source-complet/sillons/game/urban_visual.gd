class_name UrbanVisual
extends RefCounted
## 0.19 — Apparence des bâtiments qui poussent sur les zones : composée selon la catégorie, le niveau, l'âge de
## construction, la variante, l'orientation et l'état. Modèles de la bibliothèque (un par âge et par catégorie)
## assemblés avec des volumes simples partagés (annexes, étages, cheminées, champs, échafaudages, planches, gravats) :
## un changement de niveau remplace réellement la silhouette, pas seulement une couleur.

static var _unit_box: BoxMesh
static var _unit_cyl: CylinderMesh

static func _box_mesh() -> BoxMesh:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	return _unit_box

static func _cyl_mesh() -> CylinderMesh:
	if _unit_cyl == null:
		_unit_cyl = CylinderMesh.new()
		_unit_cyl.top_radius = 0.5
		_unit_cyl.bottom_radius = 0.5
		_unit_cyl.height = 1.0
		_unit_cyl.radial_segments = 10
	return _unit_cyl

static func _block(parent: Node3D, size: Vector3, color: Color, pos: Vector3, key: String = "", rough: float = 0.85, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh()
	mi.scale = size
	mi.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
	mi.material_override = Assets.mat("urban_" + (key if key != "" else color.to_html(false)), color, rough, metal)
	parent.add_child(mi)
	return mi

static func _tube(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3, key: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl_mesh()
	mi.scale = Vector3(radius * 2.0, height, radius * 2.0)
	mi.position = pos + Vector3(0.0, height * 0.5, 0.0)
	mi.material_override = Assets.mat("urban_" + (key if key != "" else color.to_html(false)), color, 0.8, 0.1)
	parent.add_child(mi)
	return mi

static func _model(parent: Node3D, family: String, age: int, cells: float, pos: Vector3, rot: float, team: int, lod: int) -> Node3D:
	## Modèle de la bibliothèque de l'âge demandé (ou du plus proche disponible), mis à l'échelle en cases.
	var category: String = "building_" + family if family in ["residential", "commercial", "industrial"] else "building_special"
	var id: String = AssetLibrary.find(category, family, clampi(age, 1, 10))
	if id.is_empty():
		return null
	var model: Node3D = AssetLibrary.instantiate_compact(id, lod)
	if model == null:
		return null
	model.scale = Vector3.ONE * AssetLibrary.scale_for_cells(id, cells)
	model.position = pos
	model.rotation.y = rot
	AssetLibrary.set_team_color(model, Assets.TEAM_COLORS[clampi(team, 0, 2)])
	parent.add_child(model)
	return model

## 0.20 — Une palette par âge (et non plus par paire d'âges) : chaume, bois, pierre, colombages, brique, brique
## industrielle, béton, béton blanc et verre, verre et acier, blanc futuriste. Les modèles de la bibliothèque
## changent tous les deux âges ; palette et toitures d'époque (`_crown`) distinguent chacun des 10 âges.
const ERA := [
	{"wall": Color(0.60, 0.47, 0.30), "roof": Color(0.74, 0.63, 0.36), "trim": Color(0.42, 0.30, 0.18), "glass": Color(0.30, 0.26, 0.20)},  # I chaume
	{"wall": Color(0.50, 0.36, 0.23), "roof": Color(0.44, 0.33, 0.22), "trim": Color(0.32, 0.22, 0.14), "glass": Color(0.28, 0.25, 0.21)},  # II bois
	{"wall": Color(0.70, 0.66, 0.58), "roof": Color(0.56, 0.28, 0.20), "trim": Color(0.46, 0.42, 0.36), "glass": Color(0.24, 0.27, 0.30)},  # III pierre, tuiles
	{"wall": Color(0.82, 0.76, 0.62), "roof": Color(0.33, 0.35, 0.40), "trim": Color(0.36, 0.25, 0.16), "glass": Color(0.26, 0.32, 0.38)},  # IV colombages, ardoise
	{"wall": Color(0.66, 0.34, 0.25), "roof": Color(0.28, 0.27, 0.27), "trim": Color(0.82, 0.78, 0.70), "glass": Color(0.30, 0.40, 0.48)},  # V brique
	{"wall": Color(0.48, 0.27, 0.22), "roof": Color(0.20, 0.20, 0.21), "trim": Color(0.16, 0.16, 0.17), "glass": Color(0.32, 0.44, 0.50)},  # VI brique industrielle
	{"wall": Color(0.74, 0.70, 0.62), "roof": Color(0.46, 0.46, 0.46), "trim": Color(0.25, 0.26, 0.28), "glass": Color(0.34, 0.52, 0.64)},  # VII béton
	{"wall": Color(0.86, 0.86, 0.84), "roof": Color(0.38, 0.41, 0.46), "trim": Color(0.20, 0.30, 0.45), "glass": Color(0.36, 0.62, 0.80)},  # VIII béton blanc, verre
	{"wall": Color(0.62, 0.68, 0.74), "roof": Color(0.30, 0.48, 0.30), "trim": Color(0.55, 0.60, 0.66), "glass": Color(0.42, 0.76, 0.90)},  # IX verre et acier, toits verts
	{"wall": Color(0.93, 0.95, 0.98), "roof": Color(0.70, 0.74, 0.82), "trim": Color(0.25, 0.80, 0.95), "glass": Color(0.50, 0.90, 1.00)},  # X futuriste
]

static func era_palette(age: int) -> Dictionary:
	return ERA[clampi(age, 1, 10) - 1] as Dictionary

static func _crown(body: Node3D, age: int, pal: Dictionary, top: float, width: float) -> void:
	## Toiture d'époque posée sur un volume : chaque âge a sa signature (cheminées, château d'eau, antennes,
	## panneaux, jardins, anneau lumineux).
	var w: float = width
	match clampi(age, 1, 10):
		1, 2:
			_block(body, Vector3(w * 0.9, 0.18, w * 0.5), pal["roof"], Vector3(0, top, 0), "crown_roof%d" % age)
			_block(body, Vector3(w * 0.6, 0.14, w * 0.3), pal["roof"], Vector3(0, top + 0.18, 0), "crown_roof%d" % age)
		3:
			_block(body, Vector3(w * 0.8, 0.22, w * 0.6), pal["roof"], Vector3(0, top, 0), "crown_roof3")
			_block(body, Vector3(0.12, 0.35, 0.12), pal["trim"], Vector3(w * 0.3, top, w * 0.15), "crown_trim3")
		4:
			for k in 2:
				_block(body, Vector3(0.1, 0.32, 0.1), pal["trim"], Vector3(-w * 0.3 + w * 0.6 * float(k), top, 0.0), "crown_trim4")
			_block(body, Vector3(w * 0.85, 0.16, w * 0.7), pal["roof"], Vector3(0, top, 0), "crown_roof4")
		5:
			_tube(body, 0.18, 0.35, pal["trim"], Vector3(w * 0.25, top, w * 0.2), "crown_tank5")
			_tube(body, 0.22, 0.08, pal["roof"], Vector3(w * 0.25, top + 0.35, w * 0.2), "crown_tankroof5")
		6:
			_tube(body, 0.09, 0.9, pal["trim"], Vector3(-w * 0.3, top, w * 0.25), "crown_stack6")
			_tube(body, 0.09, 0.7, pal["trim"], Vector3(-w * 0.1, top, w * 0.25), "crown_stack6")
		7:
			_block(body, Vector3(0.04, 0.9, 0.04), pal["trim"], Vector3(w * 0.25, top, 0.0), "crown_mast7")
			_tube(body, 0.16, 0.04, pal["roof"], Vector3(-w * 0.2, top + 0.12, w * 0.15), "crown_dish7")
		8:
			for k in 3:
				_block(body, Vector3(w * 0.22, 0.04, w * 0.5), Color(0.12, 0.18, 0.32), Vector3(-w * 0.3 + w * 0.3 * float(k), top + 0.03, 0.0), "crown_solar8", 0.3, 0.4)
		9:
			_block(body, Vector3(w * 0.85, 0.06, w * 0.85), pal["roof"], Vector3(0, top, 0), "crown_garden9")
			for k in 3:
				_tube(body, 0.12, 0.28, Color(0.22, 0.45, 0.22), Vector3(-w * 0.25 + w * 0.25 * float(k), top + 0.06, w * 0.1 * float(k % 2)), "crown_tree9")
		10:
			_tube(body, w * 0.45, 0.06, pal["trim"], Vector3(0, top + 0.15, 0), "crown_ring10")
			_block(body, Vector3(0.05, 0.8, 0.05), pal["glass"], Vector3(0, top, 0), "crown_spire10", 0.2, 0.5)

static func signature(b: SimWorld.Building) -> String:
	## Ce qui change la silhouette (une transition d'état visible reconstruit la composition).
	var c: Dictionary = b.city
	var state: String = String(c.get("state", "operational"))
	if not state in ["prosperous", "degraded", "abandoned", "burnt"]:
		state = "normal"
	var closed: bool = b.type == "zone_c" and (state == "abandoned" or float(c.get("crime", 0.0)) >= UrbanRules.CRIME_DEGRADE)
	var riot: bool = String(c.get("riot", "")) != ""
	return "%s|%d|%d|%d|%d|%s|%s|%s" % [b.type, int(c.get("level", 1)), int(c.get("style_age", 1)), int(c.get("variant", 0)) % 4,
		int(c.get("rot", 0)), state, "f" if closed else "o", "r" if riot else "-"]

static func build(b: SimWorld.Building, lod: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "UrbanModel"
	var c: Dictionary = b.city
	var level: int = clampi(int(c.get("level", 1)), 1, 6)
	var age: int = clampi(int(c.get("style_age", 1)), 1, 10)
	var variant: int = int(c.get("variant", 0))
	var rot: float = float(int(c.get("rot", 0))) * PI * 0.5
	var pal: Dictionary = era_palette(age)
	var body := Node3D.new()
	body.name = "Body"
	body.rotation.y = rot
	body.position = Vector3(float((variant >> 2) % 3 - 1) * 0.08, 0.0, float((variant >> 4) % 3 - 1) * 0.08)
	root.add_child(body)
	match b.type:
		"ruine":
			_ruins(body, c, pal, variant)
			return root
		"zone_r":
			_residential(body, b.team, level, age, variant, pal, lod)
		"zone_c":
			_commercial(body, b.team, level, age, variant, pal, lod)
		"zone_i":
			_industrial(body, b.team, level, age, variant, pal, lod)
		"zone_a":
			_farm(body, b.team, level, age, variant, pal, lod)
	_state_details(root, b, pal, variant)
	return root

# ---------------------------------------------------------------- catégories

static func _residential(body: Node3D, team: int, level: int, age: int, variant: int, pal: Dictionary, lod: int) -> void:
	var older: int = maxi(1, age - 1) if variant % 2 == 1 else age
	match level:
		1:   # habitation rudimentaire : petite maison et appentis
			_model(body, "residential", older, 1.15, Vector3(-0.18, 0, -0.1), 0.0, team, lod)
			_block(body, Vector3(0.55, 0.32, 0.45), pal["wall"], Vector3(0.55, 0, 0.5))
			_block(body, Vector3(0.6, 0.06, 0.5), pal["roof"], Vector3(0.55, 0.32, 0.5))
		2:   # habitation améliorée : maison principale et annexe
			_model(body, "residential", age, 1.45, Vector3(-0.12, 0, -0.1), 0.0, team, lod)
			_model(body, "residential", older, 0.85, Vector3(0.62, 0, 0.55), PI * 0.5, team, lod)
		3:   # quartier structuré : deux maisons, muret, cour
			_model(body, "residential", age, 1.0, Vector3(-0.45, 0, -0.35), 0.0, team, lod)
			_model(body, "residential", older, 1.0, Vector3(0.45, 0, 0.35), PI, team, lod)
			_block(body, Vector3(1.8, 0.14, 0.08), pal["trim"], Vector3(0, 0, 0.92))
			_block(body, Vector3(0.08, 0.14, 1.8), pal["trim"], Vector3(-0.92, 0, 0))
		4:   # habitat dense : immeuble à étages sur un socle
			_block(body, Vector3(1.6, 1.5, 1.2), pal["wall"], Vector3(0, 0, 0))
			for floor in 3:
				_block(body, Vector3(1.62, 0.12, 1.22), pal["glass"], Vector3(0, 0.3 + 0.42 * float(floor), 0), "glass%d" % age, 0.3)
			_block(body, Vector3(1.7, 0.1, 1.3), pal["roof"], Vector3(0, 1.5, 0))
			_model(body, "residential", age, 0.7, Vector3(0.62, 1.6, 0.25), 0.0, team, lod)
			_crown(body, age, pal, 1.6, 1.0)
		5:   # architecture avancée : tour à gradins
			_block(body, Vector3(1.6, 1.2, 1.6), pal["wall"], Vector3(0, 0, 0))
			_block(body, Vector3(1.2, 1.1, 1.2), pal["glass"], Vector3(0, 1.2, 0), "glass%d" % age, 0.25, 0.2)
			_block(body, Vector3(0.8, 0.8, 0.8), pal["wall"], Vector3(0, 2.3, 0))
			_block(body, Vector3(0.06, 0.7, 0.06), pal["trim"], Vector3(0.2, 3.1, 0.2))
			_crown(body, age, pal, 3.1, 0.8)
		_:   # habitat futuriste : tour élancée et anneau
			_tube(body, 0.55, 3.4, pal["glass"], Vector3(0, 0, 0), "glass%d" % age)
			_tube(body, 0.85, 0.12, pal["trim"], Vector3(0, 2.2, 0), "trim%d" % age)
			_tube(body, 0.7, 0.1, pal["trim"], Vector3(0, 1.2, 0), "trim%d" % age)
			_block(body, Vector3(1.8, 0.25, 1.8), pal["wall"], Vector3(0, 0, 0))
			_crown(body, age, pal, 3.4, 1.0)

static func _commercial(body: Node3D, team: int, level: int, age: int, variant: int, pal: Dictionary, lod: int) -> void:
	var awnings: Array = [Color(0.80, 0.25, 0.20), Color(0.20, 0.45, 0.75), Color(0.90, 0.70, 0.20), Color(0.30, 0.60, 0.30)]
	match level:
		1:   # étals et marché
			for k in 3:
				var x: float = -0.6 + 0.6 * float(k)
				_block(body, Vector3(0.45, 0.28, 0.4), pal["trim"], Vector3(x, 0, 0.1))
				_block(body, Vector3(0.52, 0.05, 0.5), awnings[(variant + k) % 4], Vector3(x, 0.42, 0.1), "awning%d" % ((variant + k) % 4))
		2:   # petits commerces : boutique et auvent
			_model(body, "commercial", age, 1.4, Vector3(0, 0, -0.15), 0.0, team, lod)
			_block(body, Vector3(1.3, 0.05, 0.35), awnings[variant % 4], Vector3(0, 0.45, 0.72), "awning%d" % (variant % 4))
		3:   # galerie marchande
			_model(body, "commercial", age, 1.15, Vector3(-0.42, 0, 0), 0.0, team, lod)
			_model(body, "commercial", maxi(1, age - 1), 0.95, Vector3(0.5, 0, 0.1), PI, team, lod)
			_block(body, Vector3(1.9, 0.06, 0.4), pal["glass"], Vector3(0, 0.62, 0.78), "glass%d" % age, 0.3)
		4:   # quartier commercial : grand bloc et enseigne
			_block(body, Vector3(1.8, 1.1, 1.5), pal["wall"], Vector3(0, 0, 0))
			_block(body, Vector3(1.82, 0.35, 1.52), pal["glass"], Vector3(0, 0.15, 0), "glass%d" % age, 0.25)
			_block(body, Vector3(0.9, 0.3, 0.06), awnings[variant % 4], Vector3(0, 1.15, 0.72), "awning%d" % (variant % 4))
			_crown(body, age, pal, 1.1, 1.6)
		_:   # centre économique : tour de verre
			_block(body, Vector3(1.7, 0.5, 1.7), pal["wall"], Vector3(0, 0, 0))
			_block(body, Vector3(1.1, 2.6, 1.1), pal["glass"], Vector3(0, 0.5, 0), "glass%d" % age, 0.2, 0.3)
			_block(body, Vector3(0.7, 0.4, 0.7), pal["trim"], Vector3(0, 3.1, 0))
			_crown(body, age, pal, 3.5, 0.9)

static func _industrial(body: Node3D, team: int, level: int, age: int, variant: int, pal: Dictionary, lod: int) -> void:
	var smoke_col: Color = Color(0.35, 0.33, 0.32)
	match level:
		1:   # artisanat : atelier et tas de bois
			_model(body, "industrial", age, 1.1, Vector3(-0.2, 0, -0.15), 0.0, team, lod)
			for k in 3:
				_tube(body, 0.08, 0.6, Color(0.45, 0.30, 0.18), Vector3(0.55, 0.08 + 0.16 * float(k), 0.55), "log")
		2:   # ateliers : bâtiment et cheminée
			_model(body, "industrial", age, 1.45, Vector3(-0.1, 0, 0), 0.0, team, lod)
			_tube(body, 0.12, 1.4, pal["trim"], Vector3(0.65, 0, -0.6), "chimney%d" % age)
		3:   # manufactures : halle, deux cheminées, cour
			_model(body, "industrial", age, 1.3, Vector3(-0.25, 0, 0), 0.0, team, lod)
			_tube(body, 0.12, 1.7, pal["trim"], Vector3(0.6, 0, -0.6), "chimney%d" % age)
			_tube(body, 0.1, 1.3, pal["trim"], Vector3(0.6, 0, 0.1), "chimney%d" % age)
			_block(body, Vector3(0.6, 0.25, 0.6), smoke_col, Vector3(0.55, 0, 0.65), "crate")
		4:   # industrie lourde : longue halle, réservoir, cheminées
			_block(body, Vector3(1.8, 0.9, 1.1), pal["wall"], Vector3(0, 0, -0.3))
			_block(body, Vector3(1.85, 0.12, 1.15), pal["roof"], Vector3(0, 0.9, -0.3))
			_tube(body, 0.35, 0.8, Color(0.6, 0.6, 0.62), Vector3(-0.5, 0, 0.6), "tank")
			_tube(body, 0.14, 2.0, pal["trim"], Vector3(0.7, 0, 0.6), "chimney%d" % age)
		_:   # industrie automatisée : dômes, réservoirs, convoyeur
			_model(body, "industrial", age, 1.1, Vector3(-0.35, 0, -0.3), 0.0, team, lod)
			_tube(body, 0.32, 0.9, pal["glass"], Vector3(0.55, 0, -0.45), "glass%d" % age)
			_tube(body, 0.32, 0.9, pal["glass"], Vector3(0.55, 0, 0.35), "glass%d" % age)
			_block(body, Vector3(1.6, 0.12, 0.2), pal["trim"], Vector3(0, 0.55, 0.8), "trim%d" % age)

static func _farm(body: Node3D, team: int, level: int, age: int, variant: int, pal: Dictionary, lod: int) -> void:
	var crops: Array = [Color(0.45, 0.62, 0.22), Color(0.80, 0.70, 0.30), Color(0.38, 0.55, 0.20)]
	var rows: int = 4 if level == 1 else 3
	for k in rows:
		_block(body, Vector3(1.8, 0.06, 0.32), crops[(variant + k) % 3], Vector3(0, 0, -0.75 + 0.42 * float(k)), "crop%d" % ((variant + k) % 3))
	if level >= 2:
		_model(body, "warehouse", age, 0.85, Vector3(0.55, 0, 0.55), 0.0, team, lod)
	else:
		_block(body, Vector3(0.4, 0.35, 0.4), pal["wall"], Vector3(0.7, 0, 0.7))
	if level >= 3:
		_tube(body, 0.22, 1.1, Color(0.70, 0.70, 0.66), Vector3(-0.65, 0, 0.65), "silo")
		if age >= 7:
			_block(body, Vector3(0.7, 0.4, 0.45), pal["glass"], Vector3(-0.3, 0, 0.7), "glass%d" % age, 0.2)

static func _ruins(body: Node3D, c: Dictionary, pal: Dictionary, variant: int) -> void:
	var dark: Color = Color(0.20, 0.18, 0.17)
	_block(body, Vector3(1.8, 0.06, 1.8), Color(0.28, 0.25, 0.22), Vector3(0, 0, 0), "rubble_floor")
	_block(body, Vector3(1.2, 0.5, 0.12), dark, Vector3(-0.2, 0, -0.6), "rubble_dark")
	_block(body, Vector3(0.12, 0.35, 0.9), dark, Vector3(0.6, 0, 0.0), "rubble_dark")
	for k in 4:
		var x: float = -0.6 + 0.4 * float(k)
		_block(body, Vector3(0.3, 0.12 + 0.05 * float((variant + k) % 3), 0.25), pal["wall"].darkened(0.5), Vector3(x, 0, 0.45 - 0.2 * float(k % 2)), "rubble_%d" % (k % 2))

# ---------------------------------------------------------------- états visibles

static func _state_details(root: Node3D, b: SimWorld.Building, pal: Dictionary, variant: int) -> void:
	var c: Dictionary = b.city
	var state: String = String(c.get("state", "operational"))
	var details := Node3D.new()
	details.name = "State"
	root.add_child(details)
	match state:
		"prosperous":
			_tube(details, 0.18, 0.35, Color(0.25, 0.55, 0.25), Vector3(-0.8, 0, 0.8), "bush")
			_tube(details, 0.15, 0.3, Color(0.25, 0.55, 0.25), Vector3(0.8, 0, -0.8), "bush")
			_block(details, Vector3(0.03, 0.6, 0.03), Color(0.85, 0.85, 0.85), Vector3(0.85, 0, 0.85), "pole")
			_block(details, Vector3(0.22, 0.14, 0.02), Assets.TEAM_COLORS[clampi(b.team, 0, 2)], Vector3(0.96, 0.46, 0.85), "flag%d" % b.team)
		"degraded":
			for k in 3:
				_block(details, Vector3(0.22, 0.1, 0.18), Color(0.25, 0.23, 0.2), Vector3(-0.7 + 0.5 * float(k), 0, 0.85), "debris")
			_block(details, Vector3(0.6, 0.25, 0.03), Color(0.30, 0.18, 0.30), Vector3(0.3, 0.05, 0.93), "tag")
		"abandoned":
			for k in 3:
				_block(details, Vector3(0.9, 0.06, 0.04), Color(0.35, 0.24, 0.14), Vector3(0, 0.2 + 0.14 * float(k), 0.95), "plank")
			_block(details, Vector3(0.04, 0.5, 0.9), Color(0.35, 0.24, 0.14), Vector3(0.95, 0, 0), "plank")
		"burnt":
			_block(details, Vector3(1.9, 0.04, 1.9), Color(0.08, 0.07, 0.07), Vector3(0, 0, 0), "char")
			_block(details, Vector3(0.9, 0.7, 0.9), Color(0.10, 0.09, 0.09), Vector3(0.2, 0, -0.1), "char")
	if b.type == "zone_c" and (state == "abandoned" or float(c.get("crime", 0.0)) >= UrbanRules.CRIME_DEGRADE):
		_block(details, Vector3(1.4, 0.4, 0.04), Color(0.45, 0.47, 0.50), Vector3(0, 0.02, 0.98), "shutter")
	if String(c.get("riot", "")) != "":
		for k in 4:
			var ang: float = float(k) * PI * 0.5 + 0.4
			_block(details, Vector3(0.5, 0.25, 0.15), Color(0.32, 0.28, 0.24), Vector3(cos(ang) * 1.1, 0, sin(ang) * 1.1), "barricade", 0.9).rotation.y = ang
