class_name BusinessSystem
extends RefCounted
## Estabelecimento físico do jogador: estágio, imóvel, equipamentos, horário,
## margem das odds, limites de aposta, quebras, receita de cassino e custos diários.

var sim: Simulation
var active := false
var property_id := ""
var stage := 0
var equipment: Array = []          # {uid, id, broken}
var next_uid := 1
var margin := 0.10
var max_stake := 300.0
var auto_balance := false
var manually_closed := false
var internet_down_until := 0
var boosts: Array = []             # {mult, until, label}
var cost_mods: Array = []          # {category, mult, until_day}
var supplier_discount: Dictionary = {}
var equipment_revision := 0
var hype_today := 1.0
var casino_today := 0.0
var casino_stats: Dictionary = {}   # jogo -> {today, total, wager}
var _warned_no_system := false


func _init(s) -> void:
	sim = s


func reset() -> void:
	active = false
	property_id = ""
	stage = 0
	equipment = []
	next_uid = 1
	margin = float(GameData.balance("default_margin", 0.10))
	max_stake = float(GameData.balance("default_max_stake", 300))
	auto_balance = false
	manually_closed = false
	internet_down_until = 0
	boosts = []
	cost_mods = []
	supplier_discount = {}
	equipment_revision = 0
	hype_today = 1.0
	casino_today = 0.0
	casino_stats = {}


# --- Dados -----------------------------------------------------------------------

func stage_data(s: int = -1) -> Dictionary:
	if s < 0:
		s = stage
	for d in GameData.list("stages", "stages"):
		if int(d.stage) == s:
			return d
	return {}


func stage_name() -> String:
	return str(stage_data().get("name", "Sem estabelecimento"))


func item_data(id: String) -> Dictionary:
	return GameData.find("equipment", "items", id)


func all_items() -> Array:
	return GameData.list("equipment", "items")


func capacity() -> int:
	return int(stage_data().get("capacity", 0)) + int(effects().get("capacity", 0))


func counters() -> int:
	return int(stage_data().get("counters", 0))


func max_staff() -> int:
	return int(stage_data().get("max_staff", 0))


func count_category(cat: String, working_only: bool = false) -> int:
	var n := 0
	for e in equipment:
		if working_only and e.broken:
			continue
		if str(item_data(str(e.id)).get("category", "")) == cat:
			n += 1
	return n


func count_item(id: String) -> int:
	var n := 0
	for e in equipment:
		if e.id == id:
			n += 1
	return n


## Soma dos efeitos numéricos dos equipamentos funcionando.
func effects() -> Dictionary:
	var out := {}
	for e in equipment:
		if e.broken:
			continue
		var fx: Dictionary = item_data(str(e.id)).get("effects", {})
		for k in fx:
			out[k] = float(out.get(k, 0.0)) + float(fx[k])
	return out


func has_required_equipment() -> bool:
	return active and count_category("counter") > 0 and count_category("computer") > 0


func in_open_hours() -> bool:
	var m: int = sim.time.minute
	return m >= int(GameData.balance("shop_open_minute", 540)) and m < int(GameData.balance("shop_close_minute", 1380))


func is_open() -> bool:
	return active and not manually_closed and in_open_hours() and has_required_equipment()


func internet_ok() -> bool:
	return sim.time.abs_minute() >= internet_down_until


func can_take_bets() -> bool:
	return is_open() and internet_ok() and count_category("computer", true) > 0 and count_category("counter", true) > 0


# --- Indicadores -----------------------------------------------------------------

func service_speed_mult() -> float:
	var fx := effects()
	return (1.0 + float(fx.get("service_speed", 0.0)) + sim.employees.cashier_bonus()) * sim.employees.manager_mult()


func pricing_error() -> float:
	var base := float(GameData.balance("base_pricing_error", 0.22))
	var fx := effects()
	return maxf(0.02, base * (1.0 - sim.employees.analyst_reduction()) * maxf(0.1, 1.0 + float(fx.get("pricing_error", 0.0))))


func security_score() -> float:
	return float(effects().get("security", 0.0)) + sim.employees.security_bonus()


func comfort() -> float:
	return float(effects().get("comfort", 0.0))


func patience_mult() -> float:
	return minf(2.0, 1.0 + float(effects().get("patience", 0.0)))


func boost_mult() -> float:
	var now: int = sim.time.abs_minute()
	var m := 1.0
	for b in boosts:
		if int(b.until) > now:
			m *= float(b.mult)
	return m


func odds_factor(m: float = -1.0) -> float:
	if m < 0.0:
		m = margin
	return clampf(pow(sim.market_margin() / maxf(m, 0.01), float(GameData.balance("odds_elasticity", 1.6))), 0.4, 2.5)


## Atratividade comparável à dos concorrentes (usada na divisão do mercado).
func attractiveness() -> float:
	if not active:
		return 0.0
	var rep_f := pow(maxf(sim.reputation.value, 5.0) / 50.0, 1.3)
	var fx := effects()
	var comfort_f := 1.0 + (float(fx.get("attract", 0.0)) + comfort() * 0.5) / 100.0
	var promo: float = sim.promotions.arrival_mult() if sim.promotions != null else 1.0
	var queue_pen := 1.0 / (1.0 + sim.customers.queue_length() * 0.04)
	return rep_f * odds_factor() * comfort_f * promo * boost_mult() * queue_pen


func demand_per_hour() -> float:
	if not is_open():
		return 0.0
	var curve: Array = GameData.balance("hour_curve", [])
	var h: int = sim.time.hour()
	var hc := float(curve[h]) if h < curve.size() else 1.0
	var share: float = sim.competition.player_share() if sim.competition != null else 0.45
	var wk := float(GameData.balance("weekend_mult", 1.25)) if sim.time.is_weekend() else 1.0
	return float(stage_data().get("market_demand", 10)) * share * hc * wk * hype_today * boost_mult() * (sim.promotions.arrival_mult() if sim.promotions != null else 1.0)


# --- Ciclo -----------------------------------------------------------------------

func start_day() -> void:
	casino_today = 0.0
	for k in casino_stats:
		casino_stats[k].today = 0.0
	var today: int = sim.time.day
	var extra := 0.0
	for e in sim.betting.events:
		if int(e.day) == today:
			extra += float(e.hype) - 1.0
	hype_today = clampf(1.0 + extra * 0.12, 1.0, 1.6)
	cost_mods = cost_mods.filter(func(c): return int(c.until_day) >= today)
	_warned_no_system = false


func step_minute() -> void:
	if not active:
		return
	sim.customers.step_minute()
	if is_open() and not can_take_bets() and not _warned_no_system:
		_warned_no_system = true
		sim.notify("BANCA PARADA: sem computador/balcão funcionando ou sem internet!", "error")
	elif can_take_bets():
		_warned_no_system = false


func hourly() -> void:
	if not active:
		return
	var now: int = sim.time.abs_minute()
	boosts = boosts.filter(func(b): return int(b.until) > now)
	if auto_balance and sim.employees.count_role("analista") > 0:
		sim.betting.auto_balance()
	if not is_open():
		return
	# Quebras de equipamento
	var chance := float(GameData.balance("breakdown_chance_per_hour", 0.004)) * sim.employees.breakdown_mult()
	for e in equipment:
		if not e.broken and sim.rng.randf() < chance:
			e.broken = true
			equipment_revision += 1
			sim.notify("%s COM PROBLEMA! Conserte em Administração > Equipamentos." % str(item_data(str(e.id)).get("name", "Equipamento")).to_upper(), "warning")
			sim.business_changed.emit()
			break
	_casino_hour()


func _casino_hour() -> void:
	var curve: Array = GameData.balance("hour_curve", [])
	var h: int = sim.time.hour()
	var demand := (float(curve[h]) if h < curve.size() else 1.0) * clampf(sim.reputation.value / 60.0, 0.3, 1.6)
	if sim.time.is_weekend():
		demand *= float(GameData.balance("weekend_mult", 1.25))
	if sim.promotions != null:
		demand *= sim.promotions.casino_mult()
	demand *= boost_mult()
	var dealers := sim.employees.working("crupie").size()
	var net := 0.0
	for e in equipment:
		if e.broken:
			continue
		var d := item_data(str(e.id))
		var c: Dictionary = d.get("casino", {})
		if c.is_empty():
			continue
		if d.get("dealer", false):
			if dealers <= 0:
				continue
			dealers -= 1
		var plays := float(c.plays) * demand * sim.employees.specialist_casino_mult()
		var wager := plays * float(c.avg_bet)
		var result := wager * float(c.edge) + sim.rng.randfn(0.0, float(c.avg_bet) * sqrt(maxf(plays, 1.0)) * float(c.get("vol", 1.0)))
		if float(c.get("jackpot_chance", 0.0)) > 0.0 and sim.rng.randf() < float(c.jackpot_chance):
			result -= float(c.get("jackpot", 50000))
			sim.notify("JACKPOT! Um cliente ganhou %s no %s." % [Fmt.money(float(c.jackpot)), d.name], "warning")
			sim.reputation.add(1.0, "Jackpot pago")
		net += result
		var gid := str(e.id)
		var st: Dictionary = casino_stats.get(gid, {"today": 0.0, "total": 0.0, "wager": 0.0})
		st.today = float(st.today) + result
		st.total = float(st.total) + result
		st.wager = float(st.wager) + wager
		casino_stats[gid] = st
	if net > 0.0:
		sim.economy.earn(net, EconomySystem.CASINO)
	elif net < 0.0:
		sim.economy.charge(-net, EconomySystem.CASINO_PAYOUTS)
	casino_today += net


func casino_tables_without_dealer() -> int:
	var tables := 0
	for e in equipment:
		if not e.broken and item_data(str(e.id)).get("dealer", false):
			tables += 1
	return maxi(0, tables - sim.employees.working("crupie").size())


# --- Ações -----------------------------------------------------------------------

func price_of(id: String) -> float:
	var cost := float(item_data(id).get("cost", 0))
	if not supplier_discount.is_empty() and int(supplier_discount.until) > sim.time.abs_minute():
		cost *= 1.0 - float(supplier_discount.pct)
	return roundf(cost)


## "" se pode comprar; senão o motivo.
func buy_block_reason(id: String) -> String:
	var d := item_data(id)
	if d.is_empty():
		return "Item inválido"
	if not active:
		return "Você precisa ter uma banca"
	if stage < int(d.get("min_stage", 1)):
		return "Requer estágio %d (%s)" % [int(d.min_stage), stage_data(int(d.min_stage)).get("name", "")]
	if sim.progression.level < int(d.get("min_level", 1)):
		return "Requer nível %d" % int(d.min_level)
	if d.has("requires_item") and count_item(str(d.requires_item)) == 0:
		return "Requer " + str(item_data(str(d.requires_item)).get("name", d.requires_item))
	if d.has("license") and not sim.licenses.has(str(d.license)):
		return "Requer " + str(sim.licenses.data(str(d.license)).get("name", d.license))
	if str(d.category) == "counter" and count_category("counter") >= counters():
		return "Limite de guichês do estágio (%d)" % counters()
	if str(d.category) == "computer" and count_category("computer") >= counters():
		return "Um computador por guichê (%d)" % counters()
	if d.has("max") and count_item(id) >= int(d.max):
		return "Máximo de %d" % int(d.max)
	var casino_items := 0
	if d.has("casino"):
		for e in equipment:
			if item_data(str(e.id)).has("casino"):
				casino_items += 1
		if casino_items >= capacity() / 3:
			return "Sem espaço para mais jogos neste estágio"
	if not sim.economy.can_afford(price_of(id)):
		return "Faltam " + Fmt.money(price_of(id) - sim.economy.cash)
	return ""


func buy_equipment(id: String) -> bool:
	var why := buy_block_reason(id)
	if why != "":
		sim.notify(why, "error")
		return false
	var cost := price_of(id)
	if not sim.economy.spend(cost, EconomySystem.EQUIP):
		return false
	equipment.append({"uid": next_uid, "id": id, "broken": false, "paid": cost})
	next_uid += 1
	equipment_revision += 1
	sim.progression.add_xp(GameData.xp_value("purchase"))
	sim.notify("Comprado: " + str(item_data(id).name), "cash")
	sim.business_changed.emit()
	sim.after_action()
	return true


func _find(uid: int) -> Dictionary:
	for e in equipment:
		if int(e.uid) == uid:
			return e
	return {}


func sell_equipment(uid: int) -> void:
	var e := _find(uid)
	if e.is_empty():
		return
	var v := roundf(float(e.get("paid", item_data(str(e.id)).get("cost", 0))) * float(GameData.balance("equipment_resale", 0.5)) * (0.5 if e.broken else 1.0))
	equipment.erase(e)
	sim.economy.earn(v, EconomySystem.ASSET_SALE)
	equipment_revision += 1
	sim.notify("Vendido por " + Fmt.money(v), "cash")
	sim.business_changed.emit()


func repair_cost(uid: int) -> float:
	var e := _find(uid)
	return roundf(float(item_data(str(e.get("id", ""))).get("cost", 0)) * 0.2 * sim.employees.maintenance_mult())


func repair(uid: int) -> bool:
	var e := _find(uid)
	if e.is_empty() or not e.broken:
		return false
	if not sim.economy.spend(repair_cost(uid), EconomySystem.MAINT):
		return false
	e.broken = false
	equipment_revision += 1
	sim.notify(str(item_data(str(e.id)).name) + " consertado.", "cash")
	sim.business_changed.emit()
	return true


func break_random(category: String = "") -> bool:
	var cands: Array = equipment.filter(func(e): return not e.broken and (category == "" or str(item_data(str(e.id)).category) == category))
	if cands.is_empty():
		return false
	var e: Dictionary = cands[sim.rng.randi_range(0, cands.size() - 1)]
	e.broken = true
	equipment_revision += 1
	sim.business_changed.emit()
	return true


func set_margin(m: float) -> void:
	margin = clampf(snappedf(m, 0.005), float(GameData.balance("min_margin", 0.02)), float(GameData.balance("max_margin", 0.2)))


func set_max_stake(v: float) -> void:
	max_stake = clampf(roundf(v / 10.0) * 10.0, 20.0, 1000000.0)


func equipment_value() -> float:
	var v := 0.0
	for e in equipment:
		v += float(e.get("paid", item_data(str(e.id)).get("cost", 0))) * float(GameData.balance("equipment_resale", 0.5))
	return v


# --- Abertura e expansão -----------------------------------------------------------

## Imóvel que comporta um estágio.
func property_for_stage(s: int) -> String:
	for p in GameData.list("properties", "properties"):
		if p.get("type", "") == "business" and s in p.get("stages", []).map(func(x): return int(x)):
			return str(p.id)
	return ""


func open_at(pid: String) -> bool:
	if active:
		return false
	var pd := GameData.find("properties", "properties", pid)
	var stages: Array = pd.get("stages", [])
	if stages.is_empty() or int(stages[0]) != 1:
		sim.notify("Sua primeira banca precisa ser na Sala Comercial.", "error")
		return false
	if not sim.licenses.has("basica"):
		sim.notify("Você precisa do Alvará Municipal de Apostas (Administração > Licenças).", "error")
		return false
	active = true
	property_id = pid
	stage = 1
	manually_closed = false
	equipment_revision += 1
	sim.recovery_mode = false
	sim.add_message("Mentor", "Sua banca existe! Compre um balcão e um computador (Loja de Eletrônicos ou celular > Mercado). Depois fique atrás do balcão para atender.")
	sim.notify("Você agora é dono de uma banca: " + sim.brand_name, "chapter")
	sim.business_changed.emit()
	sim.after_action()
	return true


func upgrade_requirements() -> Array:
	var out: Array = []
	var nd := stage_data(stage + 1)
	if nd.is_empty():
		return out
	out.append({"text": "Custo da obra: " + Fmt.money(float(nd.upgrade_cost)), "ok": sim.economy.can_afford(float(nd.upgrade_cost))})
	out.append({"text": "Nível %d" % int(nd.min_level), "ok": sim.progression.level >= int(nd.min_level)})
	out.append({"text": "Reputação %d" % int(nd.min_rep), "ok": sim.reputation.value >= float(nd.min_rep)})
	out.append({"text": "Licença: " + str(sim.licenses.data(str(nd.license)).get("name", nd.license)), "ok": sim.licenses.has(str(nd.license))})
	var pid := property_for_stage(stage + 1)
	if pid != property_id:
		var c := str(sim.properties.contracts.get(pid, ""))
		var nm := str(GameData.find("properties", "properties", pid).get("name", pid))
		out.append({"text": "Imóvel alugado ou comprado: " + nm, "ok": c != ""})
	return out


func can_upgrade() -> bool:
	if not active or stage_data(stage + 1).is_empty():
		return false
	for r in upgrade_requirements():
		if not r.ok:
			return false
	return true


func upgrade() -> bool:
	if not can_upgrade():
		sim.notify("Requisitos de expansão não atendidos.", "error")
		return false
	var nd := stage_data(stage + 1)
	if not sim.economy.spend(float(nd.upgrade_cost), EconomySystem.EXPANSION):
		return false
	var pid := property_for_stage(stage + 1)
	if pid != property_id:
		var old := property_id
		property_id = pid
		sim.properties.on_business_moved(old)
	stage += 1
	equipment_revision += 1
	sim.progression.add_xp(GameData.xp_value("expansion") * stage)
	sim.reputation.add(3.0, "Expansão")
	sim.notify("EXPANSÃO CONCLUÍDA: %s!" % nd.name, "chapter")
	sim.add_stat("expansions")
	sim.business_changed.emit()
	sim.after_action()
	return true


## Falência: vende tudo a preço de liquidação.
func liquidate() -> float:
	var v := 0.0
	for e in equipment:
		v += float(e.get("paid", item_data(str(e.id)).get("cost", 0))) * float(GameData.balance("liquidation_equipment", 0.3))
	reset()
	return roundf(v)


func cost_mult(category: String) -> float:
	var m := 1.0
	for c in cost_mods:
		if c.category == category:
			m *= float(c.mult)
	return m


func collect_daily_costs(costs: Dictionary, _apply: bool = true) -> void:
	if not active:
		return
	var sd := stage_data()
	var energy := float(sd.get("energy", 0))
	var maint := 0.0
	for e in equipment:
		var d := item_data(str(e.id))
		energy += float(d.get("energy", 0))
		maint += float(d.get("maintenance", 0))
	_add(costs, EconomySystem.ENERGY, energy * cost_mult(EconomySystem.ENERGY))
	_add(costs, EconomySystem.INTERNET, float(sd.get("internet", 0)) * cost_mult(EconomySystem.INTERNET))
	_add(costs, EconomySystem.SERVICES, float(sd.get("cleaning", 0)) * cost_mult(EconomySystem.SERVICES))
	_add(costs, EconomySystem.MAINT, maint * sim.employees.maintenance_mult())


static func _add(costs: Dictionary, k: String, v: float) -> void:
	if v > 0.0:
		costs[k] = float(costs.get(k, 0.0)) + roundf(v)


func to_dict() -> Dictionary:
	return {"active": active, "property_id": property_id, "stage": stage, "equipment": equipment, "next_uid": next_uid,
		"margin": margin, "max_stake": max_stake, "auto_balance": auto_balance, "manually_closed": manually_closed,
		"internet_down_until": internet_down_until, "boosts": boosts, "cost_mods": cost_mods,
		"supplier_discount": supplier_discount, "hype_today": hype_today, "casino_today": casino_today, "casino_stats": casino_stats}


func from_dict(d: Dictionary) -> void:
	active = bool(d.get("active", false))
	property_id = str(d.get("property_id", ""))
	stage = int(d.get("stage", 0))
	equipment = d.get("equipment", [])
	for e in equipment:
		e.uid = int(e.uid)
		e.broken = bool(e.broken)
	next_uid = int(d.get("next_uid", 1))
	margin = float(d.get("margin", 0.1))
	max_stake = float(d.get("max_stake", 300))
	auto_balance = bool(d.get("auto_balance", false))
	manually_closed = bool(d.get("manually_closed", false))
	internet_down_until = int(d.get("internet_down_until", 0))
	boosts = d.get("boosts", [])
	cost_mods = d.get("cost_mods", [])
	supplier_discount = d.get("supplier_discount", {})
	hype_today = float(d.get("hype_today", 1.0))
	casino_today = float(d.get("casino_today", 0.0))
	casino_stats = d.get("casino_stats", {})
	equipment_revision += 1
