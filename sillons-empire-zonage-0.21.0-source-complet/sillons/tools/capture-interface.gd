extends SceneTree
var frames:int=0
var capture_mode:String="menu"
var output:String=""
func _initialize()->void:
	var args:PackedStringArray=OS.get_cmdline_user_args()
	capture_mode=args[0];output=args[2]
	GameConfig.mode="empire";GameConfig.seed_value=15001;GameConfig.reduce_motion=true
	GameConfig.visual_quality=2;GameConfig.adaptive_visuals=false
	if capture_mode!="menu":
		var c:=StarCampaign.new();CampaignSetup.create(c,15001,false,96);
		for w in c.worlds.values():w.ai_controllers.clear()
		if capture_mode in ["orbit","system","galaxy"]:
			c.ages[0]=10;c.ages[1]=10
			for key in ViewTechnology.RESEARCH_ORDER:c.technologies[0][key]=true
			c.discovered_systems[0]={"sol":true,"proxima":true}
			c.local_resources(0,"val").merge({"food":12000.0,"wood":12000.0,"ore":12000.0},true)
			c.orbital_sites["0:val"]={"team":0,"body":"val","tier":2,"hp":2800.0,"remaining":0,"modules":{"hangar":1,"habitat":2,"arsenal":1,"radar":1},"unit_levels":{},"job":{},"map_pos":Vector2(32,80)}
			c.orbital_presence["0:val"]={"drone":2,"sonde":1,"intercepteur":4,"fregate":2}
			c.orbital_initial_granted[0]=true;c.orbital_initial_granted[1]=true;c._sync_all();OrbitalTactics.enable(c)
			if capture_mode in ["system","galaxy"]:
				var a:Array=OrbitalTactics._matching(c.orbital_maps["val"]["actors"],0,"intercepteur","unit")
				c.issue_orbit({"team":0,"body":"val","action":"depart","units":[a[0]["id"]],"destination":"aurore"})
				a=OrbitalTactics._matching(c.orbital_maps["val"]["actors"],0,"fregate","unit")
				c.issue_orbit({"team":0,"body":"val","action":"depart","units":[a[0]["id"]],"destination":"nemesis"})
				for neighbor in c.star_catalog.galaxy.neighbors("sol"):
					if not c.system_known(0,String(neighbor)):OrbitalIndustry.send_probe(c,0,"val",String(neighbor));break
		GameConfig.loaded_campaign=c
	change_scene_to_file("res://game/main_menu.tscn" if capture_mode=="menu" else "res://game/game.tscn")
func _process(_delta:float)->bool:
	frames+=1
	if frames==8 and capture_mode!="menu":
		var game=current_scene;game.paused=true
		if capture_mode in ["building","buildings"]:
			var buildings:Array=game.world.team_buildings(0,"centre",true)
			game.sel_building=buildings[0].id;game.hud.selection_changed()
			if capture_mode=="buildings":game.hud.building_drawer._switch_tab("Bâtiments")
		elif capture_mode in ["orbit","system","galaxy"]:
			game.enter_space_overview(capture_mode)
			if capture_mode=="orbit":game.orbit_hud.select_hub()
	if frames==26:
		get_root().get_texture().get_image().save_png(output)
		print("INTERFACE_CAPTURE=PASS ",capture_mode);quit()
	return false
