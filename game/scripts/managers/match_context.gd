class_name MatchContext
extends RefCounted
## O que um desafio pode ver/usar da partida: jogadores, dinheiro, sorteio e rodada atual.

var pm: PlayerManager
var money: MoneyManager
var rng := RandomNumberGenerator.new()
var round_index := 1
var total_rounds := 8
var decision_time := 20.0


## Escala dos valores: as rodadas finais valem mais.
func factor() -> float:
	return 1.0 + 0.2 * float(round_index - 1)


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
