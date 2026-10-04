extends Challenge
## ALL WIN — a decisão final. SAFE guarda 90% do patrimônio.
## ALL WIN coloca tudo na roleta: JACKPOT x4, DOBROU x2 ou PERDEU (sobra 10%).
## Quem está zerado ainda pode jogar ALL WIN com uma ficha de $1.000.

const SAFE_KEEP := 0.9
const LOSE_KEEP := 0.1
const OUTCOMES := [["jackpot", 4.0, 10], ["double", 2.0, 35], ["lose", 0.0, 55]]
const ZERO_CHIP := 1000

var outcomes: Dictionary = {}   # pid -> "jackpot" | "double" | "lose"


func options(pid: int) -> Array:
	var m := money_of(pid)
	var base := maxi(m, ZERO_CHIP)
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
			safe_money.append([pid, int(m * SAFE_KEEP) - m, "SAFE final"])
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
		var base := maxi(m, ZERO_CHIP)
		var final_v := 0
		match o:
			"jackpot": final_v = base * 4
			"double": final_v = base * 2
			_: final_v = int(m * LOSE_KEEP)
		money.append([pid, final_v - m, "ALL WIN: " + o])
		risk.append([pid, m])
		if o != "lose":
			mult.append([pid, 4.0 if o == "jackpot" else 2.0])
	steps.append(Challenge.step("allwin_spin", 6.5, {"title": "A ROLETA DO ALL WIN", "text": "Tudo ou nada...", "players": allin, "results": results, "fx": "suspense", "camera": "stage"}))
	steps.append(Challenge.step("allwin_result", 5.0, {"title": "RESULTADO!", "results": results, "money": money, "mult": mult, "risk": risk,
		"fx": "jackpot" if results.values().has("jackpot") else ("win" if results.values().has("double") else "lose"), "camera": "players"}))
	return steps
