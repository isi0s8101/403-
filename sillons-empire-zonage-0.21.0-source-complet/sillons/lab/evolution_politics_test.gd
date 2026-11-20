extends SceneTree
var failures: int = 0
var checks: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + label)
func fixture() -> StarCampaign:
	var c := StarCampaign.new()
	CampaignSetup.create(c,14020,false,96)
	for w in c.worlds.values(): w.ai_controllers.clear()
	return c
func _initialize() -> void:
	var c: StarCampaign = fixture()
	var w: SimWorld = c.current()
	var p: Dictionary = c.planets.colony(0,"val")
	PoliticalState.ensure(p)
	PoliticalState.step(c)
	check(not p["politics"]["factors"].has("Services") and not p["politics"]["factors"].has("Énergie"), "P01 aucune exigence industrielle à l'âge I")
	check(is_equal_approx(PoliticalState.productivity({"politics":{"wellbeing":0}}),0.75) and is_equal_approx(PoliticalState.productivity({"politics":{"wellbeing":80}}),1.15), "P02 coefficient borné")
	var u: SimWorld.Unit = w.team_units(0,"worker")[0]
	var n: SimWorld.ResNode = null
	for node in w.nodes.values():
		if node.res == "wood": n=node; break
	u.pos=n.pos; u.node_id=n.id; u.task="wood"; u.carry_amt=0; u.direct=false
	w.labor_factors[0]=0.75
	var reserve: float = n.amount
	w._update_gather(u)
	check(u.carry_amt > 0 and is_equal_approx(reserve-n.amount,u.carry_amt), "P02 extraction retranchée exactement du gisement")
	p["pop"]=30
	p["politics"]["wellbeing"]=0.0
	var hq: int = int(p["hq"])
	var neighbor: int = int(PlanetCampaign.neighbors(hq)[0])
	p["cells"][neighbor]=PlanetCampaign._new_cell()
	p["cells"][neighbor]["zone"]="I"
	p["cells"][neighbor]["density"]=1
	p["cells"][neighbor]["recipe"]="fonderie"
	var stock: Dictionary = c.local_resources(0,"val")
	stock["ore"]=100.0
	var output: float = float(p["stocks"]["alloy"])
	c.planets._economy(c,p)
	check(float(p["stocks"]["alloy"])>output and is_equal_approx((100.0-float(stock["ore"]))/4.0,(float(p["stocks"]["alloy"])-output)/2.0), "P02 industrie : même facteur aux entrées et sorties")
	var crisis: StarCampaign = fixture()
	var cp: Dictionary = crisis.planets.colony(0,"val")
	cp["politics"]["loyalty"]=0.0; cp["politics"]["wellbeing"]=0.0
	crisis.local_resources(0,"val")["food"]=0.0
	crisis.issue_evolution({"t":"policy","team":0,"body":"val","field":"tax","value":1.0})
	for tick in 300: crisis.step()
	check(crisis.factions.actors().size()==2 and String(cp["politics"]["stage"])!="revolt", "P03 pénurie tolérée avant sécession")
	for tick in 650: crisis.step()
	check(String(cp["politics"]["stage"])=="demands", "P03 crise durable : ultimatum proposé")
	var terms: Dictionary = cp["politics"]["terms"].duplicate(true)
	check(terms.has("max_tax") and terms.has("min_food") and not terms.has("hospital"), "P06 conditions réalisables sans technologie future")
	check(bool(crisis.issue_evolution({"t":"crisis","team":0,"body":"val","answer":"counter"}).get("ok",false)), "P05 contre-proposition acceptée")
	terms=cp["politics"]["terms"].duplicate(true)
	crisis.issue_evolution({"t":"policy","team":0,"body":"val","field":"tax","value":0.15})
	crisis.issue_evolution({"t":"policy","team":0,"body":"val","field":"autonomy","value":0.6})
	crisis.local_resources(0,"val")["food"]=100.0
	for tick in 350: crisis.step()
	check(String(cp["politics"]["stage"])=="stable" and crisis.factions.actors().size()==2, "P05 accord maintenu : stabilisation et délai de grâce")
	var revolt: StarCampaign = fixture()
	var rp: Dictionary = revolt.planets.colony(0,"val")
	rp["pop"]=24
	revolt.planets.transfer_credits(revolt,0,"val",120.0)
	var rw: SimWorld = revolt.current()
	var barracks: SimWorld.Building = rw.spawn_building(0,"caserne",Vector2i(20,60),true)
	var house: SimWorld.Building = rw.spawn_building(0,"maison",Vector2i(25,60),true)
	var regular: SimWorld.Unit = rw.spawn_unit(0,"lancier",Vector2(21,66))
	var militia: SimWorld.Unit = rw.spawn_unit(0,"lancier",Vector2(24,66))
	militia.allegiance="local"; militia.home_body="val"
	var before_stock: Dictionary = revolt.local_resources(0,"val").duplicate(true)
	var treasury: float = revolt.planets.credits(0)
	var population: int = 0
	for t in rw.teams: population += t.pop
	var result: Dictionary = RevoltTransaction.apply(revolt,rp)
	check(bool(result.get("ok",false)), "P07 transfert atomique appliqué")
	var rebel: int = int(result.get("faction",-1))
	check(rebel>=3 and revolt.factions.hostile(0,rebel) and revolt.factions.relation(1,rebel)=="neutral", "F01 identité distincte et relations propres")
	check(regular.team==0 and barracks.team==0 and rw.team_buildings(0,"centre").size()==1 and militia.team==rebel and house.team==rebel, "P07 armée et base fidèles ; milice locale et maison transférées")
	check(revolt.local_resources(rebel,"val")==before_stock and revolt.local_resources(0,"val")["food"]==0.0 and revolt.planets.credits(0)==treasury, "P07 stocks physiques transférés ; trésorerie impériale préservée")
	var after_population: int = 0
	for t in rw.teams: after_population += t.pop
	check(population==after_population and revolt.planets.books_balanced(0) and revolt.planets.books_balanced(rebel), "P07 conservation population et réserves comptables")
	check(not bool(RevoltTransaction.apply(revolt,rp).get("ok",false)), "P08 transaction répétée refusée")
	var saved: Dictionary = CampaignSave.snapshot(revolt)
	var restored: StarCampaign = CampaignSave.from_snapshot(saved)
	check(restored!=null and restored.state_hash()==revolt.state_hash(), "P08 sauvegarde après sécession complète")
	if restored!=null:
		for tick in 30: revolt.step(); restored.step()
		check(revolt.state_hash()==restored.state_hash(), "S01 reprise avec IA insurgée identique")
	var bad: Dictionary = saved.duplicate(true)
	bad["state"]["raw_stocks"][PlanetCampaign.key(rebel,"val")]["food"]=-1.0
	check(CampaignSave.from_snapshot(bad)==null, "S02 stock négatif refusé")
	bad=saved.duplicate(true)
	bad["maps"]["val"]["entities"]["units"][0]["pos"]=Vector2(INF,1)
	check(CampaignSave.from_snapshot(bad)==null, "S02 position non finie refusée")
	revolt.factions.set_relation(0,rebel,"truce")
	check(not TreatyService.can_land(revolt,0,"val"), "P10 trêve sans accès militaire implicite")
	var hostile: SimWorld = revolt.current()
	hostile.update_fog(true)
	check(not bool(hostile.issue({"t":"attack","team":0,"units":[regular.id],"target":house.id}).get("ok",false)), "P10 tirs interdits pendant la trêve")
	revolt.factions.set_relation(0,rebel,"war")
	revolt.planets.stations.append({"id":999,"team":rebel,"body":"val","hp":1000.0,"remaining":0})
	check(revolt.planets.landing_blocked(revolt,0,"val")==1, "P09 station ennemie bloque même l'ancien monde fondateur")
	check(not bool(revolt.issue_evolution({"t":"diplomacy","team":0,"target":rebel,"body":"val","kind":"occupation"}).get("ok",false)), "P09 aucune reconquête par simple clic sous verrou orbital")
	var live_before: Dictionary = CampaignSave.snapshot(revolt)
	check(not bool(revolt.issue_evolution({"t":"policy","team":0,"body":"val","field":"tax","value":NAN}).get("ok",false)) and live_before==CampaignSave.snapshot(revolt), "S02 ordre invalide sans effet partiel")
	print("EVOLUTION_POLITICS_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
