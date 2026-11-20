class_name J13Rules
extends RefCounted
## J13 : tables versionnées de l'économie planétaire. Toutes les valeurs sont des
## paramètres de conception PROVISOIRES (cadrage V3.0), à calibrer par playtests.
## Aucune règle n'est codée dans l'interface : tout passe par ces tables.

const SCHEMA: int = 13
# Partition de la sphère en bandes d'aire égale (sin(lat) uniforme) : 72 districts de même surface.
const GRID_W: int = 12
const GRID_H: int = 6
const LAND_OCEAN: int = 0
const LAND_BUILDABLE: int = 1
const LAND_RELIEF: int = 2
const LAND_PROTECTED: int = 3
const LAND_LABELS := ["océan", "constructible", "relief interdit", "réserve naturelle"]

const ECON_PERIOD: int = 20        # ticks entre deux tranches économiques
const TRANSFER_PERIOD: int = 200   # virement des bénéfices vers la trésorerie
const GOVERNOR_PERIOD: int = 100
const GOVERNOR_ACTIONS: int = 2    # actions maximum par cycle
const COLONY_START_AGE: int = 7
const SCENARIO_CREDITS: float = 500.0  # dotation de départ d'une NOUVELLE partie (écriture tracée)
const RESERVE_FLOOR: float = 50.0
const LEDGER_KEEP: int = 200
const JOURNAL_KEEP: int = 60

const GOODS := ["alloy", "concrete", "electronics", "machinery", "fuel", "medical_supplies", "consumer_goods", "ship_parts"]
const GOOD_LABELS := {"alloy": "Alliage", "concrete": "Béton", "electronics": "Électronique", "machinery": "Machines",
	"fuel": "Carburant", "medical_supplies": "Médical", "consumer_goods": "Biens", "ship_parts": "Pièces spatiales"}
const STOCK_CAP: float = 5000.0

const ZONES := ["R", "C", "I"]
const ZONE_LABELS := {"R": "Habitation", "C": "Commerce", "I": "Industrie"}
const ZONE_MIN_AGE := {"R": 1, "C": 2, "I": 4}
const DEFAULT_TARGET := {"R": 0.45, "C": 0.25, "I": 0.30}
const PRESETS := {
	"equilibre": {"R": 0.45, "C": 0.25, "I": 0.30},
	"residentiel": {"R": 0.60, "C": 0.20, "I": 0.20},
	"industriel": {"R": 0.25, "C": 0.20, "I": 0.55},
	"commerce": {"R": 0.40, "C": 0.45, "I": 0.15},
}
const TARGET_MIN: float = 0.05
const TARGET_MAX: float = 0.90
# Les habitations et commerces de base ne coûtent que des matériaux : une partie migrée
# (trésorerie 0) peut amorcer son économie sans crédit gratuit.
const ZONE_COST := {
	"R": {"wood": 60, "ore": 20},
	"C": {"wood": 50, "ore": 40},
	"I": {"credits": 60, "wood": 40, "ore": 90},
}
const ROAD_COST := {"wood": 5, "ore": 10}
# Liaison maritime (pont, bac) : traverse un district océanique sans jamais le bâtir.
const LINK_COST := {"credits": 20, "wood": 30, "ore": 60}
const REPAIR_COST := {"ore": 10}
const DENSIFY_CREDITS: int = 80
const DENSIFY_CONCRETE: int = 20
const HOUSING: int = 40            # habitants par niveau de densité
const JOBS := {"C": 20, "I": 30}   # emplois par niveau de densité
const UTILITY_NEED := {"R": 1, "C": 1, "I": 2, "hospital": 1, "police": 1, "fire": 1, "power": 0, "water": 1, "hq": 0}
const HQ_AUTONOMY: int = 2         # générateur et citerne autonomes du commandement

# Eau et électricité ne coûtent que des matériaux, comme les maisons : aucune colonie sans crédit n'est bloquée.
const FACILITIES := {
	"power": {"label": "Centrale électrique", "age": 1, "cost": {"wood": 40, "ore": 120}, "capacity": 12},
	"water": {"label": "Station d'eau", "age": 1, "cost": {"wood": 40, "ore": 60}, "capacity": 12},
	"hospital": {"label": "Hôpital", "age": 1, "cost": {"credits": 120, "wood": 60, "ore": 80}, "capacity": 400, "reach": 3},
	"police": {"label": "Poste de police", "age": 1, "cost": {"credits": 90, "wood": 40, "ore": 60}, "capacity": 500, "reach": 3},
	"fire": {"label": "Caserne de pompiers", "age": 1, "cost": {"credits": 90, "wood": 40, "ore": 70}, "capacity": 500, "reach": 2},
}
const MOBILE_SERVICES := ["hospital", "police", "fire"]
const SERVICE_LABELS := {"hospital": "Santé", "police": "Police", "fire": "Pompiers", "power": "Électricité", "water": "Eau"}
# Ordre de délestage : les premiers servis en cas de pénurie d'eau ou d'électricité.
const UTILITY_PRIORITY := ["hq", "hospital", "water", "fire", "police", "R", "I", "C"]

# Recettes : entrées « base » prises dans le dépôt du système, les autres dans le stock planétaire.
# Aucune recette ne sort plus d'unités qu'elle n'en consomme.
const RECIPES := {
	"fonderie": {"label": "Fonderie", "age": 4, "in": {"ore": 4}, "out": {"alloy": 2}},
	"betonnerie": {"label": "Bétonnerie", "age": 4, "in": {"ore": 3}, "out": {"concrete": 2}},
	"usine_civile": {"label": "Usine civile", "age": 4, "in": {"wood": 2, "alloy": 1}, "out": {"consumer_goods": 3}},
	"raffinerie": {"label": "Raffinerie", "age": 6, "in": {"ore": 2, "wood": 2}, "out": {"fuel": 1}},
	"electronique": {"label": "Électronique", "age": 7, "in": {"alloy": 2}, "out": {"electronics": 1}},
	"pharma": {"label": "Laboratoire médical", "age": 7, "in": {"wood": 1, "electronics": 1}, "out": {"medical_supplies": 2}},
	"mecanique": {"label": "Usine mécanique", "age": 8, "in": {"alloy": 2, "electronics": 1, "fuel": 1}, "out": {"machinery": 1}},
	"chantier_pieces": {"label": "Pièces spatiales", "age": 9, "in": {"alloy": 3, "electronics": 2}, "out": {"ship_parts": 1}},
}
const RECIPE_ORDER := ["fonderie", "usine_civile", "betonnerie", "raffinerie", "electronique", "pharma", "mecanique", "chantier_pieces"]

# Commerce : un commerce vend un produit RÉEL (biens manufacturés, sinon vivres du dépôt).
const GOODS_PRICE: float = 8.0
const FOOD_PRICE: float = 2.0
const SHOP_GOODS_RATE: float = 4.0   # biens vendus par tranche et par niveau
const SHOP_FOOD_RATE: float = 2.0
## 0.16 : les commerces ne vendent pas les vivres sous ce stock (ordre de sûreté : survie et armée avant le commerce).
const FOOD_SALE_FLOOR: float = 400.0
const DEMAND_PER_HEAD: float = 0.05
const PAYROLL: float = 0.005
const SHOP_MAINTENANCE: float = 0.2
const FOOD_PER_HEAD: float = 0.004

# Progression locale VII → X (les âges I–VII d'un monde fondateur suivent le centre tactique).
const AGE_UP := {
	8: {"credits": 400, "goods": {"alloy": 60}, "industry": 2, "ticks": 300},
	9: {"credits": 800, "goods": {"alloy": 80, "electronics": 60}, "industry": 3, "power": 0.9, "ticks": 400},
	10: {"credits": 1500, "goods": {"electronics": 80, "machinery": 40}, "industry": 4, "station": true, "ticks": 500},
}

# Stations de commandement supplémentaires (le chantier naval 0.12.3 est la première).
const STATION_COST := {"credits": 300, "wood": 350, "ore": 600}
const STATION_TICKS: int = 180
const STATION_HP: float = 1800.0
const STATION_LIMIT: int = 3       # chantier compris, par camp et par planète

const TRANSPORT_LIMIT: int = 64
const TRANSPORT_SEATS: int = 12
const TRANSPORT_HOLD: int = 200
const COLONY_COLONISTS: int = 12
const SURFACE_LAUNCH_COST := {"food": 60, "ore": 120}

# Noms affichés par niveau de densité.
const DENSITY_LABELS := {
	"R": ["Maisons", "Immeubles", "Tours d'habitation"],
	"C": ["Petits commerces", "Marché", "Centre commercial"],
	"I": ["Ateliers", "Usine", "Complexe industriel"],
}

# J13.1 — chaîne d'approvisionnement : ce que la colonie doit fournir, en plus du coût historique.
# Âges I–III : seulement des habitants. Dès l'âge IV, l'industrie équipe troupes et bâtiments.
static func unit_needs(kind: String) -> Dictionary:
	var definition: Dictionary = Rules.UNITS.get(kind, {}) as Dictionary
	if definition.is_empty():
		return {}
	var people: int = maxi(1, int(definition.get("pop", 1)))
	var age: int = int(definition.get("age", 1))
	var need: Dictionary = {"people": people}
	if age >= 4:
		need["alloy"] = 2 * people
	if age >= 6:
		need["fuel"] = people
	if age >= 8:
		need["electronics"] = people
	return need

static func building_needs(kind: String) -> Dictionary:
	var definition: Dictionary = Rules.BUILDINGS.get(kind, {}) as Dictionary
	if definition.is_empty():
		return {}
	if UrbanRules.is_zone(kind):
		return {} # 0.18 : une zone est un découpage du sol, pas un édifice (les services, eux, consomment du béton).
	var size: int = maxi(1, int(definition.get("size", 1)))
	var age: int = int(definition.get("age", 1))
	var need: Dictionary = {}
	if age >= 4:
		need["concrete"] = size * size
	if age >= 6:
		need["alloy"] = size * 2
	if age >= 8:
		need["electronics"] = size
	return need

static func max_density(age: int) -> int:
	return 1 if age < 4 else (2 if age < 7 else 3)

static func roman(age: int) -> String:
	return ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(age, 0, 10)]
