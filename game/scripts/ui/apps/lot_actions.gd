class_name LotActions
## Botões de ação de um imóvel (usados no app de imóvel e na aba Propriedades).


static func add(parent: Control, s: Simulation, id: String, ui) -> void:
	var ps := s.properties
	var p := ps.data(id)
	var contract := str(ps.contracts.get(id, ""))
	var col := UiKit.vbox(4)
	parent.add_child(col)
	if contract == "":
		if float(p.get("rent", 0)) > 0:
			var why := ps.rent_block_reason(id)
			var b := UiKit.button("Alugar", func():
				ps.rent(id)
				ui.refresh(), true, why == "")
			b.tooltip_text = why
			col.add_child(b)
			if why != "":
				col.add_child(UiKit.label(why, 12, UiKit.ORANGE))
		var why2 := ps.buy_block_reason(id)
		col.add_child(UiKit.button("Comprar (%s)" % Fmt.money(ps.price(id)), func():
			ps.buy(id)
			ui.refresh(), float(p.get("rent", 0)) <= 0, why2 == ""))
	elif contract == "rented":
		var why3 := ps.buy_block_reason(id)
		col.add_child(UiKit.button("Comprar (%s)" % Fmt.money(ps.price(id)), func():
			ps.buy(id)
			ui.refresh(), true, why3 == ""))
		if not ps.in_use(id):
			col.add_child(UiKit.button("Encerrar aluguel", func():
				ps.end_rent(id)
				ui.refresh()))
	elif contract == "owned" and not ps.in_use(id):
		col.add_child(UiKit.button("Vender (%s)" % Fmt.money(ps.market_value(id) * 0.85), func():
			ps.sell(id)
			ui.refresh()))
