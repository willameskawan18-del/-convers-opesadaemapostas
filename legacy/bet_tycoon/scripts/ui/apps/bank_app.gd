extends AppBase
## Banco: saldo, patrimônio, empréstimos e dívidas.


func title() -> String:
	return "Banco Central"


func subtitle() -> String:
	return "Saldo, crédito e empréstimos"


func build(body: VBoxContainer) -> void:
	var s := sim()
	var c := UiKit.card(body)
	UiKit.kv(c, "Saldo em conta", Fmt.money(s.economy.cash), UiKit.money_color(s.economy.cash))
	UiKit.kv(c, "Patrimônio líquido", Fmt.money(s.economy.net_worth()))
	UiKit.kv(c, "Dívida total", Fmt.money(s.loans.total_debt()), UiKit.RED if s.loans.total_debt() > 0 else UiKit.TEXT)
	UiKit.kv(c, "Parcelas por dia", Fmt.money(s.loans.daily_installments()))
	UiKit.kv(c, "Score de crédito", "%d / 100" % int(s.loans.credit_score))
	UiKit.kv(c, "Limite de crédito", Fmt.money(s.loans.credit_limit()))
	if s.loans.loans.size() > 0:
		body.add_child(UiKit.heading("Empréstimos ativos", 18))
		for l in s.loans.loans:
			var lc := UiKit.card(body)
			var h := UiKit.hbox()
			lc.add_child(h)
			var info := UiKit.vbox(2)
			h.add_child(UiKit.expand(info))
			info.add_child(UiKit.label(str(l.name), 16))
			info.add_child(UiKit.label("Restante %s  |  Parcela %s/dia  |  %d dias" % [Fmt.money(float(l.remaining)), Fmt.money(float(l.installment)), int(l.days_left)], 13, UiKit.MUTED))
			var pay := s.loans.payoff_amount(l)
			h.add_child(UiKit.button("Quitar (%s)" % Fmt.money(pay), func():
				s.loans.pay_off(int(l.id))
				ui.refresh(), false, s.economy.can_afford(pay)))
	body.add_child(UiKit.heading("Ofertas de crédito", 18))
	body.add_child(UiKit.label("Crédito acelera o crescimento, mas as parcelas são cobradas todo dia — mesmo com caixa negativo.", 13, UiKit.MUTED, true))
	for o in s.loans.offers():
		var oc := UiKit.card(body)
		var h2 := UiKit.hbox()
		oc.add_child(h2)
		var info2 := UiKit.vbox(2)
		h2.add_child(UiKit.expand(info2))
		var total := roundf(float(o.principal) * (1.0 + float(o.rate)))
		info2.add_child(UiKit.label("%s — %s" % [o.name, Fmt.money(float(o.principal))], 16))
		info2.add_child(UiKit.label("Juros %s  |  %d dias  |  Parcela %s/dia  |  Custo total %s" % [Fmt.pct(float(o.rate), 0), int(o.term_days), Fmt.money(ceilf(total / float(o.term_days))), Fmt.money(total)], 13, UiKit.MUTED, true))
		var why := s.loans.offer_status(o)
		if why != "":
			info2.add_child(UiKit.label(why, 13, UiKit.ORANGE))
		h2.add_child(UiKit.button("Contratar", func():
			s.loans.take(str(o.id))
			ui.refresh(), true, why == ""))
