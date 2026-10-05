extends Challenge
## EVENTO ESPECIAL — entre rodadas. Bagunça o placar e cria viradas.
## A maioria é automática; a TROCA DE PATRIMÔNIO é uma decisão do último colocado.

const EVENTS := ["imposto", "bonus", "jackpot_publico", "inflacao", "crash", "reviravolta", "troca", "robin"]
var kind := ""
var chooser := -1   # quem decide na TROCA
var target := -1


func start() -> void:
	var pool := EVENTS.duplicate()
	if ctx.inflation > 1.0:
		pool.erase("inflacao")
	kind = pool[ctx.rng.randi_range(0, pool.size() - 1)]
	if kind == "troca":
		var last := ctx.pm.last()
		chooser = last.id if last else -1
		target = _above(chooser)
		if target < 0:
			kind = "bonus"


func _above(pid: int) -> int:
	var m := money_of(pid)
	var best := -1
	for o in participants:
		if o != pid and money_of(o) > m and (best < 0 or money_of(o) < money_of(best)):
			best = o
	return best


func deciders() -> Array[int]:
	var out: Array[int] = []
	if kind == "troca" and chooser >= 0:
		out.append(chooser)
	return out


func time_limit() -> float:
	return 15.0


func options(_pid: int) -> Array:
	return [
		{"id": "swap", "label": "TROCAR", "desc": "Fica com %s" % Fmt.money(money_of(target)), "color": Pal.GOLD},
		{"id": "keep", "label": "NÃO TROCAR", "desc": "Fica com %s" % Fmt.money(money_of(chooser)), "color": Pal.PANEL2},
	]


func private_info(_pid: int) -> Dictionary:
	return {"prompt": "TROCA DE PATRIMÔNIO: trocar com %s?" % pname(target), "lines": ["Você é o último colocado. Pode trocar todo o seu dinheiro com quem está logo acima."]}


func bot_action(_pid: int) -> Dictionary:
	return {"choice": "swap" if money_of(target) > money_of(chooser) else "keep"}


func default_action(_pid: int) -> Dictionary:
	return {"choice": "keep"}


func public_info() -> Dictionary:
	return {"event": kind, "title": title_for(kind), "text": text_for(kind)}


static func title_for(k: String) -> String:
	return {"imposto": "IMPOSTO!", "bonus": "BÔNUS PARA TODOS!", "jackpot_publico": "JACKPOT DA PLATEIA!", "inflacao": "INFLAÇÃO!",
		"crash": "CRASH NA BOLSA!", "reviravolta": "REVIRAVOLTA!", "troca": "TROCA DE PATRIMÔNIO!", "robin": "ROBIN HOOD!"}.get(k, "EVENTO!")


static func text_for(k: String) -> String:
	return {"imposto": "Todos perdem 10%.", "bonus": "Todo mundo ganha um bônus.", "jackpot_publico": "Um jogador sorteado ganha uma bolada!",
		"inflacao": "Os prêmios da PRÓXIMA rodada DOBRAM!", "crash": "Todos perdem 20% do que têm.", "reviravolta": "O último colocado ganha dinheiro e uma SAFE CARD.",
		"troca": "O último colocado pode trocar de patrimônio com quem está logo acima.", "robin": "O líder entrega 15% para o último colocado."}.get(k, "")


func resolve() -> Array:
	var steps := []
	steps.append(Challenge.step("event_intro", 3.0, {"title": title_for(kind), "text": text_for(kind), "fx": "jackpot", "camera": "screen"}))
	var leader := ctx.pm.leader()
	var last := ctx.pm.last()
	match kind:
		"imposto", "crash":
			var pct := 0.1 if kind == "imposto" else 0.2
			var money := []
			for pid in participants:
				var v := int(maxi(money_of(pid), 0) * pct)
				if v > 0:
					money.append([pid, -v, title_for(kind)])
			steps.append(Challenge.step("banner", 2.4, {"title": "TODOS PERDEM %d%%" % int(pct * 100), "money": money, "fx": "lose", "camera": "players"}))
		"bonus":
			var money := []
			for pid in participants:
				money.append([pid, ctx.scaled(1000), "Bônus"])
			steps.append(Challenge.step("banner", 2.2, {"title": "TODOS GANHAM " + Fmt.delta(ctx.scaled(1000)), "money": money, "fx": "win", "camera": "players"}))
		"jackpot_publico":
			var pid: int = participants[ctx.rng.randi_range(0, participants.size() - 1)]
			var v := ctx.scaled(5000)
			steps.append(Challenge.step("banner", 2.0, {"title": "A PLATEIA ESTÁ SORTEANDO...", "fx": "drumroll", "camera": "stage"}))
			steps.append(Challenge.step("player_result", 2.6, {"title": pname(pid) + " FOI SORTEADO!", "text": Fmt.delta(v), "pid": pid, "money": [[pid, v, "Jackpot da plateia"]], "fx": "jackpot", "camera": "player"}))
		"inflacao":
			steps.append(Challenge.step("banner", 2.4, {"title": "PRÓXIMA RODADA VALE O DOBRO!", "text": "Prepare-se...", "fx": "suspense", "camera": "screen", "inflation": 2.0}))
		"reviravolta":
			var v := ctx.scaled(1500)
			steps.append(Challenge.step("player_result", 2.6, {"title": last.name + " GANHA UMA CHANCE!", "text": Fmt.delta(v) + " + 1 SAFE CARD", "pid": last.id,
				"money": [[last.id, v, "Reviravolta"]], "items": [[last.id, "shield", 1]], "fx": "win", "camera": "player"}))
		"robin":
			var v := int(maxi(leader.money, 0) * 0.15) if leader.id != last.id else 0
			steps.append(Challenge.step("player_result", 2.8, {"title": "%s → %s" % [leader.name, last.name], "text": "Transferência de " + Fmt.money(v), "pid": last.id,
				"money": [[leader.id, -v, "Robin Hood", "pay"], [last.id, v, "Robin Hood", "nobonus"]], "fx": "win", "camera": "player"}))
		"troca":
			var swap := str(actions.get(chooser, {}).get("choice", "keep")) == "swap"
			if swap:
				var a := money_of(chooser)
				var b := money_of(target)
				steps.append(Challenge.step("player_result", 3.0, {"title": "%s TROCOU COM %s!" % [pname(chooser), pname(target)], "text": "%s ⇄ %s" % [Fmt.money(a), Fmt.money(b)], "pid": chooser,
					"money": [[chooser, b - a, "Troca de patrimônio", "nobonus"], [target, a - b, "Troca de patrimônio", "pay"]], "fx": "jackpot", "camera": "player"}))
			else:
				steps.append(Challenge.step("player_result", 2.2, {"title": pname(chooser) + " NÃO QUIS TROCAR!", "text": "A plateia não entendeu nada.", "pid": chooser, "fx": "reveal", "camera": "player"}))
	return steps
