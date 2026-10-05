class_name AwardSystem
extends RefCounted
## Prêmios do fim da partida: MAIS RICO, MAIS ARRISCADO, MAIOR MULTIPLICADOR, MAIOR AZAR,
## MAIS PRECISO, MAIS VITÓRIAS e MAIOR RECUPERAÇÃO.


static func precision(p: PlayerState) -> float:
	var parts := []
	if int(p.stats.get("answered", 0)) > 0:
		parts.append(float(p.stats.correct) / float(p.stats.answered))
	if int(p.stats.get("skill_n", 0)) > 0:
		parts.append(float(p.stats.skill_sum) / float(p.stats.skill_n))
	if parts.is_empty():
		return 0.0
	var s := 0.0
	for v in parts:
		s += float(v)
	return s / parts.size()


static func compute(pm: PlayerManager) -> Array:
	var defs := [
		["MAIS RICO", func(p): return float(p.money), func(v): return Fmt.money(v)],
		["MAIS ARRISCADO", func(p): return float(p.stats.get("risk_total", 0)), func(v): return Fmt.money(v) + " em jogo"],
		["MAIOR MULTIPLICADOR", func(p): return float(p.stats.get("best_mult", 0.0)), func(v): return Fmt.mult(v)],
		["MAIOR AZAR", func(p): return float(p.stats.get("biggest_loss", 0)), func(v): return "perdeu " + Fmt.money(v) + " de uma vez"],
		["MAIS PRECISO", func(p): return precision(p), func(v): return "%d%% de acerto" % int(v * 100.0)],
		["MAIS VITÓRIAS", func(p): return float(p.stats.get("challenges_won", 0)), func(v): return "%d rodada(s)" % int(v)],
		["MAIOR RECUPERAÇÃO", func(p): return float(p.stats.get("recovery", 0)), func(v): return "+" + Fmt.money(v) + " depois do fundo do poço"],
	]
	var out := []
	for d in defs:
		var best: PlayerState = null
		var best_v := 0.0
		for p in pm.players:
			var v: float = d[1].call(p)
			if best == null or v > best_v:
				best = p
				best_v = v
		if best and best_v > 0.0:
			out.append({"title": d[0], "pid": best.id, "name": best.name, "character": best.character, "value": d[2].call(best_v)})
	return out
