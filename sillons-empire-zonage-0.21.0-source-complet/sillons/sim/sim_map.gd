class_name SimMap
extends RefCounted
## Carte « Val des Deux Gués » : générée à partir de la graine, symétrique par échange x/y
## pour l'équité (camp 0 au sud-ouest, camp 1 au nord-est).
## Une rivière NO→SE sépare les camps, deux gués la traversent, un lac central porte
## un îlot de minerai inaccessible (test des gisements inaccessibles).

const LAKE_CENTER := Vector2(48, 48)
const LAKE_R := 7.5
const ISLAND_R := 2.6
const FORDS := [Vector2(25, 25), Vector2(71, 71)]
## Comptoirs neutres : un de chaque côté, aux deux coins hors des axes d'attaque
const POSTS_SW := [Vector2i(5, 21), Vector2i(70, 87)]

static func generate(w: SimWorld) -> void:
	if w.map_size != 96:
		WorldLayout.generate(w)
		return
	if bool(w.rules.get("planet_region_grid", false)):
		var generator := PlanetGenerator.new(int(w.rules.get("planet_master_seed", w.seed_value)))
		generator.generate_region(w, int(w.rules.get("region_x", 0)), int(w.rules.get("region_y", 0)),
			bool(w.rules.get("planet_origin", false)))
		return
	var n := w.map_size
	var wobble_phase := w.rng.randf() * TAU
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			var p := Vector2(x + 0.5, y + 0.5)
			var t := SimWorld.TERRAIN_GRASS
			# rivière le long de x == y (ondulation symétrique : fonction de x + y)
			var d := absf(p.x - p.y) / sqrt(2.0)
			var width := 2.2 + 0.6 * sin((p.x + p.y) * 0.09 + wobble_phase)
			if d < width:
				t = SimWorld.TERRAIN_WATER
			var dl := p.distance_to(LAKE_CENTER)
			if dl < LAKE_R:
				t = SimWorld.TERRAIN_WATER
			if dl < ISLAND_R:
				t = SimWorld.TERRAIN_GRASS
			for f in FORDS:
				if p.distance_to(f) < 3.6 and t == SimWorld.TERRAIN_WATER:
					t = SimWorld.TERRAIN_FORD
			w.set_terrain(c, t)
	# Comptoirs neutres (miroir)
	for c in POSTS_SW:
		w.spawn_building(SimWorld.TEAM_NEUTRAL, "comptoir", c, true)
		w.spawn_building(SimWorld.TEAM_NEUTRAL, "comptoir", Vector2i(c.y, c.x), true)
	# Îlot de minerai (inaccessible à pied)
	w.add_node("minerai", LAKE_CENTER + Vector2(0.3, -0.2), 1500.0)
	# Ressources côté sud-ouest, puis miroir
	var base := Vector2(14, 82)
	var feats := []   # [kind, pos, amount]
	for off in [Vector2(6, -3), Vector2(7, -1.5), Vector2(5.5, -1.2), Vector2(6.8, -4.2), Vector2(-5, -5), Vector2(-6, -3.8), Vector2(-4.6, -6.3)]:
		feats.append(["baies", base + off, 200.0])
	for off in [Vector2(-6, 7), Vector2(-4.5, 8.5)]:
		feats.append(["minerai", base + off, 500.0])
	feats.append(["minerai", Vector2(30, 70), 600.0])
	feats.append(["minerai", Vector2(18, 54), 600.0])
	feats.append(["baies", Vector2(34, 84), 150.0])
	feats.append(["baies", Vector2(35, 85.5), 150.0])
	# Forêts (amas tirés à la graine)
	var forest_centers := [base + Vector2(11, 6), base + Vector2(-8, -12), Vector2(40, 90), Vector2(10, 40), Vector2(26, 56), Vector2(52, 78)]
	for fc in forest_centers:
		var count := 14 + w.rng.randi_range(0, 8)
		for i in count:
			var p: Vector2 = fc + Vector2(w.rng.randf_range(-4.5, 4.5), w.rng.randf_range(-3.5, 3.5))
			feats.append(["arbre", p, 90.0 + w.rng.randf_range(-10, 20)])
	var occupied := {}
	for f in feats:
		var p: Vector2 = f[1]
		for mirror in [false, true]:
			var q := Vector2(p.y, p.x) if mirror else p
			var c := w.cell_of(q)
			if not w.in_map(c) or c.x < 1 or c.y < 1 or c.x > n - 2 or c.y > n - 2:
				continue
			if w.terrain[w.idx(c)] != SimWorld.TERRAIN_GRASS or w._occupied.has(c):
				continue
			# pas sur l'emprise de départ des centres
			if _near_base(q):
				continue
			var key := "%s:%d,%d" % [f[0], c.x, c.y]
			if f[0] == "arbre":
				key = "a:%d,%d" % [c.x, c.y]
			if occupied.has(key):
				continue
			occupied[key] = true
			w.add_node(f[0], q, f[2])

static func _near_base(p: Vector2) -> bool:
	for b in [Vector2(14, 82), Vector2(82, 14)]:
		if absf(p.x - b.x) < 3.5 and absf(p.y - b.y) < 3.5:
			return true
	return false
