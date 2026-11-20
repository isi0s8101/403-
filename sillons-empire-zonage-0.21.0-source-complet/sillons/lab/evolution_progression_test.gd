extends SceneTree
func _initialize()->void:
	var c:=StarCampaign.new()
	CampaignSetup.create(c,14050,true,256)
	c.enable_supply_chain()
	for i in 20000:
		c.step()
		if i%2000==0:
			print("EVOLUTION_PROGRESS ",i," ages=",c.ages," civ=",c.planets.colony(0,"val").get("pop",-1),",",c.planets.colony(1,"nemesis").get("pop",-1)," units=",c.current().units.size()," stock=",c.resources[0])
		if int(c.ages[0])>=4 and int(c.ages[1])>=4: break
	var fair:bool=not c.system_known(0,"proxima") and not c.system_known(1,"sol")
	var progressed:bool=int(c.ages[0])>=3 and int(c.ages[1])>=3
	print("EVOLUTION_PROGRESSION_RESULT fair=",fair," ages=",c.ages," ticks=",c.tick)
	quit(0 if fair and progressed else 1)
