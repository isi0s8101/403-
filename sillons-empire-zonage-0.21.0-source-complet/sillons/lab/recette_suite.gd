class_name RecetteSuite
extends RefCounted
## Recette J1-J8 partagee entre Android (progressive, sans gel de l'UI) et CLI.
## Une assertion PASS n'est comptabilisee que si elle a ete executee.
## La validation graphique, tactile et thermique est EXCLUSIVEMENT manuelle.

const TEST_SEED := 678
const SAVE_PATH := "user://sillons-recette-temporary.save"
const MAX_LOG := 600

var running: bool = false
var finished: bool = false
var phase: String = "prêt"
var results: Array[Dictionary] = []
var count_ok: int = 0
var count_fail: int = 0
var ticks_executed: int = 0
var detail: String = ""
var run_id: String = ""
var started_at: String = ""
var _meeting: StarCampaign = null
var _meeting_ticks: int = 0

var _files: PackedStringArray = PackedStringArray()
var _file_index: int = 0
var _lab: LabScenario = null
var _repeat: LabScenario = null
var _expected_hash: String = ""
var _campaign: StarCampaign = null
var _clone: StarCampaign = null
var _part: int = 0
var _target_tick: int = 0
var _saved: Dictionary = {}
var _home_port: SimWorld.Building = null

func start() -> void:
	run_id = Time.get_datetime_string_from_system(true).replace(":", "-") + "-" + Crypto.new().generate_random_bytes(8).hex_encode()
	started_at = Time.get_datetime_string_from_system(true)
	running = true
	finished = false
	phase = "catalogue"
	results.clear()
	count_ok = 0
	count_fail = 0
	ticks_executed = 0
	_files = LabScenario.list_scenarios()
	_file_index = 0
	_lab = null
	_repeat = null
	_campaign = null
	_clone = null
	_part = 0
	_meeting = null
	_meeting_ticks = 0
	detail = "Initialisation de la recette (graine %d)" % TEST_SEED

func cancel() -> void:
	running = false
	finished = false
	phase = "interrompue"
	detail = "Recette interrompue : résultat non validé."

func is_pass() -> bool:
	return finished and count_fail == 0 and count_ok > 0

func _check(ok: bool, label: String, group: String) -> void:
	if ok:
		count_ok += 1
	else:
		count_fail += 1
	results.append({"ok": ok, "label": label, "group": group})
	if results.size() > MAX_LOG:
		# Les comptes restent exacts même si l'écran limite son historique.
		results.pop_front()

func advance(budget_ms: int = 8, max_operations: int = 128) -> void:
	if not running:
		return
	var started: int = Time.get_ticks_msec()
	var operations: int = 0
	# Double borne CPU : aucune boucle de test ne monopolise la frame Android.
	while running and operations < maxi(1, max_operations) and Time.get_ticks_msec() - started < maxi(1, budget_ms):
		operations += 1
		match phase:
			"catalogue":
				_check(Rules.AGES.size() == 10, "Dix âges disponibles", "J1-J8")
				_check(AgeProgression.troop_name("lancier", 3) != AgeProgression.troop_name("lancier", 1), "Trois styles de troupes par producteur", "J12.2")
				_check(AgeProgression.required_age(1, 2) == 2, "Une amélioration requiert l'âge supérieur", "J12.2")
				_check(AgeProgression.building_hp_multiplier(3) > AgeProgression.building_hp_multiplier(1), "Évolution des bâtiments active", "J12.2")
				_check(Rules.BUILDINGS.has("usine") and Rules.BUILDINGS.has("gare") and Rules.BUILDINGS.has("radar"), "Industrie, voie ferrée et radar", "J3-J5")
				_check(Rules.UNITS.has("char") and Rules.UNITS.has("avion") and Rules.UNITS.has("drone"), "Unités mécanisées et numériques", "J3-J5")
				_check(Rules.UNITS.has("navette") and Rules.UNITS.has("fregate") and Rules.BUILDINGS.has("spatioport"), "Unités et bâtiments spatiaux", "J6-J8")
				_check(_files.size() >= 20, "Banc d'essai historique retrouvé (%d scénarios)" % _files.size(), "J1-J2")
				phase = "laboratoires"
			"laboratoires":
				_advance_labs()
			"industrie":
				_run_modern_checks()
				phase = "campagne"
			"campagne":
				_advance_campaign()
			"empire":
				_run_empire_checks()
				phase = "finalisation"
			"finalisation":
				finished = true
				running = false
				phase = "terminée"
				detail = "Recette automatique : %d PASS / %d FAIL" % [count_ok, count_fail]
			_:
				running = false
				finished = true
				_check(false, "Phase interne inconnue", "Moteur de recette")

func _advance_labs() -> void:
	if _lab == null:
		if _file_index >= _files.size():
			phase = "industrie"
			return
		var path: String = _files[_file_index]
		_lab = LabScenario.load_file(path)
		if _lab == null:
			_check(false, "Chargement " + path.get_file(), "J1-J2")
			_file_index += 1
			return
		_lab.build()
		detail = "Laboratoire %d/%d : %s" % [_file_index + 1, _files.size(), path.get_file()]
		return
	if not _lab.finished:
		_lab.step()
		ticks_executed += 1
		return
	if bool(_lab.data.get("check_determinism", false)):
		if _repeat == null:
			_expected_hash = _lab.world.state_hash()
			_repeat = LabScenario.load_file(_files[_file_index])
			if _repeat == null:
				_check(false, "Rechargement déterminisme", "J1-J2")
			else:
				_repeat.build()
			return
		if not _repeat.finished:
			_repeat.step()
			ticks_executed += 1
			return
		_check(_repeat.world.state_hash() == _expected_hash, "Déterminisme double exécution : " + _files[_file_index].get_file(), "J1-J2")
	for item in _lab.results:
		_check(bool(item["ok"]), "%s : %s" % [_files[_file_index].get_file(), String(item["label"])], "J1-J2")
	_check(_lab.results.size() > 0, "Scénario avec assertions : " + _files[_file_index].get_file(), "J1-J2")
	_file_index += 1
	_lab = null
	_repeat = null

func _run_modern_checks() -> void:
	var w := SimWorld.new()
	w.setup(345)
	w.start_standard()
	for team in w.teams:
		team.res = {"food": 50000.0, "wood": 50000.0, "ore": 50000.0}
		team.pop_cap = 300
		team.age = 8
	var factory: SimWorld.Building = w.spawn_building(0, "usine", Vector2i(32, 80), true)
	_check(factory != null, "Usine bâtie, âge VIII", "J3")
	if factory != null:
		_check(bool(w.issue({"t": "technology", "team": 0, "building": factory.id, "key": "outillage"})["ok"]), "Recherche industrielle lancée", "J3")
		_check(not bool(w.issue({"t": "technology", "team": 0, "building": factory.id, "key": "outillage"})["ok"]), "Double recherche bloquée", "J3")
		_check(bool(w.issue({"t": "train", "team": 0, "building": factory.id, "unit": "char"})["ok"]), "Production char acceptée", "J4")
	var tank: SimWorld.Unit = w.spawn_unit(0, "char", Vector2(8, 8))
	var plane: SimWorld.Unit = w.spawn_unit(1, "avion", Vector2(10, 8))
	var aa: SimWorld.Unit = w.spawn_unit(0, "antiaerien", Vector2(8, 10))
	_check(not ModernSystems.can_target(tank, plane) and ModernSystems.can_target(aa, plane), "Filtrage air-sol / anti-aérien", "J4")
	var drone: SimWorld.Unit = w.spawn_unit(0, "drone", Vector2(8, 8))
	var jammer: SimWorld.Unit = w.spawn_unit(1, "brouilleur", Vector2(9, 9))
	_check(is_equal_approx(ModernSystems.efficiency(w, drone), 0.5), "Brouillage opérationnel", "J5")
	w.teams[0].technologies["contre_mesures"] = true
	_check(is_equal_approx(ModernSystems.efficiency(w, drone), 0.85), "Contre-mesures électroniques", "J5")
	w._kill_unit(jammer, 0)
	_check(is_equal_approx(ModernSystems.efficiency(w, drone), 1.0), "Fin brouillage après destruction", "J5")
	var silo: SimWorld.Building = w.spawn_building(0, "silo", Vector2i(5, 60), true)
	w.teams[0].fog.fill(0)
	_check(not bool(w.issue({"t": "missile", "team": 0, "building": silo.id, "pos": [80, 10]})["ok"]), "Missile refusé dans brouillard", "J5")
	w.teams[0].fog.fill(2)
	_check(bool(w.issue({"t": "missile", "team": 0, "building": silo.id, "pos": [80, 10]})["ok"]), "Missile lancé vers zone révélée", "J5")
	_check(not bool(w.issue({"t": "missile", "team": 0, "building": silo.id, "pos": [80, 10]})["ok"]), "Recharge de missile appliquée", "J5")
	var current_speed: float = 1.0
	for expected in [2.0, 4.0, 8.0, 0.5, 1.0]:
		current_speed = GameConfig.next_speed(current_speed)
		_check(is_equal_approx(current_speed, float(expected)), "Cycle de vitesse ×%s" % str(expected), "Options de vitesse")
	detail = "Scénarios J1-J5 terminés. Campagne orbitale en préparation."

func _find_port(w: SimWorld, team: int, kind: String) -> SimWorld.Building:
	var centers: Array = w.team_buildings(team, "centre", true)
	if centers.is_empty():
		return null
	var center: Vector2 = (centers[0] as SimWorld.Building).center
	for radius in range(7, 24):
		for y in range(maxi(0, int(center.y) - radius), mini(Rules.MAP_SIZE - 4, int(center.y) + radius)):
			for x in range(maxi(0, int(center.x) - radius), mini(Rules.MAP_SIZE - 4, int(center.x) + radius)):
				var cell := Vector2i(x, y)
				if w.footprint_free(cell, 4) and w.has_margin(cell, 4) and center.distance_to(Vector2(cell)) < 24.0:
					return w.spawn_building(team, kind, cell, true)
	return null

func _advance_campaign() -> void:
	match _part:
		0:
			_campaign = StarCampaign.new()
			_campaign.create(TEST_SEED)
			_check(_campaign.worlds.size() == 3 and _campaign.active == "val", "Trois planètes persistantes", "J7")
			_check(not _campaign.switch_to(0, "aurore"), "Planète verrouillée avant IX", "J7")
			_campaign.ages[0] = 9
			_campaign.resources[0] = {"food": 150000.0, "wood": 150000.0, "ore": 150000.0}
			_campaign._sync_all()
			_check(_campaign.is_unlocked(0, "aurore") and not _campaign.is_unlocked(0, "nemesis"), "Âges IX/X débloquent leurs secteurs", "J6-J8")
			var home: SimWorld = _campaign.worlds["val"]
			_home_port = _find_port(home, 0, "spatioport")
			_check(_home_port != null, "Spatioport déployable", "J6")
			if _home_port == null:
				phase = "empire"
				return
			_check(not bool(_campaign.launch_satellite(1, "val", _home_port.id)["ok"]), "Satellite sur port ennemi refusé", "J6")
			_check(bool(_campaign.launch_satellite(0, "val", _home_port.id)["ok"]), "Satellite opérationnel", "J6")
			_check(not bool(_campaign.launch_satellite(0, "val", _home_port.id)["ok"]), "Recharge satellite appliquée", "J6")
			_check(bool(_campaign.scan(0, "aurore", Vector2(47, 47))["ok"]), "Scan orbital vers Aurore", "J6")
			_check((_campaign.worlds["aurore"] as SimWorld).is_visible_to(0, Vector2(47, 47)), "Brouillard temporairement révélé", "J6")
			_check(not bool(_campaign.scan(0, "aurore", Vector2(-1, 0))["ok"]), "Scan malformé rejeté", "J6")
			_check(not bool(_campaign.dispatch(0, "val", _home_port.id, "nemesis")["ok"]), "Interstellaire interdit avant X", "J8")
			var shuttle: SimWorld.Unit = home.spawn_unit(0, "navette", _home_port.center + Vector2(4, 4))
			var worker: SimWorld.Unit = home.spawn_unit(0, "ouvrier", _home_port.center + Vector2(5, 5))
			var unselected: SimWorld.Unit = home.spawn_unit(0, "fusilier", _home_port.center + Vector2(6, 5))
			var old_losses: int = int(home.teams[0].stats["losses"])
			_check(bool(_campaign.dispatch(0, "val", _home_port.id, "aurore", [worker.id], shuttle.id)["ok"]), "Convoi explicite sans troupes non sélectionnées", "J7")
			_check(home.units.has(unselected.id), "Troupe non sélectionnée reste au sol", "J7")
			var shuttle2: SimWorld.Unit = home.spawn_unit(0, "navette", _home_port.center + Vector2(4, 6))
			var worker2: SimWorld.Unit = home.spawn_unit(0, "ouvrier", _home_port.center + Vector2(5, 6))
			var before_money: Dictionary = _campaign.resources[0].duplicate(true)
			_check(not bool(_campaign.dispatch(0, "val", _home_port.id, "aurore", [worker2.id], shuttle2.id)["ok"]), "Double fondation refusée tant que première en vol", "J7")
			_check(_campaign.resources[0] == before_money, "Aucun double prélèvement de fondation", "J7")
			_check(not home.units.has(shuttle.id) and not home.units.has(worker.id), "Unités retirées du secteur source", "J7")
			_check(int(home.teams[0].stats["losses"]) == old_losses, "Aucune perte fictive à l'embarquement", "J7")
			_check(_campaign.flights.size() == 1, "Vol en temps simulé, non instantané", "J7")
			_saved = CampaignSave.snapshot(_campaign)
			_clone = CampaignSave.from_snapshot(_saved)
			_check(_clone != null and _clone.state_hash() == _campaign.state_hash(), "Snapshot campagne déterministe", "J7")
			_target_tick = _campaign.tick + 162
			_part = 1
			detail = "J6-J7 : vol orbital vers Aurore / reprise parallèle"
		1:
			if _campaign.tick < _target_tick:
				_campaign.step()
				if _clone != null:
					_clone.step()
				ticks_executed += 1
				return
			_check(_clone != null and _clone.state_hash() == _campaign.state_hash(), "Même état après reprise et 162 ticks", "J7")
			var aurore: SimWorld = _campaign.worlds["aurore"]
			_check(not aurore.team_buildings(0, "centre", true).is_empty(), "Colonie fondée sur Aurore", "J7")
			_check(aurore.team_units(0, "builder").size() >= 1, "Ouvrier débarqué sur Aurore", "J7")
			_target_tick = _campaign.tick + 25
			_part = 2
		2:
			if _campaign.tick < _target_tick:
				_campaign.step()
				ticks_executed += 1
				return
			var aurore: SimWorld = _campaign.worlds["aurore"]
			_check(not aurore.is_visible_to(0, Vector2(47, 47)) and aurore.is_explored_by(0, Vector2(47, 47)), "Scan expiré mais exploration mémorisée", "J6")
			_campaign.ages[0] = 10
			_campaign._sync_all()
			_check(_campaign.is_unlocked(0, "nemesis"), "Ère interstellaire débloquée", "J8")
			var yard: SimWorld.Building = _find_port(aurore, 0, "chantier_orbital")
			_check(yard != null, "Chantier interstellaire fondé", "J8")
			if yard == null:
				phase = "empire"
				return
			aurore.spawn_unit(0, "fregate", yard.center + Vector2(3, 3))
			aurore.spawn_unit(0, "ouvrier", yard.center + Vector2(4, 4))
			_check(bool(_campaign.dispatch(0, "aurore", yard.id, "nemesis")["ok"]), "Départ interstellaire depuis Aurore", "J8")
			_target_tick = _campaign.tick + 422
			_part = 3
			detail = "J8 : vol interstellaire de 420 ticks vers Némésis"
		3:
			if _campaign.tick < _target_tick:
				_campaign.step()
				ticks_executed += 1
				return
			var home: SimWorld = _campaign.worlds["val"]
			var aurore: SimWorld = _campaign.worlds["aurore"]
			var nemesis: SimWorld = _campaign.worlds["nemesis"]
			_check(not nemesis.team_buildings(0, "centre", true).is_empty(), "Colonie fondée dans autre système", "J8")
			_check(home.tick == aurore.tick and aurore.tick == nemesis.tick, "Simulation simultanée des trois planètes", "J7-J8")
			_check(not _campaign.switch_to(1, "nemesis"), "Bascule interdite au camp non autorisé", "J8")
			_check(_campaign.switch_to(0, "nemesis"), "Navigation multicarte opérationnelle", "J8")
			_part = 4
		4:
			# La recette doit rejeter les champs manquants, y compris si SHA256 est cohérent.
			var malformed: Dictionary = _saved.duplicate(true)
			(malformed["flights"] as Array)[0].erase("ship_hp_ratio")
			_check(CampaignSave.from_snapshot(malformed) == null, "Convoi sans état du vaisseau refusé", "Sauvegarde")
			malformed = _saved.duplicate(true)
			((malformed["flights"] as Array)[0]["units"] as Array)[0].erase("supply")
			_check(CampaignSave.from_snapshot(malformed) == null, "Cargaison sans ravitaillement refusée", "Sauvegarde")
			malformed = _saved.duplicate(true)
			((malformed["flights"] as Array)[0]["units"] as Array)[0]["hp_ratio"] = INF
			_check(CampaignSave.from_snapshot(malformed) == null, "Ratio infini refusé", "Sauvegarde")
			malformed = _saved.duplicate(true)
			malformed["version"] = 999
			_check(CampaignSave.from_snapshot(malformed) == null, "Version inconnue rejetée", "Sauvegarde")
			var err: Error = CampaignSave.save(_campaign, SAVE_PATH)
			_check(err == OK, "Sauvegarde dédiée recette", "Sauvegarde")
			if err == OK:
				var restored: StarCampaign = CampaignSave.load_campaign(SAVE_PATH)
				_check(restored != null and restored.state_hash() == _campaign.state_hash(), "Lecture disque campagne identique", "Sauvegarde")
				# La seconde écriture génère un .bak intact avant altération du principal.
				err = CampaignSave.save(_campaign, SAVE_PATH)
				_check(err == OK, "Rotation du backup réussi", "Sauvegarde")
				var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ_WRITE)
				if file != null:
					file.seek(40)
					file.store_8(255)
					file.close()
				_check(CampaignSave.load_campaign(SAVE_PATH, false) == null, "Principal altéré refusé sans backup", "Sauvegarde")
				var rescue: StarCampaign = CampaignSave.load_campaign(SAVE_PATH)
				_check(rescue != null and rescue.state_hash() == _campaign.state_hash() and CampaignSave.last_load_source == "backup", "Secours SHA-256 restauré", "Sauvegarde")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".bak"))
			# Convois réellement en départ opposé : aucun combat au premier tick.
			_meeting = StarCampaign.new()
			_meeting.create(9921)
			_meeting.flights = [
				{"id": 101, "team": 0, "from": "val", "to": "aurore", "eta": 160, "ship": "navette", "units": [{"type": "ouvrier"}], "colony": false},
				{"id": 102, "team": 1, "from": "aurore", "to": "val", "eta": 160, "ship": "navette", "units": [{"type": "ouvrier"}], "colony": false},
				{"id": 103, "team": 0, "from": "val", "to": "nemesis", "eta": 420, "ship": "fregate", "units": [{"type": "ouvrier"}], "colony": false},
				{"id": 104, "team": 1, "from": "nemesis", "to": "val", "eta": 420, "ship": "fregate", "units": [{"type": "ouvrier"}], "colony": false},
			]
			_meeting._tick_flights()
			_check(_meeting.flights.size() == 4, "Pas d'interception juste après départ", "J8")
			_part = 5
		5:
			_meeting._tick_flights()
			_meeting_ticks += 1
			if _meeting_ticks < 210:
				return
			_check(_meeting.flights.is_empty(), "Deux rencontres calculées sur trajectoire", "J8")
			# Les alertes d'un secteur inactif doivent être visibles dans notices.
			var isolated := StarCampaign.new()
			isolated.create(4455)
			(isolated.worlds["aurore"] as SimWorld).emit("detruit", 0, "Bâtiment détruit lors du test")
			# L'agrégation intervient après step ; vérifier sans dépendre d'un RNG.
			isolated.step()
			var found: bool = false
			for item in isolated.notices:
				if String(item.get("sector", "")) == "aurore" and "Bâtiment détruit" in String(item.get("text", "")):
					found = true
			_check(found, "Alerte planète hors écran agrégée", "J7")
			var capped := StarCampaign.new()
			capped.create(6613)
			var landing: SimWorld = capped.worlds["aurore"]
			var cell: Vector2i = capped._landing_cell(landing, 0)
			if cell.x >= 0:
				landing.spawn_building(0, "centre", cell, true)
				landing.teams[0].pop = landing.teams[0].pop_cap
				var payload: Dictionary = {"id": 151, "team": 0, "from": "val", "to": "aurore", "eta": 0, "duration": 160,
					"ship": "navette", "ship_hp_ratio": 1.0,
					"units": [{"type": "ouvrier", "hp_ratio": 1.0, "supply": 100.0}], "colony": false}
				var prev_count: int = landing.units.size()
				_check(not capped._arrive(payload) and landing.units.size() == prev_count, "Convoi retient sa cargaison si population pleine", "J7")
				landing.teams[0].pop = 0
				_check(capped._arrive(payload) and landing.teams[0].pop == 3, "Débarquement après libération de capacité", "J7")
			else:
				_check(false, "Terrain colonisable du test de capacité", "J7")
			var ai_both := StarCampaign.new()
			ai_both.create(6612, true)
			_check(bool((ai_both.worlds["val"] as SimWorld).teams[0].ai_controlled) and bool((ai_both.worlds["val"] as SimWorld).teams[1].ai_controlled), "Deux camps IA éligibles expansion", "J7")
			ai_both.ages[0] = 9
			ai_both.resources[0] = {"food": 50000.0, "wood": 50000.0, "ore": 50000.0}
			ai_both._sync_all()
			var ai_world: SimWorld = ai_both.worlds["val"]
			var ai_port: SimWorld.Building = _find_port(ai_world, 0, "spatioport")
			if ai_port != null:
				ai_world.spawn_unit(0, "navette", ai_port.center + Vector2(4, 4))
				ai_world.spawn_unit(0, "ouvrier", ai_port.center + Vector2(5, 5))
				ai_both.tick = 300
				ai_both._ai_expansion()
				var ai_launch: bool = false
				for candidate in ai_both.flights:
					if int(candidate["team"]) == 0:
						ai_launch = true
				_check(ai_launch, "Camp 0 piloté par IA lance sa colonisation", "J7")
			else:
				_check(false, "Port spatial de recette du camp 0 IA", "J7")
			phase = "empire"

func _run_empire_checks() -> void:
	var graph := GalaxyGenerator.new(TEST_SEED)
	_check(graph.systems.size() == 16 and graph.route("sol", "proxima").size() >= 2, "Galaxie connectée avec routes", "J11")
	_check(graph.signature() == GalaxyGenerator.new(TEST_SEED).signature(), "Génération déterministe", "J11")
	var c := StarCampaign.new()
	c.create(TEST_SEED, false, true)
	c.ages[0] = 10
	c.resources[0] = {"food": 20000.0, "wood": 20000.0, "ore": 20000.0}
	c._sync_all()
	_check(c.planet_regions != null and c.star_catalog.has_body("val"), "Atlas planétaire disponible", "J9")
	_check(c.star_catalog.galaxy.systems.size() == 16, "Cartes stellaires et galaxie", "J10-J11")
	_check(c.system_resources(0, "sol") == c.resources[0], "Sol : trésor initial conservé", "J12")
	_check(c.system_resources(0, "proxima")["ore"] == 0.0, "Stocks indépendants sur Proxima", "J12")
	_check(not bool(c.ship_supplies(0, "sol", "proxima", {"ore": 10}).get("ok", false)), "Fret sans colonie et port refusé", "J12")
	_check(bool(c.set_system_order(0, "sol", "observe").get("ok", false)), "Directive surveiller", "J12")
	_check(not bool(c.set_system_order(0, "g01", "defend").get("ok", false)), "Directive sur étoile inconnue refusée", "J12")
	var saved: Dictionary = CampaignSave.snapshot(c)
	var restored: StarCampaign = CampaignSave.from_snapshot(saved)
	_check(restored != null and restored.state_hash() == c.state_hash(), "Sauvegarde complète J9–J12", "J12")

func report() -> Dictionary:
	return {"name": "Sillons d'Empire — Recette J1-J12", "seed": TEST_SEED,
		"run_id": run_id, "started_at_utc": started_at,
		"project_version": "0.12.0-j12-candidate",
		"godot": String(Engine.get_version_info().get("string", "inconnu")),
		"automatic_status": "PASS" if is_pass() else ("FAIL" if finished else "NOT_RUN"),
		"automatic_finished": finished, "pass_count": count_ok, "fail_count": count_fail,
		"lab_count": _files.size(), "ticks": ticks_executed,
		"results": results.duplicate(true)}
