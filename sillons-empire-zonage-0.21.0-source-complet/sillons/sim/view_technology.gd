class_name ViewTechnology
extends RefCounted
## Déblocages déterministes par camp. Le monde et la caméra ne créent aucun acquis.
## Les technologies sont sérialisées dans StarCampaign.technologies.

const PATH := [
	{"view": "tactical", "label": "Terrain tactique", "age": 1, "tech": ""},
	{"view": "planet", "label": "Globe planétaire", "age": 2, "tech": "cartographie"},
	{"view": "orbit", "label": "Espace orbital", "age": 9, "tech": "observation_orbitale"},
	{"view": "system", "label": "Système stellaire", "age": 9, "tech": "navigation_interplanetaire"},
	{"view": "galaxy", "label": "Carte galactique", "age": 10, "tech": "cartographie_galactique"},
]
const RESEARCH_ORDER := ["cartographie", "observation_orbitale", "navigation_interplanetaire", "navigation_stellaire", "cartographie_galactique"]

static func get_status(age: int, unlocked: Dictionary, level: String) -> Dictionary:
	if level == "tactical":
		return {"ok": true, "reason": "", "label": "Terrain tactique"}
	var required_age: int = 1
	var name: String = ""
	var found: bool = false
	for step in PATH:
		if String(step["view"]) == level:
			required_age = int(step["age"])
			name = String(step["label"])
			found = true
			break
	if not found:
		return {"ok": false, "reason": "Vue inconnue", "label": level}
	if age < required_age:
		return {"ok": false, "reason": "%s : âge %d requis (actuel : %d)" % [name, required_age, age], "label": name}
	for step in PATH:
		if String(step["view"]) == "tactical":
			continue
		var prerequisite_view: String = String(step["view"])
		var key: String = String(step["tech"])
		if not unlocked.has(key):
			return {"ok": false, "reason": "%s verrouillé : rechercher %s" % [name, String(Rules.TECHNOLOGIES[key]["label"])], "label": name}
		if prerequisite_view == level:
			break
	# La recherche navigation_stellaire est l'étape intermédiaire du chemin galactique.
	if level == "galaxy" and not unlocked.has("navigation_stellaire"):
		return {"ok": false, "reason": "Navigation stellaire requise", "label": name}
	return {"ok": true, "reason": "", "label": name}

static func can_open(age: int, unlocked: Dictionary, level: String) -> bool:
	return bool(get_status(age, unlocked, level)["ok"])
