class_name OnlineBusinessSystem
extends RefCounted
## Operação online fictícia (site/app da marca), separada da operação física:
## receita, custos, usuários, reputação online e riscos próprios.

var sim: Simulation
var open := false
var site_level := 0
var marketing := 0.0        # orçamento diário
var support := 0
var security_level := 0
var users := 0.0
var online_rep := 50.0
var outage_until := 0
var today_net := 0.0
var total_net := 0.0
var invested := 0.0
var _outage_warned_day := -1


func _init(s) -> void:
	sim = s


func reset() -> void:
	open = false
	site_level = 0
	marketing = 0.0
	support = 0
	security_level = 0
	users = 0.0
	online_rep = 50.0
	outage_until = 0
	today_net = 0.0
	total_net = 0.0
	invested = 0.0


func cfg() -> Dictionary:
	return GameData.load_json("online")


func level_data(lv: int = -1) -> Dictionary:
	if lv < 0:
		lv = site_level
	for l in cfg().get("site_levels", []):
		if int(l.level) == lv:
			return l
	return {}


func launch_block_reason() -> String:
	if open:
		return "Já está no ar"
	if not sim.has_business():
		return "Requer uma banca física"
	if not sim.licenses.has("digital"):
		return "Requer a Licença de Operação Digital"
	var cost := float(cfg().get("launch_cost", 20000))
	if not sim.economy.can_afford(cost):
		return "Custo de lançamento: " + Fmt.money(cost)
	return ""


func launch() -> bool:
	var why := launch_block_reason()
	if why != "":
		sim.notify(why, "error")
		return false
	var cost := float(cfg().get("launch_cost", 20000))
	if not sim.economy.spend(cost, EconomySystem.EXPANSION):
		return false
	invested += cost
	open = true
	site_level = 1
	users = 20.0
	sim.progression.add_xp(400)
	sim.notify("SITE NO AR: %s agora aceita apostas online (fictícias)!" % sim.brand_name, "chapter")
	sim.after_action()
	return true


func upgrade() -> bool:
	var nd := level_data(site_level + 1)
	if not open or nd.is_empty():
		return false
	if not sim.economy.spend(float(nd.upgrade_cost), EconomySystem.EXPANSION):
		return false
	invested += float(nd.upgrade_cost)
	site_level += 1
	online_rep = minf(100.0, online_rep + 3.0)
	sim.notify("Plataforma atualizada: " + str(nd.name), "chapter")
	sim.after_action()
	return true


func capacity() -> float:
	var servers := float(sim.business.effects().get("online_capacity", 0.0)) if sim.has_business() else 0.0
	return float(cfg().get("base_capacity", 150)) * site_level + servers


func target_users() -> float:
	var base := float(level_data().get("base_users", 0))
	var mk := 1.0 + sqrt(maxf(marketing, 0.0) / 800.0)
	return base * pow(online_rep / 50.0, 1.2) * pow(sim.reputation.value / 50.0, 0.6) * mk


func hourly() -> void:
	if not open:
		return
	var now := sim.time.abs_minute()
	users += (target_users() - users) * 0.05
	users = maxf(0.0, users)
	# Suporte insuficiente derruba a reputação online
	var need_support := int(ceil(users / float(cfg().get("users_per_support", 400))))
	if support < need_support:
		online_rep = maxf(0.0, online_rep - 0.08 * (need_support - support))
	else:
		online_rep = minf(100.0, online_rep + 0.03)
	# Sobrecarga dos servidores
	if users > capacity() and now >= outage_until:
		if sim.rng.randf() < 0.25:
			outage_until = now + 60
			online_rep = maxf(0.0, online_rep - 2.0)
			users *= 0.9
			if _outage_warned_day != sim.time.day:
				_outage_warned_day = sim.time.day
				sim.notify("SITE FORA DO AR: servidores sobrecarregados! Compre servidores.", "error")
	if now < outage_until:
		return
	var curve: Array = GameData.balance("hour_curve", [])
	var h := sim.time.hour()
	var hc := maxf(0.25, float(curve[h]) if h < curve.size() else 1.0)
	var handle := users * float(cfg().get("bets_per_user_hour", 0.12)) * float(cfg().get("avg_stake", 35)) * hc
	var edge := sim.business.margin / (1.0 + sim.business.margin) if sim.has_business() else 0.08
	var net := handle * edge + sim.rng.randfn(0.0, sqrt(maxf(handle, 1.0)) * 6.0)
	if net > 0.0:
		sim.economy.earn(net, EconomySystem.ONLINE)
	else:
		sim.economy.charge(-net, EconomySystem.ONLINE)
	today_net += net
	total_net += net


func collect_daily_costs(costs: Dictionary, _apply: bool = true) -> void:
	if not open:
		return
	costs[EconomySystem.INTERNET] = float(costs.get(EconomySystem.INTERNET, 0.0)) + float(level_data().get("hosting", 0))
	if marketing > 0.0:
		costs[EconomySystem.MARKETING] = float(costs.get(EconomySystem.MARKETING, 0.0)) + marketing
	if support > 0:
		costs[EconomySystem.SALARY] = float(costs.get(EconomySystem.SALARY, 0.0)) + support * float(cfg().get("support_salary", 140))
	var sec: Array = cfg().get("security_levels", [])
	if security_level > 0 and security_level < sec.size():
		costs[EconomySystem.SECURITY] = float(costs.get(EconomySystem.SECURITY, 0.0)) + float(sec[security_level].daily)


func daily() -> void:
	if not open:
		return
	today_net = 0.0
	# Ataques virtuais (abstratos): segurança reduz a chance e o dano
	var chance := 0.08 * (1.0 - security_level * 0.3)
	if sim.rng.randf() < chance:
		var loss := roundf(users * 6.0 * (1.0 - security_level * 0.25))
		sim.economy.charge(loss, EconomySystem.EVENTS)
		online_rep = maxf(0.0, online_rep - 4.0 + security_level)
		sim.notify("TENTATIVA DE EXPLORAÇÃO DO SISTEMA ONLINE: prejuízo de %s. Invista em segurança digital." % Fmt.money(loss), "error")
	elif security_level > 0 and sim.rng.randf() < 0.1:
		sim.add_stat("frauds_blocked")
		sim.notify("Sua segurança digital bloqueou uma tentativa de fraude no site.", "cash")


func asset_value() -> float:
	return invested * 0.5 if open else 0.0


func shutdown() -> void:
	reset()


func to_dict() -> Dictionary:
	return {"open": open, "site_level": site_level, "marketing": marketing, "support": support, "security_level": security_level,
		"users": users, "online_rep": online_rep, "outage_until": outage_until, "today_net": today_net, "total_net": total_net, "invested": invested}


func from_dict(d: Dictionary) -> void:
	open = bool(d.get("open", false))
	site_level = int(d.get("site_level", 0))
	marketing = float(d.get("marketing", 0.0))
	support = int(d.get("support", 0))
	security_level = int(d.get("security_level", 0))
	users = float(d.get("users", 0.0))
	online_rep = float(d.get("online_rep", 50.0))
	outage_until = int(d.get("outage_until", 0))
	today_net = float(d.get("today_net", 0.0))
	total_net = float(d.get("total_net", 0.0))
	invested = float(d.get("invested", 0.0))
