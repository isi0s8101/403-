extends SceneTree
## J12.3 : tests réels Godot, aucune réussite synthétique.
var count: int = 0
var fail: int = 0

func check(ok: bool, detail: String) -> void:
	count += 1
	if not ok:
		fail += 1
	print(("PASS " if ok else "FAIL ") + detail)

func _initialize() -> void:
	var c := StarCampaign.new()
	c.create(12032026)
	var key: String = OrbitalIndustry.key(0, "val")
	check(OrbitalIndustry.site(c, 0, "val").is_empty(), "Avant IX : aucun chantier naval orbital")
	c.ages[0] = 9
	c.resources[0] = {"food": 250000.0, "wood": 250000.0, "ore": 250000.0}
	c._sync_all()
	OrbitalIndustry.step(c)
	check(c.orbital_initial_granted[0] and c.orbital_sites.has(key), "Âge IX : chantier orbital initial automatique")
	check(not OrbitalIndustry.has_hub(c, 0, "val"), "Assemblage non instantané")
	for i in OrbitalIndustry.START_TICKS:
		OrbitalIndustry.step(c)
	check(OrbitalIndustry.has_hub(c, 0, "val"), "Chantier naval devenu centre opérationnel")
	check(int(OrbitalIndustry.presence(c, 0, "val").get("drone", 0)) == 1, "Drone constructeur initial disponible")
	var first: Dictionary = OrbitalIndustry.start(c, 0, "val", "module", "habitat")
	check(bool(first.get("ok", false)), "Le chantier commande son propre habitat spatial")
	var repeated: Dictionary = OrbitalIndustry.start(c, 0, "val", "module", "habitat")
	check(not bool(repeated.get("ok", false)), "Pas de double commande pendant la production")
	for i in 205:
		OrbitalIndustry.step(c)
	check(OrbitalIndustry.capacity(c, 0, "val") == OrbitalIndustry.BASE_CAP + 6, "Habitat = capacité de population orbitale")
	var hydro: Dictionary = OrbitalIndustry.start(c, 0, "val", "module", "hydroponie")
	check(bool(hydro.get("ok", false)), "Ferme hydroponique spatialement construite")
	for i in 215:
		OrbitalIndustry.step(c)
	var before_food: float = float(c.system_resources(0, "sol")["food"])
	for i in Rules.TICK_RATE * 3:
		c.tick += 1
		OrbitalIndustry.step(c)
	check(float(c.system_resources(0, "sol")["food"]) > before_food, "Production réelle de nourriture en orbite")
	var shuttle: Dictionary = OrbitalIndustry.start(c, 0, "val", "unit", "navette")
	check(bool(shuttle.get("ok", false)), "Centre orbital produit une navette dès IX")
	for i in 245:
		OrbitalIndustry.step(c)
	check(int(OrbitalIndustry.presence(c, 0, "val").get("navette", 0)) == 1, "Navette conservée dans l'inventaire orbital, pas au sol")
	var invalid: Dictionary = OrbitalIndustry.send_fleet(c, 0, "val", "aurore", {"navette": 2})
	check(not bool(invalid.get("ok", false)) and c.orbital_flights.is_empty(), "Mission avec unités manquantes refusée sans débit")
	var mission: Dictionary = c.orbital_send(0, "val", "aurore", {"navette": 1, "drone": 1})
	check(bool(mission.get("ok", false)) and c.orbital_flights.size() == 1, "Mission interplanétaire réelle : navette + constructeur")
	var snap: Dictionary = CampaignSave.snapshot(c)
	var clone: StarCampaign = CampaignSave.from_snapshot(snap)
	check(clone != null, "Sauvegarde de campagne contenant le chantier et le vol")
	if clone != null:
		check(clone.state_hash() == c.state_hash(), "Reprise exacte de l'état orbital")
	var tampered: Dictionary = snap.duplicate(true)
	(tampered["orbital_flights"] as Array)[0]["eta"] = -500
	check(CampaignSave.from_snapshot(tampered) == null, "Mission corrompue refusée")
	for i in 170:
		OrbitalIndustry.step(c)
	check(c.orbital_flights.is_empty() and int(OrbitalIndustry.presence(c, 0, "aurore").get("drone", 0)) == 1,
		"Arrivée physique : drone transféré sans duplication")
	var funds: Dictionary = c.system_resources(0, "sol").duplicate(true)
	var second: Dictionary = c.orbital_shipyard(0, "aurore")
	check(bool(second.get("ok", false)), "Drone transféré construit un nouveau centre orbital")
	check(float(c.system_resources(0, "sol")["ore"]) < float(funds["ore"]), "Coût du deuxième chantier prélevé une seule fois")
	check(not bool(c.orbital_shipyard(0, "aurore").get("ok", false)), "Un seul chantier par camp et monde")
	check(not bool(c.orbital_train(0, "val", "fregate").get("ok", false)), "Frégate verrouillée avant l'âge X")
	c.ages[0] = 10
	check(not bool(c.orbital_train(0, "val", "fregate").get("ok", false)), "Arsenal spatial nécessaire à la frégate")
	print("ORBITAL_J12_3=%s assertions=%d failures=%d" % ["PASS" if fail == 0 else "FAIL", count, fail])
	quit(0 if fail == 0 else 1)
