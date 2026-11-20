class_name EarthData
extends RefCounted
## Terre réelle : relief, bathymétrie et biomes (Natural Earth 10m + modèle numérique de terrain mondial).
## Fichier data/terre_2048.bytes (gzip) : "TERR", largeur u16, hauteur u16, puis 3 plans :
## altitude int16 en mètres (négatif = fond marin), biome u8 (23 classes de la carte), humidité u8 (0..255).
## Projection équirectangulaire, couture de longitude continue. Données pures, déterministes.
const PATH := "res://data/terre_2048.bytes"
# classe de la carte (0..22) -> biome de PlanetGenerator (0 océan, 1 littoral, 2 plaines, 3 forêt, 4 désert, 5 toundra, 6 montagnes)
const BIOME_MAP := [0, 0, 0, 0, 0, 2, 1, 5, 5, 3, 2, 3, 3, 4, 4, 2, 3, 3, 2, 2, 6, 6, 6]
const WATER_MAX_CLASS: int = 4
static var _tried: bool = false
static var _ok: bool = false
static var _w: int = 0
static var _h: int = 0
static var _alt: PackedByteArray
static var _bio: PackedByteArray
static var _hum: PackedByteArray

static func available() -> bool:
	if not _tried:
		_tried = true
		_load()
	return _ok

static func _load() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var raw: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var data: PackedByteArray = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if data.size() < 8 or data.slice(0, 4).get_string_from_ascii() != "TERR":
		return
	_w = data.decode_u16(4)
	_h = data.decode_u16(6)
	var n: int = _w * _h
	if data.size() != 8 + n * 4:
		return
	_alt = data.slice(8, 8 + n * 2)
	_bio = data.slice(8 + n * 2, 8 + n * 3)
	_hum = data.slice(8 + n * 3, 8 + n * 4)
	_ok = true

static func _alt_at(x: int, y: int) -> float:
	return float(_alt.decode_s16((posmod(x, _w) + clampi(y, 0, _h - 1) * _w) * 2))

static func altitude_m(lon: float, lat: float) -> float:
	## Altitude (m), interpolation bilinéaire, négative en mer.
	var fx: float = (lon + PI) / TAU * float(_w) - 0.5
	var fy: float = (PI * 0.5 - lat) / PI * float(_h) - 0.5
	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)
	var a: float = lerpf(_alt_at(x0, y0), _alt_at(x0 + 1, y0), tx)
	var b: float = lerpf(_alt_at(x0, y0 + 1), _alt_at(x0 + 1, y0 + 1), tx)
	return lerpf(a, b, ty)

static func map_class(lon: float, lat: float) -> int:
	var x: int = posmod(int(floor((lon + PI) / TAU * float(_w))), _w)
	var y: int = clampi(int(floor((PI * 0.5 - lat) / PI * float(_h))), 0, _h - 1)
	return int(_bio[x + y * _w])

static func sample(lon: float, lat: float) -> Dictionary:
	## Même contrat que PlanetGenerator.sample : height, humidity, temperature, biome.
	var cls: int = map_class(lon, lat)
	var alt: float = altitude_m(lon, lat)
	var x: int = posmod(int(floor((lon + PI) / TAU * float(_w))), _w)
	var y: int = clampi(int(floor((PI * 0.5 - lat) / PI * float(_h))), 0, _h - 1)
	var height: float
	var biome: int = int(BIOME_MAP[clampi(cls, 0, BIOME_MAP.size() - 1)])
	if cls <= WATER_MAX_CLASS:
		# mer et lacs : toujours sous le seuil d'eau (-0.042), avec de la marge pour le bruit fin
		height = -0.07 - clampf(-alt, 0.0, 6000.0) / 6000.0 * 0.25
		biome = 0
	else:
		height = 0.012 + clampf(alt, 0.0, 9000.0) / 6000.0
		height = minf(height, 1.0)
		# glacier d'altitude hors régions polaires = haute montagne (Himalaya, Andes, Alpes) ; calottes polaires = toundra
		if cls == 7 and alt > 2500.0 and absf(lat) < deg_to_rad(66.0):
			biome = 6
	return {"height": height, "humidity": float(_hum[x + y * _w]) / 255.0,
		"temperature": clampf(1.0 - absf(lat) / (PI * 0.5), 0.0, 1.0), "biome": biome}
