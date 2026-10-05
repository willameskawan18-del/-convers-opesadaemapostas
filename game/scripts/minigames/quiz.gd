extends Challenge
## QUIZ — primeiro cada um escolhe a DIFICULDADE (decisão de risco), depois responde.
## FÁCIL +500 (erro: nada) · MÉDIO +1.500 (erro: -500) · DIFÍCIL +3.000 (erro: -1.500)

const LEVELS := {"facil": [1, 500, 0, "FÁCIL"], "medio": [2, 1500, 500, "MÉDIO"], "dificil": [3, 3000, 1500, "DIFÍCIL"]}
var difficulty: Dictionary = {}   # pid -> "facil" | "medio" | "dificil"
var questions: Dictionary = {}    # nível -> pergunta
var answers: Dictionary = {}


func start() -> void:
	for k in LEVELS:
		questions[k] = ctx.question(int(LEVELS[k][0]))


func stage_title() -> String:
	return "ESCOLHA A DIFICULDADE" if stage == 1 else "RESPONDA!"


func time_limit() -> float:
	return 12.0 if stage == 1 else ctx.decision_time


func options(pid: int) -> Array:
	if stage == 1:
		return [
			{"id": "dificil", "label": "DIFÍCIL", "desc": "%s  |  erro %s" % [Fmt.delta(ctx.scaled(3000)), Fmt.delta(-ctx.scaled(1500))], "color": Pal.RED},
			{"id": "medio", "label": "MÉDIO", "desc": "%s  |  erro %s" % [Fmt.delta(ctx.scaled(1500)), Fmt.delta(-ctx.scaled(500))], "color": Pal.ORANGE},
			{"id": "facil", "label": "FÁCIL", "desc": "%s  |  erro: nada" % Fmt.delta(ctx.scaled(500)), "color": Pal.GREEN},
		]
	var q: Dictionary = questions[difficulty.get(pid, "facil")]
	var out := []
	for i in q.a.size():
		out.append({"id": str(i), "label": "%s) %s" % [["A", "B", "C", "D"][i], q.a[i]], "desc": "", "color": [Pal.PINK, Pal.CYAN, Pal.GOLD, Pal.GREEN][i]})
	return out


func private_info(pid: int) -> Dictionary:
	if stage == 1:
		return {"prompt": "Quanto você confia no seu conhecimento?", "lines": ["Dificuldade maior = prêmio maior... e erro mais caro."]}
	var lv: String = difficulty.get(pid, "facil")
	return {"prompt": str(questions[lv].q), "lines": ["Pergunta %s" % LEVELS[lv][3]], "layout": "grid"}


func bot_action(pid: int) -> Dictionary:
	if stage == 1:
		var sk := ctx.bot_skill(pid, "knowledge")
		var r := ctx.rng.randf() * 0.6 + sk * 0.5 + (ctx.risk_appetite(pid) - 0.5) * 0.4
		return {"choice": "dificil" if r > 0.75 else ("medio" if r > 0.45 else "facil")}
	var lv: String = difficulty.get(pid, "facil")
	var p_ok: float = [0.9, 0.65, 0.42][int(LEVELS[lv][0]) - 1] + (ctx.bot_skill(pid, "knowledge") - 0.5) * 0.4
	var q: Dictionary = questions[lv]
	if ctx.rng.randf() < p_ok:
		return {"choice": str(int(q.c))}
	var wrong := [0, 1, 2, 3].filter(func(i): return i != int(q.c))
	return {"choice": str(wrong[ctx.rng.randi_range(0, 2)])}


func default_action(pid: int) -> Dictionary:
	return {"choice": "facil"} if stage == 1 else {"choice": "-1"}


func validate(pid: int, action: Dictionary) -> bool:
	if stage == 2 and str(action.get("choice", "")) == "-1":
		return true
	return super.validate(pid, action)


func has_next_stage() -> bool:
	return stage == 1


func resolve() -> Array:
	if stage == 1:
		var rows := []
		for pid in participants:
			difficulty[pid] = str(actions[pid].choice)
			var lv: Array = LEVELS[difficulty[pid]]
			rows.append([pname(pid), lv[3], pcolor(pid), [Pal.GREEN, Pal.ORANGE, Pal.RED][int(lv[0]) - 1]])
		return [Challenge.list_step("QUEM ARRISCOU MAIS?", rows, 2.6, {"fx": "reveal", "camera": "players"})]
	var steps := []
	var money := []
	var stat := []
	var rows := []
	for pid in participants:
		var lv: String = difficulty[pid]
		var q: Dictionary = questions[lv]
		var ok := str(actions[pid].choice) == str(int(q.c))
		var d := ctx.scaled(LEVELS[lv][1]) if ok else -ctx.scaled(LEVELS[lv][2])
		if d != 0:
			money.append([pid, d, "Quiz %s" % LEVELS[lv][3]])
		stat.append([pid, "answered", 1])
		if ok:
			stat.append([pid, "correct", 1])
		rows.append([pname(pid) + "  (" + LEVELS[lv][3] + ")", ("ACERTOU " if ok else "ERROU ") + Fmt.delta(d), pcolor(pid), Pal.GREEN if ok else Pal.RED])
	steps.append(Challenge.step("banner", 2.0, {"title": "RESPOSTAS CERTAS", "text": "  ·  ".join(LEVELS.keys().map(func(k): return "%s: %s" % [LEVELS[k][3], questions[k].a[int(questions[k].c)]])), "fx": "drumroll", "camera": "screen"}))
	steps.append(Challenge.list_step("RESULTADO DO QUIZ", rows, 3.4, {"money": money, "stat": stat, "fx": "reveal"}))
	return steps
