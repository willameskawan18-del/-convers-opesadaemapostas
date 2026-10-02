class_name GameData
## Carrega e guarda em cache os arquivos de dados em res://data/*.json.
## Todos os valores de balanceamento ficam nesses arquivos, não nos scripts.

static var _cache: Dictionary = {}


static func load_json(file_name: String) -> Variant:
	if _cache.has(file_name):
		return _cache[file_name]
	var path := "res://data/%s.json" % file_name
	var data: Variant = {}
	if not FileAccess.file_exists(path):
		push_error("GameData: arquivo não encontrado: " + path)
	else:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			push_error("GameData: JSON inválido em " + path)
		else:
			data = parsed
	_cache[file_name] = data
	return data


static func balance(key: String, default: Variant = 0) -> Variant:
	var b: Dictionary = load_json("balance")
	return b.get(key, default)


static func xp_value(key: String) -> int:
	var xp: Dictionary = balance("xp", {})
	return int(xp.get(key, 0))


## Busca um item por "id" dentro de uma lista do arquivo (ex: list("equipment", "items")).
static func list(file_name: String, key: String) -> Array:
	var d: Variant = load_json(file_name)
	if d is Dictionary:
		return d.get(key, [])
	return []


static var _index: Dictionary = {}


## Busca por id com índice em memória (O(1)).
static func find(file_name: String, key: String, id: String) -> Dictionary:
	var ik := file_name + "/" + key
	if not _index.has(ik):
		var idx := {}
		for item in list(file_name, key):
			idx[str(item.get("id", ""))] = item
		_index[ik] = idx
	return _index[ik].get(id, {})
