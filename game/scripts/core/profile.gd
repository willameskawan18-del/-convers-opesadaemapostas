extends Node
## Estatísticas locais (user://profile.json). Preparado para virar conta online no futuro.

const PATH := "user://profile.json"

var data := {"matches": 0, "wins": 0, "best_money": 0, "best_mult": 0.0, "challenges_won": 0, "max_risk": 0, "last_name": "", "last_character": "sortudo"}


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		for k in parsed:
			data[k] = parsed[k]


func save_profile() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


## Registra a partida para os jogadores humanos desta máquina.
func record_match(summary: Dictionary, my_peer: int) -> void:
	var mine: Array = summary.get("ranking", []).filter(func(r): return int(r.owner_peer) == my_peer and not bool(r.is_bot))
	if mine.is_empty():
		return
	data.matches = int(data.matches) + 1
	for r in mine:
		var st: Dictionary = r.get("stats", {})
		if int(r.id) == int(summary.get("winner", -1)):
			data.wins = int(data.wins) + 1
		data.best_money = maxi(int(data.best_money), int(r.money))
		data.best_mult = maxf(float(data.best_mult), float(st.get("best_mult", 0.0)))
		data.challenges_won = int(data.challenges_won) + int(st.get("challenges_won", 0))
		data.max_risk = maxi(int(data.max_risk), int(st.get("max_risk", 0)))
	save_profile()


## Desafios da última partida (evita repetir na próxima).
func remember_recent(ids: Array) -> void:
	data.recent = ids.duplicate()
	save_profile()


func remember_player(player_name: String, character: String) -> void:
	data.last_name = player_name
	data.last_character = character
	save_profile()
