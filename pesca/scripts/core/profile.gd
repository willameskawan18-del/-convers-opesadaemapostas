extends Node
## Estatísticas locais (user://profile.json).

const PATH := "user://profile.json"
var data := {"matches": 0, "wins": 0, "best_money": 0, "last_name": "", "last_character": "rico"}


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
	save_profile()


func remember_player(n: String, c: String) -> void:
	data.last_name = n
	data.last_character = c
	save_profile()


## compatibilidade com dialogs.gd
func remember_recent(_ids: Array) -> void:
	pass
