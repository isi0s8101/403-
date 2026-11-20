class_name Rules
extends RefCounted
## Données de jeu du jalon J1.
## Toutes les valeurs marquées PROVISOIRE sont des valeurs de test (cf. game-studio/decisions.md).
## Elles se surchargent par scénario de laboratoire via SimWorld.rules_override.

const TICK_RATE := 10           # ticks de simulation par seconde (PROVISOIRE, budget à mesurer)
const DT := 1.0 / TICK_RATE
const MAP_SIZE := 96            # cases ; 1 case = 1 unité monde (≈ 2 m visuels)
const SQUAD_SIZE := 6
const RESOURCES := ["food", "wood", "ore"]
const RES_LABEL := {"food": "Nourriture", "wood": "Bois", "ore": "Minerai"}

## Profils de durée : le prototype J1 est séparé de la cible du jeu complet.
const DURATION_PROFILES := {
	"prototype_j1": {"label": "Prototype J1 (âges I-II, ≈ 15-25 min)", "cost_mult": 1.0, "research_mult": 1.0},
	"cible_60min": {"label": "Cible jeu complet (≥ 60 min, dix âges) — non calibrée au J1", "cost_mult": 1.6, "research_mult": 2.0},
}

const AGES := [
	{"id": 1, "name": "I — Exploration"},
	{"id": 2, "name": "II — Commerce"},
	{"id": 3, "name": "III — Forteresses"},
	{"id": 4, "name": "IV — Industrie"},
	{"id": 5, "name": "V — Empire"},
	{"id": 6, "name": "VI — Mécanisation"},
	{"id": 7, "name": "VII — Dissuasion"},
	{"id": 8, "name": "VIII — Numérique"},
	{"id": 9, "name": "IX — Ère orbitale"},
	{"id": 10, "name": "X — Ère interstellaire"},
]

## Passage d'âge : coût + objectif vérifiable. PROVISOIRE et configurable.
## Objectifs disponibles : "comptoir_decouvert" (règle de recette provisoire, non approuvée),
## "batiments_2" (deux bâtiments hors centre achevés), "aucun".
const AGE_UP := {
	4: {"cost": {"food": 950, "wood": 500, "ore": 600}, "time": 60.0, "objective": "batiments_2"},
	5: {"cost": {"food": 1200, "wood": 600, "ore": 800}, "time": 65.0, "objective": "built_usine"},
	6: {"cost": {"food": 1450, "wood": 700, "ore": 1000}, "time": 70.0, "objective": "built_academie"},
	7: {"cost": {"food": 1700, "wood": 800, "ore": 1200}, "time": 75.0, "objective": "built_aerodrome"},
	8: {"cost": {"food": 1950, "wood": 900, "ore": 1400}, "time": 80.0, "objective": "built_radar"},
	9: {"cost": {"food": 2400, "wood": 1050, "ore": 1600}, "time": 90.0, "objective": "built_silo"},
	10: {"cost": {"food": 3100, "wood": 1300, "ore": 2200}, "time": 110.0, "objective": "built_spatioport"},

	2: {"cost": {"food": 400, "wood": 200, "ore": 0}, "time": 35.0, "objective": "comptoir_decouvert"},
	3: {"cost": {"food": 700, "wood": 450, "ore": 300}, "time": 45.0, "objective": "tenir_gue"},
}
const FORD_RADIUS_OBJECTIVE := 9.0

const OBJECTIVE_LABEL := {
	"comptoir_decouvert": "Découvrir un comptoir neutre",
	"batiments_2": "Achever 2 bâtiments (hors centre)",
	"tenir_gue": "Achever un bâtiment à moins de 9 cases d'un gué",
	"tenir_frontiere": "Achever une palissade, un relais ou un fort près d'une frontière régionale",
	"aucun": "Aucun objectif",
	"built_usine": "Achever une usine",
	"built_academie": "Achever une académie",
	"built_aerodrome": "Achever un aérodrome",
	"built_radar": "Achever une station radar",
	"built_silo": "Achever un silo de missiles",
	"built_spatioport": "Achever un spatioport orbital",
}

## Unités. tags : worker, builder, military, ranged, cavalry, infantry, scout, caravan
const UNITS := {
	"navette": {"label": "Navette orbitale", "age": 9, "hp": 280, "speed": 4.5, "atk": 0, "range": 0, "cd": 3.0, "vision": 10, "cost": {"food": 180, "ore": 350}, "time": 36.0, "pop": 2, "tags": ["air", "orbital"]},
	"fregate": {"label": "Frégate interstellaire", "age": 10, "hp": 650, "speed": 3.6, "atk": 48, "range": 8, "cd": 2.0, "vision": 12, "cost": {"food": 320, "ore": 700}, "time": 60.0, "pop": 6, "tags": ["military", "air", "orbital", "anti_air"], "bonus": {"air": 1.5}},
	"fusilier": {"label": "Fusilier industriel", "age": 4, "hp": 110, "speed": 2.5, "atk": 18, "range": 7, "cd": 2.5, "vision": 8, "cost": {"food": 100, "ore": 120}, "time": 20.0, "pop": 2, "tags": ["military", "infantry", "ranged"], "bonus": {"infantry": 1.25}},
	"obusier": {"label": "Obusier", "age": 4, "hp": 180, "speed": 1.5, "atk": 80, "range": 11, "cd": 2.5, "vision": 11, "cost": {"food": 100, "ore": 120}, "time": 20.0, "pop": 3, "tags": ["military", "siege"], "min_range": 3.0, "setup": 2.0, "unit_mult": 0.45},
	"grenadier": {"label": "Grenadier impérial", "age": 5, "hp": 145, "speed": 2.6, "atk": 26, "range": 5, "cd": 2.5, "vision": 8, "cost": {"food": 110, "ore": 140}, "time": 22.0, "pop": 2, "tags": ["military", "infantry", "ranged"], "bonus": {"vehicle": 1.8}},
	"char": {"label": "Char de combat", "age": 6, "hp": 540, "speed": 2.3, "atk": 50, "range": 8, "cd": 2.5, "vision": 8, "cost": {"food": 120, "ore": 160}, "time": 24.0, "pop": 4, "tags": ["military", "vehicle"], "bonus": {"infantry": 1.6}},
	"avion": {"label": "Avion d’attaque", "age": 6, "hp": 190, "speed": 6.0, "atk": 25, "range": 6, "cd": 2.5, "vision": 8, "cost": {"food": 120, "ore": 160}, "time": 24.0, "pop": 3, "tags": ["military", "air"], "bonus": {"vehicle": 1.6}},
	"antiaerien": {"label": "Défense antiaérienne", "age": 6, "hp": 240, "speed": 2.1, "atk": 28, "range": 10, "cd": 2.5, "vision": 10, "cost": {"food": 120, "ore": 160}, "time": 24.0, "pop": 3, "tags": ["military", "vehicle", "anti_air"], "bonus": {"air": 3.0}},
	"train": {"label": "Train de ravitaillement", "age": 6, "hp": 350, "speed": 5.0, "atk": 0, "range": 0, "cd": 2.5, "vision": 8, "cost": {"food": 120, "ore": 160}, "time": 24.0, "pop": 3, "tags": ["rail"]},
	"lance_missiles": {"label": "Lance-missiles", "age": 7, "hp": 220, "speed": 1.7, "atk": 90, "range": 15, "cd": 2.5, "vision": 15, "cost": {"food": 130, "ore": 180}, "time": 26.0, "pop": 4, "tags": ["military", "vehicle", "siege"], "min_range": 4.0, "setup": 3.0, "unit_mult": 0.5},
	"drone": {"label": "Drone tactique", "age": 8, "hp": 95, "speed": 5.0, "atk": 18, "range": 7, "cd": 2.5, "vision": 8, "cost": {"food": 140, "ore": 200}, "time": 28.0, "pop": 1, "tags": ["military", "air", "electronic"]},
	"brouilleur": {"label": "Véhicule de guerre électronique", "age": 8, "hp": 200, "speed": 2.5, "atk": 0, "range": 0, "cd": 2.5, "vision": 8, "cost": {"food": 140, "ore": 200}, "time": 28.0, "pop": 2, "tags": ["military", "vehicle", "jammer", "electronic"]},

	"ouvrier": {"label": "Ouvrier", "hp": 50, "speed": 2.2, "atk": 2.0, "range": 0.9, "cd": 1.5, "vision": 6.0,
		"cost": {"food": 50}, "time": 9.0, "pop": 1, "age": 1, "tags": ["worker", "builder"]},
	"eclaireur": {"label": "Éclaireur", "hp": 90, "speed": 4.2, "atk": 4.0, "range": 1.0, "cd": 1.5, "vision": 13.0,
		"cost": {"food": 80, "ore": 20}, "time": 14.0, "pop": 1, "age": 1, "tags": ["scout", "cavalry"]},
	"lancier": {"label": "Lancier", "hp": 95, "speed": 2.4, "atk": 7.0, "range": 1.0, "cd": 1.5, "vision": 7.0,
		"cost": {"food": 50, "wood": 35}, "time": 11.0, "pop": 1, "age": 1, "tags": ["military", "infantry"],
		"bonus": {"cavalry": 2.5}},
	"tireur": {"label": "Tireur régulier", "hp": 75, "speed": 2.3, "atk": 11.0, "range": 6.0, "cd": 2.4, "vision": 8.0,
		"cost": {"food": 60, "ore": 45}, "time": 14.0, "pop": 1, "age": 2, "tags": ["military", "infantry", "ranged"],
		"bonus": {"infantry": 1.3}},
	"cavalier": {"label": "Cavalier", "hp": 140, "speed": 3.7, "atk": 10.0, "range": 1.1, "cd": 1.6, "vision": 8.0,
		"cost": {"food": 100, "ore": 65}, "time": 17.0, "pop": 2, "age": 2, "tags": ["military", "cavalry"],
		"bonus": {"ranged": 2.0, "caravan": 2.0, "siege": 2.5}},
	"canon": {"label": "Canon de siège", "hp": 130, "speed": 1.3, "atk": 70.0, "range": 9.0, "min_range": 3.0, "setup": 3.0,
		"cd": 5.0, "vision": 9.0, "cost": {"wood": 150, "ore": 150}, "time": 22.0, "pop": 3, "age": 3,
		"tags": ["military", "siege"], "unit_mult": 0.25},
	"caravane": {"label": "Caravane", "hp": 140, "speed": 2.5, "atk": 0.0, "range": 0.0, "cd": 1.0, "vision": 5.0,
		"cost": {"food": 60, "wood": 60}, "time": 12.0, "pop": 1, "age": 2, "tags": ["caravan"]},

	## 0.16 — Évolution de la civilisation : unités de voie et héros (champ "civ" : exigent les règles civ_evolution).
	"archer_monte": {"label": "Archer monté", "age": 2, "hp": 110, "speed": 3.9, "atk": 9.0, "range": 5.5, "cd": 2.0, "vision": 9.0, "cost": {"food": 80, "wood": 60}, "time": 16.0, "pop": 2, "tags": ["military", "cavalry", "ranged"], "bonus": {"infantry": 1.2}, "civ": true},
	"chevalier": {"label": "Chevalier", "age": 2, "hp": 220, "speed": 3.4, "atk": 14.0, "range": 1.1, "cd": 1.7, "vision": 8.0, "cost": {"food": 110, "ore": 90}, "time": 22.0, "pop": 2, "tags": ["military", "cavalry"], "bonus": {"ranged": 1.6, "siege": 2.0}, "civ": true},
	"arbaletrier": {"label": "Arbalétrier", "age": 2, "hp": 85, "speed": 2.2, "atk": 15.0, "range": 6.5, "cd": 2.6, "vision": 8.0, "cost": {"food": 60, "wood": 40, "ore": 40}, "time": 15.0, "pop": 1, "tags": ["military", "infantry", "ranged"], "bonus": {"cavalry": 1.3, "infantry": 1.2}, "civ": true},
	"mitrailleur": {"label": "Compagnie mitrailleuse", "age": 5, "hp": 150, "speed": 2.2, "atk": 32.0, "range": 7.0, "cd": 2.8, "vision": 8.0, "cost": {"food": 120, "ore": 150}, "time": 22.0, "pop": 2, "tags": ["military", "infantry", "ranged"], "bonus": {"infantry": 1.5}, "civ": true},
	"garde_imperiale": {"label": "Garde impériale", "age": 5, "hp": 220, "speed": 2.6, "atk": 30.0, "range": 6.0, "cd": 2.4, "vision": 8.0, "cost": {"food": 140, "ore": 170}, "time": 26.0, "pop": 2, "tags": ["military", "infantry", "ranged"], "bonus": {"infantry": 1.3, "vehicle": 1.3}, "civ": true},
	"tireur_elite": {"label": "Tireur d'élite", "age": 5, "hp": 95, "speed": 2.4, "atk": 55.0, "range": 11.0, "cd": 4.0, "vision": 13.0, "cost": {"food": 110, "ore": 150}, "time": 24.0, "pop": 2, "tags": ["military", "infantry", "ranged"], "bonus": {"infantry": 1.6}, "civ": true},
	"robot_combat": {"label": "Robot de combat", "age": 8, "hp": 260, "speed": 2.6, "atk": 34.0, "range": 6.0, "cd": 2.3, "vision": 8.0, "cost": {"wood": 60, "ore": 200}, "time": 20.0, "pop": 2, "tags": ["military", "vehicle", "electronic"], "bonus": {"infantry": 1.4}, "civ": true},
	"exosquelette": {"label": "Exosquelette d'assaut", "age": 8, "hp": 520, "speed": 2.4, "atk": 60.0, "range": 6.0, "cd": 2.4, "vision": 9.0, "cost": {"food": 160, "ore": 260}, "time": 30.0, "pop": 3, "tags": ["military", "infantry"], "bonus": {"vehicle": 1.5}, "civ": true},
	"marine_spatial": {"label": "Marine spatial", "age": 8, "hp": 300, "speed": 2.8, "atk": 48.0, "range": 7.5, "cd": 2.2, "vision": 10.0, "cost": {"food": 150, "ore": 230}, "time": 28.0, "pop": 2, "tags": ["military", "infantry", "ranged", "anti_air"], "bonus": {"infantry": 1.3, "air": 1.3}, "civ": true},
	"heros_antique": {"label": "Capitaine (héros)", "age": 2, "hp": 900, "speed": 2.9, "atk": 24.0, "range": 1.2, "cd": 1.5, "vision": 10.0, "cost": {"food": 300, "wood": 100, "ore": 200}, "time": 40.0, "pop": 3, "tags": ["military", "infantry", "hero"], "civ": true},
	"heros_industriel": {"label": "Général (héros)", "age": 5, "hp": 1400, "speed": 2.9, "atk": 42.0, "range": 7.0, "cd": 2.0, "vision": 11.0, "cost": {"food": 500, "ore": 450}, "time": 50.0, "pop": 4, "tags": ["military", "infantry", "ranged", "hero"], "civ": true},
	"heros_spatial": {"label": "Commandant (héros)", "age": 8, "hp": 2200, "speed": 3.1, "atk": 70.0, "range": 8.0, "cd": 2.0, "vision": 12.0, "cost": {"food": 700, "ore": 800}, "time": 60.0, "pop": 5, "tags": ["military", "infantry", "ranged", "anti_air", "hero"], "civ": true},
}

## Multiplicateur de dégâts contre les bâtiments (pas de siège avant J2).
const BUILDING_DAMAGE := {"default": 1.0, "siege": 3.0, "ranged": 0.35, "cavalry": 0.6, "worker": 0.5}

const BUILDINGS := {
	"spatioport": {"label": "Spatioport orbital", "age": 9, "size": 4, "hp": 2500, "cost": {"wood": 440, "ore": 640}, "time": 75.0, "vision": 11.0, "trains": ["navette"]},
	"chantier_orbital": {"label": "Terminal orbital terrestre (hérité)", "age": 10, "size": 4, "hp": 3200, "cost": {"wood": 620, "ore": 850}, "time": 100.0, "vision": 13.0, "trains": ["navette", "fregate"]},
	"usine": {"label": "Usine industrielle", "age": 4, "size": 4, "hp": 1600, "cost": {"wood": 270, "ore": 200}, "time": 42.0, "vision": 7.0, "trains": ["fusilier", "obusier", "grenadier", "char", "antiaerien", "lance_missiles", "brouilleur", "robot_combat"], "industry": true},
	"academie": {"label": "Académie impériale", "age": 5, "size": 3, "hp": 1700, "cost": {"wood": 300, "ore": 225}, "time": 45.0, "vision": 7.0},
	"depot": {"label": "Dépôt logistique", "age": 6, "size": 2, "hp": 1800, "cost": {"wood": 330, "ore": 250}, "time": 48.0, "vision": 7.0, "drop": true},
	"gare": {"label": "Gare ferroviaire", "age": 6, "size": 3, "hp": 1800, "cost": {"wood": 330, "ore": 250}, "time": 48.0, "vision": 7.0, "trains": ["train"], "drop": true},
	"aerodrome": {"label": "Aérodrome", "age": 6, "size": 4, "hp": 1800, "cost": {"wood": 330, "ore": 250}, "time": 48.0, "vision": 7.0, "trains": ["avion", "drone"]},
	"radar": {"label": "Station radar", "age": 7, "size": 2, "hp": 1900, "cost": {"wood": 360, "ore": 275}, "time": 51.0, "vision": 20.0},
	"silo": {"label": "Silo de missiles", "age": 7, "size": 3, "hp": 1900, "cost": {"wood": 360, "ore": 275}, "time": 51.0, "vision": 7.0},
	"intercepteur": {"label": "Batterie antimissile", "age": 7, "size": 2, "hp": 1900, "cost": {"wood": 360, "ore": 275}, "time": 51.0, "vision": 7.0},

	"centre": {"label": "Centre de commandement", "hp": 2000, "size": 4, "cost": {"wood": 300, "ore": 200}, "time": 60.0,
		"pop": 10, "drop": true, "atk": 6.0, "range": 7.0, "cd": 2.0, "vision": 10.0, "age": 1,
		"trains": ["ouvrier", "eclaireur", "heros_antique", "heros_industriel", "heros_spatial"]},
	"maison": {"label": "Maison", "hp": 400, "size": 2, "cost": {"wood": 60}, "time": 14.0, "pop": 6, "vision": 4.0, "age": 1},
	"entrepot": {"label": "Entrepôt", "hp": 500, "size": 2, "cost": {"wood": 80}, "time": 18.0, "drop": true, "vision": 5.0, "age": 1},
	"ferme": {"label": "Ferme", "hp": 300, "size": 3, "cost": {"wood": 70}, "time": 14.0, "vision": 4.0, "age": 1,
		"farm": true},
	"caserne": {"label": "Caserne", "hp": 1000, "size": 3, "cost": {"wood": 150}, "time": 28.0, "vision": 6.0, "age": 1,
		"trains": ["lancier", "tireur", "cavalier", "chevalier", "arbaletrier", "garde_imperiale", "tireur_elite", "exosquelette", "marine_spatial"]},
	"marche": {"label": "Marché", "hp": 800, "size": 3, "cost": {"wood": 170, "ore": 40}, "time": 28.0, "vision": 6.0, "age": 2,
		"trains": ["caravane", "archer_monte", "mitrailleur"], "drop": true, "trade_hub": true},
	"relais": {"label": "Relais marchand", "hp": 600, "size": 2, "cost": {"wood": 120}, "time": 18.0, "vision": 8.0, "age": 2,
		"on_post": true},
	"palissade": {"label": "Palissade", "hp": 900, "size": 1, "cost": {"wood": 25}, "time": 6.0, "vision": 2.0, "age": 2,
		"on_ford_ok": true, "wall": true},
	"fort": {"label": "Fort", "hp": 3500, "size": 3, "cost": {"wood": 250, "ore": 250}, "time": 50.0, "vision": 11.0, "age": 3,
		"atk": 14.0, "range": 8.0, "cd": 2.0, "on_ford_ok": true},
	"atelier": {"label": "Atelier de siège", "hp": 900, "size": 3, "cost": {"wood": 200, "ore": 100}, "time": 30.0, "vision": 6.0,
		"age": 3, "trains": ["canon"]},
	## 0.16 — Forge et monuments d'âge (règles civ_evolution). Un monument se pose à l'âge précédent ("monument" = âge visé) ;
	## son achèvement fait passer l'âge. Le champ "age" vaut 1 : le contrôle d'âge réel est fait par CivEvolution.
	"forge": {"label": "Forge", "age": 2, "size": 3, "hp": 1100, "cost": {"wood": 150, "ore": 60}, "time": 30.0, "vision": 6.0, "civ": true},
	"monument_grand_comptoir": {"label": "Grand Comptoir (monument, âge II)", "age": 1, "size": 4, "hp": 3000, "cost": {"food": 400, "wood": 200}, "time": 52.5, "vision": 8.0, "monument": 2, "civ": true},
	"monument_bibliotheque": {"label": "Bibliothèque des Cartes (monument, âge II)", "age": 1, "size": 4, "hp": 3000, "cost": {"food": 400, "wood": 200}, "time": 52.5, "vision": 8.0, "monument": 2, "civ": true},
	"monument_citadelle": {"label": "Citadelle (monument, âge III)", "age": 1, "size": 4, "hp": 3300, "cost": {"food": 700, "wood": 450, "ore": 300}, "time": 67.5, "vision": 8.0, "monument": 3, "civ": true},
	"monument_temple_batisseurs": {"label": "Temple des Bâtisseurs (monument, âge III)", "age": 1, "size": 4, "hp": 3300, "cost": {"food": 700, "wood": 450, "ore": 300}, "time": 67.5, "vision": 8.0, "monument": 3, "civ": true},
	"monument_grande_forge": {"label": "Grande Forge (monument, âge IV)", "age": 1, "size": 4, "hp": 3600, "cost": {"food": 950, "wood": 500, "ore": 600}, "time": 90.0, "vision": 8.0, "monument": 4, "civ": true},
	"monument_manufacture": {"label": "Manufacture royale (monument, âge IV)", "age": 1, "size": 4, "hp": 3600, "cost": {"food": 950, "wood": 500, "ore": 600}, "time": 90.0, "vision": 8.0, "monument": 4, "civ": true},
	"monument_palais": {"label": "Palais impérial (monument, âge V)", "age": 1, "size": 4, "hp": 3900, "cost": {"food": 1200, "wood": 600, "ore": 800}, "time": 97.5, "vision": 8.0, "monument": 5, "civ": true},
	"monument_grande_universite": {"label": "Grande Université (monument, âge V)", "age": 1, "size": 4, "hp": 3900, "cost": {"food": 1200, "wood": 600, "ore": 800}, "time": 97.5, "vision": 8.0, "monument": 5, "civ": true},
	"monument_arsenal_national": {"label": "Arsenal national (monument, âge VI)", "age": 1, "size": 4, "hp": 4200, "cost": {"food": 1450, "wood": 700, "ore": 1000}, "time": 105.0, "vision": 8.0, "monument": 6, "civ": true},
	"monument_gare_centrale": {"label": "Gare centrale (monument, âge VI)", "age": 1, "size": 4, "hp": 4200, "cost": {"food": 1450, "wood": 700, "ore": 1000}, "time": 105.0, "vision": 8.0, "monument": 6, "civ": true},
	"monument_bouclier_national": {"label": "Bouclier national (monument, âge VII)", "age": 1, "size": 4, "hp": 4500, "cost": {"food": 1700, "wood": 800, "ore": 1200}, "time": 112.5, "vision": 8.0, "monument": 7, "civ": true},
	"monument_etat_major": {"label": "État-major stratégique (monument, âge VII)", "age": 1, "size": 4, "hp": 4500, "cost": {"food": 1700, "wood": 800, "ore": 1200}, "time": 112.5, "vision": 8.0, "monument": 7, "civ": true},
	"monument_centre_calcul": {"label": "Centre de calcul (monument, âge VIII)", "age": 1, "size": 4, "hp": 4800, "cost": {"food": 1950, "wood": 900, "ore": 1400}, "time": 120.0, "vision": 8.0, "monument": 8, "civ": true},
	"monument_usine_robotisee": {"label": "Usine robotisée (monument, âge VIII)", "age": 1, "size": 4, "hp": 4800, "cost": {"food": 1950, "wood": 900, "ore": 1400}, "time": 120.0, "vision": 8.0, "monument": 8, "civ": true},
	"monument_ascenseur_spatial": {"label": "Ascenseur spatial (monument, âge IX)", "age": 1, "size": 4, "hp": 5100, "cost": {"food": 2400, "wood": 1050, "ore": 1600}, "time": 135.0, "vision": 8.0, "monument": 9, "civ": true},
	"monument_observatoire": {"label": "Observatoire profond (monument, âge IX)", "age": 1, "size": 4, "hp": 5100, "cost": {"food": 2400, "wood": 1050, "ore": 1600}, "time": 135.0, "vision": 8.0, "monument": 9, "civ": true},
	"monument_porte_stellaire": {"label": "Porte stellaire (monument, âge X)", "age": 1, "size": 4, "hp": 5400, "cost": {"food": 3100, "wood": 1300, "ore": 2200}, "time": 165.0, "vision": 8.0, "monument": 10, "civ": true},
	"monument_archive_galactique": {"label": "Archive galactique (monument, âge X)", "age": 1, "size": 4, "hp": 5400, "cost": {"food": 3100, "wood": 1300, "ore": 2200}, "time": 165.0, "vision": 8.0, "monument": 10, "civ": true},
	## 0.18 — Ville de l'âge de l'électricité (règles urban : UrbanRules / UrbanCity). Visibles et constructibles seulement
	## après la recherche « Électricité », dans les parties avec l'évolution de la civilisation. Valeurs PROVISOIRES.
	## 0.19 — Les bâtiments de zone poussent sur les parcelles zonées (UrbanZoning / UrbanGrowth) dès l'âge I :
	## "zoned" = ne se pose pas par « Bâtir ». Le coût indiqué sert de référence à la croissance (ressources réelles).
	"zone_r": {"label": "Habitation", "age": 1, "size": 2, "hp": 500, "cost": {"wood": 40, "ore": 10}, "time": 10.0, "vision": 4.0, "urban": true, "zoned": true},
	"zone_c": {"label": "Commerce", "age": 1, "size": 2, "hp": 600, "cost": {"wood": 50, "ore": 25}, "time": 12.0, "vision": 4.0, "urban": true, "zoned": true},
	"zone_i": {"label": "Industrie", "age": 1, "size": 2, "hp": 700, "cost": {"wood": 40, "ore": 50}, "time": 14.0, "vision": 4.0, "urban": true, "zoned": true},
	"zone_a": {"label": "Exploitation agricole", "age": 1, "size": 2, "hp": 350, "cost": {"wood": 30}, "time": 10.0, "vision": 4.0, "urban": true, "zoned": true},
	"ruine": {"label": "Ruines", "age": 1, "size": 2, "hp": 120, "cost": {}, "time": 1.0, "vision": 2.0, "zoned": true, "rubble": true},
	"puits": {"label": "Puits et citerne", "age": 1, "size": 1, "hp": 250, "cost": {"wood": 40}, "time": 8.0, "vision": 3.0, "urban": true},
	"centrale": {"label": "Centrale électrique", "age": 4, "size": 3, "hp": 1400, "cost": {"wood": 120, "ore": 200}, "time": 30.0, "vision": 6.0, "urban": true},
	"centrale_solaire": {"label": "Centrale solaire", "age": 8, "size": 3, "hp": 1100, "cost": {"wood": 80, "ore": 320}, "time": 30.0, "vision": 6.0, "urban": true},
	"poste_electrique": {"label": "Poste électrique", "age": 4, "size": 1, "hp": 300, "cost": {"ore": 35}, "time": 6.0, "vision": 3.0, "urban": true},
	"chateau_eau": {"label": "Château d'eau", "age": 4, "size": 2, "hp": 900, "cost": {"wood": 60, "ore": 90}, "time": 18.0, "vision": 6.0, "urban": true},
	"station_pompage": {"label": "Station de pompage", "age": 5, "size": 2, "hp": 900, "cost": {"wood": 80, "ore": 140}, "time": 22.0, "vision": 5.0, "urban": true},
	"commissariat": {"label": "Commissariat", "age": 3, "size": 2, "hp": 1000, "cost": {"wood": 80, "ore": 80}, "time": 20.0, "vision": 7.0, "urban": true},
	"caserne_pompiers": {"label": "Caserne de pompiers", "age": 4, "size": 2, "hp": 1000, "cost": {"wood": 80, "ore": 80}, "time": 20.0, "vision": 6.0, "urban": true},
	"hopital": {"label": "Hôpital", "age": 2, "size": 3, "hp": 1200, "cost": {"wood": 120, "ore": 120}, "time": 28.0, "vision": 6.0, "urban": true},
	"decharge": {"label": "Décharge", "age": 4, "size": 3, "hp": 800, "cost": {"wood": 60, "ore": 60}, "time": 16.0, "vision": 4.0, "urban": true},
	"recyclage": {"label": "Centre de recyclage", "age": 6, "size": 3, "hp": 1000, "cost": {"wood": 100, "ore": 180}, "time": 26.0, "vision": 5.0, "urban": true},
	"comptoir": {"label": "Comptoir neutre", "hp": 99999, "size": 2, "cost": {}, "time": 1.0, "vision": 0.0, "age": 99,
		"neutral": true},
}

## Collecte
const CARRY := 10.0
const GATHER_RATE := {"baies": 0.85, "ferme": 0.62, "arbre": 0.7, "minerai": 0.6}
const NODE_RES := {"baies": "food", "ferme": "food", "arbre": "wood", "minerai": "ore"}
const FARM_SLOTS := 1

## Commerce (PROVISOIRE) : gain par aller-retour = distance(hub, relais) * TRADE_PER_TILE
const TRADE_PER_TILE := 1.15
const EXCHANGE_START_RATE := 0.8   # 100 vendus -> 80 achetés, se dégrade de 0.04 à chaque échange
const EXCHANGE_STEP := 0.04
const EXCHANGE_MIN := 0.35

## Conquête : capacité de reconstruction. PROVISOIRE, soumis à arbitrage (cf. decisions.md D-07).
##  "batisseur_et_moyens" : un ouvrier vivant ET (stock >= coût centre OU fondation de centre OU dépôt intact)
##  "batisseur_seul"      : un ouvrier vivant suffit
const REBUILD_RULE := "batisseur_et_moyens"
## Minuteur de reconstruction (arbitrage D-07 approuvé le 2026-11-09) : un camp sans centre achevé
## pendant plus de REBUILD_TIMEOUT secondes est éliminé, même s'il garde des moyens. Valeur PROVISOIRE.
const REBUILD_TIMEOUT := 180.0

const START := {
	"res": {"food": 200, "wood": 220, "ore": 100},
	"workers": 5,
	"scouts": 1,
}

static func unit_has(type: String, tag: String) -> bool:
	return UNITS[type]["tags"].has(tag)

static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for r in RESOURCES:
		if int(cost.get(r, 0)) > 0:
			parts.append("%d %s" % [int(cost[r]), RES_LABEL[r].to_lower()])
	return ", ".join(parts) if parts.size() > 0 else "gratuit"

## Recherches achetées une fois par camp, durées en secondes de simulation.
const TECHNOLOGIES := {
 "cartographie": {"label": "Cartographie terrestre (atlas planétaire)", "age": 2, "building": "marche", "cost": {"wood": 120, "ore": 90}, "time": 30.0},
 "observation_orbitale": {"label": "Observation orbitale (vue orbite)", "age": 9, "building": "spatioport", "requires": ["cartographie"], "cost": {"ore": 400, "wood": 180}, "time": 45.0},
 "navigation_interplanetaire": {"label": "Navigation interplanétaire (vue système)", "age": 9, "building": "spatioport", "requires": ["observation_orbitale"], "cost": {"ore": 600, "food": 200}, "time": 60.0},
 "cartographie_galactique": {"label": "Cartographie galactique (vue galaxie)", "age": 10, "building": "chantier_orbital", "requires": ["navigation_stellaire"], "cost": {"ore": 900, "wood": 200}, "time": 85.0},
 "electricite": {"label": "Électricité (la ville remplace fermes, maisons et récolte)", "age": 4, "building": "usine", "cost": {"wood": 200, "ore": 250}, "time": 40.0, "civ": true},
 "outillage": {"label": "Outillage industriel (+25% collecte)", "age": 4, "building": "usine", "cost": {"wood": 180, "ore": 220}, "time": 35.0},
 "standardisation": {"label": "Standardisation (+25% production)", "age": 5, "building": "academie", "cost": {"food": 250, "ore": 350}, "time": 45.0},
 "blindage": {"label": "Blindage (-20% dégâts véhicules)", "age": 6, "building": "usine", "cost": {"ore": 500}, "time": 45.0},
 "contre_mesures": {"label": "Contre-mesures (brouillage réduit)", "age": 8, "building": "radar", "cost": {"wood": 200, "ore": 600}, "time": 50.0},
 "propulsion_orbitale": {"label": "Propulsion orbitale (+20% vitesse aérienne)", "age": 9, "building": "spatioport", "cost": {"ore": 700}, "time": 60.0},
 "navigation_stellaire": {"label": "Navigation stellaire (+20% résistance des frégates)", "age": 10, "building": "chantier_orbital", "requires": ["navigation_interplanetaire"], "cost": {"ore": 1000, "wood": 300}, "time": 80.0},
}
