class_name GameSetup
extends RefCounted
## 0.21 : réglages avancés de « Nouvelle partie ». Données pures (testables sans interface).
## Chaque réglage se traduit en règle du monde (SimWorld.rules) ou en paramètre de GameConfig :
##   durée -> cost_mult / research_mult · ressources -> start · IA -> ai_attack_mult, start_ai
##   événements -> events_scale · carte explorée -> reveal_map · taille -> GameConfig.map_dimension
const PATH := "user://newgame.cfg"

const MODES := [
	{"label": "Campagne · deux systèmes", "hint": "Cité, voies de civilisation, planètes et orbite. Carte tactique générée."},
	{"label": "Escarmouche · planète", "hint": "Vous choisissez le site de départ sur le globe, puis vous jouez la région."},
]
const WORLDS := [
	{"label": "Terre réelle", "hint": "Relief, océans et biomes réels (graine 1789). Surtout visible en escarmouche : on choisit sa région sur la vraie Terre."},
	{"label": "Planète aléatoire", "hint": "Une planète différente à chaque partie."},
	{"label": "Graine précise", "hint": "Même graine = même monde. Idéal pour rejouer ou comparer."},
]
const MAP_SIZES := [
	{"label": "Petite · 96", "value": 96, "hint": "Rapide, légère pour le téléphone."},
	{"label": "Grande · 256", "value": 256, "hint": "Format par défaut de la campagne."},
	{"label": "Immense · 512", "value": 512, "hint": "Très vaste : lourde sur mobile, prévoir une grosse batterie."},
]
const DURATIONS := [
	{"label": "Rapide", "cost": 0.7, "research": 0.6, "hint": "Coûts ×0,7 · recherches ×0,6"},
	{"label": "Standard", "cost": 1.0, "research": 1.0, "hint": "Coûts et recherches de base"},
	{"label": "Épique", "cost": 1.6, "research": 2.0, "hint": "Coûts ×1,6 · recherches ×2 (partie d'une heure et plus)"},
]
const RESOURCE_TIERS := [
	{"label": "Modestes", "mult": 0.5},
	{"label": "Standard", "mult": 1.0},
	{"label": "Confortables", "mult": 2.5},
	{"label": "Abondantes", "mult": 6.0},
]
const AI_BEHAVIOURS := [
	{"label": "Pacifique", "mult": 0.0, "hint": "L'IA développe sa cité, ne lance jamais d'assaut (elle défend sa base)."},
	{"label": "Défensive", "mult": 1.6, "hint": "L'IA attend une grosse armée avant d'attaquer."},
	{"label": "Normale", "mult": 1.0, "hint": "Comportement de référence."},
	{"label": "Agressive", "mult": 0.65, "hint": "L'IA attaque avec de petites armées, tôt et souvent."},
]
const AI_EDGES := [
	{"label": "Handicap −25 %", "mult": 0.75},
	{"label": "Égalité", "mult": 1.0},
	{"label": "Avantage +25 %", "mult": 1.25},
	{"label": "Avantage +50 %", "mult": 1.5},
]
const EVENT_LEVELS := [
	{"label": "Aucun", "scale": 0.0, "hint": "Pas de séisme, tempête, crise ni exode."},
	{"label": "Rares", "scale": 1.0, "hint": "Réglage de référence."},
	{"label": "Fréquents", "scale": 2.5, "hint": "Les événements tombent environ 2,5 fois plus souvent."},
]
const REVEALS := ["Brouillard complet", "Carte explorée"]

const PRESETS := {
	"Équilibré": {},
	"Bâtisseur paisible": {"ai": 0, "ai_edge": 1, "resources": 2, "duration": 1, "events": 1, "civ": true, "supply": true},
	"Guerre totale": {"ai": 3, "ai_edge": 2, "resources": 1, "duration": 0, "events": 2, "workers": 6},
	"Course rapide": {"duration": 0, "resources": 3, "speed": 2, "workers": 8, "map": 0, "reveal": true},
	"Survie": {"resources": 0, "ai": 3, "ai_edge": 3, "workers": 3, "scouts": 0, "events": 2, "duration": 2},
}
const PRESET_ORDER := ["Équilibré", "Bâtisseur paisible", "Guerre totale", "Course rapide", "Survie"]

static var v: Dictionary = defaults()
static var _loaded: bool = false

static func defaults() -> Dictionary:
	return {"mode": 0, "world": 1, "seed_text": "", "map": 1, "duration": 1, "speed": 1, "resources": 1,
		"workers": int(Rules.START["workers"]), "scouts": int(Rules.START["scouts"]), "reveal": false,
		"ai": 2, "ai_edge": 1, "civ": true, "supply": true, "events": 1, "demo": false}

static func apply_preset(preset_name: String) -> void:
	v = defaults()
	var p: Dictionary = PRESETS.get(preset_name, {}) as Dictionary
	for key in p.keys():
		v[key] = p[key]

static func is_planet_mode() -> bool:
	return int(v["mode"]) == 1

static func seed_value() -> int:
	match int(v["world"]):
		0:
			return PlanetGenerator.EARTH_SEED
		2:
			var text: String = String(v["seed_text"]).strip_edges()
			return maxi(0, int(text)) if text.is_valid_int() else 0
	return 0

static func start_resources(tier: int, edge: float = 1.0) -> Dictionary:
	var base: Dictionary = Rules.START["res"] as Dictionary
	var mult: float = float(RESOURCE_TIERS[clampi(tier, 0, RESOURCE_TIERS.size() - 1)]["mult"]) * edge
	var out: Dictionary = {}
	for r in Rules.RESOURCES:
		out[r] = int(round(float(base.get(r, 0)) * mult / 10.0)) * 10
	return out

static func build_rules() -> Dictionary:
	## Règles ajoutées aux mondes créés (GameConfig.merge_rules). Les bornes protègent les valeurs saisies à la main.
	var dur: Dictionary = DURATIONS[clampi(int(v["duration"]), 0, DURATIONS.size() - 1)] as Dictionary
	var edge: float = float((AI_EDGES[clampi(int(v["ai_edge"]), 0, AI_EDGES.size() - 1)] as Dictionary)["mult"])
	var workers: int = clampi(int(v["workers"]), 1, 12)
	var scouts: int = clampi(int(v["scouts"]), 0, 4)
	var tier: int = int(v["resources"])
	var rules: Dictionary = {
		"cost_mult": float(dur["cost"]), "research_mult": float(dur["research"]),
		"start": {"res": start_resources(tier), "workers": workers, "scouts": scouts},
		"start_ai": {"res": start_resources(tier, edge), "workers": workers, "scouts": scouts},
		"ai_attack_mult": float((AI_BEHAVIOURS[clampi(int(v["ai"]), 0, AI_BEHAVIOURS.size() - 1)] as Dictionary)["mult"]),
		"events_scale": float((EVENT_LEVELS[clampi(int(v["events"]), 0, EVENT_LEVELS.size() - 1)] as Dictionary)["scale"]),
	}
	if bool(v["reveal"]):
		rules["reveal_map"] = true
	return rules

static func apply() -> String:
	## Écrit les réglages dans GameConfig. Renvoie la scène à ouvrir.
	GameConfig.custom_rules = build_rules()
	GameConfig.map_dimension = int((MAP_SIZES[clampi(int(v["map"]), 0, MAP_SIZES.size() - 1)] as Dictionary)["value"])
	GameConfig.civ_evolution = bool(v["civ"])
	GameConfig.supply_chain = bool(v["supply"])
	GameConfig.sim_speed = float(GameConfig.SPEED_LEVELS[clampi(int(v["speed"]), 0, GameConfig.SPEED_LEVELS.size() - 1)])
	GameConfig.seed_value = seed_value()
	GameConfig.show_ai_debug = false
	GameConfig.loaded_world = null
	GameConfig.loaded_campaign = null
	if is_planet_mode():
		GameConfig.mode = "planet_j9"
		GameConfig.player_ai = false
		return "res://game/planet_start.tscn"
	GameConfig.mode = "empire"
	GameConfig.player_ai = bool(v["demo"])
	return "res://game/game.tscn"

static func summary() -> String:
	var lines: PackedStringArray = []
	lines.append("%s · %s" % [(MODES[int(v["mode"])] as Dictionary)["label"], (WORLDS[int(v["world"])] as Dictionary)["label"]])
	if int(v["world"]) == 2:
		lines[0] += " (%s)" % (String(v["seed_text"]) if String(v["seed_text"]).strip_edges() != "" else "aléatoire")
	if not is_planet_mode():
		lines.append("Carte %s" % String((MAP_SIZES[int(v["map"])] as Dictionary)["label"]).to_lower())
	lines.append("Durée %s · vitesse ×%s" % [String((DURATIONS[int(v["duration"])] as Dictionary)["label"]).to_lower(), str(GameConfig.SPEED_LEVELS[int(v["speed"])]).replace(".0", "")])
	lines.append("Départ : ressources %s, %d ouvriers, %d éclaireur(s), %s" % [String((RESOURCE_TIERS[int(v["resources"])] as Dictionary)["label"]).to_lower(), int(v["workers"]), int(v["scouts"]), String(REVEALS[1 if bool(v["reveal"]) else 0]).to_lower()])
	lines.append("IA %s · %s" % [String((AI_BEHAVIOURS[int(v["ai"])] as Dictionary)["label"]).to_lower(), String((AI_EDGES[int(v["ai_edge"])] as Dictionary)["label"]).to_lower()])
	lines.append("Événements : %s" % String((EVENT_LEVELS[int(v["events"])] as Dictionary)["label"]).to_lower())
	return "\n".join(lines)

static func save() -> void:
	var cfg := ConfigFile.new()
	for key in v.keys():
		cfg.set_value("setup", String(key), v[key])
	cfg.save(PATH)

static func load_saved() -> void:
	## Recharge le dernier réglage (une fois par session). Valeurs invalides ignorées.
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var base: Dictionary = defaults()
	for key in base.keys():
		var value: Variant = cfg.get_value("setup", String(key), base[key])
		if typeof(value) == typeof(base[key]):
			v[key] = value
	var limits: Dictionary = {"mode": MODES.size(), "world": WORLDS.size(), "map": MAP_SIZES.size(), "duration": DURATIONS.size(), "speed": GameConfig.SPEED_LEVELS.size(),
		"resources": RESOURCE_TIERS.size(), "ai": AI_BEHAVIOURS.size(), "ai_edge": AI_EDGES.size(), "events": EVENT_LEVELS.size()}
	for key in limits.keys():
		v[key] = clampi(int(v[key]), 0, int(limits[key]) - 1)
	v["workers"] = clampi(int(v["workers"]), 3, 10)
	v["scouts"] = clampi(int(v["scouts"]), 0, 3)
