class_name WorldLayout
extends RefCounted
const SECTOR_SIZE: int = 32
const PROFILES := [96, 256, 512]

static func base_cell(w: SimWorld, team: int) -> Vector2i:
	if w.map_size == 96: return Vector2i(12,80) if team == 0 else Vector2i(80,12)
	return Vector2i(14,w.map_size-20) if team % 2 == 0 else Vector2i(w.map_size-20,14)

static func river_x(size: int, y: float, seed_value: int) -> float:
	return float(size)*.5 + sin(y*.036 + float(posmod(seed_value,11)))*8.0

static func fords(w: SimWorld) -> Array:
	if w.map_size == 96: return SimMap.FORDS.duplicate()
	var result: Array = []
	for fraction in [.25,.73]:
		var y: float = float(w.map_size)*float(fraction)
		result.append(Vector2(river_x(w.map_size,y,w.seed_value),y))
	return result

static func generate(w: SimWorld) -> void:
	var n: int = w.map_size
	var crossings: Array = fords(w)
	for y in n:
		for x in n:
			var p := Vector2(x+.5,y+.5)
			var wet: bool = absf(p.x-river_x(n,p.y,w.seed_value)) < 2.4
			var terrain: int = SimWorld.TERRAIN_WATER if wet else SimWorld.TERRAIN_GRASS
			for crossing in crossings:
				if p.distance_squared_to(crossing) < 30.0 and wet: terrain = SimWorld.TERRAIN_FORD
			w.set_terrain(Vector2i(x,y),terrain)
	# Local starting pockets guarantee the first economic loop; the interior remains worth exploring.
	for team in [0,1]:
		var base: Vector2 = Vector2(base_cell(w,team)) + Vector2(2,2)
		for i in 9:
			_resource(w,"baies",base+Vector2(7+float(i%3),-5+float(i/3)),220)
		for i in 4: _resource(w,"minerai",base+Vector2(-7+float(i%2)*2,-5+float(i/2)*2),850)
		for j in 3:
			var c: Vector2 = base+Vector2(-9+float(j)*9,8 if team==1 else -10)
			for i in 22: _resource(w,"arbre",c+Vector2(w.rng.randf_range(-4,4),w.rng.randf_range(-4,4)),120)
		for offset in [Vector2i(7,-14),Vector2i(-9,-17)]:
			var cell: Vector2i = base_cell(w,team)+offset
			cell.x=clampi(cell.x,3,n-4);cell.y=clampi(cell.y,3,n-4)
			if w.footprint_free(cell,2): w.spawn_building(2,"comptoir",cell,true)
	for i in n*3:
		var p := Vector2(w.rng.randf_range(4,n-4),w.rng.randf_range(4,n-4))
		var away: bool = true
		for team in [0,1]:
			if p.distance_squared_to(Vector2(base_cell(w,team))) < 64: away=false
		if not away: continue
		var kind: String = "minerai" if i%13==0 else ("baies" if i%9==0 else "arbre")
		_resource(w,kind,p,900 if kind=="minerai" else 180)

static func _resource(w: SimWorld, kind: String, p: Vector2, amount: float) -> void:
	var cell: Vector2i = w.cell_of(p)
	if not w.walkable(cell) or w._occupied.has(cell) or w._node_cells.has(cell): return
	w.add_node(kind,p,amount)
