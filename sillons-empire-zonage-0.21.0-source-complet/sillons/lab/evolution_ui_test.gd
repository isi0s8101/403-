extends SceneTree
var frames: int = 0
var failures: int = 0
var checks: int = 0
var game
func _initialize() -> void:
	GameConfig.mode="empire"
	GameConfig.seed_value=14001
	change_scene_to_file("res://game/game.tscn")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1
	print(("PASS " if value else "FAIL ")+label)
func _process(_delta: float) -> bool:
	frames+=1
	if frames==14:
		game=current_scene
		game.paused=true
		check(game.campaign.evolutions_enabled and game.world.map_size==256,"U01 campagne principale raccordée")
		check(game.campaign.planets.colony(0,"val")["pop"]>0 and game.campaign.planets.colony(1,"nemesis")["pop"]>0,"M02 dotations civiles symétriques")
		for button in game.hud.root.find_children("*", "Button", true, false):
			if button.text == "Conseil":
				for pressed in [true, false]:
					var touch := InputEventScreenTouch.new()
					touch.index = 6
					touch.pressed = pressed
					touch.position = button.get_global_rect().get_center()
					root.push_input(touch, true)
	if frames==16:
		check(game.evolution_panel.visible and game.hud.is_over_ui(game.evolution_panel.get_global_rect().get_center()),"U01 conseil bloque les gestes du terrain")
		game.evolution_panel._policy("tax",0.1)
		check(is_equal_approx(float(game.campaign.planets.colony(0,"val")["politics"]["tax"]),0.1),"U01 politique envoyée au modèle")
		game.evolution_panel.page="Aménagement"
		game.evolution_panel.rebuild()
		check(game.evolution_panel.content.get_child_count()>10,"U01 aménagement accessible avant la vue spatiale")
		game.evolution_panel.page="Routes"
		game.evolution_panel.rebuild()
		check(game.evolution_panel.content.get_children().filter(func(child: Node) -> bool: return child is RoadAtlas).size()==1,"U01 atlas routier tactile présent")
		game._back_action()
		check(not game.evolution_panel.visible,"U01 retour ferme le conseil")
	if frames==39:
		var b: SimWorld.Building = game.world.spawn_building(0, "caserne", Vector2i(25,220), true)
		game.world.issue({"t":"rally","team":0,"building":b.id,"pos":[30,230]})
		game.sel_building = b.id
		game._sync_rally_flag()
		check(game.view.rally_flag != null and game.view.rally_flag.visible, "R01 drapeau permanent visible sur le terrain")
	if frames==40:
		check(game.view.terrain_streamer!=null and int(game.view.terrain_streamer.stats()["resident"])<=16 and game.view.terrain_streamer.chunk_size==32,"M04 secteurs graphiques 32, cache borné")
		print("EVOLUTION_UI_RESULT checks=",checks," failures=",failures)
		quit(0 if failures==0 else 1)
	return false
