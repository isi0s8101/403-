class_name Portraits
extends RefCounted
## Photos des modèles en jeu, chargées à la demande ; cache borné à 64 textures.
static var _index:Dictionary={}
static var _models:Dictionary={}
static var _cache:Dictionary={}
static var _loaded:bool=false
static func _indices()->void:
	if _loaded:return
	_loaded=true
	for pair in [["portraits.json",_index],["portraits-models.json",_models]]:
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://interface/"+String(pair[0])))
		if parsed is Dictionary:(pair[1] as Dictionary).merge(parsed)
static func _photo(file_name:String)->Texture2D:
	if file_name.is_empty():return null
	if _cache.has(file_name):return _cache[file_name] as Texture2D
	var picture:=Image.new()
	if picture.load_png_from_buffer(FileAccess.get_file_as_bytes("res://interface/photos/"+file_name))!=OK:return null
	picture.generate_mipmaps()
	var texture:Texture2D=ImageTexture.create_from_image(picture)
	if _cache.size()>=64:_cache.erase(_cache.keys()[0])
	_cache[file_name]=texture;return texture
static func asset(id:String)->Texture2D:
	_indices();return _photo(String(_index.get(id,"")))
static func building(kind:String,age:int)->Texture2D:
	_indices()
	var key:String="building:%s:%d"%[kind,clampi(age,1,10)]
	if _models.has(key):return _photo(_models[key])
	return asset(TacticalModels.building_id(kind,age))
static func unit(kind:String,age:int)->Texture2D:
	_indices()
	var key:String="unit:%s:%d"%[kind,clampi(age,1,10)]
	if _models.has(key):return _photo(_models[key])
	return asset(TacticalModels.unit_id(kind,age))
static func orbital(kind:String,structure:bool=false)->Texture2D:
	var family:String={"drone":"builder_drone","sonde":"probe","navette":"shuttle","intercepteur":"interceptor","fregate":"frigate","command":"station","habitat":"habitat","hydroponie":"hydroponics","extracteur":"extractor","depot":"depot","hangar":"hangar","radar":"radar","batterie":"battery","arsenal":"arsenal","shipyard":"shipyard"}.get(kind,kind)
	return asset(AssetLibrary.find("orbital_structure" if structure else "spaceship",family,10))
