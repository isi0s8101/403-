extends SceneTree
var failures:int=0
func _initialize()->void:
	for n in [96,256,512]:
		var start:int=Time.get_ticks_usec()
		var c:=StarCampaign.new()
		CampaignSetup.create(c,14040,true,n)
		c.enable_supply_chain()
		var startup:int=Time.get_ticks_usec()-start
		var timings:Array=[]
		for i in 500:
			var t:int=Time.get_ticks_usec()
			c.step()
			timings.append(Time.get_ticks_usec()-t)
		timings.sort()
		var samples:Dictionary={"dimension":n,"worlds":c.worlds.size(),"ticks":500,"startup_ms":float(startup)/1000.0,"tick_p50_ms":float(timings[250])/1000.0,"tick_p95_ms":float(timings[475])/1000.0,"tick_max_ms":float(timings[499])/1000.0,"memory_mib":float(OS.get_static_memory_usage())/1048576.0,"platform":OS.get_name(),"godot":Engine.get_version_info()["string"]}
		print("EVOLUTION_BENCHMARK ",JSON.stringify(samples))
		if c.current().map_size!=n or c.worlds["nemesis"].tick!=500: failures+=1
	print("EVOLUTION_PERFORMANCE_RESULT failures=",failures," ANDROID=NOT_RUN")
	quit(0 if failures==0 else 1)
