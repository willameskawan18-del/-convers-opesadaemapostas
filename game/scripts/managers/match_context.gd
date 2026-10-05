class_name MatchContext
extends RefCounted
## O que um desafio pode ver/usar da partida: jogadores, dinheiro, sorteio, rodada atual,
## jackpot progressivo e modificadores (inflação, alto risco).

const JACKPOT_BASE := 3000
const JACKPOT_CAP := 25000
const JACKPOT_GROWTH := 1.6

var pm: PlayerManager
var money: MoneyManager
var rng := RandomNumberGenerator.new()
var round_index := 1
var total_rounds := 9
var decision_time := 20.0
var jackpot := JACKPOT_BASE
var jackpot_won := false
var inflation := 1.0         # evento INFLAÇÃO: prêmios da próxima rodada dobram
var high_stakes := 1.0       # rodada de GRANDE RISCO
var questions_used: Dictionary = {}


## Escala dos valores: as rodadas finais valem um pouco mais.
func factor() -> float:
	return (1.0 + 0.08 * float(round_index - 1)) * inflation * high_stakes


## Valor base escalado e arredondado para múltiplos de 50.
func scaled(base: float) -> int:
	return int(roundf(base * factor() / 50.0) * 50.0)


## Apetite de risco de um bot: personalidade + quem está atrás arrisca mais.
func risk_appetite(pid: int) -> float:
	var p := pm.get_player(pid)
	if p == null:
		return 0.5
	var base := float(GameData.character(p.character).get("risk", 0.5))
	var pos := pm.position_of(pid)
	var n := maxi(1, pm.count() - 1)
	var behind := float(pos - 1) / n   # 0 = líder, 1 = último
	var late := float(round_index) / maxf(1.0, float(total_rounds))
	return clampf(base + (behind - 0.5) * 0.35 * (0.5 + late), 0.02, 0.98)


## Habilidade de um bot (0..1) para provas de habilidade/conhecimento.
func bot_skill(pid: int, kind: String = "skill") -> float:
	var p := pm.get_player(pid)
	var c: Dictionary = GameData.character(p.character if p else "")
	var s := float(c.get("speed", 0.5))
	if kind == "knowledge":
		s = {"genio": 0.85, "rico": 0.6, "trapaceiro": 0.55, "medroso": 0.55, "maluco": 0.35, "azarado": 0.45}.get(p.character if p else "", 0.5)
	return clampf(s + rng.randf_range(-0.15, 0.15), 0.05, 0.98)


func is_king(pid: int) -> bool:
	var p := pm.get_player(pid)
	return p != null and bool(p.flags.get("king", false))


## Sorteia uma pergunta do banco (sem repetir na partida). d: 1 fácil, 2 médio, 3 difícil, 0 qualquer.
func question(d: int = 0) -> Dictionary:
	var all: Array = GameData.load_json("questions").get("questions", [])
	var pool := []
	for i in all.size():
		if (d == 0 or int(all[i].d) == d) and not questions_used.has(i):
			pool.append(i)
	if pool.is_empty():
		questions_used.clear()
		for i in all.size():
			if d == 0 or int(all[i].d) == d:
				pool.append(i)
	var idx: int = pool[rng.randi_range(0, pool.size() - 1)]
	questions_used[idx] = true
	return all[idx]
