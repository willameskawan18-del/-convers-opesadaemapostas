extends Challenge
## ALIANÇAS — duplas sorteadas. 1) Cada um manda um recado para o parceiro.
## 2) Em segredo: COOPERAR ou TRAIR.
## Os dois cooperam: +2.000 cada · Um trai: traidor +4.000, traído -1.500 · Os dois traem: -800 cada.
## Quem trai ganha a marca TRAIDOR (os outros vão lembrar nas votações!).

const MESSAGES := [["coop", "Vamos cooperar! Pode confiar."], ["promise", "Eu juro que coopero."], ["threat", "Se você trair, eu traio também."], ["silent", "..."], ["joke", "Confia no pai!"]]
const HOST := -1
var partner: Dictionary = {}   # pid -> pid (HOST = apresentador)
var messages: Dictionary = {}
var host_coop := true


func start() -> void:
	var ids := participants.duplicate()
	ids.shuffle()
	while ids.size() >= 2:
		var a: int = ids.pop_back()
		var b: int = ids.pop_back()
		partner[a] = b
		partner[b] = a
	if ids.size() == 1:
		partner[ids[0]] = HOST
		host_coop = ctx.rng.randf() < 0.65


func pname2(pid: int) -> String:
	return "o APRESENTADOR" if pid == HOST else pname(pid)


func stage_title() -> String:
	return "MANDE UM RECADO" if stage == 1 else "COOPERAR OU TRAIR?"


func time_limit() -> float:
	return 12.0 if stage == 1 else ctx.decision_time


func options(_pid: int) -> Array:
	if stage == 1:
		var out := []
		for m in MESSAGES:
			out.append({"id": m[0], "label": "“%s”" % m[1], "desc": "", "color": Pal.PURPLE})
		return out
	return [
		{"id": "betray", "label": "TRAIR", "desc": "Você +%s, parceiro %s" % [Fmt.money(ctx.scaled(4000)), Fmt.delta(-ctx.scaled(1500))], "color": Pal.RED},
		{"id": "coop", "label": "COOPERAR", "desc": "Se os dois cooperarem: +%s cada" % Fmt.money(ctx.scaled(2000)), "color": Pal.GREEN},
	]


func private_info(pid: int) -> Dictionary:
	var p: int = partner[pid]
	if stage == 1:
		return {"prompt": "Seu parceiro: " + pname2(p), "lines": ["Mande um recado antes da decisão secreta.", "Os dois cooperam: +%s cada · Os dois traem: %s cada" % [Fmt.money(ctx.scaled(2000)), Fmt.delta(-ctx.scaled(800))]], "layout": "list"}
	var msg := "“%s”" % _msg_text(str(messages.get(p, "silent"))) if p != HOST else "“Eu sou o apresentador. Confie em mim.”"
	var lines := ["Recado de %s: %s" % [pname2(p), msg]]
	if p != HOST and bool(ctx.pm.get_player(p).flags.get("traitor", false)):
		lines.append("ATENÇÃO: %s já traiu alguém nesta partida!" % pname(p))
	return {"prompt": "Sua dupla: " + pname2(p), "lines": lines}


func _msg_text(id: String) -> String:
	for m in MESSAGES:
		if m[0] == id:
			return m[1]
	return "..."


func bot_action(pid: int) -> Dictionary:
	if stage == 1:
		return {"choice": MESSAGES[ctx.rng.randi_range(0, MESSAGES.size() - 1)][0]}
	var p := ctx.pm.get_player(pid)
	var betray: float = {"trapaceiro": 0.6, "maluco": 0.45, "apostador": 0.4, "rico": 0.35}.get(p.character, 0.2)
	var other: int = partner[pid]
	if other != HOST and bool(ctx.pm.get_player(other).flags.get("traitor", false)):
		betray += 0.3
	return {"choice": "betray" if ctx.rng.randf() < betray else "coop"}


func default_action(_pid: int) -> Dictionary:
	return {"choice": "silent"} if stage == 1 else {"choice": "coop"}


func has_next_stage() -> bool:
	return stage == 1


func resolve() -> Array:
	if stage == 1:
		var rows := []
		for pid in participants:
			messages[pid] = str(actions[pid].choice)
			rows.append([pname(pid) + " → " + pname2(partner[pid]), "“%s”" % _msg_text(messages[pid]), pcolor(pid), Pal.TEXT])
		return [Challenge.list_step("RECADOS", rows, 3.2, {"fx": "reveal", "camera": "players"})]
	var steps := []
	var done := {}
	for pid in participants:
		if done.has(pid):
			continue
		var o: int = partner[pid]
		done[pid] = true
		done[o] = true
		var a_coop := str(actions[pid].choice) == "coop"
		var b_coop := host_coop if o == HOST else str(actions[o].choice) == "coop"
		var money := []
		var flags := []
		var title := ""
		var fx := "win"
		if a_coop and b_coop:
			title = "%s E %s COOPERARAM!" % [pname(pid), pname2(o)]
			money.append([pid, ctx.scaled(2000), "Aliança"])
			if o != HOST:
				money.append([o, ctx.scaled(2000), "Aliança"])
		elif not a_coop and not b_coop:
			title = "%s E %s SE TRAÍRAM!" % [pname(pid), pname2(o)]
			fx = "lose"
			money.append([pid, -ctx.scaled(800), "Traição dupla"])
			flags.append([pid, "traitor", true])
			if o != HOST:
				money.append([o, -ctx.scaled(800), "Traição dupla"])
				flags.append([o, "traitor", true])
		else:
			var traitor := pid if not a_coop else o
			var victim := o if not a_coop else pid
			title = "%s TRAIU %s!" % [pname2(traitor), pname2(victim)]
			fx = "lose"
			if traitor != HOST:
				money.append([traitor, ctx.scaled(4000), "Traição"])
				flags.append([traitor, "traitor", true])
				var t := ctx.pm.get_player(traitor)
				t.stats.steals = int(t.stats.get("steals", 0)) + 1
			if victim != HOST:
				money.append([victim, -ctx.scaled(1500), "Foi traído"])
		steps.append(Challenge.step("player_result", 2.8, {"title": title, "text": "", "pid": pid, "money": money, "flags": flags, "fx": fx, "camera": "player"}))
	return steps
