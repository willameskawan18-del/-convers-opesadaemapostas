class_name BettingSystem
extends RefCounted
## Eventos esportivos fictícios, odds, apostas do jogador (como apostador) e apostas dos
## clientes na banca do jogador (o "livro"). Os resultados são sorteados com a
## probabilidade interna real de cada evento — nada é conectado a apostas reais.
##
## Estrutura preparada para mercados extras: cada aposta guarda "market" (hoje só "simples").

var sim: Simulation
var events: Array = []
var next_event_id := 1
var next_bet_id := 1
var player_bets: Array = []
var book_bets: Array = []
var player_history: Array = []
var news: Array = []
var ratings: Dictionary = {}
var scheduled_until_day := 0
var book_today := {"stakes": 0.0, "payouts": 0.0, "bets": 0}
var biggest_payout_today := 0.0


func _init(s) -> void:
	sim = s


func reset() -> void:
	events = []
	player_bets = []
	book_bets = []
	player_history = []
	news = []
	next_event_id = 1
	next_bet_id = 1
	scheduled_until_day = 0
	ratings = {}
	for sp in GameData.list("sports", "sports"):
		for p in sp.participants:
			ratings[str(p)] = sim.rng.randf_range(60.0, 95.0)
	start_day()


func start_day() -> void:
	book_today = {"stakes": 0.0, "payouts": 0.0, "bets": 0}
	biggest_payout_today = 0.0
	ensure_schedule()


func ensure_schedule() -> void:
	var today: int = sim.time.day
	for d in range(today, today + 2):
		if d > scheduled_until_day:
			_generate_day(d)
			scheduled_until_day = d
	# Remove eventos antigos já encerrados
	var cutoff := (today - 2) * 1440
	events = events.filter(func(e): return not (e.status == "finished" and int(e.start) < cutoff))
	if news.size() > 30:
		news = news.slice(news.size() - 30)


func _generate_day(d: int) -> void:
	var cfg: Dictionary = GameData.load_json("sports")
	var range_n: Array = cfg.get("events_per_day", [9, 13])
	var count := sim.rng.randi_range(int(range_n[0]), int(range_n[1]))
	var first := int(cfg.get("first_start_minute", 600))
	var last := int(cfg.get("last_start_minute", 1350))
	var sports: Array = cfg.sports
	var created: Array = []
	for i in count:
		var sp: Dictionary = _weighted_sport(sports)
		var start_min := int(round(sim.rng.randf_range(first, last) / 15.0)) * 15
		created.append(_create_event(sp, d * 1440 + start_min, d, cfg))
	created.sort_custom(func(a, b): return int(a.start) < int(b.start))
	events.append_array(created)


func _weighted_sport(sports: Array) -> Dictionary:
	var total := 0.0
	for s in sports:
		total += float(s.weight)
	var r := sim.rng.randf() * total
	for s in sports:
		r -= float(s.weight)
		if r <= 0.0:
			return s
	return sports[0]


func _pick_distinct(pool: Array, n: int) -> Array:
	var copy := pool.duplicate()
	var out: Array = []
	for i in mini(n, copy.size()):
		var idx := sim.rng.randi_range(0, copy.size() - 1)
		out.append(copy[idx])
		copy.remove_at(idx)
	return out


func _create_event(sp: Dictionary, start_abs: int, d: int, cfg: Dictionary) -> Dictionary:
	var participants: Array = []
	var outcomes: Array = []
	var p: Array = []
	match str(sp.type):
		"1x2":
			participants = _pick_distinct(sp.participants, 2)
			var diff := (_rating(participants[0]) + 4.0 - _rating(participants[1])) / 12.0
			var ph := 1.0 / (1.0 + exp(-diff))
			var draw := clampf(0.27 - 0.08 * absf(diff), 0.14, 0.3)
			p = [(1.0 - draw) * ph, draw, (1.0 - draw) * (1.0 - ph)]
			outcomes = [participants[0], "Empate", participants[1]]
		"h2h":
			participants = _pick_distinct(sp.participants, 2)
			var pa := 1.0 / (1.0 + exp(-(_rating(participants[0]) - _rating(participants[1])) / 10.0))
			p = [pa, 1.0 - pa]
			outcomes = participants.duplicate()
		_:
			participants = _pick_distinct(sp.participants, sim.rng.randi_range(4, 6))
			var tot := 0.0
			for part in participants:
				var w := exp(_rating(part) / 8.0)
				p.append(w)
				tot += w
			for i in p.size():
				p[i] = p[i] / tot
			outcomes = participants.duplicate()
	var name := " x ".join(participants) if participants.size() == 2 else "Grande Prêmio — %d pilotos" % participants.size()
	var ev := {
		"id": "E%d" % next_event_id, "sport": sp.id, "sport_name": sp.name, "name": name,
		"participants": participants, "outcomes": outcomes,
		"true_p": p.duplicate(), "market_p": p.duplicate(), "noise": [],
		"start": start_abs, "duration": int(sp.duration), "status": "scheduled",
		"result": -1, "hype": 1.0, "suspended": [], "day": d, "news": "",
	}
	next_event_id += 1
	for i in outcomes.size():
		ev.noise.append(sim.rng.randf_range(-1.0, 1.0))
		ev.suspended.append(false)
	if sim.rng.randf() < float(cfg.get("hype_chance", 0.12)):
		ev.hype = sim.rng.randf_range(1.5, 2.2)
		ev.name = ("CLÁSSICO: " if sp.type == "1x2" else "FINAL: ") + ev.name
	if sim.rng.randf() < float(cfg.get("news_chance", 0.35)):
		_apply_news(ev, cfg)
	return ev


func _rating(part) -> float:
	return float(ratings.get(str(part), 75.0))


## Uma notícia altera a probabilidade real; o mercado reage só parcialmente.
## Quem lê as notícias encontra apostas de valor.
func _apply_news(ev: Dictionary, cfg: Dictionary) -> void:
	var cand: Array = []
	for i in ev.outcomes.size():
		if str(ev.outcomes[i]) != "Empate":
			cand.append(i)
	var idx: int = cand[sim.rng.randi_range(0, cand.size() - 1)]
	var up := sim.rng.randf() < 0.5
	var shift := sim.rng.randf_range(0.06, 0.12) * (1.0 if up else -1.0)
	var before: Array = ev.true_p.duplicate()
	var tp: Array = ev.true_p
	tp[idx] = clampf(float(tp[idx]) + shift, 0.03, 0.92)
	_normalize(tp)
	var mp: Array = []
	for i in tp.size():
		mp.append(lerpf(float(before[i]), float(tp[i]), 0.35))
	_normalize(mp)
	ev.market_p = mp
	var templates: Array = cfg.get("news_up" if up else "news_down", ["{p}"])
	var text := str(templates[sim.rng.randi_range(0, templates.size() - 1)]).replace("{p}", str(ev.outcomes[idx]))
	ev.news = text
	news.append({"day": ev.day, "event_id": ev.id, "text": text, "sport": ev.sport_name, "event": ev.name})


static func _normalize(arr: Array) -> void:
	var t := 0.0
	for v in arr:
		t += float(v)
	if t <= 0.0:
		return
	for i in arr.size():
		arr[i] = float(arr[i]) / t


func get_event(id: String) -> Dictionary:
	for e in events:
		if e.id == id:
			return e
	return {}


## Eventos abertos para apostas (começam em pelo menos `lead` minutos).
func open_events(lead: int = 5) -> Array:
	var now: int = sim.time.abs_minute()
	return events.filter(func(e): return e.status == "scheduled" and int(e.start) > now + lead)


func upcoming_events(limit: int = 30) -> Array:
	var out := events.filter(func(e): return e.status != "finished")
	return out.slice(0, limit)


func finished_events(limit: int = 20) -> Array:
	var out := events.filter(func(e): return e.status == "finished")
	out.reverse()
	return out.slice(0, limit)


# --- Odds ---------------------------------------------------------------------

func market_odds(ev: Dictionary, i: int, margin: float = -1.0) -> float:
	if margin < 0.0:
		margin = sim.market_margin()
	return maxf(1.02, snappedf(1.0 / (float(ev.market_p[i]) * (1.0 + margin)), 0.01))


## Odds da banca do jogador: usa a margem configurada e a estimativa de probabilidade
## (que tem erro; analistas e sistemas reduzem esse erro).
func shop_odds(ev: Dictionary, i: int) -> float:
	var err: float = sim.business.pricing_error() if sim.has_business() else 0.0
	var est: Array = []
	for k in ev.market_p.size():
		est.append(maxf(0.01, float(ev.market_p[k]) * (1.0 + float(ev.noise[k]) * err)))
	_normalize(est)
	var m: float = sim.business.margin if sim.has_business() else sim.market_margin()
	return maxf(1.02, snappedf(1.0 / (float(est[i]) * (1.0 + m)), 0.01))


# --- Apostas do jogador -----------------------------------------------------------

func place_player_bet(event_id: String, outcome: int, stake: float) -> bool:
	var ev := get_event(event_id)
	if ev.is_empty() or ev.status != "scheduled" or int(ev.start) <= sim.time.abs_minute():
		sim.notify("Apostas encerradas para este evento.", "error")
		return false
	stake = floorf(stake)
	var mn := float(GameData.balance("player_bet_min", 5))
	var mx := float(GameData.balance("player_bet_max", 5000))
	if stake < mn or stake > mx:
		sim.notify("Aposta deve ficar entre %s e %s." % [Fmt.money(mn), Fmt.money(mx)], "error")
		return false
	if outcome < 0 or outcome >= ev.outcomes.size():
		return false
	if not sim.economy.spend(stake, EconomySystem.PERSONAL_BET):
		return false
	var odds := market_odds(ev, outcome)
	player_bets.append({"id": next_bet_id, "event_id": event_id, "outcome": outcome, "stake": stake,
		"odds": odds, "market": "simples", "event_name": ev.name, "pick": ev.outcomes[outcome]})
	next_bet_id += 1
	sim.add_stat("bets_placed")
	sim.progression.add_xp(GameData.xp_value("bet"))
	sim.notify("Aposta registrada: %s em %s @ %s" % [Fmt.money(stake), ev.outcomes[outcome], Fmt.odds(odds)], "bet")
	return true


# --- Livro da banca (apostas dos clientes) --------------------------------------------

func place_book_bet(customer_id: String, ev: Dictionary, outcome: int, stake: float) -> void:
	var odds := shop_odds(ev, outcome)
	book_bets.append({"id": next_bet_id, "event_id": ev.id, "outcome": outcome, "stake": stake,
		"odds": odds, "customer": customer_id, "market": "simples"})
	next_bet_id += 1
	sim.economy.earn(stake, EconomySystem.STAKES)
	book_today.stakes += stake
	book_today.bets += 1


func exposure(ev: Dictionary) -> Dictionary:
	var payouts: Array = []
	var counts: Array = []
	for i in ev.outcomes.size():
		payouts.append(0.0)
		counts.append(0)
	var stakes := 0.0
	var n := 0
	for b in book_bets:
		if b.event_id != ev.id:
			continue
		var o := int(b.outcome)
		payouts[o] += float(b.stake) * float(b.odds)
		counts[o] += 1
		stakes += float(b.stake)
		n += 1
	var worst := 0.0
	var worst_i := -1
	for i in payouts.size():
		if payouts[i] > worst:
			worst = payouts[i]
			worst_i = i
	return {"stakes": stakes, "payouts": payouts, "counts": counts, "bets": n,
		"worst_payout": worst, "worst_outcome": worst_i, "worst_net": worst - stakes}


## Pior cenário somado de todos os eventos abertos com apostas na banca.
func total_exposure() -> Dictionary:
	var stakes := 0.0
	var worst_payout := 0.0
	var worst_net := 0.0
	var n := 0
	for ev in events:
		if ev.status == "finished":
			continue
		var ex := exposure(ev)
		if ex.bets == 0:
			continue
		stakes += ex.stakes
		worst_payout += ex.worst_payout
		worst_net += maxf(0.0, ex.worst_net)
		n += ex.bets
	return {"stakes": stakes, "worst_payout": worst_payout, "worst_net": worst_net, "bets": n}


func risk_level(worst_net: float = -1.0) -> String:
	if worst_net < 0.0:
		worst_net = total_exposure().worst_net
	var ratio := worst_net / maxf(sim.economy.cash, 200.0)
	if ratio < 0.15: return "BAIXO"
	if ratio < 0.4: return "MÉDIO"
	if ratio < 0.8: return "ALTO"
	return "CRÍTICO"


## Balanceamento automático (exige analista): suspende o resultado que concentra risco.
func auto_balance() -> void:
	var cash: float = maxf(sim.economy.cash, 200.0)
	for ev in events:
		if ev.status != "scheduled":
			continue
		var ex := exposure(ev)
		for i in ev.outcomes.size():
			var net: float = float(ex.payouts[i]) - ex.stakes
			ev.suspended[i] = net > cash * 0.25 and ex.payouts[i] > ex.stakes * 1.8


# --- Fluxo --------------------------------------------------------------------

func step(now: int) -> void:
	for ev in events:
		if ev.status == "scheduled" and now >= int(ev.start):
			ev.status = "live"
		elif ev.status == "live" and now >= int(ev.start) + int(ev.duration):
			_settle(ev)


func _pick_result(p: Array) -> int:
	var r := sim.rng.randf()
	for i in p.size():
		r -= float(p[i])
		if r <= 0.0:
			return i
	return p.size() - 1


func _settle(ev: Dictionary) -> void:
	ev.result = _pick_result(ev.true_p)
	ev.status = "finished"
	# Apostas do jogador
	var remaining: Array = []
	for b in player_bets:
		if b.event_id != ev.id:
			remaining.append(b)
			continue
		var won := int(b.outcome) == int(ev.result)
		var payout := float(b.stake) * float(b.odds) if won else 0.0
		if won:
			sim.economy.earn(payout, EconomySystem.PERSONAL_WIN)
			sim.add_stat("bets_won")
			sim.progression.add_xp(GameData.xp_value("bet_win"))
			sim.notify("VOCÊ GANHOU! %s pagou %s" % [b.pick, Fmt.money(payout)], "win")
		else:
			sim.notify("Aposta perdida: %s (resultado: %s)" % [b.pick, ev.outcomes[ev.result]], "lose")
		var rec: Dictionary = b.duplicate()
		rec["won"] = won
		rec["payout"] = payout
		rec["result"] = ev.outcomes[ev.result]
		player_history.append(rec)
		sim.bet_settled.emit(rec)
	player_bets = remaining
	if player_history.size() > 40:
		player_history = player_history.slice(player_history.size() - 40)
	# Livro da banca
	var keep: Array = []
	var paid_total := 0.0
	for b in book_bets:
		if b.event_id != ev.id:
			keep.append(b)
			continue
		var won_b := int(b.outcome) == int(ev.result)
		var pay := float(b.stake) * float(b.odds) if won_b else 0.0
		if won_b:
			sim.economy.charge(pay, EconomySystem.PAYOUTS)
			paid_total += pay
			book_today.payouts += pay
		if sim.customers != null:
			sim.customers.on_bet_result(str(b.customer), won_b, pay - float(b.stake))
	book_bets = keep
	biggest_payout_today = maxf(biggest_payout_today, paid_total)
	if paid_total > 0.0 and paid_total >= maxf(500.0, sim.economy.cash * 0.2):
		sim.notify("Pagamento alto: %s em prêmios de %s" % [Fmt.money(paid_total), ev.name], "warning")


func to_dict() -> Dictionary:
	return {"events": events, "next_event_id": next_event_id, "next_bet_id": next_bet_id,
		"player_bets": player_bets, "book_bets": book_bets, "player_history": player_history,
		"news": news, "ratings": ratings, "scheduled_until_day": scheduled_until_day,
		"book_today": book_today, "biggest_payout_today": biggest_payout_today}


func from_dict(d: Dictionary) -> void:
	events = d.get("events", [])
	for e in events:
		e.start = int(e.start)
		e.duration = int(e.duration)
		e.result = int(e.result)
		e.day = int(e.day)
	next_event_id = int(d.get("next_event_id", 1))
	next_bet_id = int(d.get("next_bet_id", 1))
	player_bets = d.get("player_bets", [])
	book_bets = d.get("book_bets", [])
	player_history = d.get("player_history", [])
	news = d.get("news", [])
	ratings = d.get("ratings", {})
	scheduled_until_day = int(d.get("scheduled_until_day", 0))
	book_today = d.get("book_today", {"stakes": 0.0, "payouts": 0.0, "bets": 0})
	biggest_payout_today = float(d.get("biggest_payout_today", 0.0))
