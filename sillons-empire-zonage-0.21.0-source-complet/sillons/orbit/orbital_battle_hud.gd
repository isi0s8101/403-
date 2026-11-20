class_name OrbitalBattleHud
extends CanvasLayer
var game
var root:Control
var top:PanelContainer
var dock:PanelContainer
var drawer:PanelContainer
var title:Label
var stocks_label:Label
var pause_button:Button
var _drawer_open:bool=false
var multiselect:bool=false
var summary:Label
var production:Label
var hint:Label
var grid:GridContainer
var cards:Array=[]
var selected:Array=[]
var chosen:int=-1
var tab:String="Unités"
var pending:Dictionary={}
var assault:bool=false
var clock:float=0
var signature:String=""
var touches:Dictionary={}
var starts:Dictionary={}
var mouse_start:Vector2=Vector2(-1,-1)
var mouse_last:Vector2=Vector2.ZERO
var dragged:bool=false
var pinch:float=0
var blockers:Array=[]
func setup(p_game)->void:
	game=p_game;layer=15
	root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=MobileUI.theme();add_child(root)
	top=PanelContainer.new();top.anchor_right=1;top.offset_left=12;top.offset_top=12;top.offset_right=-12;top.offset_bottom=76;root.add_child(top);blockers.append(top)
	var row:=HBoxContainer.new();top.add_child(row)
	var title_box:=VBoxContainer.new();title_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title_box.add_theme_constant_override("separation",2);row.add_child(title_box)
	title=Label.new();title.clip_text=true;title.add_theme_font_size_override("font_size",18);title_box.add_child(title)
	stocks_label=Label.new();stocks_label.clip_text=true;stocks_label.add_theme_font_size_override("font_size",12);stocks_label.theme_type_variation="MutedLabel";title_box.add_child(stocks_label)
	pause_button=MobileUI.button("‖",func():game.paused=not game.paused;refresh(),48);pause_button.custom_minimum_size.x=48;row.add_child(pause_button)
	row.add_child(MobileUI.button("Terrain",func():game.land_on_space_selection(),48))
	row.add_child(MobileUI.button("Système",func():game.enter_space_overview("system"),48))
	row.add_child(MobileUI.button("Galaxie",func():game.enter_space_overview("galaxy"),48))
	row.add_child(MobileUI.button("Retour",func():game.leave_space_overview(true),48))
	for child in row.get_children():
		if child is Button:child.size_flags_horizontal=Control.SIZE_SHRINK_END;child.custom_minimum_size.x=80
	drawer=PanelContainer.new();drawer.anchor_left=1;drawer.anchor_right=1;drawer.anchor_bottom=1
	drawer.offset_left=-478;drawer.offset_right=-12;drawer.offset_top=88;drawer.offset_bottom=-87;root.add_child(drawer);blockers.append(drawer)
	root.resized.connect(_apply_orientation)
	var box:=VBoxContainer.new();box.name="Body";drawer.add_child(box)
	var heading:=HBoxContainer.new();box.add_child(heading)
	summary=Label.new();summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL;summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.add_child(summary)
	var close:Button=MobileUI.button("−",func():UIMotion.conceal(drawer),48);close.custom_minimum_size.x=48;close.size_flags_horizontal=Control.SIZE_SHRINK_END;heading.add_child(close)
	production=Label.new();production.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;production.add_theme_font_size_override("font_size",12);box.add_child(production)
	var tabs:=HBoxContainer.new();tabs.name="Tabs";box.add_child(tabs)
	for name in ["Unités","Bâtiments","Évolutions","Voyage"]:
		var button:Button=MobileUI.button(name,func():tab=name;signature="";refresh(),48)
		button.add_theme_font_size_override("font_size",13);button.toggle_mode=true;button.set_meta("tab",name);tabs.add_child(button)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
	grid=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(grid)
	dock=PanelContainer.new();dock.anchor_top=1;dock.anchor_bottom=1;dock.offset_left=12;dock.offset_top=-76;dock.offset_bottom=-12;root.add_child(dock);blockers.append(dock)
	var tools:=HBoxContainer.new();dock.add_child(tools)
	tools.add_child(MobileUI.button("Flotte",select_all,48))
	var add_selection:Button=MobileUI.button("Sélection +",func():multiselect=not multiselect;hint.text="Touchez les vaisseaux à ajouter ou retirer de la sélection." if multiselect else "Sélection simple activée.",48);add_selection.toggle_mode=true;tools.add_child(add_selection)
	tools.add_child(MobileUI.button("Station",select_hub,48))
	tools.add_child(MobileUI.button("Bâtir",func():tab="Bâtiments";signature="";UIMotion.reveal(drawer);refresh(),48))
	tools.add_child(MobileUI.button("Assaut",func():assault=not assault;hint.text="Assaut activé : touchez une destination." if assault else "Déplacement direct activé.",48))
	tools.add_child(MobileUI.button("Stop",func():_issue({"action":"hold","units":selected}),48))
	tools.add_child(MobileUI.button("Drapeau",func():pending={"action":"rally"};hint.text="Touchez le point de ralliement des futurs vaisseaux.";drawer.hide(),48))
	hint=Label.new();hint.anchor_top=1;hint.anchor_bottom=1;hint.anchor_right=1;hint.offset_left=14;hint.offset_top=-104;hint.offset_bottom=-78;hint.offset_right=-12;hint.add_theme_font_size_override("font_size",13);hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint.text="Vaisseau : sélectionner · vide : déplacer · ennemi : attaquer · glisser : carte · pincer : zoom"
	root.add_child(hint)
	drawer.hide();refresh()
func data()->Dictionary:return OrbitalTactics.map_for(game.campaign,game.space_selected)
func is_over_ui(point:Vector2)->bool:
	for control in blockers:
		if control.visible and control.get_global_rect().has_point(point):return true
	return false
func _issue(command:Dictionary)->Dictionary:
	command["team"]=game.player;command["body"]=game.space_selected
	var result:Dictionary=game.campaign.issue_orbit(command)
	hint.text="Ordre transmis." if bool(result.get("ok",false)) else String(result.get("reason","Ordre refusé"))
	signature="";refresh();return result
func select_all()->void:
	selected=[];chosen=-1
	for a in (data()["actors"] as Dictionary).values():
		if int(a["team"])==game.player and String(a["role"])=="unit":selected.append(int(a["id"]))
	game.orbit_view.selected=selected.duplicate();tab="Voyage";signature="";UIMotion.reveal(drawer);refresh()
func select_hub()->void:
	for a in (data()["actors"] as Dictionary).values():
		if int(a["team"])==game.player and String(a["role"])=="hub":
			chosen=int(a["id"]);selected=[chosen];game.orbit_focus=a["pos"];game._update_camera();game.orbit_view.selected=selected.duplicate();tab="Unités";signature="";UIMotion.reveal(drawer);refresh();return
	tab="Bâtiments";chosen=-1;signature="";UIMotion.reveal(drawer);refresh()
func _card(label:String,texture:Texture2D,details:String,key:String,action:Callable)->void:
	var card:=DataCard.new();card.key=key;card.setup(label,texture,details,action);grid.add_child(card);cards.append(card)
func _place(action:String,kind:String="")->void:
	pending={"action":action,"kind":kind};drawer.hide();hint.text="Touchez un emplacement libre ; Retour annule."
func _text(value:String)->void:
	var label:=Label.new();label.text=value;label.custom_minimum_size.x=380;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;grid.add_child(label)
func refresh()->void:
	if game.campaign==null:return
	var c:StarCampaign=game.campaign;var body:String=game.space_selected;var actors:Dictionary=data()["actors"]
	selected=selected.filter(func(id:Variant)->bool:return actors.has(id))
	game.orbit_view.selected=selected.duplicate()
	var stocks:Dictionary=c.local_resources(game.player,body) if c.evolutions_enabled else c.system_resources(game.player,c._system_of(body))
	title.text="ORBITE  /  "+String(c.info(body)["label"])
	stocks_label.text="Vivres %.0f   ·   Bois %.0f   ·   Minerai %.0f"%[float(stocks.get("food",0)),float(stocks.get("wood",0)),float(stocks.get("ore",0))]
	pause_button.text="Jouer" if game.paused else "Pause"
	var hub:Dictionary=OrbitalIndustry.site(c,game.player,body)
	summary.text="CHANTIER ORBITAL" if selected.is_empty() else ("%d vaisseau(x) sélectionné(s)"%selected.size())
	if actors.has(chosen):
		var a:Dictionary=actors[chosen]
		summary.text=(String(OrbitalIndustry.UNITS[a["type"]]["label"]) if String(a["role"])=="unit" else "INSTALLATION ORBITALE")+" · %d / %d PV"%[a["hp"],a["max_hp"]]
	production.text=""
	if not hub.is_empty():
		if int(hub["remaining"])>0:production.text="Assemblage · %d s"%ceili(float(hub["remaining"])/10)
		elif not (hub["job"] as Dictionary).is_empty():production.text="Production : %s · %d s"%[hub["job"]["kind"],ceili(float(hub["job"]["remaining"])/10)]
		else:production.text="Chantier disponible · population %d / %d"%[OrbitalIndustry.population(c,game.player,body),OrbitalIndustry.capacity(c,game.player,body)]
	var current:String=tab+str(chosen)+str(selected)+str(c.planets.local_age(c,game.player,body))+str(hub.get("tier",0))+str(hub.get("modules",{}))+str(hub.get("unit_levels",{}))
	if current!=signature:
		for button in drawer.get_node("Body/Tabs").get_children():button.button_pressed=String(button.get_meta("tab"))==tab
		signature=current;UIMotion.clear(grid);cards=[];grid.columns=2
		if actors.has(chosen) and int(actors[chosen]["team"])!=game.player:
			_text("Installation étrangère. Sélectionnez votre flotte pour l'attaquer si elle est hostile.");return
		if tab=="Unités":
			for kind in OrbitalIndustry.UNITS:
				var definition:Dictionary=OrbitalIndustry.UNITS[kind]
				_card(String(definition["label"]),Portraits.orbital(kind),Rules.cost_text(definition["cost"])+" · %d s"%(int(definition["ticks"])/10),"train:"+String(kind),func():_issue({"action":"train","kind":kind}))

		elif tab=="Bâtiments":
			_card("Chantier naval",Portraits.orbital("shipyard",true),Rules.cost_text(OrbitalIndustry.HUB_COST),"hub",func():_place("hub"))
			_card("Station de commandement",Portraits.orbital("command",true),Rules.cost_text(J13Rules.STATION_COST)+" · %d s"%(J13Rules.STATION_TICKS/10),"command",func():_place("command"))
			for kind in OrbitalIndustry.MODULES:
				var definition:Dictionary=OrbitalIndustry.MODULES[kind]
				_card(String(definition["label"]),Portraits.orbital(kind,true),Rules.cost_text(definition["cost"])+" · %d s"%(int(definition["ticks"])/10),"module:"+String(kind),func():_place("module",kind))
		elif tab=="Évolutions":
			var next_tier:int=int(hub.get("tier",1))+1
			_card("Chantier · niv. %d"%next_tier,Portraits.orbital("shipyard",true),Rules.cost_text({"wood":250*next_tier,"ore":370*next_tier}),"upgrade_hub",func():_issue({"action":"upgrade_hub"}))
			for kind in OrbitalIndustry.UNITS:
				var next_level:int=int((hub.get("unit_levels",{}) as Dictionary).get(kind,1))+1
				var costs:Dictionary={}
				for resource in OrbitalIndustry.UNITS[kind]["cost"]:costs[resource]=int(OrbitalIndustry.UNITS[kind]["cost"][resource])*next_level*2
				_card(String(OrbitalIndustry.UNITS[kind]["label"])+" · niv. %d"%next_level,Portraits.orbital(kind),Rules.cost_text(costs),"upgrade_unit:"+String(kind),func():_issue({"action":"upgrade_unit","kind":kind}))
		else:
			grid.columns=1
			_text("Sélectionnez une flotte, puis sa destination. Le voyage réserve les vaisseaux réels et possède un délai. Les cartes système et galaxie permettent de suivre sa progression.")
			var destinations:=OptionButton.new();destinations.custom_minimum_size.y=48;grid.add_child(destinations)
			var options:Array=[]
			for destination in c.sector_keys():
				if String(destination)==body or not c.is_unlocked(game.player,String(destination)):continue
				if StarCampaign.expected_flight_duration(c.star_catalog,body,String(destination))<0:continue
				options.append(String(destination));destinations.add_item(String(c.info(String(destination))["label"]))
			grid.add_child(MobileUI.button("Envoyer la sélection",func():
				if options.is_empty():hint.text="Aucune destination accessible.";return
				_issue({"action":"depart","units":selected.duplicate(),"destination":options[destinations.selected]}),48))
			grid.add_child(MobileUI.button("Transporter 100 vivres, bois et minerai",func():
				if options.is_empty():hint.text="Aucune destination accessible.";return
				var result:Dictionary=c.transfer_materials(game.player,body,options[destinations.selected],{"colonists":0,"goods":{"food":100,"wood":100,"ore":100},"found":false})
				hint.text="Fret réservé et lancé." if bool(result.get("ok",false)) else String(result.get("reason","Refus")),48))
			var origin:String=c._system_of(body)
			var unknown:=OptionButton.new();unknown.custom_minimum_size.y=48;grid.add_child(unknown)
			var signals:Array=[]
			for system in c.star_catalog.galaxy.neighbors(origin):
				if not c.system_known(game.player,String(system)):signals.append(String(system));unknown.add_item("Signal stellaire "+str(signals.size()))
			grid.add_child(MobileUI.button("Envoyer une sonde vers le signal",func():
				if signals.is_empty():hint.text="Tous les systèmes voisins sont connus.";return
				var result:Dictionary=OrbitalIndustry.send_probe(c,game.player,body,signals[unknown.selected]);hint.text="Sonde en route." if bool(result.get("ok",false)) else String(result.get("reason","Refus")),48))
			for directive in ["observe","defend","supply","explore"]:
				grid.add_child(MobileUI.button({"observe":"Suspendre les directives","defend":"Déléguer la défense du système","supply":"Déléguer son ravitaillement","explore":"Déléguer l'exploration"}[directive],func():
					var result:Dictionary=c.set_system_order(game.player,origin,directive);hint.text="Directive transmise." if bool(result.get("ok",false)) else String(result.get("reason","Refus")),48))
	for card in cards:
		var reason:String=""
		var parts:PackedStringArray=String(card.key).split(":")
		if parts[0] in ["train","module","upgrade_hub","upgrade_unit"]:
			if not OrbitalIndustry.has_hub(c,game.player,body):reason="Chantier opérationnel requis"
			elif not (hub["job"] as Dictionary).is_empty():reason="Production en cours"
			elif parts[0]=="train":
				var definition:Dictionary=OrbitalIndustry.UNITS[parts[1]]
				if c.planets.local_age(c,game.player,body)<int(definition["age"]):reason="Âge local "+J13Rules.roman(int(definition["age"]))+" requis"
				elif not String(definition["module"]).is_empty() and int(hub["modules"].get(definition["module"],0))==0:reason="Module "+String(definition["module"])+" requis"
				elif OrbitalIndustry.population(c,game.player,body)+int(definition["pop"])>OrbitalIndustry.capacity(c,game.player,body):reason="Habitat orbital requis"
				elif not OrbitalIndustry._can_pay(stocks,definition["cost"]):reason="Ressources insuffisantes"
			elif parts[0]=="module":
				var definition:Dictionary=OrbitalIndustry.MODULES[parts[1]]
				if c.planets.local_age(c,game.player,body)<int(definition["age"]):reason="Âge local "+J13Rules.roman(int(definition["age"]))+" requis"
				elif int((hub["modules"] as Dictionary).get(parts[1],0))>=int(definition["limit"]):reason="Limite de modules atteinte"
				elif int(OrbitalIndustry.presence(c,game.player,body).get("drone",0))==0:reason="Drone constructeur requis"
				elif not OrbitalIndustry._can_pay(stocks,definition["cost"]):reason="Ressources insuffisantes"
			elif parts[0]=="upgrade_hub":
				var tier:int=int(hub["tier"])
				if tier>=3:reason="Niveau maximal atteint"
				elif tier==2 and c.planets.local_age(c,game.player,body)<10:reason="Âge X local requis"
				elif not OrbitalIndustry._can_pay(stocks,{"wood":250*(tier+1),"ore":370*(tier+1)}):reason="Ressources insuffisantes"
			elif parts[0]=="upgrade_unit":
				var level:int=int((hub["unit_levels"] as Dictionary).get(parts[1],1))
				if level>=3:reason="Niveau maximal atteint"
				elif level>=int(hub["tier"]):reason="Améliorer d'abord le chantier"
				elif level==2 and c.planets.local_age(c,game.player,body)<10:reason="Âge X local requis"
				else:
					var price:Dictionary={}
					for resource in OrbitalIndustry.UNITS[parts[1]]["cost"]:price[resource]=int(OrbitalIndustry.UNITS[parts[1]]["cost"][resource])*(level+1)*2
					if not OrbitalIndustry._can_pay(stocks,price):reason="Ressources insuffisantes"
		elif card.key=="hub" and not hub.is_empty():reason="Un chantier existe déjà"
		card.availability(reason)
func _process(delta:float)->void:
	if _drawer_open!=UIMotion.is_open(drawer):_drawer_open=UIMotion.is_open(drawer);game._update_camera()
	clock+=delta
	if clock>=0.25:clock=0;refresh()
func back()->bool:
	if not pending.is_empty():pending={};game.orbit_view.placement(Vector2.ZERO,false);hint.text="Placement annulé.";return true
	if UIMotion.is_open(drawer):UIMotion.conceal(drawer);return true
	return false
func _tap(point:Vector2)->void:
	var map_point:Vector2=game.orbit_view.point_at(game.cam,point)
	if not pending.is_empty():
		var cmd:Dictionary=pending.duplicate();cmd["pos"]=map_point
		if bool(_issue(cmd).get("ok",false)):pending={};game.orbit_view.placement(Vector2.ZERO,false)
		return
	var id:int=game.orbit_view.pick(game.cam,point)
	var actors:Dictionary=data()["actors"]
	if id>=0 and actors.has(id):
		var a:Dictionary=actors[id]
		if int(a["team"])==game.player:
			chosen=id
			if multiselect and String(a["role"])=="unit":
				selected=_ships()
				if selected.has(id):selected.erase(id)
				else:selected.append(id)
			else:selected=[id]
			tab="Unités" if String(a["role"])!="unit" else "Voyage";signature="";UIMotion.reveal(drawer);refresh()
		elif not selected.is_empty() and game.campaign.factions.hostile(game.player,int(a["team"])):_issue({"action":"attack","units":_ships(),"target":id})
		else:chosen=id;selected=[];signature="";UIMotion.reveal(drawer);refresh()
	elif not _ships().is_empty():_issue({"action":"amove" if assault else "move","units":_ships(),"pos":map_point})
	else:chosen=-1;selected=[];drawer.hide()
	game.orbit_view.selected=selected.duplicate()
func _ships()->Array:
	var actors:Dictionary=data()["actors"]
	return selected.filter(func(id:Variant)->bool:return actors.has(id) and String(actors[id]["role"])=="unit")
func _pan(relative:Vector2)->void:
	game.orbit_focus-=relative*game.orbit_zoom/650.0
	game.orbit_focus=game.orbit_focus.clamp(Vector2.ONE*4,Vector2.ONE*156);game._update_camera()
func handle_input(event:InputEvent)->void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			if mouse_start.x>=0 and not dragged and not is_over_ui(event.position):_tap(event.position)
			mouse_start=Vector2(-1,-1);dragged=false;return
		if is_over_ui(event.position):return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			game.orbit_zoom=clampf(game.orbit_zoom*(0.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),40,190);game._update_camera();return
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:mouse_start=event.position;mouse_last=event.position;dragged=false
			elif mouse_start.x>=0:
				if not dragged:_tap(event.position)
				mouse_start=Vector2(-1,-1)
	elif event is InputEventMouseMotion:
		if not pending.is_empty():game.orbit_view.placement(game.orbit_view.point_at(game.cam,event.position),not is_over_ui(event.position))
		if mouse_start.x>=0:
			if event.position.distance_to(mouse_start)>14:dragged=true
			if dragged:_pan(event.position-mouse_last)
			mouse_last=event.position
	elif event is InputEventScreenTouch:
		if event.canceled:touches.erase(event.index);starts.erase(event.index);return
		if event.pressed:
			if is_over_ui(event.position):return
			touches[event.index]=event.position;starts[event.index]=event.position
			if touches.size()==2:
				var points:Array=touches.values();pinch=(points[0] as Vector2).distance_to(points[1])
				for id in starts:starts[id]=Vector2(-9999,-9999)
		else:
			if touches.has(event.index) and touches.size()==1 and starts.has(event.index) and not is_over_ui(event.position):
				if (starts[event.index] as Vector2).distance_to(event.position)<14:_tap(event.position)
			touches.erase(event.index);starts.erase(event.index)
			if touches.size()<2:pinch=0
	elif event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index]=event.position
		if touches.size()==2:
			var points:Array=touches.values();var distance:float=(points[0] as Vector2).distance_to(points[1])
			if pinch>10 and distance>10:game.orbit_zoom=clampf(game.orbit_zoom*pinch/distance,40,190);game._update_camera()
			pinch=distance
			for id in starts:starts[id]=Vector2(-9999,-9999)
		else:_pan(event.relative)

func cancel_gestures()->void:
	touches.clear();starts.clear();mouse_start=Vector2(-1,-1);dragged=false;pinch=0


func _apply_orientation() -> void:
	## 0.18 : en portrait, le tiroir de l'orbite devient un panneau du bas, au-dessus du dock.
	var portrait: bool = ResponsiveLayout.is_portrait(root)
	ResponsiveLayout.apply(drawer, ResponsiveLayout.spec(Vector4(0, 0.45, 1, 1), Vector4(8, 0, -8, -112)) if portrait else {})
