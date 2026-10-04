extends Challenge
## BOMBA — 12 caixas: dinheiro, 1 JACKPOT e 3 BOMBAS. A cada etapa você abre uma caixa
## (aumentando seu pote) ou PARA e leva o pote. Bomba = perde o pote e paga multa.
## As caixas abertas por todos ficam visíveis: informação para a próxima escolha.

const MAX_STAGES := 4
var boxes: Array = []        # [{kind: "money"|"bomb"|"jackpot", value}]
var opened: Dictionary = {}  # índice -> true
var pot: Dictionary = {}     # pid -> valor acumulado
var active: Array[int] = []  # ainda abrindo caixas
var out_reason: Dictionary = {}


func start() -> void:
	var vals := [200, 400, 400, 600, 600, 900, 1200, 2000]
	for v in vals:
		boxes.append({"kind": "money", "value": ctx.scaled(v)})
	for i in 3:
		boxes.append({"kind": "bomb", "value": 0})
	boxes.append({"kind": "jackpot", "value": 0})
	boxes.shuffle()
	for pid in participants:
		pot[pid] = 0
	active = participants.duplicate()


func deciders() -> Array[int]:
	return active


func stage_title() -> String:
	return "CAIXA %d" % stage


func time_limit() -> float:
	return 15.0


func options(pid: int) -> Array:
	var out := []
	for i in boxes.size():
		if opened.has(i):
			continue
		out.append({"id": str(i), "label": str(i + 1), "desc": "", "color": Pal.PURPLE})
	if stage > 1:
		out.append({"id": "stop", "label": "PARAR (%s)" % Fmt.money(int(pot.get(pid, 0))), "desc": "Leva o pote", "color": Pal.GREEN})
	return out


func public_info() -> Dictionary:
	var revealed := {}
	for i in opened:
		revealed[i] = boxes[i].kind if boxes[i].kind != "money" else Fmt.money(int(boxes[i].value))
	return {"revealed": revealed, "count": boxes.size(), "jackpot": ctx.jackpot}


func private_info(pid: int) -> Dictionary:
	var bombs_left := 0
	var closed := 0
	for i in boxes.size():
		if not opened.has(i):
			closed += 1
			if boxes[i].kind == "bomb":
				bombs_left += 1
	return {"prompt": "Seu pote: %s" % Fmt.money(int(pot.get(pid, 0))) if stage > 1 else "Escolha uma caixa!",
		"lines": ["Ainda há %d bomba(s) em %d caixas fechadas. Tem 1 JACKPOT (%s)!" % [bombs_left, closed, Fmt.money(ctx.jackpot)]],
		"layout": "boxes", "revealed": public_info().revealed}


func bot_action(pid: int) -> Dictionary:
	var opts := options(pid)
	var appetite := ctx.risk_appetite(pid)
	if stage > 1 and ctx.rng.randf() > appetite * 0.9 + 0.05 * (MAX_STAGES - stage):
		return {"choice": "stop"}
	var boxes_opts := opts.filter(func(o): return o.id != "stop")
	if boxes_opts.is_empty():
		return {"choice": "stop"}
	return {"choice": boxes_opts[ctx.rng.randi_range(0, boxes_opts.size() - 1)].id}


func default_action(pid: int) -> Dictionary:
	return {"choice": "stop"} if stage > 1 else bot_action(pid)


func has_next_stage() -> bool:
	return stage < MAX_STAGES and not active.is_empty() and opened.size() < boxes.size()


func resolve() -> Array:
	var steps := []
	var rows := []
	var money := []
	var stat := []
	var jackpot_pids := []
	var newly := {}
	var stoppers := []
	for pid in active.duplicate():
		var c := str(actions[pid].choice)
		if c == "stop":
			stoppers.append(pid)
			continue
		var idx := int(c)
		newly[idx] = true
		var b: Dictionary = boxes[idx]
		if stage > 1:
			stat.append([pid, "continues", 1])
		match str(b.kind):
			"bomb":
				var lost := int(pot[pid])
				var fine := ctx.scaled(500)
				money.append([pid, -fine, "Bomba!"])
				stat.append([pid, "risk_total", lost])
				rows.append([pname(pid) + " → caixa %d" % (idx + 1), "BOMBA! perdeu %s" % Fmt.money(lost + fine), pcolor(pid), Pal.RED])
				pot[pid] = 0
				active.erase(pid)
			"jackpot":
				jackpot_pids.append(pid)
				rows.append([pname(pid) + " → caixa %d" % (idx + 1), "JACKPOT!!!", pcolor(pid), Pal.GOLD])
			_:
				pot[pid] = int(pot[pid]) + int(b.value)
				rows.append([pname(pid) + " → caixa %d" % (idx + 1), "+%s (pote %s)" % [Fmt.money(int(b.value)), Fmt.money(int(pot[pid]))], pcolor(pid), Pal.GREEN])
	for i in newly:
		opened[i] = true
	if not rows.is_empty():
		steps.append(Challenge.list_step("ABRINDO AS CAIXAS...", rows, 3.2, {"money": money, "stat": stat, "fx": "lose" if money.size() > 0 else "win", "camera": "players"}))
	if not jackpot_pids.is_empty():
		steps.append(Challenge.step("banner", 3.0, {"title": "JACKPOT!", "text": ", ".join(jackpot_pids.map(func(p): return pname(p))) + " leva " + Fmt.money(ctx.jackpot),
			"money": jackpot_entries(jackpot_pids), "fx": "jackpot", "camera": "players"}))
	# quem parou (ou chegou na última etapa) leva o pote
	var cash := stoppers.duplicate()
	if stage >= MAX_STAGES or opened.size() >= boxes.size():
		for pid in active:
			if not cash.has(pid):
				cash.append(pid)
	var cm := []
	var crow := []
	for pid in cash:
		if int(pot[pid]) > 0:
			cm.append([pid, int(pot[pid]), "Bomba: pote"])
			stat.append([pid, "risk_total", int(pot[pid])])
		crow.append([pname(pid), "LEVOU " + Fmt.money(int(pot[pid])), pcolor(pid), Pal.GREEN])
		active.erase(pid)
	if not cm.is_empty() or not crow.is_empty():
		steps.append(Challenge.list_step("PARARAM A TEMPO", crow, 2.4, {"money": cm, "fx": "win"}))
	if steps.is_empty():
		steps.append(Challenge.step("banner", 1.5, {"title": "...", "fx": "reveal"}))
	return steps
