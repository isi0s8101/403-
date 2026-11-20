class_name Theater
extends RefCounted
## Test technique « deux fronts » : deux simulations indépendantes (deux cartes, deux graines)
## avancées en parallèle au même pas fixe. Un seul front est affiché à la fois ; l'autre continue
## de tourner sans rendu. Mesure le temps de simulation de chaque front, tick par tick.

const FRONT_FILES := ["res://lab/fronts/front_a_gue.json", "res://lab/fronts/front_b_plaine.json"]
const LOAD_LEVELS := [40, 100, 200, 400]   # unités visées par front (bâtiments exclus)

var fronts: Array = []          # LabScenario
var sim_ms: Array = [0.0, 0.0]  # durée du dernier tick de chaque front
var sim_ms_peak: Array = [0.0, 0.0]
var level := 40

static func _base_units(data: Dictionary) -> Dictionary:
	## Unités hors groupes « scalable » (départ standard + placements isolés), et total des groupes.
	var base := 0
	if bool(data.get("standard_start", true)):
		base += 2 * (int(Rules.START["workers"]) + int(Rules.START["scouts"]))
	var scal := 0
	for c in data.get("setup", []):
		if c.get("t", "") == "lab_spawn":
			base += 1
		elif c.get("t", "") == "spawn_group":
			if bool(c.get("scalable", false)):
				scal += int(c["count"])
			else:
				base += int(c["count"])
	return {"base": base, "scalable": scal}

func build(p_level: int) -> void:
	level = p_level
	fronts.clear()
	for f in FRONT_FILES:
		var sc := LabScenario.load_file(f)
		sc.quiet = true
		var b := _base_units(sc.data)
		sc.load_scale = maxf(0.05, float(p_level - int(b["base"])) / float(max(1, int(b["scalable"]))))
		sc.build()
		sc.world.log_events = true
		fronts.append(sc)
	sim_ms = [0.0, 0.0]
	sim_ms_peak = [0.0, 0.0]

func world(i: int) -> SimWorld:
	return fronts[i].world

func step() -> void:
	## Un tick sur chaque front, dans un ordre fixe. Le rendu n'intervient jamais ici.
	for i in fronts.size():
		var t0 := Time.get_ticks_usec()
		fronts[i].step()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		sim_ms[i] = ms
		sim_ms_peak[i] = maxf(sim_ms_peak[i], ms)

func take_events(i: int) -> Array:
	## Événements destinés à la vue ; vidés pour les deux fronts, affichés ou non (même traitement).
	var w: SimWorld = fronts[i].world
	var ev := w.events.duplicate()
	w.events.clear()
	return ev

func unit_count(i: int) -> int:
	return fronts[i].world.units.size()

func sieging(i: int) -> bool:
	## Siège en cours : une unité de siège en batterie ou en tir dans ce front.
	for u in fronts[i].world.units.values():
		if Rules.unit_has(u.type, "siege") and (u.state == "attack" or u.state == "batterie"):
			return true
	return false

func state_hash(i: int) -> String:
	return fronts[i].world.state_hash()

func unit_dump(i: int) -> PackedStringArray:
	## État individuel complet de chaque unité (comparaison fine du test d'invariance).
	var w: SimWorld = fronts[i].world
	var out := PackedStringArray()
	var ids := w.units.keys()
	ids.sort()
	for id in ids:
		var u = w.units[id]
		out.append("%d %s t%d pos=%.4f,%.4f hp=%.2f st=%s tgt=%d sq=%d cd=%.3f dep=%.2f" % [id, u.type, u.team, u.pos.x, u.pos.y,
			u.hp, u.state, u.target_id, u.squad_id, u.cd, u.deploy])
	return out

func event_signature(i: int) -> String:
	var w: SimWorld = fronts[i].world
	var parts := PackedStringArray()
	for e in w.event_log:
		parts.append("%d|%s|%d|%s" % [int(e["tick"]), e["type"], int(e["team"]), e["text"]])
	return "\n".join(parts).sha256_text()
