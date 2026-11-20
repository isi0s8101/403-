extends SceneTree
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func fixture()->StarCampaign:
	var c:=StarCampaign.new();CampaignSetup.create(c,15001,false,96)
	for w in c.worlds.values():w.ai_controllers.clear()
	c.ages[0]=10;c.ages[1]=10;c.discovered_systems[0]={"sol":true,"proxima":true};c.discovered_systems[1]={"sol":true,"proxima":true}
	for team in [0,1]:
		c.local_resources(team,"val").merge({"food":20000.0,"wood":20000.0,"ore":20000.0},true)
	c.orbital_sites["0:val"]=OrbitalIndustry._new_site(0,"val",0)
	c.orbital_sites["0:val"]["modules"]={"hangar":1,"habitat":2,"arsenal":1}
	c.orbital_initial_granted=[true,true]
	c._sync_all();OrbitalTactics.enable(c);return c
func ships(c:StarCampaign,team:int,kind:String)->Array:
	return OrbitalTactics._matching(OrbitalTactics.map_for(c,"val")["actors"],team,kind,"unit")
func _initialize()->void:
	var c:StarCampaign=fixture()
	var stock:Dictionary=OrbitalIndustry.presence(c,0,"val");stock["intercepteur"]=2;stock["fregate"]=1
	OrbitalTactics.reconcile(c)
	var actors:Dictionary=OrbitalTactics.map_for(c,"val")["actors"]
	var first:Dictionary=ships(c,0,"intercepteur")[0]
	var second:Dictionary=ships(c,0,"intercepteur")[1]
	check(ships(c,0,"intercepteur").size()==2,"inventaire réel matérialisé sans vaisseau gratuit")
	var command:Dictionary=c.issue_orbit({"team":0,"body":"val","action":"move","units":[first["id"]],"pos":Vector2(128,80)})
	check(bool(command.get("ok",false)) and (first["path"] as Array).size()>1,"route réelle autour de la planète")
	for tick in 100:
		c.step()
		check_position(c,first)
	check((first["pos"] as Vector2).distance_to(Vector2(128,80))>1,"déplacement avec durée, sans téléportation")
	var before:Dictionary=CampaignSave.snapshot(c)
	check(not bool(c.issue_orbit({"team":0,"body":"val","action":"move","units":[first["id"]],"pos":Vector2(80,80)}).get("ok",false)) and before==CampaignSave.snapshot(c),"point dans la planète refusé sans mutation")
	var saved:StarCampaign=CampaignSave.from_snapshot(CampaignSave.snapshot(c))
	check(saved!=null,"carte orbitale sauvegardée")
	if saved!=null:
		for tick in 30:c.step();saved.step()
		check(c.state_hash()==saved.state_hash(),"reprise des positions, chemins et délais déterministe")
	var first_id:int=int(first["id"]);var second_id:int=int(second["id"])
	first["hp"]=100.0
	check(bool(c.issue_orbit({"team":0,"body":"val","action":"depart","units":[first_id],"destination":"aurore"}).get("ok",false)),"départ d'une sélection précise")
	check(not actors.has(first_id) and actors.has(second_id) and int(stock["intercepteur"])==1,"seul le vaisseau choisi quitte l'orbite")
	for tick in 160:c._tick_surveys();OrbitalIndustry.step(c)
	var arrived:Array=OrbitalTactics._matching(OrbitalTactics.map_for(c,"aurore")["actors"],0,"intercepteur","unit")
	check(arrived.size()==1 and is_equal_approx(float(arrived[0]["hp"]),100.0),"arrivée physique et dégâts conservés")
	check(bool(c.issue_orbit({"team":0,"body":"aurore","action":"move","units":[arrived[0]["id"]],"pos":Vector2(30,30)}).get("ok",false)),"flotte importée pilotable sans nouvelle usine locale")
	var combat:StarCampaign=fixture()
	combat.orbital_sites["1:val"]=OrbitalIndustry._new_site(1,"val",0)
	OrbitalIndustry.presence(combat,0,"val")["fregate"]=3
	OrbitalTactics.reconcile(combat)
	var field:Dictionary=OrbitalTactics.map_for(combat,"val")["actors"]
	var target:Dictionary=OrbitalTactics._matching(field,1,"shipyard","hub")[0]
	target["pos"]=Vector2(32,110);combat.orbital_sites["1:val"]["map_pos"]=target["pos"]
	for a in ships(combat,0,"fregate"):a["pos"]=Vector2(32,96);a["prev"]=a["pos"]
	var ids:Array=ships(combat,0,"fregate").map(func(a:Dictionary)->int:return int(a["id"]))
	check(bool(combat.issue_orbit({"team":0,"body":"val","action":"attack","units":ids,"target":target["id"]}).get("ok",false)),"attaque directe sur cible visible")
	check(combat.planets.landing_blocked(combat,0,"val")>0,"station ennemie verrouille encore le débarquement")
	for tick in 250:combat.step()
	check(not OrbitalIndustry.has_hub(combat,1,"val"),"station détruite par les tirs réellement simulés")
	check(combat.planets.landing_blocked(combat,0,"val")==0,"destruction lève le verrou orbital")
	var readonly:StarCampaign=fixture()
	before=CampaignSave.snapshot(readonly)
	MovementFeed.records(readonly,0)
	check(before==CampaignSave.snapshot(readonly),"lecture du trafic sans mutation de la campagne")
	var industry:StarCampaign=fixture()
	OrbitalIndustry.presence(industry,0,"val")["drone"]=1;OrbitalTactics.reconcile(industry)
	var place:=Vector2(12,100)
	for candidate in [Vector2(12,100),Vector2(20,60),Vector2(42,108)]:
		var free:bool=true
		for a in industry.orbital_maps["val"]["actors"].values():
			if String(a["role"])!="unit" and (a["pos"] as Vector2).distance_to(candidate)<7:free=false
		if free:place=candidate;break
	var material:float=float(industry.local_resources(0,"val")["ore"])
	check(bool(industry.issue_orbit({"team":0,"body":"val","action":"module","kind":"hydroponie","pos":place}).get("ok",false)) and is_equal_approx(float(industry.local_resources(0,"val")["ore"]),material-180),"placement d'un module, coût prélevé une seule fois")
	var pending:StarCampaign=CampaignSave.from_snapshot(CampaignSave.snapshot(industry))
	check(pending!=null and pending.orbital_sites["0:val"]["job"]["map_pos"]==place,"emplacement de la construction conservé en sauvegarde")
	for i in 210:industry.step()
	var built:Array=OrbitalTactics._matching(industry.orbital_maps["val"]["actors"],0,"hydroponie","module")
	check(built.size()==1 and (built[0]["pos"] as Vector2).is_equal_approx(place),"module achevé à l'emplacement choisi")
	industry.issue_orbit({"team":0,"body":"val","action":"rally","pos":Vector2(25,40)})
	industry.issue_orbit({"team":0,"body":"val","action":"train","kind":"intercepteur"})
	for i in 180:industry.step()
	var recruit:Array=ships(industry,0,"intercepteur")
	check(recruit.size()==1 and recruit[0]["order"]["type"]=="move" and recruit[0]["order"]["pos"]==Vector2(25,40),"nouveau vaisseau envoyé automatiquement au ralliement")
	industry.orbital_sites["0:val"]["tier"]=2;recruit[0]["hp"]=150.0
	industry.issue_orbit({"team":0,"body":"val","action":"upgrade_unit","kind":"intercepteur"})
	for i in 360:industry.step()
	check(int(recruit[0]["level"])==2 and is_equal_approx(float(recruit[0]["hp"])/float(recruit[0]["max_hp"]),0.5),"évolution du vaisseau appliquée sans soin gratuit")
	print("ORBIT_TACTICAL_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
func check_position(c:StarCampaign,a:Dictionary)->void:
	if not OrbitalTactics.valid_point(a["pos"]):failures+=1;print("FAIL traversée de la planète")
