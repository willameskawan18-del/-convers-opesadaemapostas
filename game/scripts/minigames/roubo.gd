extends Challenge
## ROUBO — 1) cada um escolhe um ALVO para roubar ou fica em DEFESA.
## 2) Quem tenta roubar precisa vencer o minijogo de PRECISÃO (BOM ou melhor).
## Sucesso: leva 15% do dinheiro do alvo. Falha (ou alvo em defesa): paga multa ao alvo.

var targets: Dictionary = {}   # pid -> alvo
var defending: Dictionary = {}


func stage_title() -> String:
	return "ESCOLHA O ALVO" if stage == 1 else "ACERTE O COFRE!"


func input_type() -> String:
	return "choice" if stage == 1 else "precision"


func deciders() -> Array[int]:
	if stage == 1:
		return participants
	var out: Array[int] = []
	for pid in targets:
		out.append(pid)
	return out


func time_limit() -> float:
	return ctx.decision_time if stage == 1 else 16.0


func public_info() -> Dictionary:
	return {"seed": ctx.round_index * 131, "seconds": 10.0, "zones": [[0.04, 5.0, "PERFEITO"], [0.12, 3.0, "ÓTIMO"], [0.25, 2.0, "BOM"]], "speed": 1.6, "no_stake": true}


func options(pid: int) -> Array:
	var out := [{"id": "defend", "label": "DEFESA", "desc": "Ninguém te rouba nesta rodada", "color": Pal.CYAN}]
	for o in player_options(pid):
		o.desc = "Tem " + str(o.desc)
		out.append(o)
	return out


func private_info(pid: int) -> Dictionary:
	if stage == 1:
		return {"prompt": "Quem você vai tentar roubar?", "lines": ["Sucesso: leva 15%% do alvo  ·  Falha: paga %s ao alvo" % Fmt.money(ctx.scaled(800))]}
	return {"prompt": "Pare o marcador no centro para abrir o cofre de %s!" % pname(int(targets[pid])), "lines": ["Precisa de BOM ou melhor."]}


func validate(pid: int, action: Dictionary) -> bool:
	if stage == 2:
		return action.has("offset")
	return super.validate(pid, action)


func bot_action(pid: int) -> Dictionary:
	if stage == 2:
		var sk := ctx.bot_skill(pid)
		return {"offset": absf(ctx.rng.randfn(0.0, 0.25 - sk * 0.15)), "stake": 0}
	var appetite := ctx.risk_appetite(pid)
	if ctx.pm.position_of(pid) == 1 and ctx.rng.randf() < 0.6:
		return {"choice": "defend"}
	if ctx.rng.randf() > appetite + 0.2:
		return {"choice": "defend"}
	var leader := ctx.pm.leader()
	if leader and leader.id != pid and ctx.rng.randf() < 0.6:
		return {"choice": str(leader.id)}
	var opts := player_options(pid)
	return {"choice": opts[ctx.rng.randi_range(0, opts.size() - 1)].id}


func default_action(_pid: int) -> Dictionary:
	return {"choice": "defend"} if stage == 1 else {"offset": 1.0, "stake": 0}


func has_next_stage() -> bool:
	return stage == 1 and not targets.is_empty()


func resolve() -> Array:
	if stage == 1:
		var rows := []
		for pid in participants:
			var c := str(actions[pid].choice)
			if c == "defend":
				defending[pid] = true
				rows.append([pname(pid), "EM DEFESA", pcolor(pid), Pal.CYAN])
			else:
				targets[pid] = int(c)
				rows.append([pname(pid), "quer roubar " + pname(int(c)), pcolor(pid), Pal.RED])
		return [Challenge.list_step("OS PLANOS", rows, 3.0, {"fx": "suspense", "camera": "players"})]
	var steps := []
	for pid in targets:
		var t: int = targets[pid]
		var off := float(actions[pid].get("offset", 1.0))
		var good := off <= 0.25
		var money := []
		var title := ""
		var fx := "lose"
		if defending.has(t):
			var fine := mini(ctx.scaled(800), maxi(money_of(pid), 0))
			money = [[pid, -fine, "Roubo: alvo em defesa", "pay"], [t, fine, "Defesa contra roubo"]]
			title = "%s ESTAVA EM DEFESA! %s pagou %s" % [pname(t), pname(pid), Fmt.money(fine)]
		elif good:
			var v := maxi(0, int(money_of(t) * 0.15))
			money = [[t, -v, "Foi roubado", "pay"], [pid, v, "Roubo", "nobonus"]]
			title = "%s ROUBOU %s DE %s!" % [pname(pid), Fmt.money(v), pname(t)]
			fx = "jackpot"
			var p := ctx.pm.get_player(pid)
			p.stats.steals = int(p.stats.get("steals", 0)) + 1
		else:
			var fine := mini(ctx.scaled(800), maxi(money_of(pid), 0))
			money = [[pid, -fine, "Roubo fracassado", "pay"], [t, fine, "Tentaram te roubar"]]
			title = "%s FRACASSOU! Paga %s para %s" % [pname(pid), Fmt.money(fine), pname(t)]
		steps.append(Challenge.step("player_result", 2.8, {"title": title, "text": "Precisão: %s" % SkillChallengeGrade.label(off), "pid": pid, "money": money, "fx": fx, "camera": "player",
			"stat": [[pid, "skill_sum", clampf(1.0 - off, 0.0, 1.0)], [pid, "skill_n", 1]]}))
	if steps.is_empty():
		steps.append(Challenge.step("banner", 2.0, {"title": "NINGUÉM TENTOU ROUBAR!", "fx": "reveal"}))
	return steps
