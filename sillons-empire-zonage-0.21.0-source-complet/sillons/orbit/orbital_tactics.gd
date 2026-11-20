class_name OrbitalTactics
extends RefCounted
## Positions et combats à 10 Hz. Les stocks et les vaisseaux restent ceux de la campagne.
const SIZE: float = 160.0
const CENTER := Vector2(80, 80)
const PLANET_RADIUS: float = 22.0
const SPECS := {
	"drone": {"hp": 150.0, "speed": 5.0, "vision": 20.0, "range": 0.0, "damage": 0.0, "delay": 10},
	"sonde": {"hp": 100.0, "speed": 8.0, "vision": 45.0, "range": 0.0, "damage": 0.0, "delay": 10},
	"navette": {"hp": 300.0, "speed": 4.5, "vision": 25.0, "range": 0.0, "damage": 0.0, "delay": 10},
	"intercepteur": {"hp": 300.0, "speed": 8.0, "vision": 30.0, "range": 13.0, "damage": 24.0, "delay": 8},
	"fregate": {"hp": 1100.0, "speed": 3.2, "vision": 40.0, "range": 21.0, "damage": 68.0, "delay": 16}}
static func enable(c: StarCampaign) -> void:
	c.orbital_tactics = true
	reconcile(c)
static func map_for(c: StarCampaign, body: String) -> Dictionary:
	if not c.orbital_maps.has(body): c.orbital_maps[body] = {"size": SIZE, "actors": {}, "rally": {}, "events": [], "last_tick": c.tick}
	return c.orbital_maps[body]
static func color(team: int) -> Color:
	return [Color("69e5de"), Color("ff7c70"), Color("a6b2bc"), Color("c3a0ff"), Color("f0c979"), Color("86d798")][posmod(team, 6)]
static func anchor(team: int) -> Vector2:
	var angle: float = PI + float(team) * PI if team < 2 else float(team) * 2.39996
	return CENTER + Vector2(cos(angle), sin(angle)) * 48.0
static func valid_point(point: Vector2) -> bool:
	return point.is_finite() and point.x >= 3 and point.y >= 3 and point.x <= SIZE - 3 and point.y <= SIZE - 3 and point.distance_to(CENTER) >= PLANET_RADIUS + 2.0
static func _actor(c: StarCampaign, body: String, team: int, kind: String, role: String, point: Vector2, hp: float, reference: int = -1) -> Dictionary:
	point = point.clamp(Vector2.ONE * 4, Vector2.ONE * (SIZE - 4))
	if point.distance_to(CENTER) < PLANET_RADIUS + 2: point = CENTER + (Vector2.LEFT if point.is_equal_approx(CENTER) else (point - CENTER).normalized()) * (PLANET_RADIUS + 6)
	var id: int = c.next_orbit_actor
	c.next_orbit_actor += 1
	var actor: Dictionary = {"id": id, "team": team, "type": kind, "role": role, "pos": point, "prev": point, "hp": hp, "max_hp": hp, "reference": reference, "order": {"type": "hold", "pos": point}, "path": [], "cd": 0, "hit": -100, "level": 1}
	map_for(c, body)["actors"][id] = actor
	return actor
static func _matching(actors: Dictionary, team: int, kind: String, role: String) -> Array:
	var result: Array = []
	var ids: Array = actors.keys()
	ids.sort()
	for id in ids:
		var a: Dictionary = actors[id]
		if int(a["team"]) == team and String(a["type"]) == kind and String(a["role"]) == role: result.append(a)
	return result
static func _spawn_point(c: StarCampaign, body: String, team: int, index: int) -> Vector2:
	var home: Vector2 = anchor(team)
	var hub: Dictionary = OrbitalIndustry.site(c, team, body)
	if hub.has("map_pos"): home = hub["map_pos"]
	var actors:Dictionary=map_for(c,body)["actors"]
	for attempt in 96:
		var serial:int=index+c.next_orbit_actor+attempt
		var angle:float=float(serial)*2.39996
		var radius:float=8.0+float(attempt%5)*4.0
		var point:Vector2=home+Vector2(cos(angle),sin(angle))*radius
		if not valid_point(point):continue
		var occupied:bool=false
		for a in actors.values():
			if (a["pos"] as Vector2).distance_to(point)<(3.6 if String(a["role"])=="unit" else 6.0):occupied=true;break
		if not occupied:return point
	return home+Vector2(0,-8)

static func reconcile(c: StarCampaign) -> void:
	if not c.orbital_tactics: return
	var bodies: Dictionary = {}
	for hub in c.orbital_sites.values(): bodies[String(hub["body"])] = true
	for key in c.orbital_presence:
		var split: PackedStringArray = String(key).split(":", true, 1)
		if split.size() == 2: bodies[split[1]] = true
	for station in c.planets.stations: bodies[String(station["body"])] = true
	for body in c.orbital_maps: bodies[body] = true
	var ordered: Array = bodies.keys()
	ordered.sort()
	for body in ordered:
		var data: Dictionary = map_for(c, String(body))
		var actors: Dictionary = data["actors"]
		for team in c.faction_ids():
			var hub: Dictionary = OrbitalIndustry.site(c, int(team), String(body))
			var hubs: Array = _matching(actors, int(team), "shipyard", "hub")
			if not hub.is_empty() and float(hub.get("hp", 0)) > 0:
				var a: Dictionary = hubs[0] if not hubs.is_empty() else _actor(c, String(body), int(team), "shipyard", "hub", hub.get("map_pos", anchor(int(team))), float(hub["hp"]))
				a["hp"] = float(hub["hp"])
				a["max_hp"] = maxf(float(a["max_hp"]), OrbitalIndustry.BASE_HP + float(int(hub["tier"]) - 1) * 400)
				a["ready"] = int(hub["remaining"]) <= 0
				for kind in OrbitalIndustry.MODULES:
					var target: int = int((hub["modules"] as Dictionary).get(kind, 0))
					var modules: Array = _matching(actors, int(team), String(kind), "module")
					while modules.size() < target:
						var angle: float = float(actors.size()) * 2.39996
						var point: Vector2 = (a["pos"] as Vector2) + Vector2(cos(angle), sin(angle)) * 12.0
						var module: Dictionary = _actor(c, String(body), int(team), String(kind), "module", point, 550.0)
						modules.append(module)
					while modules.size() > target: actors.erase(modules.pop_back()["id"])
			else:
				for a in hubs: actors.erase(a["id"])
				for a in actors.values().duplicate():
					if int(a["team"]) == team and String(a["role"]) == "module": actors.erase(a["id"])
			var stock: Dictionary = c.orbital_presence.get(OrbitalIndustry.key(int(team), String(body)), {}) as Dictionary
			for kind in SPECS:
				var ships: Array = _matching(actors, int(team), String(kind), "unit")
				var target: int = int(stock.get(kind, 0))
				while ships.size() < target:
					var a: Dictionary = _actor(c, String(body), int(team), String(kind), "unit", _spawn_point(c, String(body), int(team), ships.size()), float(SPECS[kind]["hp"]))
					var levels: Dictionary = hub.get("unit_levels", {}) as Dictionary
					a["level"] = int(levels.get(kind, 1))
					a["max_hp"] = float(a["max_hp"]) * (1.0 + 0.15 * float(int(a["level"]) - 1))
					a["hp"] = a["max_hp"]
					if data["rally"].has(team):
						a["order"] = {"type": "move", "pos": data["rally"][team]}
						a["path"] = route(a["pos"], data["rally"][team])
					ships.append(a)
				while ships.size() > target: actors.erase(ships.pop_back()["id"])
		for station in c.planets.stations:
			if String(station["body"]) != body: continue
			var present: bool = false
			for a in actors.values():
				if String(a["role"]) == "command" and int(a["reference"]) == int(station["id"]):
					a["hp"] = station["hp"]; a["max_hp"]=float(J13Rules.STATION_HP); a["ready"] = int(station["remaining"]) == 0; present = true; break
			if not present:
				var point: Vector2 = station.get("map_pos", anchor(int(station["team"])) + Vector2(0, -15))
				var a: Dictionary = _actor(c, String(body), int(station["team"]), "command", "command", point, float(station["hp"]), int(station["id"]))
				a["ready"] = int(station["remaining"]) == 0; a["max_hp"]=float(J13Rules.STATION_HP)
		for a in actors.values().duplicate():
			if String(a["role"]) == "command":
				var exists: bool = false
				for station in c.planets.stations:
					if int(station["id"]) == int(a["reference"]): exists = true; break
				if not exists: actors.erase(a["id"])
static func route(start: Vector2, end: Vector2) -> Array:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(CENTER, start, end)
	if closest.distance_to(CENTER) >= PLANET_RADIUS + 2: return [end]
	var a: float = (start - CENTER).angle()
	var b: float = (end - CENTER).angle()
	var delta: float = wrapf(b - a, -PI, PI)
	var result: Array = []
	var steps: int = maxi(2, ceili(absf(delta) * 6.0))
	for index in range(steps + 1):
		var angle: float = a + delta * float(index) / float(steps)
		result.append(CENTER + Vector2(cos(angle), sin(angle)) * (PLANET_RADIUS + 4))
	result.append(end)
	return result
static func clear_line(a:Vector2,b:Vector2)->bool:
	return Geometry2D.get_closest_point_to_segment(CENTER,a,b).distance_to(CENTER)>=PLANET_RADIUS
static func visible(c: StarCampaign, body: String, team: int, target: Dictionary) -> bool:
	if int(target["team"]) == team: return true
	var actors: Dictionary = map_for(c, body)["actors"]
	for a in actors.values():
		if int(a["team"]) != team: continue
		var radius: float = float(SPECS[a["type"]]["vision"]) if String(a["role"]) == "unit" else 48.0
		if String(a["role"]) == "hub": radius += float((OrbitalIndustry.site(c, team, body).get("modules", {}) as Dictionary).get("radar", 0)) * 16
		if (a["pos"] as Vector2).distance_squared_to(target["pos"]) <= radius * radius and clear_line(a["pos"],target["pos"]): return true
	return false
static func issue(c: StarCampaign, cmd: Dictionary) -> Dictionary:
	var team: int = int(cmd.get("team", -1))
	var body: String = String(cmd.get("body", ""))
	if not c.orbital_tactics or not c.valid_faction(team) or not c.star_catalog.has_body(body) or not c.is_unlocked(team, body): return PlanetCampaign.fail("orbit", "monde connu requis")
	reconcile(c)
	var data: Dictionary = c.orbital_maps.get(body,{"size":SIZE,"actors":{},"rally":{},"events":[],"last_tick":c.tick})
	var actors: Dictionary = data["actors"]
	var action: String = String(cmd.get("action", ""))
	if action in ["hub","command","module","train","upgrade_hub","upgrade_unit"] and c.planets.local_age(c,team,body)<9: return PlanetCampaign.fail("age","âge IX local requis pour construire ou produire")
	var raw_point:Variant=cmd.get("pos",Vector2.ZERO)
	var point:=Vector2(INF,INF)
	if raw_point is Vector2:point=raw_point
	elif raw_point is Array and raw_point.size()==2 and (raw_point[0] is int or raw_point[0] is float) and (raw_point[1] is int or raw_point[1] is float):point=Vector2(float(raw_point[0]),float(raw_point[1]))
	if action in ["move", "amove", "rally", "hub", "command", "module"] and not valid_point(point): return PlanetCampaign.fail("point", "destination libre dans l'orbite requise, hors de la planète")
	if action in ["hub", "command", "module"]:
		for a in actors.values():
			if String(a["role"]) != "unit" and (a["pos"] as Vector2).distance_to(point) < 7: return PlanetCampaign.fail("occupied", "emplacement occupé : espacez les stations de 7 cases")
	var kind: String = String(cmd.get("kind", ""))
	var result: Dictionary
	if action == "rally": data["rally"][team] = point; c.orbital_maps[body]=data; return {"ok": true}
	if action == "hub":
		result = OrbitalIndustry.deploy(c, team, body)
		if bool(result.get("ok", false)): OrbitalIndustry.site(c, team, body)["map_pos"] = point
	elif action == "command":
		result = c.planets.start_station(c, team, body)
		if bool(result.get("ok", false)): c.planets.stations.back()["map_pos"] = point
	elif action in ["train", "module", "upgrade_hub", "upgrade_unit"]:
		if action == "module":
			var hub: Dictionary = OrbitalIndustry.site(c, team, body)
			var center: Vector2 = hub.get("map_pos", anchor(team))
			if point.distance_to(center) > 35: return PlanetCampaign.fail("link", "module à placer à moins de 35 cases du chantier")
		result = OrbitalIndustry.start(c, team, body, "unit" if action == "train" else action, kind)
		if bool(result.get("ok", false)) and action == "module": OrbitalIndustry.site(c, team, body)["job"]["map_pos"] = point
	elif action in ["move", "amove", "hold", "attack", "depart"]:
		var ids: Array = cmd.get("units", []) as Array
		if ids.is_empty() or ids.size() > 128: return PlanetCampaign.fail("selection", "sélectionnez des vaisseaux alliés")
		var selected: Array = []
		var unique: Dictionary = {}
		for id in ids:
			if not id is int or unique.has(id) or not actors.has(id): return PlanetCampaign.fail("selection", "identité de vaisseau invalide")
			var a: Dictionary = actors[id]
			if int(a["team"]) != team or String(a["role"]) != "unit": return PlanetCampaign.fail("owner", "vaisseau allié requis")
			unique[id] = true; selected.append(a)
		var target: int = int(cmd.get("target", -1))
		if action == "attack" and (not actors.has(target) or not c.factions.hostile(team, int(actors[target]["team"])) or not visible(c, body, team, actors[target])): return PlanetCampaign.fail("target", "cible hostile actuellement visible requise")
		if action == "depart":
			var payload: Dictionary = {}
			for a in selected: payload[a["type"]] = int(payload.get(a["type"], 0)) + 1
			result = OrbitalIndustry.send_fleet(c, team, body, String(cmd.get("destination", "")), payload, ids)
		else:
			var slot:int=0
			for a in selected:
				var goal: Vector2 = a["pos"] if action in ["hold","attack"] else point
				if selected.size()>1 and action in ["move","amove"]:
					var offset:=Vector2(cos(float(slot)*2.39996),sin(float(slot)*2.39996))*sqrt(float(slot))*3.6
					var formation:Vector2=point+offset
					if valid_point(formation):goal=formation
				slot+=1
				a["order"] = {"type": action, "pos": goal, "target": target}
				a["path"] = route(a["pos"], goal) if action in ["move", "amove"] else []
			result = {"ok": true}
	else: return PlanetCampaign.fail("action", "ordre orbital inconnu")
	if bool(result.get("ok", false)): reconcile(c)
	return result
static func completed(c: StarCampaign, team: int, body: String, job: Dictionary) -> void:
	if not c.orbital_tactics:return
	if String(job["mode"])=="module" and job.has("map_pos"):_actor(c,body,team,String(job["kind"]),"module",job["map_pos"],550.0)
	elif String(job["mode"])=="upgrade_unit":
		var kind:String=String(job["kind"])
		var target:int=int(OrbitalIndustry.site(c,team,body)["unit_levels"].get(kind,1))
		for actor in _matching(map_for(c,body)["actors"],team,kind,"unit"):
			if int(actor["level"])>=target:continue
			var ratio:float=float(actor["hp"])/float(actor["max_hp"])
			actor["level"]=target;actor["max_hp"]=float(SPECS[kind]["hp"])*(1+0.15*float(target-1));actor["hp"]=float(actor["max_hp"])*ratio
static func arrived(c: StarCampaign, flight: Dictionary) -> void:
	var team: int = int(flight["team"])
	var body: String = String(flight["to"])
	var manifest: Dictionary = flight["units"]
	var stock: Dictionary = OrbitalIndustry.presence(c, team, body)
	var index: int = 0
	var identities: Array = flight.get("tactical_units", []) as Array
	for kind in manifest:
		for count in int(manifest[kind]):
			stock[kind] = int(stock.get(kind, 0)) + 1
			var point: Vector2 = Vector2(8, 48 + index * 3) if team == 0 else Vector2(152, 48 + index * 3)
			var a: Dictionary = _actor(c, body, team, String(kind), "unit", point, float(SPECS[kind]["hp"]))
			if index < identities.size() and String(identities[index]["type"]) == kind:
				a["level"] = int(identities[index]["level"])
				a["max_hp"] = float(a["max_hp"]) * (1 + 0.15 * float(int(a["level"]) - 1))
				a["hp"] = float(a["max_hp"]) * float(identities[index]["hp_ratio"])
			a["order"] = {"type": "amove", "pos": _spawn_point(c, body, team, index)}
			a["path"] = route(point, a["order"]["pos"])
			index += 1
	c._notice(team, "Flotte arrivée sur la carte orbitale", body)
static func _hostile_target(c: StarCampaign, body: String, a: Dictionary, range_value: float) -> int:
	var best: int = -1
	var distance: float = range_value * range_value
	var actors: Dictionary = map_for(c, body)["actors"]
	var ids: Array = actors.keys(); ids.sort()
	for id in ids:
		var b: Dictionary = actors[id]
		var d: float = (a["pos"] as Vector2).distance_squared_to(b["pos"])
		if d>=distance or not c.factions.hostile(int(a["team"]),int(b["team"])):continue
		if visible(c,body,int(a["team"]),b):distance=d;best=int(id)
	return best
static func _destroy(c: StarCampaign, body: String, a: Dictionary) -> void:
	var team: int = int(a["team"])
	var kind: String = String(a["type"])
	var role: String = String(a["role"])
	if role == "unit":
		var stock: Dictionary = OrbitalIndustry.presence(c, team, body)
		stock[kind] = maxi(0, int(stock.get(kind, 0)) - 1)
	elif role == "module":
		var hub: Dictionary = OrbitalIndustry.site(c, team, body)
		if not hub.is_empty(): hub["modules"][kind] = maxi(0, int(hub["modules"].get(kind, 0)) - 1)
	elif role == "hub":
		c.orbital_sites.erase(OrbitalIndustry.key(team, body))
		for module in map_for(c,body)["actors"].values().duplicate():
			if int(module["team"])==team and String(module["role"])=="module": map_for(c,body)["actors"].erase(module["id"])
	elif role == "command":
		for station in c.planets.stations.duplicate():
			if int(station["id"]) == int(a["reference"]): c.planets.stations.erase(station); break
	map_for(c, body)["actors"].erase(a["id"])
	c._record_notice(team, "Perte en orbite : " + kind, body)
static func step(c: StarCampaign) -> void:
	if not c.orbital_tactics: return
	reconcile(c)
	var bodies: Array = c.orbital_maps.keys(); bodies.sort()
	for body in bodies:
		var data: Dictionary = c.orbital_maps[body]
		var actors: Dictionary = data["actors"]
		data["last_tick"] = c.tick
		data["events"] = []
		var ids: Array = actors.keys(); ids.sort()
		for id in ids:
			if not actors.has(id): continue
			var a: Dictionary = actors[id]
			a["prev"] = a["pos"]
			a["cd"] = maxi(0, int(a["cd"]) - 1)
			var unit: bool = String(a["role"]) == "unit"
			var spec: Dictionary = SPECS[a["type"]] if unit else {"range": 28.0, "damage": 32.0, "delay": 12, "speed": 0.0}
			if not unit and (String(a["role"]) == "module" and String(a["type"]) != "batterie"): continue
			if not unit and not bool(a.get("ready", true)): continue
			var order: Dictionary = a["order"]
			var action: String = String(order["type"])
			var target: int = int(order.get("target", -1)) if action == "attack" else -1
			if not actors.has(target) or (target >= 0 and (not c.factions.hostile(int(a["team"]), int(actors[target]["team"])) or not visible(c, String(body), int(a["team"]), actors[target]))): target = -1
			if target < 0 and action != "move" and float(spec["damage"]) > 0: target = _hostile_target(c, String(body), a, float(spec["range"]))
			if target >= 0 and float(spec["damage"]) > 0:
				var b: Dictionary = actors[target]
				var dist: float = (a["pos"] as Vector2).distance_to(b["pos"])
				if dist <= float(spec["range"]) and clear_line(a["pos"],b["pos"]):
					if int(a["cd"]) <= 0:
						var damage: float = float(spec["damage"]) * (1.0 + float(int(a["level"]) - 1) * 0.15)
						b["hp"] = float(b["hp"]) - damage
						b["hit"] = c.tick
						a["cd"] = int(spec["delay"])
						data["events"].append({"from": a["pos"], "to": b["pos"], "team": a["team"]})
						if String(b["role"]) == "hub": OrbitalIndustry.site(c, int(b["team"]), String(body))["hp"] = b["hp"]
						elif String(b["role"]) == "command":
							for station in c.planets.stations:
								if int(station["id"]) == int(b["reference"]): station["hp"] = b["hp"]; break
						if float(b["hp"]) <= 0: _destroy(c, String(body), b)
					continue
				elif unit and action == "attack" and (a["path"] as Array).is_empty(): a["path"] = route(a["pos"], b["pos"])
			if not unit: continue
			if action == "attack" and target < 0: a["order"] = {"type": "hold", "pos": a["pos"]}; a["path"] = []
			if not (a["path"] as Array).is_empty():
				var point: Vector2 = a["path"][0]
				a["pos"] = (a["pos"] as Vector2).move_toward(point, float(spec["speed"]) * Rules.DT)
				if (a["pos"] as Vector2).distance_to(point) < 0.1: a["path"].pop_front()
				if (a["path"] as Array).is_empty() and action in ["move", "amove"]: a["order"] = {"type": "hold", "pos": a["pos"]}
		# IA locale sans information cachée ; elle contrôle réellement ses vaisseaux.
		if c.tick % 20 == 0:
			for a in actors.values():
				if int(a["team"]) == 0 or String(a["role"]) != "unit" or String(a["order"]["type"]) != "hold" or float(SPECS[a["type"]]["damage"]) == 0: continue
				var target: int = _hostile_target(c, String(body), a, float(SPECS[a["type"]]["vision"]))
				if target >= 0:
					a["order"] = {"type": "attack", "target": target, "pos": actors[target]["pos"]}
					a["path"] = route(a["pos"], actors[target]["pos"])
static func number(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value))
static func validate(c:StarCampaign)->bool:
	if c.next_orbit_actor<1 or c.orbital_maps.size()>StarSystemGenerator.MAX_BODIES:return false
	var seen:Dictionary={}
	for body in c.orbital_maps:
		if not body is String or not c.star_catalog.has_body(body) or not c.orbital_maps[body] is Dictionary:return false
		var data:Dictionary=c.orbital_maps[body]
		if not data.get("actors") is Dictionary or not data.get("rally") is Dictionary or not data.get("events") is Array:return false
		if data["actors"].size()>8192 or data["events"].size()>8192 or not data.get("last_tick") is int or int(data["last_tick"])<0 or int(data["last_tick"])>c.tick:return false
		for team in data["rally"]:
			if not team is int or not c.valid_faction(team) or not data["rally"][team] is Vector2 or not valid_point(data["rally"][team]):return false
		for event in data["events"]:
			if not event is Dictionary or not event.get("team") is int or not c.valid_faction(int(event["team"])):return false
			for field in ["from","to"]:
				if not event.get(field) is Vector2 or not valid_point(event[field]):return false
		for id in data["actors"]:
			var a:Variant=data["actors"][id]
			if not a is Dictionary or not id is int or not a.get("id") is int or a["id"]!=id or id<1 or id>=c.next_orbit_actor or seen.has(id):return false
			seen[id]=true
			if not a.get("team") is int or not c.valid_faction(int(a["team"])) or a.get("role","") not in ["unit","hub","module","command"]:return false
			for field in ["pos","prev"]:
				if not a.get(field) is Vector2 or not valid_point(a[field]):return false
			if not a.get("order") is Dictionary or not a.get("path") is Array or a["path"].size()>64:return false
			if not number(a.get("hp")) or not number(a.get("max_hp")) or float(a["hp"])<=0 or float(a["max_hp"])<float(a["hp"]) or float(a["max_hp"])>100000:return false
			if not a.get("level") is int or int(a["level"])<1 or int(a["level"])>3 or not a.get("cd") is int or int(a["cd"])<0 or int(a["cd"])>1000 or not a.get("hit") is int:return false
			var role:String=String(a["role"]);var kind:String=String(a.get("type",""))
			if role=="unit" and not SPECS.has(kind):return false
			if role=="module" and not OrbitalIndustry.MODULES.has(kind):return false
			if role=="hub" and kind!="shipyard":return false
			if role=="command":
				if kind!="command" or not a.get("reference") is int:return false
				var referenced:bool=false
				for station in c.planets.stations:
					if int(station["id"])==int(a["reference"]) and int(station["team"])==int(a["team"]) and String(station["body"])==body:referenced=true
				if not referenced:return false
			if a["order"].get("type","") not in ["hold","move","amove","attack"]:return false
			if not a["order"].get("pos") is Vector2 or not valid_point(a["order"]["pos"]):return false
			for waypoint in a["path"]:
				if not waypoint is Vector2 or not valid_point(waypoint):return false
		for team in c.faction_ids():
			var stock:Dictionary=c.orbital_presence.get(OrbitalIndustry.key(team,body),{})
			for kind in SPECS:
				if _matching(data["actors"],team,kind,"unit").size()!=int(stock.get(kind,0)):return false
			var hub:Dictionary=OrbitalIndustry.site(c,team,body)
			if _matching(data["actors"],team,"shipyard","hub").size()!=(0 if hub.is_empty() else 1):return false
			for kind in OrbitalIndustry.MODULES:
				if _matching(data["actors"],team,kind,"module").size()!=int((hub.get("modules",{}) as Dictionary).get(kind,0)):return false
	for flight in c.orbital_flights:
		if not flight is Dictionary or not flight.get("units") is Dictionary:return false
		var count:int=0
		for kind in flight["units"]:
			if not SPECS.has(kind) or not flight["units"][kind] is int or int(flight["units"][kind])<1:return false
			count+=int(flight["units"][kind])
		if count<1 or count>12:return false
		if flight.has("tactical_units"):
			if not flight["tactical_units"] is Array or flight["tactical_units"].size()!=count:return false
			var manifest:Dictionary={}
			for unit in flight["tactical_units"]:
				if not unit is Dictionary or not SPECS.has(unit.get("type","")) or not unit.get("level") is int or int(unit["level"]) not in [1,2,3]:return false
				if not number(unit.get("hp_ratio")) or float(unit["hp_ratio"])<=0 or float(unit["hp_ratio"])>1:return false
				manifest[unit["type"]]=int(manifest.get(unit["type"],0))+1
			if manifest!=flight["units"]:return false
	return true

static func detach(c:StarCampaign,body:String,team:int,payload:Dictionary,preferred:Array)->Array:
	var actors:Dictionary=map_for(c,body)["actors"]
	var ids:Array=preferred.duplicate() if not preferred.is_empty() else actors.keys()
	ids.sort()
	var result:Array=[]
	for kind in payload:
		var remaining:int=int(payload[kind])
		for id in ids:
			if remaining<=0:break
			if not actors.has(id):continue
			var a:Dictionary=actors[id]
			if int(a["team"])!=team or String(a["role"])!="unit" or String(a["type"])!=kind:continue
			result.append({"type":kind,"hp_ratio":float(a["hp"])/float(a["max_hp"]),"level":a["level"]})
			actors.erase(id);remaining-=1
	return result
