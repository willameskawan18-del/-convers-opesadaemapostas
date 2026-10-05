extends Node
## Perfil local (user://profile.json): carreira, títulos, catálogo de itens achados e
## conquistas (IDs prontos para ligar ao Steamworks).

signal achievement_unlocked(id: String, title: String, desc: String)

const PATH := "user://profile.json"
const ACHIEVEMENTS := {
	"primeiro_galpao": ["PRIMEIRO GALPÃO", "Arremate o seu primeiro galpão."],
	"lucro5k": ["ACHADO DE OURO", "Lucre $5.000 num único galpão."],
	"prejuizo": ["FURADA", "Pague $3.000 a mais do que o galpão valia."],
	"raro": ["OLHO DE ESPECIALISTA", "Encontre um item raro."],
	"vazio": ["COFRE VAZIO", "Abra um item misterioso... e não tenha nada dentro."],
	"pechincha": ["NEGOCIANTE", "Feche uma pechincha com o comprador."],
	"colecao": ["COLECIONADOR", "Complete uma coleção (3 do mesmo tipo)."],
	"vitoria": ["REI DO LEILÃO", "Vença uma partida."],
	"vitoria5": ["MAGNATA DA SUCATA", "Vença 5 partidas."],
	"catalogo25": ["CATALOGADOR", "Encontre 25 itens diferentes."],
	"catalogo_full": ["ENCICLOPÉDIA DO GALPÃO", "Encontre todos os itens."],
	"fortuna": ["MILIONÁRIO DE GARAGEM", "Termine uma partida com $40.000."],
}
const TITLES := [[0, "Curioso de Garagem"], [1, "Caçador de Pechinchas"], [3, "Leiloeiro Amador"], [6, "Negociante Experiente"], [10, "Barão da Sucata"], [20, "Lenda dos Leilões"]]

var data := {"matches": 0, "wins": 0, "best_money": 0, "last_name": "", "last_character": "rico", "catalog": {}, "achievements": {}, "units": 0, "profit": 0}


func title() -> String:
	var t := str(TITLES[0][1])
	for e in TITLES:
		if int(data.wins) >= int(e[0]):
			t = str(e[1])
	return t


func unlock(id: String) -> bool:
	if not ACHIEVEMENTS.has(id) or data.achievements.has(id):
		return false
	data.achievements[id] = Time.get_datetime_string_from_system()
	save_profile()
	achievement_unlocked.emit(id, ACHIEVEMENTS[id][0], ACHIEVEMENTS[id][1])
	return true


func catalog_total() -> int:
	return GameData.load_json("items").items.size()


## Registra um item encontrado num galpão meu.
func register_item(it: Dictionary) -> void:
	var cat: Dictionary = data.catalog
	var k := str(it.name)
	cat[k] = int(cat.get(k, 0)) + 1
	save_profile()
	if bool(it.get("rare", false)):
		unlock("raro")
	if cat.size() >= 25:
		unlock("catalogo25")
	if cat.size() >= catalog_total():
		unlock("catalogo_full")


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


func record_match(summary: Dictionary, my_peer: int) -> void:
	var mine: Array = summary.get("ranking", []).filter(func(r): return int(r.owner_peer) == my_peer and not bool(r.is_bot))
	if mine.is_empty():
		return
	data.matches = int(data.matches) + 1
	for r in mine:
		if int(r.id) == int(summary.get("winner", -1)):
			data.wins = int(data.wins) + 1
		data.best_money = maxi(int(data.best_money), int(r.money))
		if int(r.money) >= 40000:
			unlock("fortuna")
	save_profile()
	if int(data.wins) >= 1:
		unlock("vitoria")
	if int(data.wins) >= 5:
		unlock("vitoria5")


func remember_player(n: String, c: String) -> void:
	data.last_name = n
	data.last_character = c
	save_profile()


## compatibilidade com dialogs.gd
func remember_recent(_ids: Array) -> void:
	pass
