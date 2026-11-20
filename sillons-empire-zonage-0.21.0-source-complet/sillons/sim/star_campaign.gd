class_name StarCampaign
extends RefCounted
## J6-J8 : trois théâtres persistants, tous simulés à pas fixe, jamais en temps réel système.
## Les ressources, technologies et âges sont communs au camp ; les troupes, cartes et brouillards
## restent propres à chaque planète. Aucun objet de scène n'est sérialisé.

const SECTORS := ["val", "aurore", "nemesis"]
const DEFINITIONS := {
	"val": {"label": "Val des Deux Gués", "system": "Sol", "age": 1},
	"aurore": {"label": "Aurore", "system": "Sol", "age": 9},
	"nemesis": {"label": "Némésis", "system": "Proxima", "age": 10},
}
const SCAN_COST := {"ore": 160}
const SATELLITE_COST := {"ore": 400, "wood": 100}
const TRAVEL_COST := {"food": 180, "ore": 350}
const STAR_TRAVEL_COST := {"food": 320, "ore": 900}
const COLONY_COST := {"wood": 300, "ore": 200}
const LANDING := [Vector2(14, 79), Vector2(80, 14)]

var orbital_tactics: bool = false
var orbital_maps: Dictionary = {}
var next_orbit_actor: int = 1
var evolutions_enabled: bool = false
var factions: FactionRegistry = FactionRegistry.new()
var homes: Dictionary = {0: "val", 1: "val"}
var raw_stocks: Dictionary = {}
var treaties: Array = []
var reinforcements: Array = []
var command_log: Array = []
var worlds: Dictionary = {}
var active: String = "val"
var tick: int = 0
var resources: Array = [{"food": 0.0, "wood": 0.0, "ore": 0.0}, {"food": 0.0, "wood": 0.0, "ore": 0.0}]
var ages: Array = [1, 1]
var technologies: Array = [{}, {}]
## 0.16 : état d'évolution de la civilisation par camp, partagé par référence avec chaque monde (Team.civ).
var civ_states: Dictionary = {}
var satellites: Array = [0, 0]
var sat_cooldown: Array = [0, 0]
var scan_cooldown: Array = [0, 0]
var flights: Array = []
var next_flight: int = 1
var eliminated: Array = [false, false]
var lost_centers_at: Array = [-1, -1]
var game_over: bool = false
var winner: int = -1
var notices: Array = []
const OFFSCREEN_ALERT_TYPES := ["mort", "detruit", "alerte_missile", "penurie", "sans_centre", "elimine", "recherche_perdue", "age_atteint"]
var _initial_seed: int = 0
var planet_regions: PlanetRegions = null
var star_catalog: StarSystemGenerator = null
# J11 : la connaissance des routes appartient à chaque camp, pas à la caméra.
var discovered_systems: Array = [{"sol": true, "proxima": true}, {"sol": true, "proxima": true}]
var survey_probes: Array = []
var next_probe_id: int = 1
# J12 : comptabilité par système ; ressources garde l'alias des stocks de Sol
# pour les appels historiques et les anciens scénarios de recette.
var system_stocks: Dictionary = {}
var freight_orders: Array = []
var next_freight_id: int = 1
var directives: Dictionary = {}
# J12.3 : chantiers navals physiquement en orbite, séparés des bâtiments tactiques.
var orbital_sites: Dictionary = {}
var orbital_presence: Dictionary = {}
var orbital_flights: Array = []
var next_orbital_flight: int = 1
var orbital_initial_granted: Array = [false, false]
# J13 : colonies à âge local, économie R/C/I, trésorerie, transports et verrou orbital.
var planets: PlanetCampaign = PlanetCampaign.new()
const FREIGHT_LIMIT: int = 64
const FREIGHT_FARE_FOOD: int = 20
const FREIGHT_MAX_UNITS: int = 20000
const ORDER_MODES := ["observe", "defend", "supply", "explore"]
const SURVEY_COST := {"food": 90, "ore": 240}
const SURVEY_BASE_TICKS: int = 140

func create(seed: int, player_ai: bool = false, planet_j9: bool = false, region_lon: float = 0.0, region_lat: float = 0.0) -> void:
	_initial_seed = seed
	discovered_systems = [{"sol": true, "proxima": true}, {"sol": true, "proxima": true}]
	survey_probes.clear()
	next_probe_id = 1
	star_catalog = StarSystemGenerator.new(seed)
	worlds.clear()
	planet_regions = null
	flights.clear()
	freight_orders.clear()
	next_freight_id = 1
	directives.clear()
	orbital_sites.clear()
	orbital_presence.clear()
	orbital_flights.clear()
	next_orbital_flight = 1
	orbital_initial_granted = [false, false]
	system_stocks.clear()
	resources = [{"food": 0.0, "wood": 0.0, "ore": 0.0}, {"food": 0.0, "wood": 0.0, "ore": 0.0}]
	active = "val"
	tick = 0
	eliminated = [false, false]
	lost_centers_at = [-1, -1]
	game_over = false
	winner = -1
	notices.clear()
	for i in SECTORS.size():
		var sector: String = SECTORS[i]
		var w := SimWorld.new()
		var overrides: Dictionary = GameConfig.merge_rules({"campaign": true, "sector": sector})
		if planet_j9 and sector == "val":
			var selected: Vector2i = PlanetGenerator.region_coords(region_lon, region_lat)
			overrides["planet_j9"] = true
			overrides["planet_region_grid"] = true
			overrides["planet_origin"] = true
			overrides["region_x"] = selected.x
			overrides["region_y"] = selected.y
			overrides["planet_master_seed"] = seed
			overrides["planet_lon"] = region_lon
			overrides["planet_lat"] = region_lat
		w.setup(seed + i * 100003, overrides)
		w.teams[0].ai_controlled = player_ai
		w.teams[1].ai_controlled = true
		if i == 0:
			w.start_standard()
			w.ai_controllers.append(AiController.new(1))
			w.teams[1].ai_controlled = true
			if player_ai:
				w.ai_controllers.append(AiController.new(0))
		else:
			# Pas de victoire locale quand les autres planètes continuent à combattre.
			w.update_fog(true)
		worlds[sector] = w
	for team in faction_ids():
		resources[team] = (current().teams[team] as SimWorld.Team).res.duplicate(true)
		ages[team] = 1
	system_stocks["sol"] = resources
	if planet_j9:
		planet_regions = PlanetRegions.new()
		planet_regions.setup(seed, PlanetGenerator.region_coords(region_lon, region_lat), worlds["val"] as SimWorld)
	planets = PlanetCampaign.new()
	planets.bootstrap(self, true)
	_sync_all()

func adopt_legacy(w: SimWorld) -> void:
	## Restauration d'un emplacement J3-J5 vers une campagne sans perte de la carte source.
	create(w.seed_value)
	w.rules["campaign"] = true
	w.rules["sector"] = "val"
	worlds["val"] = w
	for team in faction_ids():
		resources[team] = (w.teams[team] as SimWorld.Team).res.duplicate(true)
		ages[team] = int((w.teams[team] as SimWorld.Team).age)
		technologies[team] = (w.teams[team] as SimWorld.Team).technologies.duplicate(true)
	_sync_all()

func current() -> SimWorld:
	return worlds[active] as SimWorld

func info(key: String) -> Dictionary:
	if DEFINITIONS.has(key):
		var historic: Dictionary = (DEFINITIONS[key] as Dictionary).duplicate(true)
		if star_catalog != null:
			historic.merge(star_catalog.info(key), true)
		return historic
	return star_catalog.info(key) if star_catalog != null else {}

func sector_keys() -> Array:
	return star_catalog.sector_keys() if star_catalog != null else SECTORS.duplicate()

func materialize(key: String) -> SimWorld:
	if worlds.has(key):
		return worlds[key] as SimWorld
	if star_catalog == null or not star_catalog.has_body(key) or SECTORS.has(key):
		return null
	var body: Dictionary = star_catalog.info(key)
	var w := SimWorld.new()
	var s: int = int(body["seed"])
	w.setup(s, {"campaign": true, "sector": key, "planet_j9": true, "map_size": 256 if evolutions_enabled else 96, "evolutions": evolutions_enabled,
		"planet_master_seed": s, "planet_lon": 0.0, "planet_lat": 0.0})
	w.tick = tick # aligne les échéances locales sur le temps de campagne
	w.teams[0].ai_controlled = bool((worlds["val"] as SimWorld).teams[0].ai_controlled)
	w.teams[1].ai_controlled = true
	w.update_fog(true)
	worlds[key] = w
	_sync_all()
	return w

func system_known(team: int, system_id: String) -> bool:
	return valid_faction(team) and (discovered_systems[team] as Dictionary).has(system_id)

func system_owner(system_id: String) -> int:
	# Propriété dérivée des centres VIVANTS : le brouillard ne donne aucun contrôle.
	var occupation: Dictionary = {}
	for key in worlds.keys():
		if String(info(String(key)).get("system_id", "")) != system_id:
			continue
		var w: SimWorld = worlds[key]
		for team in faction_ids():
			if not w.team_buildings(team, "centre", true).is_empty():
				occupation[team] = true
	if system_id == "sol" and planet_regions != null:
		for regional_world in planet_regions.worlds_in_play():
			var region: SimWorld = regional_world as SimWorld
			for team in faction_ids():
				if not region.team_buildings(team, "centre", true).is_empty():
					occupation[team] = true
	# Un chantier naval orbital achevé est aussi un centre de commandement vivant.
	for team in faction_ids():
		if OrbitalIndustry.has_hub_in_system(self, team, system_id):
			occupation[team] = true
	if occupation.size() > 1: return -2
	if occupation.size() == 1: return int(occupation.keys()[0])
	return -1 # neutre

func system_held(team: int, system_id: String) -> bool:
	## J13-0 : présence d'un commandement vivant du camp, même si le système est contesté.
	## Sol est contesté dès le départ (deux centres) : la défense doit rester délégable.
	if not valid_faction(team):
		return false
	for key in worlds.keys():
		if String(info(String(key)).get("system_id", "")) != system_id:
			continue
		if not (worlds[key] as SimWorld).team_buildings(team, "centre", true).is_empty():
			return true
	if system_id == "sol" and planet_regions != null:
		for regional_world in planet_regions.worlds_in_play():
			if not (regional_world as SimWorld).team_buildings(team, "centre", true).is_empty():
				return true
	return OrbitalIndustry.has_hub_in_system(self, team, system_id)

func system_has_port(team: int, system_id: String) -> bool:
	if not valid_faction(team):
		return false
	if OrbitalIndustry.has_hub_in_system(self, team, system_id):
		return true
	for key in worlds.keys():
		if String(info(String(key)).get("system_id", "")) != system_id:
			continue
		var w: SimWorld = worlds[key]
		for b in w.team_buildings(team, "", true):
			if b.type == "chantier_orbital":
				return true
	if system_id == "sol" and planet_regions != null:
		for regional_world in planet_regions.worlds_in_play():
			var region: SimWorld = regional_world as SimWorld
			for b in region.team_buildings(team, "", true):
				if b.type == "chantier_orbital":
					return true
	return false

func survey_system(team: int, origin: String, target: String) -> Dictionary:
	if star_catalog == null or not valid_faction(team) or eliminated[team] or ages[team] < 10:
		return {"ok": false, "reason": "âge interstellaire X requis"}
	var graph: GalaxyGenerator = star_catalog.galaxy
	if not graph.adjacent(origin, target) or not system_known(team, origin) or system_known(team, target):
		return {"ok": false, "reason": "explorer une étoile inconnue reliée à un système connu"}
	if not system_has_port(team, origin):
		return {"ok": false, "reason": "chantier orbital allié achevé requis dans le système de départ"}
	for probe in survey_probes:
		if int(probe["team"]) == team and String(probe["target"]) == target:
			return {"ok": false, "reason": "sonde déjà en route"}
	var stock: Dictionary = system_resources(team, origin)
	for res in SURVEY_COST.keys():
		if float(stock.get(res, 0.0)) < float(SURVEY_COST[res]):
			return {"ok": false, "reason": "ressources insuffisantes dans le système de lancement"}
	for res in SURVEY_COST.keys():
		stock[res] = float(stock[res]) - float(SURVEY_COST[res])
	var eta: int = SURVEY_BASE_TICKS + int(round(graph.edge_distance(origin, target) * 3.0))
	survey_probes.append({"id": next_probe_id, "team": team, "from": origin, "target": target,
		"eta": eta, "duration": eta})
	next_probe_id += 1
	_notice(team, "Sonde envoyée vers une étoile inconnue", active)
	return {"ok": true, "eta": eta}

func _tick_surveys() -> void:
	for probe in survey_probes.duplicate():
		probe["eta"] = maxi(0, int(probe["eta"]) - 1)
		if int(probe["eta"]) > 0:
			continue
		var team: int = int(probe["team"])
		var target: String = String(probe["target"])
		(discovered_systems[team] as Dictionary)[target] = true
		_record_notice(team, "Exploration achevée : %s" % String(star_catalog.galaxy.systems[target]["label"]), active)
		survey_probes.erase(probe)

static func expected_flight_duration(catalog: StarSystemGenerator, source: String, target: String) -> int:
	var a: Dictionary = catalog.info(source)
	var b: Dictionary = catalog.info(target)
	if a.is_empty() or b.is_empty():
		return -1
	var s1: String = String(a["system_id"])
	var s2: String = String(b["system_id"])
	if s1 == s2:
		return 160
	if not catalog.galaxy.adjacent(s1, s2):
		return -1
	# Compatibilité temporelle avec les vols Sol ↔ Proxima J10.
	if [s1, s2].has("sol") and [s1, s2].has("proxima"):
		return 420
	return 420 + int(round(catalog.galaxy.edge_distance(s1, s2) * 4.0))

func is_unlocked(team: int, key: String) -> bool:
	if evolutions_enabled and valid_faction(team) and String(homes.get(team, "")) == key: return true
	var definition: Dictionary = info(key)
	if definition.is_empty() or not valid_faction(team) or ages[team] < int(definition["age"]):
		return false
	return system_known(team, String(definition["system_id"]))

func switch_to(team: int, key: String) -> bool:
	if not is_unlocked(team, key):
		return false
	if materialize(key) == null:
		return false
	active = key
	return true

func system_resources(team: int, system_id: String) -> Dictionary:
	if evolutions_enabled:
		var home: String = String(homes.get(team, ""))
		if not home.is_empty() and _system_of(home) == system_id and planets.has_colony(team, home): return local_resources(team, home)
		var ids: Array = planets.colonies.keys()
		ids.sort()
		for id in ids:
			var p: Dictionary = planets.colonies[id]
			if int(p["team"]) == team and _system_of(String(p["body"])) == system_id and String(p["status"]) != "lost": return local_resources(team, String(p["body"]))
		return local_resources(team, "depot@" + system_id)
	if not valid_faction(team) or star_catalog == null or not star_catalog.galaxy.systems.has(system_id):
		return {}
	# J1–J11 : l'alias Sol respecte les affectations c.resources[team] des outils de labo.
	system_stocks["sol"] = resources
	if not system_stocks.has(system_id):
		system_stocks[system_id] = [
			{"food": 0.0, "wood": 0.0, "ore": 0.0},
			{"food": 0.0, "wood": 0.0, "ore": 0.0}]
	return (system_stocks[system_id] as Array)[team] as Dictionary

func _system_of(key: String) -> String:
	return String(info(key).get("system_id", ""))

func _sync_all() -> void:
	if evolutions_enabled:
		EvolutionCampaign.sync(self)
		return
	for key in worlds.keys():
		var w: SimWorld = worlds[key]
		if planets.supply_chain and w.supply_gate == null:
			w.supply_gate = ColonyGate.new(self, String(key))
		for team in faction_ids():
			var t: SimWorld.Team = w.teams[team]
			t.res = system_resources(team, _system_of(String(key)))
			t.age = planets.local_age(self, team, String(key))
			t.technologies = technologies[team]
			t.eliminated = eliminated[team]
	if planet_regions != null:
		for region_world in planet_regions.worlds_in_play():
			var w: SimWorld = region_world
			if planets.supply_chain and w.supply_gate == null:
				w.supply_gate = ColonyGate.new(self, "val")
			for team in faction_ids():
				(w.teams[team] as SimWorld.Team).res = system_resources(team, "sol")
				(w.teams[team] as SimWorld.Team).age = ages[team]
				(w.teams[team] as SimWorld.Team).technologies = technologies[team]
				(w.teams[team] as SimWorld.Team).eliminated = eliminated[team]

func step() -> void:
	if evolutions_enabled:
		if not game_over: EvolutionCampaign.step(self)
		return
	if game_over:
		tick += 1
		return
	var order: Array = worlds.keys()
	order.sort()
	for key in worlds.keys():
		var w: SimWorld = worlds[key]
		# 0.20 : ville détaillée à l'écran, abrégée ailleurs ; calculs décalés d'un monde à l'autre.
		w.urban_far = String(key) != String(active)
		w.urban_phase = posmod(order.find(key), 3)
		for team in faction_ids():
			var t: SimWorld.Team = w.teams[team]
			t.res = system_resources(team, _system_of(String(key)))
			t.age = planets.local_age(self, team, String(key))
			t.technologies = technologies[team]
			t.eliminated = eliminated[team]
		# Secteurs proceduraux vides : horloge persistante sans parcours A* inutile.
		# Une unité, une construction ou un balayage réactive immédiatement le tick complet.
		if not SECTORS.has(String(key)) and w.units.is_empty() and w.buildings.is_empty() and w.orbital_scans.is_empty():
			w.tick += 1
		else:
			w.step()
		if key != active:
			# Capturer les alertes AVANT la purge ; aucune double émission dans le secteur.
			for event in w.events:
				if String(event.get("type", "")) in OFFSCREEN_ALERT_TYPES:
					var owner: int = int(event.get("team", -1))
					if owner >= 0 and owner < 2:
						_record_notice(owner, "[%s] %s" % [String(info(key)["label"]), String(event.get("text", "Alerte"))], key)
			w.events.clear()
		if tick % 100 == 0 and w.event_log.size() > 2000:
			w.event_log = w.event_log.slice(-2000)
		for team in faction_ids():
			# J13 : un passage d'âge obtenu sur une colonie reste local à cette colonie.
			planets.note_world_age(self, team, String(key), int((w.teams[team] as SimWorld.Team).age))
			# Le dictionnaire de technologies est partagé, y compris après chargement.
			technologies[team].merge((w.teams[team] as SimWorld.Team).technologies, true)
	if planet_regions != null:
		planet_regions.step_background(self)
	_tick_flights()
	_tick_surveys()
	_tick_freight()
	OrbitalIndustry.step(self)
	planets.step(self)
	OrbitalTactics.step(self)
	if tick % 300 == 0:
		_tick_directives()
	if tick % 10 == 0:
		_ai_expansion()
	if tick % 5 == 0:
		_check_defeat()
	_sync_all()
	tick += 1

func _record_notice(team: int, description: String, key: String, region: String = "") -> void:
	var item := {"tick": tick, "team": team, "text": description, "sector": key, "region": region}
	notices.append(item)
	if notices.size() > 120:
		notices.pop_front()

func _notice(team: int, description: String, key: String = "val") -> void:
	_record_notice(team, description, key)
	# Les stations peuvent exister autour d'une planète non encore matérialisée.
	if worlds.has(key):
		(worlds[key] as SimWorld).emit("strat", team, description)

# ---------------- J12 : transports de ressources multi-sauts / délégation ----------------
func _route_for_supply(team: int, start: String, destination: String) -> Array:
	if not valid_faction(team) or start == destination or not system_known(team, start) or not system_known(team, destination):
		return []
	if not system_has_port(team, start) or system_owner(destination) != team:
		return []
	var queue: Array = [start]
	var previous: Dictionary = {start: ""}
	while not queue.is_empty():
		var current_id: String = String(queue.pop_front())
		if current_id == destination:
			break
		var neighbors: Array = star_catalog.galaxy.neighbors(current_id)
		neighbors.sort()
		for next_value in neighbors:
			var next_id: String = String(next_value)
			if previous.has(next_id) or not system_known(team, next_id):
				continue
			if next_id != destination and (system_owner(next_id) != team or not system_has_port(team, next_id)):
				continue
			previous[next_id] = current_id
			queue.append(next_id)
	if not previous.has(destination):
		return []
	var route: Array = [destination]
	while String(route[0]) != start:
		route.push_front(previous[String(route[0])])
	return route

func _freight_eta(a: String, b: String) -> int:
	return 80 + int(round(star_catalog.galaxy.edge_distance(a, b) * 4.0))

func ship_supplies(team: int, start: String, destination: String, goods: Dictionary) -> Dictionary:
	if not valid_faction(team):
		return {"ok": false, "reason": "camp invalide"}
	if eliminated[team]:
		return {"ok": false, "reason": "camp indisponible"}
	if ages[team] < 10 or freight_orders.size() >= FREIGHT_LIMIT or goods.is_empty():
		return {"ok": false, "reason": "âge X, ressources ou capacité de transport insuffisants"}
	var route: Array = _route_for_supply(team, start, destination)
	if route.size() < 2:
		return {"ok": false, "reason": "route non sécurisée : relais alliés et ports nécessaires"}
	var request: Dictionary = {}
	for raw_key in goods.keys():
		if not raw_key is String or not Rules.RESOURCES.has(String(raw_key)):
			return {"ok": false, "reason": "ressource invalide"}
		var value: Variant = goods[raw_key]
		if not value is int or int(value) < 1 or int(value) > FREIGHT_MAX_UNITS:
			return {"ok": false, "reason": "quantité entière positive requise"}
		request[raw_key] = int(value)
	var stock: Dictionary = system_resources(team, start)
	var cost: Dictionary = request.duplicate(true)
	var orbital_depots: int = OrbitalIndustry.logistics_bonus(self, team, start)
	var fare_per_hop: int = maxi(5, FREIGHT_FARE_FOOD - 5 * orbital_depots)
	cost["food"] = int(cost.get("food", 0)) + (route.size() - 1) * fare_per_hop
	for res in cost.keys():
		if float(stock.get(res, 0.0)) < float(cost[res]):
			return {"ok": false, "reason": "stocks insuffisants dans le système de départ"}
	for res in cost.keys():
		stock[res] = float(stock[res]) - float(cost[res])
	freight_orders.append({"id": next_freight_id, "team": team, "from": start, "to": destination,
		"route": route, "hop": 0, "eta": _freight_eta(start, String(route[1])),
		"goods": request, "holding": false})
	next_freight_id += 1
	_record_notice(team, "Ravitaillement lancé : %s → %s (%d étapes)" % [start, destination, route.size() - 1], active)
	return {"ok": true, "id": next_freight_id - 1, "route": route.duplicate(), "eta": int(freight_orders.back()["eta"])}

func _tick_freight() -> void:
	for freight_value in freight_orders.duplicate():
		var freight: Dictionary = freight_value as Dictionary
		freight["eta"] = maxi(0, int(freight["eta"]) - 1)
		if int(freight["eta"]) > 0:
			continue
		var route: Array = freight["route"] as Array
		var next_hop: int = int(freight["hop"]) + 1
		var target: String = String(route[next_hop])
		var team: int = int(freight["team"])
		# Sans relais opérationnel, le fret attend ; jamais d'apparition instantanée.
		var final_stop: bool = next_hop == route.size() - 1
		var accessible: bool = (system_owner(target) == team) if final_stop else (system_owner(target) == team and system_has_port(team, target))
		if not accessible:
			if not bool(freight.get("holding", false)):
				_record_notice(team, "Fret immobilisé : relais ou colonie perdu(e) dans %s" % target, active)
			freight["holding"] = true
			continue
		freight["holding"] = false
		if final_stop:
			var stock: Dictionary = system_resources(team, target)
			for kind in (freight["goods"] as Dictionary).keys():
				stock[kind] = float(stock.get(kind, 0.0)) + float(freight["goods"][kind])
			freight_orders.erase(freight)
			_record_notice(team, "Ravitaillement livré dans %s" % target, active)
		else:
			freight["hop"] = next_hop
			freight["eta"] = _freight_eta(target, String(route[next_hop + 1]))

func set_system_order(team: int, system_id: String, order: String) -> Dictionary:
	if not valid_faction(team) or order not in ORDER_MODES or not system_known(team, system_id) or eliminated[team]:
		return {"ok": false, "reason": "ordre ou cible non autorisés"}
	var allowed: bool = system_owner(system_id) == team
	if order in ["observe", "defend"] and system_held(team, system_id):
		allowed = true
	if not allowed and not (order == "explore" and system_has_port(team, system_id)):
		return {"ok": false, "reason": "contrôle allié requis"}
	directives["%d:%s" % [team, system_id]] = order
	_record_notice(team, "Directive %s : %s" % [order, system_id], active)
	return {"ok": true}

func _tick_directives() -> void:
	var keys: Array = directives.keys()
	keys.sort()
	for name in keys:
		var parts: PackedStringArray = String(name).split(":")
		if parts.size() != 2:
			continue
		var team: int = int(parts[0])
		var target: String = parts[1]
		if eliminated[team] or not system_known(team, target):
			continue
		match String(directives[name]):
			"defend":
				for world_key in worlds.keys():
					if _system_of(String(world_key)) != target:
						continue
					var w: SimWorld = worlds[world_key]
					var centers: Array = w.team_buildings(team, "centre", true)
					if not centers.is_empty():
						w.issue({"t": "army_defend", "team": team, "pos": (centers[0] as SimWorld.Building).center, "radius": 18.0})
			"explore":
				if ages[team] < 10 or not system_has_port(team, target):
					continue
				var neighbors: Array = star_catalog.galaxy.neighbors(target)
				neighbors.sort()
				for next_id in neighbors:
					if not system_known(team, String(next_id)):
						if bool(survey_system(team, target, String(next_id)).get("ok", false)):
							break
			"supply":
				if target == "sol" or system_owner(target) != team or not system_has_port(team, "sol"):
					continue
				var already: bool = false
				for freight in freight_orders:
					if int(freight["team"]) == team and String(freight["to"]) == target:
						already = true
				if already:
					continue
				var need: Dictionary = {}
				var remote: Dictionary = system_resources(team, target)
				for res in ["food", "wood", "ore"]:
					if float(remote.get(res, 0.0)) < 200.0:
						need[res] = 300
				if not need.is_empty():
					ship_supplies(team, "sol", target, need)

func launch_satellite(team: int, key: String, port_id: int) -> Dictionary:
	if not _authorized_port(team, key, port_id, ["spatioport", "chantier_orbital"]):
		return {"ok": false, "reason": "spatioport ou chantier allié achevé requis"}
	if ages[team] < 9 or tick < int(sat_cooldown[team]) or int(satellites[team]) >= 3:
		return {"ok": false, "reason": "âge IX, recharge ou limite de 3 satellites"}
	var w: SimWorld = worlds[key]
	if not w._can_pay(team, SATELLITE_COST):
		return {"ok": false, "reason": w._missing_text(team, SATELLITE_COST)}
	w._pay(team, SATELLITE_COST)
	satellites[team] = int(satellites[team]) + 1
	sat_cooldown[team] = tick + 400
	_notice(team, "Satellite %d/3 placé en orbite" % int(satellites[team]), key)
	return {"ok": true}

func scan(team: int, key: String, p: Vector2) -> Dictionary:
	var station: Dictionary = OrbitalIndustry.site(self, team, key)
	var sensors: bool = OrbitalIndustry.has_hub(self, team, key) and int((station.get("modules", {}) as Dictionary).get("radar", 0)) > 0
	if not is_unlocked(team, key) or (int(satellites[team]) <= 0 and not sensors):
		return {"ok": false, "reason": "secteur verrouillé, satellite ou radar orbital requis"}
	if tick < int(scan_cooldown[team]):
		return {"ok": false, "reason": "recharge du balayage orbital"}
	if not p.is_finite() or p.x < 0.0 or p.y < 0.0 or p.x >= (worlds[key].map_size if worlds.has(key) else 256 if evolutions_enabled else 96) or p.y >= (worlds[key].map_size if worlds.has(key) else 256 if evolutions_enabled else 96):
		return {"ok": false, "reason": "coordonnées invalides"}
	var w: SimWorld = materialize(key)
	if w == null:
		return {"ok": false, "reason": "monde inaccessible"}
	if not w._can_pay(team, SCAN_COST):
		return {"ok": false, "reason": w._missing_text(team, SCAN_COST)}
	w._pay(team, SCAN_COST)
	w.orbital_scans.append({"team": team, "pos": p, "until": w.tick + 180, "radius": 20.0})
	scan_cooldown[team] = tick + 120
	w.update_fog(true)
	_notice(team, "Balayage orbital actif sur %s (18 s)" % String(info(key)["label"]), key)
	return {"ok": true}

func _authorized_port(team: int, key: String, bid: int, kinds: Array) -> bool:
	if not worlds.has(key) or not valid_faction(team) or eliminated[team]:
		return false
	var w: SimWorld = worlds[key]
	var b: SimWorld.Building = w.buildings.get(bid) as SimWorld.Building
	return b != null and b.team == team and b.complete and kinds.has(b.type)

func shipping_candidates(team: int, source: String, port_id: int, target: String) -> Dictionary:
	if not worlds.has(source) or info(target).is_empty() or source == target:
		return {"ok": false, "reason": "trajet invalide"}
	var interstellar: bool = String(info(source)["system"]) != String(info(target)["system"])
	var kinds: Array = ["chantier_orbital"] if interstellar else ["spatioport", "chantier_orbital"]
	if not _authorized_port(team, source, port_id, kinds):
		return {"ok": false, "reason": "plateforme alliée achevée requise"}
	var w: SimWorld = worlds[source]
	var port: SimWorld.Building = w.buildings[port_id]
	var ships: Array = []
	var cargo: Array = []
	for u in w.team_units(team):
		if u.pos.distance_squared_to(port.center) > 400.0:
			continue
		if u.type == ("fregate" if interstellar else "navette"):
			ships.append({"id": u.id, "type": u.type})
		elif not Rules.unit_has(u.type, "orbital") and u.type != "train":
			cargo.append({"id": u.id, "type": u.type})
	return {"ok": true, "ships": ships, "cargo": cargo}

func dispatch(team: int, source: String, port_id: int, target: String, cargo_ids: Array = [], ship_id: int = -1) -> Dictionary:
	if info(target).is_empty() or not worlds.has(source) or source == target:
		return {"ok": false, "reason": "destination distincte requise"}
	var interstellar: bool = String(info(source)["system"]) != String(info(target)["system"])
	var kinds: Array = ["chantier_orbital"] if interstellar else ["spatioport", "chantier_orbital"]
	if not _authorized_port(team, source, port_id, kinds):
		return {"ok": false, "reason": "plateforme alliée achevée requise"}
	if not is_unlocked(team, target) or (interstellar and ages[team] < 10):
		return {"ok": false, "reason": "âge IX/X requis ou système non exploré"}
	if interstellar and expected_flight_duration(star_catalog, source, target) < 0:
		return {"ok": false, "reason": "aucune route stellaire directe : conquérir un système relais"}
	# J13 : validation unique du verrou orbital, pour le joueur comme pour l'IA.
	var orbital_lock: String = planets.lock_text(self, team, target)
	if evolutions_enabled and not TreatyService.can_land(self, team, target): return {"ok": false, "reason": "Accès militaire non accordé par le traité"}
	if not orbital_lock.is_empty():
		return {"ok": false, "reason": orbital_lock, "reason_code": "orbital_lock"}
	var w: SimWorld = worlds[source]
	var dest: SimWorld = materialize(target)
	if dest == null:
		return {"ok": false, "reason": "monde de destination indisponible"}
	var planet_target: Vector2i = planet_regions.active if planet_regions != null and target == "val" else Vector2i(-1, -1)
	var choices: Dictionary = shipping_candidates(team, source, port_id, target)
	if not bool(choices.get("ok", false)):
		return choices
	var ship: SimWorld.Unit = null
	var cargo: Array = []
	var allowed: Dictionary = {}
	for item in choices["cargo"]:
		allowed[int(item["id"])] = true
	for item in choices["ships"]:
		if ship_id < 0 or int(item["id"]) == ship_id:
			ship = w.units.get(int(item["id"])) as SimWorld.Unit
			break
	if cargo_ids.is_empty() and ship_id < 0:
		# Compatibilité des recettes historiques et du commandement IA.
		for item in choices["cargo"]:
			if cargo.size() >= 6:
				break
			cargo.append(w.units.get(int(item["id"])) as SimWorld.Unit)
	else:
		var unique: Dictionary = {}
		for raw_id in cargo_ids:
			if not raw_id is int:
				return {"ok": false, "reason": "identifiant d'unité invalide"}
			var uid: int = int(raw_id)
			if not allowed.has(uid) or unique.has(uid):
				return {"ok": false, "reason": "cargaison non autorisée"}
			unique[uid] = true
			cargo.append(w.units.get(uid) as SimWorld.Unit)
		if cargo.size() > 6:
			return {"ok": false, "reason": "six unités au maximum"}
	if ship == null:
		return {"ok": false, "reason": "produire une %s près de la plateforme" % ("frégate" if interstellar else "navette")}
	if cargo.is_empty():
		return {"ok": false, "reason": "placer 1 à 6 unités à proximité pour embarquement"}
	var has_center: bool = not dest.team_buildings(team, "centre", true).is_empty()
	if not has_center:
		for flight in flights:
			if int(flight["team"]) == team and String(flight["to"]) == target and bool(flight["colony"]):
				if planet_target.x < 0 or flight.get("planet_to", Vector2i(-1, -1)) == planet_target:
					return {"ok": false, "reason": "fondation déjà en cours : attendre le premier débarquement"}
	var has_builder: bool = false
	for u in cargo:
		if Rules.unit_has(u.type, "builder"):
			has_builder = true
	if not has_center and not has_builder:
		return {"ok": false, "reason": "premier débarquement : un ouvrier requis"}
	if not has_center:
		var newcomers: int = int(Rules.UNITS[ship.type]["pop"])
		for u in cargo:
			newcomers += int(Rules.UNITS[u.type]["pop"])
		var foundation_cap: int = int(Rules.BUILDINGS["centre"].get("pop", 0))
		if dest.teams[team].pop + newcomers > dest.teams[team].pop_cap + foundation_cap:
			return {"ok": false, "reason": "cargaison trop importante pour la première colonie : réduire les troupes"}
	var cost: Dictionary = STAR_TRAVEL_COST.duplicate(true) if interstellar else TRAVEL_COST.duplicate(true)
	if not has_center:
		for r in COLONY_COST:
			cost[r] = int(cost.get(r, 0)) + int(COLONY_COST[r])
	if not w._can_pay(team, cost):
		return {"ok": false, "reason": w._missing_text(team, cost)}
	# Tous les contrôles et la provision de la colonie précèdent le retrait d'unités.
	w._pay(team, cost)
	var units_payload: Array = []
	for u in cargo:
		var data: Dictionary = {"type": u.type, "hp_ratio": u.hp / maxf(1.0, u.max_hp), "supply": u.supply, "evolution": u.evolution}
		if evolutions_enabled:
			data["identity"] = {"army_plan": u.army_plan, "army_origin": u.army_origin, "allegiance": u.allegiance, "home_body": u.home_body, "planet_uid": u.planet_uid, "carry_res": u.carry_res, "carry_amt": u.carry_amt}
		units_payload.append(data)
		w.transfer_out_unit(u)
	w.transfer_out_unit(ship)
	var duration: int = expected_flight_duration(star_catalog, source, target)
	var record: Dictionary = {"id": next_flight, "team": team, "from": source, "to": target,
		"eta": duration, "duration": duration,
		"ship": ship.type, "ship_hp_ratio": ship.hp / maxf(1.0, ship.max_hp), "ship_evolution": ship.evolution, "units": units_payload, "colony": not has_center}
	if planet_regions != null:
		if source == "val":
			record["planet_from"] = planet_regions.active
		if target == "val":
			record["planet_to"] = planet_target
	flights.append(record)
	next_flight += 1
	_notice(team, "%s : expédition vers %s (%d unités)" % [String(Rules.UNITS[ship.type]["label"]), String(info(target)["label"]), cargo.size()], source)
	return {"ok": true}

func _tick_flights() -> void:
	# Chaque vol progresse sur une arête orientée. Collision uniquement quand les
	# deux positions (mesurées dans un même repère) se rencontrent.
	var before: Dictionary = {}
	for flight in flights:
		var duration: int = _flight_duration(flight)
		var old_eta: int = int(flight["eta"])
		before[int(flight["id"])] = clampf(1.0 - float(old_eta) / float(duration), 0.0, 1.0)
		flight["eta"] = maxi(0, old_eta - 1)
	var candidates: Array = flights.duplicate()
	for i in range(candidates.size()):
		var a: Dictionary = candidates[i]
		if not flights.has(a):
			continue
		for j in range(i + 1, candidates.size()):
			var b: Dictionary = candidates[j]
			if not flights.has(b) or not factions.hostile(int(a["team"]), int(b["team"])):
				continue
			var a_start: Dictionary = info(String(a["from"]))
			var a_end: Dictionary = info(String(a["to"]))
			var b_start: Dictionary = info(String(b["from"]))
			var b_end: Dictionary = info(String(b["to"]))
			# Deux vols interstellaires partagent une arête, même s'ils viennent
			# de planètes différentes au sein des systèmes de départ/arrivée.
			var same_edge: bool = String(a_start.get("system_id", "")) != String(a_end.get("system_id", ""))
			if same_edge:
				same_edge = a_start.get("system_id") == b_end.get("system_id") and a_end.get("system_id") == b_start.get("system_id")
			else:
				same_edge = a["from"] == b["to"] and a["to"] == b["from"]
			if not same_edge:
				continue
			var a0: float = float(before.get(int(a["id"]), 0.0))
			var b0: float = 1.0 - float(before.get(int(b["id"]), 0.0))
			var a1: float = 1.0 - float(a["eta"]) / float(_flight_duration(a))
			var b1: float = float(b["eta"]) / float(_flight_duration(b))
			# A va de 0 à 1 ; B de 1 à 0. Aucun combat avant le croisement.
			if a0 > b0 or a1 < b1:
				continue
			var a_power: int = (3 if a["ship"] == "fregate" else 1) + (a["units"] as Array).size()
			var b_power: int = (3 if b["ship"] == "fregate" else 1) + (b["units"] as Array).size()
			if a_power <= b_power:
				flights.erase(a)
				_notice(int(a["team"]), "Convoi perdu en interception à mi-trajet", String(a["from"]))
			if b_power <= a_power:
				flights.erase(b)
				_notice(int(b["team"]), "Convoi perdu en interception à mi-trajet", String(b["from"]))
			break
	for flight in flights.duplicate():
		if int(flight["eta"]) <= 0 and _arrive(flight):
			flights.erase(flight)

func _flight_duration(flight: Dictionary) -> int:
	# Anciens instantanés 0.8.1 : pas de champ duration.
	var from_key: String = String(flight["from"])
	var to_key: String = String(flight["to"])
	var interstellar: bool = String(info(from_key)["system"]) != String(info(to_key)["system"])
	var default_duration: int = 420 if interstellar else 160
	return maxi(1, int(flight.get("duration", default_duration)))

func _landing_cell(w: SimWorld, team: int) -> Vector2i:
	var anchor: Vector2i = WorldLayout.base_cell(w, team) if evolutions_enabled else Vector2i(LANDING[team]) - Vector2i(2, 2)
	for radius in range(0, 27):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var p: Vector2i = anchor + Vector2i(dx, dy)
				if w.footprint_free(p, 4) and w.has_margin(p, 4):
					return p
	return Vector2i(-1, -1)

func _arrive(flight: Dictionary) -> bool:
	var team: int = int(flight["team"])
	var dest_key: String = String(flight["to"])
	var w: SimWorld = worlds[dest_key]
	# J13 : une station reconstruite pendant le vol bloque cette vague ; les troupes déjà au sol restent.
	var orbital_lock: String = planets.lock_text(self, team, dest_key)
	if evolutions_enabled and not TreatyService.can_land(self, team, dest_key): orbital_lock = "Accès diplomatique suspendu"
	if not orbital_lock.is_empty():
		if not bool(flight.get("locked", false)):
			_notice(team, orbital_lock + " · convoi en attente en orbite", dest_key)
		flight["locked"] = true
		return false
	flight.erase("locked")
	var arrival_region: Vector2i = flight.get("planet_to", Vector2i(-1, -1)) as Vector2i
	if dest_key == "val" and planet_regions != null and PlanetRegions.valid(arrival_region):
		w = planet_regions.obtain(arrival_region, bool((worlds["val"] as SimWorld).teams[0].ai_controlled))
	var cells: Vector2i = _landing_cell(w, team)
	if cells.x < 0:
		if not bool(flight.get("holding", false)):
			_notice(team, "Convoi en attente : zone de débarquement encombrée", dest_key)
		flight["holding"] = true
		return false
	var arrival: Vector2 = Vector2(cells) + Vector2(2.0, 5.5)
	if not w.walkable(w.cell_of(arrival)):
		arrival = Vector2(w.nearest_walkable(w.cell_of(arrival), arrival)) + Vector2(0.5, 0.5)
	var founding: bool = bool(flight["colony"]) and w.team_buildings(team, "centre", true).is_empty()
	var extra_capacity: int = int(Rules.BUILDINGS["centre"].get("pop", 0)) if founding else 0
	var incoming_pop: int = int(Rules.UNITS[String(flight["ship"])]["pop"])
	for record in flight["units"]:
		incoming_pop += int(Rules.UNITS[String(record["type"])]["pop"])
	var t: SimWorld.Team = w.teams[team]
	if t.pop + incoming_pop > t.pop_cap + extra_capacity:
		if not bool(flight.get("holding", false)):
			_notice(team, "Convoi en orbite : capacité de population insuffisante", dest_key)
		flight["holding"] = true
		return false
	if founding:
		w.spawn_building(team, "centre", cells, true)
		# J13 : une colonie nouvelle naît à l'âge VII local, quel que soit l'âge de l'empire.
		if not planets.has_colony(team, dest_key):
			planets.found(self, team, dest_key, "conquered" if planets.has_hostile_colony(self, team, dest_key) else "colony", 0)
	var vessel: SimWorld.Unit = w.spawn_unit(team, String(flight["ship"]), arrival + Vector2(2.0, 1.0))
	AgeProgression.apply_unit_level(vessel, int(flight.get("ship_evolution", 1)))
	vessel.hp = maxf(1.0, vessel.max_hp * float(flight["ship_hp_ratio"]))
	for record in flight["units"]:
		var d: Dictionary = record
		var u: SimWorld.Unit = w.spawn_unit(team, String(d["type"]), arrival + Vector2(0.8 * float(w.units.size() % 4), 0.5))
		AgeProgression.apply_unit_level(u, int(d.get("evolution", 1)))
		u.hp = maxf(1.0, u.max_hp * float(d["hp_ratio"]))
		u.supply = clampf(float(d["supply"]), 0.0, 100.0)
		if evolutions_enabled and d.has("identity"):
			SaveGame.restore(u, d["identity"])
		if evolutions_enabled and flight.has("reinforcement_pos") and Rules.unit_has(u.type, "military"):
			u.direct = true
			u.order = {"type": "amove", "pos": flight["reinforcement_pos"]}
		if Rules.unit_has(u.type, "military"):
			w._join_squad(u, null, true)
	w.update_fog(true)
	if bool(t.ai_controlled):
		var already: bool = false
		for ctrl in w.ai_controllers:
			if ctrl.team == team:
				already = true
		if not already:
			w.ai_controllers.append(AiController.new(team))
	var region_suffix: String = " · région %d:%d" % [arrival_region.x, arrival_region.y] if PlanetRegions.valid(arrival_region) else ""
	if PlanetRegions.valid(arrival_region) and dest_key == "val":
		_record_notice(team, "Débarquement réussi sur %s%s" % [String(info(dest_key)["label"]), region_suffix], dest_key, PlanetRegions.key(arrival_region))
		w.emit("strat", team, "Débarquement réussi" + region_suffix)
	else:
		_notice(team, "Débarquement réussi sur %s%s" % [String(info(dest_key)["label"]), region_suffix], dest_key)
	return true

func _ai_expansion() -> void:
	# Ne pas présumer que seul le camp 1 est piloté par l'IA.
	if tick % 300 != 0:
		return
	for team in faction_ids():
		if eliminated[team] or ages[team] < 9:
			continue
		var ai_enabled: bool = false
		for source in worlds.keys():
			if bool(((worlds[source] as SimWorld).teams[team] as SimWorld.Team).ai_controlled):
				ai_enabled = true
		if not ai_enabled:
			continue
		# J13 : un verrou orbital se lève par un siège, jamais par un contournement.
		planets.ai_orbital(self, team)
		var sent: bool = false
		for source in worlds.keys():
			if sent:
				break
			var w: SimWorld = worlds[source]
			for b in w.team_buildings(team, "", true):
				if b.type not in ["spatioport", "chantier_orbital"]:
					continue
				for dest in sector_keys():
					if dest == source or not is_unlocked(team, String(dest)):
						continue
					if expected_flight_duration(star_catalog, String(source), String(dest)) < 0:
						continue
					var dest_world: SimWorld = worlds.get(String(dest)) as SimWorld
					if dest_world == null and system_owner(_system_of(String(dest))) == team:
						continue
					if dest_world == null:
						dest_world = materialize(String(dest))
					if dest_world != null and dest_world.team_buildings(team, "centre", true).is_empty():
						var result: Dictionary = dispatch(team, source, b.id, dest)
						if bool(result["ok"]):
							sent = true
							break
				if sent:
					break
		# L'IA découvre progressivement, au lieu de révéler la galaxie gratuitement.
		if not sent and ages[team] >= 10 and survey_probes.size() < 8:
			var known: Array = (discovered_systems[team] as Dictionary).keys()
			known.sort()
			for origin in known:
				if not system_has_port(team, String(origin)):
					continue
				for neighbor in star_catalog.galaxy.neighbors(String(origin)):
					if not system_known(team, String(neighbor)):
						var scan: Dictionary = survey_system(team, String(origin), String(neighbor))
						if bool(scan.get("ok", false)):
							return

func _check_defeat() -> void:
	for team in faction_ids():
		if eliminated[team]:
			continue
		var centers: bool = false
		var capable: bool = false
		for key in worlds.keys():
			var w: SimWorld = worlds[key]
			if not w.team_buildings(team, "centre", true).is_empty():
				centers = true
			if not w.team_units(team, "builder").is_empty():
				capable = true
		if planet_regions != null:
			for region_world in planet_regions.worlds_in_play():
				var extra: SimWorld = region_world
				if not extra.team_buildings(team, "centre", true).is_empty():
					centers = true
				if not extra.team_units(team, "builder").is_empty():
					capable = true
		# Les bases et drones constructeurs orbitaux ont les mêmes droits de survie
		# que les centres terrestres et leurs ouvriers.
		for body in sector_keys():
			if OrbitalIndustry.has_hub(self, team, String(body)):
				centers = true
			if int((orbital_presence.get(OrbitalIndustry.key(team, String(body)), {}) as Dictionary).get("drone", 0)) > 0:
				capable = true
		for flight in orbital_flights:
			if int(flight["team"]) == team and int((flight["units"] as Dictionary).get("drone", 0)) > 0:
				capable = true
		if planets.has_command(self, team):
			centers = true
		if planets.assembling(team):
			capable = true
		for flight in flights:
			if int(flight["team"]) == team and not capable:
				for item in flight["units"]:
					if Rules.unit_has(String(item["type"]), "builder"):
						capable = true
		if centers:
			lost_centers_at[team] = -1
			continue
		if int(lost_centers_at[team]) < 0:
			lost_centers_at[team] = tick
		var timeout: bool = tick - int(lost_centers_at[team]) > int(Rules.REBUILD_TIMEOUT * Rules.TICK_RATE)
		# Un chantier en cours de montage n'est pas actif mais peut être terminé.
		for site_value in orbital_sites.values():
			var yard: Dictionary = site_value as Dictionary
			if int(yard["team"]) == team and int(yard["remaining"]) > 0:
				capable = true
		if not capable or timeout:
			eliminated[team] = true
			_notice(team, "Défaite : plus de centre et reconstruction impossible", "val")
	if bool(eliminated[0]) or bool(eliminated[1]):
		game_over = true
		winner = -1 if bool(eliminated[0]) and bool(eliminated[1]) else (1 if bool(eliminated[0]) else 0)
		_notice(winner, "Issue de la campagne : %s" % ("égalité" if winner == -1 else "victoire du camp %d" % winner), "val")
		for key in worlds.keys():
			var w: SimWorld = worlds[key]
			w.game_over = true
			w.winner = winner
			w.emit("fin", winner, "Fin de campagne : victoire du camp %d" % winner if winner >= 0 else "Fin de campagne : égalité", {})

func state_hash() -> String:
	if evolutions_enabled: return var_to_bytes(EvolutionSave.snapshot(self)).hex_encode().sha256_text()
	var parts := PackedStringArray([str(tick), str(ages), var_to_str(resources), var_to_str(technologies),
		str(satellites), str(sat_cooldown), str(scan_cooldown), str(eliminated), str(lost_centers_at),
		str(game_over), str(winner), var_to_str(flights), str(next_flight),
		var_to_str(discovered_systems), var_to_str(survey_probes), str(next_probe_id),
		var_to_str(system_stocks), var_to_str(freight_orders), str(next_freight_id), var_to_str(directives),
		var_to_str(orbital_sites), var_to_str(orbital_presence), var_to_str(orbital_flights),
		str(next_orbital_flight), str(orbital_initial_granted), planets.hash_text()])
	if orbital_tactics: parts.append(var_to_str(orbital_maps)); parts.append(str(next_orbit_actor))
	var keys: Array = worlds.keys()
	keys.sort()
	for key in keys:
		parts.append(String(key) + ":" + (worlds[key] as SimWorld).state_hash())
	if planet_regions != null:
		parts.append(str(planet_regions.active))
		var region_keys: Array = planet_regions.regions.keys()
		region_keys.sort()
		for k in region_keys:
			if k != PlanetRegions.key(planet_regions.active):
				parts.append(String(k) + ":" + (planet_regions.regions[k] as SimWorld).state_hash())
		parts.append(var_to_str(planet_regions.crossings))
	return "|".join(parts).sha256_text()


## J12.3 — API de construction et de commandement orbital.
func orbital_shipyard(team: int, body: String) -> Dictionary:
	return OrbitalIndustry.deploy(self, team, body)

func orbital_build(team: int, body: String, module_id: String) -> Dictionary:
	return OrbitalIndustry.start(self, team, body, "module", module_id)

func orbital_train(team: int, body: String, unit_id: String) -> Dictionary:
	return OrbitalIndustry.start(self, team, body, "unit", unit_id)

func orbital_upgrade(team: int, body: String, unit_id: String = "") -> Dictionary:
	return OrbitalIndustry.start(self, team, body, "upgrade_hub" if unit_id.is_empty() else "upgrade_unit", unit_id)

func orbital_send(team: int, source: String, target: String, manifest: Dictionary) -> Dictionary:
	return OrbitalIndustry.send_fleet(self, team, source, target, manifest)


## J13 — API métier unique (joueur, IA, gouverneur, recette). Chaque appel renvoie
## {ok, reason, reason_code, ...} ; un refus n'a aucun effet économique.
func local_age(team: int, body: String) -> int:
	return planets.local_age(self, team, body)

func zone_planet(team: int, body: String, district: int, kind: String, recipe: String = "") -> Dictionary:
	return planets.zone(self, team, body, district, kind, -1.0, recipe)

func build_civic(team: int, body: String, district: int, facility: String) -> Dictionary:
	return planets.build_civic(self, team, body, district, facility)

func build_road(team: int, body: String, district: int) -> Dictionary:
	return planets.build_road(self, team, body, district)

func set_zoning_balance(team: int, body: String, r: float, commerce: float, industry: float) -> Dictionary:
	return planets.set_target(self, team, body, r, commerce, industry)

func set_governor_policy(team: int, body: String, enabled: bool, budget_cap: float = -1.0) -> Dictionary:
	return planets.set_governor(self, team, body, enabled, budget_cap)

func advance_colony_age(team: int, body: String) -> Dictionary:
	return planets.advance_colony_age(self, team, body)

func start_orbital_station(team: int, body: String) -> Dictionary:
	return planets.start_station(self, team, body)

func attack_orbital_station(team: int, body: String) -> Dictionary:
	return planets.attack_station(self, team, body)

func request_hostile_landing(team: int, body: String) -> Dictionary:
	var blocked: String = planets.lock_text(self, team, body)
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked, "reason_code": "orbital_lock"}
	return {"ok": true}

func transfer_materials(team: int, origin: String, destination: String, manifest: Dictionary) -> Dictionary:
	return planets.send_transport(self, team, origin, destination, manifest)

func found_colony(team: int, origin: String, body: String, goods: Dictionary = {}) -> Dictionary:
	return planets.send_transport(self, team, origin, body, {"colonists": J13Rules.COLONY_COLONISTS, "goods": goods, "found": true})

func transfer_credits(team: int, body: String, amount: float) -> Dictionary:
	return planets.transfer_credits(self, team, body, amount)

func enable_supply_chain() -> void:
	## J13.1 : nouvelle partie « économie complète ». Les troupes viennent des habitants et
	## l'industrie équipe troupes et bâtiments. Les mondes fondateurs reçoivent leurs premiers habitants.
	if planets.supply_chain:
		return
	planets.supply_chain = true
	for team in faction_ids():
		var home: Dictionary = planets.colony(team, String(homes.get(team, "val")) if evolutions_enabled else "val")
		if not home.is_empty() and int(home["pop"]) < 12:
			home["pop"] = 12
	_sync_all()

func faction_ids() -> Array:
	return factions.actors() if evolutions_enabled else [0, 1]

func valid_faction(team: int) -> bool:
	return factions.records.has(team) and team != 2 if evolutions_enabled else team in [0, 1]

func ensure_faction(team: int) -> void:
	while resources.size() <= team:
		resources.append({"food": 0.0, "wood": 0.0, "ore": 0.0})
		ages.append(1)
		technologies.append({})
		satellites.append(0)
		sat_cooldown.append(0)
		scan_cooldown.append(0)
		eliminated.append(false)
		lost_centers_at.append(-1)
		discovered_systems.append({})
		orbital_initial_granted.append(false)
	while planets.treasury.size() <= team: planets.treasury.append(PlanetCampaign._new_account())

func local_resources(team: int, body: String) -> Dictionary:
	var id: String = PlanetCampaign.key(team, body)
	if not raw_stocks.has(id): raw_stocks[id] = {"food": 0.0, "wood": 0.0, "ore": 0.0}
	return raw_stocks[id] as Dictionary

func issue_evolution(cmd: Dictionary) -> Dictionary:
	if not evolutions_enabled or not valid_faction(int(cmd.get("team", -1))): return PlanetCampaign.fail("camp", "camp invalide")
	var result: Dictionary
	match String(cmd.get("t", "")):
		"policy", "crisis": result = PoliticalState.issue(self, cmd)
		"diplomacy": result = TreatyService.issue(self, cmd)
		"roads": result = RoadService.issue(self, cmd)
		"reinforcement_mission": result = MilitaryLogistics.issue(self, cmd)
		"civic": result = planets.quick_build(self, int(cmd["team"]), String(cmd.get("body", "")), String(cmd.get("kind", "")), String(cmd.get("recipe", "")))
		"governor_budget":
			var p: Dictionary = planets.colony(int(cmd["team"]), String(cmd.get("body", "")))
			var value: float = float(cmd.get("value", -1))
			if p.is_empty() or not is_finite(value) or value < 0.0 or value > 10000.0: return PlanetCampaign.fail("budget", "plafond invalide")
			p["governor"]["budget_cap"] = value
			result = {"ok": true}
		_: return PlanetCampaign.fail("ordre", "ordre inconnu")
	if bool(result.get("ok", false)):
		command_log.append({"tick": tick, "cmd": cmd.duplicate(true)})
		if command_log.size() > 2048: command_log.pop_front()
	return result

func issue_orbit(cmd: Dictionary) -> Dictionary:
	var result: Dictionary = OrbitalTactics.issue(self, cmd)
	if bool(result.get("ok", false)):
		command_log.append({"tick": tick, "orbit": cmd.duplicate(true)})
		if command_log.size() > 2048: command_log.pop_front()
	return result


func civ_state(team: int) -> Dictionary:
	## 0.16 : un seul état de civilisation par empire, quel que soit le monde où l'on joue.
	if not civ_states.has(team) or not civ_states[team] is Dictionary:
		civ_states[team] = CivEvolution.blank()
	return civ_states[team] as Dictionary
