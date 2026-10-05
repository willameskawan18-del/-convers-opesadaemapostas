extends Challenge
## DERRUBE O REI — o líder (KING) defende a coroa. Todos jogam PRECISÃO.
## Cada desafiante que for MAIS preciso que o rei leva 6% do dinheiro dele.
## Se o rei vencer todo mundo, ganha +3.000 do show.

var king := -1


func start() -> void:
	var l := ctx.pm.leader()
	king = l.id if l else participants[0]


func input_type() -> String:
	return "precision"


func time_limit() -> float:
	return 16.0


func public_info() -> Dictionary:
	return {"seed": ctx.round_index * 977, "seconds": 10.0, "zones": [[0.04, 5.0, "PERFEITO"], [0.12, 3.0, "ÓTIMO"], [0.25, 2.0, "BOM"]], "speed": 1.7, "no_stake": true, "king": king}


func private_info(pid: int) -> Dictionary:
	if pid == king:
		return {"prompt": "VOCÊ É O KING! Defenda a coroa.", "lines": ["Cada desafiante mais preciso que você leva 6% do seu dinheiro."]}
	return {"prompt": "DERRUBE %s!" % pname(king), "lines": ["Seja mais preciso que o rei e leve 6%% dele (%s)." % Fmt.money(int(maxi(money_of(king), 0) * 0.06))]}


func validate(_pid: int, action: Dictionary) -> bool:
	return action.has("offset")


func bot_action(pid: int) -> Dictionary:
	var sk := ctx.bot_skill(pid)
	return {"offset": absf(ctx.rng.randfn(0.0, 0.24 - sk * 0.15)), "stake": 0}


func default_action(_pid: int) -> Dictionary:
	return {"offset": 1.0, "stake": 0}


func resolve() -> Array:
	var k_off := float(actions[king].offset)
	var rows := [[pname(king) + " (KING)", "%.0f%% do centro — %s" % [k_off * 100.0, SkillChallengeGrade.label(k_off)], pcolor(king), Pal.GOLD]]
	var money := []
	var winners := []
	var stat := []
	for pid in participants:
		var off := float(actions[pid].offset)
		stat.append([pid, "skill_sum", clampf(1.0 - off, 0.0, 1.0)])
		stat.append([pid, "skill_n", 1])
		if pid == king:
			continue
		var beat := off < k_off
		rows.append([pname(pid), "%.0f%% — %s" % [off * 100.0, "DERRUBOU!" if beat else "não deu"], pcolor(pid), Pal.GREEN if beat else Pal.RED])
		if beat:
			winners.append(pid)
	var steps := [Challenge.list_step("DUELO PELA COROA", rows, 3.4, {"fx": "reveal", "stat": stat, "camera": "players"})]
	if winners.is_empty():
		steps.append(Challenge.step("player_result", 2.6, {"title": "O REI CONTINUA NO TRONO!", "text": pname(king) + " " + Fmt.delta(ctx.scaled(3000)), "pid": king,
			"money": [[king, ctx.scaled(3000), "Defendeu a coroa"]], "fx": "jackpot", "camera": "player"}))
		return steps
	var each := maxi(0, int(money_of(king) * 0.06))
	for pid in winners:
		money.append([king, -each, "Coroa atacada", "pay"])
		money.append([pid, each, "Derrubou o rei", "nobonus"])
	steps.append(Challenge.step("player_result", 3.0, {"title": "O REI FOI ATACADO!", "text": "%d desafiante(s) levaram %s cada" % [winners.size(), Fmt.money(each)], "pid": king, "money": money, "fx": "lose", "camera": "player"}))
	return steps
