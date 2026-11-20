extends SceneTree
## Menu « Nouvelle partie » : godot --headless --path . --script res://lab/new_game_test.gd
var checks: int = 0
var fails: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("PASS " if ok else "FAIL ") + description)

func _world(extra: Dictionary = {}) -> SimWorld:
	var w := SimWorld.new()
	var rules: Dictionary = GameConfig.merge_rules({"map_size": 96})
	for key in extra.keys():
		rules[key] = extra[key]
	w.setup(1234, rules)
	w.start_standard()
	return w

func _count(w: SimWorld, team: int, kind: String) -> int:
	var n: int = 0
	for u in w.units.values():
		if u.team == team and u.type == kind:
			n += 1
	return n

func _initialize() -> void:
	# --- valeurs par défaut et préréglages
	GameSetup.apply_preset("Équilibré")
	check(GameSetup.seed_value() == 0, "monde aléatoire = graine 0")
	var base: Dictionary = GameSetup.build_rules()
	check(is_equal_approx(float(base["cost_mult"]), 1.0) and is_equal_approx(float(base["ai_attack_mult"]), 1.0), "équilibré = règles de référence")
	check(int((base["start"] as Dictionary)["workers"]) == int(Rules.START["workers"]), "équilibré : ouvriers de base")
	check(int(((base["start"] as Dictionary)["res"] as Dictionary)["wood"]) == 220, "équilibré : 220 bois")
	for preset in GameSetup.PRESET_ORDER:
		GameSetup.apply_preset(String(preset))
		var r: Dictionary = GameSetup.build_rules()
		check(float(r["cost_mult"]) > 0.0 and int((r["start"] as Dictionary)["workers"]) >= 3, "préréglage « %s » cohérent" % preset)
	# --- Terre réelle
	GameSetup.apply_preset("Équilibré")
	GameSetup.v["world"] = 0
	check(GameSetup.seed_value() == PlanetGenerator.EARTH_SEED, "Terre réelle = graine 1789")
	GameSetup.v["world"] = 2
	GameSetup.v["seed_text"] = "4242"
	check(GameSetup.seed_value() == 4242, "graine précise")
	GameSetup.v["seed_text"] = "abc"
	check(GameSetup.seed_value() == 0, "graine invalide = aléatoire")
	# --- application à GameConfig
	GameSetup.apply_preset("Guerre totale")
	GameSetup.v["mode"] = 1
	var scene: String = GameSetup.apply()
	check(scene == "res://game/planet_start.tscn" and GameConfig.mode == "planet_j9", "escarmouche : choix du site")
	GameSetup.v["mode"] = 0
	GameSetup.v["map"] = 0
	scene = GameSetup.apply()
	check(scene == "res://game/game.tscn" and GameConfig.mode == "empire" and GameConfig.map_dimension == 96, "campagne : carte petite")
	check(float(GameConfig.custom_rules["cost_mult"]) < 1.0, "guerre totale : durée rapide")
	# --- effets réels sur un monde
	var w: SimWorld = _world()
	var expected_player: Dictionary = GameSetup.start_resources(1)
	var expected_ai: Dictionary = GameSetup.start_resources(1, 1.25)
	check(is_equal_approx(w.teams[0].res["wood"], float(expected_player["wood"])), "ressources du joueur")
	check(is_equal_approx(w.teams[1].res["wood"], float(expected_ai["wood"])) and float(expected_ai["wood"]) > float(expected_player["wood"]), "dotation de l'IA différente")
	check(_count(w, 0, "ouvrier") == 6 and _count(w, 1, "ouvrier") == 6, "ouvriers de départ réglés")
	check(is_equal_approx(w.scaled_cost({"wood": 100.0})["wood"], 70.0), "coûts ×0,7")
	check(is_equal_approx(float(w.rule("ai_attack_mult", 1.0)), 0.65), "IA agressive")
	check(is_equal_approx(float(w.rule("events_scale", 1.0)), 2.5), "événements fréquents")
	# --- carte explorée
	GameSetup.apply_preset("Course rapide")
	GameSetup.apply()
	var fast: SimWorld = _world()
	fast.update_fog(true)
	var unseen: int = 0
	for cell in fast.teams[0].fog:
		if cell == 0:
			unseen += 1
	check(unseen == 0, "carte explorée : aucune case inconnue")
	var plain: SimWorld = _world({"reveal_map": false})
	plain.update_fog(true)
	var hidden: int = 0
	for cell in plain.teams[0].fog:
		if cell == 0:
			hidden += 1
	check(hidden > 0, "brouillard complet : cases inconnues")
	# --- IA pacifique
	GameSetup.apply_preset("Bâtisseur paisible")
	GameSetup.apply()
	check(is_zero_approx(float(GameConfig.custom_rules["ai_attack_mult"])), "IA pacifique = multiplicateur 0")
	# --- campagne complète créée avec ces règles
	var c := StarCampaign.new()
	CampaignSetup.create(c, 1234, false, 96)
	check((c.worlds["val"] as SimWorld).rules.has("start_ai") and (c.worlds["val"] as SimWorld).map_size == 96, "campagne : règles et taille appliquées")
	# --- isolement : sans réglage, rien ne change
	GameConfig.custom_rules = {}
	GameConfig.map_dimension = 256
	var legacy: SimWorld = _world()
	check(not legacy.rules.has("start") and not legacy.rules.has("reveal_map"), "sans menu : règles historiques inchangées")
	# --- sauvegarde des réglages
	GameSetup.apply_preset("Survie")
	GameSetup.save()
	GameSetup.v = GameSetup.defaults()
	GameSetup._loaded = false
	GameSetup.load_saved()
	check(int(GameSetup.v["workers"]) == 3 and int(GameSetup.v["ai_edge"]) == 3, "réglages rechargés")
	print("NEW_GAME_TEST checks=%d fails=%d" % [checks, fails])
	quit(1 if fails > 0 else 0)
