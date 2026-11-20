extends SceneTree
var failures: int = 0
func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures += 1
func _initialize() -> void:
	var c := StarCampaign.new()
	CampaignSetup.create(c, 14001, false, 256)
	check(c.current().map_size == 256, "M01 dimensions 256")
	check(c.worlds["val"].team_buildings(1, "centre").is_empty(), "M01 aucun adversaire principal sur Val")
	check(c.worlds["nemesis"].team_buildings(1, "centre", true).size() == 1, "M01 civilisation adverse active")
	check(c.ages == [1, 1] and c.system_known(0, "sol") and not c.system_known(0, "proxima") and not c.system_known(1, "sol"), "M02 origines et connaissances propres")
	for tick in 80: c.step()
	var snap: Dictionary = CampaignSave.snapshot(c)
	var restored: StarCampaign = CampaignSave.from_snapshot(snap)
	check(restored != null, "S01 sauvegarde V2 acceptée")
	if restored != null:
		check(c.state_hash() == restored.state_hash(), "S01 hash initial identique")
		for tick in 40:
			c.step()
			restored.step()
		check(c.state_hash() == restored.state_hash(), "S01 continuation déterministe")
	var other_view := StarCampaign.new()
	CampaignSetup.create(other_view, 14001, false, 256)
	var observed := StarCampaign.new()
	CampaignSetup.create(observed, 14001, false, 256)
	other_view.active = "nemesis"
	for tick in 250:
		observed.step()
		other_view.step()
	var dense_reference: SimWorld = SaveGame.from_snapshot(SaveGame.snapshot(observed.current()))
	dense_reference.rules["dense_fog_reference"] = true
	var sparse: SimWorld = observed.current()
	for tick in 100:
		sparse.step()
		dense_reference.step()
	check(sparse.teams[0].fog == dense_reference.teams[0].fog and sparse.teams[1].fog == dense_reference.teams[1].fog, "M05 brouillard compact identique à la référence dense")
	# La comparaison des deux campagnes doit porter sur la même échéance.
	for tick in 100: other_view.worlds["val"].step()
	var invariant: bool = observed.raw_stocks == other_view.raw_stocks and SaveGame.fields(observed.planets) == SaveGame.fields(other_view.planets)
	for body in observed.worlds: invariant = invariant and SaveGame.snapshot(observed.worlds[body]) == SaveGame.snapshot(other_view.worlds[body])
	check(invariant, "M04 simulation observée et hors écran identique")
	check(CampaignSave.save(c, "user://evolutions-recette.save") == OK, "S01 écriture atomique V2")
	var disk: StarCampaign = CampaignSave.load_campaign("user://evolutions-recette.save", false)
	check(disk != null and disk.state_hash() == c.state_hash(), "S01 fichier et SHA restaurés")
	check(CampaignSave.save(c, "user://evolutions-recette.save") == OK, "S01 backup V2 conservé")
	var corrupt := FileAccess.open("user://evolutions-recette.save", FileAccess.WRITE)
	corrupt.store_string("invalid")
	corrupt.close()
	check(CampaignSave.load_campaign("user://evolutions-recette.save") != null and CampaignSave.last_load_source == "backup", "S02 fichier corrompu : reprise du backup V2")
	print("EVOLUTION_RESULT failures=", failures)
	quit(0 if failures == 0 else 1)
