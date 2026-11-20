extends SceneTree
var frames:int=0
var checks:int=0
var failures:int=0
var game
var barracks:SimWorld.Building
var point:Vector2
var before:int=0
var orbital_ship:int=-1
var orbital_before:Vector2
func _initialize()->void:
	var c:=StarCampaign.new();CampaignSetup.create(c,15030,false,96)
	for w in c.worlds.values():w.ai_controllers.clear()
	c.ages[0]=10;c.discovered_systems[0]={"sol":true,"proxima":true}
	for key in ViewTechnology.RESEARCH_ORDER:c.technologies[0][key]=true
	c.local_resources(0,"val").merge({"food":20000.0,"wood":20000.0,"ore":20000.0},true)
	c.orbital_sites["0:val"]=OrbitalIndustry._new_site(0,"val",0)
	c.orbital_sites["0:val"]["modules"]={"habitat":2,"hangar":1,"arsenal":1}
	c.orbital_presence["0:val"]={"drone":1,"navette":1,"intercepteur":2}
	c.orbital_initial_granted=[true,true];c._sync_all();OrbitalTactics.enable(c)
	GameConfig.mode="skirmish";GameConfig.loaded_campaign=c;GameConfig.reduce_motion=true
	change_scene_to_file("res://game/game.tscn")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func tap(position:Vector2)->void:
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=9;event.position=position;event.pressed=pressed;root.push_input(event,true)
func drag(index:int,position:Vector2,relative:Vector2)->void:
	var event:=InputEventScreenDrag.new();event.index=index;event.position=position;event.relative=relative;root.push_input(event,true)
func touch(index:int,position:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=position;event.pressed=pressed;root.push_input(event,true)
func _process(_delta:float)->bool:
	frames+=1
	if frames==12:
		game=current_scene;game.paused=true
		barracks=game.world.spawn_building(0,"caserne",Vector2i(30,50),true)
		game.focus(barracks.center);game.view.sync(1,0)
		point=game.cam.unproject_position(Vector3(barracks.center.x,2,barracks.center.y))
		tap(point)
	if frames==14:
		var drawer:BuildingDrawer=game.hud.building_drawer
		check(game.sel_building==barracks.id and UIMotion.is_open(drawer),"toucher le toit ouvre le bâtiment")
		check(drawer.art.texture!=null and drawer.cards.size()>0 and drawer.cards[0].picture.texture!=null,"photos de bâtiment et unités chargées")
		check(drawer.active_tab=="Unités" and drawer.tabs.get_child_count()==3,"onglets du bâtiment disponibles")
		before=barracks.queue.size();tap(drawer.cards[0].picture.get_global_rect().get_center())
	if frames==16:
		var drawer:BuildingDrawer=game.hud.building_drawer
		check(barracks.queue.size()==before+1,"toucher la photo produit une unité réelle")
		var wanted:Vector2=Vector2(40,60)
		game.begin_rally();game.hud.building_drawer.hide()
		game._tap(game.cam.unproject_position(Vector3(wanted.x,0,wanted.y)))
		check(game.mode=="" and barracks.rally.distance_to(wanted)<0.2,"point de ralliement cliqué sans récursion")
		drawer.open_building(barracks.id);drawer._switch_tab("Bâtiments")
		check(drawer.cards.size()==Rules.BUILDINGS.keys().filter(func(k)->bool:return k!="comptoir" and CivEvolution.visible_building(game.world,game.player,String(k))).size() and drawer.cards.all(func(card:DataCard)->bool:return card.picture.texture!=null),"catalogue de bâtiments photographié (0.16 : seuls les deux monuments de l'âge suivant sont proposés)")
		drawer.toggle_fold();check(drawer.folded and not drawer.body_box.visible,"fiche de bâtiment rétractable")
		drawer.toggle_fold();check(not drawer.folded and drawer.body_box.visible,"fiche redéployable")
		game._back_action();check(game.sel_building==-1 and not UIMotion.is_open(drawer),"Retour ferme la fiche avant le menu pause")
		GameConfig.reduce_motion=false;game.hud._toggle_build();game.hud._toggle_build();game.hud._toggle_build()
		check(UIMotion.is_open(game.hud.build_panel),"trois pressions rapides gardent le bon état du tiroir")
		game.hud.build_panel.hide();GameConfig.reduce_motion=true
		game.enter_space_overview("orbit")
	if frames==18:
		check(game.orbit_view!=null and game.orbit_hud!=null and game.space_view==null,"orbite = carte tactique distincte")
		var own:Array=OrbitalTactics._matching(game.orbit_hud.data()["actors"],0,"intercepteur","unit")
		orbital_ship=int(own[0]["id"]);orbital_before=own[0]["pos"]
		game.orbit_view.sync(1)
		var position:Vector3=game.orbit_view.actors[orbital_ship].global_position
		tap(game.cam.unproject_position(position))
	if frames==20:
		check(game.orbit_hud.selected==[orbital_ship] and UIMotion.is_open(game.orbit_hud.drawer),"toucher un vaisseau ouvre sa sélection")
		var revision:int=game.campaign.command_log.size()
		game.orbit_hud.tab="Unités";game.orbit_hud.signature="";game.orbit_hud.refresh()
		before=game.campaign.command_log.size()
		tap(game.orbit_hud.cards[0].picture.get_global_rect().get_center())
		check(game.campaign.command_log.size()==before+1 and not OrbitalIndustry.site(game.campaign,0,"val")["job"].is_empty(),"production orbitale par photo, sans ordre sous le panneau")
		check(revision==before,"ouvrir un onglet n'émet pas d'ordre")
		game.orbit_hud.drawer.hide();game._update_camera()
		var target:=Vector2(25,61)
		point=game.cam.unproject_position(game.orbit_view.to_global(Vector3(target.x,0,target.y)))
		tap(point)
	if frames==22:
		var actor:Dictionary=game.orbit_hud.data()["actors"][orbital_ship]
		check(actor["order"]["type"]=="move" and actor["path"].size()>0,"toucher le vide ordonne un mouvement orbital")
		for i in 20:game.campaign.step()
		check((actor["pos"] as Vector2).distance_to(orbital_before)>0.5,"le vaisseau se déplace dans la simulation")
		before=game.campaign.command_log.size()
		var zoom:float=game.orbit_zoom
		touch(2,Vector2(450,300),true);touch(3,Vector2(650,300),true)
		drag(3,Vector2(730,300),Vector2(80,0))
		touch(2,Vector2(450,300),false);touch(3,Vector2(730,300),false)
		check(game.orbit_zoom<zoom and game.campaign.command_log.size()==before,"pincement orbital zoome sans tap fantôme")
		var focus:Vector2=game.orbit_focus
		touch(2,Vector2(450,300),true);drag(2,Vector2(510,300),Vector2(60,0));touch(2,Vector2(510,300),false)
		check(not game.orbit_focus.is_equal_approx(focus) and game.campaign.command_log.size()==before,"glisser déplace seulement la caméra")
		touch(2,Vector2(450,300),true);touch(3,Vector2(650,300),true)
		touch(2,Vector2(450,300),false);touch(3,Vector2(650,300),false)
		check(game.campaign.command_log.size()==before,"deux doigts relâchés sans déplacement ne donnent aucun ordre")
		touch(2,Vector2(450,300),true);game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(game.orbit_hud.touches.is_empty() and game.orbit_hud.mouse_start.x<0,"perte du focus nettoie les gestes orbitaux")
		var saved:Dictionary=CampaignSave.snapshot(game.campaign)
		game.enter_space_overview("system");game.space_hud.refresh(true)
		game.enter_space_overview("galaxy");game.galaxy_hud.refresh(true)
		check(CampaignSave.snapshot(game.campaign)==saved,"navigation et trafic système/galaxie en lecture seule")
		var buttons:Array=game.galaxy_hud.root.find_children("*","Button",true,false)
		check(buttons.size()==4 and buttons.all(func(button:Button)->bool:return button.text in ["Terrain","Carte orbitale","Système","−"]),"galaxie limitée au suivi et à la navigation")
		game.open_galaxy_system("sol");game.enter_space_overview("orbit");game.orbit_hud.select_hub()
	if frames==24:
		game._back_action();check(game.space_mode=="orbit" and not UIMotion.is_open(game.orbit_hud.drawer),"Retour replie d'abord le panneau orbital")
		game._back_action();check(game.space_mode=="" and game.hud.visible and game.view.visible,"Retour suivant retrouve le terrain")
		print("INTERFACE_INTERACTION_RESULT checks=",checks," failures=",failures)
		quit(0 if failures==0 else 1)
	return false
