extends "res://lab/ui_test_base.gd"
## 0.17 — Lot UI-6 : thèmes par âge. Pour chacun des 10 âges : thème appliqué, contraste WCAG mesuré
## (jetons ET centre réel des textures), aucune couleur codée en dur dans les fichiers d'interface,
## passage d'âge sans effet sur la simulation ni fermeture des panneaux, thème fixe, réduction des animations,
## aucune construction de Theme pendant 600 images sans changement d'âge, repli « Économie ».

const UI_FILES := ["game/hud.gd", "game/mobile_ui.gd", "game/strategic_hud.gd", "interface/building_drawer.gd", "interface/data_card.gd",
	"interface/civ_panel.gd", "interface/observation_hud.gd", "interface/movement_feed.gd", "interface/ui_motion.gd", "interface/portraits.gd",
	"interface/touch_tile.gd", "interface/ui_feedback.gd", "interface/age_ceremony.gd", "interface/selection_bar.gd", "interface/control_groups.gd",
	"interface/command_card.gd", "interface/alert_feed.gd", "interface/command_bars.gd", "interface/order_path_view.gd", "interface/placement_tool.gd",
	"interface/production_panel.gd", "evolution/evolution_panel.gd", "orbit/orbital_battle_hud.gd", "views/planet_hud.gd"]
var table: Dictionary = {}

func result_key() -> String:
	return "UI_THEME_RESULT"

func _center_mean(path: String, margin: int) -> Color:
	var image: Image = (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var total: Vector3 = Vector3.ZERO
	var n: int = 0
	for y in range(margin, image.get_height() - margin):
		for x in range(margin, image.get_width() - margin):
			var c: Color = image.get_pixel(x, y)
			total += Vector3(c.r, c.g, c.b)
			n += 1
	total /= float(maxi(1, n))
	return Color(total.x, total.y, total.z)

func run() -> void:
	var w: SimWorld = game.world
	var signatures: Dictionary = {}
	var light: Color = Color(0.78, 0.78, 0.78)
	for age in range(1, 11):
		AgeTheme.apply(age)
		var k: Dictionary = AgeTheme.tokens(age)
		var t: Theme = MobileUI.theme()
		var panel: StyleBox = t.get_stylebox("panel", "PanelContainer")
		var font: Font = t.get_font("font", "Button")
		var signature: String = "%s|%s|%s" % [panel.get_class() + (String((panel as StyleBoxTexture).texture.resource_path) if panel is StyleBoxTexture else str((panel as StyleBoxFlat).bg_color)), font.resource_path if font != null else "défaut", str(k["accent"])]
		signatures[signature] = age
		check(AgeTheme.current_age == age and t == AgeTheme.shared(), "T%02d thème de l'âge %s appliqué au thème partagé (%s)" % [age, Hud.ROMAN[age], String(k["name"])])
		var bgs: Array = [AgeTheme.over(k["bg"], Color.BLACK), AgeTheme.over(k["bg"], light)]
		if bool(k["skin"]):
			bgs.append(_center_mean((AgeTheme.SKIN_ROOT % age) + "panel.png", 24))
		var surfaces: Array = [k["surface"], k["surface_hi"], k["surface_press"]]
		if bool(k["skin"]):
			surfaces.append(_center_mean((AgeTheme.SKIN_ROOT % age) + "button.png", 14))
		var worst_text: float = 99.0
		var worst_icon: float = 99.0
		for bg in bgs:
			for fg in [k["text"], k["muted"], k["accent"], AgeTheme.SEMANTIC["success"], AgeTheme.SEMANTIC["warning"], AgeTheme.SEMANTIC["danger"], AgeTheme.SEMANTIC["info"]]:
				worst_text = minf(worst_text, AgeTheme.contrast(fg, bg))
		for surface in surfaces:
			worst_text = minf(worst_text, AgeTheme.contrast(k["text"], surface))
			worst_text = minf(worst_text, AgeTheme.contrast(k["muted"], surface))
		worst_text = minf(worst_text, AgeTheme.contrast(k["accent_text"], k["accent"]))
		worst_icon = minf(AgeTheme.contrast(k["fill"], k["track"]), AgeTheme.contrast(k["border"], AgeTheme.over(k["bg"], Color.BLACK)))
		worst_icon = minf(worst_icon, AgeTheme.contrast(k["disabled"], k["surface_off"]))
		table[str(age)] = {"nom": String(k["name"]), "texte_min": snappedf(worst_text, 0.01), "icones_min": snappedf(worst_icon, 0.01)}
		check(worst_text >= 4.5, "T%02d contraste du texte ≥ 4,5:1 (min %.2f, fonds jetons et textures réelles)" % [age, worst_text])
		check(worst_icon >= 3.0, "T%02d contraste des barres, bordures et icônes ≥ 3:1 (min %.2f)" % [age, worst_icon])
	check(signatures.size() == 10, "T11 dix thèmes distincts et reconnaissables (%d)" % signatures.size())
	print("CONTRAST_TABLE " + JSON.stringify(table))
	# --- contrôle statique : aucune couleur codée en dur dans les fichiers d'interface
	var violations: Array = []
	var literal := RegEx.new()
	literal.compile("Color\\(\\s*\"|Color\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)")
	for path in UI_FILES:
		var text: String = FileAccess.get_file_as_string("res://" + path)
		var line_no: int = 0
		for line in text.split("\n"):
			line_no += 1
			for m in literal.search_all(line):
				if m.get_string().ends_with("\""):
					violations.append("%s:%d" % [path, line_no])
				elif m.get_string(1) != m.get_string(2) or m.get_string(2) != m.get_string(3):
					violations.append("%s:%d" % [path, line_no])
	check(violations.is_empty(), "T12 aucune couleur codée en dur dans %d fichiers d'interface (%s)" % [UI_FILES.size(), ", ".join(violations)])
	# --- passage d'âge dans la vraie scène : aucun effet sur la simulation, panneaux conservés
	GameConfig.theme_mode = 0
	AgeTheme.apply(AgeTheme.wanted_age(game))
	await frames(3)
	var start_age: int = AgeTheme.current_age
	game.civ_panel.open()
	await frames(3)
	game.campaign.ages[0] = start_age + 1
	w.teams[0].age = start_age + 1
	var fingerprint: String = UnitCommands.state_text(w) + CivEvolution.hash_text(w)
	game.hud.check_theme_age()
	await frames(4)
	check(AgeTheme.current_age == start_age + 1, "T13 passage d'âge : le thème suit aussitôt l'âge de la civilisation")
	check(UnitCommands.state_text(w) + CivEvolution.hash_text(w) == fingerprint, "T14 le changement de thème ne modifie pas la simulation (empreinte identique)")
	check(game.civ_panel.visible, "T15 le panneau ouvert reste ouvert pendant le changement de thème")
	game.civ_panel.hide()
	# --- thème fixe
	GameConfig.theme_mode = 4
	AgeTheme.apply(AgeTheme.wanted_age(game))
	game.campaign.ages[0] = start_age + 2
	w.teams[0].age = start_age + 2
	game.hud.check_theme_age()
	await frames(4)
	check(AgeTheme.current_age == 4, "T16 thème fixe (âge IV) : inchangé par un passage d'âge")
	GameConfig.theme_mode = 0
	# --- cérémonie : réduite à un fondu avec « Réduire les animations », non bloquante et passable
	GameConfig.reduce_motion = true
	# 0.18 : le contrôle périodique du HUD (toutes les 0,2 s) ramène le thème à l'âge réel de la partie. Pour que la
	# recette ne dépende plus de l'instant où tombe ce contrôle, la partie est mise à l'âge joué par la cérémonie.
	game.campaign.ages[0] = 7
	w.teams[0].age = 7
	game.hud.ceremony.play(7, "Monument : essai")
	check(AgeTheme.current_age == 7, "T17 « Réduire les animations » : thème appliqué immédiatement (simple fondu)")
	game.hud.ceremony.skip()
	GameConfig.reduce_motion = false
	game.paused = false
	var tick_before: int = w.tick
	game.campaign.ages[0] = 8
	w.teams[0].age = 8
	game.hud.ceremony.play(8, "Monument : essai")
	check(game.hud.ceremony.active and AgeTheme.current_age == 7, "T18 cérémonie complète : 1 à 2 s, l'ancien style d'abord")
	await wait(0.4)
	check(w.tick > tick_before, "T19 cérémonie jamais bloquante : la partie continue dessous")
	await tap(center_of(game.hud.ceremony))
	check(not game.hud.ceremony.active and AgeTheme.current_age == 8, "T20 un toucher sur le bandeau termine la cérémonie (nouvel âge appliqué)")
	game.paused = true
	GameConfig.reduce_motion = true
	# --- aucun recalcul par image
	AgeTheme.apply(AgeTheme.wanted_age(game))
	var builds: int = AgeTheme.builds
	await frames(600)
	check(AgeTheme.builds == builds, "T21 600 images sans changement d'âge : aucune construction de Theme")
	var before_cached: int = AgeTheme.builds
	AgeTheme.apply(2)
	AgeTheme.apply(3)
	AgeTheme.apply(2)
	check(AgeTheme.builds - before_cached <= 2, "T22 chaque thème est construit une seule fois puis mis en cache")
	# --- repli « Économie »
	GameConfig.visual_quality = 0
	check(AgeTheme.theme_for(5).get_stylebox("panel", "PanelContainer") is StyleBoxFlat, "T23 profil Économie : habillage simple sans texture (repli)")
	GameConfig.visual_quality = 1
	# --- réglages sauvegardés
	GameConfig.theme_mode = 6
	GameConfig.ui_sounds = false
	GameConfig.left_handed = true
	GameConfig.ui_scale = 1.15
	GameConfig.save_preferences()
	GameConfig.theme_mode = 0
	GameConfig.ui_sounds = true
	GameConfig.left_handed = false
	GameConfig.ui_scale = 1.0
	GameConfig.load_preferences()
	check(GameConfig.theme_mode == 6 and not GameConfig.ui_sounds and GameConfig.left_handed and is_equal_approx(GameConfig.ui_scale, 1.15), "T24 réglages d'interface sauvegardés et relus (thème, sons, main gauche, échelle)")
	# --- mode gaucher : miroir des barres, ordre des boutons inchangé
	var card_x: float = game.hud.command_card.get_global_rect().position.x
	game.hud._apply_mirror()
	await frames(3)
	var mirrored_x: float = game.hud.command_card.get_global_rect().position.x
	check(card_x > game.hud.root.size.x * 0.5 and mirrored_x < game.hud.root.size.x * 0.5, "T25 mode gaucher : la carte de commandes passe à gauche")
	GameConfig.left_handed = false
	game.hud._apply_mirror()
	GameConfig.theme_mode = 0
	GameConfig.ui_scale = 1.0
	GameConfig.save_preferences()
