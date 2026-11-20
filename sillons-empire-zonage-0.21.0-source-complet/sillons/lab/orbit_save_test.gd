extends SceneTree
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func _initialize()->void:
	var c:=StarCampaign.new();CampaignSetup.create(c,15050,false,96)
	for w in c.worlds.values():w.ai_controllers.clear()
	c.ages[0]=10;c.discovered_systems[0]={"sol":true,"proxima":true}
	c.orbital_sites["0:val"]=OrbitalIndustry._new_site(0,"val",0)
	c.orbital_presence["0:val"]={"intercepteur":2};c.orbital_initial_granted=[true,true];c._sync_all();OrbitalTactics.enable(c)
	var own:Array=OrbitalTactics._matching(c.orbital_maps["val"]["actors"],0,"intercepteur","unit")
	var id:int=own[0]["id"]
	c.issue_orbit({"team":0,"body":"val","action":"move","units":[id],"pos":[20,50]})
	for i in 15:c.step()
	var snapshot:Dictionary=CampaignSave.snapshot(c)
	check(CampaignSave.from_snapshot(snapshot)!=null,"sauvegarde avec un vaisseau en mouvement")
	for mutation in ["position","pv","type","chemin","ordre","inventaire","identifiant","ralliement","dictionnaire"]:
		var bad:Dictionary=snapshot.duplicate(true)
		var actor:Dictionary=bad["state"]["orbital_maps"]["val"]["actors"][id]
		match mutation:
			"position":actor["pos"]=Vector2(80,80)
			"pv":actor["hp"]=[]
			"type":actor["type"]="inconnu"
			"chemin":actor["path"].resize(100)
			"ordre":actor["order"]={"type":"invalide"}
			"inventaire":bad["state"]["orbital_presence"]["0:val"]["intercepteur"]=1
			"identifiant":bad["state"]["next_orbit_actor"]=id
			"ralliement":bad["state"]["orbital_maps"]["val"]["rally"][0]=Vector2(80,80)
			"dictionnaire":bad["state"]["orbital_maps"]=[]
		check(CampaignSave.from_snapshot(bad)==null,"refus propre d'une sauvegarde altérée : "+mutation)
	var legacy:Dictionary=snapshot.duplicate(true)
	for field in ["orbital_tactics","orbital_maps","next_orbit_actor"]:legacy["state"].erase(field)
	var migrated:StarCampaign=CampaignSave.from_snapshot(legacy)
	check(migrated!=null and migrated.orbital_tactics and migrated.orbital_presence==c.orbital_presence,"migration 0.14 sans ajout de vaisseaux")
	var p:Dictionary=c.planets.colony(0,"val");p["tracks_empire"]=false;p["local_age"]=7
	check(bool(c.issue_orbit({"team":0,"body":"val","action":"move","units":[id],"pos":Vector2(20,40)}).get("ok",false)),"âge VII local : la flotte importée reste pilotable")
	check(not bool(c.issue_orbit({"team":0,"body":"val","action":"train","kind":"intercepteur"}).get("ok",false)),"âge VII local : aucune production orbitale anticipée")
	check(bool(c.issue_orbit({"team":0,"body":"val","action":"depart","units":[id],"destination":"aurore"}).get("ok",false)),"âge VII local : le vaisseau peut repartir")
	var flight_snapshot:Dictionary=CampaignSave.snapshot(c)
	check(CampaignSave.from_snapshot(flight_snapshot)!=null,"dégâts et niveaux de la flotte en transit sauvegardés")
	flight_snapshot["state"]["orbital_flights"][0]["tactical_units"][0]["hp_ratio"]=-1.0
	check(CampaignSave.from_snapshot(flight_snapshot)==null,"intégrité des vaisseaux en transit vérifiée")
	print("ORBIT_SAVE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
