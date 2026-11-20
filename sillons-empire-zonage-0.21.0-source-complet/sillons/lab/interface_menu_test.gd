extends SceneTree
var frames:int=0
var checks:int=0
var failures:int=0
var menu
var quality:int=2
func _initialize()->void:change_scene_to_file("res://game/main_menu.tscn")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func tap(control:Control)->void:
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=4;event.position=control.get_global_rect().get_center();event.pressed=pressed;root.push_input(event,true)
func button(caption:String)->Button:
	for node in menu.find_children("*","Button",true,false):
		if String(node.text)==caption:return node
	return null
func _process(_delta:float)->bool:
	frames+=1
	if frames==10:
		menu=current_scene;GameConfig.reduce_motion=true
		check(menu.backdrop!=null and menu.backdrop.stage.get_child_count()>10,"menu avec décor 3D du jeu")
		check(button("COMMENCER UNE CAMPAGNE   →")!=null and button("Choisir une planète")!=null,"accès campagne et planète lisibles")
		check(button("Continuer mon empire").disabled,"reprise désactivée si aucun fichier de sauvegarde")
		tap(button("Paramètres"))
	if frames==12:
		check(UIMotion.is_open(menu.settings_drawer) and menu.settings_scrim.visible,"paramètres tactiles avec fond modal")
		quality=GameConfig.visual_quality;tap(menu._quality_menu)
	if frames==14:
		check(GameConfig.visual_quality==(quality+1)%3,"changement de profil graphique")
		GameConfig.visual_quality=0;menu.backdrop.apply_quality()
		check(not menu.backdrop.sunlight.shadow_enabled and menu.get_viewport().scaling_3d_scale<0.8,"profil économie appliqué au décor sans réduire l'UI")
		GameConfig.reduce_motion=true;var camera:Vector3=menu.backdrop.camera.position;menu.backdrop._process(1)
		check(menu.backdrop.camera.position==camera,"réduction des animations respecte le choix")
		menu._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		check(not UIMotion.is_open(menu.settings_drawer) and not menu.settings_scrim.visible,"Retour ferme les paramètres")
		tap(button("Laboratoire et scénarios"))
	if frames==16:
		check(UIMotion.is_open(menu._lab_drawer) and menu.lab_list.item_count>0,"anciens ateliers accessibles dans le nouveau menu")
		GameConfig.reduce_motion=false;menu._toggle_laboratory();menu._toggle_laboratory()
		check(UIMotion.is_open(menu._lab_drawer),"réouverture rapide sans panneau bloqué")
		print("INTERFACE_MENU_RESULT checks=",checks," failures=",failures)
		quit(0 if failures==0 else 1)
	return false
