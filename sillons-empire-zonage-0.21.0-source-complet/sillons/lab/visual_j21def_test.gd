extends SceneTree
## Recette graphique J2.1-D/E/F. Exécution Godot :
## godot --headless --path . -s res://lab/visual_j21def_test.gd
## Ne dépend pas de l'affichage GPU, ne modifie aucun état de simulation.

var game
var frames: int = 0
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	GameConfig.mode = "lab"
	GameConfig.lab_path = "res://lab/scenarios/r04_delegation.json"
	GameConfig.visual_quality = 2
	change_scene_to_file("res://game/game.tscn")

func _check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s VISUAL_J21DEF %s" % ["PASS" if ok else "FAIL", name])

func _finish() -> void:
	print("VISUAL_J21DEF_RESULT=%s checks=%d fail=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 12:
		return false
	if game == null:
		game = current_scene
		if game == null:
			_check("scene_chargee", false)
			_finish()
			return false
		game.paused = true
		return false
	var v: WorldView = game.view as WorldView
	_check("vue_disponible", v != null)
	if v == null:
		_finish()
		return false
	var state_before: String = game.world.state_hash()
	var tick_before: int = int(game.world.tick)
	var own_unit = null
	for u in game.world.units.values():
		if u.team == game.player and u.type in ["ouvrier", "lancier", "tireur", "cavalier"]:
			own_unit = u
			break
	_check("unite_amie_disponible", own_unit != null)
	if own_unit != null:
		v.set_visual_lod(23.0, own_unit.pos)
		v.sync(1.0, 0.0)
		var node: Node3D = v.unit_nodes.get(own_unit.id) as Node3D
		_check("modele_unite_existant", node != null)
		if node != null:
			if node.has_meta("library_asset"):
				_check("modele_bibliotheque_proche", int(node.get_meta("library_lod", 1)) == 0)
				var players: Array = node.get_meta("players", []) as Array
				_check("squelette_anime_proche", not players.is_empty())
				TacticalModels.animate(node, true, false, false, 2.4)
				if not players.is_empty():
					_check("cycle_marche", (players[0] as AnimationPlayer).current_animation == "walk")
				v.set_visual_lod(65.0, own_unit.pos)
				v.sync(1.0, 0.0)
				var distant: Node3D = v.unit_nodes[own_unit.id] as Node3D
				_check("lod_statique_sans_squelette", int(distant.get_meta("library_lod", 0)) == 1 and (distant.get_meta("players", []) as Array).is_empty())
			else:
				_check("rig_articule_proche", node.get_node_or_null("Body/Figure/Rig") != null)
				var arm: Node3D = node.get_node_or_null("Body/Figure/Rig/Chest/ArmLeft") as Node3D
				_check("articulation_epaule", arm != null)
				if arm != null:
					UnitVisual.animate(node, own_unit.type, own_unit.id, true, false, false, 0.65, 1.0)
					_check("cycle_marche", absf(arm.rotation.x) > 0.001)
					UnitVisual.set_lod(node, false)
					var rig: Node3D = node.get_node("Body/Figure/Rig") as Node3D
					_check("lod_simple", not rig.visible)
					UnitVisual.set_lod(node, true)
					_check("lod_detail", rig.visible)
	var own_building = null
	for b in game.world.buildings.values():
		if b.team == game.player and b.type != "ferme":
			own_building = b
			break
	_check("batiment_disponible", own_building != null)
	if own_building != null:
		v.set_visual_lod(23.0, own_building.center)
		v.sync(1.0, 0.0)
		var wrapper: Node3D = v.building_nodes.get(own_building.id) as Node3D
		_check("batiment_rendu", wrapper != null)
		if wrapper != null:
			var model: Node3D = wrapper.get_node("Model") as Node3D
			_check("detail_architectural", model.get_node_or_null("Architecture") != null)
			BuildingVisual.set_damage(model, 0.2)
			BuildingVisual.set_lod(model, true)
			var damage: Node3D = model.get_node_or_null("Damage") as Node3D
			_check("impact_persistant", damage != null and damage.visible)
			if damage != null:
				var cracks: Node3D = damage.get_node_or_null("Cracks") as Node3D
				_check("fissures_sante_critique", cracks != null and cracks.visible)
			BuildingVisual.set_damage(model, 1.0)
			_check("degat_retirable", damage != null and not damage.visible)
	game.set_visual_quality(0)
	_check("profil_economie", int(v.visual_stats()["quality"]) == 0 and not game.sun.shadow_enabled)
	game.set_visual_quality(2)
	_check("profil_detail", int(v.visual_stats()["quality"]) == 2)
	_check("limite_rigs", int(v.visual_stats()["rigs"]) <= WorldView.MAX_VISUAL_RIGS)
	_check("limite_batiments", int(v.visual_stats()["buildings"]) <= WorldView.MAX_DETAILED_BUILDINGS)
	_check("effets_bornes", WorldView.MAX_VISUAL_FX > 0)
	_check("menu_qualite", game.hud.quality_btn != null)
	_check("aide_tactile", game.hud.controls_panel != null and not game.hud.controls_panel.visible)
	_check("simulation_inalteree", game.world.tick == tick_before and game.world.state_hash() == state_before)
	_finish()
	return false
