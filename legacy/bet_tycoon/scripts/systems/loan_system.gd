class_name LoanSystem
extends RefCounted
## Banco: empréstimos com principal, taxa, prazo, parcela diária e custo total.

var sim: Simulation
var loans: Array = []
var next_id := 1
var credit_score := 60.0
var missed_today := false


func _init(s) -> void:
	sim = s


func reset() -> void:
	loans = []
	next_id = 1
	credit_score = 60.0


func offers() -> Array:
	return GameData.list("loans", "offers")


func total_debt() -> float:
	var t := 0.0
	for l in loans:
		t += float(l.remaining)
	return t


func daily_installments() -> float:
	var t := 0.0
	for l in loans:
		t += minf(float(l.installment), float(l.remaining))
	return t


## Empréstimos simultâneos: 1 no começo, 2 no nível 6, 3 no nível 12.
func max_active_loans() -> int:
	var lv: int = sim.progression.level
	return 3 if lv >= 12 else (2 if lv >= 6 else 1)


func credit_limit() -> float:
	var base: float = sim.asset_value() + maxf(0.0, sim.economy.cash)
	return maxf(2000.0, base * 0.8 + sim.progression.level * 3000.0) * clampf(credit_score / 60.0, 0.3, 1.5)


func offer_status(o: Dictionary) -> String:
	if sim.progression.level < int(o.get("min_level", 1)):
		return "Requer nível %d" % int(o.min_level)
	if o.get("requires_business", false) and not sim.has_business():
		return "Requer um negócio aberto"
	var max_loans := max_active_loans()
	if loans.size() >= max_loans:
		return "Você já tem %d empréstimo(s) ativo(s). Quite antes de pegar outro%s" % [loans.size(), "" if max_loans >= 3 else " (mais vagas no nível %d)" % (6 if max_loans == 1 else 12)]
	for l in loans:
		if str(l.get("offer_id", "")) == str(o.id):
			return "Você já tem este empréstimo ativo"
	var total := float(o.principal) * (1.0 + float(o.rate))
	if total_debt() + total > credit_limit():
		return "Acima do seu limite de crédito (%s)" % Fmt.money(credit_limit())
	return ""


func take(offer_id: String) -> bool:
	var o := GameData.find("loans", "offers", offer_id)
	if o.is_empty():
		return false
	var why := offer_status(o)
	if why != "":
		sim.notify(why, "error")
		return false
	var principal := float(o.principal)
	var total := roundf(principal * (1.0 + float(o.rate)))
	var term := int(o.term_days)
	loans.append({"id": next_id, "offer_id": str(o.id), "name": o.name, "principal": principal, "total": total,
		"remaining": total, "installment": ceilf(total / term), "days_left": term, "rate": float(o.rate)})
	next_id += 1
	sim.economy.earn(principal, EconomySystem.LOAN_IN)
	sim.notify("Empréstimo aprovado: +%s (total a pagar %s)" % [Fmt.money(principal), Fmt.money(total)], "cash")
	sim.after_action()
	return true


func payoff_amount(l: Dictionary) -> float:
	# Quitação antecipada com desconto de parte dos juros restantes.
	var interest_share := float(l.remaining) * (float(l.rate) / (1.0 + float(l.rate)))
	return roundf(float(l.remaining) - interest_share * 0.5)


func pay_off(loan_id: int) -> bool:
	for l in loans:
		if int(l.id) == loan_id:
			var amt := payoff_amount(l)
			if not sim.economy.spend(amt, EconomySystem.LOAN):
				return false
			loans.erase(l)
			credit_score = minf(100.0, credit_score + 4.0)
			sim.notify("Empréstimo quitado!", "cash")
			sim.after_action()
			return true
	return false


func collect_daily_costs(costs: Dictionary, apply: bool = true) -> void:
	var done: Array = []
	for l in loans:
		var pay := minf(float(l.installment), float(l.remaining))
		costs[EconomySystem.LOAN] = float(costs.get(EconomySystem.LOAN, 0.0)) + pay
		if not apply:
			continue
		l.remaining = float(l.remaining) - pay
		l.days_left = int(l.days_left) - 1
		if float(l.remaining) <= 0.5:
			done.append(l)
	for l in done:
		loans.erase(l)
		credit_score = minf(100.0, credit_score + 3.0)
		sim.notify("Empréstimo \"%s\" totalmente pago." % l.name, "cash")


## Chamado após o fechamento do dia: caixa negativo prejudica o crédito.
func daily(cash_negative: bool) -> void:
	if cash_negative:
		credit_score = maxf(0.0, credit_score - 6.0)
	else:
		credit_score = minf(100.0, credit_score + 0.3)


func to_dict() -> Dictionary:
	return {"loans": loans, "next_id": next_id, "credit_score": credit_score}


func from_dict(d: Dictionary) -> void:
	loans = d.get("loans", [])
	for l in loans:
		l.id = int(l.id)
		l.days_left = int(l.days_left)
	next_id = int(d.get("next_id", 1))
	credit_score = float(d.get("credit_score", 60.0))
