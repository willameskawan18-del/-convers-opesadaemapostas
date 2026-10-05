extends Node
## Perfil local (user://profile.json): bestiário, conquistas, tutorial, recordes e a
## expedição salva. As conquistas já têm IDs prontos para ligar ao Steamworks depois.

signal achievement_unlocked(id: String, title: String, desc: String)
signal species_discovered(id: String)

const PATH := "user://profile.json"
const ACHIEVEMENTS := {
	"primeiro": ["PRIMEIRO PEIXE", "Pesque o seu primeiro peixe."],
	"cinquenta": ["PESCADOR DE VERDADE", "Pesque 50 peixes no total."],
	"raro": ["OLHO CLÍNICO", "Pesque um peixe RARO."],
	"epico": ["HISTÓRIA PRA CONTAR", "Pesque um peixe ÉPICO."],
	"lendario": ["LENDA DOS MARES", "Pesque um peixe LENDÁRIO."],
	"abismo": ["ALÉM DAS BOIAS ROXAS", "Chegue ao Abismo."],
	"tentaculo": ["REMO NELE!", "Espante um tentáculo gigante."],
	"olhos": ["PRENDA A RESPIRAÇÃO", "Sobreviva aos olhos na névoa."],
	"naufragio": ["CAPITÃO AFUNDADO", "Naufrague. Acontece."],
	"tempestade": ["NADA ME PARA", "Pesque durante uma tempestade."],
	"cota3": ["VETERANO", "Bata 3 cotas na mesma expedição."],
	"rico": ["MAGNATA DO PESCADO", "Venda $10.000 numa expedição."],
	"bestiario50": ["BIÓLOGO MARINHO", "Descubra metade das espécies."],
	"bestiario100": ["BESTIÁRIO COMPLETO", "Descubra todas as espécies."],
}

var data := {"best_money": 0, "last_name": "", "last_character": "sortudo", "bestiary": {}, "achievements": {}, "tutorial_done": false, "total_caught": 0, "best_nights": 0}


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if p is Dictionary:
			for k in p:
				data[k] = p[k]


func save_profile() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func remember_player(n: String, c: String) -> void:
	data.last_name = n
	data.last_character = c
	save_profile()


func remember_recent(_ids: Array) -> void:
	pass


func record_match(_s: Dictionary, _p: int) -> void:
	pass


## Registra uma captura. Retorna true se for uma espécie nova.
func register_catch(f: Dictionary) -> bool:
	var b: Dictionary = data.bestiary
	var id := str(f.id)
	var is_new := not b.has(id)
	var e: Dictionary = b.get(id, {"count": 0, "best_kg": 0.0})
	e.count = int(e.count) + 1
	e.best_kg = maxf(float(e.best_kg), float(f.kg))
	b[id] = e
	data.total_caught = int(data.total_caught) + 1
	save_profile()
	if is_new:
		species_discovered.emit(id)
	unlock("primeiro")
	if int(data.total_caught) >= 50:
		unlock("cinquenta")
	match str(f.rarity):
		"raro": unlock("raro")
		"epico": unlock("epico")
		"lendario": unlock("lendario")
	var total: int = GameData.load_json("fish").fish.size()
	if b.size() * 2 >= total:
		unlock("bestiario50")
	if b.size() >= total:
		unlock("bestiario100")
	return is_new


func unlock(id: String) -> bool:
	if not ACHIEVEMENTS.has(id) or data.achievements.has(id):
		return false
	data.achievements[id] = Time.get_datetime_string_from_system()
	save_profile()
	achievement_unlocked.emit(id, ACHIEVEMENTS[id][0], ACHIEVEMENTS[id][1])
	return true


func bestiary_progress() -> Vector2i:
	return Vector2i(data.bestiary.size(), GameData.load_json("fish").fish.size())


# --- Expedição salva ---------------------------------------------------------------------

const SAVE_PATH := "user://expedition.json"


func has_expedition() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_expedition(d: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_expedition() -> Dictionary:
	if not has_expedition():
		return {}
	var p: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return p if p is Dictionary else {}


func clear_expedition() -> void:
	if has_expedition():
		DirAccess.remove_absolute(SAVE_PATH)
