extends SceneTree
## 0.18.1 — Tous les caractères des textes d'interface existent-ils dans les polices livrées ?
## Sur Android, Godot ne trouve pas toujours de police système de secours : un caractère absent s'affiche
## comme un carré avec son code (ex. « FF0B » pour le plus pleine chasse). On n'utilise donc que des
## caractères présents dans les polices de l'interface (ou dans Fira Sans SemiBold, leur police de repli).

const FONTS: Array[String] = ["FiraSans-Regular", "FiraSans-SemiBold", "FiraSans-Light", "Cardo-Bold", "AnonymousPro-Bold"]
const DIRS: Array[String] = ["res://game", "res://interface", "res://views", "res://orbit", "res://evolution", "res://sim"]

func _files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_files(dir.path_join(sub), out)

func _theme_without_font() -> bool:
	for k in AgeTheme.TOKENS:
		for role in ["title_font", "button_font", "body_font"]:
			if String((k as Dictionary)[role]) == "":
				return true
	return false

func _initialize() -> void:
	var fonts: Dictionary = {}
	for name in FONTS:
		var f: FontFile = load("res://interface/fonts/%s.ttf" % name) as FontFile
		f.allow_system_fallback = false
		fonts[name] = f
	var files: Array[String] = []
	for dir in DIRS:
		_files(dir, files)
	var literal := RegEx.new()
	literal.compile("\"(?:[^\"\\\\]|\\\\.)*\"")
	var where: Dictionary = {}   # caractère → premier fichier:ligne
	var menu_chars: Dictionary = {}  # caractères du menu principal (thème neutre : police par défaut du moteur)
	for path in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			var code: String = line.strip_edges()
			if code.begins_with("#"):
				continue
			for m in literal.search_all(line):
				var s: String = m.get_string()
				for j in s.length():
					var c: int = s.unicode_at(j)
					if c > 127 and not where.has(c):
						where[c] = "%s:%d" % [path.trim_prefix("res://"), i + 1]
					if c > 127 and path.ends_with("main_menu.gd"):
						menu_chars[c] = true
	var missing: int = 0
	var codes: Array = where.keys()
	codes.sort()
	for c in codes:
		var lacking: PackedStringArray = PackedStringArray()
		for name in FONTS:
			# Comme AgeTheme.font() : toute police autre que Fira Regular / SemiBold se replie sur Fira SemiBold.
			var own: bool = (fonts[name] as FontFile).has_char(int(c))
			var via_fallback: bool = name not in ["FiraSans-Regular", "FiraSans-SemiBold"] and (fonts["FiraSans-SemiBold"] as FontFile).has_char(int(c))
			if not own and not via_fallback:
				lacking.append(name)
		# Menu principal : vérifié aussi contre la police par défaut du moteur si un thème n'en impose pas.
		if menu_chars.has(c) and _theme_without_font() and not ThemeDB.fallback_font.has_char(int(c)):
			lacking.append("police par défaut du moteur")
		if not lacking.is_empty():
			missing += 1
			print("GLYPH_MISSING U+%04X « %s » %s — absent de : %s" % [int(c), String.chr(int(c)), where[c], ", ".join(lacking)])
	for k in AgeTheme.TOKENS:
		for role in ["title_font", "button_font", "body_font"]:
			var fname: String = String((k as Dictionary)[role])
			if fname != "" and not FONTS.has(fname):
				missing += 1
				print("GLYPH_FONT_UNKNOWN %s %s" % [String((k as Dictionary)["name"]), fname])
	print("GLYPHS_RESULT=%s characters=%d missing=%d" % ["PASS" if missing == 0 else "FAIL", codes.size(), missing])
	quit(1 if missing > 0 else 0)
