extends SkillChallenge
## PRECISÃO — escolha quanto apostar e pare o marcador na zona ideal.
## PERFEITO x5 · ÓTIMO x3 · BOM x2 · ERRO x0 (perde a aposta).

const STAKES := [400, 1000, 2000]
const ZONES := [[0.04, 5.0, "PERFEITO"], [0.12, 3.0, "ÓTIMO"], [0.25, 2.0, "BOM"]]


func game_seconds() -> float:
	return 10.0


func private_info(pid: int) -> Dictionary:
	var st := []
	for v in STAKES:
		st.append(stake_for(pid, ctx.scaled(v)).amount)
	return {"prompt": "Escolha a aposta e pare o marcador no CENTRO!", "stakes": st, "free": money_of(pid) <= 0,
		"lines": ["PERFEITO x5  ·  ÓTIMO x3  ·  BOM x2  ·  ERRO x0"]}


func public_info() -> Dictionary:
	var d := super.public_info()
	d["zones"] = ZONES
	d["speed"] = 1.2 + 0.08 * ctx.round_index
	return d


func validate(_pid: int, action: Dictionary) -> bool:
	return action.has("offset") and int(action.get("stake", -1)) in [0, 1, 2]


func default_action(_pid: int) -> Dictionary:
	return {"offset": 1.0, "stake": 0, "score": 0.0, "miss": true}


func bot_action(pid: int) -> Dictionary:
	var sk := ctx.bot_skill(pid)
	var off := absf(ctx.rng.randfn(0.0, 0.22 - sk * 0.15))
	var appetite := ctx.risk_appetite(pid)
	var stake := 2 if appetite > 0.7 else (1 if appetite > 0.4 else 0)
	return {"offset": off, "stake": stake, "score": 1.0 - clampf(off, 0.0, 1.0)}


static func grade(offset: float) -> Array:
	for z in ZONES:
		if offset <= float(z[0]):
			return [float(z[1]), str(z[2])]
	return [0.0, "ERROU"]


func resolve() -> Array:
	var rows := []
	var money := []
	var mult := []
	var risk := []
	for pid in participants:
		var a: Dictionary = actions[pid]
		var g := grade(float(a.offset))
		var st := stake_for(pid, ctx.scaled(STAKES[int(a.stake)]))
		var amt := int(st.amount)
		var d := int(amt * float(g[0])) if bool(st.free) else int(amt * (float(g[0]) - 1.0))
		money.append([pid, d, "Precisão " + str(g[1])])
		if not bool(st.free):
			risk.append([pid, amt])
		if float(g[0]) > 0:
			mult.append([pid, float(g[0])])
		rows.append([pname(pid) + "  (aposta " + Fmt.money(amt) + ")", "%s %s  %s" % [g[1], Fmt.mult(float(g[0])), Fmt.delta(d)], pcolor(pid), Pal.GOLD if float(g[0]) >= 5 else (Pal.GREEN if float(g[0]) > 0 else Pal.RED)])
	var best := ranked()
	var stat := skill_stats(participants)
	stat.append([best[0], "skill_wins", 1])
	return [Challenge.list_step("PRECISÃO", rows, 3.6, {"money": money, "mult": mult, "risk": risk, "stat": stat, "fx": "reveal"})]
