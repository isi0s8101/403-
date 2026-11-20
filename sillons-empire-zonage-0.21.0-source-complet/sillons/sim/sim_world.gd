class_name SimWorld
extends RefCounted
## Simulation déterministe du jeu, indépendante du rendu et des entrées tactiles.
## Tous les ordres passent par issue() : ils sont validés, appliqués et journalisés (rejeu).

const TEAM_NEUTRAL := 2
const TERRAIN_GRASS := 0
const TERRAIN_WATER := 1
const TERRAIN_FORD := 2

class Unit:
	var id: int
	var team: int
	var type: String
	var pos: Vector2
	var prev_pos: Vector2
	var hp: float
	var max_hp: float
	var path: PackedVector2Array = PackedVector2Array()
	var path_goal: Vector2 = Vector2(-999, -999)
	var path_timer: int = 0
	var path_failed: bool = false
	var waiting_path: bool = false   # en attente de son tour de calcul de chemin (budget par tick)
	var state: String = "idle"
	var order: Dictionary = {}
	var direct: bool = false
	var squad_id: int = -1
	var target_id: int = -1
	var cd: float = 0.0
	var task: String = ""          # food / wood / ore / build / trade
	var node_id: int = -1
	var build_id: int = -1
	var carry_res: String = ""
	var carry_amt: float = 0.0
	var blocked_reason: String = ""
	var facing: float = 0.0
	var attacking_tick: int = -100
	var hit_tick: int = -100
	var trade_leg: int = 0         # 0 = vers relais, 1 = retour
	var trade_relais: int = -1
	var deploy: float = 0.0        # artillerie : temps de mise en batterie accumulé
	var supply: float = 100.0
	var rail_a: int = -1
	var rail_b: int = -1
	var goal_key: int = -1
	var goal_pos: Vector2 = Vector2(-1, -1)
	var goal_tick: int = -1000
	var planet_uid: int = 0  # Identité permanente même si l’ID tactique change de région.
	var evolution: int = 1 # Niveau d'équipement et silhouette individuelle, 1..3.
	var allegiance: String = "regular"
	var home_body: String = ""
	var rally_contract: Dictionary = {}
	var order_steps: Array = []
	var order_step: int = 0
	var step_since: int = 0
	var army_plan: int = -1
	var wave_pending: bool = false
	var army_origin: String = ""
	var origin_building: int = -1 # Producteur : upgrades de CET établissement uniquement.
	# 0.17 : commandement (UnitCommands, OrderQueue) — posture, garnison, files de groupe, ordres manuels aux ouvriers.
	var stance: String = ""
	var target_pref: String = ""
	var manual: bool = false
	var garrison_id: int = -1
	var order_loop: bool = false
	var order_group: int = 0
	var order_offset: Vector2 = Vector2.ZERO
	var step_arrived: int = -1

class Building:
	var id: int
	var team: int
	var type: String
	var cell: Vector2i
	var size: int
	var center: Vector2
	var hp: float
	var max_hp: float
	var complete: bool = false
	var progress: float = 0.0
	var queue: Array = []
	var prod_timer: float = 0.0
	var prod_blocked: String = ""
	var cd: float = 0.0
	var rally: Vector2
	var farmer: int = -1
	var hit_tick: int = -100
	var rally_revision: int = 0
	var rally_contract: Dictionary = {}
	var army_plan: int = -1
	var forming_squad: int = -1
	var tier: int = 1 # Stade architectural, conservé dans les sauvegardes.
	var unit_evolutions: Dictionary = {} # Par type de troupe, niveau acquis dans CE bâtiment.
	var upgrade_job: Dictionary = {} # Recherche locale par bâtiment, 1 à la fois.
	var repeat_unit: String = ""     # 0.17 : production répétée (UnitCommands)
	var rally_node: int = -1         # 0.17 : ralliement des ouvriers sur une ressource
	var city: Dictionary = {}        # 0.18 : état urbain (UrbanCity)

class ResNode:
	var id: int
	var kind: String
	var res: String
	var pos: Vector2
	var amount: float
	var max_amount: float
	var cell: Vector2i

class Squad:
	var id: int
	var team: int
	var number: int
	var units: Array = []
	var order: Dictionary = {}
	var direct: bool = false
	var army_role: String = ""
	var army_target: Vector2 = Vector2.ZERO
	var formation: String = ""       # 0.17 : "" (bloc) | line | column | box | spread
	var facing: Vector2 = Vector2.ZERO
	var stance: String = ""
	var target_pref: String = ""

class Team:
	var id: int
	var name: String
	var res: Dictionary = {"food": 0.0, "wood": 0.0, "ore": 0.0}
	var age: int = 1
	var priorities: Dictionary = {"food": 2, "wood": 2, "ore": 1}
	var pop: int = 0
	var pop_cap: int = 0
	var eliminated: bool = false
	var fog: PackedByteArray = PackedByteArray()   # 0 inconnu, 1 exploré, 2 visible
	var visible_cells: PackedInt32Array = PackedInt32Array()
	var visibility_ready: bool = false
	var memory: Dictionary = {}                     # id bâtiment -> {type, team, pos, tick}
	var discovered_posts: Array = []
	var unreachable: Dictionary = {}                # id gisement -> tick de constat
	var res_access: Dictionary = {"food": true, "wood": true, "ore": true}
	var research: Dictionary = {}                   # {"to": 2, "remaining": s, "total": s}
	var trade_res: String = "food"
	var exchange_rate: float = 0.8
	var army: Dictionary = {}                       # tâche déléguée : {"type":"defend","pos":V2,"radius":r}
	var squad_counter: int = 0
	var stats: Dictionary = {"gathered": {"food": 0.0, "wood": 0.0, "ore": 0.0}, "trade": 0.0, "kills": 0, "losses": 0,
		"units_trained": 0, "spent": 0.0}
	var ai_controlled: bool = false
	var opening: String = ""
	var technologies: Dictionary = {}
	var tech_research: Dictionary = {}
	var no_cc_since: int = -1
	var civ: Dictionary = {}                        # 0.16 : état d'évolution de la civilisation (CivEvolution)
	var city: Dictionary = {}                       # 0.18 : bilan de la ville (UrbanCity)
	var zoning: Dictionary = {}                     # 0.19 : zones peintes et routes (UrbanZoning)

var modern: Dictionary = {"missiles": [], "rail_links": [], "connected": []}
var orbital_scans: Array = []   # visibilités temporaires par théâtre, sérialisées

var map_size: int = 96
var factions: FactionRegistry = FactionRegistry.new()
var labor_factors: Dictionary = {}
var navigation_quota: int = -1
var army_plans: Dictionary = {}
var next_plan_id: int = 1
var external_plan_counts: Dictionary = {}
var rally_notices: Dictionary = {}
var _track_visibility: bool = false
var _revealed_cells: PackedInt32Array = PackedInt32Array()
var tick: int = 0
var seed_value: int = 1
var rng := RandomNumberGenerator.new()
var terrain := PackedByteArray()
var astar := AStarGrid2D.new()
var astar_terrain := AStarGrid2D.new()   # eau seule : sert à repérer les structures qui bloquent un passage
var units: Dictionary = {}
var buildings: Dictionary = {}
var nodes: Dictionary = {}
var squads: Dictionary = {}
var teams: Array = []
var next_id: int = 1
var events: Array = []          # événements non consommés par la vue
var event_log: Array = []       # journal complet (laboratoire)
var replay: Array = []          # ordres journalisés {tick, cmd}
var winner: int = -1
var game_over: bool = false
var rules := {}                 # surcharges de règles (laboratoire)
var ai_controllers: Array = []
var log_events := true
## Recherches de chemin A* autorisées par tick (lisse les pics d'un ordre de masse). PROVISOIRE.
const PATH_BUDGET := 24
var _paths_left := PATH_BUDGET
var _occupied := {}             # case -> id bâtiment
var _node_cells := {}           # cases portant un gisement non épuisé
var urban_roads := PackedByteArray()  # 0.19 : routes de tous les camps (dérivé des Team.zoning, non sauvegardé)
var urban_far := false   # 0.20 : monde hors de l'écran du joueur (calcul abrégé de la ville) ; fixé à chaque tick par la campagne
var urban_phase := 0     # 0.20 : décalage du calcul de la ville selon le monde (0 à 2), fixé à chaque tick par la campagne

# ---------------------------------------------------------------- initialisation

## J13.1 : passerelle vers l'économie planétaire (objet non sauvegardé, posé par la campagne).
var supply_gate: RefCounted = null
## 0.16 : caches de CivEvolution (modificateurs, auras de héros), recalculés, jamais sauvegardés.
var civ_cache: Dictionary = {}
## 0.21 : « carte explorée » appliquée une fois par session (non sauvegardé : le brouillard l'est).
var _map_revealed: bool = false

func setup(p_seed: int, overrides: Dictionary = {}) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	rules = overrides.duplicate(true)
	map_size = int(rules.get("map_size", 96))
	if not WorldLayout.PROFILES.has(map_size): map_size = 96
	if bool(rules.get("planet_region_grid", false)):
		var age_iii: Dictionary = Rules.AGE_UP[3].duplicate(true)
		age_iii["objective"] = "tenir_frontiere"
		rules["age_up_3"] = age_iii
	terrain.resize(map_size * map_size)
	astar.region = Rect2i(0, 0, map_size, map_size)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar_terrain.region = astar.region
	astar_terrain.cell_size = Vector2(1, 1)
	astar_terrain.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar_terrain.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_terrain.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_terrain.update()
	for i in 3:
		var t := Team.new()
		t.id = i
		t.name = ["Joueur", "Adversaire", "Neutre"][i]
		t.fog.resize(map_size * map_size)
		t.fog.fill(0)
		t.exchange_rate = Rules.EXCHANGE_START_RATE
		teams.append(t)
	SimMap.generate(self)
	# J9 est activé explicitement ; les parties et recettes historiques restent inchangées.
	if bool(rules.get("planet_j9", false)) and not bool(rules.get("planet_region_grid", false)):
		var atlas := PlanetGenerator.new(int(rules.get("planet_master_seed", p_seed)))
		atlas.tactical_decorate(self, float(rules.get("planet_lon", 0.0)), float(rules.get("planet_lat", 0.0)))

func rule(key: String, default_value):
	return rules.get(key, default_value)

func start_standard() -> void:
	## Partie normale : centre, ouvriers, éclaireur pour chaque camp.
	var bases := [WorldLayout.base_cell(self,0), WorldLayout.base_cell(self,1)]
	for team_id in 2:
		if rules.has("home_team") and int(rules["home_team"]) != team_id: continue
		var t: Team = teams[team_id]
		var st: Dictionary = rule("start", Rules.START)
		if team_id == 1 and rules.has("start_ai"):
			st = rules["start_ai"] as Dictionary
		for r in Rules.RESOURCES:
			t.res[r] = float(st["res"].get(r, 0))
		var cc := spawn_building(team_id, "centre", bases[team_id], true)
		for i in int(st["workers"]):
			var w := spawn_unit(team_id, "ouvrier", cc.center + Vector2(-2.5 + i * 1.2, 3.2 if team_id == 0 else -3.2))
			w.task = ""
		for i in int(st["scouts"]):
			spawn_unit(team_id, "eclaireur", cc.center + Vector2(3.2, 0 if team_id == 0 else 0) * (1 if team_id == 0 else -1))
	update_fog(true)

# ---------------------------------------------------------------- utilitaires grille

func idx(c: Vector2i) -> int:
	return c.y * map_size + c.x

func in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < map_size and c.y < map_size

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x)), 0, map_size - 1), clampi(int(floor(p.y)), 0, map_size - 1))

func walkable(c: Vector2i) -> bool:
	return in_map(c) and not astar.is_point_solid(c)

func set_terrain(c: Vector2i, v: int) -> void:
	terrain[idx(c)] = v
	astar.set_point_solid(c, v == TERRAIN_WATER)
	astar_terrain.set_point_solid(c, v == TERRAIN_WATER)

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := cell_of(from)
	var b := cell_of(to)
	if not walkable(a):
		a = nearest_walkable(a, from)
	if not walkable(b):
		return PackedVector2Array()
	var ids := astar.get_id_path(a, b)
	var out := PackedVector2Array()
	if ids.is_empty():
		return out
	for i in range(1, ids.size()):
		out.append(Vector2(ids[i].x + 0.5, ids[i].y + 0.5))
	out.append(to)
	return out

func nearest_walkable(c: Vector2i, near: Vector2) -> Vector2i:
	var best := c
	var bd := INF
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if walkable(n):
					var d := near.distance_squared_to(Vector2(n) + Vector2(0.5, 0.5))
					if d < bd:
						bd = d
						best = n
		if bd < INF:
			return best
	return best

func approach_point(from: Vector2, center: Vector2, radius: float) -> Vector2:
	## Case libre autour d'une cible (bâtiment, gisement), la plus proche de l'unité.
	var cands := []
	var r := int(ceil(radius)) + 1
	var cc := cell_of(center)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var n := cc + Vector2i(dx, dy)
			if walkable(n):
				var p := Vector2(n) + Vector2(0.5, 0.5)
				var dc := p.distance_to(center)
				if dc <= radius + 0.75:
					cands.append([p.distance_squared_to(from), p])
	if cands.is_empty():
		return Vector2(-1, -1)
	cands.sort_custom(func(a, b): return a[0] < b[0])
	return cands[0][1]

func goal_for(u: Unit, key: int, center: Vector2, radius: float) -> Vector2:
	## Point d'approche mis en cache par unité (recalculé si la cible change ou toutes les 5 s).
	if u.goal_key != key or tick - u.goal_tick > 50 or u.goal_pos.x < 0:
		u.goal_key = key
		u.goal_tick = tick
		u.goal_pos = approach_point(u.pos, center, radius)
	return u.goal_pos

func reachable(from: Vector2, center: Vector2, radius: float) -> bool:
	var p := approach_point(from, center, radius)
	if p.x < 0:
		return false
	if cell_of(from) == cell_of(p):
		return true
	return find_path(from, p).size() > 0

# ---------------------------------------------------------------- création d'entités

func new_id() -> int:
	next_id += 1
	return next_id - 1

func add_node(kind: String, p: Vector2, amount: float) -> ResNode:
	var n := ResNode.new()
	n.id = new_id()
	n.kind = kind
	n.res = Rules.NODE_RES[kind]
	n.pos = p
	n.amount = amount
	n.max_amount = amount
	n.cell = cell_of(p)
	nodes[n.id] = n
	_node_cells[n.cell] = n.id
	return n

func spawn_unit(team_id: int, type: String, p: Vector2) -> Unit:
	var u := Unit.new()
	u.id = new_id()
	u.team = team_id
	u.type = type
	var c := cell_of(p)
	if not walkable(c):
		c = nearest_walkable(c, p)
		p = Vector2(c) + Vector2(0.5, 0.5)
	u.pos = p
	u.prev_pos = p
	u.max_hp = float(Rules.UNITS[type]["hp"])
	u.hp = u.max_hp
	units[u.id] = u
	teams[team_id].pop += int(Rules.UNITS[type]["pop"])
	_ugrid_add(u)
	return u

## Grille spatiale des unités, reconstruite à chaque tick : sert à élaguer la recherche de cibles.
## Les positions bougent d'au plus ~0,45 case pendant un tick : la requête prend une marge de 1 case,
## puis la distance exacte est calculée sur la position courante. Résultat identique à un parcours complet
## (à distance égale, le plus petit id l'emporte, comme dans l'ordre d'insertion).
const UGRID := 8.0
var _ugrid := {}

func _ugrid_add(u: Unit) -> void:
	var k := Vector2i(int(u.pos.x / UGRID), int(u.pos.y / UGRID))
	var cell = _ugrid.get(k)
	if cell == null:
		_ugrid[k] = [u]
	else:
		cell.append(u)

func _rebuild_ugrid() -> void:
	_ugrid.clear()
	for u in units.values():
		if u.garrison_id == -1:
			_ugrid_add(u)

func footprint_free(cell: Vector2i, size: int, allow_ford: bool = false) -> bool:
	for dy in size:
		for dx in size:
			var c := cell + Vector2i(dx, dy)
			if not in_map(c):
				return false
			var t := terrain[idx(c)]
			if not (t == TERRAIN_GRASS or (allow_ford and t == TERRAIN_FORD)):
				return false
			if _occupied.has(c) or (_node_cells.has(c) and nodes[_node_cells[c]].amount > 0.0):
				return false
			if not urban_roads.is_empty() and urban_roads[idx(c)] != 0: return false # 0.19 : on ne bâtit pas sur une route
	return true

func has_margin(cell: Vector2i, size: int, margin: int = 1) -> bool:
	## Vrai si aucune case autour de l'emprise n'est occupée par un bâtiment (laisse des passages).
	for dy in range(-margin, size + margin):
		for dx in range(-margin, size + margin):
			var c := cell + Vector2i(dx, dy)
			if _occupied.has(c):
				return false
	return true

func spawn_building(team_id: int, type: String, cell: Vector2i, complete: bool) -> Building:
	var b := Building.new()
	b.id = new_id()
	b.team = team_id
	b.type = type
	b.cell = cell
	b.size = int(Rules.BUILDINGS[type]["size"])
	b.center = Vector2(cell) + Vector2(b.size, b.size) * 0.5
	b.max_hp = float(Rules.BUILDINGS[type]["hp"])
	b.complete = complete
	b.progress = 1.0 if complete else 0.0
	b.hp = b.max_hp if complete else max(1.0, b.max_hp * 0.1)
	b.rally = b.center + Vector2(0, b.size * 0.5 + 2.0) * (1 if team_id != 1 else -1)
	buildings[b.id] = b
	for dy in b.size:
		for dx in b.size:
			var c := cell + Vector2i(dx, dy)
			_occupied[c] = b.id
			astar.set_point_solid(c, true)
	if complete and team_id < TEAM_NEUTRAL:
		teams[team_id].pop_cap += int(Rules.BUILDINGS[type].get("pop", 0))
	return b

# ---------------------------------------------------------------- requêtes

func team_units(team_id: int, tag: String = "") -> Array:
	var out := []
	for u in units.values():
		if u.team == team_id and (tag == "" or Rules.unit_has(u.type, tag)):
			out.append(u)
	return out

func team_buildings(team_id: int, type: String = "", only_complete: bool = false) -> Array:
	var out := []
	for b in buildings.values():
		if b.team == team_id and (type == "" or b.type == type) and (not only_complete or b.complete):
			out.append(b)
	return out

func team_squads(team_id: int) -> Array:
	var out := []
	for s in squads.values():
		if s.team == team_id:
			out.append(s)
	return out

func entity(eid: int):
	if units.has(eid):
		return units[eid]
	if buildings.has(eid):
		return buildings[eid]
	return null

func entity_pos(e) -> Vector2:
	return e.pos if e is Unit else e.center

func is_visible_to(team_id: int, p: Vector2) -> bool:
	return teams[team_id].fog[idx(cell_of(p))] == 2

func is_explored_by(team_id: int, p: Vector2) -> bool:
	return teams[team_id].fog[idx(cell_of(p))] >= 1

func enemies_of(team_id: int) -> Array:
	return factions.enemies(team_id)

# ---------------------------------------------------------------- événements

func emit(type: String, team_id: int, text: String, extra: Dictionary = {}) -> void:
	var e := {"tick": tick, "type": type, "team": team_id, "text": text}
	e.merge(extra)
	events.append(e)
	if log_events:
		event_log.append(e)

# ---------------------------------------------------------------- ordres

func issue(cmd: Dictionary) -> Dictionary:
	var res := _apply(cmd)
	var recorded: Dictionary = cmd.duplicate(true) if EvolutionSave._plain(cmd) else {"t": String(cmd.get("t", "invalid")), "team": int(cmd.get("team", 0)), "rejected_payload": true}
	replay.append({"tick": tick, "cmd": recorded, "ok": res["ok"], "reason": res.get("reason", "")})
	if not res["ok"]:
		emit("refus", int(cmd.get("team", 0)), "Ordre refusé : " + res["reason"], {"cmd": cmd.get("t", "")})
	return res

func _ok() -> Dictionary:
	return {"ok": true}

func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _v2(a) -> Vector2:
	if a is Vector2:
		return a
	return Vector2(float(a[0]), float(a[1]))

func _apply(cmd: Dictionary) -> Dictionary:
	var team_id := int(cmd.get("team", 0))
	if team_id < 0 or team_id >= teams.size() or team_id == TEAM_NEUTRAL:
		return _no("camp invalide")
	if teams[team_id].eliminated:
		return _no("camp éliminé")
	if String(cmd.get("t", "")) in ["upgrade_building", "upgrade_troop"]:
		return AgeProgression.start_upgrade(self, team_id, cmd)
	if String(cmd.get("t", "")) in ["technology", "missile"]:
		return ModernSystems.command(self, team_id, cmd)
	if String(cmd.get("t", "")).begins_with("civ_"):
		return CivEvolution.command(self, team_id, cmd)
	if UnitCommands.handles(String(cmd.get("t", ""))):
		return UnitCommands.command(self, team_id, cmd)
	if UrbanCity.handles(String(cmd.get("t", ""))): return UrbanCity.command(self, team_id, cmd)
	match String(cmd.get("t", "")):
		"move", "attack", "amove":
			return _cmd_move_attack(team_id, cmd)
		"take_unit":
			var u = units.get(int(cmd["unit"]))
			if u == null or u.team != team_id:
				return _no("unité introuvable")
			u.direct = true
			u.order = {"type": "hold", "pos": u.pos}
			u.task = "" if Rules.unit_has(u.type, "worker") else u.task
			u.blocked_reason = ""
			emit("controle", team_id, "%s #%d : contrôle direct" % [Rules.UNITS[u.type]["label"], u.id], {"unit": u.id})
			return _ok()
		"release_unit":
			var u = units.get(int(cmd["unit"]))
			if u == null or u.team != team_id:
				return _no("unité introuvable")
			u.direct = false
			u.order = {}
			u.target_id = -1
			u.manual = false
			emit("controle", team_id, "%s #%d rendue à son escouade" % [Rules.UNITS[u.type]["label"], u.id], {"unit": u.id})
			return _ok()
		"release_squad":
			var s = squads.get(int(cmd["squad"]))
			if s == null or s.team != team_id:
				return _no("escouade introuvable")
			s.direct = false
			s.order = {}
			emit("controle", team_id, "Escouade %d rendue à l'armée" % s.number, {"squad": s.id})
			return _ok()
		"army_defend":
			var p := _v2(cmd["pos"])
			if not is_explored_by(team_id, p):
				return _no("secteur inexploré")
			teams[team_id].army = {"type": "defend", "pos": p, "radius": float(cmd.get("radius", 12.0))}
			emit("armee", team_id, "Armée : défense du secteur déléguée", {"pos": p})
			return _ok()
		"army_cancel":
			teams[team_id].army = {}
			for s in team_squads(team_id):
				if not s.direct:
					s.order = {"type": "hold", "pos": _squad_center(s)}
					s.army_role = ""
			return _ok()
		"set_priority":
			var r := String(cmd["res"])
			if not Rules.RESOURCES.has(r):
				return _no("ressource inconnue")
			teams[team_id].priorities[r] = clampi(int(cmd["value"]), 0, 3)
			emit("priorite", team_id, "Priorité %s : %d" % [Rules.RES_LABEL[r], teams[team_id].priorities[r]])
			return _ok()
		"build":
			return _cmd_build(team_id, String(cmd["type"]), Vector2i(int(cmd["cell"][0]), int(cmd["cell"][1])))
		"train":
			return _cmd_train(team_id, int(cmd["building"]), String(cmd["unit"]))
		"cancel_train":
			var b = buildings.get(int(cmd["building"]))
			if b == null or b.team != team_id or b.queue.is_empty():
				return _no("file vide")
			var ut: String = b.queue.pop_back()
			_refund(team_id, Rules.UNITS[ut]["cost"])
			CivEvolution.on_train_cancelled(self, team_id, ut)
			if b.queue.is_empty():
				b.prod_timer = 0.0
			return _ok()
		"age_up":
			return _cmd_age_up(team_id)
		"exchange":
			return _cmd_exchange(team_id, String(cmd["sell"]), String(cmd["buy"]))
		"trade_res":
			teams[team_id].trade_res = String(cmd["res"])
			return _ok()
		"rally", "rally_group":
			return RallyService.issue(self, cmd)
		"army_plan", "queue_orders", "plan_toggle":
			return ArmyPlans.issue(self, cmd)
		"lab_spawn":
			var u := spawn_unit(team_id, String(cmd["unit"]), _v2(cmd["pos"]))
			if Rules.unit_has(u.type, "military"):
				_join_squad(u, null, bool(cmd.get("new_squad", false)))
			return {"ok": true, "id": u.id}
		"lab_building":
			var c := Vector2i(int(cmd["cell"][0]), int(cmd["cell"][1]))
			if not footprint_free(c, int(Rules.BUILDINGS[String(cmd["type"])]["size"]), bool(Rules.BUILDINGS[String(cmd["type"])].get("on_ford_ok", false))):
				return _no("emplacement occupé")
			var b := spawn_building(team_id, String(cmd["type"]), c, bool(cmd.get("complete", true)))
			return {"ok": true, "id": b.id}
		"lab_res":
			for r in cmd["res"].keys():
				teams[team_id].res[r] = float(cmd["res"][r])
			return _ok()
		"lab_age":
			teams[team_id].age = int(cmd["age"])
			return _ok()
		"lab_kill":
			var e = entity(int(cmd["id"]))
			if e == null:
				return _no("entité introuvable")
			if e is Unit:
				_kill_unit(e, -1)
			else:
				_destroy_building(e, -1)
			return _ok()
		"lab_kill_type":
			for u in team_units(team_id):
				if u.type == String(cmd["unit"]):
					_kill_unit(u, -1)
			return _ok()
		"lab_deplete":
			var n = nodes.get(int(cmd["id"]))
			if n != null:
				n.amount = float(cmd.get("amount", 0.0))
			return _ok()
		"lab_urban_event":
			## Recette : déclenche un événement urbain (mêmes effets que le tirage de la simulation).
			if not UrbanEvents.EVENTS.has(String(cmd.get("event", ""))):
				return _no("événement inconnu")
			var at: Array = cmd.get("at", [-1, -1]) as Array
			var report: Dictionary = UrbanEvents.start(self, team_id, String(cmd["event"]), Vector2i(int(at[0]), int(at[1])))
			return {"ok": true, "report": report}
		"lab_reveal":
			var t: Team = teams[team_id]
			for i in t.fog.size():
				t.fog[i] = max(t.fog[i], 1)
			return _ok()
		"lab_block_ford":
			## Par défaut : une ligne de palissades dans l'axe de la rivière (x == y), qui suffit à fermer
			## le gué ; "full": true remplit tout le gué (verrou épais).
			var f: Vector2 = WorldLayout.fords(self)[int(cmd["ford"])]
			var full := bool(cmd.get("full", false))
			var n := 0
			for dy in range(-5, 6):
				for dx in range(-5, 6):
					var c := cell_of(f) + Vector2i(dx, dy)
					if not full and c.x != c.y:
						continue
					if in_map(c) and terrain[idx(c)] == TERRAIN_FORD and not _occupied.has(c):
						spawn_building(team_id, "palissade", c, true)
						n += 1
			return {"ok": true, "count": n}
		"lab_opening":
			teams[team_id].opening = String(cmd["opening"])
			return _ok()
	return _no("ordre inconnu")

func _cmd_move_attack(team_id: int, cmd: Dictionary) -> Dictionary:
	var target_id := int(cmd.get("target", -1))
	var commanded: Array = []
	if cmd.has("squad") and squads.has(int(cmd["squad"])):
		commanded = _squad_members(squads[int(cmd["squad"])])
	else:
		for id in cmd.get("units", []):
			if units.has(int(id)):
				commanded.append(units[int(id)])
	var all_air: bool = not commanded.is_empty()
	for selected in commanded:
		all_air = all_air and Rules.unit_has(selected.type, "air")
	var order := {}
	if cmd["t"] == "attack":
		var tgt = entity(target_id)
		if tgt == null:
			return _no("cible introuvable")
		if not factions.hostile(team_id, tgt.team):
			return _no("cible non hostile")
		if not is_visible_to(team_id, entity_pos(tgt)):
			return _no("cible hors de vue")
		order = {"type": "attack", "target": target_id}
	else:
		var p := _v2(cmd["pos"])
		if not p.is_finite() or p.x < 0 or p.y < 0 or p.x >= map_size or p.y >= map_size:
			return _no("destination hors carte")
		if not all_air and not walkable(cell_of(p)):
			var c := cell_of(p)
			if in_map(c) and _occupied.has(c):
				var nb := nearest_walkable(c, p)
				p = Vector2(nb) + Vector2(0.5, 0.5)
			else:
				return _no("destination infranchissable (eau)")
		order = {"type": "amove" if cmd["t"] == "amove" else "move", "pos": p}
	if cmd.has("squad"):
		var s = squads.get(int(cmd["squad"]))
		if s == null or s.team != team_id:
			return _no("escouade introuvable")
		if order["type"] != "attack" and _squad_members(s).size() > 0:
			var ref: Unit = _squad_members(s)[0]
			if not all_air and find_path(ref.pos, order["pos"]).is_empty() and cell_of(ref.pos) != cell_of(order["pos"]):
				return _no("aucun chemin vers la destination")
		for member in _squad_members(s):
			member.rally_contract = {}
			member.order_steps = []
			member.direct = false
			UnitCommands.leave_garrison(self, member)
		UnitCommands.on_squad_order(self, s, order)
		s.order = order
		s.direct = true
		s.army_role = "Ordre direct"
		for u in _squad_members(s):
			if not u.direct:
				u.target_id = -1
				u.path_goal = Vector2(-999, -999)
		return _ok()
	var ids: Array = cmd.get("units", [])
	if ids.is_empty():
		return _no("aucune unité sélectionnée")
	var accepted := 0
	for i in ids:
		var u = units.get(int(i))
		if u == null or u.team != team_id:
			continue
		if order["type"] == "attack" and Rules.UNITS[u.type]["atk"] <= 0.0:
			continue
		if order["type"] == "attack" and not ModernSystems.can_target(u, entity(target_id)):
			continue
		if u.type == "train":
			continue
		if order["type"] != "attack" and not Rules.unit_has(u.type, "air") and find_path(u.pos, order["pos"]).is_empty() and cell_of(u.pos) != cell_of(order["pos"]):
			continue
		u.rally_contract = {}
		u.order_steps = []
		u.direct = true
		UnitCommands.leave_garrison(self, u)
		u.order = order.duplicate()
		u.target_id = -1
		u.path_goal = Vector2(-999, -999)
		if Rules.unit_has(u.type, "worker"):
			_release_worker_job(u)
			u.task = ""
		accepted += 1
	if accepted == 0:
		return _no("aucune unité ne peut exécuter cet ordre (chemin ou capacité)")
	return _ok()

func _can_pay(team_id: int, cost: Dictionary) -> bool:
	for r in cost.keys():
		if teams[team_id].res.get(r, 0.0) < float(cost[r]) - 0.001:
			return false
	return true

func _missing_text(team_id: int, cost: Dictionary) -> String:
	var parts := []
	for r in Rules.RESOURCES:
		var need = float(cost.get(r, 0)) - teams[team_id].res[r]
		if need > 0.001:
			parts.append("%d %s" % [ceili(need), Rules.RES_LABEL[r].to_lower()])
	return "manque " + ", ".join(parts)

func _pay(team_id: int, cost: Dictionary) -> void:
	for r in cost.keys():
		teams[team_id].res[r] -= float(cost[r])
		teams[team_id].stats["spent"] += float(cost[r])

func _refund(team_id: int, cost: Dictionary) -> void:
	for r in cost.keys():
		teams[team_id].res[r] += float(cost[r])

func scaled_cost(cost: Dictionary) -> Dictionary:
	var m: float = rule("cost_mult", 1.0)
	var out := {}
	for k in cost.keys():
		out[k] = float(cost[k]) * m
	return out

func build_check(team_id: int, type: String, cell: Vector2i) -> String:
	if not Rules.BUILDINGS.has(type) or Rules.BUILDINGS[type].get("neutral", false):
		return "bâtiment inconnu"
	var def: Dictionary = Rules.BUILDINGS[type]
	if teams[team_id].age < int(def["age"]):
		return "nécessite l'âge %s" % Rules.AGES[int(def["age"]) - 1]["name"]
	var urban_lack: String = UrbanCity.build_lack(self, team_id, type, cell)
	if urban_lack != "": return urban_lack
	var size := int(def["size"])
	if not footprint_free(cell, size, bool(def.get("on_ford_ok", false))):
		return "emplacement occupé ou sur l'eau" + ("" if def.get("on_ford_ok", false) else " (seuls palissades et forts se posent sur un gué)")
	var center := Vector2(cell) + Vector2(size, size) * 0.5
	if not is_explored_by(team_id, center):
		return "zone inexplorée"
	if def.get("on_post", false):
		var post = _post_near(center, 4.5)
		if post == null:
			return "le relais doit être bâti contre un comptoir neutre"
		if not teams[team_id].discovered_posts.has(post.id):
			return "comptoir non découvert"
		if _relais_at(post) != null:
			return "ce comptoir a déjà un relais"
	for e in enemies_of(team_id):
		for u in team_units(e, "military"):
			if u.pos.distance_to(center) < 5.0 and is_visible_to(team_id, u.pos):
				return "ennemis à proximité"
	if not _can_pay(team_id, scaled_cost(def["cost"])):
		return _missing_text(team_id, scaled_cost(def["cost"]))
	# 0.16 : monuments d'âge et forge (évolution de la civilisation).
	var civ_lack: String = CivEvolution.build_lack(self, team_id, type)
	if civ_lack != "":
		return civ_lack
	# J13.1 : béton, alliage, électronique fournis par les zones industrielles de la colonie.
	if supply_gate != null:
		var industry_lack: String = supply_gate.call("lack", team_id, type, false)
		if industry_lack != "":
			return industry_lack
	var workers := team_units(team_id, "builder")
	if workers.is_empty():
		return "aucun ouvrier disponible"
	var any_path := false
	for w in workers:
		if reachable(w.pos, center, size * 0.5 + 0.5):
			any_path = true
			break
	if not any_path:
		return "aucun ouvrier ne peut atteindre l'emplacement"
	return ""

func _post_near(p: Vector2, r: float):
	for b in buildings.values():
		if b.type == "comptoir" and b.center.distance_to(p) <= r:
			return b
	return null

func _relais_at(post) :
	for b in buildings.values():
		if b.type == "relais" and b.center.distance_to(post.center) <= 4.5:
			return b
	return null

func _cmd_build(team_id: int, type: String, cell: Vector2i) -> Dictionary:
	var why := build_check(team_id, type, cell)
	if why != "":
		return _no(why)
	_pay(team_id, scaled_cost(Rules.BUILDINGS[type]["cost"]))
	if supply_gate != null:
		supply_gate.call("consume", team_id, type, false)
	var b := spawn_building(team_id, type, cell, false)
	emit("fondation", team_id, "Fondation : %s" % Rules.BUILDINGS[type]["label"], {"building": b.id})
	_assign_builders(team_id)
	return {"ok": true, "id": b.id}

func train_check(team_id: int, b, unit_type: String) -> String:
	if b == null or b.team != team_id:
		return "bâtiment introuvable"
	if not b.complete:
		return "bâtiment en construction"
	if not Rules.BUILDINGS[b.type].get("trains", []).has(unit_type):
		return "ce bâtiment ne forme pas cette unité"
	var def: Dictionary = Rules.UNITS[unit_type]
	if teams[team_id].age < int(def["age"]):
		return "nécessite l'âge %s" % Rules.AGES[int(def["age"]) - 1]["name"]
	var civ_lack: String = CivEvolution.train_lack(self, team_id, unit_type)
	if civ_lack != "":
		return civ_lack
	if b.queue.size() >= 5:
		return "file de production pleine"
	if not _can_pay(team_id, scaled_cost(def["cost"])):
		return _missing_text(team_id, scaled_cost(def["cost"]))
	# J13.1 : recrues prises dans la population logée, équipements pris dans les stocks industriels.
	if supply_gate != null:
		var colony_lack: String = supply_gate.call("lack", team_id, unit_type, true)
		if colony_lack != "":
			return colony_lack
	return ""

func _cmd_train(team_id: int, bid: int, unit_type: String) -> Dictionary:
	var b = buildings.get(bid)
	var why := train_check(team_id, b, unit_type)
	if why != "":
		return _no(why)
	_pay(team_id, scaled_cost(Rules.UNITS[unit_type]["cost"]))
	if supply_gate != null:
		supply_gate.call("consume", team_id, unit_type, true)
	b.queue.append(unit_type)
	CivEvolution.on_train_queued(self, team_id, unit_type)
	return _ok()

func age_up_status(team_id: int) -> Dictionary:
	## Retourne l'état lisible du passage d'âge : coût, objectif, manques.
	var t: Team = teams[team_id]
	var to := t.age + 1
	var out := {"to": to, "possible": false, "res_ok": false, "obj_ok": false, "missing": [], "objective": "", "cost": {}}
	if not Rules.AGE_UP.has(to) or to > int(rule("max_age", 99)):
		out["missing"].append("âge maximal du jalon atteint")
		return out
	var def: Dictionary = rule("age_up_%d" % to, Rules.AGE_UP[to])
	var cost := scaled_cost(def["cost"])
	out["cost"] = cost
	out["res_ok"] = _can_pay(team_id, cost)
	if not out["res_ok"]:
		out["missing"].append(_missing_text(team_id, cost))
	var obj: String = def["objective"]
	out["objective"] = obj
	out["obj_ok"] = objective_done(team_id, obj)
	if not out["obj_ok"]:
		out["missing"].append("objectif : " + Rules.OBJECTIVE_LABEL.get(obj, obj))
	if not t.research.is_empty():
		out["missing"].append("passage déjà en cours")
	if team_buildings(team_id, "centre", true).is_empty():
		out["missing"].append("aucun centre de commandement")
	if bool(rules.get("campaign", false)) and not bool(rules.get("evolutions", false)) and String(rules.get("sector", "val")) != "val":
		out["missing"].append("passage d'âge centralisé depuis Val des Deux Gués")
	if CivEvolution.enabled(self):
		out["missing"].append(CivEvolution.age_note(self, team_id))
		out["monument"] = true
	out["possible"] = out["missing"].is_empty()
	return out

func objective_done(team_id: int, obj: String) -> bool:
	if obj.begins_with("built_"):
		return not team_buildings(team_id, obj.substr(6), true).is_empty()
	match obj:
		"comptoir_decouvert":
			return teams[team_id].discovered_posts.size() > 0
		"batiments_2":
			var n := 0
			for b in team_buildings(team_id, "", true):
				if b.type != "centre":
					n += 1
			return n >= 2
		"tenir_gue":
			for b in team_buildings(team_id, "", true):
				for f in WorldLayout.fords(self):
					if b.center.distance_to(f) <= Rules.FORD_RADIUS_OBJECTIVE:
						return true
			return false
		"tenir_frontiere":
			# Les régions générées n'ont pas de gués artificiels aux coordonnées fixes.
			# Age III : sécuriser un passage terrestre proche de la limite régionale.
			for b in team_buildings(team_id, "", true):
				if b.type in ["palissade", "relais", "fort"]:
					if minf(minf(b.center.x, b.center.y), minf(float(map_size) - b.center.x, float(map_size) - b.center.y)) <= 18.0:
						return true
			return false
		"aucun":
			return true
	return false

func _cmd_age_up(team_id: int) -> Dictionary:
	var st := age_up_status(team_id)
	if not st["possible"]:
		return _no("passage d'âge impossible : " + "; ".join(st["missing"]))
	var def: Dictionary = rule("age_up_%d" % st["to"], Rules.AGE_UP[st["to"]])
	_pay(team_id, st["cost"])
	var dur: float = float(def["time"]) * float(rule("research_mult", 1.0))
	teams[team_id].research = {"to": st["to"], "remaining": dur, "total": dur}
	emit("age", team_id, "Passage à l'âge %s lancé" % Rules.AGES[st["to"] - 1]["name"])
	return _ok()

func _cmd_exchange(team_id: int, sell: String, buy: String) -> Dictionary:
	var t: Team = teams[team_id]
	if team_buildings(team_id, "marche", true).is_empty():
		return _no("nécessite un marché achevé")
	if sell == buy or not Rules.RESOURCES.has(sell) or not Rules.RESOURCES.has(buy):
		return _no("échange invalide")
	if t.res[sell] < 100.0:
		return _no("manque %d %s" % [ceili(100.0 - t.res[sell]), Rules.RES_LABEL[sell].to_lower()])
	t.res[sell] -= 100.0
	var gain := 100.0 * t.exchange_rate
	t.res[buy] += gain
	t.exchange_rate = max(Rules.EXCHANGE_MIN, t.exchange_rate - Rules.EXCHANGE_STEP)
	emit("echange", team_id, "Échange : 100 %s → %d %s" % [Rules.RES_LABEL[sell].to_lower(), int(gain), Rules.RES_LABEL[buy].to_lower()])
	return _ok()

# ---------------------------------------------------------------- boucle de simulation

func step() -> void:
	RallyService.step(self)
	ArmyPlans.step(self)
	if game_over:
		tick += 1
		return
	_paths_left = navigation_quota if navigation_quota >= 0 else int(rule("path_budget", PATH_BUDGET))
	_rebuild_ugrid()
	for u in units.values():
		u.prev_pos = u.pos
	for ai in ai_controllers:
		ai.think(self)
	if tick % 10 == 0:
		for t in faction_ids():
			if not teams[t].eliminated:
				_economy(t)
				_army(t)
	ModernSystems.step(self)
	AgeProgression.step(self)
	CivEvolution.step(self)
	UnitCommands.step(self)
	UrbanCity.step(self)
	_production_and_research()
	var ids := units.keys()
	for id in ids:
		if units.has(id):
			_update_unit(units[id])
	_separation()
	_buildings_attack()
	if tick % 5 == 0:
		update_fog(false)
	if tick % 10 == 5 and not bool(rules.get("campaign", false)):
		_check_conquest()
	if tick % 30 == 0:
		for t in teams:
			t.exchange_rate = min(Rules.EXCHANGE_START_RATE, t.exchange_rate + 0.005)
	tick += 1

# ---------------------------------------------------------------- économie

func _gatherers(team_id: int) -> Array:
	var out := []
	for u in team_units(team_id, "worker"):
		if not u.direct and not u.manual and u.task != "build":
			out.append(u)
	return out

func _assign_builders(team_id: int) -> void:
	for b in team_buildings(team_id):
		if b.complete:
			continue
		var builders := 0
		for u in team_units(team_id, "builder"):
			if u.task == "build" and u.build_id == b.id:
				builders += 1
		var want := 2 if b.size >= 3 else 1
		if b.type == "centre":
			want = 3
		while builders < want:
			var best = null
			var bd := INF
			for u in _gatherers(team_id):
				var d: float = u.pos.distance_squared_to(b.center) + (25.0 if u.carry_amt > 5 else 0.0)
				if d < bd and reachable(u.pos, b.center, b.size * 0.5 + 0.5):
					bd = d
					best = u
			if best == null:
				break
			_release_worker_job(best)
			best.task = "build"
			best.build_id = b.id
			best.state = "to_build"
			best.path_goal = Vector2(-999, -999)
			builders += 1

func _release_worker_job(u: Unit) -> void:
	if u.node_id != -1:
		for b in buildings.values():
			if b.farmer == u.id:
				b.farmer = -1
	u.node_id = -1
	u.build_id = -1
	u.blocked_reason = ""

func _economy(team_id: int) -> void:
	var t: Team = teams[team_id]
	_assign_builders(team_id)
	if UrbanCity.replaces_gathering(self, team_id): return
	# Accessibilité des ressources (recalculée toutes les 5 s)
	if tick % 50 == 0:
		var probe := _probe_pos(team_id)
		for r in Rules.RESOURCES:
			var was: bool = t.res_access[r]
			t.res_access[r] = _find_node(team_id, r, probe, true) != null
			if was and not t.res_access[r]:
				emit("penurie", team_id, "Aucun gisement de %s accessible : ouvriers réaffectés" % Rules.RES_LABEL[r].to_lower(), {"res": r})
			elif not was and t.res_access[r]:
				emit("penurie_fin", team_id, "Gisement de %s de nouveau accessible" % Rules.RES_LABEL[r].to_lower(), {"res": r})
	var gs := _gatherers(team_id)
	if gs.is_empty():
		return
	var weights := {}
	var total := 0.0
	for r in Rules.RESOURCES:
		var w := float(t.priorities[r]) if t.res_access[r] else 0.0
		weights[r] = w
		total += w
	var desired := {"food": 0, "wood": 0, "ore": 0}
	if total > 0.0:
		var n := gs.size()
		var assigned := 0
		var rema := []
		for r in Rules.RESOURCES:
			var exact: float = n * weights[r] / total
			desired[r] = int(floor(exact))
			assigned += desired[r]
			rema.append([exact - floor(exact), Rules.RESOURCES.find(r), r])
		rema.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
		var i := 0
		while assigned < n:
			desired[rema[i % 3][2]] += 1
			assigned += 1
			i += 1
	var by_res := {"food": [], "wood": [], "ore": [], "": []}
	for u in gs:
		var k = u.task if by_res.has(u.task) else ""
		by_res[k].append(u)
	# Les inactifs d'abord
	for u in by_res[""]:
		for r in Rules.RESOURCES:
			if by_res[r].size() < desired[r]:
				_set_task(u, r)
				by_res[r].append(u)
				break
	var moves := {}
	for r in Rules.RESOURCES:
		while by_res[r].size() > desired[r]:
			var dest := ""
			for r2 in Rules.RESOURCES:
				if by_res[r2].size() < desired[r2]:
					dest = r2
					break
			if dest == "":
				break
			# déplace l'ouvrier qui ne transporte rien de préférence
			var pick: Unit = by_res[r][by_res[r].size() - 1]
			for cand in by_res[r]:
				if cand.carry_amt < 0.5:
					pick = cand
			by_res[r].erase(pick)
			_set_task(pick, dest)
			by_res[dest].append(pick)
			var key := "%s>%s" % [r, dest]
			moves[key] = moves.get(key, 0) + 1
	for k in moves.keys():
		var p: PackedStringArray = k.split(">")
		emit("reaffectation", team_id, "Réaffectation : %d ouvrier(s) %s → %s" % [moves[k], Rules.RES_LABEL[p[0]].to_lower(), Rules.RES_LABEL[p[1]].to_lower()], {"from": p[0], "to": p[1], "count": moves[k]})

func _probe_pos(team_id: int) -> Vector2:
	var ccs := team_buildings(team_id, "centre")
	if not ccs.is_empty():
		return ccs[0].center
	var ws := team_units(team_id, "worker")
	if not ws.is_empty():
		return ws[0].pos
	return Vector2(48, 48)

func _set_task(u: Unit, r: String) -> void:
	_release_worker_job(u)
	u.task = r
	u.state = "idle"
	u.path_goal = Vector2(-999, -999)

func _find_node(team_id: int, r: String, from: Vector2, check_only: bool = false, exclude: int = -1):
	## Gisement exploré, non épuisé et atteignable le plus proche. Les fermes comptent pour la nourriture.
	var t: Team = teams[team_id]
	var cands := []
	for n in nodes.values():
		if n.res != r or n.amount <= 0.0 or n.id == exclude:
			continue
		if not is_explored_by(team_id, n.pos):
			continue
		if t.unreachable.has(n.id) and tick - int(t.unreachable[n.id]) < 300:
			continue
		cands.append([from.distance_squared_to(n.pos), n])
	if r == "food":
		for b in team_buildings(team_id, "ferme", true):
			if b.farmer == -1 or not units.has(b.farmer):
				cands.append([from.distance_squared_to(b.center) + 40.0, b])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var tries := 0
	for c in cands:
		var target = c[1]
		var tp: Vector2 = target.pos if target is ResNode else target.center
		var rad := 0.6 if target is ResNode else 1.5
		if reachable(from, tp, rad):
			return target
		if target is ResNode:
			t.unreachable[target.id] = tick
		tries += 1
		if tries > 6:
			break
	return null

func _nearest_drop(team_id: int, p: Vector2):
	var best = null
	var bd := INF
	for b in team_buildings(team_id, "", true):
		if Rules.BUILDINGS[b.type].get("drop", false):
			var d := p.distance_squared_to(b.center)
			if d < bd:
				bd = d
				best = b
	return best

# ---------------------------------------------------------------- armée déléguée

func _squad_members(s: Squad) -> Array:
	var out := []
	for id in s.units:
		if units.has(id):
			out.append(units[id])
	return out

func _squad_center(s: Squad) -> Vector2:
	var m := _squad_members(s)
	if m.is_empty():
		return Vector2.ZERO
	var c := Vector2.ZERO
	for u in m:
		c += u.pos
	return c / m.size()

func _army(team_id: int) -> void:
	var t: Team = teams[team_id]
	if t.army.is_empty():
		return
	var pool := []
	for s in team_squads(team_id):
		if not s.direct and _squad_members(s).size() > 0:
			pool.append(s)
	if pool.is_empty():
		return
	var center: Vector2 = t.army["pos"]
	var radius: float = t.army["radius"]
	# Menaces : ennemis visibles par le camp dans le secteur
	var threats := []
	for e in enemies_of(team_id):
		for u in team_units(e):
			if u.pos.distance_to(center) <= radius * 1.25 and is_visible_to(team_id, u.pos):
				threats.append(u)
	if not threats.is_empty():
		threats.sort_custom(func(a, b): return a.pos.distance_squared_to(center) < b.pos.distance_squared_to(center))
		# Une escouade par menace distincte (groupes à > 5 cases), le reste sur la menace la plus proche ; 1 réserve si >= 3 escouades
		var groups := []
		for u in threats:
			var placed := false
			for g in groups:
				if g[0].pos.distance_to(u.pos) < 5.0:
					g.append(u)
					placed = true
					break
			if not placed:
				groups.append([u])
		var reserve = null
		if pool.size() >= 3:
			pool.sort_custom(func(a, b): return _squad_center(a).distance_squared_to(center) < _squad_center(b).distance_squared_to(center))
			reserve = pool[0]
		var gi := 0
		for s in pool:
			if s == reserve:
				s.order = {"type": "hold", "pos": center}
				s.army_role = "Réserve"
				s.army_target = center
				continue
			var g: Array = groups[gi % groups.size()]
			s.order = {"type": "attack", "target": g[0].id}
			s.army_role = "Interception"
			s.army_target = g[0].pos
			gi += 1
		return
	# Pas de menace : répartition des postes autour du centre, orientés vers l'ennemi connu
	var dir := Vector2(1, -1).normalized() if team_id == 0 else Vector2(-1, 1).normalized()
	for id in t.memory.keys():
		var m: Dictionary = t.memory[id]
		if m["team"] != team_id and m["team"] != TEAM_NEUTRAL:
			dir = (m["pos"] - center).normalized()
			break
	var posts := [{"pos": center, "role": "Réserve"}]
	var n_front := pool.size() - 1
	for i in n_front:
		var ang := 0.0 if n_front == 1 else lerpf(-0.9, 0.9, float(i) / float(n_front - 1))
		var p: Vector2 = center + dir.rotated(ang) * radius * 0.6
		var c := cell_of(p)
		if not walkable(c):
			p = Vector2(nearest_walkable(c, p)) + Vector2(0.5, 0.5)
		posts.append({"pos": p, "role": "Poste %d" % (i + 1)})
	# affectation gloutonne déterministe : chaque poste prend l'escouade libre la plus proche
	var free := pool.duplicate()
	for post in posts:
		var best = null
		var bd := INF
		for s in free:
			var d := _squad_center(s).distance_squared_to(post["pos"])
			if d < bd:
				bd = d
				best = s
		if best == null:
			break
		free.erase(best)
		var ppos: Vector2 = post["pos"]
		var role: String = post["role"]
		var sc := _squad_center(best)
		if best.army_role.begins_with(role) and best.army_target == ppos:
			continue
		var rep := route_report(sc, ppos)
		if rep["status"] != "directe" and rep["status"] != "detour" and sc.distance_to(ppos) > 2.0:
			# poste inaccessible : position praticable la plus proche du poste vers le centre du secteur
			var alt := ppos
			for k in 8:
				var q: Vector2 = ppos.lerp(center, float(k + 1) / 8.0)
				if find_path(sc, q).size() > 0:
					alt = q
					break
			ppos = alt
			role += " (repli, accès bloqué)"
		elif rep["status"] == "detour":
			role += " (autre accès)"
		best.order = {"type": "hold", "pos": ppos}
		best.army_role = role
		best.army_target = post["pos"]

func _join_squad(u: Unit, b, force_new: bool = false) -> void:
	var s = null
	if not force_new:
		if b != null and squads.has(b.forming_squad):
			var cand: Squad = squads[b.forming_squad]
			if cand.units.size() < Rules.SQUAD_SIZE:
				s = cand
		elif b == null:
			for cand in team_squads(u.team):
				if cand.units.size() < Rules.SQUAD_SIZE and not cand.direct:
					s = cand
	if s == null:
		s = Squad.new()
		s.id = new_id()
		s.team = u.team
		teams[u.team].squad_counter += 1
		s.number = teams[u.team].squad_counter
		s.order = {"type": "hold", "pos": u.pos if b == null else b.rally}
		squads[s.id] = s
		if b != null:
			b.forming_squad = s.id
		emit("escouade", u.team, "Escouade %d formée" % s.number, {"squad": s.id})
	s.units.append(u.id)
	u.squad_id = s.id

func formation_slot(s: Squad, u: Unit) -> Vector2:
	if s.formation != "":
		return UnitCommands.formation_slot(self, s, u)
	var i := s.units.find(u.id)
	var cols := 3
	var row := i / cols
	var col := i % cols
	return Vector2((col - 1) * 1.3, (row - 0.5) * 1.3)

# ---------------------------------------------------------------- production

func _production_and_research() -> void:
	for t in teams:
		if t.id == TEAM_NEUTRAL or t.eliminated:
			continue
		if not t.research.is_empty() and not team_buildings(t.id, "centre", true).is_empty():
			t.research["remaining"] -= Rules.DT
			if t.research["remaining"] <= 0.0:
				t.age = int(t.research["to"])
				t.research = {}
				emit("age_atteint", t.id, "%s atteint l'âge %s" % [t.name, Rules.AGES[t.age - 1]["name"]], {"age": t.age})
	for b in buildings.values():
		if not b.complete or b.queue.is_empty() or b.team == TEAM_NEUTRAL:
			continue
		var ut: String = b.queue[0]
		var t: Team = teams[b.team]
		var pop := int(Rules.UNITS[ut]["pop"])
		if t.pop + pop > t.pop_cap:
			if b.prod_blocked == "":
				emit("pop", b.team, "Population maximale atteinte : construisez une maison", {"building": b.id})
			b.prod_blocked = "Population maximale (%d/%d)" % [t.pop, t.pop_cap]
			continue
		b.prod_blocked = ""
		b.prod_timer += Rules.DT * (1.25 if t.technologies.has("standardisation") else 1.0) * AgeProgression.production_multiplier(b.tier) * labor(b.team) * CivEvolution.speed_mult(self, b.team, "train_speed")
		if b.prod_timer >= float(Rules.UNITS[ut]["time"]):
			b.prod_timer = 0.0
			b.queue.pop_front()
			var dir = (b.rally - b.center).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2(0, 1)
			var u := spawn_unit(b.team, ut, b.center + dir * (b.size * 0.5 + 0.8))
			u.origin_building = b.id
			u.home_body = String(rules.get("sector", ""))
			AgeProgression.apply_unit_level(u, int(b.unit_evolutions.get(ut, 1)))
			CivEvolution.on_unit_spawn(self, u)
			t.stats["units_trained"] += 1
			if Rules.unit_has(ut, "military"):
				_join_squad(u, b)
			elif not Rules.unit_has(ut, "worker"):
				u.order = {"type": "move", "pos": b.rally}
			RallyService.assign(self, u, b)
			ArmyPlans.on_spawn(self, u, b)
			UnitCommands.on_spawn(self, u, b)
			emit("unite", b.team, "Unité prête : %s" % Rules.UNITS[ut]["label"], {"unit": u.id})

# ---------------------------------------------------------------- unités

func _move_towards(u: Unit, goal: Vector2, stop_dist: float = 0.15) -> bool:
	if Rules.unit_has(u.type, "air"):
		var distance: float = u.pos.distance_to(goal)
		var movement: Vector2 = goal - u.pos
		u.facing = atan2(movement.y, movement.x)
		u.pos = u.pos.move_toward(goal.clamp(Vector2.ZERO, Vector2.ONE * (map_size - 0.01)), float(Rules.UNITS[u.type]["speed"]) * Rules.DT * ModernSystems.efficiency(self, u))
		return distance <= stop_dist
	## Avance le long d'un chemin A*. Retourne true quand l'unité est arrivée.
	## Un échec de chemin est mis en cache 2 s pour éviter de relancer A* à chaque tick.
	if u.pos.distance_to(goal) <= stop_dist:
		u.path = PackedVector2Array()
		return true
	u.waiting_path = false
	var need := u.path_goal.distance_to(goal) > 0.75 or u.path_timer <= 0 or (u.path.is_empty() and not u.path_failed)
	if need and _paths_left <= 0 and u.pos.distance_to(goal) >= 2.0:
		# budget de recherches de chemin épuisé pour ce tick : l'unité attend son tour (ordre des id,
		# donc déterministe) ; un chemin encore valable vers le même but est conservé.
		if u.path.is_empty() or u.path_goal.distance_to(goal) > 0.75:
			u.waiting_path = true
			return false
		need = false
	if need:
		u.path_goal = goal
		u.path_timer = 40
		u.path_failed = false
		if u.pos.distance_to(goal) < 2.0:
			u.path = PackedVector2Array([goal])
		else:
			u.path = find_path(u.pos, goal)
			_paths_left -= 1
			if u.path.is_empty():
				u.path_failed = true
				u.path_timer = 20
	if u.path_failed:
		u.path_timer -= 1
		return false
	u.path_timer -= 1
	u.deploy = 0.0
	var speed: float = float(Rules.UNITS[u.type]["speed"]) * Rules.DT * ModernSystems.efficiency(self, u)
	if terrain[idx(cell_of(u.pos))] == TERRAIN_FORD:
		speed *= 0.7
	while speed > 0.0 and not u.path.is_empty():
		var wp: Vector2 = u.path[0]
		var d := u.pos.distance_to(wp)
		if d <= speed:
			u.pos = wp
			speed -= d
			u.path.remove_at(0)
		else:
			var v := (wp - u.pos) / d
			u.pos += v * speed
			u.facing = atan2(v.y, v.x)
			speed = 0.0
	return u.pos.distance_to(goal) <= stop_dist

func _update_unit(u: Unit) -> void:
	if u.garrison_id != -1:
		return
	if u.type == "train":
		ModernSystems.train_step(self, u)
		return
	if u.cd > 0.0:
		u.cd -= Rules.DT
	if Rules.unit_has(u.type, "worker") and not u.direct:
		_update_worker(u)
		return
	if Rules.unit_has(u.type, "caravan") and not u.direct:
		_update_caravan(u)
		return
	var order: Dictionary = u.order
	var slot := Vector2.ZERO
	if not u.direct and u.squad_id != -1 and squads.has(u.squad_id):
		var s: Squad = squads[u.squad_id]
		order = s.order
		slot = formation_slot(s, u)
	_update_combatant(u, order, slot)

func _update_combatant(u: Unit, order: Dictionary, slot: Vector2) -> void:
	var def: Dictionary = Rules.UNITS[u.type]
	var otype: String = order.get("type", "")
	if not u.rally_contract.is_empty() and not u.order_steps.is_empty(): u.rally_contract = {}
	# Ordre de déplacement : prioritaire, n'engage pas en route
	if otype == "move":
		var goal: Vector2 = order["pos"] + slot
		if not walkable(cell_of(goal)):
			goal = order["pos"]
		u.state = "move"
		if _move_towards(u, goal, 0.25):
			order["type"] = "hold"
			u.state = "idle"
		return
	var tgt = null
	if otype == "attack":
		tgt = entity(int(order["target"]))
		if tgt == null:
			order["type"] = "hold"
			order["pos"] = u.pos - slot
			otype = "hold"
	if tgt == null and u.target_id != -1:
		tgt = entity(u.target_id)
		if tgt != null:
			var anchor: Vector2 = order.get("pos", u.pos) if otype == "hold" else u.pos
			if anchor.distance_to(entity_pos(tgt)) > float(def["vision"]) + 6.0 or not is_visible_to(u.team, entity_pos(tgt)):
				tgt = null
	if tgt != null and otype != "attack" and not UnitCommands.keep_target(self, u, tgt, order):
		tgt = null
	if tgt == null and float(def["atk"]) > 0.0:
		tgt = UnitCommands.acquire(self, u, float(def["vision"]))
	if tgt != null and not factions.hostile(u.team, tgt.team):
		tgt = null
	if tgt != null and float(def["atk"]) > 0.0:
		u.target_id = tgt.id
		_engage(u, tgt)
		return
	u.target_id = -1
	if otype == "hold" or otype == "amove":
		var goal: Vector2 = order["pos"] + slot
		if not walkable(cell_of(goal)):
			goal = order["pos"]
		u.state = "move" if u.pos.distance_to(goal) > 0.4 else "idle"
		if _move_towards(u, goal, 0.3) and otype == "amove":
			order["type"] = "hold"
	else:
		u.state = "idle"

func _acquire(u: Unit, radius: float):
	if Rules.unit_has(u.type, "siege"):
		var bb = null
		var bbd := pow(float(Rules.UNITS[u.type]["range"]) + 2.0, 2)
		for b in buildings.values():
			if not factions.hostile(u.team, b.team) or not is_visible_to(u.team, b.center):
				continue
			var d := u.pos.distance_squared_to(b.center)
			if d < bbd:
				bbd = d
				bb = b
		if bb != null:
			return bb
	var best = null
	var bd := radius * radius
	var foes := enemies_of(u.team)
	if not foes.is_empty():
		var r := radius + 1.0
		var x0 := int(maxf(0.0, u.pos.x - r) / UGRID)
		var x1 := int(maxf(0.0, u.pos.x + r) / UGRID)
		var y0 := int(maxf(0.0, u.pos.y - r) / UGRID)
		var y1 := int(maxf(0.0, u.pos.y + r) / UGRID)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var cell = _ugrid.get(Vector2i(gx, gy))
				if cell == null:
					continue
				for o in cell:
					if not factions.hostile(u.team, o.team) or not units.has(o.id) or not ModernSystems.can_target(u, o) or not is_visible_to(u.team, o.pos):
						continue
					var d := u.pos.distance_squared_to(o.pos)
					if d < bd or (d == bd and best != null and o.id < best.id):
						bd = d
						best = o
	if best == null:
		for e in enemies_of(u.team):
			for b in buildings.values():
				if b.team != e or not is_visible_to(u.team, b.center):
					continue
				var d = u.pos.distance_squared_to(b.center) - b.size * b.size * 0.25
				if d < bd * 0.6:
					bd = d
					best = b
	return best

func _engage(u: Unit, tgt) -> void:
	if not ModernSystems.can_target(u, tgt) or not is_visible_to(u.team, entity_pos(tgt)):
		u.target_id = -1
		return
	var def: Dictionary = Rules.UNITS[u.type]
	var tp := entity_pos(tgt)
	var reach: float = float(def["range"]) + (tgt.size * 0.5 if tgt is Building else 0.35)
	var dist := u.pos.distance_to(tp)
	var min_r: float = float(def.get("min_range", 0.0))
	if min_r > 0.0 and dist < min_r + (tgt.size * 0.5 if tgt is Building else 0.0):
		# artillerie : cible trop proche, recul avant de tirer
		u.deploy = 0.0
		u.state = "trop_pres"
		var away := (u.pos - tp).normalized()
		if away == Vector2.ZERO:
			away = Vector2(1, 0)
		_move_towards(u, u.pos + away * 2.0, 0.2)
		return
	if dist <= reach + 0.1:
		u.path = PackedVector2Array()
		var v := tp - u.pos
		u.facing = atan2(v.y, v.x)
		var setup_t: float = float(def.get("setup", 0.0))
		if u.deploy < setup_t:
			u.deploy += Rules.DT
			u.state = "batterie"
			return
		u.state = "attack"
		if u.cd <= 0.0:
			u.cd = float(def["cd"])
			u.attacking_tick = tick
			if float(def["range"]) > 2.0:
				emit("tir", u.team, "", {"from": u.pos, "to": tp, "siege": Rules.unit_has(u.type, "siege")})
			_damage(tgt, _damage_value(u, tgt), u)
	else:
		if not UnitCommands.may_chase(self, u):
			u.target_id = -1
			u.state = "idle"
			return
		u.deploy = 0.0
		u.state = "move"
		var goal := tp
		if tgt is Building:
			goal = goal_for(u, tgt.id, tgt.center, tgt.size * 0.5 + 0.3)
			if goal.x < 0:
				return
		if not _move_towards(u, goal, max(0.2, reach * 0.8)) and u.path.is_empty() and not u.waiting_path:
			# cible inaccessible : abandon
			u.target_id = -1

func _damage_value(u: Unit, tgt) -> float:
	var def: Dictionary = Rules.UNITS[u.type]
	var dmg: float = float(def["atk"]) * ModernSystems.efficiency(self, u) * AgeProgression.attack_multiplier(u.evolution) * CivEvolution.attack_mult(self, u, tgt)
	if tgt is Unit:
		dmg *= float(def.get("unit_mult", 1.0))
		var bonus: Dictionary = def.get("bonus", {})
		for tag in bonus.keys():
			if Rules.unit_has(tgt.type, tag):
				dmg *= float(bonus[tag])
	else:
		var m: float = Rules.BUILDING_DAMAGE["default"]
		for tag in ["siege", "ranged", "cavalry", "worker"]:
			if Rules.unit_has(u.type, tag):
				m = Rules.BUILDING_DAMAGE[tag]
				break
		dmg *= m
	return dmg

func _damage(tgt, dmg: float, src) -> void:
	if tgt is Unit and Rules.unit_has(tgt.type, "vehicle") and teams[tgt.team].technologies.has("blindage"):
		dmg *= 0.8
	if tgt is Unit and tgt.type == "fregate" and teams[tgt.team].technologies.has("navigation_stellaire"):
		dmg *= 0.8
	dmg *= CivEvolution.defense_mult(self, tgt)
	tgt.hp -= dmg
	tgt.hit_tick = tick
	if tgt is Unit:
		if tgt.state in ["to_node", "to_drop", "gather"] and tgt.blocked_reason == "":
			tgt.blocked_reason = "attaqué en chemin"
			if tick % 20 == 0 or true:
				pass
		if tgt.hp <= 0.0:
			_kill_unit(tgt, src.team if src != null else -1)
		elif tgt.target_id == -1 and src is Unit and Rules.UNITS[tgt.type]["atk"] > 0 and tgt.stance != "passive" and not (tgt.direct and tgt.order.get("type", "") == "move"):
			tgt.target_id = src.id
	else:
		if tgt.hp <= 0.0:
			_destroy_building(tgt, src.team if src != null else -1)

func transfer_out_unit(u: Unit) -> void:
	## Embarquement = transfert, pas destruction : aucune perte militaire fictive.
	if not units.has(u.id):
		return
	_release_worker_job(u)
	units.erase(u.id)
	teams[u.team].pop -= int(Rules.UNITS[u.type]["pop"])
	if squads.has(u.squad_id):
		var squad: Squad = squads[u.squad_id]
		squad.units.erase(u.id)
		if squad.units.is_empty():
			squads.erase(squad.id)

func _kill_unit(u: Unit, by_team: int) -> void:
	if not units.has(u.id):
		return
	_release_worker_job(u)
	units.erase(u.id)
	teams[u.team].pop -= int(Rules.UNITS[u.type]["pop"])
	teams[u.team].stats["losses"] += 1
	if by_team >= 0 and by_team < teams.size() and by_team != TEAM_NEUTRAL:
		teams[by_team].stats["kills"] += 1
	CivEvolution.on_kill(self, u, by_team)
	if squads.has(u.squad_id):
		var s: Squad = squads[u.squad_id]
		s.units.erase(u.id)
		if s.units.is_empty():
			squads.erase(s.id)
	emit("mort", u.team, "Unité perdue : %s" % Rules.UNITS[u.type]["label"], {"unit": u.id, "utype": u.type, "pos": u.pos})

func _destroy_building(b: Building, by_team: int) -> void:
	if not buildings.has(b.id):
		return
	buildings.erase(b.id)
	for dy in b.size:
		for dx in b.size:
			var c := b.cell + Vector2i(dx, dy)
			_occupied.erase(c)
			astar.set_point_solid(c, terrain[idx(c)] == TERRAIN_WATER)
	if b.complete and b.team != TEAM_NEUTRAL:
		teams[b.team].pop_cap -= int(Rules.BUILDINGS[b.type].get("pop", 0))
	UrbanGrowth.on_destroyed(self, b, by_team) # 0.19 : ruines persistantes d'un bâtiment de zone détruit
	if b.team != TEAM_NEUTRAL:
		CivEvolution.on_building_lost(self, b, by_team)
		_refund_queue(b)
	emit("detruit", b.team, "Bâtiment détruit : %s" % Rules.BUILDINGS[b.type]["label"], {"building": b.id, "btype": b.type, "pos": b.center})

func _refund_queue(b: Building) -> void:
	b.queue.clear()

func _update_worker(u: Unit) -> void:
	# autodéfense minimale : un ouvrier ne riposte pas, il poursuit sa tâche
	match u.task:
		"build":
			var b = buildings.get(u.build_id)
			if b == null or b.complete:
				u.task = ""
				u.build_id = -1
				u.state = "idle"
				return
			var ap := goal_for(u, b.id, b.center, b.size * 0.5 + 0.3)
			if ap.x < 0:
				u.blocked_reason = "chantier inaccessible"
				u.task = ""
				return
			if u.pos.distance_to(b.center) <= b.size * 0.5 + 1.6:
				u.state = "build"
				var dur: float = float(Rules.BUILDINGS[b.type]["time"]) / CivEvolution.speed_mult(self, u.team, "build_speed")
				b.progress = min(1.0, b.progress + Rules.DT / dur)
				b.hp = min(b.max_hp, b.hp + b.max_hp * 0.9 * Rules.DT / dur)
				if b.progress >= 1.0:
					_complete_building(b)
			else:
				u.state = "to_build"
				if not _move_towards(u, ap, 0.3) and u.path.is_empty() and not u.waiting_path and u.pos.distance_to(ap) > 0.5:
					u.blocked_reason = "chantier inaccessible"
					u.task = ""
		"food", "wood", "ore":
			if UrbanCity.replaces_gathering(self, u.team) and UrbanCity.stop_gather(self, u): return
			_update_gather(u)
		"repair":
			UnitCommands.update_repair(self, u)
		_:
			u.state = "idle"

func _complete_building(b: Building) -> void:
	b.complete = true
	b.progress = 1.0
	if b.team != TEAM_NEUTRAL:
		teams[b.team].pop_cap += int(Rules.BUILDINGS[b.type].get("pop", 0))
	emit("acheve", b.team, "Construction terminée : %s" % Rules.BUILDINGS[b.type]["label"], {"building": b.id, "btype": b.type})
	CivEvolution.on_building_complete(self, b)

func _update_gather(u: Unit) -> void:
	var t: Team = teams[u.team]
	# Plein : retour au dépôt
	if u.carry_amt >= Rules.CARRY - 0.01 or (u.state == "to_drop"):
		var drop = _nearest_drop(u.team, u.pos)
		if drop == null:
			u.blocked_reason = "aucun dépôt (centre, entrepôt, marché)"
			u.state = "idle"
			return
		u.state = "to_drop"
		var ap := goal_for(u, drop.id, drop.center, drop.size * 0.5 + 0.3)
		if u.pos.distance_to(drop.center) <= drop.size * 0.5 + 1.6:
			if u.carry_amt > 0.0:
				t.res[u.carry_res] += u.carry_amt
				t.stats["gathered"][u.carry_res] += u.carry_amt
			u.carry_amt = 0.0
			u.state = "to_node"
			u.blocked_reason = ""
			if u.carry_res != u.task:
				u.node_id = -1
			return
		if ap.x < 0 or (not _move_towards(u, ap, 0.3) and u.path.is_empty() and not u.waiting_path and u.pos.distance_to(ap) > 0.5):
			u.blocked_reason = "trajet vers le dépôt interrompu"
		return
	# Changement de tâche avec une charge d'une autre ressource : on dépose d'abord
	if u.carry_amt > 0.0 and u.carry_res != u.task:
		u.state = "to_drop"
		return
	var target = null
	if u.node_id != -1:
		target = nodes.get(u.node_id)
		if target == null:
			target = buildings.get(u.node_id)
			if target != null and (target.farmer != u.id and target.farmer != -1 and units.has(target.farmer)):
				target = null
		if target is ResNode and target.amount <= 0.0:
			emit("epuise", u.team, "Gisement épuisé (%s) : recherche d'un autre" % Rules.RES_LABEL[u.task].to_lower(), {"node": target.id, "unit": u.id})
			target = null
	if target == null:
		var old := u.node_id
		_release_worker_job(u)
		target = _find_node(u.team, u.task, u.pos, false, old)
		if target == null:
			var farms_full: bool = u.task == "food" and not team_buildings(u.team, "ferme", true).is_empty()
			u.blocked_reason = ("fermes toutes occupées, baies épuisées" if farms_full else "aucun gisement de %s accessible" % Rules.RES_LABEL[u.task].to_lower())
			if t.res_access[u.task]:
				if farms_full:
					emit("penurie", u.team, "Nourriture : fermes toutes occupées et baies épuisées — construisez une ferme", {"res": u.task})
				else:
					emit("penurie", u.team, "Aucun gisement de %s accessible : ouvriers réaffectés" % Rules.RES_LABEL[u.task].to_lower(), {"res": u.task})
			t.res_access[u.task] = false
			u.task = ""
			u.state = "idle"
			return
		u.node_id = target.id
		if target is Building:
			target.farmer = u.id
	var tp: Vector2 = target.pos if target is ResNode else target.center
	var rad = 0.9 if target is ResNode else target.size * 0.5 + 0.4
	if u.pos.distance_to(tp) <= rad + 0.7:
		u.state = "gather"
		u.blocked_reason = ""
		var v := tp - u.pos
		if v.length() > 0.01:
			u.facing = atan2(v.y, v.x)
		var kind: String = target.kind if target is ResNode else "ferme"
		var amt: float = Rules.GATHER_RATE[kind] * Rules.DT * labor(u.team) * (1.25 if t.technologies.has("outillage") else 1.0) * CivEvolution.gather_mult(self, u.team, String(Rules.NODE_RES.get(kind, "food")))
		if target is ResNode:
			amt = min(amt, target.amount)
			target.amount -= amt
		u.carry_res = u.task
		u.carry_amt += amt
		if target is ResNode and target.amount <= 0.0:
			emit("epuise", u.team, "Gisement épuisé (%s) : recherche d'un autre" % Rules.RES_LABEL[u.task].to_lower(), {"node": target.id, "unit": u.id})
			u.node_id = -1
	else:
		u.state = "to_node"
		var goal := tp if target is ResNode else goal_for(u, target.id, tp, rad)
		if target is ResNode and not walkable(cell_of(tp)):
			goal = goal_for(u, target.id, tp, 0.9)
		if goal.x < 0 or (not _move_towards(u, goal, 0.6) and u.path.is_empty() and not u.waiting_path and u.pos.distance_to(goal) > 0.8):
			if target is ResNode:
				t.unreachable[target.id] = tick
			u.blocked_reason = "trajet interrompu : gisement inaccessible"
			_release_worker_job(u)

func _update_caravan(u: Unit) -> void:
	var t: Team = teams[u.team]
	var relais = buildings.get(u.trade_relais)
	if relais == null or not relais.complete or relais.team != u.team:
		relais = null
		var bd := INF
		for b in team_buildings(u.team, "relais", true):
			var d := u.pos.distance_squared_to(b.center)
			if d < bd:
				bd = d
				relais = b
		if relais == null:
			u.blocked_reason = "aucun relais marchand achevé"
			u.state = "idle"
			return
		u.trade_relais = relais.id
		u.trade_leg = 0
	var hub = null
	var hd := INF
	for b in team_buildings(u.team, "", true):
		if b.type == "marche" or b.type == "centre":
			var d: float = relais.center.distance_squared_to(b.center)
			if d < hd:
				hd = d
				hub = b
	if hub == null:
		u.blocked_reason = "aucun marché ni centre"
		u.state = "idle"
		return
	u.blocked_reason = ""
	var dest = relais if u.trade_leg == 0 else hub
	var ap := goal_for(u, dest.id, dest.center, dest.size * 0.5 + 0.3)
	u.state = "trade"
	if u.pos.distance_to(dest.center) <= dest.size * 0.5 + 1.6:
		if u.trade_leg == 0:
			u.trade_leg = 1
		else:
			var gain: float = relais.center.distance_to(hub.center) * float(rule("trade_per_tile", Rules.TRADE_PER_TILE)) * CivEvolution.speed_mult(self, u.team, "trade")
			t.res[t.trade_res] += gain
			t.stats["trade"] += gain
			emit("commerce", u.team, "Caravane : +%d %s" % [int(gain), Rules.RES_LABEL[t.trade_res].to_lower()], {"gain": gain})
			u.trade_leg = 0
		u.path_goal = Vector2(-999, -999)
		return
	if ap.x < 0 or (not _move_towards(u, ap, 0.3) and u.path.is_empty() and not u.waiting_path and u.pos.distance_to(ap) > 0.5):
		u.blocked_reason = "route commerciale coupée"

func _separation() -> void:
	var arr := units.values()
	var n := arr.size()
	var grid := {}
	for u in arr:
		var k := Vector2i(int(u.pos.x / 2.0), int(u.pos.y / 2.0))
		if not grid.has(k):
			grid[k] = []
		grid[k].append(u)
	for u in arr:
		if u.state == "gather" or u.state == "build" or u.garrison_id != -1 or Rules.unit_has(u.type, "air") or u.type == "train":
			continue
		var k := Vector2i(int(u.pos.x / 2.0), int(u.pos.y / 2.0))
		var push := Vector2.ZERO
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cell = grid.get(k + Vector2i(dx, dy))
				if cell == null:
					continue
				for o in cell:
					if o == u or o.garrison_id != -1 or Rules.unit_has(o.type, "air"):
						continue
					var v: Vector2 = u.pos - o.pos
					var d := v.length()
					if d < 0.7:
						var dirv: Vector2 = v / d if d > 0.001 else Vector2(1, 0).rotated(float(u.id % 12) * 0.52)
						push += dirv * (0.7 - d) * 0.35
		if push != Vector2.ZERO:
			var np: Vector2 = u.pos + push.limit_length(0.3)
			if np.x > 0.0 and np.y > 0.0 and np.x < map_size and np.y < map_size and walkable(cell_of(np)):
				u.pos = np

func _buildings_attack() -> void:
	for b in buildings.values():
		if not b.complete or b.team == TEAM_NEUTRAL:
			continue
		var def: Dictionary = Rules.BUILDINGS[b.type]
		if float(def.get("atk", 0.0)) <= 0.0:
			continue
		if b.cd > 0.0:
			b.cd -= Rules.DT
			continue
		var best = null
		var bd: float = pow(float(def["range"]) + b.size * 0.5, 2)
		for o in units.values():
			if not factions.hostile(b.team, o.team) or Rules.unit_has(o.type, "air") or o.garrison_id != -1 or not is_visible_to(b.team, o.pos):
				continue
			var d = b.center.distance_squared_to(o.pos)
			if d < bd:
				bd = d
				best = o
		if best != null:
			b.cd = float(def["cd"])
			b.hit_tick = b.hit_tick
			emit("tir", b.team, "", {"from": b.center, "to": best.pos})
			_damage(best, float(def["atk"]), b)

# ---------------------------------------------------------------- brouillard et mémoire

func update_fog(_force: bool) -> void:
	for t in teams:
		if t.id == TEAM_NEUTRAL:
			continue
		var fog: PackedByteArray = t.fog
		if t.id == 0 and bool(rules.get("reveal_map", false)) and not _map_revealed:
			fog.fill(1)
			_map_revealed = true
		_track_visibility = bool(rules.get("evolutions", false)) and not bool(rules.get("dense_fog_reference", false))
		_revealed_cells = PackedInt32Array()
		if _track_visibility and t.visibility_ready:
			for i in t.visible_cells: fog[i] = 1
		else:
			for i in fog.size():
				if fog[i] == 2: fog[i] = 1
		for u in units.values():
			if u.team == t.id:
				_reveal(fog, u.pos, float(Rules.UNITS[u.type]["vision"]))
		for b in buildings.values():
			if b.team == t.id:
				_reveal(fog, b.center, float(Rules.BUILDINGS[b.type]["vision"]) + b.size * 0.5)
		for scan in orbital_scans:
			if int(scan["team"]) == t.id and int(scan["until"]) > tick:
				_reveal(fog, scan["pos"], float(scan["radius"]))
		t.fog = fog
		if _track_visibility:
			t.visible_cells = _revealed_cells
			t.visibility_ready = true
		# mémoire des structures vues
		for b in buildings.values():
			if b.team == t.id:
				continue
			if fog[idx(cell_of(b.center))] == 2:
				t.memory[b.id] = {"type": b.type, "team": b.team, "pos": b.center, "tick": tick}
				if b.type == "comptoir" and not t.discovered_posts.has(b.id):
					t.discovered_posts.append(b.id)
					emit("comptoir", t.id, "Comptoir neutre découvert", {"building": b.id, "pos": b.center})
		for id in t.memory.keys():
			if not buildings.has(id) and fog[idx(cell_of(t.memory[id]["pos"]))] == 2:
				t.memory.erase(id)
	for scan in orbital_scans.duplicate():
		if int(scan["until"]) <= tick:
			orbital_scans.erase(scan)

func _reveal(fog: PackedByteArray, p: Vector2, r: float) -> void:
	var c := cell_of(p)
	var ri := int(ceil(r))
	var r2 := r * r
	for dy in range(-ri, ri + 1):
		var y := c.y + dy
		if y < 0 or y >= map_size:
			continue
		for dx in range(-ri, ri + 1):
			var x := c.x + dx
			if x < 0 or x >= map_size:
				continue
			if dx * dx + dy * dy <= r2:
				var index: int = y * map_size + x
				if _track_visibility and fog[index] != 2: _revealed_cells.append(index)
				fog[index] = 2

# ---------------------------------------------------------------- conquête

func rebuild_capacity(team_id: int) -> Dictionary:
	## Capacité de reconstruction d'un centre (règle PROVISOIRE, cf. decisions.md D-07).
	var rule_name: String = rule("rebuild_rule", Rules.REBUILD_RULE)
	if not team_buildings(team_id, "centre", true).is_empty():
		return {"capable": true, "reason": "centre debout"}
	var builders := team_units(team_id, "builder")
	if builders.is_empty():
		return {"capable": false, "reason": "aucun ouvrier bâtisseur"}
	var t: Team = teams[team_id]
	var limit_s: float = float(rule("rebuild_timeout", Rules.REBUILD_TIMEOUT))
	if limit_s > 0.0 and t.no_cc_since >= 0 and float(tick - t.no_cc_since) * Rules.DT > limit_s:
		return {"capable": false, "reason": "aucun centre rebâti en %d s" % int(limit_s)}
	if rule_name == "batisseur_seul":
		return {"capable": true, "reason": "ouvrier vivant"}
	if _can_pay(team_id, scaled_cost(Rules.BUILDINGS["centre"]["cost"])):
		return {"capable": true, "reason": "ouvrier + ressources suffisantes"}
	if not team_buildings(team_id, "centre", false).is_empty():
		return {"capable": true, "reason": "ouvrier + fondation de centre"}
	for b in team_buildings(team_id, "", true):
		if Rules.BUILDINGS[b.type].get("drop", false):
			return {"capable": true, "reason": "ouvrier + dépôt pour collecter"}
	return {"capable": false, "reason": "ouvrier sans ressources ni dépôt"}

func _check_conquest() -> void:
	for t in teams:
		if t.id == TEAM_NEUTRAL or t.eliminated:
			continue
		if not team_buildings(t.id, "centre", true).is_empty():
			t.no_cc_since = -1
			continue
		if t.no_cc_since < 0:
			t.no_cc_since = tick
			var limit_s: float = float(rule("rebuild_timeout", Rules.REBUILD_TIMEOUT))
			if limit_s > 0.0:
				emit("sans_centre", t.id, "%s n'a plus de centre : %d s pour en rebâtir un" % [t.name, int(limit_s)], {"timeout": limit_s})
		var cap := rebuild_capacity(t.id)
		if not cap["capable"]:
			t.eliminated = true
			emit("elimine", t.id, "%s éliminé : plus de centre et %s" % [t.name, cap["reason"]], {"reason": cap["reason"]})
	var alive := []
	for t in teams:
		if t.id < 2 and not t.eliminated:
			alive.append(t.id)
	if alive.size() <= 1 and not game_over:
		game_over = true
		winner = alive[0] if alive.size() == 1 else -1
		emit("fin", winner, "Victoire : %s" % (teams[winner].name if winner >= 0 else "aucun"), {"winner": winner})

# ---------------------------------------------------------------- routes et passages

func path_length(path: PackedVector2Array, from: Vector2) -> float:
	var l := 0.0
	var prev := from
	for p in path:
		l += prev.distance_to(p)
		prev = p
	return l

func terrain_path(from: Vector2, to: Vector2) -> Array:
	## Chemin en ignorant les bâtiments (eau seule) : sert à savoir ce qui bloque un passage.
	var a := cell_of(from)
	var b := cell_of(to)
	if astar_terrain.is_point_solid(a) or astar_terrain.is_point_solid(b):
		return []
	return astar_terrain.get_id_path(a, b)

func blocking_structure(team_id: int, from: Vector2, to: Vector2):
	## Première structure ennemie rencontrée sur le chemin « terrain seul ». Null si le terrain lui-même bloque.
	var cells := terrain_path(from, to)
	for c in cells:
		if _occupied.has(c):
			var b = buildings.get(_occupied[c])
			if b != null and b.team != team_id and b.team != TEAM_NEUTRAL:
				return b
	return null

func route_report(from: Vector2, to: Vector2) -> Dictionary:
	## Compare la route praticable à la route « terrain seul » : détour, blocage ou route directe.
	var real := find_path(from, to)
	var terr := terrain_path(from, to)
	var terr_len := 0.0
	for i in range(1, terr.size()):
		terr_len += Vector2(terr[i - 1]).distance_to(Vector2(terr[i]))
	if real.is_empty():
		return {"status": "bloquee" if terr_len > 0 else "impossible", "real": 0.0, "terrain": terr_len}
	var rl := path_length(real, from)
	var ratio: float = rl / max(1.0, terr_len)
	return {"status": "detour" if ratio > 1.3 else "directe", "real": rl, "terrain": terr_len, "ratio": ratio}

# ---------------------------------------------------------------- vue IA (informations du camp uniquement)

func ai_visible_enemies(team_id: int) -> Array:
	var out := []
	for e in enemies_of(team_id):
		for u in team_units(e):
			if is_visible_to(team_id, u.pos):
				out.append(u)
	return out

func ai_memory(team_id: int) -> Dictionary:
	return teams[team_id].memory

# ---------------------------------------------------------------- empreinte d'état (déterminisme)

func state_hash() -> String:
	var parts := PackedStringArray()
	parts.append(str(tick))
	parts.append(var_to_str(modern))
	for team in teams:
		parts.append(var_to_str([team.technologies, team.tech_research]))
	if CivEvolution.enabled(self):
		parts.append(CivEvolution.hash_text(self))
	for team in teams:
		if not team.city.is_empty(): parts.append(var_to_str(team.city.get("pop_bonus", 0)) + var_to_str(team.city.get("habitants", 0)))
	var ids := units.keys()
	ids.sort()
	for id in ids:
		var u: Unit = units[id]
		parts.append("%d:%s:%.3f,%.3f:%.1f" % [id, u.type, u.pos.x, u.pos.y, u.hp])
		parts.append(str(u.supply))
	parts.append(var_to_str(orbital_scans))
	var bids := buildings.keys()
	bids.sort()
	for id in bids:
		parts.append("b%d:%.1f:%.3f" % [id, buildings[id].hp, buildings[id].progress])
	for t in teams:
		parts.append("%.2f,%.2f,%.2f,%d" % [t.res["food"], t.res["wood"], t.res["ore"], t.age])
	return "|".join(parts).sha256_text()

func faction_ids() -> Array:
	return factions.actors()

func ensure_faction(id: int) -> void:
	while teams.size() <= id:
		var team := Team.new()
		team.id = teams.size()
		team.name = String((factions.records.get(team.id, {}) as Dictionary).get("name", "Faction " + str(team.id)))
		team.fog.resize(map_size * map_size)
		team.fog.fill(0)
		teams.append(team)

func labor(team: int) -> float:
	return float(labor_factors.get(team, 1.0))
