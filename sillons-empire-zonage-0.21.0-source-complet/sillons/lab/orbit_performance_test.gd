extends SceneTree
func _initialize()->void:
	var c:=StarCampaign.new();c.create(15070)
	c.ages=[10,10];c.orbital_initial_granted=[true,true]
	for w in c.worlds.values():w.ai_controllers.clear()
	for body in StarCampaign.SECTORS:
		for team in [0,1]:
			c.orbital_sites[OrbitalIndustry.key(team,body)]=OrbitalIndustry._new_site(team,body,0)
			c.orbital_presence[OrbitalIndustry.key(team,body)]={"intercepteur":16,"fregate":4}
	OrbitalTactics.enable(c)
	var timings:Array=[]
	for i in 150:
		c.tick+=1
		var start:int=Time.get_ticks_usec();OrbitalTactics.step(c);timings.append(Time.get_ticks_usec()-start)
	timings.sort()
	print("ORBIT_BENCHMARK ",JSON.stringify({"maps":3,"ships":120,"ticks":150,"p50_ms":float(timings[75])/1000.0,"p95_ms":float(timings[142])/1000.0,"max_ms":float(timings[149])/1000.0,"platform":OS.get_name(),"godot":Engine.get_version_info()["string"]}))
	var valid:bool=OrbitalTactics.validate(c)
	print("ORBIT_PERFORMANCE_RESULT valid=",valid," ANDROID=NOT_RUN")
	quit(0 if valid else 1)
