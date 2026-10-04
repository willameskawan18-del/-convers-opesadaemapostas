class_name PromotionSystem
extends RefCounted
## Promoções: custo, duração, alcance (mais clientes), impacto na reputação e retorno estimado.
## Abstrações de jogo — nada de mecânicas reais de pressão sobre apostadores.

var sim: Simulation
var active: Array = []     # {id, until}


func _init(s) -> void:
	sim = s


func reset() -> void:
	active = []


func all() -> Array:
	return GameData.list("promotions", "promotions")


func data(id: String) -> Dictionary:
	return GameData.find("promotions", "promotions", id)


func _live() -> Array:
	var now := sim.time.abs_minute()
	return active.filter(func(a): return int(a.until) > now)


func is_active(id: String) -> bool:
	for a in _live():
		if a.id == id:
			return true
	return false


func arrival_mult() -> float:
	var m := 1.0
	for a in _live():
		var d := data(str(a.id))
		var reach := float(d.get("reach", 0.0))
		if d.get("weekend_only", false) and not sim.time.is_weekend():
			reach *= 0.3
		m *= 1.0 + reach
	return m


func stake_bonus() -> float:
	var b := 0.0
	for a in _live():
		b += float(data(str(a.id)).get("stake_bonus", 0.0))
	return b


func casino_mult() -> float:
	var m := 1.0
	for a in _live():
		m *= 1.0 + float(data(str(a.id)).get("casino_boost", 0.0))
	return m


func loyalty_active() -> bool:
	for a in _live():
		if data(str(a.id)).get("loyalty", false):
			return true
	return false


## Retorno estimado (aproximado) para ajudar a decisão.
func estimated_return(id: String) -> float:
	var d := data(id)
	if not sim.has_business():
		return 0.0
	var per_day: float = sim.business.stage_data().get("market_demand", 8) * 10.0 * 0.45
	var extra_customers: float = per_day * float(d.reach) * float(d.days)
	var handle := 110.0 * float(sim.business.stage_data().get("stake_mult", 1.0))
	var edge := sim.business.margin / (1.0 + sim.business.margin)
	return roundf(extra_customers * handle * edge - float(d.cost) - extra_customers * float(d.get("per_customer", 0)))


func block_reason(id: String) -> String:
	var d := data(id)
	if not sim.has_business():
		return "Requer uma banca"
	if sim.business.stage < int(d.get("min_stage", 1)):
		return "Requer estágio %d" % int(d.min_stage)
	if is_active(id):
		return "Já está ativa"
	if not sim.economy.can_afford(float(d.cost)):
		return "Faltam " + Fmt.money(float(d.cost) - sim.economy.cash)
	return ""


func launch(id: String) -> bool:
	var why := block_reason(id)
	if why != "":
		sim.notify(why, "error")
		return false
	var d := data(id)
	if not sim.economy.spend(float(d.cost), EconomySystem.PROMO):
		return false
	active.append({"id": id, "until": sim.time.abs_minute() + int(d.days) * 1440})
	sim.reputation.add(float(d.get("rep", 0.0)), "Promoções")
	sim.add_stat("promotions")
	sim.notify("Promoção lançada: %s (%d dia(s))" % [d.name, int(d.days)], "cash")
	sim.after_action()
	return true


func collect_daily_costs(costs: Dictionary, _apply: bool = true) -> void:
	if sim.customers == null:
		return
	var per := 0.0
	for a in _live():
		per += float(data(str(a.id)).get("per_customer", 0))
	if per > 0.0:
		var served := float(sim.customers.today.get("served", 0))
		costs[EconomySystem.PROMO] = float(costs.get(EconomySystem.PROMO, 0.0)) + per * served


func daily() -> void:
	active = _live()


func to_dict() -> Dictionary:
	return {"active": active}


func from_dict(d: Dictionary) -> void:
	active = d.get("active", [])
