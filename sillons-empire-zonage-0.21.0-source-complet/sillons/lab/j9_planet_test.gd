extends SceneTree
## Batterie J9 déterministe. Exécuter avec Godot 4.7 :
## godot --headless --path . --script res://lab/j9_planet_test.gd
var checks: int = 0
var fails: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("PASS " if ok else "FAIL ") + description)

func _initialize() -> void:
	var g := PlanetGenerator.new(471901)
	var h0: Dictionary = g.sample(0.56, -0.28)
	var h1: Dictionary = PlanetGenerator.new(471901).sample(0.56, -0.28)
	check(h0 == h1, "meme graine, memes reliefs et biomes")
	check(g.sample(0.56, -0.28) != PlanetGenerator.new(471902).sample(0.56, -0.28), "graines differentes")
	var max_seam: float = 0.0
	for j in 65:
		var lat: float = -PI * 0.5 + float(j) / 64.0 * PI
		var left: Dictionary = g.sample(-PI, lat)
		var right: Dictionary = g.sample(PI, lat)
		max_seam = maxf(max_seam, absf(float(left["height"]) - float(right["height"])))
	check(max_seam < 0.00001, "couture de longitude continue")
	check(g.atlas_coords(-PI, 0).x == g.atlas_coords(PI, 0).x, "index d'atlas periodique")
	var valid: bool = true
	for seed in 1000:
		var atlas := PlanetGenerator.new(seed + 1)
		for j in 5:
			var ll: Vector2 = PlanetGenerator.lon_lat_from_pixel((seed * 31 + j * 89) % 512, (seed * 23 + j * 19) % 256)
			var sample_data: Dictionary = atlas.sample(ll.x, ll.y)
			var biome: int = int(sample_data["biome"])
			if not is_finite(float(sample_data["height"])) or biome < 0 or biome >= PlanetGenerator.BIOME_NAMES.size():
				valid = false
	check(valid, "1000 graines x 5 echantillons : donnees finies et biome reconnu")
	var w := SimWorld.new()
	w.setup(471901, {"planet_j9": true, "planet_region_grid": true, "planet_origin": true, "region_x": 256, "region_y": 128, "planet_master_seed": 471901, "planet_lon": 0.0, "planet_lat": 0.0})
	w.start_standard()
	var w2 := SimWorld.new()
	w2.setup(471901, {"planet_j9": true, "planet_region_grid": true, "planet_origin": true, "region_x": 256, "region_y": 128, "planet_master_seed": 471901, "planet_lon": 0.0, "planet_lat": 0.0})
	w2.start_standard()
	check(w.terrain == w2.terrain and w.state_hash() == w2.state_hash(), "carte tactique J9 reproductible")
	var bases_walkable: bool = w.walkable(Vector2i(10, 79)) and w.walkable(Vector2i(79, 10))
	check(bases_walkable, "deux zones de depart praticables sur la planete")
	check(bool(w.rules.get("planet_region_grid", false)), "simulation de region planetaire active")
	check(w.team_buildings(0, "centre", true).size() == 1 and w.team_buildings(1, "centre", true).size() == 1, "bases de depart presentes")
	var source_save: Dictionary = SaveGame.snapshot(w)
	var restored: SimWorld = SaveGame.from_snapshot(source_save)
	check(restored != null and restored.state_hash() == w.state_hash(), "instantane tactique procedural conserve")
	var streamer := TerrainChunkStreamer.new()
	streamer.world = w
	var same_edge: bool = true
	for y in range(0, Rules.MAP_SIZE + 1, 24):
		for x in range(0, Rules.MAP_SIZE + 1, 24):
			if not is_finite(streamer.sample_edge_height(x, y)):
				same_edge = false
	check(same_edge, "coutures heightmap inter-chunks finies")
	var c := StarCampaign.new()
	c.create(471901, false, true)
	check(bool((c.worlds["val"] as SimWorld).rules.get("planet_j9", false)), "activation de la planete J9")
	check(not bool((c.worlds["aurore"] as SimWorld).rules.get("planet_j9", false)), "secteurs J6-J8 preserves")
	var restored_campaign: StarCampaign = CampaignSave.from_snapshot(CampaignSave.snapshot(c))
	check(restored_campaign != null and restored_campaign.state_hash() == c.state_hash(), "campagne J9 restaurable dans schema precedent")
	streamer.free() # Nœud de laboratoire non ajouté à l’arbre : libération explicite.
	print("J9_TEST_RESULT=%s checks=%d failures=%d" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0 if fails == 0 else 1)
