class_name CivRules
extends RefCounted
## 0.16 — Tables de l'évolution de la civilisation (valeurs PROVISOIRES, à équilibrer en partie réelle).
## Inspiration de genre (RTS à âges et à grandes armées) ; aucun nom, unité ou visuel repris d'un jeu existant.
## Les effets sont des pourcentages additionnés par clé de modificateur (voir CivEvolution.MOD_KEYS).

const EPOCHS := ["antique", "industrielle", "spatiale"]
const EPOCH_AGE := {"antique": 2, "industrielle": 5, "spatiale": 8}
const EPOCH_LABEL := {"antique": "Époque antique (âges II–IV)", "industrielle": "Époque industrielle (âges V–VII)", "spatiale": "Époque spatiale (âges VIII–X)"}
const VOIE_LABEL := {"marchande": "Voie marchande", "militaire": "Voie militaire", "savante": "Voie savante"}
const VOIE_SUMMARY := {"marchande": "Commerce, collecte et richesse", "militaire": "Armées plus rapides et plus fortes", "savante": "Recherche, construction et pouvoirs"}

## Voie choisie à chaque époque : un bonus permanent et une unité spéciale.
const VOIES := {
	"antique": {
		"marchande": {"bonus": {"trade": 25, "gather_food": 10}, "unit": "archer_monte", "text": "+25 % commerce, +10 % nourriture · Archer monté (marché)"},
		"militaire": {"bonus": {"train_speed": 15, "attack_melee": 10}, "unit": "chevalier", "text": "+15 % vitesse de formation, +10 % attaque au corps à corps · Chevalier (caserne)"},
		"savante": {"bonus": {"research_speed": 20, "build_speed": 10}, "unit": "arbaletrier", "text": "+20 % vitesse de recherche, +10 % construction · Arbalétrier (caserne)"},
	},
	"industrielle": {
		"marchande": {"bonus": {"trade": 25, "gather_wood": 10, "gather_ore": 10}, "unit": "mitrailleur", "text": "+25 % commerce, +10 % bois et minerai · Compagnie mitrailleuse (marché)"},
		"militaire": {"bonus": {"attack_all": 10, "train_speed": 10}, "unit": "garde_imperiale", "text": "+10 % attaque de toutes les troupes, +10 % formation · Garde impériale (caserne)"},
		"savante": {"bonus": {"research_speed": 20, "build_speed": 20}, "unit": "tireur_elite", "text": "+20 % recherche, +20 % construction · Tireur d'élite (caserne)"},
	},
	"spatiale": {
		"marchande": {"bonus": {"gather_all": 15, "trade": 15}, "unit": "robot_combat", "text": "+15 % collecte, +15 % commerce · Robot de combat (usine)"},
		"militaire": {"bonus": {"armor_military": 10, "attack_all": 5}, "unit": "exosquelette", "text": "−10 % dégâts subis par les troupes, +5 % attaque · Exosquelette d'assaut (caserne)"},
		"savante": {"bonus": {"power_gain": 50, "research_speed": 25}, "unit": "marine_spatial", "text": "+50 % points de commandement, +25 % recherche · Marine spatial (caserne)"},
	},
}

## Monuments : deux par âge ; on en bâtit UN pour passer à cet âge. Bonus actif tant qu'il est debout.
const MONUMENTS := {
	"monument_grand_comptoir": {"age": 2, "bonus": {"trade": 25, "gather_food": 5}, "text": "+25 % commerce, +5 % nourriture", "family": "market", "leaning": "marchande"},
	"monument_bibliotheque": {"age": 2, "bonus": {"research_speed": 15}, "text": "+15 % vitesse de recherche", "family": "university", "leaning": "savante"},
	"monument_citadelle": {"age": 3, "bonus": {"armor_building": 25}, "text": "−25 % dégâts subis par les bâtiments", "family": "tower", "leaning": "militaire"},
	"monument_temple_batisseurs": {"age": 3, "bonus": {"build_speed": 25}, "text": "+25 % vitesse de construction", "family": "temple", "leaning": "savante"},
	"monument_grande_forge": {"age": 4, "bonus": {"upgrade_discount": 25, "attack_melee": 5}, "text": "Améliorations d'armée −25 %, +5 % attaque au corps à corps", "family": "factory", "leaning": "militaire"},
	"monument_manufacture": {"age": 4, "bonus": {"gather_wood": 10, "gather_ore": 10}, "text": "+10 % bois et minerai", "family": "laboratory", "leaning": "marchande"},
	"monument_palais": {"age": 5, "bonus": {"train_speed": 15}, "text": "+15 % vitesse de formation des unités", "family": "command_center", "leaning": "militaire"},
	"monument_grande_universite": {"age": 5, "bonus": {"research_speed": 20}, "text": "+20 % vitesse de recherche", "family": "university", "leaning": "savante"},
	"monument_arsenal_national": {"age": 6, "bonus": {"attack_vehicle": 15, "armor_vehicle": 10}, "text": "Véhicules : +15 % attaque, −10 % dégâts subis", "family": "factory", "leaning": "militaire"},
	"monument_gare_centrale": {"age": 6, "bonus": {"trade": 20, "gather_all": 5}, "text": "+20 % commerce, +5 % collecte", "family": "logistics_depot", "leaning": "marchande"},
	"monument_bouclier_national": {"age": 7, "bonus": {"armor_building": 30}, "text": "−30 % dégâts subis par les bâtiments", "family": "planetary_defense", "leaning": "militaire"},
	"monument_etat_major": {"age": 7, "bonus": {"power_gain": 40, "attack_all": 5}, "text": "+40 % points de commandement, +5 % attaque", "family": "radar", "leaning": "savante"},
	"monument_centre_calcul": {"age": 8, "bonus": {"research_speed": 25}, "text": "+25 % vitesse de recherche", "family": "research_center", "leaning": "savante"},
	"monument_usine_robotisee": {"age": 8, "bonus": {"train_speed": 20}, "text": "+20 % vitesse de formation des unités", "family": "factory", "leaning": "militaire"},
	"monument_ascenseur_spatial": {"age": 9, "bonus": {"gather_all": 10, "trade": 10}, "text": "+10 % collecte, +10 % commerce", "family": "spaceport", "leaning": "marchande"},
	"monument_observatoire": {"age": 9, "bonus": {"power_gain": 50}, "text": "+50 % points de commandement", "family": "research_center", "leaning": "savante"},
	"monument_porte_stellaire": {"age": 10, "bonus": {"attack_all": 10, "armor_military": 10}, "text": "+10 % attaque, −10 % dégâts subis par les troupes", "family": "spaceport", "leaning": "militaire"},
	"monument_archive_galactique": {"age": 10, "bonus": {"research_speed": 30, "build_speed": 20}, "text": "+30 % recherche, +20 % construction", "family": "research_center", "leaning": "marchande"},
}

## Améliorations d'armée et d'économie : trois niveaux, chacun à un âge et un bâtiment.
const UPGRADES := {
	"armes_melee": {"label": "Armes de mêlée", "building": "forge", "ages": [2, 4, 6], "base": {"food": 120, "ore": 80}, "time": 30.0, "effect": {"attack_melee": 10}},
	"armes_tir": {"label": "Armes de tir", "building": "forge", "ages": [2, 4, 6], "base": {"wood": 100, "ore": 100}, "time": 30.0, "effect": {"attack_ranged": 10}},
	"armures_infanterie": {"label": "Armures d'infanterie", "building": "forge", "ages": [2, 4, 6], "base": {"food": 100, "ore": 100}, "time": 30.0, "effect": {"armor_infantry": 8}},
	"armures_cavalerie": {"label": "Protection des montures", "building": "forge", "ages": [3, 5, 7], "base": {"food": 150, "ore": 100}, "time": 35.0, "effect": {"armor_cavalry": 8}},
	"balistique": {"label": "Balistique", "building": "forge", "ages": [3, 5, 7], "base": {"wood": 150, "ore": 120}, "time": 35.0, "effect": {"attack_siege": 12}},
	"blindage_avance": {"label": "Blindage avancé", "building": "usine", "ages": [6, 8, 10], "base": {"ore": 300}, "time": 40.0, "effect": {"armor_vehicle": 8}},
	"aerodynamique": {"label": "Aérodynamique", "building": "aerodrome", "ages": [6, 8, 10], "base": {"wood": 150, "ore": 250}, "time": 40.0, "effect": {"attack_air": 10}},
	"outils_bucheron": {"label": "Outils de bûcheron", "building": "centre", "ages": [2, 4, 6], "base": {"food": 80, "wood": 60}, "time": 25.0, "effect": {"gather_wood": 10}},
	"pioches": {"label": "Pioches et forage", "building": "centre", "ages": [2, 4, 6], "base": {"food": 80, "wood": 80}, "time": 25.0, "effect": {"gather_ore": 10}},
	"charrues": {"label": "Charrues et irrigation", "building": "centre", "ages": [2, 4, 6], "base": {"wood": 120}, "time": 25.0, "effect": {"gather_food": 10}},
	"batisseurs": {"label": "Corporation des bâtisseurs", "building": "centre", "ages": [2, 5, 8], "base": {"food": 100, "wood": 100}, "time": 30.0, "effect": {"build_speed": 12}},
}

## Héros : un par époque, unique ; rappel possible après une attente.
const HEROES := {
	"heros_antique": {"epoch": "antique", "aura": 7.0, "recall": 60.0, "names": {"marchande": "Capitaine des comptoirs", "militaire": "Capitaine de la garde", "savante": "Capitaine ingénieur", "": "Capitaine"}},
	"heros_industriel": {"epoch": "industrielle", "aura": 8.0, "recall": 75.0, "names": {"marchande": "Général des compagnies", "militaire": "Général d'armée", "savante": "Général savant", "": "Général"}},
	"heros_spatial": {"epoch": "spatiale", "aura": 9.0, "recall": 90.0, "names": {"marchande": "Commandante de flotte marchande", "militaire": "Commandante d'assaut", "savante": "Commandante scientifique", "": "Commandante"}},
}
const HERO_AURA := {"attack": 15, "armor": 15}

## Pouvoirs de commandement : points gagnés au combat, déblocage permanent, usage avec recharge.
const POWERS := {
	"ravitaillement": {"label": "Ravitaillement", "tier": 1, "unlock": 3.0, "cooldown": 90.0, "radius": 8.0, "text": "Soigne 35 % des PV des unités alliées dans la zone"},
	"eclaireurs": {"label": "Éclaireurs", "tier": 1, "unlock": 3.0, "cooldown": 60.0, "radius": 15.0, "text": "Révèle une zone pendant 30 s"},
	"cri_ralliement": {"label": "Cri de ralliement", "tier": 2, "unlock": 8.0, "cooldown": 120.0, "radius": 9.0, "text": "+25 % attaque des alliés dans la zone pendant 20 s"},
	"renforts": {"label": "Renforts", "tier": 2, "unlock": 8.0, "cooldown": 180.0, "radius": 10.0, "text": "4 soldats de l'âge courant près d'un de vos bâtiments (population requise)"},
	"bombardement": {"label": "Bombardement", "tier": 3, "unlock": 15.0, "cooldown": 150.0, "radius": 4.0, "text": "Frappe une zone visible après 3 s (ennemis seulement)"},
	"bouclier": {"label": "Bouclier", "tier": 3, "unlock": 15.0, "cooldown": 180.0, "radius": 10.0, "text": "−50 % dégâts subis par vos bâtiments dans la zone pendant 30 s"},
}
const POWER_ORDER := ["ravitaillement", "eclaireurs", "cri_ralliement", "renforts", "bombardement", "bouclier"]
const POINTS_PER_POP: float = 0.5
const POINTS_PER_BUILDING: float = 1.5
const POINTS_MAX: float = 999.0

static func renfort_unit(age: int) -> String:
	if age <= 1:
		return "lancier"
	if age <= 3:
		return "tireur"
	if age == 4:
		return "fusilier"
	return "grenadier"

static func upgrade_cost(key: String, level: int, discount: float) -> Dictionary:
	var base: Dictionary = (UPGRADES[key] as Dictionary)["base"] as Dictionary
	var out: Dictionary = {}
	for resource in base.keys():
		out[resource] = ceili(float(base[resource]) * float(level) * maxf(0.25, 1.0 - discount / 100.0))
	return out

static func upgrade_time(key: String, level: int) -> float:
	return float((UPGRADES[key] as Dictionary)["time"]) + 15.0 * float(level - 1)

static func monuments_for(age: int) -> Array:
	var out: Array = []
	for key in MONUMENTS.keys():
		if int((MONUMENTS[key] as Dictionary)["age"]) == age:
			out.append(String(key))
	out.sort()
	return out
