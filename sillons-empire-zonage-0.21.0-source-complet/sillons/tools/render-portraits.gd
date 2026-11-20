extends SceneTree
## Génère les photos de l'interface à partir des modèles réellement employés en jeu.
## À exécuter avec un pilote graphique, puis conserver les PNG .bytes dans le paquet.
var stage:Node3D
var camera:Camera3D
var floor_node:MeshInstance3D
var catalog:Dictionary={}
var completed:int=0
func _initialize()->void:
	_generate.call_deferred()
func bounds(node:Node3D)->AABB:
	var combined:=AABB()
	var found:bool=false
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or not mesh.visible:continue
		var box:AABB=(node.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
		combined=combined.merge(box) if found else box;found=true
	return combined
func _generate()->void:
	root.size=Vector2i(256,192)
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("142b35")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("b8d5e1");settings.ambient_light_energy=0.7
	settings.tonemap_mode=Environment.TONE_MAPPER_AGX;env.environment=settings;scene.add_child(env)
	for direction in [Vector3(-40,-35,0),Vector3(-15,120,0)]:
		var light:=DirectionalLight3D.new();light.rotation_degrees=direction
		light.light_energy=1.8 if direction.y<0 else 0.7;light.light_color=Color("ffe9cf") if direction.y<0 else Color("93bfcf")
		light.shadow_enabled=direction.y<0;scene.add_child(light)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;scene.add_child(camera)
	stage=Node3D.new();scene.add_child(stage)
	floor_node=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2.ONE*500;floor_node.mesh=plane;floor_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new();material.albedo_color=Color("1b343f");material.roughness=0.9;floor_node.material_override=material;scene.add_child(floor_node)
	for age in range(1,11):
		for kind in Rules.BUILDINGS:
			if kind=="comptoir":continue
			var model:Node3D=TacticalModels.building(kind,0,int(Rules.BUILDINGS[kind]["size"]),age,0)
			if model==null:model=Assets.build_building(kind,0,int(Rules.BUILDINGS[kind]["size"]))
			await photograph(model,"building:%s:%d"%[kind,age])
		for kind in Rules.UNITS:
			var model:Node3D=TacticalModels.unit(kind,0,age,0)
			if model==null:model=Assets.build_unit(kind,0)
			await photograph(model,"unit:%s:%d"%[kind,age])
		print("PORTRAIT_AGE_DONE ",age)
	var file:=FileAccess.open("res://interface/portraits-models.json",FileAccess.WRITE);file.store_string(JSON.stringify(catalog,"\t"));file.close()
	print("PORTRAIT_RENDER_RESULT count=",completed);quit()
func photograph(model:Node3D,key:String)->void:
	if model==null:push_error("Modèle absent : "+key);quit(1);return
	UIMotion.clear(stage);stage.add_child(model)
	await process_frame;await process_frame
	var box:AABB=bounds(model)
	if key.begins_with("unit:") and model.has_meta("library_asset"):
		var record:Dictionary=AssetLibrary.info(String(model.get_meta("library_asset")))
		if String(record.get("category","")).begins_with("unit_") and key.get_slice(":",1) not in ["cavalier","eclaireur","canon"]:
			box=box.merge(AABB(Vector3(-0.55*Assets.UNIT_SCALE,0,-0.55*Assets.UNIT_SCALE),Vector3(1.1,1.4,1.1)*Assets.UNIT_SCALE))
	var center:Vector3=box.get_center()
	var extent:float=maxf(0.2,box.size.length())
	camera.size=extent*0.86;camera.near=0.01;camera.far=extent*20+100
	camera.position=center+Vector3(1.35,1.05,1.65).normalized()*extent*4
	camera.look_at(center,Vector3.UP);floor_node.position.y=box.position.y-0.02
	await process_frame;await process_frame
	await RenderingServer.frame_post_draw
	var file_name:String="model_"+key.replace(":","_")+".png.bytes"
	if root.get_texture().get_image().save_png("res://interface/photos/"+file_name)!=OK:push_error("Écriture photo : "+key);quit(1);return
	catalog[key]=file_name;completed+=1
