class_name RoundManager
extends RefCounted
## Controla o número da rodada, a sequência de desafios e quando entram os eventos especiais.

var total := 8
var current := 0
var sequence: Array = []
var event_after: Array = []


func setup(rounds: int, mm: MinigameManager, rng: RandomNumberGenerator) -> void:
	total = clampi(rounds, 3, 20)
	current = 0
	sequence = mm.build_sequence(total, rng)
	# Eventos: depois de ~1/3 e ~2/3 da partida
	event_after = [maxi(1, int(round(total / 3.0))), maxi(2, int(round(total * 2 / 3.0)))]
	if event_after[0] == event_after[1]:
		event_after.pop_back()


func next() -> String:
	current += 1
	return str(sequence[current - 1]) if current <= sequence.size() else ""


func has_next() -> bool:
	return current < total


func event_now() -> bool:
	return event_after.has(current)


## Texto do HUD: "RODADA 3/8" (a rodada ALL WIN aparece como FINAL)
func label() -> String:
	return "RODADA %d/%d" % [current, total]
