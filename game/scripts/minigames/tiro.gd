extends SkillChallenge
## TIRO AO ALVO — 15 s de alvos: NORMAL +1 · DOURADO +3 · MULTIPLICADOR x2 · NEGATIVO -3.
## Às vezes aparece o raríssimo ALVO JACKPOT (leva o jackpot acumulado!).

func game_seconds() -> float:
	return 15.0


func public_info() -> Dictionary:
	var d := super.public_info()
	d["jackpot_target"] = ctx.rng.randf() < 0.45
	d["jackpot"] = ctx.jackpot
	return d


func private_info(_pid: int) -> Dictionary:
	return {"prompt": "Clique nos alvos! Evite os VERMELHOS.", "lines": ["Cada ponto vale %s  ·  1º lugar +%s" % [Fmt.money(ctx.scaled(120)), Fmt.money(ctx.scaled(1500))]]}


func bot_action(pid: int) -> Dictionary:
	var sk := ctx.bot_skill(pid)
	var pts := int(roundf(ctx.rng.randf_range(6.0, 16.0) + sk * 18.0))
	if ctx.rng.randf() < 0.25:
		pts -= ctx.rng.randi_range(3, 9)
	return {"score": clampf(pts / 40.0, 0.0, 1.0), "points": pts, "jackpot": ctx.rng.randf() < 0.04}


func default_action(_pid: int) -> Dictionary:
	return {"score": 0.0, "points": 0, "miss": true}


func validate(_pid: int, action: Dictionary) -> bool:
	return action.has("points") and int(action.points) <= 300


func resolve() -> Array:
	var r := participants.duplicate()
	r.sort_custom(func(a, b): return int(actions[a].get("points", 0)) > int(actions[b].get("points", 0)))
	var rows := []
	var money := []
	for i in r.size():
		var pid: int = r[i]
		var pts := int(actions[pid].get("points", 0))
		var d := pts * ctx.scaled(120) + (ctx.scaled(1500) if i == 0 and pts > 0 else 0)
		money.append([pid, d, "Tiro ao alvo"])
		rows.append(["%dº %s" % [i + 1, pname(pid)], "%d pts  %s" % [pts, Fmt.delta(d)], pcolor(pid), Pal.GOLD if i == 0 else (Pal.GREEN if d > 0 else Pal.RED)])
	var stat := skill_stats(participants)
	stat.append([r[0], "skill_wins", 1])
	var steps := [Challenge.list_step("PLACAR DO TIRO", rows, 3.4, {"money": money, "stat": stat, "fx": "win"})]
	var jp := participants.filter(func(pid): return bool(actions[pid].get("jackpot", false)))
	if not jp.is_empty():
		steps.append(Challenge.step("banner", 3.2, {"title": "ACERTOU O ALVO JACKPOT!", "text": ", ".join(jp.map(func(p): return pname(p))) + " leva " + Fmt.money(ctx.jackpot),
			"money": jackpot_entries(jp), "fx": "jackpot", "camera": "players"}))
	return steps
