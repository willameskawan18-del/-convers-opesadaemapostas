extends Challenge
## AS PORTAS — três portas: uma multiplica por 5, outra por 2 e outra zera a aposta.
## Antes de escolher, cada porta tem uma PISTA. Duas pistas são verdadeiras e UMA é mentira.
## Todos escolhem ao mesmo tempo; as portas abrem da pior para a melhor.

const CLUES := {
	5.0: ["Alguém ganhou muito dinheiro aqui.", "Dá para ouvir moedas caindo atrás desta porta.", "O apresentador sorriu quando passou por aqui."],
	2.0: ["Um prêmio modesto espera aqui.", "Nem rico, nem pobre: um prêmio honesto.", "Aqui ninguém fica milionário... mas ninguém chora."],
	0.0: ["Um jogador perdeu tudo aqui.", "Tem cheiro de queimado atrás desta porta.", "A plateia fica em silêncio quando olha para cá."],
}
var clues: Array = []
var liar := 0

const LETTERS := ["A", "B", "C"]
var mults: Array = [5.0, 2.0, 0.0]
var base_stake := 0
var stakes: Dictionary = {}   # pid -> {amount, free}


func start() -> void:
	mults = [5.0, 2.0, 0.0]
	for i in range(mults.size() - 1, 0, -1):
		var j := ctx.rng.randi_range(0, i)
		var t: float = mults[i]
		mults[i] = mults[j]
		mults[j] = t
	base_stake = ctx.scaled(800)
	liar = ctx.rng.randi_range(0, 2)
	clues.clear()
	for i in 3:
		var m: float = mults[i]
		if i == liar:
			var others := [5.0, 2.0, 0.0].filter(func(v): return not is_equal_approx(v, m))
			m = others[ctx.rng.randi_range(0, others.size() - 1)]
		var pool: Array = CLUES[m]
		clues.append(pool[ctx.rng.randi_range(0, pool.size() - 1)])
	for pid in participants:
		stakes[pid] = stake_for(pid, base_stake)


func options(_pid: int) -> Array:
	var cols := [Color("ff4d6d"), Color("4dabf7"), Color("ffd43b")]
	var out := []
	for i in 3:
		out.append({"id": LETTERS[i], "label": "PORTA " + LETTERS[i], "desc": "“%s”" % clues[i], "color": cols[i]})
	return out


func public_info() -> Dictionary:
	return {"stake": base_stake, "doors": LETTERS, "prizes": ["x5", "x2", "x0"], "clues": clues}


func private_info(pid: int) -> Dictionary:
	var s: Dictionary = stakes.get(pid, {})
	return {"stake": s.get("amount", 0), "free": s.get("free", false), "layout": "doors",
		"prompt": "Duas pistas dizem a verdade. UMA é mentira.",
		"lines": ["Sua aposta: %s%s" % [Fmt.money(int(s.get("amount", 0))), "  (ficha de resgate: não perde nada!)" if s.get("free", false) else ""], "Prêmios: x5 · x2 · x0"]}


func bot_action(pid: int) -> Dictionary:
	# bots inteligentes confiam nas pistas "boas"; outros chutam
	if ctx.rng.randf() < ctx.bot_skill(pid, "knowledge"):
		var good := []
		for i in 3:
			if CLUES[5.0].has(clues[i]):
				good.append(i)
		if not good.is_empty():
			return {"choice": LETTERS[good[ctx.rng.randi_range(0, good.size() - 1)]]}
	return {"choice": LETTERS[ctx.rng.randi_range(0, 2)]}


func default_action(_pid: int) -> Dictionary:
	return {"choice": LETTERS[ctx.rng.randi_range(0, 2)]}


func resolve() -> Array:
	var steps := []
	var picks := {}
	for pid in participants:
		picks[pid] = LETTERS.find(str(actions[pid].choice))
	steps.append(Challenge.step("door_picks", 2.6, {"title": "AS ESCOLHAS", "text": "Quem foi em qual porta?", "picks": picks, "camera": "doors", "fx": "reveal"}))
	steps.append(Challenge.step("banner", 2.4, {"title": "A PISTA MENTIROSA ERA...", "text": "PORTA %s: “%s”" % [LETTERS[liar], clues[liar]], "fx": "drumroll", "camera": "doors"}))
	var order := [0, 1, 2]
	order.sort_custom(func(a, b): return float(mults[a]) < float(mults[b]))
	for idx in order:
		var m: float = mults[idx]
		var money := []
		var mult := []
		var risk := []
		var names := []
		for pid in participants:
			if picks[pid] != idx:
				continue
			var s: Dictionary = stakes[pid]
			var amt := int(s.amount)
			var d := 0
			if bool(s.free):
				d = int(amt * m)
			else:
				d = int(roundf(amt * (m - 1.0)))
				risk.append([pid, amt])
			money.append([pid, d, "Porta %s (%s)" % [LETTERS[idx], Fmt.mult(m)]])
			if m > 0:
				mult.append([pid, m])
			names.append(pname(pid))
		var title := "PORTA %s: %s" % [LETTERS[idx], Fmt.mult(m)]
		var text := ("Ninguém escolheu esta porta." if names.is_empty() else ", ".join(names))
		var fx := "lose" if m <= 0.0 else ("jackpot" if m >= 5.0 else "win")
		if names.is_empty():
			fx = "reveal"
		steps.append(Challenge.step("door_open", 2.4 if m < 5.0 else 3.2, {"title": title, "text": text, "door": idx, "door_mult": m,
			"money": money, "mult": mult, "risk": risk, "fx": fx, "camera": "doors"}))
	return steps
