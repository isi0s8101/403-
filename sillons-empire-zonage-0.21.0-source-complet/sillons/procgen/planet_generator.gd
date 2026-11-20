class_name PlanetGenerator
extends RefCounted
## J9-A : planète reproductible. Données pures : aucune dépendance à la caméra ou au tick.
## Longitude en radians [-PI,PI], latitude [-PI/2,PI/2]. Un échantillon à +/-PI est identique.
const GENERATOR_VERSION: int = 1
## Graine spéciale : la vraie Terre (données réelles, voir earth_data.gd). Toute autre graine reste procédurale.
const EARTH_SEED: int = 1789
const ATLAS_W: int = 512
const ATLAS_H: int = 256
const OCEAN: int = 0
const COAST: int = 1
const PLAINS: int = 2
const FOREST: int = 3
const DESERT: int = 4
const TUNDRA: int = 5
const MOUNTAIN: int = 6
const BIOME_NAMES := ["Océan", "Littoral", "Plaines", "Forêt", "Désert", "Toundra", "Montagnes"]
const BIOME_COLORS := [Color("183f68"), Color("b8b891"), Color("65975d"), Color("28744e"), Color("bc945e"), Color("8299a4"), Color("aaa8a1")]

var seed: int = 1
var _earth: bool = false
var _continental: FastNoiseLite
var _detail: FastNoiseLite
var _humidity: FastNoiseLite

func _init(p_seed: int = 1) -> void:
	seed = p_seed
	_earth = p_seed == EARTH_SEED and EarthData.available()
	_continental = FastNoiseLite.new()
	_continental.seed = posmod(seed, 2147483647)
	_continental.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continental.frequency = 0.88
	_continental.fractal_type = FastNoiseLite.FRACTAL_FBM
	_continental.fractal_octaves = 4
	_continental.fractal_gain = 0.51
	_detail = FastNoiseLite.new()
	_detail.seed = posmod(seed + 982451653, 2147483647)
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 4.1
	_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail.fractal_octaves = 3
	_humidity = FastNoiseLite.new()
	_humidity.seed = posmod(seed + 26544357, 2147483647)
	_humidity.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_humidity.frequency = 2.3

static func sphere_direction(lon: float, lat: float) -> Vector3:
	var c: float = cos(lat)
	return Vector3(c * cos(lon), sin(lat), c * sin(lon))

func is_earth() -> bool:
	return _earth

func sample(lon: float, lat: float) -> Dictionary:
	if _earth:
		return EarthData.sample(lon, lat)
	var d: Vector3 = sphere_direction(lon, clampf(lat, -PI * 0.5, PI * 0.5))
	var continental: float = _continental.get_noise_3dv(d * 2.5)
	var detail: float = _detail.get_noise_3dv(d * 3.4)
	var height: float = continental * 0.82 + detail * 0.18 - 0.025
	var humidity: float = 0.5 + 0.5 * _humidity.get_noise_3dv(d * 2.2)
	var temperature: float = clampf(1.0 - absf(lat) / (PI * 0.5), 0.0, 1.0)
	var biome: int = PLAINS
	if height < -0.04:
		biome = OCEAN
	elif height < 0.018:
		biome = COAST
	elif height > 0.35:
		biome = MOUNTAIN
	elif temperature < 0.26:
		biome = TUNDRA
	elif temperature > 0.53 and humidity < 0.39:
		biome = DESERT
	elif humidity > 0.54:
		biome = FOREST
	return {"height": height, "humidity": humidity, "temperature": temperature, "biome": biome}

func atlas_coords(lon: float, lat: float) -> Vector2i:
	var x: int = posmod(int(floor((lon + PI) / TAU * float(ATLAS_W))), ATLAS_W)
	var y: int = clampi(int(floor((PI * 0.5 - lat) / PI * float(ATLAS_H))), 0, ATLAS_H - 1)
	return Vector2i(x, y)

static func lon_lat_from_pixel(x: int, y: int, width: int = ATLAS_W, height: int = ATLAS_H) -> Vector2:
	return Vector2((float(x) + 0.5) / float(width) * TAU - PI, PI * 0.5 - (float(y) + 0.5) / float(height) * PI)

func color_at(lon: float, lat: float) -> Color:
	var data: Dictionary = sample(lon, lat)
	var biome: int = int(data["biome"])
	var col: Color = BIOME_COLORS[biome]
	var height: float = float(data["height"])
	var factor: float = clampf(0.88 + height * 0.35, 0.62, 1.20)
	return Color(col.r * factor, col.g * factor, col.b * factor, 1.0)

func region_seed(lon: float, lat: float) -> int:
	var ij: Vector2i = atlas_coords(lon, lat)
	# Multiplier in 64-bit range, no random state mutation.
	return posmod(seed * 1013 + ij.x * 2000003 + ij.y * 1000033 + 7919, 2147483647) + 1

func generate_atlas_row(image: Image, y: int) -> void:
	if image == null or y < 0 or y >= image.get_height():
		return
	var w: int = image.get_width()
	var h: int = image.get_height()
	for x in w:
		var ll: Vector2 = lon_lat_from_pixel(x, y, w, h)
		image.set_pixel(x, y, color_at(ll.x, ll.y))

func tactical_decorate(w: SimWorld, lon: float, lat: float) -> void:
	## Conserve les gués, centres et ressources du RTS historique. Variation locale de lacs
	## et de gisements, symétrique par échange x/y pour l'équilibre initial.
	## Cette étape est un premier fragment jouable, pas une planète 96x96 agrandie.
	var region: Dictionary = sample(lon, lat)
	var bias: float = float(region["humidity"])
	var rng := RandomNumberGenerator.new()
	rng.seed = region_seed(lon, lat)
	for y in w.map_size:
		for x in range(y + 1, Rules.MAP_SIZE):
			var p: Vector2i = Vector2i(x, y)
			var mirrored: Vector2i = Vector2i(y, x)
			if w.terrain[w.idx(p)] != SimWorld.TERRAIN_GRASS or w.terrain[w.idx(mirrored)] != SimWorld.TERRAIN_GRASS:
				continue
			if w._occupied.has(p) or w._occupied.has(mirrored) or w._node_cells.has(p) or w._node_cells.has(mirrored):
				continue
			# Préserver les couloirs de départ, les bases et les routes proches du gué.
			if p.x < 7 or p.y < 7 or p.x > 88 or p.y > 88:
				continue
			if (Vector2(p) - Vector2(14, 82)).length() < 20.0 or (Vector2(p) - Vector2(82, 14)).length() < 20.0:
				continue
			if absf(float(p.x - p.y)) < 12.0:
				continue
			if rng.randf() < 0.006 * bias:
				# Petites mares, jamais sur gisements ni bâtiments.
				w.set_terrain(p, SimWorld.TERRAIN_WATER)
				w.set_terrain(mirrored, SimWorld.TERRAIN_WATER)

# J9 complet : les 512 x 256 cases de l'atlas représentent des régions tactiques
# déterministes de 96 x 96 cellules. Les coordonnées de leurs sommets s'alignent
# exactement, y compris sur la couture +/-PI. Aucune carte globale n'est allouée.
static func region_coords(lon: float, lat: float) -> Vector2i:
	var x: int = posmod(int(floor((lon + PI) / TAU * float(ATLAS_W))), ATLAS_W)
	var y: int = clampi(int(floor((PI * 0.5 - lat) / PI * float(ATLAS_H))), 0, ATLAS_H - 1)
	return Vector2i(x, y)

static func region_center(rx: int, ry: int) -> Vector2:
	return Vector2(-PI + TAU * (float(posmod(rx, ATLAS_W)) + 0.5) / float(ATLAS_W),
		PI * 0.5 - PI * (float(ry) + 0.5) / float(ATLAS_H))

static func region_cell_ll(rx: int, ry: int, x: float, y: float, dimension: int = 96) -> Vector2:
	# J13-0 : la couture +PI/-PI est ramenée sur la même longitude (bord est du dernier secteur = bord ouest du premier).
	var gx: float = fposmod(float(posmod(rx, ATLAS_W)) + x / float(dimension), float(ATLAS_W))
	var gy: float = float(ry) + y / float(dimension)
	return Vector2(-PI + gx / float(ATLAS_W) * TAU, PI * 0.5 - gy / float(ATLAS_H) * PI)

func region_elevation(rx: int, ry: int, x: float, y: float, dimension: int = 96) -> float:
	# Fonction pure sur la sphère, pas de bruit 2D non périodique aux frontières.
	var ll: Vector2 = region_cell_ll(rx, ry, x, y, dimension)
	var d: Vector3 = sphere_direction(ll.x, ll.y)
	var macro: float = float(sample(ll.x, ll.y)["height"])
	var fine: float = _detail.get_noise_3dv(d * 410.0) * 0.045 * (0.4 if _earth else 1.0)
	return macro + fine

func generate_region(w: SimWorld, rx: int, ry: int, origin: bool = false) -> void:
	# Le décor tactique initial et ses gués ne sont pas recopiés à chaque région.
	# Centres de départ protégés uniquement dans le secteur d'origine.
	for y in w.map_size:
		for x in w.map_size:
			var elevation: float = region_elevation(rx, ry, float(x) + 0.5, float(y) + 0.5, w.map_size)
			var water: bool = elevation < -0.042
			if origin:
				for base in [Vector2(12.0, 80.0), Vector2(80.0, 12.0)]:
					if Vector2(float(x), float(y)).distance_squared_to(base) < 100.0:
						water = false
			w.set_terrain(Vector2i(x, y), SimWorld.TERRAIN_WATER if water else SimWorld.TERRAIN_GRASS)
	if origin:
		# Relais neutres garantis : sans eux l'objectif d'âge II serait bloqué.
		# Positions internes, sans altérer la continuité des frontières régionales.
		for port in [Vector2i(5, 21), Vector2i(21, 5), Vector2i(70, 87), Vector2i(87, 70)]:
			for dy in 3:
				for dx in 3:
					var cleared: Vector2i = port + Vector2i(dx, dy)
					w.set_terrain(cleared, SimWorld.TERRAIN_GRASS)
			w.spawn_building(SimWorld.TEAM_NEUTRAL, "comptoir", port, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = region_seed(region_center(rx, ry).x, region_center(rx, ry).y)
	# Noeuds placés sans collision avec l'eau ni les bases. Borne GPU/CPU faible.
	var occupied: Dictionary = {}
	for i in 90:
		var x: int = rng.randi_range(2, w.map_size - 3)
		var y: int = rng.randi_range(2, w.map_size - 3)
		var c := Vector2i(x, y)
		if occupied.has(c) or not w.walkable(c) or w._occupied.has(c):
			continue
		if origin and (Vector2(c).distance_to(Vector2(14, 82)) < 9.0 or Vector2(c).distance_to(Vector2(82, 14)) < 9.0):
			continue
		occupied[c] = true
		var kind: String = "arbre" if i % 5 < 3 else ("baies" if i % 5 == 3 else "minerai")
		w.add_node(kind, Vector2(c) + Vector2(0.5, 0.5), 210.0 if kind == "arbre" else 550.0)
	if origin:
		# Ressources garanties à distance raisonnable des deux centres initiaux.
		for base in [Vector2i(14, 82), Vector2i(82, 14)]:
			for kind in ["arbre", "baies", "minerai"]:
				var positions: Array[Vector2i] = [base + Vector2i(-9, 0), base + Vector2i(0, 9), base + Vector2i(9, 0), base + Vector2i(0, -9)]
				for c in positions:
					if w.in_map(c) and w.walkable(c) and not w._node_cells.has(c):
						w.add_node(kind, Vector2(c) + Vector2(0.5, 0.5), 500.0)
						break
