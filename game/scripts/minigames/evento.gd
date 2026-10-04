extends Challenge
## EVENTO ESPECIAL — acontece entre rodadas, sem decisão. Bagunça o placar e cria viradas.

const EVENTS := ["chuva", "imposto", "robin", "resgate", "sorteio", "jackpot_publico"]
var kind := ""


func start() -> void:
	kind = EVENTS[ctx.rng.randi_range(0, EVENTS.size() - 1)]


func public_info() -> Dictionary:
	return {"event": kind, "title": title_for(kind), "text": text_for(kind)}


static func title_for(k: String) -> String:
	return {"chuva": "CHUVA DE DINHEIRO!", "imposto": "IMPOSTO DO LÍDER!", "robin": "ROBIN HOOD!", "resgate": "RESGATE DO ÚLTIMO!",
		"sorteio": "SORTEIO RELÂMPAGO!", "jackpot_publico": "JACKPOT DA PLATEIA!"}.get(k, "EVENTO!")


static func text_for(k: String) -> String:
	return {"chuva": "Todo mundo ganha dinheiro do céu.", "imposto": "Quem está na frente paga 25% de imposto.",
		"robin": "O líder entrega 20% para o último colocado.", "resgate": "O último colocado recebe uma ajuda generosa.",
		"sorteio": "Um jogador aleatório dobra o dinheiro (até um limite).", "jackpot_publico": "A plateia escolhe alguém para ganhar um bônus!"}.get(k, "")


func resolve() -> Array:
	var steps := []
	steps.append(Challenge.step("event_intro", 3.0, {"title": title_for(kind), "text": text_for(kind), "fx": "jackpot", "camera": "screen"}))
	var leader := ctx.pm.leader()
	var last := ctx.pm.last()
	match kind:
		"chuva":
			var money := []
			for pid in participants:
				money.append([pid, ctx.scaled(500), "Chuva de dinheiro"])
			steps.append(Challenge.step("banner", 2.2, {"title": "TODOS GANHAM " + Fmt.delta(ctx.scaled(500)), "money": money, "fx": "win", "camera": "players"}))
		"imposto":
			var v := int(leader.money * 0.25)
			steps.append(Challenge.step("player_result", 2.6, {"title": leader.name + " PAGA O IMPOSTO", "text": Fmt.delta(-v), "pid": leader.id,
				"money": [[leader.id, -v, "Imposto do líder"]], "fx": "lose", "camera": "player"}))
		"robin":
			var v := int(leader.money * 0.2)
			if leader.id == last.id:
				v = 0
			steps.append(Challenge.step("player_result", 2.8, {"title": "%s → %s" % [leader.name, last.name], "text": "Transferência de " + Fmt.money(v), "pid": last.id,
				"money": [[leader.id, -v, "Robin Hood"], [last.id, v, "Robin Hood"]], "fx": "win", "camera": "player"}))
		"resgate":
			var v := ctx.scaled(1500)
			steps.append(Challenge.step("player_result", 2.6, {"title": last.name + " FOI RESGATADO!", "text": Fmt.delta(v), "pid": last.id,
				"money": [[last.id, v, "Resgate"]], "fx": "win", "camera": "player"}))
		"sorteio":
			var pid: int = participants[ctx.rng.randi_range(0, participants.size() - 1)]
			var v := clampi(money_of(pid), ctx.scaled(500), ctx.scaled(4000))
			steps.append(Challenge.step("banner", 2.0, {"title": "SORTEANDO...", "fx": "drumroll", "camera": "players"}))
			steps.append(Challenge.step("player_result", 2.6, {"title": pname(pid) + " DOBROU!", "text": Fmt.delta(v), "pid": pid,
				"money": [[pid, v, "Sorteio relâmpago"]], "mult": [[pid, 2.0]], "fx": "jackpot", "camera": "player"}))
		_:
			var pid: int = participants[ctx.rng.randi_range(0, participants.size() - 1)]
			var v := ctx.scaled(2000)
			steps.append(Challenge.step("banner", 2.0, {"title": "A PLATEIA ESTÁ VOTANDO...", "fx": "drumroll", "camera": "stage"}))
			steps.append(Challenge.step("player_result", 2.6, {"title": "A PLATEIA ESCOLHEU " + pname(pid) + "!", "text": Fmt.delta(v), "pid": pid,
				"money": [[pid, v, "Jackpot da plateia"]], "fx": "jackpot", "camera": "player"}))
	return steps
