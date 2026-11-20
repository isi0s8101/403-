extends SceneTree
var failures: int = 0
var checks: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + label)
func fixture() -> SimWorld:
	var w := SimWorld.new()
	w.setup(14010, {"campaign": true})
	for y in 96:
		for x in 96: w.set_terrain(Vector2i(x,y), SimWorld.TERRAIN_GRASS)
	w.teams[0].res = {"food": 20000.0, "wood": 20000.0, "ore": 20000.0}
	w.teams[0].age = 3
	w.teams[0].pop_cap = 200
	w.spawn_building(0, "centre", Vector2i(3,3), true)
	return w
func ready_unit(w: SimWorld, b: SimWorld.Building) -> SimWorld.Unit:
	var result: Dictionary = w.issue({"t":"train","team":0,"building":b.id,"unit":"lancier"})
	check(bool(result.get("ok",false)), "formation réellement payée")
	b.prod_timer = float(Rules.UNITS["lancier"]["time"])
	w.step()
	return w.units[w.units.keys().back()]
func _initialize() -> void:
	var w: SimWorld = fixture()
	var a: SimWorld.Building = w.spawn_building(0, "caserne", Vector2i(10,10), true)
	var b: SimWorld.Building = w.spawn_building(0, "caserne", Vector2i(10,20), true)
	check(bool(w.issue({"t":"rally","team":0,"building":a.id,"pos":[30,15]}).get("ok",false)), "R01 drapeau posé")
	var first: SimWorld.Unit = ready_unit(w,a)
	check(first.direct and first.order.get("pos") == Vector2(30,15), "R01 ordre dès la création")
	var former_squad: int = first.squad_id
	w.issue({"t":"rally","team":0,"building":a.id,"pos":[40,20]})
	var second: SimWorld.Unit = ready_unit(w,a)
	check(first.order.get("pos") == Vector2(30,15) and second.order.get("pos") == Vector2(40,20) and second.squad_id != former_squad, "R02 contrats anciens conservés et nouvelle escouade")
	var revision: int = a.rally_revision
	check(not bool(w.issue({"t":"rally_group","team":0,"buildings":[a.id,-9],"pos":[20,30]}).get("ok",false)) and a.rally_revision == revision, "R03 groupe invalide refusé atomiquement")
	check(not bool(w.issue({"t":"rally","team":0,"building":a.id,"pos":[NAN,12]}).get("ok",false)), "R03 NaN refusé")
	w.set_terrain(Vector2i(32,32), SimWorld.TERRAIN_WATER)
	check(not bool(w.issue({"t":"rally","team":0,"building":a.id,"pos":[32,32]}).get("ok",false)), "R03 eau refusée")
	w.issue({"t":"rally_group","team":0,"buildings":[a.id,b.id],"kind":"unit","target":first.id})
	var mobile: SimWorld.Unit = ready_unit(w,b)
	check(mobile.rally_contract.get("target",-1) == first.id, "R06 cible mobile enregistrée")
	w.transfer_out_unit(first)
	for tick in 8: w.step()
	check(bool(mobile.rally_contract.get("alerted",false)) or mobile.rally_contract.is_empty(), "R06 cible détruite : repli local")
	var alerts: int = 0
	for event in w.event_log:
		if event.get("type") == "rally" and int(event.get("unit",-1)) == mobile.id: alerts += 1
	check(alerts <= 1, "R03 une seule alerte par renfort")
	var worker: SimWorld.Unit = w.spawn_unit(0,"ouvrier",Vector2(7,10))
	RallyService.assign(w,worker,a)
	check(worker.rally_contract.is_empty() and not worker.direct, "R01 ouvriers conservés dans l'économie")
	var restored: SimWorld = SaveGame.from_snapshot(SaveGame.snapshot(w))
	check(restored != null and restored.buildings[a.id].rally_contract == a.rally_contract, "R04 contrat et révision restaurés")
	if restored != null:
		for tick in 40:
			w.step()
			restored.step()
		var expected: Dictionary = SaveGame.snapshot(w)
		var actual: Dictionary = SaveGame.snapshot(restored)
		for key in expected:
			if expected[key] != actual[key]:
				print("DIFFERENCE ", key)
				if key == "entities":
					for kind in expected[key]:
						for index in expected[key][kind].size():
							if expected[key][kind][index] != actual[key][kind][index]:
								for field in expected[key][kind][index]:
									if expected[key][kind][index][field] != actual[key][kind][index][field]: print("FIELD ",kind," ",index," ",field, " expected=", expected[key][kind][index][field], " actual=",actual[key][kind][index][field])
		check(expected == actual, "R04 continuation complète identique")
	var planned: SimWorld = fixture()
	var p1: SimWorld.Building = planned.spawn_building(0,"caserne",Vector2i(10,10),true)
	var p2: SimWorld.Building = planned.spawn_building(0,"caserne",Vector2i(10,20),true)
	check(bool(planned.issue({"t":"army_plan","team":0,"buildings":[p1.id,p2.id],"composition":{"lancier":2},"wave":2,"pos":[35,35]}).get("ok",false)), "R05 plan de composition partagé")
	planned.step()
	check(p1.queue.size()+p2.queue.size()==2, "R05 deux réservations et aucune troisième recrue")
	for tick in 200: planned.step()
	check(planned.team_units(0,"military").size() <= 2 and p1.queue.size()+p2.queue.size()==0, "R05 cible respectée sur deux producteurs")
	var u: SimWorld.Unit = planned.team_units(0,"military")[0]
	check(bool(planned.issue({"t":"queue_orders","team":0,"units":[u.id],"orders":[{"type":"move","pos":[20,35]},{"type":"wait","ticks":30},{"type":"defend","pos":[25,35]}]}).get("ok",false)), "R06 ordres successifs validés")
	check(not bool(planned.issue({"t":"queue_orders","team":0,"units":[u.id],"orders":[{"type":"escort","target":-1}]}).get("ok",false)), "R06 escorte inexistante refusée")
	print("EVOLUTION_RALLY_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
