extends SceneTree
## 0.16 — Recette de l'évolution de la civilisation (hors rendu) :
## godot --headless --path . --script res://lab/civ_evolution_test.gd
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func world(civ: bool) -> SimWorld:
	var w := SimWorld.new()
	w.setup(16001, {"civ_evolution": civ, "max_age": 10})
	w.start_standard()
	w.teams[0].res = {"food": 90000.0, "wood": 90000.0, "ore": 90000.0}
	w.teams[0].pop_cap = 150
	w.update_fog(true)
	return w

func free_cell(w: SimWorld, team: int, kind: String, skip: int = 0) -> Vector2i:
	var center: Vector2 = (w.team_buildings(team, "centre", true)[0] as SimWorld.Building).center
	var size: int = int(Rules.BUILDINGS[kind]["size"])
	var found: int = 0
	for radius in range(6, 30):
		for k in 24:
			var a: float = TAU * float(k) / 24.0
			var p: Vector2 = center + Vector2(cos(a), sin(a)) * float(radius)
			var cell := Vector2i(int(p.x) - size / 2, int(p.y) - size / 2)
			if w.has_margin(cell, size) and w.footprint_free(cell, size) and w.is_explored_by(team, Vector2(cell) + Vector2(size, size) * 0.5):
				if found == skip:
					return cell
				found += 1
	return Vector2i(-1, -1)

func complete(w: SimWorld, kind: String) -> SimWorld.Building:
	## Bâtiment de laboratoire achevé, posé sans commande (pour préparer une situation).
	var b: SimWorld.Building = w.spawn_building(0, kind, free_cell(w, 0, kind), false)
	w._complete_building(b)
	return b

func near_building(w: SimWorld, b: SimWorld.Building, offset: float) -> Vector2:
	var p: Vector2 = b.center + Vector2(float(b.size) * 0.5 + offset, 0.0)
	return Vector2(w.nearest_walkable(w.cell_of(p), p)) + Vector2(0.5, 0.5)

func _initialize() -> void:
	_legacy()
	_core()
	_campaign()
	_ai()
	print("CIV_EVOLUTION_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

# ------------------------------------------------------------------ parties historiques inchangées
func _legacy() -> void:
	var w: SimWorld = world(false)
	var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
	w.teams[0].age = 2
	check(w.train_check(0, cc, "heros_antique").contains("réservé"), "partie historique : héros refusé")
	check(w.build_check(0, "forge", free_cell(w, 0, "forge")).contains("réservé"), "partie historique : forge refusée")
	check(not bool(w.issue({"t": "civ_voie", "team": 0, "epoch": "antique", "voie": "marchande"})["ok"]), "partie historique : ordres de civilisation refusés")
	check(not bool(w.age_up_status(0).has("monument")), "partie historique : passage d'âge classique conservé")
	check(is_equal_approx(CivEvolution.gather_mult(w, 0, "food"), 1.0) and CivEvolution.hash_text(w).is_empty(), "partie historique : aucun modificateur, empreinte inchangée")

# ------------------------------------------------------------------ règles de la civilisation
func _core() -> void:
	var w: SimWorld = world(true)
	var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
	check(not bool(w.age_up_status(0)["possible"]) and str(w.age_up_status(0)["missing"]).contains("monument"), "le passage d'âge se fait par un monument")
	# Voies
	var refused: Dictionary = w.issue({"t": "civ_voie", "team": 0, "epoch": "antique", "voie": "marchande"})
	check(not bool(refused["ok"]) and String(refused["reason"]).contains("âge II"), "voie antique refusée avant l'âge II")
	# Monument : âge et objectif
	var mon: String = "monument_grand_comptoir"
	check(w.build_check(0, "monument_citadelle", free_cell(w, 0, "monument_citadelle")).contains("âge II requis"), "monument de l'âge III refusé à l'âge I")
	check(w.build_check(0, mon, free_cell(w, 0, mon)).contains("objectif"), "monument refusé tant que l'objectif d'âge n'est pas rempli")
	for b in w.buildings.values():
		if b.type == "comptoir":
			w.teams[0].discovered_posts.append(b.id)
			break
	var before: Dictionary = (w.teams[0].res as Dictionary).duplicate()
	var placed: Dictionary = w.issue({"t": "build", "team": 0, "type": mon, "cell": [free_cell(w, 0, mon).x, free_cell(w, 0, mon).y]})
	check(bool(placed["ok"]) and float(w.teams[0].res["food"]) == float(before["food"]) - 400.0, "monument posé et payé (coût du passage d'âge)")
	check(w.build_check(0, "monument_bibliotheque", free_cell(w, 0, "monument_bibliotheque")).contains("un seul monument"), "un seul des deux monuments par âge")
	var monument: SimWorld.Building = w.buildings[int(placed["id"])]
	var progress0: float = monument.progress
	for i in 40:
		w.step()
	check(monument.progress > progress0, "les ouvriers construisent le monument (%.3f)" % monument.progress)
	w._complete_building(monument)
	check(w.teams[0].age == 2, "achèvement du monument : âge II atteint")
	check(is_equal_approx(CivEvolution.mod(w, 0, "trade"), 25.0), "bonus du monument actif (+25 % commerce)")
	# Voie maintenant
	check(bool(w.issue({"t": "civ_voie", "team": 0, "epoch": "antique", "voie": "marchande"})["ok"]), "voie marchande choisie à l'âge II")
	check(not bool(w.issue({"t": "civ_voie", "team": 0, "epoch": "antique", "voie": "militaire"})["ok"]), "choix de voie définitif")
	check(is_equal_approx(CivEvolution.mod(w, 0, "trade"), 50.0) and is_equal_approx(CivEvolution.gather_mult(w, 0, "food"), 1.15), "bonus de voie et de monument cumulés (+50 % commerce, +15 % nourriture)")
	var barracks: SimWorld.Building = complete(w, "caserne")
	var market: SimWorld.Building = complete(w, "marche")
	check(w.train_check(0, barracks, "chevalier").contains("voie militaire"), "chevalier refusé : unité de la voie militaire")
	check(w.train_check(0, market, "archer_monte") == "", "archer monté autorisé : unité de la voie marchande")
	check(not CivEvolution.visible_unit(w, 0, "chevalier") and CivEvolution.visible_unit(w, 0, "archer_monte"), "l'interface ne montre que l'unité de sa voie")
	# Destruction du monument : bonus perdu, âge conservé
	var hash0: String = w.state_hash()
	w._destroy_building(monument, 1)
	check(w.teams[0].age == 2 and is_equal_approx(CivEvolution.mod(w, 0, "trade"), 25.0), "monument détruit : bonus perdu, âge conservé")
	check(float(CivEvolution.state(w, 1)["points"]) > 0.0 and w.state_hash() != hash0, "destruction d'un monument : points de commandement pour l'adversaire")
	# Forge et améliorations
	var forge: SimWorld.Building = complete(w, "forge")
	var spear: SimWorld.Unit = w.spawn_unit(0, "lancier", near_building(w, barracks, 2.0))
	var target: SimWorld.Unit = w.spawn_unit(1, "lancier", near_building(w, barracks, 4.0))
	var dmg0: float = w._damage_value(spear, target)
	check(bool(w.issue({"t": "civ_upgrade", "team": 0, "building": forge.id, "key": "armes_melee"})["ok"]), "amélioration « Armes de mêlée » lancée à la forge")
	check(not bool(w.issue({"t": "civ_upgrade", "team": 0, "building": forge.id, "key": "armes_tir"})["ok"]), "une seule amélioration à la fois par bâtiment")
	check(not bool(w.issue({"t": "civ_upgrade", "team": 0, "building": cc.id, "key": "armes_tir"})["ok"]), "amélioration refusée hors de son bâtiment")
	for i in 320:
		w.step()
	check(int((CivEvolution.state(w, 0)["upgrades"] as Dictionary).get("armes_melee", 0)) == 1, "amélioration achevée après sa durée")
	check(is_equal_approx(w._damage_value(spear, target), dmg0 * 1.1), "attaque au corps à corps +10 %")
	var level2: Dictionary = w.issue({"t": "civ_upgrade", "team": 0, "building": forge.id, "key": "armes_melee"})
	check(not bool(level2["ok"]) and String(level2["reason"]).contains("âge IV"), "niveau 2 réservé à l'âge IV")
	# Héros
	var res0: float = float(w.teams[0].res["ore"])
	check(bool(w.issue({"t": "train", "team": 0, "building": cc.id, "unit": "heros_antique"})["ok"]) and float(w.teams[0].res["ore"]) < res0, "héros antique recruté au centre")
	check(w.train_check(0, cc, "heros_antique").contains("déjà en service"), "héros unique : second recrutement refusé")
	for i in 420:
		w.step()
	var hero: SimWorld.Unit = null
	for u in w.team_units(0):
		if u.type == "heros_antique":
			hero = u
	check(hero != null and String((CivEvolution.state(w, 0)["heroes"] as Dictionary)["heros_antique"]["state"]) == "alive", "héros en service")
	if hero != null:
		hero.order = {}
		var close: SimWorld.Unit = w.spawn_unit(0, "lancier", hero.pos + Vector2(1.5, 0.0))
		var far_away: SimWorld.Unit = w.spawn_unit(0, "lancier", w.team_buildings(0, "centre", true)[0].center + Vector2(0, -12))
		w.step()
		close.pos = hero.pos + Vector2(1.0, 0.0)
		far_away.pos = hero.pos + Vector2(20.0, 0.0)
		CivEvolution.step(w)
		check(w._damage_value(close, target) > w._damage_value(far_away, target) * 1.12, "aura du héros : +15 % attaque à proximité")
		check(CivEvolution.defense_mult(w, close) < CivEvolution.defense_mult(w, far_away), "aura du héros : dégâts subis réduits à proximité")
		w.issue({"t": "lab_kill", "team": 0, "id": hero.id})
		check(w.train_check(0, cc, "heros_antique").contains("rappel"), "héros tombé : rappel après une attente")
		for i in 310:
			w.step()
		check(w.train_check(0, cc, "heros_antique") == "", "rappel du héros possible (attente réduite de moitié par la voie marchande)")
	# Points et pouvoirs
	var points0: float = float(CivEvolution.state(w, 0)["points"])
	var victim: SimWorld.Unit = w.spawn_unit(1, "lancier", near_building(w, barracks, 6.0))
	w._kill_unit(victim, 0)
	check(is_equal_approx(float(CivEvolution.state(w, 0)["points"]), points0 + 0.5), "points de commandement gagnés en détruisant un ennemi")
	var locked: Dictionary = w.issue({"t": "civ_unlock", "team": 0, "power": "bombardement"})
	check(not bool(locked["ok"]), "pouvoir de rang 3 refusé sans rang 2")
	CivEvolution.state(w, 0)["points"] = 60.0
	var hash1: String = w.state_hash()
	check(not bool(w.issue({"t": "civ_power", "team": 0, "power": "ravitaillement", "pos": [10, 10]})["ok"]) and w.state_hash() == hash1, "pouvoir non débloqué : refus sans effet")
	for power in ["ravitaillement", "eclaireurs", "cri_ralliement", "renforts", "bombardement", "bouclier"]:
		w.issue({"t": "civ_unlock", "team": 0, "power": power})
	check((CivEvolution.state(w, 0)["powers"] as Dictionary).size() == 6 and is_equal_approx(float(CivEvolution.state(w, 0)["points"]), 8.0), "six pouvoirs débloqués dans l'ordre des rangs (52 points dépensés)")
	spear.hp = spear.max_hp * 0.3
	check(bool(w.issue({"t": "civ_power", "team": 0, "power": "ravitaillement", "pos": [spear.pos.x, spear.pos.y]})["ok"]) and spear.hp > spear.max_hp * 0.6, "Ravitaillement : soin de 35 %")
	check(String(w.issue({"t": "civ_power", "team": 0, "power": "ravitaillement", "pos": [spear.pos.x, spear.pos.y]})["reason"]).contains("recharge"), "pouvoir en recharge")
	var scans: int = w.orbital_scans.size()
	check(bool(w.issue({"t": "civ_power", "team": 0, "power": "eclaireurs", "pos": [60, 60]})["ok"]) and w.orbital_scans.size() == scans + 1, "Éclaireurs : zone révélée")
	var base_attack: float = CivEvolution.attack_mult(w, spear, null)
	w.issue({"t": "civ_power", "team": 0, "power": "cri_ralliement", "pos": [spear.pos.x, spear.pos.y]})
	check(is_equal_approx(CivEvolution.attack_mult(w, spear, null), base_attack + 0.25), "Cri de ralliement : +25 % attaque")
	var pop0: int = w.teams[0].pop
	check(bool(w.issue({"t": "civ_power", "team": 0, "power": "renforts", "pos": [barracks.center.x, barracks.center.y]})["ok"]) and w.teams[0].pop > pop0, "Renforts : soldats ajoutés (population comptée)")
	var enemy: SimWorld.Unit = w.spawn_unit(1, "lancier", near_building(w, barracks, 3.0))
	var friend: SimWorld.Unit = w.spawn_unit(0, "lancier", enemy.pos + Vector2(0.5, 0.0))
	w.update_fog(true)
	var friend_hp: float = friend.hp
	check(bool(w.issue({"t": "civ_power", "team": 0, "power": "bombardement", "pos": [enemy.pos.x, enemy.pos.y]})["ok"]), "Bombardement ordonné sur une zone visible")
	var enemy_id: int = enemy.id
	for i in 32:
		w.step()
	check(not w.units.has(enemy_id) or (w.units[enemy_id] as SimWorld.Unit).hp < enemy.max_hp, "Bombardement : l'ennemi est touché après 3 s")
	check(not w.units.has(friend.id) or friend.hp >= friend_hp - 40.0, "Bombardement : pas de tir sur ses propres troupes")
	var shield0: float = CivEvolution.defense_mult(w, barracks)
	w.issue({"t": "civ_power", "team": 0, "power": "bouclier", "pos": [barracks.center.x, barracks.center.y]})
	check(CivEvolution.defense_mult(w, barracks) <= shield0 * 0.51, "Bouclier : −50 % de dégâts sur les bâtiments")
	# Sauvegarde
	var copy: SimWorld = SaveGame.from_snapshot(SaveGame.snapshot(w))
	check(copy != null and copy.state_hash() == w.state_hash(), "sauvegarde : état de civilisation conservé")
	if copy != null:
		for i in 60:
			w.step()
			copy.step()
		check(copy.state_hash() == w.state_hash(), "reprise déterministe après sauvegarde")

# ------------------------------------------------------------------ campagne « deux systèmes »
func _campaign() -> void:
	var c := StarCampaign.new()
	CampaignSetup.create(c, 16002, false, 96)
	var val: SimWorld = c.worlds["val"]
	check(CivEvolution.enabled(val) and CivEvolution.enabled(c.worlds["nemesis"]), "nouvelle campagne : évolution de la civilisation active")
	check(is_same(val.teams[0].civ, c.civ_state(0)), "état de civilisation partagé par l'empire (référence commune)")
	for i in 30:
		c.step()
	c.civ_state(0)["points"] = 7.0
	c.civ_state(0)["voies"]["antique"] = "savante"
	CivEvolution._bump(c.civ_state(0))
	var saved: Dictionary = EvolutionSave.snapshot(c)
	var restored: StarCampaign = EvolutionSave.from_snapshot(saved)
	check(restored != null and is_equal_approx(float(restored.civ_state(0)["points"]), 7.0) and is_same((restored.worlds["val"] as SimWorld).teams[0].civ, restored.civ_state(0)), "sauvegarde de campagne : civilisation restaurée et repartagée")
	var old: Dictionary = saved.duplicate(true)
	(old["state"] as Dictionary).erase("civ_states")
	check(EvolutionSave.from_snapshot(old) != null, "ancienne sauvegarde 0.15 relue (aucune civilisation ajoutée)")
	var forged: Dictionary = saved.duplicate(true)
	forged["state"]["civ_states"]["intrus"] = {}
	check(EvolutionSave.from_snapshot(forged) == null, "sauvegarde falsifiée refusée")

# ------------------------------------------------------------------ IA contre IA
func _ai() -> void:
	var c := StarCampaign.new()
	# Profil 256 du jeu (comme evolution_progression_test) : le profil 96 de laboratoire limite trop la navigation.
	CampaignSetup.create(c, 16050, true, 256)
	c.enable_supply_chain()
	var done: bool = false
	for i in 20000:
		c.step()
		if i % 4000 == 0:
			print("  tick %d âges %s voies %s / %s" % [i, str(c.ages), str(c.civ_state(0)["voies"]), str(c.civ_state(1)["voies"])])
		if int(c.ages[0]) >= 4 and int(c.ages[1]) >= 4:
			done = true
			break
	for team in [0, 1]:
		var civ: Dictionary = c.civ_state(team)
		var home: SimWorld = c.worlds[String(c.homes[team])]
		var monuments: int = 0
		for key in (civ["monuments"] as Dictionary).keys():
			monuments += int(civ["monuments"][key])
		print("  camp %d : âge %d, voies %s, monuments %s, améliorations %s, héros %s, points %.1f, pouvoirs %s, forge %d" % [team, int(c.ages[team]), str(civ["voies"]),
			str(civ["monuments"]), str(civ["upgrades"]), str(civ["heroes"].keys()), float(civ["points"]), str(civ["powers"].keys()), home.team_buildings(team, "forge", true).size()])
		check(int(c.ages[team]) >= 3, "IA camp %d : passe les âges par des monuments (âge %d)" % [team, int(c.ages[team])])
		check(monuments >= 1 and (civ["voies"] as Dictionary).has("antique"), "IA camp %d : monument bâti et voie choisie" % team)
		check(not home.team_buildings(team, "forge", true).is_empty() and not (civ["upgrades"] as Dictionary).is_empty(), "IA camp %d : forge et améliorations" % team)
	check(done or int(c.ages[0]) >= 3, "progression IA en temps raisonnable (tick %d)" % c.tick)
