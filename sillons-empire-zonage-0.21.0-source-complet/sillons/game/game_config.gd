class_name GameConfig
extends RefCounted
## Paramètres de lancement partagés entre le menu et la partie.

static var reduce_motion: bool = false
static var mode := "skirmish"        # skirmish | lab
static var seed_value := 0
static var planet_lon: float = 0.0
static var planet_lat: float = 0.0
static var lab_path := ""
static var civ_evolution := true       # 0.16 : voies, monuments, forge, héros et pouvoirs (campagne « deux systèmes »)
static var supply_chain := true        # J13.1 : troupes issues des habitants, industrie requise
static var show_ai_debug := false
static var show_perf := false
static var adaptive_visuals: bool = true
static var visual_quality: int = 1     # 0 économie | 1 équilibré | 2 détaillé
# 0.17 : interface — thème (0 = suit l'âge, 1..10 = âge fixe), sons, vibrations, main gauche, échelle.
static var theme_mode: int = 0
static var ui_sounds: bool = true
static var ui_vibration: bool = true
static var left_handed: bool = false
static var ui_scale: float = 1.0
const UI_SCALES := [0.85, 1.0, 1.15, 1.3]
# Accélération du TEMPS DE SIMULATION exclusivement ; pas le temps des gestes/UI.
const SPEED_LEVELS := [0.5, 1.0, 2.0, 4.0, 8.0]
static var sim_speed: float = 1.0
# Retenir la recette et ses validations entre les écrans d'une même session.
static var recette_suite: RefCounted = null
static var recette_manual: Dictionary = {}
static var recette_manual_run_id: String = ""
static var speed_benchmarks: Dictionary = {}
static var recovery_notice: String = ""

static func next_speed(value: float) -> float:
	var i: int = SPEED_LEVELS.find(value)
	return float(SPEED_LEVELS[(i + 1) % SPEED_LEVELS.size()]) if i >= 0 else 1.0

static var player_ai := false        # démonstration : le camp joueur est joué par l'IA

## 0.21 : réglages avancés de « Nouvelle partie » (voir game_setup.gd). Vide = parties historiques inchangées.
static var custom_rules: Dictionary = {}
static var map_dimension: int = 256     # carte tactique de la campagne : 96 | 256 | 512

static func merge_rules(overrides: Dictionary) -> Dictionary:
	## Ajoute les réglages choisis au menu ; les règles de campagne déjà posées gardent la priorité.
	for key in custom_rules.keys():
		if not overrides.has(key):
			var value: Variant = custom_rules[key]
			overrides[key] = (value as Dictionary).duplicate(true) if value is Dictionary else value
	return overrides

static var loaded_world: SimWorld = null
static var loaded_campaign: StarCampaign = null

static func load_preferences() -> void:
	var preferences := ConfigFile.new()
	if preferences.load("user://presentation.cfg") != OK:
		return
	reduce_motion = bool(preferences.get_value("visual","reduce_motion",false))
	var value: Variant = preferences.get_value("visual", "quality", 1)
	if value is int:
		visual_quality = clampi(int(value), 0, 2)
	var adaptive: Variant = preferences.get_value("visual", "adaptive", true)
	if adaptive is bool:
		adaptive_visuals = bool(adaptive)
	var mode_value: Variant = preferences.get_value("interface", "theme_mode", 0)
	if mode_value is int:
		theme_mode = clampi(int(mode_value), 0, 10)
	var sounds_value: Variant = preferences.get_value("interface", "sounds", true)
	if sounds_value is bool:
		ui_sounds = bool(sounds_value)
	var vibration_value: Variant = preferences.get_value("interface", "vibration", true)
	if vibration_value is bool:
		ui_vibration = bool(vibration_value)
	var left_value: Variant = preferences.get_value("interface", "left_handed", false)
	if left_value is bool:
		left_handed = bool(left_value)
	var scale_value: Variant = preferences.get_value("interface", "scale", 1.0)
	if scale_value is float or scale_value is int:
		ui_scale = clampf(float(scale_value), 0.85, 1.3)

static func save_preferences() -> void:
	var preferences := ConfigFile.new()
	preferences.set_value("visual","reduce_motion",reduce_motion)
	preferences.set_value("visual", "quality", clampi(visual_quality, 0, 2))
	preferences.set_value("visual", "adaptive", adaptive_visuals)
	preferences.set_value("interface", "theme_mode", clampi(theme_mode, 0, 10))
	preferences.set_value("interface", "sounds", ui_sounds)
	preferences.set_value("interface", "vibration", ui_vibration)
	preferences.set_value("interface", "left_handed", left_handed)
	preferences.set_value("interface", "scale", clampf(ui_scale, 0.85, 1.3))
	var error: Error = preferences.save("user://presentation.cfg")
	if error != OK:
		push_warning("Réglage graphique non enregistré : " + error_string(error))
