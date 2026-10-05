extends Challenge
## RISCO — SAFE garante um valor pequeno; RISK é cara ou coroa: ganha muito ou perde muito.

var safe_v := 0
var win_v := 0
var lose_v := 0


func start() -> void:
	safe_v = ctx.scaled(500)
	win_v = ctx.scaled(2000)
	lose_v = ctx.scaled(1000)


func options(_pid: int) -> Array:
	return [
		{"id": "risk", "label": "RISK", "desc": "50%%: %s  |  50%%: %s" % [Fmt.delta(win_v), Fmt.delta(-lose_v)], "color": Color("ff3d7f")},
		{"id": "safe", "label": "SAFE", "desc": "Garantido: " + Fmt.delta(safe_v), "color": Color("3ddc97")},
	]


func public_info() -> Dictionary:
	return {"safe": safe_v, "win": win_v, "lose": lose_v}


func bot_action(pid: int) -> Dictionary:
	var appetite := ctx.risk_appetite(pid)
	if money_of(pid) <= 0:
		appetite += 0.5
	return {"choice": "risk" if ctx.rng.randf() < appetite else "safe"}


func resolve() -> Array:
	var steps := []
	var safe_ids := participants.filter(func(pid): return actions[pid].choice == "safe")
	var risk_ids := participants.filter(func(pid): return actions[pid].choice == "risk")
	var choices := {}
	for pid in participants:
		choices[pid] = "SAFE" if safe_ids.has(pid) else "RISK"
	steps.append(Challenge.step("choices", 2.6, {"title": "SAFE OU RISK?", "text": "%d no seguro, %d no risco!" % [safe_ids.size(), risk_ids.size()], "choices": choices, "fx": "reveal", "camera": "players"}))
	if not safe_ids.is_empty():
		var money := []
		for pid in safe_ids:
			money.append([pid, safe_v, "SAFE"])
		steps.append(Challenge.step("banner", 1.8, {"title": "OS CAUTELOSOS", "text": "Cada um leva " + Fmt.delta(safe_v), "money": money, "fx": "win", "camera": "players"}))
	if risk_ids.is_empty():
		steps.append(Challenge.step("banner", 1.8, {"title": "NINGUÉM ARRISCOU!", "text": "A plateia vaia!", "fx": "lose"}))
		return steps
	steps.append(Challenge.step("banner", 1.8, {"title": "E AGORA... A MOEDA!", "text": "Quem arriscou vai descobrir o destino", "fx": "drumroll", "camera": "stage"}))
	risk_ids.shuffle()
	for pid in risk_ids:
		var won := ctx.rng.randf() < 0.5
		var d := win_v if won else -lose_v
		var res := {"title": pname(pid) + (": GANHOU!" if won else ": PERDEU!"), "text": Fmt.delta(d), "pid": pid,
			"coin": "win" if won else "lose", "money": [[pid, d, "RISK"]], "risk": [[pid, mini(lose_v, maxi(money_of(pid), 0))]],
			"fx": "win" if won else "lose", "camera": "player"}
		if won:
			res["mult"] = [[pid, 2.0]]
		steps.append(Challenge.step("coin", 2.0, res))
	return steps
