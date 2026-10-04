class_name EconomySystem
extends RefCounted
## Sistema central de dinheiro. Toda entrada/saída passa por aqui com uma categoria,
## o que permite mostrar ao jogador exatamente para onde o dinheiro está indo.

# Receitas operacionais
const STAKES := "Apostas recebidas"
const CASINO := "Cassino"
const ONLINE := "Operação online"
const BRANCHES := "Filiais"
const RENT_INCOME := "Aluguéis recebidos"
const JOBS := "Trabalhos"
const PERSONAL_WIN := "Prêmios pessoais"
const REWARD := "Recompensas"
const EVENTS_IN := "Eventos (entrada)"
# Despesas operacionais
const PAYOUTS := "Prêmios pagos"
const CASINO_PAYOUTS := "Prêmios do cassino"
const RENT := "Aluguel"
const ENERGY := "Energia"
const INTERNET := "Internet"
const SALARY := "Salários"
const MAINT := "Manutenção"
const TAX := "Impostos"
const LICENSE := "Taxas de licença"
const SECURITY := "Segurança"
const SERVICES := "Serviços"
const OPS := "Custos operacionais"
const PROMO := "Promoções"
const MARKETING := "Marketing"
const LOAN := "Parcelas de empréstimo"
const EVENTS := "Eventos"
const PERSONAL_BET := "Apostas pessoais"
# Investimentos / financiamento (não entram no lucro operacional)
const EQUIP := "Equipamentos"
const PROPERTY := "Compra de imóveis"
const EXPANSION := "Expansão"
const LICENSE_BUY := "Compra de licenças"
const ACQUISITION := "Aquisições"
const LOAN_IN := "Empréstimos recebidos"
const ASSET_SALE := "Venda de ativos"

const NON_OPERATIONAL := [EQUIP, PROPERTY, EXPANSION, LICENSE_BUY, ACQUISITION, LOAN_IN, ASSET_SALE]
const PERSONAL := [JOBS, PERSONAL_WIN, PERSONAL_BET, REWARD]

var sim: Simulation
var cash := 0.0
var today_income := {}
var today_expense := {}
var history: Array = []
var lifetime_income := 0.0
var lifetime_expense := 0.0


func _init(s) -> void:
	sim = s


func reset() -> void:
	cash = float(GameData.balance("start_cash", 100))
	today_income = {}
	today_expense = {}
	history = []
	lifetime_income = 0.0
	lifetime_expense = 0.0


func earn(amount: float, category: String) -> void:
	if amount <= 0.0 or is_nan(amount):
		return
	cash += amount
	today_income[category] = float(today_income.get(category, 0.0)) + amount
	if not category in NON_OPERATIONAL:
		lifetime_income += amount
	sim.cash_changed.emit(cash)


## Tenta gastar. Retorna false (e avisa) se não houver dinheiro suficiente.
func spend(amount: float, category: String, silent: bool = false) -> bool:
	if amount <= 0.0:
		return true
	if cash + 0.001 < amount:
		if not silent:
			sim.notify("Dinheiro insuficiente: faltam %s" % Fmt.money(amount - cash), "error")
		return false
	_take(amount, category)
	return true


## Cobrança obrigatória (pode deixar o caixa negativo): despesas fixas, prêmios, parcelas.
func charge(amount: float, category: String) -> void:
	if amount <= 0.0 or is_nan(amount):
		return
	_take(amount, category)


func _take(amount: float, category: String) -> void:
	cash -= amount
	today_expense[category] = float(today_expense.get(category, 0.0)) + amount
	if not category in NON_OPERATIONAL:
		lifetime_expense += amount
	sim.cash_changed.emit(cash)


func can_afford(amount: float) -> bool:
	return cash + 0.001 >= amount


static func _sum(d: Dictionary, include_non_op: bool, only_business: bool = false) -> float:
	var t := 0.0
	for k in d:
		if not include_non_op and k in NON_OPERATIONAL:
			continue
		if only_business and k in PERSONAL:
			continue
		t += float(d[k])
	return t


func revenue_today() -> float:
	return _sum(today_income, false)


func expenses_today() -> float:
	return _sum(today_expense, false)


func business_profit_today() -> float:
	return _sum(today_income, false, true) - _sum(today_expense, false, true)


func net_worth() -> float:
	return cash + sim.asset_value() - sim.loans.total_debt()


func close_day() -> Dictionary:
	var summary := {
		"day": sim.time.day,
		"income": today_income.duplicate(),
		"expense": today_expense.duplicate(),
		"revenue": revenue_today(),
		"expenses": expenses_today(),
		"profit": revenue_today() - expenses_today(),
		"business_profit": business_profit_today(),
		"investments": _sum(today_expense, true) - expenses_today(),
	}
	history.append({"day": summary.day, "revenue": summary.revenue, "expenses": summary.expenses, "profit": summary.profit, "cash": cash})
	if history.size() > 60:
		history.pop_front()
	today_income = {}
	today_expense = {}
	return summary


func to_dict() -> Dictionary:
	return {"cash": cash, "today_income": today_income, "today_expense": today_expense, "history": history,
		"lifetime_income": lifetime_income, "lifetime_expense": lifetime_expense}


func from_dict(d: Dictionary) -> void:
	cash = float(d.get("cash", 0.0))
	today_income = d.get("today_income", {})
	today_expense = d.get("today_expense", {})
	history = d.get("history", [])
	lifetime_income = float(d.get("lifetime_income", 0.0))
	lifetime_expense = float(d.get("lifetime_expense", 0.0))
