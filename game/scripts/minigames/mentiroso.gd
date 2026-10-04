extends Challenge
## QUEM ESTÁ MENTINDO? — três personagens respondem a mesma pergunta. Só UM diz a verdade.
## Duas rodadas. Acertar +2.000 · Errar -1.000.

const COUNT := 2
const CHARS := ["Sortudo", "Azarado", "Rico", "Trapaceiro", "Apostador", "Gênio", "Medroso", "Maluco"]
var puzzles: Array = []   # {q, claims:[[who, answer]], truth}


func start() -> void:
	for i in COUNT:
		var q := ctx.question(1 + i)
		var who := CHARS.duplicate()
		who.shuffle()
		var wrong := [0, 1, 2, 3].filter(func(k): return k != int(q.c))
		wrong.shuffle()
		var answers := [int(q.c), wrong[0], wrong[1]]
		answers.shuffle()
		var claims := []
		for k in 3:
			claims.append([who[k], str(q.a[answers[k]])])
		puzzles.append({"q": q.q, "claims": claims, "truth": answers.find(int(q.c))})


func stage_title() -> String:
	return "CASO %d DE %d" % [stage, COUNT]


func time_limit() -> float:
	return 18.0


func options(_pid: int) -> Array:
	var p: Dictionary = puzzles[stage - 1]
	var out := []
	for k in 3:
		out.append({"id": str(k), "label": str(p.claims[k][0]), "desc": "“%s”" % p.claims[k][1], "color": [Pal.PINK, Pal.CYAN, Pal.GOLD][k]})
	return out


func private_info(_pid: int) -> Dictionary:
	var p: Dictionary = puzzles[stage - 1]
	var lines := []
	for k in 3:
		lines.append("%s diz: “%s”" % [p.claims[k][0], p.claims[k][1]])
	return {"prompt": "Pergunta: " + str(p.q), "lines": lines, "footer": "Só UM diz a verdade. Quem?"}


func bot_action(pid: int) -> Dictionary:
	var p: Dictionary = puzzles[stage - 1]
	var sk := ctx.bot_skill(pid, "knowledge")
	if ctx.rng.randf() < 0.5 + sk * 0.4:
		return {"choice": str(int(p.truth))}
	return {"choice": str((int(p.truth) + ctx.rng.randi_range(1, 2)) % 3)}


func default_action(_pid: int) -> Dictionary:
	return {"choice": "-1"}


func validate(pid: int, action: Dictionary) -> bool:
	return str(action.get("choice", "")) == "-1" or super.validate(pid, action)


func has_next_stage() -> bool:
	return stage < COUNT


func resolve() -> Array:
	var p: Dictionary = puzzles[stage - 1]
	var money := []
	var stat := []
	var rows := []
	for pid in participants:
		var ok := str(actions[pid].choice) == str(int(p.truth))
		var d := ctx.scaled(2000) if ok else -ctx.scaled(1000)
		money.append([pid, d, "Quem mente?"])
		stat.append([pid, "answered", 1])
		if ok:
			stat.append([pid, "correct", 1])
		rows.append([pname(pid), Fmt.delta(d), pcolor(pid), Pal.GREEN if ok else Pal.RED])
	var truth_claim: Array = p.claims[int(p.truth)]
	return [
		Challenge.step("banner", 2.4, {"title": "%s FALOU A VERDADE!" % str(truth_claim[0]).to_upper(), "text": "“%s”" % truth_claim[1], "fx": "reveal", "camera": "screen"}),
		Challenge.list_step("QUEM DESCOBRIU?", rows, 2.8, {"money": money, "stat": stat}),
	]
