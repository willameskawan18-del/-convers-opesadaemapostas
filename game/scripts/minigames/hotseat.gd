extends Challenge
## HOT SEAT — um jogador vai para a cadeira quente e responde em segredo uma pergunta
## sobre ele mesmo. Os outros tentam adivinhar. Acertou +1.000, errou -500.
## O jogador da cadeira ganha +400 por quem acertou (ou +1.500 se ninguém acertar).

var seat := -1
var question: Dictionary = {}


func start() -> void:
	seat = participants[ctx.rng.randi_range(0, participants.size() - 1)]
	var prefs: Array = GameData.load_json("questions").get("preferences", [])
	question = prefs[ctx.rng.randi_range(0, prefs.size() - 1)]


func public_info() -> Dictionary:
	return {"seat": seat, "seat_name": pname(seat), "question": question.q}


func options(_pid: int) -> Array:
	var out := []
	for i in question.a.size():
		out.append({"id": str(i), "label": str(question.a[i]), "desc": "", "color": [Pal.PINK, Pal.CYAN, Pal.GOLD][i % 3]})
	return out


func private_info(pid: int) -> Dictionary:
	if pid == seat:
		return {"prompt": "VOCÊ ESTÁ NA CADEIRA QUENTE!", "lines": ["Responda com sinceridade: " + str(question.q), "Você ganha %s por cada pessoa que acertar." % Fmt.money(ctx.scaled(400))]}
	return {"prompt": "O que %s escolheria?" % pname(seat), "lines": [str(question.q), "Acertou: %s  ·  Errou: %s" % [Fmt.delta(ctx.scaled(1000)), Fmt.delta(-ctx.scaled(500))]]}


func bot_action(_pid: int) -> Dictionary:
	return {"choice": str(ctx.rng.randi_range(0, question.a.size() - 1))}


func default_action(_pid: int) -> Dictionary:
	return {"choice": "0"}


func resolve() -> Array:
	var answer := int(actions[seat].choice)
	var money := []
	var rows := []
	var right := 0
	for pid in participants:
		if pid == seat:
			continue
		var ok := int(actions[pid].choice) == answer
		if ok:
			right += 1
		var d := ctx.scaled(1000) if ok else -ctx.scaled(500)
		money.append([pid, d, "Hot seat"])
		rows.append([pname(pid) + ": " + str(question.a[int(actions[pid].choice)]), Fmt.delta(d), pcolor(pid), Pal.GREEN if ok else Pal.RED])
	var seat_gain := right * ctx.scaled(400) if right > 0 else ctx.scaled(1500)
	money.append([seat, seat_gain, "Hot seat (cadeira)"])
	rows.append([pname(seat) + " (CADEIRA)", Fmt.delta(seat_gain) + (" — imprevisível!" if right == 0 else ""), pcolor(seat), Pal.GOLD])
	return [
		Challenge.step("player_result", 2.6, {"title": "%s ESCOLHEU: %s" % [pname(seat), str(question.a[answer]).to_upper()], "text": str(question.q), "pid": seat, "fx": "reveal", "camera": "player"}),
		Challenge.list_step("QUEM CONHECE %s?" % pname(seat), rows, 3.2, {"money": money}),
	]
