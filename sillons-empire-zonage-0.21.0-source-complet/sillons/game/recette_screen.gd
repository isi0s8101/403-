extends Control
## Écran Android de recette assistée, sans écriture sur une sauvegarde de partie.
## Les critères physiques ne sont JAMAIS marqués PASS automatiquement.

const MANUAL_CHECKS := [
	{"id": "boot", "name": "Installation / accueil", "how": "Ouvrir l'APK en paysage ; aucune erreur à l'écran"},
	{"id": "touch", "name": "Gestes tactiles", "how": "En partie : toucher, appui long, pan, pinch, rotation, ordres"},
	{"id": "visual", "name": "Terrain et graphismes J2.1", "how": "Observer PBR, bâtiments, eau, animations, ombres et lisibilité"},
	{"id": "economy", "name": "Économie et IA J1–J5", "how": "En escarmouche : récolter, bâtir, combattre et commander"},
	{"id": "orbital", "name": "Panneau spatial J6–J8", "how": "Atelier âge X : satellite, scan, secteurs, convois"},
	{"id": "save", "name": "Sauvegarde utilisateur", "how": "Sauvegarder en cours de partie, quitter et reprendre"},
	{"id": "fps", "name": "Performances Galaxy S25 Ultra", "how": "Mesurer FPS, pauses, réactivité à 1× / 4× / 8×"},
	{"id": "thermal", "name": "Stabilité sur durée", "how": "Au moins 10 min de charge ; vérifier crash, chauffe et RAM"},
	{"id": "planet", "name": "Atlas géant J9", "how": "Parcourir 2 régions, dézoom, retour, sauvegarde et unités conservées"},
	{"id": "system", "name": "Système J10", "how": "Dézoomer vers orbite et système ; revenir à la même région"},
	{"id": "galaxy", "name": "Galaxie J11", "how": "Sonde, brouillard du camp, route, colonie puis sauvegarde"},
	{"id": "orders", "name": "Commandement J12", "how": "Défense déléguée, ordre d'exploration, approvisionnement auto"},
	{"id": "freight", "name": "Fret multisaut J12", "how": "Comparer stocks source et cible, ETA, tenue au relais, sauvegarde"},
	{"id": "view_tech", "name": "Accès technologique aux vues", "how": "Vérifier les prérequis Cartographie → Orbite → Système → Galaxie, verrouillage sans recherche"},
	{"id": "building_tree", "name": "Évolution locale des bâtiments et unités", "how": "Améliorer une caserne et ses lanciers, comparer avec une autre caserne, sauvegarder et reprendre"},
]

var suite: RecetteSuite = null
var manual: Dictionary = {}
var buttons: Dictionary = {}
var auto_status: Label
var automatic_log: RichTextLabel
var manual_status: Label
var info_status: Label
var start_button: Button
var cancel_button: Button
var speed_button: Button
var _display_clock: float = 0.0
var _suite_was_running: bool = false

func _ready() -> void:
	if GameConfig.recette_suite is RecetteSuite:
		suite = GameConfig.recette_suite as RecetteSuite
	else:
		suite = RecetteSuite.new()
		GameConfig.recette_suite = suite
	var background := ColorRect.new()
	background.color = Color(0.018, 0.045, 0.06)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(_label("RECETTE INTÉGRALE  |  J1–J12", 25))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_button("Menu principal", _back))
	var sub := _label("Graine fixe 678 · Aucune sauvegarde de partie modifiée · Contrôles Android à confirmer manuellement", 13)
	column.add_child(sub)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	column.add_child(columns)
	var left := _panel(columns, 530)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	lv.add_child(_label("1. TESTS AUTOMATIQUES", 18))
	auto_status = _label("Non exécutés", 15)
	lv.add_child(auto_status)
	var actions := HBoxContainer.new()
	lv.add_child(actions)
	start_button = _button("Démarrer", _start)
	actions.add_child(start_button)
	cancel_button = _button("Arrêter", _stop)
	cancel_button.disabled = true
	actions.add_child(cancel_button)
	speed_button = _button("", _speed)
	actions.add_child(speed_button)
	_speed_caption()
	lv.add_child(_label("Tests : J1–J8 et vérifications moteur J9–J12 ; recette approfondie CLI via verify-j12.sh.", 12))
	automatic_log = RichTextLabel.new()
	automatic_log.fit_content = false
	automatic_log.scroll_active = true
	automatic_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	automatic_log.add_theme_font_size_override("normal_font_size", 13)
	lv.add_child(automatic_log)
	var right := _panel(columns, 530)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 5)
	right.add_child(rv)
	rv.add_child(_label("2. RECETTE MATÉRIELLE ANDROID", 18))
	manual_status = _label("0/%d contrôles validés · Aucune certification automatique" % MANUAL_CHECKS.size(), 13)
	rv.add_child(manual_status)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 5)
	scroll.add_child(rows)
	for i in range(MANUAL_CHECKS.size()):
		var check: Dictionary = MANUAL_CHECKS[i]
		var old_manual: Dictionary = GameConfig.recette_manual if GameConfig.recette_manual_run_id == suite.run_id and not suite.run_id.is_empty() else {}
		var previous: String = String(old_manual.get(String(check["id"]), "NOT_TESTED"))
		manual[check["id"]] = previous if previous in ["NOT_TESTED", "PASS", "FAIL"] else "NOT_TESTED"
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label := VBoxContainer.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		label.add_child(_label(String(check["name"]), 14))
		var hint := _label(String(check["how"]), 12)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_child(hint)
		var btn := _button("À contrôler", _cycle_manual.bind(i))
		btn.custom_minimum_size = Vector2(126, 46)
		buttons[check["id"]] = btn
		row.add_child(btn)
	var foot := HBoxContainer.new()
	column.add_child(foot)
	foot.add_child(_button("ENREGISTRER LE RAPPORT JSON", _save_report))
	foot.add_child(_button("COPIER LE RAPPORT", _copy_report))
	foot.add_child(_button("Ouvrir l'atelier spatial", _open_sandbox))
	foot.add_child(_button("Partie normale", _play))
	info_status = _label("Statut : aucune exécution. Les contrôles manuels restent en attente.", 12)
	info_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(info_status)
	_refresh()

func _panel(parent: Control, width_min: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = width_min
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.14, 0.94)
	style.border_color = Color(0.17, 0.37, 0.43)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

func _label(value: String, size: int = 14) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.85, 0.95, 0.97))
	return l

func _button(value: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 43
	b.pressed.connect(action)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _process(delta: float) -> void:
	if suite.running:
		# Nombre de ticks de test modulé par la vitesse demandée.
		# Plafond CPU indépendant (8 ms/frame) pour garder l'UI tactile réactive.
		var operations: int = maxi(4, mini(128, int(16.0 * GameConfig.sim_speed)))
		suite.advance(8, operations)
	var just_finished: bool = _suite_was_running and not suite.running
	_suite_was_running = suite.running
	_display_clock += delta
	if _display_clock > 0.18 or just_finished:
		_display_clock = 0.0
		_refresh()

func _start() -> void:
	# Les validations manuelles ne sont PAS réutilisables pour une nouvelle exécution.
	suite.start()
	manual.clear()
	for check in MANUAL_CHECKS:
		manual[String(check["id"])] = "NOT_TESTED"
	GameConfig.recette_manual = manual.duplicate(true)
	GameConfig.recette_manual_run_id = suite.run_id
	GameConfig.speed_benchmarks.clear()
	info_status.text = "Nouvelle exécution " + suite.run_id + " · validations Android remises à zéro."
	_refresh()

func _stop() -> void:
	suite.cancel()
	_refresh()

func _speed() -> void:
	GameConfig.sim_speed = GameConfig.next_speed(GameConfig.sim_speed)
	_speed_caption()

func _speed_caption() -> void:
	if speed_button != null:
		speed_button.text = "Recette ×%s" % str(GameConfig.sim_speed).replace(".0", "")

func _cycle_manual(index: int) -> void:
	var key: String = String(MANUAL_CHECKS[index]["id"])
	var current: String = String(manual[key])
	manual[key] = "PASS" if current == "NOT_TESTED" else ("FAIL" if current == "PASS" else "NOT_TESTED")
	GameConfig.recette_manual = manual.duplicate(true)
	GameConfig.recette_manual_run_id = suite.run_id
	_refresh()

func _final_status() -> String:
	var all_pass: bool = suite.is_pass()
	var pending: bool = false
	for key in manual.keys():
		if manual[key] == "FAIL":
			return "FAIL"
		if manual[key] != "PASS":
			pending = true
	if suite.finished and suite.count_fail > 0:
		return "FAIL"
	return "PASS" if all_pass and not pending else "INCOMPLETE"

func _refresh() -> void:
	start_button.disabled = suite.running
	cancel_button.disabled = not suite.running
	var state: String = "EN COURS" if suite.running else ("PASS" if suite.is_pass() else ("FAIL" if suite.finished else "NON EXÉCUTÉ"))
	auto_status.text = "%s  ·  %d PASS  /  %d FAIL  ·  %d ticks\n%s" % [state, suite.count_ok, suite.count_fail, suite.ticks_executed, suite.detail]
	var display := PackedStringArray()
	var first: int = maxi(0, suite.results.size() - 28)
	for i in range(first, suite.results.size()):
		var item: Dictionary = suite.results[i]
		display.append("%s | %s | %s" % ["PASS" if item["ok"] else "FAIL", String(item["group"]), String(item["label"])])
	automatic_log.text = "\n".join(display)
	var manual_count: int = 0
	for check in MANUAL_CHECKS:
		var key: String = String(check["id"])
		var value: String = String(manual[key])
		var btn: Button = buttons[key]
		btn.text = "PASS" if value == "PASS" else ("ÉCHEC" if value == "FAIL" else "À contrôler")
		if value == "PASS":
			manual_count += 1
	manual_status.text = "%d/%d PASS · %s · %d vitesses mesurées" % [manual_count, MANUAL_CHECKS.size(), _final_status(), GameConfig.speed_benchmarks.size()]

func _build_report() -> Dictionary:
	var document: Dictionary = suite.report()
	document["android_manual"] = manual.duplicate(true)
	document["android_manual_run_id"] = GameConfig.recette_manual_run_id
	document["device_model"] = OS.get_model_name()
	document["speed_benchmarks"] = GameConfig.speed_benchmarks.duplicate(true)
	document["overall_status"] = _final_status()
	document["created_at"] = Time.get_datetime_string_from_system(true)
	document["note"] = "Les contrôles matériels sont déclarés manuellement par l'opérateur."
	return document

func _copy_report() -> void:
	var json_text: String = JSON.stringify(_build_report(), "\t")
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		info_status.text = "Presse-papiers non disponible sur cet appareil : utiliser le fichier JSON."
		return
	DisplayServer.clipboard_set(json_text)
	info_status.text = "Rapport JSON copié : coller dans un message, une note ou un fichier."

func _save_report() -> void:
	var document: Dictionary = _build_report()
	var path := "user://recette-j1-j12-%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		info_status.text = "Écriture impossible : code %d" % FileAccess.get_open_error()
		return
	f.store_string(JSON.stringify(document, "\t") + "\n")
	f.flush()
	var error: Error = f.get_error()
	f.close()
	info_status.text = "Rapport : %s (%s)" % [path, "OK" if error == OK else "erreur %d" % error]

func _back() -> void:
	get_tree().change_scene_to_file("res://game/main_menu.tscn")

func _open_sandbox() -> void:
	# Configuration équivalente au laboratoire spatial : aucun accès à la sauvegarde.
	var c := StarCampaign.new()
	c.create(678)
	c.ages[0] = 10
	for key in ViewTechnology.RESEARCH_ORDER:
		c.technologies[0][key] = true # Atelier uniquement.
	c.resources[0] = {"food": 60000.0, "wood": 60000.0, "ore": 60000.0}
	c.satellites[0] = 1
	c._sync_all()
	var w: SimWorld = c.current()
	w.teams[0].pop_cap = 250
	var port: SimWorld.Building = suite._find_port(w, 0, "spatioport")
	suite._find_port(w, 0, "chantier_orbital")
	if port != null:
		for kind in ["navette", "fregate", "ouvrier", "ouvrier", "fusilier", "char"]:
			w.spawn_unit(0, kind, port.center + Vector2(5.0 + float(w.units.size() % 3), 4.0))
	w.update_fog(true)
	GameConfig.mode = "skirmish"
	GameConfig.loaded_world = null
	GameConfig.loaded_campaign = c
	get_tree().change_scene_to_file("res://game/game.tscn")

func _play() -> void:
	GameConfig.mode = "skirmish"
	GameConfig.seed_value = 678
	GameConfig.loaded_campaign = null
	GameConfig.loaded_world = null
	GameConfig.player_ai = false
	get_tree().change_scene_to_file("res://game/game.tscn")
