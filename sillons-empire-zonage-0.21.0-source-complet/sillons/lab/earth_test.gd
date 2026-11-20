extends SceneTree
## Terre réelle. godot --headless --path . --script res://lab/earth_test.gd
var checks: int = 0
var fails: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("PASS " if ok else "FAIL ") + description)

func _b(g: PlanetGenerator, lon_deg: float, lat_deg: float) -> int:
	return int(g.sample(deg_to_rad(lon_deg), deg_to_rad(lat_deg))["biome"])

func _initialize() -> void:
	check(EarthData.available(), "données Terre chargées")
	var g := PlanetGenerator.new(PlanetGenerator.EARTH_SEED)
	check(g.is_earth(), "graine 1789 = Terre")
	check(not PlanetGenerator.new(471901).is_earth(), "autres graines restent procédurales")
	check(_b(g, -150, 0) == PlanetGenerator.OCEAN, "Pacifique = océan")
	check(_b(g, -30, 30) == PlanetGenerator.OCEAN, "Atlantique = océan")
	check(_b(g, 51, 41) == PlanetGenerator.OCEAN, "mer Caspienne = eau")
	check(_b(g, 10, 23) == PlanetGenerator.DESERT, "Sahara = désert")
	check(_b(g, 86.9, 28.0) == PlanetGenerator.MOUNTAIN, "Himalaya = montagnes")
	check(_b(g, -62, -4) == PlanetGenerator.FOREST, "Amazonie = forêt")
	check(_b(g, 2.35, 48.85) != PlanetGenerator.OCEAN, "Paris = terre")
	check(_b(g, 0, -85) != PlanetGenerator.OCEAN, "Antarctique = terre")
	check(float(g.sample(deg_to_rad(86.9), deg_to_rad(28.0))["height"]) > 0.9, "Himalaya très haut")
	var seam: float = 0.0
	for j in 65:
		var lat: float = -PI * 0.5 + float(j) / 64.0 * PI
		seam = maxf(seam, absf(float(g.sample(-PI, lat)["height"]) - float(g.sample(PI, lat)["height"])))
	check(seam < 0.0001, "couture de longitude continue")
	check(g.sample(0.3, 0.4) == PlanetGenerator.new(PlanetGenerator.EARTH_SEED).sample(0.3, 0.4), "déterministe")
	var land: int = 0
	for j in 90:
		for i in 180:
			var ll: Vector2 = PlanetGenerator.lon_lat_from_pixel(i * 3, j * 3 + 1)
			if int(g.sample(ll.x, ll.y)["biome"]) != PlanetGenerator.OCEAN:
				land += 1
	check(land > 16200 * 0.28 and land < 16200 * 0.40, "part de terres réaliste (~34 % avec banquises côtières)")
	var w := SimWorld.new()
	var ll0: Vector2 = Vector2(deg_to_rad(2.35), deg_to_rad(48.85))
	var rc: Vector2i = PlanetGenerator.region_coords(ll0.x, ll0.y)
	w.setup(PlanetGenerator.EARTH_SEED, {"planet_j9": true, "planet_region_grid": true, "planet_origin": true, "region_x": rc.x, "region_y": rc.y, "planet_master_seed": PlanetGenerator.EARTH_SEED, "planet_lon": ll0.x, "planet_lat": ll0.y})
	w.start_standard()
	check(w.walkable(Vector2i(10, 79)) and w.walkable(Vector2i(79, 10)), "région de Paris jouable (deux départs praticables)")
	print("EARTH_TEST checks=%d fails=%d" % [checks, fails])
	quit(1 if fails > 0 else 0)
