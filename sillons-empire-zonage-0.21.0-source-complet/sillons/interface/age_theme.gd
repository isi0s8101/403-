class_name AgeTheme
extends RefCounted
## 0.17 — Directeur de thème : l'apparence de l'interface suit l'âge de la civilisation du joueur,
## de l'antique (âge I : pierre, bois, bronze) à l'application « next-gen » (âge X : verre, lumière irisée).
## La disposition, les tailles, l'ordre des boutons et les gestes sont IDENTIQUES à tous les âges : seuls les
## matières, couleurs, polices, sons et rythmes d'animation changent.
## Un seul objet Theme est partagé par toute l'interface (MobileUI.theme()) ; changer d'âge recopie dans cet
## objet le thème de l'âge, construit une seule fois puis mis en cache : aucun recalcul par image.

const SKIN_ROOT := "res://interface/ui_skins/age_%02d/"
const FONT_ROOT := "res://interface/fonts/"
## Couleurs de sens : identiques à tous les âges (on change le rendu, jamais la signification).
const SEMANTIC := {"success": Color("78dc92"), "warning": Color("f5b84f"), "danger": Color("ff8a80"), "info": Color("7cc9ff")}
const RES := {"food": Color(0.86, 0.36, 0.3), "wood": Color(0.55, 0.38, 0.2), "ore": Color(0.75, 0.7, 0.5)}
const ZONES := {"R": Color("63d3a2"), "C": Color("63baff"), "I": Color("efb666")}
const MAP := {"grass": Color(0.3, 0.42, 0.2), "water": Color(0.15, 0.3, 0.4), "rock": Color(0.3, 0.45, 0.5), "frame": Color(1, 1, 1)}
const STEP_COLORS := {"move": Color("7cc9ff"), "amove": Color("ff8a80"), "attack": Color("ff5e52"), "wait": Color("d8d8d8"),
	"defend": Color("f5b84f"), "patrol": Color("f5b84f"), "escort": Color("78dc92"), "follow": Color("78dc92"), "build": Color("e9c480"),
	"gather": Color("9be07a"), "return": Color("9be07a"), "repair": Color("e9c480"), "garrison": Color("c6aaff"), "release": Color("ffffff"), "explore": Color("7cf0e0")}
const NEUTRAL_INK := Color("eef2f4")
const NEUTRAL_MUTED := Color("a8bac4")
const NEUTRAL_ACCENT := Color("e9c480")

## Jetons de style. Âge 0 = thème neutre (menus hors partie, identique à la charte 0.16).
## Contrastes vérifiés par la recette lab/ui_theme_test.gd (WCAG : texte ≥ 4,5:1, éléments graphiques ≥ 3:1).
const TOKENS := [
	{"name": "Neutre", "bg": Color(0.032, 0.055, 0.073, 0.96), "surface": Color("132936"), "surface_hi": Color("234552"), "surface_press": Color("36515a"), "surface_off": Color("101b22"),
		"border": Color(0.33, 0.52, 0.58, 0.45), "text": Color("eef2f4"), "muted": Color("a8bac4"), "disabled": Color("8798a3"), "accent": Color("e9c480"), "accent_text": Color("101c25"),
		"fill": Color("68d3c5"), "track": Color("0a1820"), "scrim": Color(0.005, 0.012, 0.02, 0.55), "select": Color(0.27, 0.88, 0.94), "radius": 12, "button_radius": 9,
		# 0.18.1 : polices livrées aussi pour le thème neutre (menus) — la police par défaut du moteur n'a pas tous les
		# caractères (ex. « → ») et Android ne fournit pas toujours de police de secours.
		"skin": false, "title_font": "FiraSans-SemiBold", "button_font": "FiraSans-SemiBold", "body_font": "FiraSans-Regular", "motion": 1.0, "material": "charte sombre"},
	{"name": "Exploration", "bg": Color("1f1a15"), "surface": Color("3a2e22"), "surface_hi": Color("4a3b2b"), "surface_press": Color("5c4833"), "surface_off": Color("26201a"),
		"border": Color("8a6a3e"), "text": Color("f5ead6"), "muted": Color("cfba98"), "disabled": Color("9a8a72"), "accent": Color("e0a852"), "accent_text": Color("1c140b"),
		"fill": Color("d08e3e"), "track": Color("2c241b"), "scrim": Color(0.04, 0.03, 0.02, 0.6), "select": Color("e0a852"), "radius": 5, "button_radius": 4,
		"skin": true, "title_font": "Cardo-Bold", "button_font": "Cardo-Bold", "body_font": "FiraSans-Regular", "motion": 1.35, "material": "pierre taillée, bois brut, cuir"},
	{"name": "Commerce", "bg": Color("241a24"), "surface": Color("3b2a3a"), "surface_hi": Color("4b3749"), "surface_press": Color("5d4459"), "surface_off": Color("2a202a"),
		"border": Color("b8934a"), "text": Color("f8f0de"), "muted": Color("d9caad"), "disabled": Color("a09286"), "accent": Color("d9b566"), "accent_text": Color("20160a"),
		"fill": Color("c49c50"), "track": Color("2e222d"), "scrim": Color(0.05, 0.03, 0.05, 0.6), "select": Color("d9b566"), "radius": 7, "button_radius": 6,
		"skin": true, "title_font": "Cardo-Bold", "button_font": "Cardo-Bold", "body_font": "FiraSans-Regular", "motion": 1.25, "material": "parchemin, cire, bronze"},
	{"name": "Forteresses", "bg": Color("1c1d20"), "surface": Color("34363b"), "surface_hi": Color("44464c"), "surface_press": Color("505259"), "surface_off": Color("222326"),
		"border": Color("787a80"), "text": Color("eeedea"), "muted": Color("d2d1cb"), "disabled": Color("8e8e8a"), "accent": Color("e66a5e"), "accent_text": Color("160807"),
		"fill": Color("d85248"), "track": Color("2a2b2f"), "scrim": Color(0.02, 0.02, 0.025, 0.6), "select": Color("e66a5e"), "radius": 4, "button_radius": 3,
		"skin": true, "title_font": "Cardo-Bold", "button_font": "Cardo-Bold", "body_font": "FiraSans-Regular", "motion": 1.15, "material": "pierre de taille, fer forgé, rivets"},
	{"name": "Industrie", "bg": Color("1b1712"), "surface": Color("342c21"), "surface_hi": Color("43392b"), "surface_press": Color("544735"), "surface_off": Color("221d17"),
		"border": Color("b5763c"), "text": Color("f4e7cf"), "muted": Color("cfba96"), "disabled": Color("998970"), "accent": Color("dc9656"), "accent_text": Color("1b1006"),
		"fill": Color("5fa37a"), "track": Color("252a22"), "scrim": Color(0.03, 0.025, 0.02, 0.6), "select": Color("dc9656"), "radius": 6, "button_radius": 5,
		"skin": true, "title_font": "Cardo-Bold", "button_font": "FiraSans-SemiBold", "body_font": "FiraSans-Regular", "motion": 1.1, "material": "laiton, bois verni, plaques rivetées"},
	{"name": "Empire", "bg": Color("0f1a33"), "surface": Color("1c2c52"), "surface_hi": Color("263a68"), "surface_press": Color("31477c"), "surface_off": Color("14203c"),
		"border": Color("d4af37"), "text": Color("ffffff"), "muted": Color("ccd6ec"), "disabled": Color("8f9cba"), "accent": Color("eaca62"), "accent_text": Color("10172a"),
		"fill": Color("e6c55a"), "track": Color("14223f"), "scrim": Color(0.01, 0.02, 0.05, 0.6), "select": Color("eaca62"), "radius": 9, "button_radius": 8,
		"skin": true, "title_font": "Cardo-Bold", "button_font": "Cardo-Bold", "body_font": "FiraSans-Regular", "motion": 1.05, "material": "marbre, dorures, velours"},
	{"name": "Mécanisation", "bg": Color("15160f"), "surface": Color("2e321f"), "surface_hi": Color("3b4027"), "surface_press": Color("4a5031"), "surface_off": Color("1b1d14"),
		"border": Color("c8b27a"), "text": Color("f0ead6"), "muted": Color("c8bfa2"), "disabled": Color("948e76"), "accent": Color("dcc684"), "accent_text": Color("15160f"),
		"fill": Color("a6ae60"), "track": Color("22251a"), "scrim": Color(0.02, 0.02, 0.015, 0.6), "select": Color("dcc684"), "radius": 2, "button_radius": 2,
		"skin": true, "title_font": "AnonymousPro-Bold", "button_font": "FiraSans-SemiBold", "body_font": "FiraSans-Regular", "motion": 0.95, "material": "acier peint, pochoirs, tôle"},
	{"name": "Dissuasion", "bg": Color("0b100c"), "surface": Color("1a221c"), "surface_hi": Color("223026"), "surface_press": Color("2c3e31"), "surface_off": Color("101612"),
		"border": Color("3fcf6a"), "text": Color("c4ffd2"), "muted": Color("8fd4a3"), "disabled": Color("5e946f"), "accent": Color("ffb81c"), "accent_text": Color("120c00"),
		"fill": Color("3fcf6a"), "track": Color("132017"), "scrim": Color(0.0, 0.02, 0.0, 0.62), "select": Color("3fcf6a"), "radius": 3, "button_radius": 3,
		"skin": true, "title_font": "AnonymousPro-Bold", "button_font": "AnonymousPro-Bold", "body_font": "FiraSans-Regular", "motion": 0.9, "material": "consoles, écrans cathodiques, radar"},
	{"name": "Numérique", "bg": Color("0d1426"), "surface": Color("17223d"), "surface_hi": Color("20305a"), "surface_press": Color("2a3d70"), "surface_off": Color("11192e"),
		"border": Color("2fd0e6"), "text": Color("ffffff"), "muted": Color("bcc8e0"), "disabled": Color("7f8ca8"), "accent": Color("40dcf2"), "accent_text": Color("04121a"),
		"fill": Color("38d9f0"), "track": Color("121b33"), "scrim": Color(0.0, 0.01, 0.04, 0.6), "select": Color("40dcf2"), "radius": 6, "button_radius": 6,
		"skin": false, "title_font": "FiraSans-SemiBold", "button_font": "FiraSans-SemiBold", "body_font": "FiraSans-Regular", "motion": 0.8, "material": "interface plate, grilles, néon sobre"},
	{"name": "Ère orbitale", "bg": Color("0c121b"), "surface": Color("1c2938"), "surface_hi": Color("253649"), "surface_press": Color("2f455c"), "surface_off": Color("111924"),
		"border": Color("9fe8ff"), "text": Color("f4fbff"), "muted": Color("cfe0ea"), "disabled": Color("889caa"), "accent": Color("84e5ff"), "accent_text": Color("021018"),
		"fill": Color("8be9ff"), "track": Color("141e2a"), "scrim": Color(0.0, 0.01, 0.03, 0.58), "select": Color("84e5ff"), "radius": 14, "button_radius": 12,
		"skin": true, "title_font": "FiraSans-Light", "button_font": "FiraSans-Regular", "body_font": "FiraSans-Regular", "motion": 0.75, "material": "verre dépoli, filets lumineux"},
	{"name": "Ère interstellaire", "bg": Color("0a0916"), "surface": Color("1c1934"), "surface_hi": Color("282448"), "surface_press": Color("36305e"), "surface_off": Color("121022"),
		"border": Color("b49cff"), "text": Color("ffffff"), "muted": Color("d0cbea"), "disabled": Color("8d87ad"), "accent": Color("c6aaff"), "accent_text": Color("0b0820"),
		"fill": Color("a8e6f4"), "track": Color("16142c"), "scrim": Color(0.01, 0.0, 0.03, 0.58), "select": Color("c6aaff"), "radius": 20, "button_radius": 16,
		"skin": true, "title_font": "FiraSans-SemiBold", "button_font": "FiraSans-SemiBold", "body_font": "FiraSans-Regular", "motion": 0.7, "material": "verre, halo, liseré irisé"},
]

static var current_age: int = 0
static var builds: int = 0
static var _cache: Dictionary = {}
static var _shared: Theme = null
static var _fonts: Dictionary = {}
static var _sounds: Dictionary = {}
static var _listeners: Array = []

# ---------------------------------------------------------------- accès

static func tokens(age: int = -1) -> Dictionary:
	return TOKENS[clampi(current_age if age < 0 else age, 0, TOKENS.size() - 1)]

static func c(key: String, age: int = -1) -> Color:
	var k: Dictionary = tokens(age)
	if SEMANTIC.has(key):
		return SEMANTIC[key]
	return k.get(key, Color.MAGENTA) as Color

static func age_name(age: int = -1) -> String:
	return String(tokens(age)["name"])

static func shared() -> Theme:
	if _shared == null:
		_shared = Theme.new()
		_shared.merge_with(theme_for(current_age))
	return _shared

static func theme_for(age: int) -> Theme:
	age = clampi(age, 0, TOKENS.size() - 1)
	var key: String = "%d:%d" % [age, _economy()]
	if not _cache.has(key):
		_cache[key] = build(age)
	return _cache[key]

static func _economy() -> int:
	return 1 if GameConfig.visual_quality == 0 else 0

static func on_changed(callback: Callable) -> void:
	_listeners.append(callback)

static func apply(age: int) -> bool:
	## Applique l'habillage d'un âge à toute l'interface. Vrai si l'apparence a changé.
	age = clampi(age, 0, TOKENS.size() - 1)
	if age == current_age and _shared != null:
		return false
	current_age = age
	var source: Theme = theme_for(age)
	var target: Theme = shared()
	target.clear()
	target.merge_with(source)
	var alive: Array = []
	for callback in _listeners:
		if (callback as Callable).is_valid():
			(callback as Callable).call(age)
			alive.append(callback)
	_listeners = alive
	return true

static func game_age(game) -> int:
	## Âge de référence : âge le plus élevé de l'empire (campagne), sinon âge du camp sur la carte.
	if game == null:
		return 0
	if game.get("campaign") != null and game.campaign.ages.size() > game.player:
		return clampi(int(game.campaign.ages[game.player]), 1, 10)
	if game.get("world") != null and game.world.teams.size() > game.player:
		return clampi(int(game.world.teams[game.player].age), 1, 10)
	return 1

static func wanted_age(game) -> int:
	return GameConfig.theme_mode if GameConfig.theme_mode > 0 else game_age(game)

# ---------------------------------------------------------------- construction (une fois par âge)

static func font(name: String) -> Font:
	if name == "":
		return null
	if not _fonts.has(name):
		var loaded: FontFile = load(FONT_ROOT + name + ".ttf") as FontFile
		if loaded != null and name != "FiraSans-Regular" and name != "FiraSans-SemiBold":
			var fallback: Font = font("FiraSans-SemiBold")
			if fallback != null:
				loaded.fallbacks = [fallback]
		_fonts[name] = loaded
	return _fonts[name]

static func _flat(bg: Color, border: Color, radius: int, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	s.anti_aliasing = true
	return s

static func _skin(age: int, file: String, margin: int, content: Vector2) -> StyleBoxTexture:
	var tex: Texture2D = load((SKIN_ROOT % age) + file) as Texture2D
	if tex == null:
		return null
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.set_texture_margin_all(margin)
	s.content_margin_left = content.x
	s.content_margin_right = content.x
	s.content_margin_top = content.y
	s.content_margin_bottom = content.y
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s

static func panel_box(age: int = -1) -> StyleBox:
	age = current_age if age < 0 else age
	var k: Dictionary = tokens(age)
	if bool(k["skin"]) and _economy() == 0:
		var skinned: StyleBoxTexture = _skin(age, "panel.png", 24, Vector2(12, 12))
		if skinned != null:
			return skinned
	var flat: StyleBoxFlat = _flat(k["bg"], k["border"], int(k["radius"]))
	if age >= 9 and _economy() == 0:
		flat.shadow_color = Color(k["border"], 0.22)
		flat.shadow_size = 6
	return flat

static func build(age: int) -> Theme:
	builds += 1
	var k: Dictionary = tokens(age)
	var t := Theme.new()
	t.default_font_size = 16
	var body: Font = font(String(k["body_font"]))
	if body != null:
		t.default_font = body
	var radius: int = int(k["button_radius"])
	var panel_style: StyleBox = panel_box(age)
	var track: StyleBoxFlat = _flat(k["track"], Color(k["border"], 0.6), 3)
	var fill: StyleBoxFlat = _flat(k["fill"], k["fill"], 3, 0)
	t.set_stylebox("background", "ProgressBar", track)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_stylebox("panel", "PanelContainer", panel_style)
	t.set_stylebox("panel", "PopupPanel", panel_style)
	t.set_stylebox("panel", "AcceptDialog", panel_style)
	var normal: StyleBox = null
	if bool(k["skin"]) and _economy() == 0:
		normal = _skin(age, "button.png", 14, Vector2(10, 6))
	if normal == null:
		var flat_normal: StyleBoxFlat = _flat(k["surface"], k["border"], radius)
		flat_normal.content_margin_top = 6
		flat_normal.content_margin_bottom = 6
		normal = flat_normal
	var hover: StyleBoxFlat = _flat(k["surface_hi"], k["border"], radius)
	var pressed: StyleBoxFlat = _flat(k["surface_press"], k["accent"], radius, 2)
	var disabled: StyleBoxFlat = _flat(k["surface_off"], Color(k["border"], 0.35), radius)
	var focus: StyleBoxFlat = _flat(Color(0, 0, 0, 0), k["accent"], radius, 2)
	for box in [hover, pressed, disabled, focus]:
		box.content_margin_top = 6
		box.content_margin_bottom = 6
	for entry in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["focus", focus], ["hover_pressed", pressed]]:
		t.set_stylebox(String(entry[0]), "Button", entry[1] as StyleBox)
	var button_font: Font = font(String(k["button_font"]))
	if button_font != null:
		t.set_font("font", "Button", button_font)
	for kind in ["Button", "CheckButton", "OptionButton"]:
		t.set_color("font_color", kind, k["text"])
		t.set_color("font_hover_color", kind, k["text"])
		t.set_color("font_pressed_color", kind, k["text"])
		t.set_color("font_focus_color", kind, k["text"])
		t.set_color("font_hover_pressed_color", kind, k["text"])
		t.set_color("font_disabled_color", kind, k["disabled"])
	t.set_color("font_color", "Label", k["text"])
	t.set_color("font_color", "LineEdit", k["text"])
	t.set_color("font_color", "ItemList", k["text"])
	t.set_color("font_color", "RichTextLabel", k["text"])
	t.set_color("default_color", "RichTextLabel", k["text"])
	t.set_stylebox("normal", "LineEdit", hover)
	t.set_stylebox("focus", "LineEdit", hover)
	t.set_stylebox("panel", "ItemList", hover)
	t.set_stylebox("selected", "ItemList", pressed)
	var selected_tab: StyleBoxFlat = pressed.duplicate() as StyleBoxFlat
	var normal_tab: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	normal_tab.bg_color = k["surface"]
	for tab in [selected_tab, normal_tab]:
		tab.content_margin_top = 11
		tab.content_margin_bottom = 11
	t.set_stylebox("tab_selected", "TabBar", selected_tab)
	t.set_stylebox("tab_unselected", "TabBar", normal_tab)
	t.set_stylebox("tab_hovered", "TabBar", hover)
	t.set_color("font_selected_color", "TabBar", k["text"])
	t.set_color("font_unselected_color", "TabBar", k["muted"])
	t.set_color("font_hovered_color", "TabBar", k["text"])
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	# Variantes nommées : les éléments nouveaux naissent « thémables » (aucune couleur fixée dans le code).
	t.set_type_variation("HeaderLabel", "Label")
	t.set_color("font_color", "HeaderLabel", k["accent"])
	t.set_font_size("font_size", "HeaderLabel", 18)
	var title: Font = font(String(k["title_font"]))
	if title != null:
		t.set_font("font", "HeaderLabel", title)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", k["muted"])
	t.set_font_size("font_size", "MutedLabel", 13)
	t.set_type_variation("PrimaryButton", "Button")
	var primary: StyleBoxFlat = _flat(k["accent"], Color(k["accent"]).lightened(0.25), radius)
	var primary_hover: StyleBoxFlat = _flat(Color(k["accent"]).lightened(0.12), Color(k["accent"]).lightened(0.35), radius)
	for box in [primary, primary_hover]:
		box.content_margin_top = 6
		box.content_margin_bottom = 6
	t.set_stylebox("normal", "PrimaryButton", primary)
	t.set_stylebox("hover", "PrimaryButton", primary_hover)
	t.set_stylebox("pressed", "PrimaryButton", primary_hover)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(key, "PrimaryButton", k["accent_text"])
	t.set_type_variation("ToggleOnButton", "Button")
	var on: StyleBoxFlat = _flat(k["surface_press"], k["accent"], radius, 2)
	on.content_margin_top = 6
	on.content_margin_bottom = 6
	t.set_stylebox("normal", "ToggleOnButton", on)
	t.set_stylebox("hover", "ToggleOnButton", on)
	t.set_color("font_color", "ToggleOnButton", k["accent"])
	t.set_color("font_hover_color", "ToggleOnButton", k["accent"])
	return t

# ---------------------------------------------------------------- sons et retours haptiques

static func sound(kind: String, age: int = -1) -> AudioStream:
	var a: int = current_age if age < 0 else age
	a = 8 if a <= 0 else a
	var key: String = "%d:%s" % [a, kind]
	if not _sounds.has(key):
		_sounds[key] = load((SKIN_ROOT % a) + kind + ".wav")
	return _sounds[key]

static func haptic(ms: int) -> void:
	if GameConfig.ui_vibration and OS.has_feature("android"):
		Input.vibrate_handheld(ms)

# ---------------------------------------------------------------- mesures (recette)

static func luminance(color: Color) -> float:
	var channels: Array = []
	for v in [color.r, color.g, color.b]:
		var x: float = float(v)
		channels.append(x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4))
	return 0.2126 * float(channels[0]) + 0.7152 * float(channels[1]) + 0.0722 * float(channels[2])

static func contrast(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

static func over(fg: Color, backdrop: Color) -> Color:
	## Couleur visible d'un fond partiellement transparent posé sur la scène.
	return Color(fg.r * fg.a + backdrop.r * (1.0 - fg.a), fg.g * fg.a + backdrop.g * (1.0 - fg.a), fg.b * fg.a + backdrop.b * (1.0 - fg.a), 1.0)
