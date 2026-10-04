extends SkillChallenge
## MEMÓRIA — uma sequência de cores aparece e some. Repita na ordem!
## Cada cor certa vale dinheiro; sequência completa ganha bônus.

const COLORS := ["VERMELHO", "AZUL", "VERDE", "AMARELO", "ROXO", "LARANJA"]
var sequence: Array = []


func start() -> void:
	var n := 6 + (1 if ctx.round_index > 5 else 0)
	for i in n:
		sequence.append(ctx.rng.randi_range(0, COLORS.size() - 1))


func game_seconds() -> float:
	return sequence.size() * 0.8 + 14.0


func public_info() -> Dictionary:
	var d := super.public_info()
	d["sequence"] = sequence
	d["colors"] = COLORS
	return d


func private_info(_pid: int) -> Dictionary:
	return {"prompt": "Memorize a sequência!", "lines": ["Cada cor certa: %s  ·  Sequência perfeita: +%s" % [Fmt.money(ctx.scaled(350)), Fmt.money(ctx.scaled(1500))]]}


func validate(_pid: int, action: Dictionary) -> bool:
	return action.has("correct") and int(action.correct) >= 0 and int(action.correct) <= sequence.size()


func default_action(_pid: int) -> Dictionary:
	return {"correct": 0, "score": 0.0, "miss": true}


func bot_action(pid: int) -> Dictionary:
	var sk := ctx.bot_skill(pid)
	var c := 0
	while c < sequence.size() and ctx.rng.randf() < 0.72 + sk * 0.25:
		c += 1
	return {"correct": c, "score": float(c) / sequence.size()}


func resolve() -> Array:
	var rows := []
	var money := []
	var r := participants.duplicate()
	r.sort_custom(func(a, b): return int(actions[a].get("correct", 0)) > int(actions[b].get("correct", 0)))
	for pid in r:
		var c := int(actions[pid].get("correct", 0))
		var perfect := c == sequence.size()
		var d := c * ctx.scaled(350) + (ctx.scaled(1500) if perfect else 0)
		if d > 0:
			money.append([pid, d, "Memória"])
		rows.append([pname(pid), "%d/%d %s %s" % [c, sequence.size(), "PERFEITO!" if perfect else "", Fmt.delta(d)], pcolor(pid), Pal.GOLD if perfect else (Pal.GREEN if d > 0 else Pal.MUTED)])
	var stat := skill_stats(participants)
	stat.append([r[0], "skill_wins", 1])
	var seq_txt := " · ".join(sequence.map(func(i): return COLORS[i]))
	return [
		Challenge.step("banner", 2.2, {"title": "A SEQUÊNCIA ERA", "text": seq_txt, "fx": "reveal", "camera": "screen"}),
		Challenge.list_step("MEMÓRIA", rows, 3.2, {"money": money, "stat": stat}),
	]
