class_name PlayerManager
extends RefCounted
## Lista de jogadores (2 a 8), ranking e posse por peer de rede.

const MAX_PLAYERS := 8
const MIN_PLAYERS := 2

var players: Array[PlayerState] = []
var _next_id := 1


func clear() -> void:
	players.clear()
	_next_id = 1


func count() -> int:
	return players.size()


func is_full() -> bool:
	return players.size() >= MAX_PLAYERS


func add(player_name: String, character: String, is_bot: bool, owner_peer: int = 1) -> PlayerState:
	if is_full():
		return null
	var p := PlayerState.new()
	p.id = _next_id
	_next_id += 1
	p.name = player_name.strip_edges().substr(0, 16)
	if p.name == "":
		p.name = "JOGADOR %d" % p.id
	p.character = character
	p.is_bot = is_bot
	p.owner_peer = owner_peer
	p.reset_stats()
	players.append(p)
	return p


func remove(id: int) -> void:
	for i in players.size():
		if players[i].id == id:
			players.remove_at(i)
			return


func get_player(id: int) -> PlayerState:
	for p in players:
		if p.id == id:
			return p
	return null


func ids() -> Array[int]:
	var out: Array[int] = []
	for p in players:
		out.append(p.id)
	return out


func owned_by(peer: int) -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	for p in players:
		if p.owner_peer == peer:
			out.append(p)
	return out


func used_characters() -> Array:
	return players.map(func(p): return p.character)


## Ordenado por dinheiro (desc). Empate: quem entrou primeiro fica na frente.
func ranking() -> Array[PlayerState]:
	var out: Array[PlayerState] = players.duplicate()
	out.sort_custom(func(a: PlayerState, b: PlayerState) -> bool:
		if a.money != b.money:
			return a.money > b.money
		return a.id < b.id)
	return out


## Posição 1..n; jogadores com o mesmo dinheiro dividem a posição.
func position_of(id: int) -> int:
	var p := get_player(id)
	if p == null:
		return 0
	var pos := 1
	for o in players:
		if o.money > p.money:
			pos += 1
	return pos


func leader() -> PlayerState:
	var r := ranking()
	return r[0] if r.size() > 0 else null


func last() -> PlayerState:
	var r := ranking()
	return r[r.size() - 1] if r.size() > 0 else null


func to_array() -> Array:
	return players.map(func(p): return p.to_dict())
