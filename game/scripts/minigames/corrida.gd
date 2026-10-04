extends SkillChallenge
## CORRIDA — aperte para correr e PULE os obstáculos. Cada um corre na sua tela;
## depois todos assistem à corrida com os tempos reais.
## 1º +5.000 · 2º +3.000 · 3º +1.500 · último -1.000

const LENGTH := 100.0
var obstacles: Array = []


func start() -> void:
	var x := 18.0
	while x < LENGTH - 8.0:
		obstacles.append(snappedf(x, 0.5))
		x += ctx.rng.randf_range(11.0, 19.0)


func game_seconds() -> float:
	return 20.0


func public_info() -> Dictionary:
	var d := super.public_info()
	d["length"] = LENGTH
	d["obstacles"] = obstacles
	return d


func private_info(_pid: int) -> Dictionary:
	return {"prompt": "CORRA! Aperte várias vezes para acelerar e PULE os obstáculos.", "lines": ["1º %s  ·  2º %s  ·  3º %s  ·  último %s" % [Fmt.delta(ctx.scaled(5000)), Fmt.delta(ctx.scaled(3000)), Fmt.delta(ctx.scaled(1500)), Fmt.delta(-ctx.scaled(1000))]]}


func validate(_pid: int, action: Dictionary) -> bool:
	return action.has("time") and float(action.time) >= 3.0


func default_action(_pid: int) -> Dictionary:
	return {"time": 99.0, "score": 0.0, "miss": true}


func bot_action(pid: int) -> Dictionary:
	var sk := ctx.bot_skill(pid)
	var t := 15.5 - sk * 6.0 + ctx.rng.randf_range(-0.8, 1.6)
	return {"time": snappedf(t, 0.01), "score": clampf((20.0 - t) / 12.0, 0.0, 1.0)}


func bot_delay(_pid: int, action: Dictionary) -> float:
	return minf(float(action.time), game_seconds())


func resolve() -> Array:
	var r := participants.duplicate()
	r.sort_custom(func(a, b): return float(actions[a].time) < float(actions[b].time))
	var prizes := [ctx.scaled(5000), ctx.scaled(3000), ctx.scaled(1500)]
	var money := []
	var rows := []
	var times := {}
	for i in r.size():
		var pid: int = r[i]
		times[pid] = float(actions[pid].time)
		var d := 0
		if i < prizes.size() and i < r.size() - 1:
			d = prizes[i]
		elif i == r.size() - 1:
			d = -ctx.scaled(1000)
		if d != 0:
			money.append([pid, d, "Corrida %dº" % (i + 1)])
		var tt := "DNF" if float(actions[pid].time) >= 90.0 else "%.2fs" % float(actions[pid].time)
		rows.append(["%dº %s" % [i + 1, pname(pid)], "%s  %s" % [tt, Fmt.delta(d) if d != 0 else ""], pcolor(pid), Pal.GOLD if i == 0 else (Pal.RED if d < 0 else Pal.TEXT)])
	var stat := skill_stats(participants)
	stat.append([r[0], "skill_wins", 1])
	return [
		Challenge.step("race", 6.0, {"title": "A CORRIDA!", "times": times, "length": LENGTH, "obstacles": obstacles, "fx": "suspense", "camera": "screen"}),
		Challenge.list_step("CHEGADA", rows, 3.2, {"money": money, "stat": stat, "fx": "win"}),
	]
