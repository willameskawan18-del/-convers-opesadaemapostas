class_name CompetitorCard
## Cartão com dados de um concorrente (reutilizado no app e na aba Concorrência).

const STATE_NAMES := {"MONITOR": "Monitorando o mercado", "ANALYZE": "Analisando a concorrência", "PROMOTION": "Em PROMOÇÃO",
	"EXPANSION": "Expandindo", "NORMAL_OPERATION": "Operação normal", "CLOSED": "Fechada", "FILIAL": "Sua filial"}


static func build(parent: Control, s: Simulation, id: String, ui, detailed: bool) -> void:
	var cs := s.competition
	var c := cs.get_comp(id)
	if c.is_empty():
		parent.add_child(UiKit.label("Concorrente desconhecido.", 15, UiKit.MUTED))
		return
	var data := GameData.find("competitors", "competitors", id)
	var card := UiKit.card(parent, UiKit.PANEL2, UiKit.RED.darkened(0.4) if c.state == "PROMOTION" else Color(1, 1, 1, 0.05))
	var h := UiKit.hbox()
	card.add_child(h)
	h.add_child(UiKit.expand(UiKit.label(str(c.name), 19, UiKit.GOLD)))
	h.add_child(UiKit.label(str(STATE_NAMES.get(str(c.state), c.state)), 14, UiKit.RED if c.state == "PROMOTION" else UiKit.MUTED))
	if detailed:
		card.add_child(UiKit.label(str(data.get("desc", "")), 13, UiKit.MUTED, true))
	if c.status == "acquired":
		UiKit.kv(card, "Renda diária da filial", Fmt.money(cs.branch_income(c)), UiKit.GREEN)
		return
	if c.status == "closed":
		card.add_child(UiKit.label("Fechou as portas.", 15, UiKit.RED))
		return
	UiKit.kv(card, "Capital estimado", Fmt.money(float(c.capital)), UiKit.money_color(float(c.capital)))
	UiKit.kv(card, "Reputação", "%d" % int(c.reputation), UiKit.BLUE)
	UiKit.kv(card, "Margem das odds", Fmt.pct(float(c.margin)) + ("  (promoção)" if int(c.promo_days) > 0 else ""))
	UiKit.kv(card, "Porte / estratégia", "%d / %s" % [int(c.size), c.strategy])
	UiKit.kv(card, "Agressividade", "%d%%" % int(float(c.aggression) * 100))
	UiKit.kv(card, "Resultado de ontem", Fmt.signed_money(float(c.profit_yesterday)), UiKit.money_color(float(c.profit_yesterday)))
	if c.get("casino", false) and detailed:
		card.add_child(UiKit.button("Entrar no salão de jogos", func():
			ui.open_app("cassino", id), true))
	var why := cs.acquire_block_reason(c)
	var price := cs.acquisition_price(c)
	var row := UiKit.hbox()
	card.add_child(row)
	row.add_child(UiKit.expand(UiKit.label("Comprar a empresa: " + Fmt.money(price) + ("" if why == "" else "  — " + why), 13, UiKit.MUTED if why != "" else UiKit.TEXT, true)))
	row.add_child(UiKit.button("Adquirir", func():
		cs.acquire(id)
		ui.refresh(), false, why == ""))
