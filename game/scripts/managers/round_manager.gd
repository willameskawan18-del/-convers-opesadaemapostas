class_name RoundManager
extends RefCounted
## Estrutura da partida por CATEGORIAS. Padrão (9 rodadas + ALL WIN = 10):
## CONHECIMENTO → RISCO → HABILIDADE → SOCIAL → RISCO → HABILIDADE → CONHECIMENTO → SOCIAL → GRANDE RISCO → ALL WIN
## Eventos especiais entram entre algumas rodadas.

const PATTERN := ["conhecimento", "risco", "habilidade", "social", "risco", "habilidade", "conhecimento", "social", "habilidade", "risco", "conhecimento", "social"]

var total := 9
var current := 0
var categories: Array = []
var sequence: Array = []      # ids escolhidos (preenchido conforme a partida avança)
var event_after: Array = []
var mm: MinigameManager
var recent: Array = []


func setup(rounds: int, minigames: MinigameManager, rng: RandomNumberGenerator, recent_ids: Array = []) -> void:
	mm = minigames
	recent = recent_ids
	total = clampi(rounds, 4, 13)
	current = 0
	sequence = []
	categories = []
	for i in total - 1:
		categories.append(PATTERN[i % PATTERN.size()])
	categories.append("grande_risco")
	event_after = [maxi(1, int(round(total / 3.0))), maxi(2, int(round(total * 2 / 3.0)))]
	if event_after[0] == event_after[1]:
		event_after.pop_back()


## Avança para a próxima rodada e escolhe o desafio (na hora, para considerar a rodada).
func next(rng: RandomNumberGenerator) -> String:
	current += 1
	var cat: String = categories[current - 1]
	var id := mm.pick(cat, current, sequence, recent, rng)
	sequence.append(id)
	return id


func category() -> String:
	return str(categories[current - 1]) if current >= 1 and current <= categories.size() else "especial"


func has_next() -> bool:
	return current < total


func event_now() -> bool:
	return event_after.has(current)


## Total exibido no HUD inclui a rodada ALL WIN.
func display_total() -> int:
	return total + 1
