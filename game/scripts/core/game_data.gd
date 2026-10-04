class_name GameData
## Leitura de dados JSON (res://data) com cache.

static var _cache: Dictionary = {}


static func load_json(file: String) -> Dictionary:
	if _cache.has(file):
		return _cache[file]
	var path := "res://data/%s.json" % file
	var d: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			d = parsed
	else:
		push_error("Dados não encontrados: " + path)
	_cache[file] = d
	return d


static func characters() -> Array:
	return load_json("characters").get("characters", [])


static func character(id: String) -> Dictionary:
	for c in characters():
		if c.id == id:
			return c
	return characters()[0]


static func character_color(id: String) -> Color:
	return Color(str(character(id).get("color", "#ffffff")))


static func bot_names() -> Array:
	return load_json("characters").get("bot_names", ["BOT"])
