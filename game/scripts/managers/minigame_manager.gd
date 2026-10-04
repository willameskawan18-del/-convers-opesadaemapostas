class_name MinigameManager
extends RefCounted
## Registro dos desafios (ChallengeDef em res://data/challenges) e sorteio da sequência.

const CHALLENGES := [
	"res://data/challenges/portas.tres",
	"res://data/challenges/risco.tres",
	"res://data/challenges/reacao.tres",
	"res://data/challenges/leilao.tres",
	"res://data/challenges/bluff.tres",
	"res://data/challenges/evento.tres",
	"res://data/challenges/allwin.tres",
]

var defs: Dictionary = {}   # id -> ChallengeDef


func _init() -> void:
	for path in CHALLENGES:
		var d: ChallengeDef = load(path)
		if d == null:
			push_error("Desafio inválido: " + path)
			continue
		defs[d.id] = d


func get_def(id: String) -> ChallengeDef:
	return defs.get(id)


func rotation_ids() -> Array:
	var out := []
	for id in defs:
		if defs[id].in_rotation:
			out.append(id)
	return out


## Sequência de `count` desafios: todos aparecem antes de repetir e nunca dois iguais seguidos.
func build_sequence(count: int, rng: RandomNumberGenerator) -> Array:
	var pool := rotation_ids()
	var out := []
	while out.size() < count:
		var bag := pool.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = bag[i]
			bag[i] = bag[j]
			bag[j] = t
		if out.size() > 0 and bag.size() > 1 and bag[0] == out[out.size() - 1]:
			bag.push_back(bag.pop_front())
		out.append_array(bag)
	return out.slice(0, count)


func create(id: String, ctx: MatchContext) -> Challenge:
	var d := get_def(id)
	if d == null or d.logic == null:
		push_error("Desafio sem lógica: " + id)
		return null
	var c: Challenge = d.logic.new()
	c.setup(ctx, d)
	return c
