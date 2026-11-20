class_name CityOverlay
extends Node3D
## 0.18 — Vues de la ville au sol (un maillage, deux appels de dessin au plus) :
## chaque bâtiment urbain du joueur est teinté selon la vue choisie (vert = bien, orange = moyen, rouge = problème),
## et les rayons d'action des sources et services de la vue sont tracés. Pendant la pose d'une centrale, d'un château
## d'eau ou d'un service, le rayon apparaît sous le fantôme. Lecture seule : aucune règle ici.

const REFRESH := 0.25
const VIEWS := ["", "power", "water", "police", "fire", "health", "pollution", "happiness",
	"population", "density", "prosperity", "production", "state", "incidents", "infra", "zoning"]
const VIEW_LABEL := {"": "Aucune", "power": "Électricité", "water": "Eau", "police": "Criminalité", "fire": "Pompiers", "health": "Santé", "pollution": "Pollution", "happiness": "Bien-être",
	"population": "Population", "density": "Densité", "prosperity": "Prospérité", "production": "Production", "state": "État", "incidents": "Incidents",
	"infra": "Infrastructures", "zoning": "Zonage"}
## 0.20 — Filtres de la ville (activables d'un toucher dans le mode Zonage ou le panneau Ville). Les filtres « neutres »
## montrent une intensité (clair : peu, foncé : beaucoup), les autres vont du rouge (problème) au vert (bien).
const FILTERS := ["", "zoning", "population", "density", "police", "prosperity", "production", "pollution", "state", "incidents", "infra"]
const NEUTRAL := ["population", "density", "production"]
const VIEW_SOURCES := {"power": ["centrale", "centrale_solaire", "poste_electrique", "centre"], "water": ["chateau_eau", "station_pompage", "centre"],
	"police": ["commissariat"], "fire": ["caserne_pompiers"], "health": ["hopital"], "pollution": ["decharge", "recyclage"], "happiness": []}
const LEGEND := {"power": "vert : alimenté · orange : pénurie · rouge : hors réseau", "water": "vert : desservi · orange : pénurie · rouge : hors réseau",
	"police": "vert : sûr · rouge : criminalité élevée", "fire": "vert : couvert par les pompiers · rouge : non couvert · clignote : en feu",
	"health": "vert : bonne santé · rouge : quartier malade", "pollution": "vert : air sain · rouge : pollué", "happiness": "vert : heureux · rouge : mécontent",
	"population": "foncé : beaucoup d'habitants · clair : peu", "density": "foncé : quartier dense · clair : peu dense",
	"prosperity": "vert : riche · rouge : pauvre", "production": "foncé : produit beaucoup · clair : peu ou rien",
	"state": "vert : prospère ou en état · orange : dégradé, chantier · rouge : abandonné, brûlé, en ruine",
	"incidents": "rouge : feu, émeute, inondation · orange : touché récemment · vert : calme",
	"infra": "vert : route reliée et services · rouge : sans route ni services", "zoning": "couleurs des zones peintes (calque du mode Zonage)"}
var game
var mesh: ImmediateMesh
var view: String = ""
var _t: float = 0.0
var quads: int = 0
var circles: int = 0

func setup(p_game) -> void:
	game = p_game
	name = "CityOverlay"
	mesh = ImmediateMesh.new()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 3
	# 0.20 : les teintes restent lisibles par-dessus les bâtiments (filtre de carte), comme un calque.
	material.no_depth_test = true
	instance.material_override = material
	add_child(instance)

func set_view(key: String) -> void:
	view = key if VIEWS.has(key) else ""
	_t = REFRESH
	# Filtre « Zonage » : le calque coloré du terrain, hors du mode Zonage aussi.
	if game != null and game.view != null and not (game.zoning_tool != null and game.zoning_tool.active):
		game.view.set_overlay(1 if view == "zoning" else 0)

func _process(delta: float) -> void:
	_t += delta
	if _t < REFRESH:
		return
	_t = 0.0
	rebuild()

func _placing_key() -> String:
	var kind: String = String(game.place_type) if String(game.mode) == "place" else ""
	if kind == "":
		return ""
	for key in VIEW_SOURCES.keys():
		if (VIEW_SOURCES[key] as Array).has(kind):
			return String(key)
	if UrbanRules.is_zone(kind):
		return "power"
	return ""

static func reach_of(kind: String, key: String) -> float:
	match key:
		"power":
			if UrbanRules.POWER_SOURCES.has(kind): return float(UrbanRules.POWER_SOURCES[kind]["reach"])
			if UrbanRules.RELAY.has(kind): return float(UrbanRules.RELAY[kind])
		"water":
			if UrbanRules.WATER_SOURCES.has(kind): return float(UrbanRules.WATER_SOURCES[kind]["reach"])
		_:
			if UrbanRules.SERVICES.has(kind): return float(UrbanRules.SERVICES[kind]["reach"])
	return 0.0

static func value_of(b: SimWorld.Building, key: String) -> float:
	## 0 = problème, 1 = bien ; -1 = sans objet pour cette vue.
	var c: Dictionary = b.city
	match key:
		"power":
			if not UrbanRules.POWER_USE.has(b.type) and not UrbanRules.RELAY.has(b.type): return -1.0
			return 1.0 if bool(c.get("powered", false)) else (0.5 if bool(c.get("powered_grid", false)) else 0.0)
		"water":
			if not UrbanRules.WATER_USE.has(b.type): return -1.0
			return 1.0 if bool(c.get("watered", false)) else (0.5 if bool(c.get("watered_grid", false)) else 0.0)
		"police":
			if not UrbanRules.is_zone(b.type): return -1.0
			return 1.0 - float(c.get("crime", 0.0)) / 100.0
		"fire":
			return 1.0 if bool(c.get("fire", false)) else 0.0
		"health":
			if b.type != "zone_r": return -1.0
			return float(c.get("health_v", 100.0)) / 100.0
		"pollution":
			return 1.0 - float(c.get("pollution", 0.0)) / 100.0
		"happiness":
			if not UrbanRules.is_zone(b.type): return -1.0
			return float(c.get("happiness", 50.0)) / 100.0
		"population":
			if b.type != "zone_r": return -1.0
			return clampf(float(c.get("habitants", 0)) / float(UrbanRules.HABITANTS_PER_LEVEL * 4), 0.0, 1.0)
		"density":
			if not UrbanRules.is_zone(b.type): return -1.0
			return clampf(float(c.get("density", 0.0)) / float(UrbanRules.LEVEL_MAX), 0.0, 1.0)
		"prosperity":
			if not UrbanRules.is_zone(b.type): return -1.0
			return float(c.get("wealth", 40.0)) / 100.0
		"production":
			if not UrbanRules.OUTPUT.has(b.type): return -1.0
			var total: float = 0.0
			for v in (c.get("out", {}) as Dictionary).values():
				total += float(v)
			return clampf(total / 1.5, 0.0, 1.0)
		"state":
			if b.type == "ruine": return 0.0
			if not UrbanRules.is_zone(b.type): return -1.0
			return float(STATE_VALUE.get(String(c.get("state", "operational")), 0.7))
		"incidents":
			if b.type == "ruine": return 0.1
			if not UrbanRules.is_zone(b.type) and not UrbanRules.is_urban(b.type): return -1.0
			if float(c.get("burning", 0.0)) > 0.0 or String(c.get("riot", "")) != "" or float(c.get("flooded", 0.0)) > 0.0: return 0.0
			if b.hp < b.max_hp * 0.75 or float(c.get("crime", 0.0)) >= 55.0: return 0.45
			return 1.0
		"infra":
			if not UrbanRules.is_zone(b.type): return -1.0
			var score: float = 0.4 if UrbanZoning.access(b_world, b.team, b.cell, b.size) else 0.0
			for service in ["police", "fire", "health", "waste"]:
				score += 0.15 if bool(c.get(service, false)) else 0.0
			return clampf(score, 0.0, 1.0)
	return -1.0

const STATE_VALUE := {"prosperous": 1.0, "operational": 0.8, "construction": 0.55, "reconstruction": 0.5, "degraded": 0.35,
	"damaged": 0.25, "abandoned": 0.1, "burning": 0.0, "burnt": 0.0}
## Monde lu par la vue « infrastructures » (lecture seule, fixé avant chaque reconstruction).
static var b_world: SimWorld = null

static func neutral_tint(v: float) -> Color:
	var low: Color = AgeTheme.SEMANTIC["info"]
	return low.lerp(low.darkened(0.78), clampf(v, 0.0, 1.0))

static func tint(v: float) -> Color:
	var bad: Color = AgeTheme.SEMANTIC["danger"]
	var mid: Color = AgeTheme.SEMANTIC["warning"]
	var good: Color = AgeTheme.SEMANTIC["success"]
	return bad.lerp(mid, v * 2.0) if v < 0.5 else mid.lerp(good, (v - 0.5) * 2.0)

func rebuild() -> void:
	mesh.clear_surfaces()
	quads = 0
	circles = 0
	var key: String = view
	var placing: String = _placing_key()
	if key == "" and placing != "":
		key = placing
	if key == "" or game.world == null:
		return
	var w: SimWorld = game.world
	b_world = w
	if key == "zoning":
		return
	var tris: Array = []
	var lines: Array = []
	var blink: bool = int(Time.get_ticks_msec() / 300) % 2 == 0
	for candidate in w.team_buildings(game.player, "", true):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.is_urban(b.type) or b.type == "ruine":
			var v: float = value_of(b, key)
			if v >= 0.0:
				var color: Color = neutral_tint(v) if NEUTRAL.has(key) else tint(clampf(v, 0.0, 1.0))
				if key == "fire" and float(b.city.get("burning", 0.0)) > 0.0:
					color = AgeTheme.SEMANTIC["danger"] if blink else Color(1, 1, 1)
				color.a = 0.68
				_square(tris, b, color)
		if (VIEW_SOURCES.get(key, []) as Array).has(b.type):
			var r: float = reach_of(b.type, key)
			if r > 0.0:
				_circle(lines, b.center, r + 0.5, Color(AgeTheme.SEMANTIC["info"], 0.8))
	if placing != "" and String(game.mode) == "place":
		var size: int = int(Rules.BUILDINGS[game.place_type]["size"])
		var center: Vector2 = Vector2(game.place_cell) + Vector2(size, size) * 0.5
		var r2: float = reach_of(String(game.place_type), key)
		if r2 > 0.0:
			_circle(lines, center, r2 + 0.5, Color(AgeTheme.SEMANTIC["success"], 0.95))
	if not tris.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for t in tris:
			mesh.surface_set_color(t[1])
			mesh.surface_add_vertex(t[0])
		mesh.surface_end()
	if not lines.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for l in lines:
			mesh.surface_set_color(l[2])
			mesh.surface_add_vertex(l[0])
			mesh.surface_set_color(l[2])
			mesh.surface_add_vertex(l[1])
		mesh.surface_end()

func _square(tris: Array, b: SimWorld.Building, color: Color) -> void:
	var a: Vector2 = Vector2(b.cell) + Vector2(0.1, 0.1)
	var s: float = float(b.size) - 0.2
	var y: float = 0.12
	var p0 := Vector3(a.x, y, a.y)
	var p1 := Vector3(a.x + s, y, a.y)
	var p2 := Vector3(a.x + s, y, a.y + s)
	var p3 := Vector3(a.x, y, a.y + s)
	for p in [p0, p1, p2, p0, p2, p3]:
		tris.append([p, color])
	quads += 1

func _circle(lines: Array, center: Vector2, radius: float, color: Color) -> void:
	var segments: int = 48
	for i in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		lines.append([Vector3(center.x + cos(a0) * radius, 0.16, center.y + sin(a0) * radius), Vector3(center.x + cos(a1) * radius, 0.16, center.y + sin(a1) * radius), color])
	circles += 1
