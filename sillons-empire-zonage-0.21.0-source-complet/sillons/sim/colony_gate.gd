class_name ColonyGate
extends RefCounted
## J13.1 : lien entre la carte tactique et l'économie planétaire.
## Former une unité prélève des habitants (recrues ou colons) et les équipements fabriqués
## par les zones industrielles ; bâtir un édifice avancé consomme béton, alliage, électronique.
## Objet non sérialisé (reposé par StarCampaign._sync_all) : il ne détient aucune donnée de partie.
var _campaign: WeakRef
var body: String = ""

func _init(c: StarCampaign, p_body: String) -> void:
	_campaign = weakref(c)
	body = p_body

func _colony(team_id: int) -> Dictionary:
	var c: StarCampaign = _campaign.get_ref() as StarCampaign
	if c == null or not c.planets.supply_chain:
		return {}
	return c.planets.colony(team_id, body)

func lack(team_id: int, kind: String, is_unit: bool) -> String:
	## Chaîne vide si la colonie fournit tout ; sinon la cause affichée au joueur.
	var p: Dictionary = _colony(team_id)
	if p.is_empty():
		return ""
	var need: Dictionary = J13Rules.unit_needs(kind) if is_unit else J13Rules.building_needs(kind)
	for raw in need.keys():
		if String(raw) == "people":
			if int(p["pop"]) < int(need[raw]):
				return "habitants insuffisants : %d recrue(s) à loger en zone d'habitation" % int(need[raw])
		elif float((p["stocks"] as Dictionary).get(raw, 0.0)) < float(need[raw]):
			return "industrie : manque %d %s" % [ceili(float(need[raw]) - float((p["stocks"] as Dictionary).get(raw, 0.0))), String(J13Rules.GOOD_LABELS[raw]).to_lower()]
	return ""

func consume(team_id: int, kind: String, is_unit: bool) -> void:
	var p: Dictionary = _colony(team_id)
	if p.is_empty():
		return
	var need: Dictionary = J13Rules.unit_needs(kind) if is_unit else J13Rules.building_needs(kind)
	for raw in need.keys():
		if String(raw) == "people":
			p["pop"] = int(p["pop"]) - int(need[raw])
		else:
			(p["stocks"] as Dictionary)[raw] = float((p["stocks"] as Dictionary)[raw]) - float(need[raw])
