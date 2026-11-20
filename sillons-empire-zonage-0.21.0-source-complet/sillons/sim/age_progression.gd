class_name AgeProgression
extends RefCounted
## J12.2 : améliorations LOCALES au bâtiment producteur. Pas d'amélioration implicite par âge.
## Un bâtiment peut conduire une recherche à la fois, indépendante de la recherche globale.
## Les caractéristiques d'une unité sont figées par son évolution, même après destruction de sa caserne.

const TROOP_STYLES := {
	"ouvrier": ["Pionnier", "Artisan spécialisé", "Technicien d'empire"],
	"eclaireur": ["Éclaireur léger", "Reconnaissance montée", "Reconnaissance vétérane"],
	"lancier": ["Milice de piques", "Lancier équipé", "Garde d'élite"],
	"tireur": ["Tireur de ligne", "Tireur régulier", "Tireur d'élite"],
	"cavalier": ["Cavalier léger", "Cavalier cuirassé", "Cavalerie vétérane"],
	"canon": ["Canon de campagne", "Canon renforcé", "Artillerie de siège"],
	"caravane": ["Convoi marchand", "Caravane protégée", "Convoi impérial"],
	"fusilier": ["Fusilier industriel", "Fusilier mécanisé", "Infanterie d'assaut"],
	"obusier": ["Obusier mobile", "Obusier stabilisé", "Artillerie avancée"],
	"grenadier": ["Grenadier impérial", "Grenadier blindé", "Grenadier d'assaut"],
	"char": ["Char de série", "Char modernisé", "Char lourd avancé"],
	"avion": ["Avion d'attaque", "Avion modernisé", "Chasseur tactique"],
	"antiaerien": ["Défense mobile", "Défense radar", "Batterie intégrée"],
	"train": ["Train logistique", "Train protégé", "Convoi ferroviaire lourd"],
	"lance_missiles": ["Lanceur conventionnel", "Lanceur guidé", "Lanceur avancé"],
	"drone": ["Drone tactique", "Drone autonome", "Drone de combat avancé"],
	"brouilleur": ["Brouilleur mobile", "Brouilleur coordonné", "Guerre électronique intégrée"],
	"navette": ["Navette orbitale", "Navette renforcée", "Transport interplanétaire"],
	"fregate": ["Frégate de ligne", "Frégate améliorée", "Frégate de commandement"],
}
const BUILDING_STYLES := {
	"centre": ["Centre pionnier", "Hôtel de commandement", "Citadelle impériale"],
	"caserne": ["Caserne de milice", "Caserne régulière", "Caserne d'élite"],
	"atelier": ["Atelier de siège", "Arsenal mécanisé", "Arsenal renforcé"],
	"usine": ["Usine industrielle", "Complexe mécanisé", "Complexe militaire avancé"],
	"aerodrome": ["Piste militaire", "Base aérienne", "Base aérienne intégrée"],
	"gare": ["Gare logistique", "Gare protégée", "Terminal intermodal"],
	"spatioport": ["Port orbital", "Plateforme avancée", "Complexe orbital"],
	"chantier_orbital": ["Chantier orbital", "Arsenal stellaire", "Chantier interstellaire"],
	"marche": ["Marché local", "Bourse marchande", "Marché impérial"],
	"fort": ["Fort de pierre", "Forteresse renforcée", "Bastion avancé"],
}

static func building_name(kind: String, tier: int) -> String:
	var names: Array = BUILDING_STYLES.get(kind, []) as Array
	if names.is_empty():
		return String(Rules.BUILDINGS[kind]["label"]) + " · niveau %d" % clampi(tier, 1, 3)
	return String(names[clampi(tier, 1, 3) - 1])

static func troop_name(kind: String, tier: int) -> String:
	var names: Array = TROOP_STYLES.get(kind, []) as Array
	if names.is_empty():
		return String(Rules.UNITS[kind]["label"])
	return String(names[clampi(tier, 1, 3) - 1])

static func required_age(base: int, target: int) -> int:
	# Les recherches tardives évoluent à l'intérieur de l'âge X.
	return mini(10, base + target - 1)

static func hp_multiplier(level: int) -> float:
	return 1.0 + 0.12 * float(clampi(level, 1, 3) - 1)

static func attack_multiplier(level: int) -> float:
	return 1.0 + 0.10 * float(clampi(level, 1, 3) - 1)

static func building_hp_multiplier(level: int) -> float:
	return 1.0 + 0.20 * float(clampi(level, 1, 3) - 1)

static func production_multiplier(level: int) -> float:
	return 1.0 + 0.10 * float(clampi(level, 1, 3) - 1)

static func building_cost(kind: String, target: int) -> Dictionary:
	var raw: Dictionary = Rules.BUILDINGS[kind]["cost"]
	var out: Dictionary = {}
	for resource in Rules.RESOURCES:
		var original: float = float(raw.get(resource, 0.0))
		if original > 0.0:
			out[resource] = ceili(original * (0.75 if target == 2 else 1.2))
	return out

static func troop_cost(kind: String, target: int) -> Dictionary:
	var raw: Dictionary = Rules.UNITS[kind]["cost"]
	var out: Dictionary = {}
	for resource in Rules.RESOURCES:
		var original: float = float(raw.get(resource, 0.0))
		if original > 0.0:
			out[resource] = ceili(original * (2.5 if target == 2 else 4.0))
	return out

static func building_duration(target: int) -> float:
	return 30.0 if target == 2 else 48.0

static func troop_duration(target: int) -> float:
	return 24.0 if target == 2 else 38.0

static func upgrade_status(w: SimWorld, team: int, b: SimWorld.Building, mode: String, unit_kind: String = "") -> Dictionary:
	var target: int = 1
	var base_age: int = 1
	if b == null or b.team != team or not b.complete or team < 0 or team >= 2:
		return {"ok": false, "reason": "bâtiment allié achevé requis", "target": target}
	if b.type == "comptoir":
		return {"ok": false, "reason": "bâtiment neutre", "target": target}
	if mode == "building":
		target = b.tier + 1
		base_age = int(Rules.BUILDINGS[b.type].get("age", 1))
	elif mode == "troop":
		var trains: Array = Rules.BUILDINGS[b.type].get("trains", []) as Array
		if not Rules.UNITS.has(unit_kind) or not trains.has(unit_kind):
			return {"ok": false, "reason": "ce bâtiment ne produit pas cette troupe", "target": target}
		target = int(b.unit_evolutions.get(unit_kind, 1)) + 1
		base_age = int(Rules.UNITS[unit_kind].get("age", 1))
	else:
		return {"ok": false, "reason": "voie d'évolution inconnue", "target": target}
	if target > 3:
		return {"ok": false, "reason": "niveau maximal", "target": target}
	if not b.upgrade_job.is_empty():
		return {"ok": false, "reason": "évolution déjà en cours", "target": target}
	if mode == "troop" and not CivEvolution.troop_upgrade_allowed(w, team, unit_kind):
		return {"ok": false, "reason": "unité non disponible pour ce camp", "target": target}
	if mode == "troop" and b.tier < target:
		return {"ok": false, "reason": "améliorer d'abord le bâtiment au niveau %d" % target, "target": target}
	var required: int = required_age(base_age, target)
	if (w.teams[team] as SimWorld.Team).age < required:
		return {"ok": false, "reason": "âge %d requis" % required, "target": target}
	var raw: Dictionary = building_cost(b.type, target) if mode == "building" else troop_cost(unit_kind, target)
	var cost: Dictionary = w.scaled_cost(raw)
	if not w._can_pay(team, cost):
		return {"ok": false, "reason": w._missing_text(team, cost), "target": target, "cost": cost}
	return {"ok": true, "reason": "", "target": target, "cost": cost}

static func start_upgrade(w: SimWorld, team: int, cmd: Dictionary) -> Dictionary:
	var mode: String = "building" if String(cmd.get("t", "")) == "upgrade_building" else "troop"
	var b: SimWorld.Building = w.buildings.get(int(cmd.get("building", -1))) as SimWorld.Building
	var kind: String = String(cmd.get("unit", ""))
	var status: Dictionary = upgrade_status(w, team, b, mode, kind)
	if not bool(status["ok"]):
		return w._no(String(status["reason"]))
	w._pay(team, status["cost"])
	var target: int = int(status["target"])
	b.upgrade_job = {"mode": mode, "unit": kind, "target": target,
		"remaining": building_duration(target) if mode == "building" else troop_duration(target)}
	w.emit("evolution", team, "Évolution lancée : %s niveau %d" % [b.type if mode == "building" else kind, target], {"building": b.id})
	return w._ok()

static func apply_unit_level(u: SimWorld.Unit, level: int) -> void:
	var next_level: int = clampi(level, 1, 3)
	var health_ratio: float = clampf(u.hp / maxf(1.0, u.max_hp), 0.0, 1.0)
	u.evolution = next_level
	u.max_hp = float(Rules.UNITS[u.type]["hp"]) * hp_multiplier(next_level)
	u.hp = maxf(0.0, health_ratio * u.max_hp)

static func complete_job(w: SimWorld, b: SimWorld.Building) -> void:
	var job: Dictionary = b.upgrade_job
	var mode: String = String(job.get("mode", ""))
	var target: int = int(job.get("target", 1))
	if mode == "building":
		var ratio: float = clampf(b.hp / maxf(1.0, b.max_hp), 0.0, 1.0)
		b.tier = clampi(target, 1, 3)
		b.max_hp = float(Rules.BUILDINGS[b.type]["hp"]) * building_hp_multiplier(b.tier)
		b.hp = maxf(1.0, b.max_hp * ratio)
		w.emit("evolution", b.team, "%s amélioré (niveau %d)" % [building_name(b.type, b.tier), b.tier], {"building": b.id})
	elif mode == "troop":
		var kind: String = String(job.get("unit", ""))
		if not Rules.UNITS.has(kind):
			b.upgrade_job = {}
			return
		b.unit_evolutions[kind] = clampi(target, 1, 3)
		# Moderniser uniquement les unités originaires de CET établissement.
		for unit in w.units.values():
			if unit.team == b.team and unit.origin_building == b.id and unit.type == kind:
				apply_unit_level(unit, target)
		w.emit("evolution", b.team, "Équipement disponible : %s" % troop_name(kind, target), {"building": b.id})
	b.upgrade_job = {}

static func job_signature(b: SimWorld.Building) -> String:
	if b.upgrade_job.is_empty():
		return ""
	return "%s:%s:%d" % [String(b.upgrade_job.get("mode", "")), String(b.upgrade_job.get("unit", "")), int(b.upgrade_job.get("target", 1))]

static func step(w: SimWorld) -> void:
	for b in w.buildings.values():
		if b.team >= 2 or not b.complete or b.upgrade_job.is_empty():
			continue
		b.upgrade_job["remaining"] = float(b.upgrade_job["remaining"]) - Rules.DT * CivEvolution.speed_mult(w, b.team, "research_speed")
		if float(b.upgrade_job["remaining"]) <= 0.0:
			complete_job(w, b)
