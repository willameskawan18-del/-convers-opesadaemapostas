class_name PropertySystem
extends RefCounted
## Imóveis: aluguel, compra, venda, renda passiva e valorização.
## contracts[id] = "rented" | "owned".

var sim: Simulation
var contracts: Dictionary = {}
var value_mult: Dictionary = {}
var discounts: Dictionary = {}     # id -> {pct, until_day}


func _init(s) -> void:
	sim = s


func reset() -> void:
	contracts = {}
	value_mult = {}
	discounts = {}


func all() -> Array:
	return GameData.list("properties", "properties")


func data(id: String) -> Dictionary:
	return GameData.find("properties", "properties", id)


func display_name(id: String) -> String:
	return str(data(id).get("name", id))


func has_business_contract() -> bool:
	for id in contracts:
		if data(id).get("type", "") == "business":
			return true
	return false


func owned_count(type: String = "") -> int:
	var n := 0
	for id in contracts:
		if contracts[id] == "owned" and (type == "" or data(id).get("type", "") == type):
			n += 1
	return n


func price(id: String) -> float:
	var p := float(data(id).get("price", 0)) * float(value_mult.get(id, 1.0))
	var disc: Dictionary = discounts.get(id, {})
	if not disc.is_empty() and int(disc.until_day) >= sim.time.day:
		p *= 1.0 - float(disc.pct)
	return roundf(p)


func market_value(id: String) -> float:
	return roundf(float(data(id).get("price", 0)) * float(value_mult.get(id, 1.0)))


func asset_value() -> float:
	var v := 0.0
	for id in contracts:
		if contracts[id] == "owned":
			v += market_value(id)
	return v


func in_use(id: String) -> bool:
	return sim.has_business() and sim.business.property_id == id


func _level_ok(id: String) -> bool:
	return sim.progression.level >= int(data(id).get("min_level", 1))


func rent_block_reason(id: String) -> String:
	var d := data(id)
	if float(d.get("rent", 0)) <= 0.0:
		return "Este imóvel não está para alugar"
	if contracts.has(id):
		return "Você já tem contrato"
	if not _level_ok(id):
		return "Requer nível %d" % int(d.min_level)
	if d.get("type", "") == "business" and not sim.has_business():
		var stages: Array = d.get("stages", [])
		if stages.is_empty() or int(stages[0]) != 1:
			return "Comece pela Sala Comercial"
		if not sim.licenses.has("basica"):
			return "Requer o Alvará Municipal de Apostas"
	if not sim.economy.can_afford(float(d.get("deposit", 0))):
		return "Taxa de contrato: " + Fmt.money(float(d.deposit))
	return ""


func rent(id: String) -> bool:
	var why := rent_block_reason(id)
	if why != "":
		sim.notify(why, "error")
		return false
	var d := data(id)
	if not sim.economy.spend(float(d.get("deposit", 0)), EconomySystem.RENT):
		return false
	contracts[id] = "rented"
	sim.notify("Contrato de aluguel assinado: %s (%s/dia)" % [d.name, Fmt.money(float(d.rent))], "cash")
	if d.get("type", "") == "business" and not sim.has_business():
		sim.business.open_at(id)
	sim.business_changed.emit()
	sim.after_action()
	return true


func buy_block_reason(id: String) -> String:
	var d := data(id)
	if contracts.get(id, "") == "owned":
		return "Você já é dono"
	if not _level_ok(id):
		return "Requer nível %d" % int(d.min_level)
	if d.get("type", "") == "business" and not sim.has_business():
		var stages: Array = d.get("stages", [])
		if stages.is_empty() or int(stages[0]) != 1:
			return "Comece pela Sala Comercial"
		if not sim.licenses.has("basica"):
			return "Requer o Alvará Municipal de Apostas"
	if not sim.economy.can_afford(price(id)):
		return "Faltam " + Fmt.money(price(id) - sim.economy.cash)
	return ""


func buy(id: String) -> bool:
	var why := buy_block_reason(id)
	if why != "":
		sim.notify(why, "error")
		return false
	var cost := price(id)
	if not sim.economy.spend(cost, EconomySystem.PROPERTY):
		return false
	contracts[id] = "owned"
	discounts.erase(id)
	sim.progression.add_xp(GameData.xp_value("property"))
	sim.add_stat("properties_bought")
	sim.notify("IMÓVEL COMPRADO: %s. Sem mais aluguel!" % display_name(id), "chapter")
	var d := data(id)
	if d.get("type", "") == "business" and not sim.has_business():
		sim.business.open_at(id)
	sim.business_changed.emit()
	sim.after_action()
	return true


func end_rent(id: String) -> bool:
	if contracts.get(id, "") != "rented":
		return false
	if in_use(id):
		sim.notify("Sua banca funciona aqui. Expanda para outro imóvel antes.", "error")
		return false
	contracts.erase(id)
	sim.notify("Contrato encerrado: " + display_name(id), "info")
	sim.business_changed.emit()
	return true


func sell(id: String) -> bool:
	if contracts.get(id, "") != "owned":
		return false
	if in_use(id):
		sim.notify("Não é possível vender o imóvel onde sua banca funciona.", "error")
		return false
	var v := roundf(market_value(id) * 0.85)
	contracts.erase(id)
	sim.economy.earn(v, EconomySystem.ASSET_SALE)
	sim.notify("Imóvel vendido por " + Fmt.money(v), "cash")
	sim.business_changed.emit()
	return true


## Quando o negócio muda de imóvel, o antigo alugado é encerrado; o comprado vira renda.
func on_business_moved(old_id: String) -> void:
	if contracts.get(old_id, "") == "rented":
		contracts.erase(old_id)
		sim.notify("Contrato da %s encerrado após a mudança." % display_name(old_id), "info")
	elif contracts.get(old_id, "") == "owned":
		sim.notify("%s agora é alugado para terceiros (renda passiva)." % display_name(old_id), "info")


func rental_income(id: String) -> float:
	var d := data(id)
	if d.get("type", "") == "investment":
		return float(d.get("rental_income", 0))
	return float(d.get("rent", 0)) * 0.7


func collect_daily_costs(costs: Dictionary, apply: bool = true) -> void:
	for id in contracts:
		var d := data(id)
		if contracts[id] == "rented":
			costs[EconomySystem.RENT] = float(costs.get(EconomySystem.RENT, 0.0)) + float(d.get("rent", 0)) * (sim.business.cost_mult(EconomySystem.RENT) if sim.business else 1.0)
		elif contracts[id] == "owned":
			costs[EconomySystem.TAX] = float(costs.get(EconomySystem.TAX, 0.0)) + float(d.get("upkeep", 0))
			if apply and not in_use(id):
				sim.economy.earn(rental_income(id), EconomySystem.RENT_INCOME)


func daily() -> void:
	for p in all():
		var id := str(p.id)
		value_mult[id] = float(value_mult.get(id, 1.0)) * (1.0 + sim.rng.randf_range(-0.0005, 0.0015))
	for id in discounts.keys():
		if int(discounts[id].until_day) < sim.time.day:
			discounts.erase(id)


func add_discount(pct: float, days: int) -> String:
	var cands: Array = all().filter(func(p): return contracts.get(str(p.id), "") != "owned")
	if cands.is_empty():
		return ""
	var p: Dictionary = cands[sim.rng.randi_range(0, cands.size() - 1)]
	discounts[str(p.id)] = {"pct": pct, "until_day": sim.time.day + days}
	return str(p.name)


## Falência: imóveis comprados são vendidos a preço de liquidação; aluguéis encerrados.
func liquidate() -> float:
	var v := 0.0
	for id in contracts:
		if contracts[id] == "owned":
			v += market_value(id) * float(GameData.balance("liquidation_property", 0.7))
	contracts = {}
	return roundf(v)


func to_dict() -> Dictionary:
	return {"contracts": contracts, "value_mult": value_mult, "discounts": discounts}


func from_dict(d: Dictionary) -> void:
	contracts = d.get("contracts", {})
	value_mult = d.get("value_mult", {})
	discounts = d.get("discounts", {})
