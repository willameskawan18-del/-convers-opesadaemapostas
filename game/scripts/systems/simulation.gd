class_name Simulation
extends Object
## Núcleo da simulação. Não depende de cenas nem de nós: pode rodar em testes headless
## (ex: simular 100 dias) e é a única fonte de verdade do estado do jogo.
## O mundo 3D e a UI apenas leem este estado e chamam suas ações.
##
## Futuro cooperativo: o estado da empresa (sistemas abaixo) é global; o que é do
## personagem (posição, ações físicas) fica fora daqui, no PlayerController.

signal notified(text: String, kind: String)
signal cash_changed(cash: float)
signal day_ended(report: Dictionary)
signal decision_requested(ev: Dictionary)
signal business_changed
signal staff_changed
signal level_up(level: int, title: String)
signal mission_changed
signal victory_reached
signal went_bankrupt(info: Dictionary)
signal bet_settled(info: Dictionary)
signal job_changed

const SAVE_VERSION := 1

var rng := RandomNumberGenerator.new()
var time: TimeSystem
var economy: EconomySystem
var reputation: ReputationSystem
var progression: ProgressionSystem
var betting: BettingSystem
var jobs: JobSystem
var licenses: LicenseSystem
var loans: LoanSystem
var missions: MissionSystem
# Sistemas de negócio (fase 2+)
var business: BusinessSystem
var customers: CustomerSystem
var employees: EmployeeSystem
var properties: PropertySystem
var competition: CompetitionSystem
var online: OnlineBusinessSystem
var events: EventSystem
var promotions: PromotionSystem

var stats: Dictionary = {}
var messages: Array = []
var player_name := "Você"
var brand_name := "Fortuna Bet"
var player_at_counter := false
var paused_for_decision := false
var campaign_complete := false
var recovery_mode := false
var negative_days := 0
var auto_decide := false   # testes: resolve decisões automaticamente
var last_report: Dictionary = {}
var _minute_acc := 0.0
var _day_snapshot: Dictionary = {}


func _init() -> void:
	time = TimeSystem.new(self)
	economy = EconomySystem.new(self)
	reputation = ReputationSystem.new(self)
	progression = ProgressionSystem.new(self)
	betting = BettingSystem.new(self)
	jobs = JobSystem.new(self)
	licenses = LicenseSystem.new(self)
	loans = LoanSystem.new(self)
	missions = MissionSystem.new(self)
	_create_business_systems()
	new_game("Você", "Fortuna Bet", 1)


## Ponto de extensão: cria os sistemas de negócio se os scripts existirem.
func _create_business_systems() -> void:
	business = BusinessSystem.new(self)
	customers = CustomerSystem.new(self)
	employees = EmployeeSystem.new(self)
	properties = PropertySystem.new(self)
	competition = CompetitionSystem.new(self)
	events = EventSystem.new(self)
	promotions = PromotionSystem.new(self)
	online = OnlineBusinessSystem.new(self)


func systems() -> Array:
	var out: Array = [time, economy, reputation, progression, betting, jobs, licenses, loans, missions]
	for s in [business, customers, employees, properties, competition, online, events, promotions]:
		if s != null:
			out.append(s)
	return out


func new_game(p_name: String = "Você", p_brand: String = "Fortuna Bet", seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	player_name = p_name if p_name.strip_edges() != "" else "Você"
	brand_name = p_brand if p_brand.strip_edges() != "" else "Fortuna Bet"
	stats = {}
	messages = []
	player_at_counter = false
	paused_for_decision = false
	campaign_complete = false
	recovery_mode = false
	negative_days = 0
	last_report = {}
	_minute_acc = 0.0
	time.reset()
	for s in systems():
		if s != time:
			s.reset()
	_snapshot_day()
	add_message("Mentor", "Bem-vindo, %s. Você tem R$ 100 e uma cidade inteira de oportunidades. Comece apostando pouco na Banca do Zé e procure trabalho no Depósito, no Mercado ou na Loja." % player_name)
	add_message("Zé", "Ô novato! Passa aqui na banca que tem jogo bom hoje.")


# --- Utilidades ------------------------------------------------------------------

func notify(text: String, kind: String = "info") -> void:
	notified.emit(text, kind)


func add_stat(key: String, n: float = 1.0) -> void:
	stats[key] = float(stats.get(key, 0.0)) + n


func stat(key: String) -> float:
	return float(stats.get(key, 0.0))


func add_message(from: String, text: String) -> void:
	if text == "":
		return
	messages.append({"from": from, "text": text, "day": time.day, "time": time.clock_text()})
	if messages.size() > 50:
		messages.pop_front()


func has_business() -> bool:
	return business != null and business.active


func market_margin() -> float:
	return float(GameData.balance("market_margin", 0.10))


func asset_value() -> float:
	var v := 0.0
	if properties != null:
		v += properties.asset_value()
	if business != null:
		v += business.equipment_value()
	if online != null:
		v += online.asset_value()
	return v


## Custos fixos que serão cobrados no fechamento do dia (sem aplicar).
func forecast_daily_costs() -> Dictionary:
	var costs: Dictionary = {}
	for s in [business, employees, properties, licenses, online, loans, promotions, competition]:
		if s != null and s.has_method("collect_daily_costs"):
			s.collect_daily_costs(costs, false)
	return costs


## Chamar após qualquer ação do jogador para atualizar missões imediatamente.
func after_action() -> void:
	missions.evaluate()


# --- Loop de tempo ------------------------------------------------------------------

func advance(game_minutes: float) -> void:
	if paused_for_decision:
		return
	_minute_acc += game_minutes
	var guard := 0
	while _minute_acc >= 1.0 and guard < 2000:
		_minute_acc -= 1.0
		guard += 1
		_step_minute()
		if paused_for_decision:
			_minute_acc = 0.0
			break


func _step_minute() -> void:
	time.step()
	var now := time.abs_minute()
	betting.step(now)
	jobs.step(now)
	if business != null:
		business.step_minute()
	if time.minute % 60 == 0:
		_on_hour()
	if time.minute % 10 == 0:
		missions.evaluate()
	if time.day_over():
		end_day()


func _on_hour() -> void:
	for s in [employees, business, online, competition, promotions, events]:
		if s != null and s.has_method("hourly"):
			s.hourly()


func _snapshot_day() -> void:
	_day_snapshot = {
		"rep": reputation.value,
		"net_worth": economy.net_worth(),
		"xp": progression.total_xp,
		"customers_new": stat("customers_new"),
		"customers_lost": stat("customers_lost"),
		"customers_served": stat("customers_served"),
	}


## Fechamento do dia: cobra despesas recorrentes, gera relatório, checa falência.
func end_day() -> void:
	if jobs.is_shift():
		jobs.step(time.abs_minute() + 100000)
	var costs: Dictionary = {}
	for s in [business, employees, properties, licenses, online, loans, promotions, competition]:
		if s != null and s.has_method("collect_daily_costs"):
			s.collect_daily_costs(costs, true)
	for cat in costs:
		economy.charge(float(costs[cat]), cat)
	var biz_profit := economy.business_profit_today()
	if has_business() and biz_profit > 0.0:
		var tax := roundf(biz_profit * float(GameData.balance("tax_rate", 0.06)))
		economy.charge(tax, EconomySystem.TAX)
		biz_profit -= tax
	if has_business():
		if biz_profit > 0.0:
			add_stat("profitable_days")
			progression.add_xp(GameData.xp_value("profitable_day") + mini(200, int(biz_profit / 250.0)))
	for s in [competition, employees, customers, online, properties, events]:
		if s != null and s.has_method("daily"):
			s.daily()
	reputation.daily()
	loans.daily(economy.cash < 0.0)
	var summary := economy.close_day()
	summary["biz_profit"] = biz_profit
	var report := _build_report(summary)
	last_report = report
	_check_bankruptcy(report)
	time.next_day()
	reputation.start_day()
	betting.start_day()
	progression.xp_today = 0
	for s in [business, customers, employees, events]:
		if s != null and s.has_method("start_day"):
			s.start_day()
	_snapshot_day()
	missions.evaluate()
	day_ended.emit(report)


func _build_report(summary: Dictionary) -> Dictionary:
	var exp_cats: Dictionary = summary.expense
	var inc_cats: Dictionary = summary.income
	var biggest_cost := ""
	var biggest_cost_v := 0.0
	for k in exp_cats:
		if k in EconomySystem.NON_OPERATIONAL:
			continue
		if float(exp_cats[k]) > biggest_cost_v:
			biggest_cost_v = float(exp_cats[k])
			biggest_cost = k
	var best := ""
	var best_v := 0.0
	for k in inc_cats:
		if k in EconomySystem.NON_OPERATIONAL:
			continue
		if float(inc_cats[k]) > best_v:
			best_v = float(inc_cats[k])
			best = k
	var problems: Array = []
	var abandoned := stat("customers_abandoned") - float(_day_snapshot.get("abandoned", stat("customers_abandoned")))
	if customers != null:
		abandoned = float(customers.today.get("abandoned", 0))
		if abandoned > 0:
			problems.append([abandoned * 3.0, "%d clientes desistiram da fila" % int(abandoned)])
		var turned := float(customers.today.get("turned_away", 0))
		if turned > 0:
			problems.append([turned * 2.0, "%d clientes não couberam no estabelecimento" % int(turned)])
	if betting.book_today.payouts > betting.book_today.stakes and betting.book_today.bets > 0:
		problems.append([(betting.book_today.payouts - betting.book_today.stakes) / 50.0, "Os prêmios pagos superaram as apostas recebidas"])
	if economy.cash < 0:
		problems.append([999.0, "Caixa negativo! Risco de falência"])
	var rep_drop := reputation.value - float(_day_snapshot.rep)
	if rep_drop < -1.0:
		var worst_reason := ""
		var worst_v := 0.0
		for r in reputation.today_changes:
			if float(reputation.today_changes[r]) < worst_v:
				worst_v = float(reputation.today_changes[r])
				worst_reason = r
		problems.append([absf(rep_drop) * 5.0, "Reputação caiu (%s)" % worst_reason])
	problems.sort_custom(func(a, b): return a[0] > b[0])
	var exposure := betting.total_exposure()
	return {
		"day": summary.day,
		"revenue": summary.revenue,
		"expenses": summary.expenses,
		"profit": summary.profit,
		"biz_profit": summary.biz_profit,
		"investments": summary.investments,
		"income": inc_cats,
		"expense": exp_cats,
		"new_customers": int(stat("customers_new") - float(_day_snapshot.customers_new)),
		"lost_customers": int(stat("customers_lost") - float(_day_snapshot.customers_lost)),
		"served": int(stat("customers_served") - float(_day_snapshot.customers_served)),
		"rep_from": float(_day_snapshot.rep),
		"rep_to": reputation.value,
		"net_worth": economy.net_worth(),
		"cash": economy.cash,
		"debt": loans.total_debt(),
		"exposure": exposure.worst_net,
		"xp": progression.total_xp - int(_day_snapshot.xp),
		"biggest_cost": "%s (%s)" % [biggest_cost, Fmt.money(biggest_cost_v)] if biggest_cost != "" else "—",
		"best_result": "%s (%s)" % [best, Fmt.money(best_v)] if best != "" else "—",
		"biggest_problem": str(problems[0][1]) if problems.size() > 0 else "Nenhum problema grave",
	}


# --- Falência ----------------------------------------------------------------------

func _check_bankruptcy(report: Dictionary) -> void:
	if economy.cash >= 0.0:
		negative_days = 0
		return
	# Cheque especial: saldo negativo paga juros diários
	var interest := roundf(-economy.cash * 0.015)
	economy.charge(interest, EconomySystem.LOAN)
	var grace := int(GameData.balance("bankruptcy_grace_days", 3))
	var insolvent := economy.net_worth() < 0.0 or -economy.cash > loans.credit_limit()
	if not insolvent:
		negative_days = 0
		report["warning"] = "Você está no cheque especial (juros de 1,5%% ao dia: %s hoje). Volte ao azul logo." % Fmt.money(interest)
		notify("Cheque especial: juros de %s hoje." % Fmt.money(interest), "warning")
		return
	negative_days += 1
	if negative_days >= grace:
		declare_bankruptcy()
	else:
		notify("ALERTA: dívidas maiores que seu patrimônio! %d dia(s) até a falência." % (grace - negative_days), "error")
		report["warning"] = "Insolvência: %d dia(s) para regularizar antes da falência. Venda ativos, faça empréstimos ou trabalhe." % (grace - negative_days)


func declare_bankruptcy() -> void:
	var recovered := 0.0
	if business != null:
		recovered += business.liquidate()
	if properties != null:
		recovered += properties.liquidate()
	if employees != null:
		employees.dismiss_all()
	if online != null:
		online.shutdown()
	# Ativos liquidados abatem a dívida; o restante é renegociado.
	var cash_after := economy.cash + recovered
	var debt := loans.total_debt()
	loans.loans = []
	var remaining_debt := maxf(0.0, debt - maxf(0.0, cash_after)) + maxf(0.0, -cash_after)
	remaining_debt = roundf(remaining_debt * 0.5)
	economy.cash = float(GameData.balance("recovery_cash", 300))
	if remaining_debt > 0:
		loans.loans.append({"id": loans.next_id, "name": "Dívida renegociada", "principal": remaining_debt, "total": remaining_debt,
			"remaining": remaining_debt, "installment": ceilf(remaining_debt / 60.0), "days_left": 60, "rate": 0.0})
		loans.next_id += 1
	loans.credit_score = 20.0
	licenses.owned = licenses.owned.filter(func(l): return l == "basica")
	reputation.value = maxf(25.0, reputation.value - 20.0)
	recovery_mode = true
	negative_days = 0
	add_stat("bankruptcies")
	missions.rollback_to("cap3")
	notify("FALÊNCIA! Você perdeu seus ativos. MODO RECUPERAÇÃO ativado.", "error")
	add_message("Mentor", "Todo grande empresário já caiu. Trabalhos pagam um bônus de recuperação. Junte capital e reabra sua banca.")
	went_bankrupt.emit({"recovered": recovered, "remaining_debt": remaining_debt})
	business_changed.emit()
	staff_changed.emit()


func trigger_victory() -> void:
	if campaign_complete:
		return
	campaign_complete = true
	victory_reached.emit()


# --- Decisões (eventos com escolha) --------------------------------------------------

func request_decision(ev: Dictionary) -> void:
	if auto_decide:
		# Testes automáticos: escolhe a opção mais conservadora (a última)
		resolve_decision(ev, maxi(0, ev.get("options", []).size() - 1))
		return
	paused_for_decision = true
	decision_requested.emit(ev)


func resolve_decision(ev: Dictionary, option: int) -> void:
	paused_for_decision = false
	if events != null:
		events.resolve(ev, option)


# --- Save/Load ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := {
		"version": SAVE_VERSION, "seed": rng.seed, "rng_state": str(rng.state),
		"stats": stats, "messages": messages, "player_name": player_name, "brand_name": brand_name,
		"campaign_complete": campaign_complete, "recovery_mode": recovery_mode,
		"negative_days": negative_days, "last_report": last_report, "day_snapshot": _day_snapshot,
	}
	d["time"] = time.to_dict()
	d["economy"] = economy.to_dict()
	d["reputation"] = reputation.to_dict()
	d["progression"] = progression.to_dict()
	d["betting"] = betting.to_dict()
	d["jobs"] = jobs.to_dict()
	d["licenses"] = licenses.to_dict()
	d["loans"] = loans.to_dict()
	d["missions"] = missions.to_dict()
	for key in ["business", "customers", "employees", "properties", "competition", "online", "events", "promotions"]:
		var s = get(key)
		if s != null:
			d[key] = s.to_dict()
	return d


func from_dict(d: Dictionary) -> void:
	new_game(str(d.get("player_name", "Você")), str(d.get("brand_name", "Fortuna Bet")))
	rng.seed = int(d.get("seed", 0))
	rng.state = int(str(d.get("rng_state", "0")))
	stats = d.get("stats", {})
	messages = d.get("messages", [])
	campaign_complete = bool(d.get("campaign_complete", false))
	recovery_mode = bool(d.get("recovery_mode", false))
	negative_days = int(d.get("negative_days", 0))
	last_report = d.get("last_report", {})
	time.from_dict(d.get("time", {}))
	economy.from_dict(d.get("economy", {}))
	reputation.from_dict(d.get("reputation", {}))
	progression.from_dict(d.get("progression", {}))
	betting.from_dict(d.get("betting", {}))
	jobs.from_dict(d.get("jobs", {}))
	licenses.from_dict(d.get("licenses", {}))
	loans.from_dict(d.get("loans", {}))
	missions.from_dict(d.get("missions", {}))
	for key in ["business", "customers", "employees", "properties", "competition", "online", "events", "promotions"]:
		var s = get(key)
		if s != null and d.has(key):
			s.from_dict(d[key])
	_day_snapshot = d.get("day_snapshot", {})
	if _day_snapshot.is_empty():
		_snapshot_day()
	paused_for_decision = false
	business_changed.emit()
	staff_changed.emit()
	mission_changed.emit()
