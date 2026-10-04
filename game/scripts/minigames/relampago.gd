extends Challenge
## QUIZ RELÂMPAGO — 4 perguntas rápidas (8 s cada). Quem acerta primeiro ganha mais.

const COUNT := 4
var qs: Array = []
var score: Dictionary = {}


func start() -> void:
	for i in COUNT:
		qs.append(ctx.question(1 if i < 2 else 2))
	for pid in participants:
		score[pid] = 0


func stage_title() -> String:
	return "PERGUNTA %d DE %d" % [stage, COUNT]


func time_limit() -> float:
	return 8.0


func options(_pid: int) -> Array:
	var q: Dictionary = qs[stage - 1]
	var out := []
	for i in q.a.size():
		out.append({"id": str(i), "label": "%s) %s" % [["A", "B", "C", "D"][i], q.a[i]], "desc": "", "color": [Pal.PINK, Pal.CYAN, Pal.GOLD, Pal.GREEN][i]})
	return out


func private_info(_pid: int) -> Dictionary:
	return {"prompt": str(qs[stage - 1].q), "lines": ["RÁPIDO! O primeiro a acertar ganha mais."], "layout": "grid", "timed": true}


func validate(pid: int, action: Dictionary) -> bool:
	return str(action.get("choice", "")) == "-1" or super.validate(pid, action)


func bot_action(pid: int) -> Dictionary:
	var q: Dictionary = qs[stage - 1]
	var sk := ctx.bot_skill(pid, "knowledge")
	var c := int(q.c) if ctx.rng.randf() < 0.45 + sk * 0.45 else (int(q.c) + ctx.rng.randi_range(1, 3)) % 4
	return {"choice": str(c), "ms": int(ctx.rng.randf_range(1400.0, 5200.0) - sk * 800.0)}


## Tempo do bot = momento em que ele "aperta" (usado pelo MatchRunner).
func bot_delay(pid: int, action: Dictionary) -> float:
	return float(action.get("ms", 3000)) / 1000.0


func default_action(_pid: int) -> Dictionary:
	return {"choice": "-1", "ms": 99999}


func has_next_stage() -> bool:
	return stage < COUNT


func resolve() -> Array:
	var q: Dictionary = qs[stage - 1]
	var right := []
	for pid in participants:
		if str(actions[pid].get("choice", "")) == str(int(q.c)):
			right.append(pid)
	right.sort_custom(func(a, b): return int(actions[a].get("ms", 99999)) < int(actions[b].get("ms", 99999)))
	var money := []
	var stat := []
	var rows := []
	for i in right.size():
		var v := ctx.scaled(1000) if i == 0 else ctx.scaled(400)
		money.append([right[i], v, "Relâmpago"])
		score[right[i]] = int(score[right[i]]) + 1
		rows.append([("1º " if i == 0 else "") + pname(right[i]), "%.1fs  %s" % [int(actions[right[i]].get("ms", 0)) / 1000.0, Fmt.delta(v)], pcolor(right[i]), Pal.GOLD if i == 0 else Pal.GREEN])
	for pid in participants:
		stat.append([pid, "answered", 1])
		if right.has(pid):
			stat.append([pid, "correct", 1])
		else:
			var miss := str(actions[pid].get("choice", "-1")) == "-1"
			rows.append([pname(pid), "SEM RESPOSTA" if miss else "ERROU", pcolor(pid), Pal.MUTED if miss else Pal.RED])
	var steps := [Challenge.list_step("RESPOSTA: " + str(q.a[int(q.c)]), rows, 2.6, {"money": money, "stat": stat, "fx": "win" if right.size() > 0 else "lose"})]
	if stage == COUNT:
		var perfect := participants.filter(func(pid): return int(score[pid]) == COUNT)
		if not perfect.is_empty():
			var m := []
			for pid in perfect:
				m.append([pid, ctx.scaled(1500), "Relâmpago perfeito"])
			steps.append(Challenge.step("banner", 2.2, {"title": "GABARITOU!", "text": ", ".join(perfect.map(func(p): return pname(p))) + "  " + Fmt.delta(ctx.scaled(1500)), "money": m, "fx": "jackpot", "camera": "players"}))
	return steps
