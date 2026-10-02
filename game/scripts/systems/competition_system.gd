class_name CompetitionSystem
extends RefCounted
## Concorrentes controlados por IA. Cada um tem capital, reputação, odds (margem), tamanho,
## estratégia e agressividade, e segue a máquina de estados
## MONITOR → ANALYZE → (PROMOTION | EXPANSION | NORMAL_OPERATION) → MONITOR.
## A participação de mercado do jogador vem da atratividade comparada.

var sim: Simulation
var comps: Array = []
var _share_cache := 0.45
var _share_minute := -1


func _init(s) -> void:
	sim = s


func reset() -> void:
	comps = []
	for c in GameData.list("competitors", "competitors"):
		comps.append({
			"id": c.id, "name": c.name, "capital": float(c.capital), "reputation": float(c.reputation),
			"base_margin": float(c.margin), "margin": float(c.margin), "size": int(c.size),
			"strategy": c.strategy, "aggression": float(c.aggression), "casino": bool(c.get("casino", false)),
			"status": "active", "state": "MONITOR", "state_days": 0, "promo_days": 0,
			"last_share": 0.0, "history": [], "profit_yesterday": 0.0,
		})
	_share_minute = -1


func cfg(key: String, default: Variant) -> Variant:
	var d: Dictionary = GameData.load_json("competitors")
	return d.get(key, default)


func get_comp(id: String) -> Dictionary:
	for c in comps:
		if c.id == id:
			return c
	return {}


func active() -> Array:
	return comps.filter(func(c): return c.status == "active")


func comp_attractiveness(c: Dictionary) -> float:
	var rep_f := pow(maxf(float(c.reputation), 5.0) / 50.0, 1.3)
	var odds_f := clampf(pow(sim.market_margin() / maxf(float(c.margin), 0.01), float(GameData.balance("odds_elasticity", 1.6))), 0.4, 2.5)
	var promo := 1.35 if int(c.promo_days) > 0 else 1.0
	return rep_f * odds_f * (1.0 + 0.12 * int(c.size)) * promo


## Peso de um concorrente: compete mais com quem tem porte parecido com o seu.
func _weight(c: Dictionary) -> float:
	var st := maxi(1, sim.business.stage) if sim.has_business() else 1
	return 1.0 / (1.0 + 0.45 * absi(int(c.size) - st))


func player_share() -> float:
	if not sim.has_business():
		return 0.0
	var now := sim.time.abs_minute()
	if now - _share_minute < 15 and _share_minute >= 0:
		return _share_cache
	_share_minute = now
	var mine := sim.business.attractiveness() * (1.0 + 0.1 * sim.business.stage)
	var others := 0.0
	for c in active():
		others += comp_attractiveness(c) * _weight(c)
	_share_cache = clampf(mine / maxf(mine + others, 0.001), 0.02, 0.95)
	return _share_cache


func market_shares() -> Array:
	var mine := sim.business.attractiveness() * (1.0 + 0.1 * sim.business.stage) if sim.has_business() else 0.0
	var rows: Array = []
	var total := mine
	for c in active():
		var a := comp_attractiveness(c) * _weight(c)
		rows.append([c.name, a])
		total += a
	var out: Array = [[sim.brand_name + " (você)", mine / maxf(total, 0.001)]]
	for r in rows:
		out.append([r[0], r[1] / maxf(total, 0.001)])
	return out


# --- IA diária -------------------------------------------------------------------

func daily() -> void:
	var share := player_share()
	var base_rev := float(cfg("base_revenue_per_size", 1000))
	var base_cost := float(cfg("base_cost_per_size", 760))
	for c in comps:
		if c.status == "acquired":
			continue
		if c.status != "active":
			continue
		var size := int(c.size)
		var pressure := share * _weight(c) if sim.has_business() else 0.0
		var revenue := size * base_rev * (float(c.reputation) / 55.0) * sqrt(float(c.margin) / 0.1) * (1.0 - pressure * 0.75) * sim.rng.randf_range(0.85, 1.15)
		var cost := size * base_cost
		if int(c.promo_days) > 0:
			cost += size * float(cfg("promo_cost_per_size", 1500)) / 3.0
		var profit := revenue - cost
		c.capital = float(c.capital) + profit
		c.profit_yesterday = profit
		_step_state(c, share)
		# Reputação reage ao jogador e oscila
		var rep_gap := sim.reputation.value - float(c.reputation)
		c.reputation = clampf(float(c.reputation) + sim.rng.randf_range(-0.6, 0.6) - (0.25 if rep_gap > 10.0 and sim.has_business() else 0.0), 20.0, 95.0)
		c.history.append(int(c.capital))
		if c.history.size() > 30:
			c.history.pop_front()
		if float(c.capital) < -size * 8000.0:
			c.status = "closed"
			c.state = "CLOSED"
			sim.add_stat("competitors_defeated")
			sim.notify("%s FECHOU AS PORTAS! Os clientes dela agora procuram outras casas." % c.name, "competitor")
			sim.add_message("Mentor", "Um concorrente a menos. Você ganhou espaço no mercado.")
			sim.business_changed.emit()
	_share_minute = -1


func _step_state(c: Dictionary, share: float) -> void:
	c.state_days = int(c.state_days) + 1
	if int(c.promo_days) > 0:
		c.promo_days = int(c.promo_days) - 1
		if int(c.promo_days) == 0:
			c.margin = float(c.base_margin)
	match str(c.state):
		"MONITOR":
			c.state = "ANALYZE"
			c.state_days = 0
		"ANALYZE":
			var threat := share - float(c.last_share)
			c.last_share = share
			var size := int(c.size)
			var promo_cost := size * float(cfg("promo_cost_per_size", 1500))
			var expand_cost := float(cfg("expand_cost_per_size", 60000)) * (size + 1)
			var trigger := share > 0.55 - float(c.aggression) * 0.3 or threat > 0.04
			if sim.has_business() and trigger and float(c.capital) > promo_cost and sim.rng.randf() < 0.4 + float(c.aggression) * 0.5:
				c.state = "PROMOTION"
				c.promo_days = 3
				c.margin = maxf(0.03, float(c.base_margin) - 0.025)
				c.capital = float(c.capital) - promo_cost
				c.reputation = minf(95.0, float(c.reputation) + 1.0)
				sim.notify("%s LANÇOU UMA PROMOÇÃO: odds turbinadas por 3 dias!" % c.name, "competitor")
			elif float(c.capital) > expand_cost * 1.3 and size < 6 and sim.rng.randf() < float(c.aggression) * 0.35:
				c.state = "EXPANSION"
				c.size = size + 1
				c.capital = float(c.capital) - expand_cost
				c.reputation = minf(95.0, float(c.reputation) + 2.0)
				sim.notify("%s expandiu e agora é ainda maior (porte %d)." % [c.name, int(c.size)], "competitor")
			else:
				c.state = "NORMAL_OPERATION"
			c.state_days = 0
		"PROMOTION":
			if int(c.promo_days) <= 0:
				c.state = "NORMAL_OPERATION"
				c.state_days = 0
		"EXPANSION":
			c.state = "NORMAL_OPERATION"
			c.state_days = 0
		_:
			if int(c.state_days) >= 2:
				c.state = "MONITOR"
				c.state_days = 0


## Evento: força um concorrente a lançar promoção.
func force_promotion() -> String:
	var list := active()
	if list.is_empty():
		return ""
	var c: Dictionary = list[sim.rng.randi_range(0, list.size() - 1)]
	c.state = "PROMOTION"
	c.promo_days = 3
	c.margin = maxf(0.03, float(c.base_margin) - 0.025)
	_share_minute = -1
	return str(c.name)


# --- Aquisição -----------------------------------------------------------------

func acquisition_price(c: Dictionary) -> float:
	return roundf((maxf(float(c.capital), 0.0) * 0.6 + int(c.size) * 35000.0 * (float(c.reputation) / 60.0)) / 1000.0) * 1000.0


func acquire_block_reason(c: Dictionary) -> String:
	if c.status != "active":
		return "Indisponível"
	if not sim.has_business():
		return "Você precisa ter um negócio"
	if sim.business.stage < int(c.size):
		return "Seu negócio precisa ser pelo menos do porte %d" % int(c.size)
	if sim.progression.level < 6:
		return "Requer nível 6"
	if not sim.economy.can_afford(acquisition_price(c)):
		return "Faltam " + Fmt.money(acquisition_price(c) - sim.economy.cash)
	return ""


func acquire(id: String) -> bool:
	var c := get_comp(id)
	if c.is_empty():
		return false
	var why := acquire_block_reason(c)
	if why != "":
		sim.notify(why, "error")
		return false
	if not sim.economy.spend(acquisition_price(c), EconomySystem.ACQUISITION):
		return false
	c.status = "acquired"
	c.state = "FILIAL"
	sim.add_stat("competitors_defeated")
	sim.progression.add_xp(500 * int(c.size))
	sim.reputation.add(3.0, "Aquisição de concorrente")
	sim.notify("AQUISIÇÃO CONCLUÍDA: %s agora é uma filial da %s!" % [c.name, sim.brand_name], "chapter")
	_share_minute = -1
	sim.business_changed.emit()
	sim.after_action()
	return true


func branch_income(c: Dictionary) -> float:
	return roundf(int(c.size) * 420.0 * clampf(sim.reputation.value / 60.0, 0.4, 1.6))


func collect_daily_costs(_costs: Dictionary, apply: bool = true) -> void:
	if not apply:
		return
	for c in comps:
		if c.status == "acquired":
			sim.economy.earn(branch_income(c), EconomySystem.BRANCHES)


func branches() -> Array:
	return comps.filter(func(c): return c.status == "acquired")


func status_text(c: Dictionary) -> String:
	match str(c.status):
		"closed": return "FECHADA"
		"acquired": return "FILIAL " + sim.brand_name.to_upper()
	return ""


func to_dict() -> Dictionary:
	return {"comps": comps}


func from_dict(d: Dictionary) -> void:
	var saved: Array = d.get("comps", [])
	if saved.is_empty():
		return
	comps = saved
	for c in comps:
		c.size = int(c.size)
		c.promo_days = int(c.promo_days)
		c.state_days = int(c.state_days)
	_share_minute = -1
