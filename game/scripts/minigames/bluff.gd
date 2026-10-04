extends Challenge
## BLUFF — cada jogador recebe em segredo uma oferta. PEGAR garante o valor;
## DOBRAR pode render o dobro da oferta ou uma perda pesada. Ninguém sabe a oferta dos outros.

var offers: Dictionary = {}


func start() -> void:
	for pid in participants:
		offers[pid] = int(roundf(ctx.scaled(ctx.rng.randf_range(1000.0, 3000.0)) / 100.0) * 100.0)


func lose_value(pid: int) -> int:
	return int(roundf(int(offers[pid]) * 4.0 / 3.0 / 50.0) * 50.0)


func options(pid: int) -> Array:
	var o := int(offers.get(pid, 0))
	return [
		{"id": "double", "label": "DOBRAR", "desc": "50%%: %s  |  50%%: %s" % [Fmt.delta(o * 2), Fmt.delta(-lose_value(pid))], "color": Color("ff3d7f")},
		{"id": "take", "label": "PEGAR", "desc": "Leva " + Fmt.delta(o), "color": Color("3ddc97")},
	]


func private_info(pid: int) -> Dictionary:
	return {"offer": offers.get(pid, 0), "lose": lose_value(pid) if offers.has(pid) else 0, "prompt": "SUA OFERTA SECRETA: " + Fmt.money(int(offers.get(pid, 0)))}


func bot_action(pid: int) -> Dictionary:
	var appetite := ctx.risk_appetite(pid) - 0.1
	return {"choice": "double" if ctx.rng.randf() < appetite else "take"}


func resolve() -> Array:
	var steps := []
	steps.append(Challenge.step("banner", 2.0, {"title": "HORA DA VERDADE", "text": "Quem pegou... e quem dobrou?", "fx": "drumroll", "camera": "stage"}))
	var order := participants.duplicate()
	order.shuffle()
	for pid in order:
		var o := int(offers[pid])
		if actions[pid].choice == "take":
			steps.append(Challenge.step("player_result", 1.8, {"title": pname(pid) + " PEGOU", "text": "Oferta secreta: %s" % Fmt.money(o), "pid": pid,
				"money": [[pid, o, "Bluff: pegou"]], "fx": "win", "camera": "player", "choice": "PEGAR"}))
		else:
			var won := ctx.rng.randf() < 0.5
			var d := o * 2 if won else -lose_value(pid)
			var res := {"title": pname(pid) + " DOBROU... " + ("E GANHOU!" if won else "E PERDEU!"), "text": "Oferta era %s → %s" % [Fmt.money(o), Fmt.delta(d)], "pid": pid,
				"money": [[pid, d, "Bluff: dobrou"]], "risk": [[pid, mini(lose_value(pid), money_of(pid))]], "fx": "jackpot" if won else "lose", "camera": "player", "choice": "DOBRAR"}
			if won:
				res["mult"] = [[pid, 2.0]]
			steps.append(Challenge.step("player_result", 2.6, res))
	return steps
