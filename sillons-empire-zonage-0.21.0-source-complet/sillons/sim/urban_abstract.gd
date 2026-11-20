class_name UrbanAbstract
extends RefCounted
## 0.20 — Villes à plusieurs échelles. Le monde affiché calcule sa ville en détail (toutes les 2 s) ; les mondes
## lointains (autres régions, planètes, systèmes) gardent les mêmes règles avec un calcul abrégé (une période sur
## UrbanRules.FAR_EVERY, durées et probabilités ajustées : UrbanCity.time_scale). Ici : résumés en lecture seule,
## d'une ville (vue planète) et de toutes les villes d'un camp (vues orbite, système, galaxie). Aucune règle.

static func summary(w: SimWorld, team: int) -> Dictionary:
	var t: SimWorld.Team = w.teams[team]
	var c: Dictionary = t.city
	var buildings: int = 0
	var sites: int = 0
	var ruins: int = 0
	for candidate in w.team_buildings(team):
		var b: SimWorld.Building = candidate as SimWorld.Building
		if UrbanRules.is_zone(b.type):
			if b.complete:
				buildings += 1
			else:
				sites += 1
		elif b.type == "ruine":
			ruins += 1
	return {"habitants": int(c.get("habitants", 0)), "buildings": buildings, "sites": sites, "ruins": ruins,
		"level_avg": float(c.get("level_avg", 0.0)), "wealth": float(c.get("wealth_avg", 0.0)), "crime": float(c.get("crime_avg", 0.0)),
		"production": (c.get("production", {}) as Dictionary).duplicate(), "burning": int(c.get("burning", 0)),
		"riots": int(c.get("riots", 0)), "settlement": String(c.get("settlement", "")), "far": w.urban_far,
		"events": UrbanEvents.labels(t), "has_city": not c.is_empty() and (buildings + sites) > 0}

static func world_label(key: String) -> String:
	if StarCampaign.DEFINITIONS.has(key):
		return String((StarCampaign.DEFINITIONS[key] as Dictionary)["label"])
	return key.capitalize()

static func empire(campaign: StarCampaign, team: int) -> Dictionary:
	## Toutes les villes du camp, monde par monde, et les totaux (vues orbite, système, galaxie).
	var out: Dictionary = {"worlds": [], "habitants": 0, "buildings": 0, "production": {"food": 0.0, "wood": 0.0, "ore": 0.0}, "far": 0}
	if campaign == null:
		return out
	var keys: Array = campaign.worlds.keys()
	keys.sort()
	for key in keys:
		var w: SimWorld = campaign.worlds[key]
		if team < 0 or team >= w.teams.size():
			continue
		var s: Dictionary = summary(w, team)
		if not bool(s["has_city"]):
			continue
		s["key"] = String(key)
		s["label"] = world_label(String(key))
		(out["worlds"] as Array).append(s)
		out["habitants"] = int(out["habitants"]) + int(s["habitants"])
		out["buildings"] = int(out["buildings"]) + int(s["buildings"])
		for res in (out["production"] as Dictionary).keys():
			out["production"][res] = float(out["production"][res]) + float((s["production"] as Dictionary).get(res, 0.0))
		if bool(s["far"]):
			out["far"] = int(out["far"]) + 1
	return out

static func empire_line(campaign: StarCampaign, team: int) -> String:
	var e: Dictionary = empire(campaign, team)
	var worlds: Array = e["worlds"] as Array
	if worlds.is_empty():
		return ""
	var p: Dictionary = e["production"] as Dictionary
	return "Villes : %d monde(s) · %d habitants · %d bâtiments · +%.1f vivres/s · +%.1f bois/s · +%.1f minerai/s" % [
		worlds.size(), int(e["habitants"]), int(e["buildings"]), float(p["food"]), float(p["wood"]), float(p["ore"])]
