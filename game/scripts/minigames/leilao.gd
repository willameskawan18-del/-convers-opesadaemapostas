extends Challenge
## LEILÃO (com informação secreta) — um prêmio misterioso. Alguns jogadores recebem PISTAS
## secretas (que podem estar erradas). Lances ABERTOS em até 4 etapas: todos veem os lances.
## Quem passar sai. O maior lance paga e leva: +$10.000, +$5.000, x2, proteção... ou penalidade.

const ITEMS := ["MALETA MISTERIOSA", "CAIXA DOURADA", "COFRE DO APRESENTADOR", "ENVELOPE PRETO", "BAÚ DO PIRATA", "PRESENTE SUSPEITO"]
const PRIZES := [["cash_big", 15], ["cash", 25], ["double", 15], ["shield", 15], ["penalty", 20], ["empty", 10]]
const MAX_STAGES := 4

var item := ""
var prize := ""
var bids: Dictionary = {}       # pid -> maior lance
var history: Array = []         # [[etapa, pid, lance|-1]]
var active: Array[int] = []
var hints: Dictionary = {}      # pid -> texto
var high_pid := -1
var raised_this_stage := 0


func start() -> void:
	item = ITEMS[ctx.rng.randi_range(0, ITEMS.size() - 1)]
	var total := 0
	for p in PRIZES:
		total += int(p[1])
	var r := ctx.rng.randi_range(1, total)
	for p in PRIZES:
		r -= int(p[1])
		if r <= 0:
			prize = str(p[0])
			break
	for pid in participants:
		bids[pid] = 0
	active = participants.duplicate()
	# Informação secreta para ~metade dos jogadores (80% de chance de ser verdade)
	var informed := participants.duplicate()
	informed.shuffle()
	for i in maxi(1, participants.size() / 2):
		var pid: int = informed[i]
		var truthful := ctx.rng.randf() < 0.8
		var p := prize if truthful else str(PRIZES[ctx.rng.randi_range(0, PRIZES.size() - 1)][0])
		hints[pid] = _hint_text(p)


func _hint_text(p: String) -> String:
	match p:
		"cash_big": return "Tenho 80%% de certeza que vale MAIS de %s." % Fmt.money(prize_value("cash"))
		"cash": return "Ouvi dizer que é dinheiro... uns %s." % Fmt.money(prize_value("cash"))
		"double": return "Parece que DOBRA alguma coisa..."
		"shield": return "Acho que é um item de PROTEÇÃO."
		"penalty", "empty": return "Acho que é uma ARMADILHA."
	return "Não faço ideia."


func prize_value(p: String) -> int:
	match p:
		"cash_big": return ctx.scaled(10000)
		"cash": return ctx.scaled(5000)
	return 0


func prize_text() -> String:
	match prize:
		"cash_big": return "%s EM DINHEIRO!" % Fmt.money(prize_value("cash_big"))
		"cash": return "%s EM DINHEIRO!" % Fmt.money(prize_value("cash"))
		"double": return "x2 NO SEU DINHEIRO (até %s)!" % Fmt.money(ctx.scaled(8000))
		"shield": return "2 SAFE CARDS!"
		"penalty": return "PENALIDADE: %s!" % Fmt.delta(-ctx.scaled(3000))
	return "CAIXA VAZIA!"


func deciders() -> Array[int]:
	return active


func input_type() -> String:
	return "auction"


func stage_title() -> String:
	return "LANCES — ETAPA %d DE %d" % [stage, MAX_STAGES]


func time_limit() -> float:
	return 16.0


func min_bid() -> int:
	return int(bids.get(high_pid, 0)) + ctx.scaled(200) if high_pid >= 0 else ctx.scaled(200)


func public_info() -> Dictionary:
	var hist := []
	for h in history:
		hist.append([pname(int(h[1])), int(h[2]), int(h[0])])
	return {"item": item, "high": int(bids.get(high_pid, 0)), "high_name": pname(high_pid) if high_pid >= 0 else "", "history": hist, "min": min_bid()}


func private_info(pid: int) -> Dictionary:
	var lines := ["Possíveis prêmios: +$10.000, +$5.000, x2, proteção, penalidade ou nada."]
	if hints.has(pid):
		lines.append("SUA PISTA SECRETA: " + str(hints[pid]))
	else:
		lines.append("Você não recebeu pista. Observe os lances dos outros!")
	return {"prompt": item, "lines": lines, "max_bid": maxi(0, money_of(pid)), "min_bid": min_bid(), "my_bid": int(bids.get(pid, 0)), "history": public_info().history,
		"high": int(bids.get(high_pid, 0)), "high_name": pname(high_pid) if high_pid >= 0 else ""}


func validate(pid: int, action: Dictionary) -> bool:
	if action.get("pass", false):
		return true
	var b := int(action.get("bid", -1))
	return b >= min_bid() and b <= money_of(pid)


func bot_action(pid: int) -> Dictionary:
	var est := ctx.scaled(3500)
	if hints.has(pid):
		var h: String = hints[pid]
		if h.contains("MAIS"):
			est = ctx.scaled(9000)
		elif h.contains("dinheiro"):
			est = ctx.scaled(5000)
		elif h.contains("DOBRA"):
			est = mini(money_of(pid), ctx.scaled(8000))
		elif h.contains("PROTEÇÃO"):
			est = ctx.scaled(2000)
		else:
			est = ctx.scaled(300)
	var limit := int(est * (0.4 + ctx.risk_appetite(pid) * 0.6))
	var mb := min_bid()
	if mb > limit or mb > money_of(pid) or (high_pid == pid):
		return {"pass": true} if high_pid != pid else {"pass": true, "hold": true}
	var b := mini(money_of(pid), mb + int(ctx.rng.randf_range(0.0, 0.3) * limit / 50.0) * 50)
	return {"bid": b}


func default_action(_pid: int) -> Dictionary:
	return {"pass": true}


func has_next_stage() -> bool:
	return stage < MAX_STAGES and raised_this_stage > 0 and active.size() > 1


func resolve() -> Array:
	raised_this_stage = 0
	var rows := []
	# processa lances em ordem crescente (o maior fica por último e vira o líder)
	var order := active.duplicate()
	order.sort_custom(func(a, b): return int(actions[a].get("bid", 0)) < int(actions[b].get("bid", 0)))
	for pid in order:
		var a: Dictionary = actions[pid]
		if a.get("pass", false):
			if pid != high_pid:
				active.erase(pid)
				history.append([stage, pid, -1])
				rows.append([pname(pid), "PASSOU", pcolor(pid), Pal.MUTED])
			else:
				rows.append([pname(pid), "segura o lance " + Fmt.money(int(bids[pid])), pcolor(pid), Pal.CYAN])
			continue
		var b := int(a.bid)
		if b > int(bids.get(high_pid, 0)) or high_pid < 0:
			high_pid = pid
		bids[pid] = b
		raised_this_stage += 1
		history.append([stage, pid, b])
		rows.append([pname(pid), "LANCE " + Fmt.money(b), pcolor(pid), Pal.GOLD if pid == high_pid else Pal.TEXT])
	var steps := [Challenge.list_step("LANCES (ETAPA %d)" % stage, rows, 2.8, {"fx": "reveal", "camera": "players"})]
	if has_next_stage():
		steps.append(Challenge.step("banner", 1.8, {"title": "MAIOR LANCE: " + Fmt.money(int(bids[high_pid])), "text": pname(high_pid) + " está na frente. Alguém cobre?", "fx": "drumroll", "camera": "players"}))
		return steps
	# fim do leilão
	if high_pid < 0 or int(bids.get(high_pid, 0)) <= 0:
		steps.append(Challenge.step("banner", 2.4, {"title": "NINGUÉM ARREMATOU!", "text": "Dentro tinha: " + prize_text(), "fx": "reveal", "camera": "screen"}))
		return steps
	var paid := int(bids[high_pid])
	steps.append(Challenge.step("player_result", 2.4, {"title": "ARREMATADO POR " + pname(high_pid), "text": "Pagou " + Fmt.money(paid), "pid": high_pid,
		"money": [[high_pid, -paid, "Leilão: lance", "pay"]], "risk": [[high_pid, paid]], "fx": "reveal", "camera": "player"}))
	steps.append(Challenge.step("banner", 1.8, {"title": "ABRINDO O " + item + "...", "fx": "drumroll", "camera": "stage"}))
	var res := {"title": prize_text(), "pid": high_pid, "fx": "win", "camera": "player", "money": [], "items": []}
	match prize:
		"cash_big", "cash":
			var v := prize_value(prize)
			res.money = [[high_pid, v, "Leilão: prêmio"]]
			res.text = "Lucro: " + Fmt.delta(v - paid)
			res.fx = "jackpot" if v > paid * 2 else ("win" if v > paid else "lose")
			if paid > 0:
				res["mult"] = [[high_pid, float(v) / paid]]
		"double":
			var v := clampi(money_of(high_pid) - paid, 0, ctx.scaled(8000))
			res.money = [[high_pid, v, "Leilão: x2"]]
			res.text = "Dobrou: " + Fmt.delta(v)
			res["mult"] = [[high_pid, 2.0]]
		"shield":
			res.items = [[high_pid, "shield", 2]]
			res.text = "Duas proteções para as próximas rodadas!"
		"penalty":
			res.money = [[high_pid, -ctx.scaled(3000), "Leilão: armadilha"]]
			res.text = "Era uma armadilha!"
			res.fx = "lose"
		_:
			res.text = "Pagou por nada!"
			res.fx = "lose"
	steps.append(Challenge.step("prize", 3.2, res))
	return steps
