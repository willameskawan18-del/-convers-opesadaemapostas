extends Challenge
## LEILÃO — um prêmio misterioso com uma dica de faixa de valor. Lances secretos;
## o maior lance paga e leva. Pode ser uma fortuna... ou uma caixa vazia.

const ITEMS := ["MALETA MISTERIOSA", "CAIXA DOURADA", "COFRE DO APRESENTADOR", "ENVELOPE PRETO", "BAÚ DO PIRATA", "PRESENTE SUSPEITO"]
const VALUES := [[0.0, 14], [400.0, 14], [1200.0, 20], [2500.0, 22], [4500.0, 18], [8000.0, 10], [15000.0, 2]]

var item := ""
var value := 0
var hint_lo := 0
var hint_hi := 0


func start() -> void:
	item = ITEMS[ctx.rng.randi_range(0, ITEMS.size() - 1)]
	var total := 0
	for v in VALUES:
		total += int(v[1])
	var r := ctx.rng.randi_range(1, total)
	var base := 0.0
	for v in VALUES:
		r -= int(v[1])
		if r <= 0:
			base = float(v[0])
			break
	value = ctx.scaled(base) if base > 0 else 0
	var ref := maxf(float(value), float(ctx.scaled(1500)))
	hint_lo = int(roundf(value * ctx.rng.randf_range(0.0, 0.7) / 100.0) * 100.0)
	hint_hi = int(roundf(ref * ctx.rng.randf_range(1.3, 2.2) / 100.0) * 100.0)


func public_info() -> Dictionary:
	return {"item": item, "hint_lo": hint_lo, "hint_hi": hint_hi}


func private_info(pid: int) -> Dictionary:
	return {"max_bid": money_of(pid)}


func validate(pid: int, action: Dictionary) -> bool:
	var b := int(action.get("bid", -1))
	return b >= 0 and b <= money_of(pid)


func bot_action(pid: int) -> Dictionary:
	var mid := (hint_lo + hint_hi) / 2.0
	var appetite := ctx.risk_appetite(pid)
	var bid := mid * ctx.rng.randf_range(0.25, 0.75) * (0.5 + appetite)
	if ctx.rng.randf() < 0.15:
		bid = 0.0
	bid = minf(bid, money_of(pid) * (0.3 + appetite * 0.5))
	return {"bid": int(roundf(maxf(bid, 0.0) / 50.0) * 50.0)}


func default_action(_pid: int) -> Dictionary:
	return {"bid": 0}


func resolve() -> Array:
	var steps := []
	var bids := []
	for pid in participants:
		bids.append([pid, int(actions[pid].bid)])
	# Maior lance; empate: quem deu o lance primeiro
	bids.sort_custom(func(a, b):
		if a[1] != b[1]:
			return a[1] > b[1]
		return submit_order.find(a[0]) < submit_order.find(b[0]))
	steps.append(Challenge.step("bids", 3.2, {"title": "OS LANCES", "text": item, "bids": bids, "fx": "reveal", "camera": "screen"}))
	var winner := -1
	if bids.size() > 0 and int(bids[0][1]) > 0:
		winner = int(bids[0][0])
	if winner < 0:
		steps.append(Challenge.step("banner", 2.2, {"title": "NINGUÉM DEU LANCE!", "text": "O prêmio volta para o cofre...", "fx": "lose"}))
		steps.append(Challenge.step("prize", 2.6, {"title": "DENTRO TINHA: " + Fmt.money(value), "text": "Ninguém levou.", "prize": value, "fx": "reveal", "camera": "stage"}))
		return steps
	var paid := int(bids[0][1])
	var stolen := ""
	if bids.size() > 1 and int(bids[1][1]) > 0 and int(bids[0][1]) - int(bids[1][1]) <= maxi(100, paid / 10):
		stolen = "Por pouco! %s quase levou." % pname(int(bids[1][0]))
	steps.append(Challenge.step("player_result", 2.4, {"title": "ARREMATADO POR " + pname(winner), "text": "Pagou %s. %s" % [Fmt.money(paid), stolen], "pid": winner,
		"money": [[winner, -paid, "Lance no leilão"]], "risk": [[winner, paid]], "fx": "reveal", "camera": "player"}))
	steps.append(Challenge.step("banner", 1.8, {"title": "ABRINDO O " + item + "...", "fx": "drumroll", "camera": "stage"}))
	var fx := "lose" if value < paid else ("jackpot" if value >= paid * 2 else "win")
	var res := {"title": ("CAIXA VAZIA!" if value == 0 else "TINHA " + Fmt.money(value) + "!"), "text": "Lucro de %s: %s" % [pname(winner), Fmt.delta(value - paid)],
		"pid": winner, "prize": value, "money": [[winner, value, "Prêmio do leilão"]], "fx": fx, "camera": "player"}
	if paid > 0 and value > 0:
		res["mult"] = [[winner, float(value) / paid]]
	steps.append(Challenge.step("prize", 3.0, res))
	return steps
