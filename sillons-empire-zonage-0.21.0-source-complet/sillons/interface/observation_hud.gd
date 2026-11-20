class_name ObservationHud
extends CanvasLayer
var game
var root:Control
var panel:PanelContainer
var title:Label
var details:Label
var traffic:VBoxContainer
var is_galaxy:bool=false
var _last_tick:int=-1
var _signature:String=""
var orbit_btn:Button
var land_btn:Button
var zoom_button:Button
func build(p_game,p_galaxy:bool)->void:
	game=p_game;is_galaxy=p_galaxy;layer=15
	root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=MobileUI.theme();add_child(root)
	var header:=PanelContainer.new();header.name="Header";header.anchor_right=1;header.offset_left=12;header.offset_right=-12;header.offset_top=12;header.offset_bottom=78;root.add_child(header)
	var row:=HBoxContainer.new();header.add_child(row)
	title=Label.new();title.clip_text=true;title.add_theme_font_size_override("font_size",19);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title)
	row.add_child(MobileUI.button("Terrain",func():game.leave_space_overview(true),48))
	orbit_btn=MobileUI.button("Carte orbitale",_open_orbit,48);row.add_child(orbit_btn)
	zoom_button=MobileUI.button("Système" if is_galaxy else "Galaxie",_navigate,48);row.add_child(zoom_button)
	for child in row.get_children():
		if child is Button:child.size_flags_horizontal=Control.SIZE_SHRINK_END;child.custom_minimum_size.x=96
	panel=PanelContainer.new();panel.anchor_right=1;panel.anchor_top=1;panel.anchor_bottom=1
	panel.offset_left=12;panel.offset_right=-12;panel.offset_top=-200;panel.offset_bottom=-12;root.add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	var strip:=HBoxContainer.new();box.add_child(strip)
	details=Label.new();details.add_theme_font_size_override("font_size",13);details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;strip.add_child(details)

	var fold:Button=MobileUI.button("−",_fold,48);fold.size_flags_horizontal=Control.SIZE_SHRINK_END;fold.custom_minimum_size.x=48;strip.add_child(fold)
	var scroll:=ScrollContainer.new();scroll.name="TrafficList";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
	traffic=VBoxContainer.new();traffic.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(traffic)
	refresh(true)
func _fold()->void:
	var scroller:Control=traffic.get_parent() as Control
	scroller.visible=not scroller.visible
	panel.offset_top=-200 if scroller.visible else -80
func _open_orbit()->void:
	if is_galaxy:game.open_galaxy_system(game.galaxy_selected)
	game.enter_space_overview("orbit")
func _navigate()->void:
	if is_galaxy:game.open_galaxy_system(game.galaxy_selected)
	else:game.enter_space_overview("galaxy")
func is_over_ui(point:Vector2)->bool:
	return panel.get_global_rect().has_point(point) or (root.get_node("Header") as Control).get_global_rect().has_point(point)
func refresh(force:bool=false)->void:
	var c:StarCampaign=game.campaign
	if not force and c.tick-_last_tick<10:return
	_last_tick=c.tick
	var system:String=game.galaxy_selected if is_galaxy else c._system_of(game.space_selected)
	var known:bool=c.system_known(game.player,system)
	var caption:String=String(c.star_catalog.galaxy.systems[system]["label"]) if known else "Signal inconnu"
	title.text=("GALAXIE" if is_galaxy else "SYSTÈME")+"  /  "+caption
	if is_galaxy:game.galaxy_view.select_marker(game.galaxy_selected)
	else:title.text+="  ·  "+String(c.info(game.space_selected).get("label",""));game.space_view.select_marker(game.space_selected)
	details.text="OBSERVATION DU TRAFIC · sélectionner pour naviguer · les ordres se donnent sur les cartes jouables."
	orbit_btn.disabled=not known
	zoom_button.disabled=is_galaxy and not known
	var rows:Array=MovementFeed.records(c,game.player)
	if not is_galaxy:rows=rows.filter(func(item:Dictionary)->bool:return String(item["from_system"])==system or String(item["to_system"])==system)
	var signature:String=str(rows)
	if signature==_signature and not force:return
	_signature=signature;UIMotion.clear(traffic)
	if rows.is_empty():
		var empty:=Label.new();empty.text="Aucun déplacement connu en cours.";empty.theme_type_variation="MutedLabel";traffic.add_child(empty)
	for record in rows:
		var row:=HBoxContainer.new();traffic.add_child(row)
		var info:=Label.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		info.text="%s  •  %s → %s"%[record["kind"],MovementFeed.caption(c,String(record["from"])),MovementFeed.caption(c,String(record["to"]))]
		info.add_theme_color_override("font_color",MovementFeed.tint(record,game.player));row.add_child(info)
		var progress:=ProgressBar.new();progress.custom_minimum_size=Vector2(160,12);progress.show_percentage=false
		progress.value=clampf(100.0*(1-float(record["eta"])/float(record["duration"])),0,100);row.add_child(progress)
		var eta:=Label.new();eta.text="%d s"%ceili(float(record["eta"])/10);eta.custom_minimum_size.x=52;row.add_child(eta)
