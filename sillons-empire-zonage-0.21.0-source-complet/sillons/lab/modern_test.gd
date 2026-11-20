extends SceneTree
var failures: int = 0
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func base() -> SimWorld:
	var w := SimWorld.new()
	w.setup(345)
	w.start_standard()
	for t in w.teams:
		t.res = {"food": 50000.0, "wood": 50000.0, "ore": 50000.0}
		t.pop_cap = 300
	return w
func run_steps(w: SimWorld, n: int) -> void:
	for i in n:
		w.step()
func _initialize() -> void:
	var w: SimWorld = base()
	var t: SimWorld.Team = w.teams[0]
	t.age = 3
	w.spawn_building(0, "maison", Vector2i(20, 80), true)
	w.spawn_building(0, "entrepot", Vector2i(24, 80), true)
	for age in range(4, 9):
		var prerequisites: Dictionary = {5: "usine", 6: "academie", 7: "aerodrome", 8: "radar"}
		if prerequisites.has(age):
			w.spawn_building(0, String(prerequisites[age]), Vector2i(25 + age * 5, 82), true)
		check(w.issue({"t": "age_up", "team": 0})["ok"], "passage âge %d accepté" % age)
		run_steps(w, int(float(Rules.AGE_UP[age]["time"]) * 10.0) + 2)
		check(t.age == age and w.teams[1].age == 1, "âge %d atteint, adversaire indépendant" % age)
	check(not w.issue({"t": "age_up", "team": 0})["ok"], "âge IX indisponible")
	check(not w.issue({"t": "age_up", "team": -1})["ok"], "camp négatif refusé")
	var factory: SimWorld.Building = w.team_buildings(0, "usine", true)[0]
	check(w.issue({"t": "technology", "team": 0, "building": factory.id, "key": "outillage"})["ok"], "recherche lancée")
	check(not w.issue({"t": "technology", "team": 0, "building": factory.id, "key": "outillage"})["ok"], "double recherche refusée")
	run_steps(w, 352)
	check(t.technologies.has("outillage"), "technologie achevée")
	check(not w.issue({"t": "technology", "team": 1, "building": factory.id, "key": "outillage"})["ok"], "recherche bâtiment ennemi refusée")
	var ore: float = t.res["ore"]
	ModernSystems.step(w)
	# Usine : tick multiple de 10, source de bois contrôlée.
	w.tick = 10000
	ore = t.res["ore"]
	var wood: float = t.res["wood"]
	ModernSystems.step(w)
	check(is_equal_approx(float(t.res["ore"]) - ore, 1.5) and is_equal_approx(wood - float(t.res["wood"]), 2.0), "industrie transforme 2 bois en 1,5 minerai")
	check(w.issue({"t": "train", "team": 0, "building": factory.id, "unit": "char"})["ok"], "formation char acceptée")
	run_steps(w, 250)
	check(w.team_units(0, "vehicle").size() > 0, "char produit")
	var tank := w.spawn_unit(0, "char", Vector2(8, 8))
	var plane := w.spawn_unit(1, "avion", Vector2(10, 8))
	var aa := w.spawn_unit(0, "antiaerien", Vector2(8, 10))
	check(not ModernSystems.can_target(tank, plane) and ModernSystems.can_target(aa, plane), "filtrage air-sol et antiaérien")
	w.set_terrain(Vector2i(10, 9), SimWorld.TERRAIN_WATER)
	plane.pos = Vector2(10.5, 8.5)
	for i in 10:
		w._move_towards(plane, Vector2(10.5, 12.5))
	check(plane.pos.y > 9.5, "avion franchit l’eau")
	tank.supply = 1.0
	w.tick = 10000
	ModernSystems.step(w)
	check(tank.supply == 0.0 and ModernSystems.efficiency(w, tank) == 0.5, "rupture ravitaillement réduit efficacité")
	var drone := w.spawn_unit(0, "drone", Vector2(8, 8))
	var jammer := w.spawn_unit(1, "brouilleur", Vector2(9, 9))
	check(ModernSystems.efficiency(w, drone) == 0.5, "brouillage drone")
	t.technologies["contre_mesures"] = true
	check(ModernSystems.efficiency(w, drone) == 0.85, "contre-mesures réduisent brouillage")
	w._kill_unit(jammer, 0)
	check(ModernSystems.efficiency(w, drone) == 1.0, "destruction brouilleur restaure efficacité")
	var silo := w.spawn_building(0, "silo", Vector2i(5, 60), true)
	var target: Vector2 = Vector2(80, 10)
	t.fog.fill(0)
	check(not w.issue({"t": "missile", "team": 0, "building": silo.id, "pos": [80, 10]})["ok"], "missile vers brouillard refusé")
	t.fog.fill(2)
	check(w.issue({"t": "missile", "team": 0, "building": silo.id, "pos": [80, 10]})["ok"], "missile visible lancé")
	check(not w.issue({"t": "missile", "team": 0, "building": silo.id, "pos": [80, 10]})["ok"], "recharge missile imposée")
	var interceptor := w.spawn_building(1, "intercepteur", Vector2i(82, 10), true)
	ModernSystems.step(w)
	check(w.modern["missiles"].is_empty() and interceptor.cd > 0.0, "interception antimissile")
	w._destroy_building(interceptor, 0)
	silo.cd = 0.0
	var victim := w.spawn_unit(1, "char", target)
	var hp: float = victim.hp
	w.issue({"t": "missile", "team": 0, "building": silo.id, "pos": [80, 10]})
	for i in 50:
		ModernSystems.step(w)
	check(victim.hp < hp, "impact sans interception")
	var rail_world: SimWorld = base()
	for y in range(75, 90):
		for x in range(5, 65):
			rail_world.set_terrain(Vector2i(x, y), SimWorld.TERRAIN_GRASS)
	var station_a := rail_world.spawn_building(0, "gare", Vector2i(32, 80), true)
	var station_b := rail_world.spawn_building(0, "gare", Vector2i(53, 80), true)
	ModernSystems._network(rail_world)
	check(rail_world.modern["connected"].has(station_b.id), "réseau transitif centre → gare → gare")
	var train := rail_world.spawn_unit(0, "train", Vector2(35, 84))
	var train_start: Vector2 = train.pos
	for i in 30:
		ModernSystems.train_step(rail_world, train)
	check(train.state == "rail" and train.pos.distance_to(train_start) > 2.0, "train circule entre gares")
	var forward_tank := rail_world.spawn_unit(0, "char", Vector2(58, 84))
	forward_tank.supply = 20.0
	ModernSystems.step(rail_world)
	check(forward_tank.supply > 20.0, "ravitaillement via réseau connecté")
	rail_world._destroy_building(station_a, 1)
	ModernSystems._network(rail_world)
	ModernSystems.train_step(rail_world, train)
	check(not rail_world.modern["connected"].has(station_b.id) and train.state == "idle", "destruction gare coupe réseau et train")
	check(not rail_world.issue({"t": "move", "team": 0, "units": [train.id], "pos": [60, 80]})["ok"], "train refuse déplacement libre hors liaison")
	plane.team = 0
	check(w.issue({"t": "move", "team": 0, "units": [plane.id], "pos": [10.5, 9.5]})["ok"], "ordre aérien vers eau accepté")
	check(not w.issue({"t": "move", "team": 0, "units": [plane.id], "pos": [-1, 9]})["ok"], "ordre hors carte refusé")
	# Sauvegarde avec IA, missiles en vol, technologie en cours et tous les états.
	w.ai_controllers.append(AiController.new(1))
	check(SaveGame.save(w, "user://modern-test.save") == OK, "sauvegarde atomique")
	check(SaveGame.save(w, "user://modern-test.save") == OK and FileAccess.file_exists("user://modern-test.save.bak"), "remplacement sauvegarde et copie de secours")
	check(SaveGame.load_world("user://modern-test.save.bak") != null, "copie de secours rechargeable")
	var loaded: SimWorld = SaveGame.load_world("user://modern-test.save")
	check(loaded != null and w.state_hash() == loaded.state_hash(), "chargement conserve empreinte")
	if loaded != null:
		for i in 100:
			w.step()
			loaded.step()
		check(w.state_hash() == loaded.state_hash(), "continuation déterministe après reprise 100 ticks")
		check(var_to_bytes(SaveGame.snapshot(w)) == var_to_bytes(SaveGame.snapshot(loaded)), "état complet identique après reprise (IA, ordres, files, chemins)")
	var file := FileAccess.open("user://modern-test.save", FileAccess.WRITE)
	file.store_string("corruption")
	file.close()
	check(SaveGame.load_world("user://modern-test.save") == null, "sauvegarde corrompue refusée")
	print("MODERN_TEST: %d/%d PASS" % [checks - failures, checks])
	quit(1 if failures else 0)
