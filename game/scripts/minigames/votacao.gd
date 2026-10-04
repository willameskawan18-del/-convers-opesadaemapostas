extends Challenge
## VOTAÇÃO — todos votam (não vale votar em si mesmo). Tipos diferentes a cada vez.
## Quem votou com a maioria também ganha um pouco.

const KINDS := {
	"merece": ["QUEM MERECE %s?", "O mais votado recebe %s."],
	"paga": ["QUEM PAGA A CONTA?", "O mais votado paga %s ao show."],
	"protecao": ["QUEM MERECE UMA SAFE CARD?", "O mais votado ganha uma SAFE CARD."],
	"perigoso": ["QUEM É O MAIS PERIGOSO?", "O mais votado perde 10%% (máx. %s)."],
}
var kind := ""


func start() -> void:
	var keys := KINDS.keys()
	kind = keys[ctx.rng.randi_range(0, keys.size() - 1)]


func value() -> int:
	match kind:
		"merece": return ctx.scaled(5000)
		"paga": return ctx.scaled(2000)
		"perigoso": return ctx.scaled(4000)
	return 0


func title_text() -> String:
	var t: String = KINDS[kind][0]
	return t % Fmt.money(value()) if t.contains("%s") else t


func public_info() -> Dictionary:
	var d: String = KINDS[kind][1]
	return {"kind": kind, "question": title_text(), "effect": d % Fmt.money(value()) if d.contains("%s") else d}


func options(pid: int) -> Array:
	return player_options(pid)


func private_info(_pid: int) -> Dictionary:
	var pub := public_info()
	return {"prompt": str(pub.question), "lines": [str(pub.effect), "Quem votar no mais votado ganha +%s." % Fmt.money(ctx.scaled(300))]}


func bot_action(pid: int) -> Dictionary:
	var opts := options(pid)
	var positive := kind == "merece" or kind == "protecao"
	var best: Dictionary = opts[0]
	var best_score := -INF
	for o in opts:
		var p := ctx.pm.get_player(int(o.player))
		var sc := ctx.rng.randf() * 2.0
		if bool(p.flags.get("traitor", false)):
			sc += -3.0 if positive else 3.0
		var rel := float(ctx.pm.position_of(p.id))
		sc += (rel if positive else -rel) * 0.8
		if sc > best_score:
			best_score = sc
			best = o
	return {"choice": best.id}


func default_action(pid: int) -> Dictionary:
	var opts := options(pid)
	return {"choice": opts[ctx.rng.randi_range(0, opts.size() - 1)].id}


func resolve() -> Array:
	var votes := {}
	for pid in participants:
		var t := int(actions[pid].choice)
		votes[t] = int(votes.get(t, 0)) + 1
	var top := 0
	for t in votes:
		top = maxi(top, int(votes[t]))
	var winners := votes.keys().filter(func(t): return int(votes[t]) == top)
	var chosen: int = winners[ctx.rng.randi_range(0, winners.size() - 1)]
	var rows := []
	for pid in participants:
		var t := int(actions[pid].choice)
		rows.append([pname(pid) + " votou em", pname(t), pcolor(pid), pcolor(t)])
	var steps := [Challenge.list_step(title_text(), rows, 3.4, {"fx": "reveal", "camera": "players"})]
	if winners.size() > 1:
		steps.append(Challenge.step("banner", 2.0, {"title": "EMPATE!", "text": "Desempate no sorteio...", "fx": "drumroll"}))
	var res := {"pid": chosen, "camera": "player", "money": [], "items": []}
	match kind:
		"merece":
			res.title = pname(chosen) + " LEVA " + Fmt.money(value()) + "!"
			res.money = [[chosen, value(), "Votação"]]
			res.fx = "jackpot"
		"paga":
			res.title = pname(chosen) + " PAGA A CONTA!"
			res.money = [[chosen, -value(), "Votação: pagou a conta", "pay"]]
			res.fx = "lose"
		"protecao":
			res.title = pname(chosen) + " GANHA UMA SAFE CARD!"
			res.items = [[chosen, "shield", 1]]
			res.fx = "win"
		_:
			var v := mini(value(), maxi(0, int(money_of(chosen) * 0.1)))
			res.title = pname(chosen) + " É O MAIS PERIGOSO!"
			res.money = [[chosen, -v, "Votação: o mais perigoso", "pay"]]
			res.fx = "lose"
	res.text = "%d voto(s)" % top
	steps.append(Challenge.step("player_result", 2.8, res))
	var bonus := []
	for pid in participants:
		if int(actions[pid].choice) == chosen:
			bonus.append([pid, ctx.scaled(300), "Votou com a maioria"])
	if not bonus.is_empty():
		steps.append(Challenge.step("banner", 1.8, {"title": "VOTARAM COM A MAIORIA", "text": ", ".join(bonus.map(func(b): return pname(int(b[0])))) + "  " + Fmt.delta(ctx.scaled(300)), "money": bonus, "fx": "win"}))
	return steps
