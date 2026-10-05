extends Challenge
## CARTAS — 8 cartas viradas. Escolha uma, ESPIE em segredo e decida: MANTER ou TROCAR
## (troca por outra carta aleatória, sem ver). Efeitos: GANHO, PERDA, MULTIPLICADOR,
## PROTEÇÃO (SAFE CARD), TROCA (troca de lugar com quem está logo acima) e JACKPOT.

const NAMES := {"gain": "GANHO", "big_gain": "GANHO GRANDE", "loss": "PERDA", "mult": "MULTIPLICADOR", "shield": "PROTEÇÃO", "swap": "TROCA", "jackpot": "JACKPOT"}
var deck: Array = []         # tipos
var picks: Dictionary = {}   # pid -> índice da carta
var final: Dictionary = {}   # pid -> índice final


func start() -> void:
	deck = ["gain", "big_gain", "loss", "loss", "mult", "shield", "swap", "gain"]
	if ctx.rng.randf() < 0.45:
		deck[7] = "jackpot"
	deck.shuffle()


func stage_title() -> String:
	return "ESCOLHA UMA CARTA" if stage == 1 else "MANTER OU TROCAR?"


func time_limit() -> float:
	return 14.0


func describe(kind: String) -> String:
	match kind:
		"gain": return "GANHO: " + Fmt.delta(ctx.scaled(1500))
		"big_gain": return "GANHO GRANDE: " + Fmt.delta(ctx.scaled(3000))
		"loss": return "PERDA: " + Fmt.delta(-ctx.scaled(1500))
		"mult": return "MULTIPLICADOR: +30% do seu dinheiro"
		"shield": return "PROTEÇÃO: ganha 1 SAFE CARD"
		"swap": return "TROCA: troca de dinheiro com quem está logo acima"
		"jackpot": return "JACKPOT: leva " + Fmt.money(ctx.jackpot)
	return kind


func options(pid: int) -> Array:
	if stage == 1:
		var out := []
		for i in deck.size():
			out.append({"id": str(i), "label": "?", "desc": "", "color": [Pal.PINK, Pal.CYAN, Pal.GOLD, Pal.PURPLE][i % 4]})
		return out
	return [
		{"id": "swap", "label": "TROCAR", "desc": "Pega outra carta (às cegas)", "color": Pal.ORANGE},
		{"id": "keep", "label": "MANTER", "desc": "Fica com esta", "color": Pal.GREEN},
	]


func private_info(pid: int) -> Dictionary:
	if stage == 1:
		return {"prompt": "Escolha uma carta!", "lines": ["No baralho: 2 ganhos, 1 ganho grande, 2 perdas, multiplicador, proteção, troca%s" % (" e um JACKPOT?" if deck.has("jackpot") else "")], "layout": "cards"}
	var k: String = deck[int(picks.get(pid, 0))]
	return {"prompt": "Sua carta (só você vê): " + describe(k), "lines": ["Trocar te dá uma carta aleatória entre as outras 7."], "peek": k}


func bot_action(pid: int) -> Dictionary:
	if stage == 1:
		return {"choice": str(ctx.rng.randi_range(0, deck.size() - 1))}
	var k: String = deck[int(picks.get(pid, 0))]
	var bad := k == "loss" or (k == "swap" and ctx.pm.position_of(pid) == 1)
	return {"choice": "swap" if bad or (k == "gain" and ctx.rng.randf() < ctx.risk_appetite(pid) * 0.4) else "keep"}


func default_action(pid: int) -> Dictionary:
	return {"choice": str(ctx.rng.randi_range(0, deck.size() - 1))} if stage == 1 else {"choice": "keep"}


func has_next_stage() -> bool:
	return stage == 1


func resolve() -> Array:
	if stage == 1:
		for pid in participants:
			picks[pid] = int(actions[pid].choice)
		return [Challenge.step("banner", 1.8, {"title": "CARTAS ESCOLHIDAS!", "text": "Agora cada um espia a sua... em segredo.", "fx": "reveal", "camera": "players"})]
	var rows := []
	var steps := []
	var jackpot_pids := []
	var money := []
	var items := []
	var mult := []
	var swaps := []
	for pid in participants:
		var idx: int = picks[pid]
		var swapped := str(actions[pid].choice) == "swap"
		if swapped:
			var choices := range(deck.size()).filter(func(i): return i != idx)
			idx = choices[ctx.rng.randi_range(0, choices.size() - 1)]
			ctx.pm.get_player(pid).stats.continues = int(ctx.pm.get_player(pid).stats.get("continues", 0)) + 1
		final[pid] = idx
		var k: String = deck[idx]
		var txt: String = NAMES[k]
		var col := Pal.GREEN
		match k:
			"gain": money.append([pid, ctx.scaled(1500), "Carta: ganho"])
			"big_gain": money.append([pid, ctx.scaled(3000), "Carta: ganho grande"])
			"loss":
				money.append([pid, -ctx.scaled(1500), "Carta: perda"])
				col = Pal.RED
			"mult":
				var v := clampi(int(money_of(pid) * 0.3), ctx.scaled(500), ctx.scaled(5000))
				money.append([pid, v, "Carta: multiplicador"])
				mult.append([pid, 1.3])
				txt += " " + Fmt.delta(v)
			"shield":
				items.append([pid, "shield", 1])
				col = Pal.CYAN
			"swap":
				swaps.append(pid)
				col = Pal.ORANGE
			"jackpot":
				jackpot_pids.append(pid)
				col = Pal.GOLD
		rows.append([pname(pid) + (" (trocou)" if swapped else ""), txt, pcolor(pid), col])
	steps.append(Challenge.list_step("CARTAS NA MESA!", rows, 3.6, {"money": money, "items": items, "mult": mult, "fx": "reveal", "camera": "players"}))
	for pid in swaps:
		var above := _player_above(pid)
		if above < 0:
			steps.append(Challenge.step("player_result", 2.2, {"title": pname(pid) + ": TROCA!", "text": "Já está em 1º... ninguém acima. Nada acontece.", "pid": pid, "fx": "reveal", "camera": "player"}))
			continue
		var a := money_of(pid)
		var b := money_of(above)
		steps.append(Challenge.step("player_result", 3.0, {"title": "%s TROCA COM %s!" % [pname(pid), pname(above)], "text": "%s ⇄ %s" % [Fmt.money(a), Fmt.money(b)], "pid": pid,
			"money": [[pid, b - a, "Carta: troca", "nobonus"], [above, a - b, "Carta: troca", "nobonus"]], "fx": "jackpot" if b > a else "lose", "camera": "player"}))
	if not jackpot_pids.is_empty():
		steps.append(Challenge.step("banner", 3.0, {"title": "JACKPOT!", "text": ", ".join(jackpot_pids.map(func(p): return pname(p))) + " leva " + Fmt.money(ctx.jackpot),
			"money": jackpot_entries(jackpot_pids), "fx": "jackpot", "camera": "players"}))
	return steps


func _player_above(pid: int) -> int:
	var m := money_of(pid)
	var best := -1
	for o in participants:
		if o != pid and money_of(o) > m and (best < 0 or money_of(o) < money_of(best)):
			best = o
	return best
