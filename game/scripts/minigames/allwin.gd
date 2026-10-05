extends Challenge
## ALL WIN — a decisão final. SAFE guarda 90% do patrimônio.
## ALL WIN coloca tudo na roleta: JACKPOT x4, DOBROU x2 ou PERDEU (sobra 10%).
## Quem está zerado ou endividado ainda pode jogar ALL WIN com uma ficha de $1.000
## (ganha o prêmio da ficha, mas não perde mais nada).

const SAFE_KEEP := 0.9
const LOSE_KEEP := 0.1
const OUTCOMES := [["jackpot", 4.0, 10], ["double", 2.0, 35], ["lose", 0.0, 55]]
const ZERO_CHIP := 1000

var outcomes: Dictionary = {}   # pid -> "jackpot" | "double" | "lose"


func options(pid: int) -> Array:
	var m := money_of(pid)
	var base := maxi(m, ZERO_CHIP)
	if m <= 0:
		return [
			{"id": "allwin", "label": "ALL WIN", "desc": "Ficha de %s: x4 ou x2... ou nada" % Fmt.money(ZERO_CHIP), "color": Color("ffcc33")},
			{"id": "safe", "label": "SAFE", "desc": "Fica com %s" % Fmt.money(m), "color": Color("3ddc97")},
		]
	return [
		{"id": "allwin", "label": "ALL WIN", "desc": "x4 ou x2 → até %s  |  ou sobra %s" % [Fmt.money(base * 4), Fmt.money(int(m * LOSE_KEEP))], "color": Color("ffcc33")},
		{"id": "safe", "label": "SAFE", "desc": "Guarda %s (90%%)" % Fmt.money(int(m * SAFE_KEEP)), "color": Color("3ddc97")},
	]


func public_info() -> Dictionary:
	return {"safe_keep": SAFE_KEEP, "lose_keep": LOSE_KEEP, "chances": "JACKPOT x4: 10%  ·  DOBROU x2: 35%  ·  PERDEU: 55%"}


func time_limit() -> float:
	return ctx.decision_time + 5.0


func bot_action(pid: int) -> Dictionary:
	var pos := ctx.pm.position_of(pid)
	var appetite := ctx.risk_appetite(pid)
	if pos == 1:
		appetite *= 0.45
	elif pos >= 3:
		appetite = minf(1.0, appetite + 0.3)
	return {"choice": "allwin" if ctx.rng.randf() < appetite else "safe"}


func _roll() -> String:
	var r := ctx.rng.randi_range(1, 100)
	for o in OUTCOMES:
		r -= int(o[2])
		if r <= 0:
			return str(o[0])
	return "lose"


func resolve() -> Array:
	var steps := []
	var choices := {}
	var allin := []
	for pid in participants:
		choices[pid] = "ALL WIN" if actions[pid].choice == "allwin" else "SAFE"
		if actions[pid].choice == "allwin":
			allin.append(pid)
	steps.append(Challenge.step("allwin_choices", 4.0, {"title": "AS ESCOLHAS FINAIS", "text": "%d jogador(es) foram de ALL WIN!" % allin.size(), "choices": choices, "fx": "reveal", "camera": "players"}))
	# SAFE
	var safe_money := []
	for pid in participants:
		if not allin.has(pid):
			var m := money_of(pid)
			if m > 0:
				safe_money.append([pid, int(m * SAFE_KEEP) - m, "SAFE final", "pay"])
	if not safe_money.is_empty():
		steps.append(Challenge.step("banner", 2.2, {"title": "OS PRUDENTES GUARDAM 90%", "money": safe_money, "fx": "reveal", "camera": "players"}))
	if allin.is_empty():
		steps.append(Challenge.step("banner", 2.4, {"title": "NINGUÉM TEVE CORAGEM!", "text": "A plateia não acredita!", "fx": "lose", "camera": "stage"}))
		return steps
	var results := {}
	var money := []
	var mult := []
	var risk := []
	for pid in allin:
		var o := _roll()
		outcomes[pid] = o
		results[pid] = o
		var m := money_of(pid)
		var d := 0
		if m <= 0:
			d = {"jackpot": ZERO_CHIP * 4, "double": ZERO_CHIP * 2}.get(o, 0)
		else:
			match o:
				"jackpot": d = m * 3
				"double": d = m
				_: d = int(m * LOSE_KEEP) - m
		money.append([pid, d, "ALL WIN: " + o, "nobonus"])
		risk.append([pid, maxi(m, 0)])
		ctx.pm.get_player(pid).stats.risk_total = int(ctx.pm.get_player(pid).stats.get("risk_total", 0)) + maxi(m, 0)
		if o != "lose":
			mult.append([pid, 4.0 if o == "jackpot" else 2.0])
	steps.append(Challenge.step("allwin_spin", 6.5, {"title": "A ROLETA DO ALL WIN", "text": "Tudo ou nada...", "players": allin, "results": results, "fx": "suspense", "camera": "stage"}))
	steps.append(Challenge.step("allwin_result", 5.0, {"title": "RESULTADO!", "results": results, "money": money, "mult": mult, "risk": risk,
		"fx": "jackpot" if results.values().has("jackpot") else ("win" if results.values().has("double") else "lose"), "camera": "players"}))
	return steps


func private_info(pid: int) -> Dictionary:
	return {"prompt": "Seu patrimônio: %s  ·  Posição: %s" % [Fmt.money(money_of(pid)), Fmt.place(ctx.pm.position_of(pid))],
		"lines": ["JACKPOT x4 (10%)  ·  DOBROU x2 (35%)  ·  PERDEU: sobra 10% (55%)", "SAFE guarda 90%."]}
