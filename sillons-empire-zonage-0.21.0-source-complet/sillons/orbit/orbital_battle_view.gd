class_name OrbitalBattleView
extends Node3D
var campaign: StarCampaign
var body: String
var player: int = 0
var actors: Dictionary = {}
var selected: Array = []
var planet: PlanetGlobeView
var shots: MeshInstance3D
var _last_shot_tick: int = -1
var ghost: MeshInstance3D
var _materials: Dictionary = {}
var orders:MeshInstance3D
var rally_marker:Node3D
var blueprints:Dictionary={}
func setup(c: StarCampaign, planet_id: String, team: int) -> void:
	campaign=c;body=planet_id;player=team
	position=Vector3(-32,0,-32)
	OrbitalTactics.enable(c)
	var stars:=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
	var sphere:=SphereMesh.new();sphere.radius=0.10;sphere.height=0.2;sphere.radial_segments=6;sphere.rings=3;mm.mesh=sphere;mm.instance_count=180
	for i in 180:
		var x:float=float(posmod(i*7919+37,701))-270
		var z:float=float(posmod(i*1531+91,701))-270
		mm.set_instance_transform(i,Transform3D(Basis(),Vector3(x,-28-float(i%9),z)))
	stars.multimesh=mm;stars.material_override=_material(Color("789aad"),true);add_child(stars)
	planet=PlanetGlobeView.new();add_child(planet);planet.setup(int(c.info(body)["seed"]))
	planet.position=Vector3(80,-12,80);planet.scale=Vector3.ONE*1.12
	if planet.marker!=null:planet.marker.hide()
	_rings()
	shots=MeshInstance3D.new();add_child(shots)
	orders=MeshInstance3D.new();add_child(orders)
	rally_marker=Node3D.new();add_child(rally_marker)
	var beacon:=MeshInstance3D.new();var beacon_mesh:=CylinderMesh.new();beacon_mesh.top_radius=0.3;beacon_mesh.bottom_radius=0.9;beacon_mesh.height=3;beacon.mesh=beacon_mesh;beacon.position.y=1.5;beacon.material_override=_material(OrbitalTactics.color(player),true);rally_marker.add_child(beacon)
	var caption:=Label3D.new();caption.text="RALLIEMENT";caption.position.y=5;caption.pixel_size=0.08;caption.font_size=24;caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED;caption.modulate=OrbitalTactics.color(player);rally_marker.add_child(caption)
	var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-55,115,0);rim.light_color=Color("b3d2e6");rim.light_energy=1.3;add_child(rim)
	ghost=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=3.4;cylinder.bottom_radius=3.4;cylinder.height=0.15;cylinder.radial_segments=32
	ghost.mesh=cylinder;ghost.material_override=_material(Color(0.3,1,0.8,0.45),true);ghost.hide();add_child(ghost)
	sync(1)
func _material(color:Color,emissive:bool=false)->StandardMaterial3D:
	var key:String=color.to_html()+str(emissive)
	if _materials.has(key):return _materials[key]
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=0.6;material.metallic=0.25
	if emissive:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a<1:material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key]=material;return material
func _rings()->void:
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES,_material(Color("1d3f50"),true))
	for radius in [26.0,48.0,70.0]:
		for i in 96:
			var a:float=float(i)*TAU/96;var b:float=float(i+1)*TAU/96
			mesh.surface_add_vertex(Vector3(80+cos(a)*radius,-0.2,80+sin(a)*radius))
			mesh.surface_add_vertex(Vector3(80+cos(b)*radius,-0.2,80+sin(b)*radius))
	for i in range(0,161,20):
		mesh.surface_add_vertex(Vector3(i,-0.5,0));mesh.surface_add_vertex(Vector3(i,-0.5,160))
		mesh.surface_add_vertex(Vector3(0,-0.5,i));mesh.surface_add_vertex(Vector3(160,-0.5,i))
	mesh.surface_end();var node:=MeshInstance3D.new();node.mesh=mesh;add_child(node)
func _make_actor(a:Dictionary)->Node3D:
	var root:=Node3D.new()
	var structure:bool=String(a["role"])!="unit"
	var kind:String="shipyard" if String(a["role"])=="hub" else String(a["type"])
	var family:String={"drone":"builder_drone","sonde":"probe","navette":"shuttle","intercepteur":"interceptor","fregate":"frigate","command":"station","hydroponie":"hydroponics","extracteur":"extractor","batterie":"battery"}.get(kind,kind)
	var id:String=AssetLibrary.find("orbital_structure" if structure else "spaceship",family,10)
	var model:Node3D=AssetLibrary.instantiate_compact(id,1)
	if model!=null:
		RealismAssets.enhance_legacy(model)
		model.scale=Vector3.ONE*AssetLibrary.scale_for_cells(id,6.2 if structure else (4.0 if kind=="fregate" else 2.8))
		AssetLibrary.set_team_color(model,OrbitalTactics.color(int(a["team"])));root.add_child(model)
	else:
		var fallback:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(3,1,4) if structure else Vector3(1.3,0.5,2.4)
		fallback.mesh=mesh;fallback.material_override=_material(OrbitalTactics.color(int(a["team"])));root.add_child(fallback)
	var label:=Label3D.new();label.name="Label";label.pixel_size=0.08;label.font_size=28;label.position.y=5.0 if structure else 2.6
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=OrbitalTactics.color(int(a["team"]));root.add_child(label)
	var ring:=MeshInstance3D.new();ring.name="Ring"
	var mesh:=TorusMesh.new();mesh.inner_radius=3.5 if structure else 1.8;mesh.outer_radius=3.65 if structure else 1.95;mesh.rings=16;mesh.ring_segments=8
	ring.mesh=mesh;ring.material_override=_material(OrbitalTactics.color(int(a["team"])),true);root.add_child(ring)
	add_child(root);return root
func sync(alpha:float)->void:
	var data:Dictionary=OrbitalTactics.map_for(campaign,body)
	_sync_construction()
	rally_marker.visible=data["rally"].has(player)
	if rally_marker.visible:
		var flag_point:Vector2=data["rally"][player];rally_marker.position=Vector3(flag_point.x,0,flag_point.y)
	var state:Dictionary=data["actors"]
	for id in actors.keys():
		if not state.has(id):actors[id].queue_free();actors.erase(id)
	for id in state:
		var a:Dictionary=state[id]
		if not actors.has(id):actors[id]=_make_actor(a)
		var node:Node3D=actors[id]
		node.visible=OrbitalTactics.visible(campaign,body,player,a)
		if not node.visible:continue
		var point:Vector2=(a["prev"] as Vector2).lerp(a["pos"],clampf(alpha,0,1))
		node.position=Vector3(point.x,1.2,point.y)
		var motion:Vector2=(a["pos"] as Vector2)-(a["prev"] as Vector2)
		if motion.length_squared()>0.0001:node.rotation.y=atan2(motion.x,motion.y)
		var chosen:bool=selected.has(id)
		node.get_node("Ring").visible=chosen
		var label:Label3D=node.get_node("Label") as Label3D
		label.text=(String(OrbitalIndustry.UNITS[a["type"]]["label"]) if String(a["role"])=="unit" else ("Chantier naval" if String(a["role"])=="hub" else String(OrbitalIndustry.MODULES.get(a["type"],{"label":"Station de commandement"})["label"])))+"\n%d / %d PV"%[a["hp"],a["max_hp"]]
		label.visible=chosen or int(a["hit"])>campaign.tick-20 or String(a["role"])=="hub"
		if not bool(a.get("ready",true)):label.text="ASSEMBLAGE\n"+label.text
	if _last_shot_tick!=int(data["last_tick"]):
		_last_shot_tick=int(data["last_tick"])
		_order_lines(state)
		var mesh:=ImmediateMesh.new()
		if not (data["events"] as Array).is_empty():
			mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			for event in data["events"]:
				var from:Vector2=event["from"];var to:Vector2=event["to"]
				mesh.surface_set_color(OrbitalTactics.color(int(event["team"])));mesh.surface_add_vertex(Vector3(from.x,1.8,from.y));mesh.surface_set_color(Color.WHITE);mesh.surface_add_vertex(Vector3(to.x,1.8,to.y))
			mesh.surface_end()
		shots.mesh=mesh
		var material:StandardMaterial3D=_material(Color.WHITE,true);material.vertex_color_use_as_albedo=true;shots.material_override=material
func pick(camera:Camera3D,screen:Vector2)->int:
	var candidate:int=-1;var best:float=40
	for id in actors:
		var node:Node3D=actors[id]
		if not node.visible or camera.is_position_behind(node.global_position):continue
		var distance:float=camera.unproject_position(node.global_position).distance_to(screen)
		if distance<best:best=distance;candidate=int(id)
	return candidate
func point_at(camera:Camera3D,screen:Vector2)->Vector2:
	var origin:Vector3=camera.project_ray_origin(screen)
	var direction:Vector3=camera.project_ray_normal(screen)
	if absf(direction.y)<0.00001:return Vector2(-1,-1)
	var hit:Vector3=origin+direction*(-origin.y/direction.y)-position
	return Vector2(hit.x,hit.z)
func placement(point:Vector2,enabled:bool)->void:
	ghost.visible=enabled
	ghost.position=Vector3(point.x,0.2,point.y)
	ghost.material_override=_material(Color(0.3,1,0.8,0.5) if OrbitalTactics.valid_point(point) else Color(1,0.3,0.3,0.5),true)

func _order_lines(state:Dictionary)->void:
	var mesh:=ImmediateMesh.new();var count:int=0
	for id in selected:
		if state.has(id):count+=(state[id]["path"] as Array).size()
	if count>0:
		mesh.surface_begin(Mesh.PRIMITIVE_LINES,_material(Color("64a6a1"),true))
		for id in selected:
			if not state.has(id):continue
			var point:Vector2=state[id]["pos"]
			for waypoint in state[id]["path"]:
				mesh.surface_add_vertex(Vector3(point.x,0.3,point.y));mesh.surface_add_vertex(Vector3(waypoint.x,0.3,waypoint.y));point=waypoint
		mesh.surface_end()
	orders.mesh=mesh
func _sync_construction()->void:
	var hub:Dictionary=OrbitalIndustry.site(campaign,player,body)
	var job:Dictionary=hub.get("job",{})
	var active:bool=String(job.get("mode",""))=="module" and job.has("map_pos")
	if not active:
		for node in blueprints.values():node.queue_free()
		blueprints.clear();return
	if blueprints.is_empty():
		var node:=Node3D.new();add_child(node)
		var ring:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=3.2;mesh.outer_radius=3.5;mesh.rings=24;mesh.ring_segments=6;ring.mesh=mesh;ring.material_override=_material(Color("e9c480"),true);node.add_child(ring)
		var label:=Label3D.new();label.name="Label";label.position.y=4;label.pixel_size=0.08;label.font_size=26;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("e9c480");node.add_child(label);blueprints[player]=node
	var node:Node3D=blueprints[player];var point:Vector2=job["map_pos"];node.position=Vector3(point.x,0.5,point.y)
	(node.get_node("Label") as Label3D).text=String(OrbitalIndustry.MODULES[job["kind"]]["label"])+"\nConstruction · %d s"%ceili(float(job["remaining"])/10)
