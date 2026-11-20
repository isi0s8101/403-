class_name UrbanRules
extends RefCounted
## 0.18 — Tables de la ville de l'âge de l'électricité (carte de bataille). Valeurs PROVISOIRES, à équilibrer en partie réelle.
## Repères de genre seulement (zones habitation / commerce / industrie, services à rayon d'action, réseaux, bien-être) :
## aucun nom, chiffre, visuel ou texte repris d'un jeu existant.

const TECH := "electricite"
const PERIOD: int = 20                 # ticks entre deux calculs de la ville (2 s)
const PERIOD_S: float = 2.0
const ZONES := ["zone_r", "zone_c", "zone_i", "zone_a"]
const ZONE_LABEL := {"zone_r": "Habitation", "zone_c": "Commerce", "zone_i": "Industrie", "zone_a": "Agriculture"}
## Remplacement net : ces bâtiments ne se construisent plus après la recherche.
const REPLACED := ["maison", "ferme", "entrepot"]
const LEVEL_MAX: int = 6               # 0.19 : plafond absolu (habitation) ; voir KIND_LEVELS et AGE_LEVEL_CAP
const LEVEL_NAMES := {
	"zone_r": ["Habitation rudimentaire", "Habitation améliorée", "Quartier structuré", "Habitat dense", "Architecture avancée", "Habitat futuriste"],
	"zone_c": ["Étals et marché", "Petits commerces", "Galerie marchande", "Quartier commercial", "Centre économique"],
	"zone_i": ["Artisanat", "Ateliers", "Manufactures", "Industrie lourde", "Industrie automatisée"],
	"zone_a": ["Cultures", "Ferme", "Domaine agricole"]}
## Amélioration d'une zone (niveau suivant) : coût par niveau visé, payé en ressources réelles.
const UPGRADE_COST := {2: {"wood": 80, "ore": 60}, 3: {"wood": 160, "ore": 150}, 4: {"wood": 260, "ore": 260},
	5: {"wood": 380, "ore": 420}, 6: {"wood": 520, "ore": 640}}
const START_DENSITY: float = 0.5      # densité d'une zone neuve à son achèvement
const MIN_DENSITY: float = 0.25

## Habitants et emplois par niveau de densité.
const HABITANTS_PER_LEVEL: int = 24
const JOBS_PER_LEVEL := {"zone_c": 12, "zone_i": 16, "zone_a": 8}
const ACTIVE_SHARE: float = 0.6        # part des habitants en âge de travailler
const POP_PER_UNIT: int = 4            # habitants logés par place d'unité (armée, ouvriers)
## Production par emploi occupé et par seconde, avant bien-être, électricité et bonus.
const OUTPUT := {"zone_c": {"food": 0.06, "wood": 0.04}, "zone_i": {"ore": 0.07}, "zone_a": {"food": 0.09}}
const CUSTOMERS_PER_SHOP_JOB: float = 1.5   # habitants nécessaires par emploi commercial pour vendre à plein
## Garde-fou : le centre de commandement assure un approvisionnement minimal (par seconde) une fois la ville ouverte.
const CENTRE_TRICKLE := {"food": 0.15, "wood": 0.15, "ore": 0.15}

## Consommation par bâtiment (par niveau de densité pour les zones).
const POWER_USE := {"zone_r": 1, "zone_c": 1, "zone_i": 2, "commissariat": 1, "caserne_pompiers": 1, "hopital": 2,
	"decharge": 1, "recyclage": 2, "chateau_eau": 1, "station_pompage": 2}
const WATER_USE := {"zone_r": 1, "zone_c": 1, "zone_i": 1, "hopital": 2, "caserne_pompiers": 1}
## Ordre de délestage : les premiers servis en cas de pénurie.
const PRIORITY := ["hopital", "caserne_pompiers", "commissariat", "chateau_eau", "station_pompage", "decharge", "recyclage", "zone_r", "zone_i", "zone_c"]

## Sources des réseaux. "reach" : rayon desservi (cases, depuis le centre du bâtiment).
const POWER_SOURCES := {
	"centrale": {"power": 60, "reach": 8.0},
	"centrale_solaire": {"power": 45, "reach": 7.0},
	"centre": {"power": 8, "reach": 6.0},
}
const RELAY := {"poste_electrique": 6.0}   # un poste relié au réseau prolonge la desserte
const WATER_SOURCES := {
	"chateau_eau": {"water": 40, "reach": 8.0},
	"station_pompage": {"water": 90, "reach": 7.0, "near_water": 3},
	"centre": {"water": 8, "reach": 6.0},
}
## Services : rayon et nombre de bâtiments servis (les plus proches d'abord).
const SERVICES := {
	"commissariat": {"key": "police", "reach": 9.0, "capacity": 18},
	"caserne_pompiers": {"key": "fire", "reach": 9.0, "capacity": 18},
	"hopital": {"key": "health", "reach": 10.0, "capacity": 24},
	"decharge": {"key": "waste", "reach": 8.0, "capacity": 16, "pollution_mult": 0.45},
	"recyclage": {"key": "waste", "reach": 10.0, "capacity": 30, "pollution_mult": 0.25},
}
const SERVICE_LABEL := {"police": "Sécurité", "fire": "Pompiers", "health": "Santé", "waste": "Déchets"}

## Pollution émise (par niveau de densité pour l'industrie), décroissance linéaire jusqu'au rayon.
const POLLUTION := {"zone_i": 14.0, "centrale": 30.0, "decharge": 4.0}
const POLLUTION_REACH: float = 7.0

## Criminalité (0–100) : cible vers laquelle chaque zone tend de 20 % par calcul.
const CRIME_BASE: float = 8.0
const CRIME_PER_LEVEL: float = 9.0
const CRIME_UNEMPLOYMENT: float = 35.0
const CRIME_POLICE_MULT: float = 0.3
const CRIME_THEFT: float = 0.005       # part de production commerciale perdue par point de criminalité au-delà de 40
const CRIME_EASE: float = 0.2

## Incendies : probabilité par calcul et par bâtiment urbain, durée, dégâts, propagation.
const FIRE_CHANCE: float = 0.0002            # 0.19 : multipliée ensuite par matériaux, temps qu'il fait, densité
const FIRE_COVERED_MULT: float = 0.2
const FIRE_INDUSTRY_MULT: float = 2.0
const FIRE_DAMAGED_MULT: float = 3.0   # bâtiment à moins de la moitié de sa vie
const FIRE_DURATION: float = 40.0
const FIRE_COVERED_DURATION: float = 4.0
const FIRE_DAMAGE: float = 0.02        # part de la vie maximale perdue par seconde de feu
const FIRE_SPREAD_CHANCE: float = 0.02
const FIRE_SPREAD_REACH: float = 2.0

## Santé et maladies.
const HEALTH_POLLUTION: float = 0.6
const HEALTH_NO_WATER: float = 35.0
const HEALTH_HOSPITAL_BONUS: float = 25.0
const EPIDEMIC_HEALTH: float = 45.0
const EPIDEMIC_CHANCE: float = 0.02
const EPIDEMIC_HOSPITAL_MULT: float = 0.2
const EPIDEMIC_LOSS: float = 0.25      # part de la densité perdue

## Croissance des zones (densité par calcul).
const GROW_STEP: float = 0.08
const DECLINE_STEP: float = 0.05
const GROW_HAPPINESS: float = 55.0
const DECLINE_HAPPINESS: float = 30.0

## Bien-être : productivité de 0,5 à 1,2 selon le bien-être général.
const PRODUCTIVITY_MIN: float = 0.5
const PRODUCTIVITY_SPAN: float = 0.7

## Alertes (pas minimal entre deux alertes du même genre, en ticks).
const ALERT_GAP: int = 300

static func is_zone(kind: String) -> bool:
	return ZONES.has(kind)

static func is_urban(kind: String) -> bool:
	return Rules.BUILDINGS.has(kind) and bool((Rules.BUILDINGS[kind] as Dictionary).get("urban", false))

static func level_name(kind: String, level: int) -> String:
	if not LEVEL_NAMES.has(kind):
		return ""
	var names: Array = LEVEL_NAMES[kind] as Array
	return String(names[clampi(level, 1, names.size()) - 1])

static func roman(level: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(level, 0, 10)]

static func kind_max(kind: String) -> int:
	return int(KIND_LEVELS.get(kind, 3))

static func age_cap(age: int) -> int:
	return int(AGE_LEVEL_CAP[clampi(age, 1, 10)])

static func material(style_age: int) -> float:
	## Inflammabilité des matériaux selon l'âge de construction (bois, pierre et brique, béton et acier).
	if style_age <= 3:
		return FIRE_MATERIAL_OLD
	if style_age <= 6:
		return FIRE_MATERIAL_MID
	return FIRE_MATERIAL_MODERN


# ================================================================ 0.19 — zonage, croissance organique, états

## Niveaux maximaux par catégorie, et plafond de niveau selon l'âge du camp (la ville ne se densifie pas sans l'âge).
const KIND_LEVELS := {"zone_r": 6, "zone_c": 5, "zone_i": 5, "zone_a": 3}
const AGE_LEVEL_CAP := [0, 2, 2, 3, 4, 4, 5, 5, 6, 6, 6]
## Avant la recherche Électricité : pas de réseau électrique, l'eau ne fait qu'améliorer la santé, production réduite.
const ERA_OUTPUT_MULT: float = 0.6
const ERA_NO_WATER_HEALTH: float = 10.0
## Puits (eau d'époque) et garde (casernes et forts) : desserte avant les réseaux modernes.
const WELL := {"puits": {"water": 12, "reach": 6.0, "fire_reach": 6.0, "fire_capacity": 8}}
const GUARD := {"caserne": {"reach": 7.0, "capacity": 10}, "fort": {"reach": 6.0, "capacity": 8}}

## Croissance : parcelles de 2×2 cases, accès par une route à moins de ROAD_REACH cases, reliée au centre.
const PARCEL: int = 2
const ROAD_REACH: int = 2
const TERRITORY: float = 22.0           # cases autour d'un bâtiment allié achevé où l'on peut zoner et tracer
const GROW_EVERY: int = 1               # croissance à chaque calcul de la ville (2 s)
const BUILD_TIME: float = 12.0          # secondes de chantier d'un bâtiment de niveau I (sans ouvrier)
const BUILD_TIME_PER_LEVEL: float = 6.0
const MAX_SITES_BASE: int = 2           # chantiers simultanés : 2 + habitants / HABITANTS_PER_SITE (main-d'œuvre)
const HABITANTS_PER_SITE: int = 40
const MAX_SITES: int = 5
const GROW_COST := {"zone_r": {"wood": 30}, "zone_c": {"wood": 30, "food": 10}, "zone_i": {"wood": 25, "ore": 15}, "zone_a": {"wood": 20}}
const REBUILD_COST_MULT: float = 1.2
const DEMAND_MIN: float = 0.05          # demande minimale pour lancer un chantier
const ENEMY_REACH: float = 9.0          # pas de chantier avec un ennemi armé à cette distance
const UNSAFE_CRIME: float = 70.0        # pas de chantier dans un voisinage plus criminel
const LEVEL_CHECK_EVERY: int = 3        # un bâtiment tente de monter de niveau au plus tous les 3 calculs
const LEVEL_WORKS: float = 12.0         # secondes de travaux pour passer un niveau (production réduite)
## Services exigés pour atteindre un niveau.
const LEVEL_NEEDS := {3: ["police"], 4: ["police", "water"], 5: ["police", "water", "fire", "power"], 6: ["police", "water", "fire", "health", "power"]}
## Nourriture consommée par habitant et par seconde (ressource réelle) ; à zéro : famine.
const FOOD_PER_HABITANT: float = 0.003
## États : effet sur la production et les habitants.
const STATE_OUTPUT := {"operational": 1.0, "prosperous": 1.15, "degraded": 0.7, "damaged": 0.5, "reconstruction": 0.5,
	"burning": 0.0, "burnt": 0.0, "abandoned": 0.0, "construction": 0.0}
const DEZONE_DELAY: float = 30.0        # secondes avant la démolition d'un bâtiment dont la zone a changé
const ABANDON_DELAY: float = 60.0       # secondes d'abandon avant la ruine
const BURNT_REPAIR_DELAY: float = 60.0  # un bâtiment brûlé non réparé tombe en ruine après ce délai
const REPAIR_COST := {"wood": 30}
## Criminalité 0.19 : causes et conséquences.
const CRIME_POVERTY: float = 0.25       # par point de richesse sous 40
const CRIME_CONFLICT: float = 15.0      # ennemi armé à proximité
const CRIME_NO_SERVICE: float = 5.0
const CRIME_DEGRADE: float = 60.0
const CRIME_DEGRADE_TIME: float = 20.0
const CRIME_MIGRATION: float = 65.0
const CRIME_PRODUCTION: float = 0.006   # part de production perdue par point au-delà de 50 (industrie, agriculture)
const PILLAGE_CRIME: float = 70.0       # criminalité moyenne de la ville au-delà de laquelle des pillages ont lieu
const PILLAGE_CHANCE: float = 0.05
const PILLAGE_SHARE: float = 0.03
const RIOT_CRIME: float = 80.0
const RIOT_HAPPINESS: float = 25.0
const RIOT_TIME: float = 30.0
const RIOT_DAMAGE: float = 0.03         # part de la vie perdue par calcul pendant une émeute (jusqu'à 40 %)
const RIOT_ARMY_REACH: float = 6.0
## Incendies 0.19 : intensité, matériaux, temps qu'il fait, lutte.
const FIRE_MATERIAL_OLD: float = 1.6
const FIRE_MATERIAL_MID: float = 1.0
const FIRE_MATERIAL_MODERN: float = 0.6
const FIRE_START_INTENSITY: float = 0.25
const FIRE_GROWTH: float = 0.15
const FIRE_STATION_FIGHT: float = 0.4   # intensité retirée par calcul par une caserne reliée par la route
const FIRE_WELL_FIGHT: float = 0.18
const FIRE_WATER_FIGHT: float = 0.1
const FIRE_TECH_FIGHT: float = 0.1      # âge VII et plus
const FIRE_WAR_CHANCE: float = 0.12     # bâtiment touché par les combats
const FIRE_DEFECT_MULT: float = 1.5     # électricité coupée sur un réseau (installation défectueuse)
const FIRE_CASUALTY: float = 0.05       # densité perdue par calcul, à pleine intensité
const WEATHER_CYCLE: int = 6000         # ticks d'un cycle sec / humide (10 min)
## Agglomération selon les habitants (classement du camp).
const SETTLEMENTS := [[0, "Campement"], [40, "Village"], [200, "Bourg"], [600, "Ville"], [1600, "Métropole"], [4000, "Mégalopole"]]

# 0.20 — Calcul réparti et villes lointaines (PROVISOIRE).
const TEAM_OFFSET: int = 10          # les camps impairs sont calculés 10 ticks après les camps pairs
const FAR_EVERY: int = 3             # ville d'un monde hors écran : calculée une période sur 3 (durées × 3)
