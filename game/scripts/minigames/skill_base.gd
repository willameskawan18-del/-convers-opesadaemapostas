class_name SkillChallenge
extends Challenge
## Base das provas de HABILIDADE jogadas na tela de cada um (precisão, tiro, memória, corrida).
## O jogador joga localmente e envia {score: 0..1, ...}. Bots recebem uma nota pela habilidade.

## Duração do minijogo em segundos (o tempo de decisão inclui uma folga).
func game_seconds() -> float:
	return 12.0


func time_limit() -> float:
	return game_seconds() + 8.0


func seed_value() -> int:
	return int(ctx.round_index * 7919 + participants.size() * 31)


func public_info() -> Dictionary:
	return {"seed": seed_value(), "seconds": game_seconds()}


func validate(_pid: int, action: Dictionary) -> bool:
	return action.has("score")


func default_action(_pid: int) -> Dictionary:
	return {"score": 0.0, "miss": true}


func bot_delay(_pid: int, _action: Dictionary) -> float:
	return game_seconds() * ctx.rng.randf_range(0.6, 1.0)


## Ranking pelo score (maior primeiro).
func ranked() -> Array:
	var r := participants.duplicate()
	r.sort_custom(func(a, b): return float(actions[a].get("score", 0.0)) > float(actions[b].get("score", 0.0)))
	return r


func skill_stats(pids: Array) -> Array:
	var out := []
	for pid in pids:
		out.append([pid, "skill_sum", clampf(float(actions[pid].get("score", 0.0)), 0.0, 1.0)])
		out.append([pid, "skill_n", 1])
	return out
