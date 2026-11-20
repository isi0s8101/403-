extends SceneTree
## Recette : vue liée à la recherche réellement acquise, indépendamment du zoom.
var failures: int = 0
var checks: int = 0

func verify(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", name])

func _initialize() -> void:
	var techs: Dictionary = {}
	verify(ViewTechnology.can_open(1, techs, "tactical"), "Terrain libre âge I")
	verify(not ViewTechnology.can_open(1, techs, "planet"), "Atlas interdit avant âge II")
	verify(not ViewTechnology.can_open(10, techs, "planet"), "Âge X seul ne débloque rien")
	techs["cartographie"] = true
	verify(ViewTechnology.can_open(2, techs, "planet"), "Atlas après cartographie")
	verify(not ViewTechnology.can_open(9, techs, "orbit"), "Orbite sans recherche refusée")
	techs["observation_orbitale"] = true
	verify(ViewTechnology.can_open(9, techs, "orbit"), "Orbite recherchée")
	verify(not ViewTechnology.can_open(9, techs, "system"), "Système verrouillé avant navigation interplanétaire")
	techs["navigation_interplanetaire"] = true
	verify(ViewTechnology.can_open(9, techs, "system"), "Système débloqué âge IX")
	verify(not ViewTechnology.can_open(10, techs, "galaxy"), "Galaxie refusée sans filière X")
	techs["cartographie_galactique"] = true
	verify(not ViewTechnology.can_open(10, techs, "galaxy"), "Navigation stellaire toujours requise")
	techs["navigation_stellaire"] = true
	verify(ViewTechnology.can_open(10, techs, "galaxy"), "Galaxie débloquée avec filière complète")
	techs.erase("cartographie")
	verify(not ViewTechnology.can_open(10, techs, "galaxy"), "Arbre incomplet interdit")
	verify(not ViewTechnology.can_open(10, techs, "undefined"), "Niveau invalide refusé")
	print("VIEW_TECH_RESULT=%s checks=%d fails=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
