class_name TacticalModels
extends RefCounted
## Adaptateur visuel : les emprises, l'âge local et le gameplay restent dans SimWorld.
const BUILDINGS := {"centre": "command_center", "maison": "residential", "caserne": "barracks", "marche": "market",
	"entrepot": "warehouse", "atelier": "laboratory", "palissade": "wall", "fort": "tower", "usine": "factory",
	"academie": "university", "depot": "logistics_depot", "aerodrome": "airport", "radar": "radar", "silo": "planetary_defense",
	"intercepteur": "planetary_defense", "spatioport": "spaceport", "chantier_orbital": "shipyard", "comptoir": "port",
	# 0.16 : forge et monuments d'âge (modèles de la bibliothèque, choisis par famille et âge).
	"forge": "warehouse", "monument_grand_comptoir": "market", "monument_bibliotheque": "university", "monument_citadelle": "tower",
	"monument_temple_batisseurs": "temple", "monument_grande_forge": "factory", "monument_manufacture": "laboratory",
	"monument_palais": "command_center", "monument_grande_universite": "university", "monument_arsenal_national": "factory",
	"monument_gare_centrale": "logistics_depot", "monument_bouclier_national": "planetary_defense", "monument_etat_major": "radar",
	"monument_centre_calcul": "research_center", "monument_usine_robotisee": "factory", "monument_ascenseur_spatial": "spaceport",
	"monument_observatoire": "research_center", "monument_porte_stellaire": "spaceport", "monument_archive_galactique": "research_center",
	# 0.18 : ville de l'âge de l'électricité (familles de la bibliothèque, aucun modèle extérieur).
	"zone_r": "residential", "zone_c": "commercial", "zone_i": "industrial", "centrale": "power_plant", "centrale_solaire": "power_plant",
	"poste_electrique": "power_plant", "chateau_eau": "water_works", "station_pompage": "water_works", "commissariat": "police",
	"caserne_pompiers": "fire_station", "hopital": "hospital", "decharge": "warehouse", "recyclage": "factory",
	# 0.19 : puits et citerne (famille « eau » de la bibliothèque, dès l'âge I). Exploitation agricole et ruines :
	# portraits de la fiche seulement (au sol, UrbanVisual compose champs et décombres).
	"puits": "water_works", "zone_a": "warehouse", "ruine": "wall"}
const UNITS := {"ouvrier": ["unit_civilian", "builder"], "colon": ["unit_civilian", "colonist"],
	"lancier": ["unit_military", "spearman"], "tireur": ["unit_military", "archer"],
	"cavalier": ["unit_military", "cavalry"], "eclaireur": ["unit_military", "mounted_scout"],
	"canon": ["unit_military", "gun"], "fusilier": ["unit_military", "fusilier"], "grenadier": ["unit_military", "grenadier"],
	"obusier": ["vehicle_ground", "sp_artillery"], "char": ["vehicle_ground", "tank_light"], "antiaerien": ["vehicle_ground", "aa_tracked"],
	"brouilleur": ["vehicle_ground", "jammer"], "lance_missiles": ["vehicle_ground", "missile_carrier"],
	"train": ["vehicle_ground", "locomotive"], "caravane": ["vehicle_ground", "caravan"],
	"avion": ["vehicle_air", "fighter"], "drone": ["vehicle_air", "drone_strike"],
	"navette": ["spaceship", "shuttle"], "fregate": ["spaceship", "frigate"],
	# 0.16 : unités de voie et héros.
	"archer_monte": ["unit_military", "horse_archer"], "chevalier": ["unit_military", "knight"], "arbaletrier": ["unit_military", "crossbowman"],
	"mitrailleur": ["unit_military", "machine_gunner"], "garde_imperiale": ["unit_military", "guard"], "tireur_elite": ["unit_military", "sniper"],
	"robot_combat": ["unit_military", "combat_robot"], "exosquelette": ["unit_military", "exosuit"], "marine_spatial": ["unit_military", "space_marine"],
	"heros_antique": ["unit_military", "officer"], "heros_industriel": ["unit_military", "officer"], "heros_spatial": ["unit_military", "officer"]}

static func building_id(kind: String, age: int) -> String:
	if not BUILDINGS.has(kind):
		return ""
	var family: String = String(BUILDINGS[kind])
	var category: String = "building_special"
	if family in ["residential", "commercial", "industrial"]:
		category = "building_" + family
	return AssetLibrary.find(category, family, age)

static func unit_id(kind: String, age: int) -> String:
	if not UNITS.has(kind):
		return ""
	var spec: Array = UNITS[kind] as Array
	if kind == "tireur" and age >= 4:
		return AssetLibrary.find("unit_military", "fusilier", age)
	return AssetLibrary.find(String(spec[0]), String(spec[1]), age)

static func building(kind: String, team: int, size: int, age: int, lod: int = 0) -> Node3D:
	var id: String = building_id(kind, age)
	if id.is_empty() or int(AssetLibrary.info(id).get("age", 99)) > age:
		return null
	var model: Node3D = RealismAssets.building("marche" if kind == "comptoir" else kind, age, team, float(size))
	if model == null:
		model = AssetLibrary.instantiate_compact(id, lod)
		if model != null:
			RealismAssets.enhance_legacy(model)
	if model == null:
		return null
	var visual := Node3D.new()
	var s: float = AssetLibrary.scale_for_cells(id, float(size) * 0.91)
	if not model.has_meta("realism_asset"):
		model.scale = Vector3.ONE * s
	model.name = "LibraryModel"
	AssetLibrary.set_team_color(model, Assets.TEAM_COLORS[clampi(team, 0, 2)])
	visual.add_child(model)
	visual.set_meta("library_asset", id)
	# Les dommages restent lisibles sans reconstruire les façades historiques sur le nouveau modèle.
	var architecture := Node3D.new()
	architecture.name = "Architecture"
	visual.add_child(architecture)
	var damage := Node3D.new()
	damage.name = "Damage"
	damage.visible = false
	visual.add_child(damage)
	var cracks := Node3D.new()
	cracks.name = "Cracks"
	damage.add_child(cracks)
	for i in 3:
		Assets.box(cracks, Vector3(float(size) * 0.18, 0.06, float(size) * 0.18), Assets.mat("scorch_pbr", Color("282522")),
			Vector3(float(i - 1) * float(size) * 0.23, 0.08, float(size) * 0.32))
	return visual

static func unit(kind: String, team: int, age: int, lod: int = 1) -> Node3D:
	var id: String = unit_id(kind, age)
	if id.is_empty():
		return null
	var record: Dictionary = AssetLibrary.info(id)
	if int(record.get("age", 99)) > age:
		return null
	var human_kind: String = "fusilier" if kind == "tireur" and age >= 4 else kind
	var figure: Node3D = RealismAssets.instantiate("human_" + human_kind, team) if lod == 0 else null
	if figure == null:
		figure = AssetLibrary.instantiate(id, 0) if lod == 0 else AssetLibrary.instantiate_compact(id, 2)
		if figure != null:
			RealismAssets.enhance_legacy(figure)
	if figure == null:
		return null
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	figure.name = "LibraryModel"
	var size_m: Array = record["size_m"] as Array
	var humanoid: bool = String(record["category"]).begins_with("unit_") and not kind in ["cavalier", "eclaireur", "canon"]
	var factor: float = 1.18 / maxf(0.1, float(size_m[1])) if humanoid else AssetLibrary.scale_for_cells(id, 2.3 if kind in ["fregate", "train"] else 1.65)
	figure.scale = Vector3.ONE * (1.18 / 1.8 if figure.has_meta("realism_asset") else factor)
	AssetLibrary.set_team_color(figure, Assets.TEAM_COLORS[clampi(team, 0, 2)])
	body.add_child(figure)
	root.set_meta("library_asset", id)
	root.set_meta("library_lod", lod)
	root.set_meta("library_age", age)
	root.set_meta("players", figure.find_children("*", "AnimationPlayer", true, false))
	root.scale = Vector3.ONE * Assets.UNIT_SCALE
	return root

static func animate(root: Node3D, moving: bool, attacking: bool, working: bool, velocity: float, animation_enabled: bool = true) -> void:
	var action: String = "attack" if attacking else ("work" if working else ("walk" if moving else "idle"))
	for raw in root.get_meta("players", []) as Array:
		var player: AnimationPlayer = raw as AnimationPlayer
		if player == null:
			continue
		player.active = animation_enabled
		if String(root.get_meta("animation", "")) != action and player.has_animation(action):
			player.play(action, 0.12)
		player.speed_scale = clampf(velocity / 2.4, 0.4, 16.0) if action == "walk" else 1.0
	root.set_meta("animation", action)
