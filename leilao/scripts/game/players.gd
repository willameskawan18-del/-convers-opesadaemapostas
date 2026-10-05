class_name Players
extends RefCounted
## Lista de compradores (1 a 6) e ranking.

const MAX := 6
var list: Array[PlayerState] = []
var _next := 1


func clear() -> void:
	list.clear()
	_next = 1


func add(player_name: String, character: String, is_bot: bool, owner: int) -> PlayerState:
	if list.size() >= MAX:
		return null
	var p := PlayerState.new()
	p.id = _next
	_next += 1
	p.name = player_name.strip_edges().substr(0, 14)
	if p.name == "":
		p.name = "COMPRADOR %d" % p.id
	p.character = character
	p.is_bot = is_bot
	p.owner_peer = owner
	p.reset()
	list.append(p)
	return p


func remove(id: int) -> void:
	for i in list.size():
		if list[i].id == id:
			list.remove_at(i)
			return


func get_p(id: int) -> PlayerState:
	for p in list:
		if p.id == id:
			return p
	return null


func owned_by(peer: int) -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	for p in list:
		if p.owner_peer == peer:
			out.append(p)
	return out


func used_characters() -> Array:
	return list.map(func(p): return p.character)


func to_array() -> Array:
	return list.map(func(p): return p.to_dict())
