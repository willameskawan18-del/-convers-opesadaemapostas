extends Challenge
## AS PORTAS — três portas: uma multiplica por 5, outra por 2 e outra zera a aposta.
## Todos escolhem ao mesmo tempo; as portas abrem da pior para a melhor.

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
	base_stake = ctx.scaled(400)
	for pid in participants:
		stakes[pid] = stake_for(pid, base_stake)


func options(_pid: int) -> Array:
	var cols := [Color("ff4d6d"), Color("4dabf7"), Color("ffd43b")]
	var out := []
	for i in 3:
		out.append({"id": LETTERS[i], "label": "PORTA " + LETTERS[i], "desc": "?", "color": cols[i]})
	return out


func public_info() -> Dictionary:
	return {"stake": base_stake, "doors": LETTERS, "prizes": ["x5", "x2", "x0"]}


func private_info(pid: int) -> Dictionary:
	var s: Dictionary = stakes.get(pid, {})
	return {"stake": s.get("amount", 0), "free": s.get("free", false)}


func bot_action(_pid: int) -> Dictionary:
	return {"choice": LETTERS[ctx.rng.randi_range(0, 2)]}


func default_action(_pid: int) -> Dictionary:
	return {"choice": LETTERS[ctx.rng.randi_range(0, 2)]}


func resolve() -> Array:
	var steps := []
	var picks := {}
	for pid in participants:
		picks[pid] = LETTERS.find(str(actions[pid].choice))
	steps.append(Challenge.step("door_picks", 2.6, {"title": "AS ESCOLHAS", "text": "Quem foi em qual porta?", "picks": picks, "camera": "doors", "fx": "reveal"}))
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
