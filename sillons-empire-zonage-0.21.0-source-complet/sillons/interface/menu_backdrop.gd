class_name MenuBackdrop
extends Node3D
var sunlight:DirectionalLight3D
var camera: Camera3D
var stage: Node3D
var clock: float = 0.0
var age: int = 1
func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("13283c")
	sky_material.sky_horizon_color = Color("879b9e")
	sky_material.ground_horizon_color = Color("566d69")
	sky.sky_material = sky_material; settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_energy = 0.6
	settings.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.environment = settings; add_child(environment)
	var sun := DirectionalLight3D.new(); sunlight=sun; sun.rotation_degrees = Vector3(-32,-36,0)
	sun.light_color = Color("ffe8bb"); sun.light_energy = 1.6; sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 42; sun.shadow_bias = 0.12; sun.shadow_normal_bias = 2
	add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-55,145,0)
	fill.light_color = Color("80b5d1"); fill.light_energy = 0.35; add_child(fill)
	camera = Camera3D.new(); camera.fov = 44; camera.position = Vector3(17,13,21)
	add_child(camera); camera.look_at(Vector3(0,1.4,0)); camera.current = true
	var ground := MeshInstance3D.new(); var mesh := PlaneMesh.new(); mesh.size=Vector2(700,700)
	ground.mesh=mesh; ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new(); material.albedo_texture=RealismAssets.texture("grass")
	material.normal_enabled=true; material.normal_texture=RealismAssets.texture("grass","normal")
	material.roughness=0.95; material.uv1_scale=Vector3(120,120,120)
	ground.material_override=material; add_child(ground)
	stage=Node3D.new(); add_child(stage); show_age(1); apply_quality()
func show_age(value: int) -> void:
	age=value
	if stage==null:return
	UIMotion.clear(stage)
	var examples: Array = [["centre",Vector3(1,0,1),6],["maison",Vector3(-6,0,0),4],["caserne",Vector3(0,0,-7),5],["maison",Vector3(7,0,-5),4]]
	if age>=4: examples[2][0]="usine"
	if age>=9: examples[1][0]="spatioport"
	for example in examples:
		var model: Node3D = TacticalModels.building(String(example[0]),0,int(example[2]),age,0)
		if model!=null: model.position=example[1]; stage.add_child(model)
	for i in 12:
		var tree: Node3D=RealismAssets.instantiate("oak_"+str([3,11,21][i%3]))
		if tree==null:continue
		var angle:float=float(i)*0.63
		tree.position=Vector3(cos(angle)*16,0,sin(angle)*15-6)
		tree.scale=Vector3.ONE*(0.8+0.12*float(i%3)); stage.add_child(tree)
	for i in 4:
		var person:Node3D=TacticalModels.unit("ouvrier",0,age,0)
		if person!=null: person.position=Vector3(-1+i*0.85,0,5); person.rotation.y=0.8; stage.add_child(person)
func _process(delta:float)->void:
	if GameConfig.reduce_motion or camera==null:return
	clock+=delta
	camera.position=Vector3(17+sin(clock*0.09)*0.7,13,21+cos(clock*0.07)*0.6)
	camera.look_at(Vector3(0,1.4,0))

func apply_quality()->void:
	if sunlight==null:return
	sunlight.shadow_enabled=GameConfig.visual_quality>0
	get_viewport().scaling_3d_scale=[0.70,0.85,1.0][GameConfig.visual_quality]
	Engine.max_fps=30 if GameConfig.visual_quality==0 else 60
