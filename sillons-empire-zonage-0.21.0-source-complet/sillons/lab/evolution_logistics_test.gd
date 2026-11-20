extends SceneTree
var checks:int=0
var failures:int=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value: failures+=1
	print(("PASS " if value else "FAIL ")+label)
func _initialize()->void:
	var c:=StarCampaign.new()
	CampaignSetup.create(c,14060,false,96)
	for w in c.worlds.values(): w.ai_controllers.clear()
	c.ages[0]=10
	c.local_resources(0,"val").merge({"food":20000.0,"wood":20000.0,"ore":20000.0},true)
	c._sync_all()
	var w:SimWorld=c.current()
	var port:SimWorld.Building=w.spawn_building(0,"spatioport",Vector2i(22,65),true)
	var factory:SimWorld.Building=w.spawn_building(0,"caserne",Vector2i(10,65),true)
	var plan:Dictionary=w.issue({"t":"army_plan","team":0,"buildings":[factory.id],"composition":{"lancier":2},"wave":2,"pos":[30,75]})
	var id:int=int(plan["id"])
	for i in 2:
		var unit:SimWorld.Unit=w.spawn_unit(0,"lancier",port.center+Vector2(5+i,0))
		unit.army_plan=id; unit.army_origin="val"; unit.direct=true
	var worker:SimWorld.Unit=w.team_units(0,"worker")[0]
	worker.pos=port.center+Vector2(4,1)
	worker.carry_res="wood"; worker.carry_amt=5.0
	var ship:SimWorld.Unit=w.spawn_unit(0,"navette",port.center+Vector2(3,0))
	var population:int=w.teams[0].pop
	var mission:Dictionary=c.issue_evolution({"t":"reinforcement_mission","team":0,"plan":id,"source":"val","target":"aurore"})
	check(bool(mission.get("ok",false)),"R06 mission militaire assignée à un plan")
	MilitaryLogistics.step(c)
	check(c.flights.size()==1 and not w.units.has(ship.id),"R06 navette réelle retirée au départ")
	check(w.team_units(0,"military").is_empty() and not w.units.has(worker.id),"R06 soldats et bâtisseur embarqués physiquement")
	var loaded:StarCampaign=CampaignSave.from_snapshot(CampaignSave.snapshot(c))
	check(loaded!=null and loaded.flights.size()==1,"S01 mission et identité sauvegardées en transit")
	for tick in 160: c._tick_flights()
	var dest:SimWorld=c.worlds["aurore"]
	check(c.flights.is_empty() and dest.team_units(0,"military").size()==2,"R06 une seule livraison des renforts")
	check(dest.teams[0].pop+w.teams[0].pop==population,"R06 population embarquée et débarquée conservée")
	var carried:float=0.0
	for unit in dest.team_units(0,"worker"):
		if unit.carry_res=="wood": carried+=unit.carry_amt
	check(is_equal_approx(carried,5.0),"R06 stock porté conservé pendant le vol")
	for unit in dest.team_units(0,"military"):
		check(unit.army_plan==id and unit.army_origin=="val" and unit.direct and unit.order.get("type")=="amove","R06 contrat repris après débarquement")
	c._sync_all()
	ArmyPlans.step(w)
	check(factory.queue.is_empty() and int(w.external_plan_counts[id]["lancier"])==2,"R05 composition globale inclut les unités déjà acheminées")
	check(c.planets.local_age(c,0,"aurore")==7,"D09 colonie fondée à l'âge VII local")
	print("EVOLUTION_LOGISTICS_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
