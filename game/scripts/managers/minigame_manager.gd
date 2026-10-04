class_name MinigameManager
extends RefCounted
## Registro dos desafios (ChallengeDef em res://data/challenges) e sorteio por CATEGORIA.

const CHALLENGES := [
	# Conhecimento
	"res://data/challenges/quiz.tres",
	"res://data/challenges/relampago.tres",
	"res://data/challenges/matematica.tres",
	"res://data/challenges/detetive.tres",
	"res://data/challenges/mentiroso.tres",
	# Habilidade
	"res://data/challenges/reacao.tres",
	"res://data/challenges/precisao.tres",
	"res://data/challenges/tiro.tres",
	"res://data/challenges/memoria.tres",
	"res://data/challenges/corrida.tres",
	# Risco
	"res://data/challenges/portas.tres",
	"res://data/challenges/bomba.tres",
	"res://data/challenges/escada.tres",
	"res://data/challenges/cartas.tres",
	"res://data/challenges/leilao.tres",
	"res://data/challenges/risco.tres",
	"res://data/challenges/bluff.tres",
	# Social
	"res://data/challenges/votacao.tres",
	"res://data/challenges/alianca.tres",
	"res://data/challenges/hotseat.tres",
	"res://data/challenges/roubo.tres",
	"res://data/challenges/rei.tres",
	# Especiais
	"res://data/challenges/evento.tres",
	"res://data/challenges/allwin.tres",
]

const CATEGORY_NAMES := {"conhecimento": "CONHECIMENTO", "habilidade": "HABILIDADE", "risco": "RISCO", "social": "SOCIAL", "grande_risco": "GRANDE RISCO", "especial": "ESPECIAL"}
const CATEGORY_COLORS := {"conhecimento": "4dabf7", "habilidade": "3ddc97", "risco": "ff4d6d", "social": "b072ff", "grande_risco": "ffcc33", "especial": "ffcc33"}
## Desafios bons para a rodada de GRANDE RISCO (valores dobrados)
const BIG_RISK := ["portas", "bomba", "escada", "cartas"]

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


func rotation_ids(category: String = "") -> Array:
	var out := []
	for id in defs:
		if defs[id].in_rotation and (category == "" or defs[id].category == category):
			out.append(id)
	return out


## Escolhe um desafio da categoria: sem repetir na partida, evitando os da partida anterior.
func pick(category: String, round_index: int, used: Array, recent: Array, rng: RandomNumberGenerator) -> String:
	var pool := BIG_RISK.duplicate() if category == "grande_risco" else rotation_ids(category)
	pool = pool.filter(func(id): return defs.has(id) and int(defs[id].min_round) <= round_index)
	var fresh := pool.filter(func(id): return not used.has(id) and not recent.has(id))
	if fresh.is_empty():
		fresh = pool.filter(func(id): return not used.has(id))
	if fresh.is_empty():
		fresh = pool
	return str(fresh[rng.randi_range(0, fresh.size() - 1)])


## Sequência antiga (sem categorias) — mantida para compatibilidade/testes.
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
