class_name FactionRegistry
extends RefCounted
## Stable identities. Neutral 2 remains non-combatant; rebel identities start at 3.
var records: Dictionary = {0: {"name": "Joueur", "kind": "empire", "home": "val"}, 1: {"name": "Adversaire", "kind": "empire", "home": "val"}, 2: {"name": "Neutre", "kind": "neutral", "home": ""}}
var relations: Dictionary = {"0:1": "war"}
var rebels: Dictionary = {}
var next_id: int = 3

func actors() -> Array:
	var result: Array = []
	for id in records:
		if int(id) != 2: result.append(int(id))
	result.sort()
	return result

static func pair(a: int, b: int) -> String:
	return "%d:%d" % [mini(a,b), maxi(a,b)]

func relation(a: int, b: int) -> String:
	if a == b: return "allied"
	if a == 2 or b == 2: return "neutral"
	return String(relations.get(pair(a,b), "neutral"))

func hostile(a: int, b: int) -> bool:
	return relation(a,b) == "war"

func set_relation(a: int, b: int, value: String) -> bool:
	if a == b or a == 2 or b == 2 or not records.has(a) or not records.has(b): return false
	if value not in ["war", "neutral", "truce", "trade", "allied", "federated", "autonomous"]: return false
	relations[pair(a,b)] = value
	return true

func enemies(team: int) -> Array:
	var result: Array = []
	for id in actors():
		if hostile(team, int(id)): result.append(int(id))
	return result

func allocate(name: String, body: String, kind: String = "independent") -> int:
	if kind == "rebel" and rebels.has(body): return int(rebels[body])
	var id: int = next_id
	next_id += 1
	records[id] = {"name": name.left(96), "kind": kind, "home": body}
	if kind == "rebel": rebels[body] = id
	return id

func snapshot() -> Dictionary:
	return {"records": records, "relations": relations, "rebels": rebels, "next_id": next_id}.duplicate(true)

static func from_snapshot(data: Dictionary) -> FactionRegistry:
	if not data.get("records") is Dictionary or not data.get("relations") is Dictionary or not data.get("rebels") is Dictionary: return null
	var result := FactionRegistry.new()
	var raw: Dictionary = data["records"] as Dictionary
	if raw.size() < 3 or raw.size() > 512: return null
	for i in raw.size():
		if not raw.has(i) or not raw[i] is Dictionary: return null
		var record: Dictionary = raw[i] as Dictionary
		if not record.get("name") is String or String(record["name"]).length() > 96 or record.get("kind") not in ["empire", "neutral", "independent", "rebel"]: return null
	for key in (data["relations"] as Dictionary):
		if not key is String: return null
		var parts: PackedStringArray = String(key).split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return null
		if not raw.has(int(parts[0])) or not raw.has(int(parts[1])): return null
		if data["relations"][key] not in ["war", "neutral", "truce", "trade", "allied", "federated", "autonomous"]: return null
	for body in data["rebels"]:
		if not body is String or not data["rebels"][body] is int: return null
		var actor: int = int(data["rebels"][body])
		if actor < 3 or not raw.has(actor) or String(raw[actor]["kind"]) != "rebel" or String(raw[actor].get("home", "")) != body: return null
	if int(data.get("next_id", -1)) != raw.size(): return null
	result.records = raw.duplicate(true)
	result.relations = (data["relations"] as Dictionary).duplicate(true)
	result.rebels = (data["rebels"] as Dictionary).duplicate(true)
	result.next_id = int(data["next_id"])
	return result
