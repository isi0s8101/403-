extends SceneTree
## 0.17 — Recette de simulation : files d'ordres (OrderQueue) et commandes du § 5.12 (UnitCommands).
## Chaque commande : effet attendu, refus sans aucun effet (empreinte étendue inchangée), sauvegarde, IA (camp 1).
var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

func fixture() -> SimWorld:
	var w := SimWorld.new()
	w.setup(17010, {"campaign": true})
	for y in 96:
		for x in 96:
			w.set_terrain(Vector2i(x, y), SimWorld.TERRAIN_GRASS)
	for t in [0, 1]:
		w.teams[t].res = {"food": 20000.0, "wood": 20000.0, "ore": 20000.0}
		w.teams[t].age = 3
	w.spawn_building(0, "centre", Vector2i(4, 4), true)
	w.spawn_building(1, "centre", Vector2i(84, 84), true)
	w.teams[0].pop_cap = 200
	w.teams[1].pop_cap = 200
	w.issue({"t": "lab_reveal", "team": 0})
	w.issue({"t": "lab_reveal", "team": 1})
	w.update_fog(true)
	return w

func spawn(w: SimWorld, team: int, kind: String, at: Vector2) -> SimWorld.Unit:
	return w.spawn_unit(team, kind, at)

func run(w: SimWorld, ticks: int) -> void:
	for i in ticks:
		w.step()

func refused(w: SimWorld, cmd: Dictionary, label: String) -> void:
	var before: String = UnitCommands.state_text(w)
	var result: Dictionary = w.issue(cmd)
	check(not bool(result.get("ok", true)) and UnitCommands.state_text(w) == before, label + " (refus sans effet : %s)" % String(result.get("reason", "")))

func _initialize() -> void:
	_queues()
	_group_and_loop()
	_workers()
	_commands_military()
	_commands_workers()
	_commands_buildings()
	_save_and_ai()
	print("UNIT_COMMANDS_RESULT=%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

# ---------------------------------------------------------------- files

func _queues() -> void:
	var w: SimWorld = fixture()
	var u: SimWorld.Unit = spawn(w, 0, "lancier", Vector2(20.5, 20.5))
	var path: Array = [[30.5, 20.5], [30.5, 30.5], [20.5, 30.5]]
	var result: Dictionary = w.issue({"t": "queue_orders", "team": 0, "units": [u.id], "orders": [{"type": "move", "pos": path[0]}, {"type": "move", "pos": path[1]}, {"type": "move", "pos": path[2]}]})
	check(bool(result.get("ok", false)) and u.order_steps.size() == 3 and u.direct, "Q01 trajet A → B → C enregistré, contrôle direct signalé")
	var seen: Array = []
	for i in 600:
		w.step()
		if seen.is_empty() or int(seen.back()) != u.order_step:
			seen.append(u.order_step)
		if u.order_steps.is_empty():
			break
	check(seen == [0, 1, 2, 0] or seen == [0, 1, 2], "Q02 étapes suivies dans l'ordre (%s)" % str(seen))
	check(u.order_steps.is_empty() and u.pos.distance_to(Vector2(20.5, 30.5)) < 1.2, "Q03 file terminée au point C")
	w.issue({"t": "queue_orders", "team": 0, "units": [u.id], "orders": [{"type": "move", "pos": [40.5, 30.5]}, {"type": "move", "pos": [40.5, 40.5]}]})
	result = w.issue({"t": "queue_append", "team": 0, "units": [u.id], "orders": [{"type": "move", "pos": [30.5, 40.5]}]})
	check(bool(result.get("ok", false)) and u.order_steps.size() == 3 and u.order_step == 0, "Q04 mode « Enchaîner » : l'étape s'ajoute sans effacer la file")
	w.issue({"t": "move", "team": 0, "units": [u.id], "pos": [22.5, 22.5]})
	check(u.order_steps.is_empty() and String(u.order["type"]) == "move", "Q05 ordre simple sans « Enchaîner » : la file est remplacée")
	w.issue({"t": "queue_orders", "team": 0, "units": [u.id], "orders": [{"type": "move", "pos": [30.5, 22.5]}, {"type": "move", "pos": [35.5, 22.5]}, {"type": "move", "pos": [40.5, 22.5]}]})
	result = w.issue({"t": "queue_edit", "team": 0, "units": [u.id], "op": "remove", "index": 1})
	check(bool(result.get("ok", false)) and u.order_steps.size() == 2 and Vector2(float(u.order_steps[1]["pos"][0]), 0).x == 40.5, "Q06 suppression d'une étape")
	result = w.issue({"t": "queue_edit", "team": 0, "units": [u.id], "op": "move", "index": 1, "pos": [42.5, 24.5]})
	check(bool(result.get("ok", false)) and float(u.order_steps[1]["pos"][1]) == 24.5, "Q07 déplacement d'une étape")
	result = w.issue({"t": "queue_edit", "team": 0, "units": [u.id], "op": "insert", "index": 1, "step": {"type": "wait", "ticks": 20}})
	check(bool(result.get("ok", false)) and String(u.order_steps[1]["type"]) == "wait" and u.order_steps.size() == 3, "Q08 insertion avant une étape")
	result = w.issue({"t": "queue_edit", "team": 0, "units": [u.id], "op": "undo"})
	check(bool(result.get("ok", false)) and u.order_steps.size() == 2, "Q09 annuler la dernière étape")
	refused(w, {"t": "queue_edit", "team": 0, "units": [u.id], "op": "remove", "index": 9}, "Q10 étape inexistante")
	refused(w, {"t": "queue_edit", "team": 0, "units": [u.id], "op": "move", "index": 1, "pos": [NAN, 3]}, "Q10b destination invalide")
	var sixteen: Array = []
	for i in 16:
		sixteen.append({"type": "move", "pos": [20.5 + float(i), 50.5]})
	check(bool(w.issue({"t": "queue_orders", "team": 0, "units": [u.id], "orders": sixteen}).get("ok", false)), "Q11 16 étapes acceptées")
	refused(w, {"t": "queue_append", "team": 0, "units": [u.id], "orders": [{"type": "move", "pos": [10.5, 10.5]}]}, "Q12 17e étape refusée")
	refused(w, {"t": "queue_orders", "team": 0, "units": [u.id], "orders": sixteen + [{"type": "move", "pos": [9.5, 9.5]}]}, "Q12b file de 17 étapes refusée")
	check(bool(w.issue({"t": "queue_clear", "team": 0, "units": [u.id]}).get("ok", false)) and u.order_steps.is_empty() and String(u.order["type"]) == "hold", "Q13 vider la file : l'unité s'arrête")
	# Étape impossible : îlot entouré d'eau (case praticable, chemin introuvable) → sautée avec alerte.
	for y in range(57, 64):
		for x in range(57, 64):
			if x == 57 or y == 57 or x == 63 or y == 63:
				w.set_terrain(Vector2i(x, y), SimWorld.TERRAIN_WATER)
	w.events.clear()
	w.issue({"t": "queue_orders", "team": 0, "units": [u.id], "orders": [{"type": "move", "pos": [60.5, 60.5]}, {"type": "move", "pos": [24.5, 26.5]}]})
	var alerted: bool = false
	for i in 400:
		w.step()
		for e in w.events:
			alerted = alerted or (String(e["type"]) == "file" and String(e["text"]).contains("inaccessible"))
		w.events.clear()
		if u.order_steps.is_empty():
			break
	check(alerted and u.pos.distance_to(Vector2(24.5, 26.5)) < 1.2, "Q14 étape impossible sautée avec alerte, la suite est exécutée")
	refused(w, {"t": "queue_orders", "team": 0, "units": [u.id], "orders": [{"type": "attack", "target": u.id}]}, "Q15 attaque d'une cible alliée")
	var worker: SimWorld.Unit = spawn(w, 0, "ouvrier", Vector2(14.5, 14.5))
	refused(w, {"t": "queue_orders", "team": 0, "units": [u.id, worker.id], "orders": [{"type": "amove", "pos": [30.5, 30.5]}]}, "Q16 assaut refusé à un ouvrier (sélection mixte)")
	# Ancienne commande 0.14 inchangée.
	var legacy: SimWorld.Unit = spawn(w, 0, "lancier", Vector2(18.5, 34.5))
	check(bool(w.issue({"t": "queue_orders", "team": 0, "units": [legacy.id], "orders": [{"type": "move", "pos": [20.5, 35.5]}, {"type": "wait", "ticks": 30}, {"type": "defend", "pos": [25.5, 35.5]}]}).get("ok", false)), "Q17 ancienne file 0.14 (marcher, attendre, tenir) acceptée")
	refused(w, {"t": "queue_orders", "team": 0, "units": [legacy.id], "orders": [{"type": "escort", "target": -1}]}, "Q18 escorte inexistante refusée")
	# Sauvegarde en cours de file : même étape, même empreinte, même suite.
	w.issue({"t": "queue_orders", "team": 0, "units": [u.id], "orders": [{"type": "move", "pos": [40.5, 26.5]}, {"type": "amove", "pos": [40.5, 40.5]}, {"type": "move", "pos": [26.5, 40.5]}], "loop": true})
	run(w, 120)
	var copy: SimWorld = SaveGame.from_snapshot(SaveGame.snapshot(w))
	var restored: SimWorld.Unit = copy.units.get(u.id) as SimWorld.Unit
	check(restored != null and restored.order_step == u.order_step and restored.order_loop and UnitCommands.state_text(copy) == UnitCommands.state_text(w), "Q19 sauvegarde en cours de file : même étape, même empreinte")
	run(w, 150)
	run(copy, 150)
	check(UnitCommands.state_text(copy) == UnitCommands.state_text(w), "Q20 suite identique après rechargement (déterminisme)")

func _group_and_loop() -> void:
	var w: SimWorld = fixture()
	var ids: Array = []
	for i in 6:
		ids.append(spawn(w, 0, "lancier", Vector2(20.5 + float(i % 3) * 1.2, 20.5 + float(i / 3) * 1.2)).id)
	check(bool(w.issue({"t": "queue_orders", "team": 0, "units": ids, "orders": [{"type": "move", "pos": [40.5, 20.5]}, {"type": "move", "pos": [40.5, 40.5]}]}).get("ok", false)), "G01 file de groupe acceptée (6 unités)")
	var offsets: Dictionary = {}
	for id in ids:
		offsets[str((w.units[id] as SimWorld.Unit).order_offset)] = true
	check(offsets.size() == 6, "G02 chaque membre garde sa place dans la formation")
	var advance_ticks: Dictionary = {}
	for i in 900:
		w.step()
		for id in ids:
			var m: SimWorld.Unit = w.units[id]
			if (m.order_step >= 1 or m.order_steps.is_empty()) and not advance_ticks.has(id):
				advance_ticks[id] = w.tick
		if advance_ticks.size() == ids.size():
			break
	var unique: Dictionary = {}
	for value in advance_ticks.values():
		unique[value] = true
	check(advance_ticks.size() == 6 and unique.size() == 1, "G03 le groupe attend ses retardataires et repart ensemble (%s)" % str(unique.keys()))
	# Patrouille en boucle sur 3 points, 2 tours.
	var p: SimWorld.Unit = spawn(w, 0, "lancier", Vector2(60.5, 60.5))
	w.issue({"t": "queue_orders", "team": 0, "units": [p.id], "orders": [{"type": "amove", "pos": [66.5, 60.5]}, {"type": "amove", "pos": [66.5, 66.5]}, {"type": "amove", "pos": [60.5, 66.5]}], "loop": true})
	var wraps: int = 0
	var last: int = 0
	for i in 1400:
		w.step()
		if p.order_step < last:
			wraps += 1
		last = p.order_step
		if wraps >= 2:
			break
	check(wraps >= 2 and not p.order_steps.is_empty(), "G04 patrouille en boucle sur 3 points : 2 tours complets")
	check(bool(w.issue({"t": "queue_edit", "team": 0, "units": [p.id], "op": "loop", "value": false}).get("ok", false)) and not p.order_loop, "G05 bascule « En boucle » désactivée")

func _workers() -> void:
	var w: SimWorld = fixture()
	var a: SimWorld.Unit = spawn(w, 0, "ouvrier", Vector2(12.5, 12.5))
	var b: SimWorld.Unit = spawn(w, 0, "ouvrier", Vector2(13.5, 12.5))
	var sites: Array = []
	for cell in [Vector2i(16, 10), Vector2i(20, 10), Vector2i(24, 10)]:
		sites.append(int(w.issue({"t": "lab_building", "team": 0, "type": "maison", "cell": [cell.x, cell.y], "complete": false})["id"]))
	var result: Dictionary = w.issue({"t": "queue_orders", "team": 0, "units": [a.id, b.id], "orders": [{"type": "build", "building": sites[0]}, {"type": "build", "building": sites[1]}, {"type": "build", "building": sites[2]}]})
	check(bool(result.get("ok", false)) and a.manual and a.task == "build" and a.build_id == sites[0], "W01 ouvriers : « bâtir A puis B puis C » accepté")
	var finished: Array = []
	for i in 2400:
		w.step()
		for e in w.events:
			if String(e["type"]) == "acheve":
				finished.append(int(e["building"]))
		w.events.clear()
		if finished.size() >= 3:
			break
	check(finished == sites, "W02 chantiers achevés dans l'ordre demandé")
	run(w, 12)
	check(not a.manual and not a.direct and a.order_steps.is_empty(), "W03 file finie : retour à l'économie automatique")
	refused(w, {"t": "queue_orders", "team": 0, "units": [a.id], "orders": [{"type": "build", "building": sites[0]}]}, "W04 bâtir un bâtiment déjà achevé")

# ---------------------------------------------------------------- commandes militaires

func _commands_military() -> void:
	var w: SimWorld = fixture()
	var u: SimWorld.Unit = spawn(w, 0, "lancier", Vector2(30.5, 30.5))
	w.issue({"t": "move", "team": 0, "units": [u.id], "pos": [50.5, 30.5]})
	run(w, 5)
	check(bool(w.issue({"t": "stop", "team": 0, "units": [u.id]}).get("ok", false)) and String(u.order["type"]) == "hold" and u.order_steps.is_empty(), "C01 arrêt : ordre et file vidés, l'unité reste sur place")
	refused(w, {"t": "stop", "team": 0, "units": []}, "C02 arrêt sans unité")
	refused(w, {"t": "stop", "team": 0, "units": [999999]}, "C02b arrêt d'une unité inconnue")
	var foe: SimWorld.Unit = spawn(w, 1, "lancier", u.pos + Vector2(4.0, 0.0))
	foe.stance = "passive"
	check(bool(w.issue({"t": "hold", "team": 0, "units": [u.id]}).get("ok", false)) and u.stance == "hold", "C03 tenir la position : posture « tenir »")
	var before: Vector2 = u.pos
	run(w, 30)
	check(u.pos.distance_to(before) < 0.4, "C04 tenir : pas de poursuite d'un ennemi hors de portée")
	check(bool(w.issue({"t": "stance", "team": 0, "units": [u.id], "value": "aggressive"}).get("ok", false)) and u.stance == "", "C05 posture agressive : poursuit à nouveau")
	run(w, 30)
	check(u.pos.distance_to(before) > 1.0, "C06 agressive : l'unité engage l'ennemi visible")
	refused(w, {"t": "stance", "team": 0, "units": [u.id], "value": "furieuse"}, "C07 posture inconnue")
	var calm: SimWorld.Unit = spawn(w, 0, "lancier", Vector2(70.5, 30.5))
	var bully: SimWorld.Unit = spawn(w, 1, "lancier", Vector2(71.0, 30.5))
	w.issue({"t": "stance", "team": 0, "units": [calm.id], "value": "passive"})
	run(w, 30)
	check(bully.hp >= bully.max_hp - 0.01, "C08 passive : ne tire jamais, même attaquée")
	# Cible prioritaire.
	var archer_target: SimWorld.Unit = spawn(w, 1, "tireur", Vector2(36.5, 52.5))
	var spear_target: SimWorld.Unit = spawn(w, 1, "lancier", Vector2(33.5, 52.5))
	var hunter: SimWorld.Unit = spawn(w, 0, "cavalier", Vector2(31.5, 52.5))
	w.update_fog(true)
	check(UnitCommands.acquire(w, hunter, float(Rules.UNITS["cavalier"]["vision"])) == spear_target, "C09 sans priorité : la plus proche")
	check(bool(w.issue({"t": "target_priority", "team": 0, "units": [hunter.id], "value": "ranged"}).get("ok", false)) and UnitCommands.acquire(w, hunter, float(Rules.UNITS["cavalier"]["vision"])) == archer_target, "C10 cible prioritaire : les tireurs d'abord")
	refused(w, {"t": "target_priority", "team": 0, "units": [hunter.id], "value": "dragons"}, "C11 priorité inconnue")
	# Formation d'escouade.
	var squad_ids: Array = []
	for i in 6:
		var r: Dictionary = w.issue({"t": "lab_spawn", "team": 0, "unit": "lancier", "pos": [20.5 + float(i), 70.5], "new_squad": i == 0})
		squad_ids.append(int(r["id"]))
	var squad_id: int = (w.units[squad_ids[0]] as SimWorld.Unit).squad_id
	check(bool(w.issue({"t": "formation", "team": 0, "squad": squad_id, "value": "line"}).get("ok", false)) and (w.squads[squad_id] as SimWorld.Squad).formation == "line", "C12 formation « ligne » choisie pour l'escouade")
	w.issue({"t": "move", "team": 0, "squad": squad_id, "pos": [20.5, 84.5]})
	run(w, 220)
	var xs: Array = []
	var ys: Array = []
	for id in squad_ids:
		xs.append((w.units[id] as SimWorld.Unit).pos.x)
		ys.append((w.units[id] as SimWorld.Unit).pos.y)
	check(float(xs.max()) - float(xs.min()) > 4.0 and float(ys.max()) - float(ys.min()) < 2.5, "C13 ligne perpendiculaire à la marche, orientée vers la destination")
	refused(w, {"t": "formation", "team": 0, "units": [u.id], "value": "line"}, "C14 formation sans escouade")
	refused(w, {"t": "formation", "team": 0, "squad": squad_id, "value": "tortue"}, "C14b formation inconnue")
	# Repli.
	var far: SimWorld.Unit = spawn(w, 0, "lancier", Vector2(60.5, 10.5))
	var d0: float = far.pos.distance_to(Vector2(6, 6))
	check(bool(w.issue({"t": "retreat", "team": 0, "units": [far.id]}).get("ok", false)), "C15 repli vers la base accepté")
	run(w, 150)
	check(far.pos.distance_to(Vector2(6, 6)) < d0 - 10.0, "C16 repli : l'unité revient vers le centre sans combattre")
	var lost := SimWorld.new()
	lost.setup(17011, {"campaign": true})
	var orphan: SimWorld.Unit = lost.spawn_unit(0, "lancier", Vector2(30.5, 30.5))
	refused(lost, {"t": "retreat", "team": 0, "units": [orphan.id]}, "C17 repli sans centre ni fort")
	# Suivre.
	var leader: SimWorld.Unit = spawn(w, 0, "eclaireur", Vector2(40.5, 60.5))
	var tail: SimWorld.Unit = spawn(w, 0, "lancier", Vector2(38.5, 60.5))
	check(bool(w.issue({"t": "follow", "team": 0, "units": [tail.id], "target": leader.id}).get("ok", false)), "C18 suivre une unité alliée")
	w.issue({"t": "move", "team": 0, "units": [leader.id], "pos": [48.5, 64.5]})
	run(w, 120)
	check(tail.pos.distance_to(leader.pos) < 3.5, "C19 suivre : l'unité reste près de la cible")
	refused(w, {"t": "follow", "team": 0, "units": [tail.id], "target": foe.id}, "C20 suivre une unité ennemie")
	# Exploration automatique.
	var fresh := SimWorld.new()
	fresh.setup(17012, {"campaign": true})
	for y in 96:
		for x in 96:
			fresh.set_terrain(Vector2i(x, y), SimWorld.TERRAIN_GRASS)
	fresh.spawn_building(0, "centre", Vector2i(4, 4), true)
	var scout: SimWorld.Unit = fresh.spawn_unit(0, "eclaireur", Vector2(10.5, 10.5))
	fresh.update_fog(true)
	var explored_before: int = 0
	for value in fresh.teams[0].fog:
		if value > 0: explored_before += 1
	check(bool(fresh.issue({"t": "explore", "team": 0, "units": [scout.id]}).get("ok", false)), "C21 exploration automatique lancée")
	run(fresh, 400)
	var explored_after: int = 0
	for value in fresh.teams[0].fog:
		if value > 0: explored_after += 1
	check(explored_after > explored_before + 400, "C22 exploration : %d → %d cases découvertes" % [explored_before, explored_after])
	refused(w, {"t": "explore", "team": 0, "units": [u.id]}, "C23 exploration refusée : carte entièrement explorée")
	# Garnison.
	var hall: SimWorld.Building = w.spawn_building(0, "caserne", Vector2i(40, 40), true)
	var garrison_ids: Array = []
	for i in 3:
		garrison_ids.append(spawn(w, 0, "tireur", Vector2(38.5 + float(i), 44.5)).id)
	check(bool(w.issue({"t": "garrison", "team": 0, "units": garrison_ids, "building": hall.id}).get("ok", false)), "C24 garnison acceptée (3 places sur 6)")
	run(w, 80)
	var inside: int = 0
	for id in garrison_ids:
		if (w.units[id] as SimWorld.Unit).garrison_id == hall.id: inside += 1
	check(inside == 3, "C25 les tireurs sont entrés en garnison")
	var raider: SimWorld.Unit = spawn(w, 1, "lancier", hall.center + Vector2(3.6, 0.0))
	raider.stance = "passive"
	run(w, 40)
	check(raider.hp < raider.max_hp, "C26 la garnison tire depuis le bâtiment")
	var lodge: SimWorld.Building = w.spawn_building(0, "maison", Vector2i(46, 40), true)
	var crowd: Array = []
	for i in 4:
		crowd.append(spawn(w, 0, "lancier", Vector2(46.5 + float(i), 44.5)).id)
	refused(w, {"t": "garrison", "team": 0, "units": crowd, "building": lodge.id}, "C27 garnison pleine")
	refused(w, {"t": "garrison", "team": 0, "units": [hunter.id], "building": hall.id}, "C27b cavalerie refusée en garnison")
	check(bool(w.issue({"t": "ungarrison", "team": 0, "building": hall.id}).get("ok", false)) and (w.units[garrison_ids[0]] as SimWorld.Unit).garrison_id == -1, "C28 sortie de garnison")
	w.issue({"t": "garrison", "team": 0, "units": garrison_ids, "building": hall.id})
	run(w, 80)
	w.issue({"t": "lab_kill", "team": 0, "id": hall.id})
	run(w, 2)
	check((w.units[garrison_ids[0]] as SimWorld.Unit).garrison_id == -1 and w.walkable(w.cell_of((w.units[garrison_ids[0]] as SimWorld.Unit).pos)), "C29 bâtiment détruit : la garnison est éjectée sur une case libre")

# ---------------------------------------------------------------- ouvriers

func _commands_workers() -> void:
	var w: SimWorld = fixture()
	var a: SimWorld.Unit = spawn(w, 0, "ouvrier", Vector2(14.5, 14.5))
	var house: SimWorld.Building = w.spawn_building(0, "maison", Vector2i(18, 14), true)
	house.hp = house.max_hp * 0.5
	var wood_before: float = float(w.teams[0].res["wood"])
	check(bool(w.issue({"t": "repair", "team": 0, "units": [a.id], "building": house.id}).get("ok", false)), "O01 réparation acceptée")
	run(w, 400)
	check(house.hp >= house.max_hp - 0.01 and float(w.teams[0].res["wood"]) < wood_before, "O02 bâtiment réparé, coût prélevé (%.1f bois)" % (wood_before - float(w.teams[0].res["wood"])))
	refused(w, {"t": "repair", "team": 0, "units": [a.id], "building": house.id}, "O03 rien à réparer")
	var site: int = int(w.issue({"t": "lab_building", "team": 0, "type": "maison", "cell": [22, 18], "complete": false})["id"])
	check(bool(w.issue({"t": "build_assign", "team": 0, "units": [a.id], "building": site}).get("ok", false)) and a.task == "build" and a.build_id == site, "O04 « bâtir ce chantier » assigné")
	for i in 900:
		w.step()
		if (w.buildings[site] as SimWorld.Building).complete:
			break
	var built: SimWorld.Building = w.buildings[site]
	check(built.complete, "O05 chantier achevé par l'ouvrier désigné (progression %.2f, tâche %s, état %s, %s)" % [built.progress, a.task, a.state, a.blocked_reason])
	var tree: SimWorld.ResNode = w.add_node("arbre", Vector2(30.5, 14.5), 200.0)
	w.update_fog(true)
	check(bool(w.issue({"t": "gather", "team": 0, "units": [a.id], "node": tree.id}).get("ok", false)) and a.task == "wood" and a.node_id == tree.id and a.manual, "O06 « récolter ici » : ouvrier attaché au gisement")
	run(w, 120)
	check(a.carry_amt > 0.0 or float(w.teams[0].res["wood"]) > 0.0, "O07 l'ouvrier récolte le gisement désigné")
	check(bool(w.issue({"t": "return_drop", "team": 0, "units": [a.id]}).get("ok", false)), "O08 retour au dépôt accepté")
	run(w, 200)
	check(a.carry_amt <= 0.01, "O09 ressource déposée")
	refused(w, {"t": "return_drop", "team": 0, "units": [a.id]}, "O10 retour au dépôt sans charge")
	tree.amount = 0.0
	refused(w, {"t": "gather", "team": 0, "units": [a.id], "node": tree.id}, "O11 gisement épuisé")
	check(bool(w.issue({"t": "worker_auto", "team": 0, "units": [a.id]}).get("ok", false)) and not a.manual and not a.direct, "O12 retour à l'automatique d'un toucher")
	var soldier: SimWorld.Unit = spawn(w, 0, "lancier", Vector2(16.5, 20.5))
	refused(w, {"t": "repair", "team": 0, "units": [soldier.id], "building": house.id}, "O13 réparation réservée aux ouvriers")

# ---------------------------------------------------------------- bâtiments

func _commands_buildings() -> void:
	var w: SimWorld = fixture()
	var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
	var barracks: SimWorld.Building = w.spawn_building(0, "caserne", Vector2i(16, 16), true)
	var food_before: float = float(w.teams[0].res["food"])
	for kind in ["lancier", "tireur", "lancier"]:
		w.issue({"t": "train", "team": 0, "building": barracks.id, "unit": kind})
	var result: Dictionary = w.issue({"t": "cancel_train_at", "team": 0, "building": barracks.id, "index": 1})
	check(bool(result.get("ok", false)) and barracks.queue == ["lancier", "lancier"], "B01 annulation d'un élément précis de la file")
	check(is_equal_approx(float(w.teams[0].res["food"]), food_before - 2.0 * float(Rules.UNITS["lancier"]["cost"].get("food", 0))), "B02 remboursement exact de l'élément annulé")
	refused(w, {"t": "cancel_train_at", "team": 0, "building": barracks.id, "index": 5}, "B03 élément inexistant")
	barracks.queue.clear()
	check(bool(w.issue({"t": "repeat_train", "team": 0, "building": barracks.id, "unit": "lancier"}).get("ok", false)) and barracks.repeat_unit == "lancier", "B04 production répétée activée")
	var trained: int = 0
	for i in 900:
		w.step()
		for e in w.events:
			if String(e["type"]) == "unite": trained += 1
		w.events.clear()
	check(trained >= 3, "B05 la caserne relance seule la production (%d lanciers)" % trained)
	w.teams[0].pop_cap = w.teams[0].pop
	barracks.queue.clear()
	run(w, 30)
	check(barracks.queue.is_empty(), "B06 production répétée suspendue quand la population est pleine (aucune dépense)")
	refused(w, {"t": "repeat_train", "team": 0, "building": cc.id, "unit": "heros_antique"}, "B07 héros : production répétée refusée")
	refused(w, {"t": "repeat_train", "team": 0, "building": barracks.id, "unit": "ouvrier"}, "B07b unité non formée ici")
	w.teams[0].pop_cap = 200
	var ore: SimWorld.ResNode = w.add_node("minerai", Vector2(14.5, 4.5), 400.0)
	w.update_fog(true)
	check(bool(w.issue({"t": "rally_resource", "team": 0, "building": cc.id, "node": ore.id}).get("ok", false)) and cc.rally_node == ore.id, "B08 ralliement des ouvriers sur une ressource")
	w.issue({"t": "train", "team": 0, "building": cc.id, "unit": "ouvrier"})
	cc.prod_timer = 999.0
	w.step()
	var recruit: SimWorld.Unit = w.units[w.units.keys().back()]
	check(recruit.type == "ouvrier" and recruit.task == "ore" and recruit.node_id == ore.id, "B09 le nouvel ouvrier va directement récolter")
	ore.amount = 0.0
	refused(w, {"t": "rally_resource", "team": 0, "building": cc.id, "node": ore.id}, "B10 ressource épuisée refusée")
	var site: int = int(w.issue({"t": "lab_building", "team": 0, "type": "maison", "cell": [30, 30], "complete": false})["id"])
	var wood_before: float = float(w.teams[0].res["wood"])
	result = w.issue({"t": "demolish", "team": 0, "building": site})
	check(bool(result.get("ok", false)) and not w.buildings.has(site) and float(w.teams[0].res["wood"]) > wood_before, "B11 démolition d'un chantier : moitié du coût remboursée")
	refused(w, {"t": "demolish", "team": 0, "building": cc.id}, "B12 dernier centre : démolition refusée")
	refused(w, {"t": "demolish", "team": 1, "building": barracks.id}, "B13 démolition d'un bâtiment adverse refusée")

# ---------------------------------------------------------------- sauvegarde et IA

func _save_and_ai() -> void:
	var w: SimWorld = fixture()
	var u: SimWorld.Unit = spawn(w, 0, "lancier", Vector2(30.5, 30.5))
	var r: Dictionary = w.issue({"t": "lab_spawn", "team": 0, "unit": "lancier", "pos": [32.5, 30.5], "new_squad": true})
	var sid: int = (w.units[int(r["id"])] as SimWorld.Unit).squad_id
	var hall: SimWorld.Building = w.spawn_building(0, "caserne", Vector2i(40, 40), true)
	var cc: SimWorld.Building = w.team_buildings(0, "centre", true)[0]
	var tree: SimWorld.ResNode = w.add_node("arbre", Vector2(20.5, 10.5), 300.0)
	w.update_fog(true)
	w.issue({"t": "stance", "team": 0, "units": [u.id], "value": "defensive"})
	w.issue({"t": "target_priority", "team": 0, "units": [u.id], "value": "cavalry"})
	w.issue({"t": "formation", "team": 0, "squad": sid, "value": "box"})
	w.issue({"t": "repeat_train", "team": 0, "building": hall.id, "unit": "tireur"})
	w.issue({"t": "rally_resource", "team": 0, "building": cc.id, "node": tree.id})
	var copy: SimWorld = SaveGame.from_snapshot(SaveGame.snapshot(w))
	var cu: SimWorld.Unit = copy.units[u.id]
	check(cu.stance == "defensive" and cu.target_pref == "cavalry" and (copy.squads[sid] as SimWorld.Squad).formation == "box" and (copy.buildings[hall.id] as SimWorld.Building).repeat_unit == "tireur" and (copy.buildings[cc.id] as SimWorld.Building).rally_node == tree.id, "S01 postures, priorités, formation, production répétée et ralliement sauvegardés")
	check(UnitCommands.state_text(copy) == UnitCommands.state_text(w), "S02 empreinte étendue identique après rechargement")
	# IA : mêmes commandes, mêmes conditions.
	var enemy: SimWorld.Unit = spawn(w, 1, "lancier", Vector2(70.5, 70.5))
	check(bool(w.issue({"t": "stance", "team": 1, "units": [enemy.id], "value": "hold"}).get("ok", false)) and enemy.stance == "hold", "S03 IA (camp 1) : même commande de posture")
	check(bool(w.issue({"t": "retreat", "team": 1, "units": [enemy.id]}).get("ok", false)), "S04 IA : repli vers son propre centre")
	refused(w, {"t": "stop", "team": 1, "units": [u.id]}, "S05 IA : aucune commande sur les unités du joueur")
	refused(w, {"t": "garrison", "team": 1, "units": [enemy.id], "building": hall.id}, "S06 IA : pas de garnison dans un bâtiment du joueur")
