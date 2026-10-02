extends AppBase
## Painel de administração (computador da banca / celular). Abas consistentes; cada aba é
## uma função build_<id>. Abas de negócio só aparecem quando há sistemas/negócio.

const TABS := [
	["overview", "Visão Geral"], ["finance", "Finanças"], ["bets", "Apostas"], ["customers", "Clientes"],
	["staff", "Funcionários"], ["equipment", "Equipamentos"], ["properties", "Propriedades"],
	["licenses", "Licenças"], ["promotions", "Promoções"], ["risk", "Risco"], ["reputation", "Reputação"],
	["competition", "Concorrência"], ["casino", "Cassino"],
]

var tab := "overview"


func title() -> String:
	return "Administração — " + sim().brand_name


func subtitle() -> String:
	return "Relatórios e gestão do negócio"


func window_size() -> Vector2:
	return Vector2(1040, 620)


func live() -> bool:
	return tab in ["overview", "bets", "risk", "customers"]


func build(body: VBoxContainer) -> void:
	if arg is String and arg != "":
		tab = arg
		arg = null
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 4)
	bar.add_theme_constant_override("v_separation", 4)
	body.add_child(bar)
	for t in TABS:
		var id: String = t[0]
		if not has_method("build_" + id):
			continue
		var b := UiKit.button(t[1], func():
			tab = id
			ui.refresh(), id == tab)
		bar.add_child(b)
	UiKit.sep(body)
	if has_method("build_" + tab):
		call("build_" + tab, body)


func _need_business(body: VBoxContainer) -> bool:
	if sim().has_business():
		return true
	body.add_child(UiKit.label("Você ainda não tem uma banca. Junte capital, obtenha o Alvará Municipal e alugue a Sala Comercial ao lado do mercado.", 16, UiKit.MUTED, true))
	return false


# --- Visão geral ----------------------------------------------------------------

func build_overview(body: VBoxContainer) -> void:
	var s := sim()
	var row := UiKit.hbox(12)
	body.add_child(row)
	_stat(row, "Caixa", Fmt.money(s.economy.cash), UiKit.money_color(s.economy.cash))
	_stat(row, "Patrimônio líquido", Fmt.money(s.economy.net_worth()), UiKit.GOLD)
	_stat(row, "Receita hoje", Fmt.money(s.economy.revenue_today()), UiKit.GREEN)
	_stat(row, "Despesas hoje", Fmt.money(s.economy.expenses_today()), UiKit.RED)
	var row2 := UiKit.hbox(12)
	body.add_child(row2)
	_stat(row2, "Reputação", "%d — %s" % [int(s.reputation.value), s.reputation.label()], UiKit.BLUE)
	_stat(row2, "Nível", "%d — %s" % [s.progression.level, s.progression.title()], UiKit.GOLD)
	_stat(row2, "Dívidas", Fmt.money(s.loans.total_debt()), UiKit.RED if s.loans.total_debt() > 0 else UiKit.TEXT)
	if s.has_business():
		var ex := s.betting.total_exposure()
		var lvl := s.betting.risk_level(ex.worst_net)
		_stat(row2, "Risco", lvl, UiKit.risk_color(lvl))
		var c := UiKit.card(body)
		c.add_child(UiKit.heading(s.business.stage_name(), 17))
		UiKit.kv(c, "Imóvel", s.properties.display_name(s.business.property_id))
		UiKit.kv(c, "Capacidade", "%d pessoas  |  %d guichê(s)" % [s.business.capacity(), s.business.counters()])
		UiKit.kv(c, "Funcionários", "%d / %d" % [s.employees.staff.size(), s.business.max_staff()])
		UiKit.kv(c, "Clientes atendidos hoje", str(s.customers.today.get("served", 0)))
		if s.competition != null:
			UiKit.kv(c, "Participação de mercado", Fmt.pct(s.competition.player_share()))
	else:
		body.add_child(UiKit.label("Sem negócio aberto. Siga os objetivos da campanha para abrir sua primeira banca.", 15, UiKit.MUTED, true))
	if not s.last_report.is_empty():
		var r := s.last_report
		var c2 := UiKit.card(body)
		c2.add_child(UiKit.heading("Último relatório (Dia %d)" % int(r.day), 16))
		UiKit.kv(c2, "Lucro operacional", Fmt.money(float(r.profit)), UiKit.money_color(float(r.profit)))
		UiKit.kv(c2, "Maior custo", str(r.biggest_cost))
		UiKit.kv(c2, "Maior problema", str(r.biggest_problem))


func _stat(parent: Control, label: String, value: String, color: Color) -> void:
	var c := UiKit.card(parent)
	c.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(UiKit.label(label.to_upper(), 11, UiKit.MUTED))
	c.add_child(UiKit.label(value, 18, color))


# --- Finanças --------------------------------------------------------------------

func build_finance(body: VBoxContainer) -> void:
	var s := sim()
	var cols := UiKit.hbox(14)
	body.add_child(cols)
	var col1 := UiKit.vbox()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(col1)
	var inc := UiKit.card(col1)
	inc.add_child(UiKit.heading("Entradas de hoje", 16))
	_cat_list(inc, s.economy.today_income, UiKit.GREEN)
	var col2 := UiKit.vbox()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(col2)
	var exp := UiKit.card(col2)
	exp.add_child(UiKit.heading("Saídas de hoje", 16))
	_cat_list(exp, s.economy.today_expense, UiKit.RED)
	var fc := UiKit.card(body)
	fc.add_child(UiKit.heading("Custos fixos previstos (cobrados à meia-noite)", 16))
	var costs := s.forecast_daily_costs()
	if costs.is_empty():
		fc.add_child(UiKit.label("Nenhum custo fixo.", 14, UiKit.MUTED))
	var total := 0.0
	for k in costs:
		UiKit.kv(fc, k, Fmt.money(float(costs[k])), UiKit.RED)
		total += float(costs[k])
	UiKit.kv(fc, "TOTAL / dia", Fmt.money(total), UiKit.GOLD)
	body.add_child(UiKit.heading("Histórico (últimos dias)", 16))
	var hist: Array = s.economy.history.duplicate()
	hist.reverse()
	if hist.is_empty():
		body.add_child(UiKit.label("Ainda não há dias encerrados.", 14, UiKit.MUTED))
	for h in hist.slice(0, 10):
		body.add_child(UiKit.label("Dia %d — receita %s | despesas %s | resultado %s | caixa %s" % [int(h.day), Fmt.money(float(h.revenue)), Fmt.money(float(h.expenses)), Fmt.signed_money(float(h.profit)), Fmt.money(float(h.cash))], 14, UiKit.money_color(float(h.profit))))


func _cat_list(parent: Control, d: Dictionary, color: Color) -> void:
	if d.is_empty():
		parent.add_child(UiKit.label("Nada ainda.", 14, UiKit.MUTED))
		return
	var keys := d.keys()
	keys.sort_custom(func(a, b): return float(d[a]) > float(d[b]))
	for k in keys:
		var tag := "  (investimento)" if k in EconomySystem.NON_OPERATIONAL else ""
		UiKit.kv(parent, str(k) + tag, Fmt.money(float(d[k])), color)


# --- Licenças ----------------------------------------------------------------------

func build_licenses(body: VBoxContainer) -> void:
	var s := sim()
	for l in s.licenses.all():
		var c := UiKit.card(body, UiKit.PANEL2, UiKit.GREEN if s.licenses.has(str(l.id)) else Color(1, 1, 1, 0.05))
		var h := UiKit.hbox()
		c.add_child(h)
		var info := UiKit.vbox(3)
		h.add_child(UiKit.expand(info))
		info.add_child(UiKit.label(str(l.name), 17, UiKit.GREEN if s.licenses.has(str(l.id)) else UiKit.TEXT))
		info.add_child(UiKit.label(str(l.desc), 13, UiKit.MUTED, true))
		info.add_child(UiKit.label("Taxa de manutenção: %s/dia" % Fmt.money(float(l.get("daily_fee", 0))), 13, UiKit.MUTED))
		if s.licenses.has(str(l.id)):
			h.add_child(UiKit.label("OBTIDA", 16, UiKit.GREEN))
			continue
		for r in s.licenses.requirements(str(l.id)):
			UiKit.status_line(info, r.ok, r.text)
		h.add_child(UiKit.button("Obter", func():
			s.licenses.buy(str(l.id))
			ui.refresh(), true, s.licenses.can_buy(str(l.id))))


# --- Apostas da banca --------------------------------------------------------------

func build_bets(body: VBoxContainer) -> void:
	if not _need_business(body):
		return
	var s := sim()
	var b := s.business
	var c := UiKit.card(body)
	var h := UiKit.hbox()
	c.add_child(h)
	var info := UiKit.vbox(2)
	h.add_child(UiKit.expand(info))
	var st := "ABERTA" if b.is_open() else ("FECHADA (horário 09:00–23:00)" if not b.manually_closed else "FECHADA POR VOCÊ")
	if b.active and not b.has_required_equipment():
		st = "SEM BALCÃO/COMPUTADOR"
	info.add_child(UiKit.label("Banca: " + st, 17, UiKit.GREEN if b.is_open() else UiKit.RED))
	info.add_child(UiKit.label("Sem atendentes, você precisa ficar atrás do balcão para atender.", 13, UiKit.MUTED))
	h.add_child(UiKit.button("Reabrir" if b.manually_closed else "Fechar banca", func():
		b.manually_closed = not b.manually_closed
		ui.refresh()))
	# Margem das odds
	var mc := UiKit.card(body)
	mc.add_child(UiKit.heading("Configuração de odds", 16))
	var mh := UiKit.hbox()
	mc.add_child(mh)
	mh.add_child(UiKit.expand(UiKit.label("Margem da casa: %s   (mercado: %s)" % [Fmt.pct(b.margin), Fmt.pct(s.market_margin())], 16)))
	mh.add_child(UiKit.button("- 0,5%", func():
		b.set_margin(b.margin - 0.005)
		ui.refresh()))
	mh.add_child(UiKit.button("+ 0,5%", func():
		b.set_margin(b.margin + 0.005)
		ui.refresh()))
	var attract := b.odds_factor()
	mc.add_child(UiKit.label("Atratividade das odds: %s  |  Odds maiores (margem menor) atraem clientes e aumentam a exposição." % ("ALTA" if attract > 1.2 else ("NORMAL" if attract > 0.85 else "BAIXA")), 13, UiKit.MUTED, true))
	var sh := UiKit.hbox()
	mc.add_child(sh)
	sh.add_child(UiKit.expand(UiKit.label("Aposta máxima por bilhete: " + Fmt.money(b.max_stake), 16)))
	for delta in [-100, -10, 10, 100]:
		sh.add_child(UiKit.button(("%+d" % delta), func():
			b.set_max_stake(b.max_stake + delta * (10 if absi(delta) == 100 and b.max_stake >= 1000 else 1))
			ui.refresh()))
	if s.employees.count_role("analista") > 0:
		mc.add_child(UiKit.button("Balanceamento automático: " + ("LIGADO" if b.auto_balance else "DESLIGADO"), func():
			b.auto_balance = not b.auto_balance
			ui.refresh(), b.auto_balance))
	else:
		mc.add_child(UiKit.label("Contrate um analista para liberar o balanceamento automático de risco.", 13, UiKit.MUTED))
	# Exposição por evento
	body.add_child(UiKit.heading("EXPOSIÇÃO ATUAL", 18))
	var any := false
	for ev in s.betting.upcoming_events(40):
		var ex := s.betting.exposure(ev)
		if ex.bets == 0 and ev.status != "scheduled":
			continue
		if ex.bets == 0 and int(ev.day) != s.time.day:
			continue
		any = true
		var ec := UiKit.card(body)
		var eh := UiKit.hbox()
		ec.add_child(eh)
		eh.add_child(UiKit.expand(UiKit.label("%s  —  %s" % [ev.name, "AO VIVO" if ev.status == "live" else Fmt.hm(int(ev.start) % 1440)], 15, UiKit.GOLD if float(ev.hype) > 1.2 else UiKit.TEXT)))
		var lvl := s.betting.risk_level(maxf(0.0, ex.worst_net))
		eh.add_child(UiKit.label("Risco: " + lvl, 14, UiKit.risk_color(lvl)))
		ec.add_child(UiKit.label("Apostas recebidas: %s (%d bilhetes)  |  Possível pagamento: %s  |  Exposição: %s" % [Fmt.money(ex.stakes), ex.bets, Fmt.money(ex.worst_payout), Fmt.money(maxf(0.0, ex.worst_net))], 13, UiKit.MUTED, true))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		ec.add_child(flow)
		for i in ev.outcomes.size():
			var susp: bool = ev.suspended[i]
			var txt := "%s @ %s  |  paga %s%s" % [ev.outcomes[i], Fmt.odds(s.betting.shop_odds(ev, i)), Fmt.money(float(ex.payouts[i])), "  [SUSPENSO]" if susp else ""]
			var btn := UiKit.button(txt, func():
				ev.suspended[i] = not ev.suspended[i]
				ui.refresh(), false, ev.status == "scheduled")
			btn.tooltip_text = "Clique para suspender/reabrir apostas neste resultado"
			if susp:
				btn.add_theme_color_override("font_color", UiKit.RED)
			flow.add_child(btn)
	if not any:
		body.add_child(UiKit.label("Nenhuma aposta de cliente em aberto.", 14, UiKit.MUTED))
	var bt: Dictionary = s.betting.book_today
	UiKit.kv(body, "Hoje: apostas recebidas / prêmios pagos", "%s / %s" % [Fmt.money(float(bt.stakes)), Fmt.money(float(bt.payouts))])


# --- Clientes ----------------------------------------------------------------------

func build_customers(body: VBoxContainer) -> void:
	if not _need_business(body):
		return
	var s := sim()
	var cs := s.customers
	var row := UiKit.hbox(12)
	body.add_child(row)
	_stat(row, "Na fila", str(cs.queue_length()), UiKit.GOLD)
	_stat(row, "No local", "%d / %d" % [cs.inside_count(), s.business.capacity()], UiKit.TEXT)
	_stat(row, "Atendidos hoje", str(cs.today.served), UiKit.GREEN)
	_stat(row, "Desistências hoje", str(cs.today.abandoned), UiKit.RED)
	_stat(row, "Clientes ativos", str(cs.active_customers()), UiKit.BLUE)
	body.add_child(UiKit.label("Demanda estimada agora: %.1f clientes/hora  |  Recusados (lotado): %d  |  Não entraram (fila/desconfiança): %d" % [s.business.demand_per_hour(), int(cs.today.turned_away), int(cs.today.balked)], 13, UiKit.MUTED, true))
	body.add_child(UiKit.heading("Perfis por tipo", 16))
	var counts := {}
	for id in cs.pool:
		var p: Dictionary = cs.pool[id]
		if p.lost:
			continue
		counts[p.type] = int(counts.get(p.type, 0)) + 1
	for t in cs.types():
		if counts.has(t.id):
			UiKit.kv(body, str(t.name), str(counts[t.id]))
	body.add_child(UiKit.heading("Clientes frequentes", 16))
	var ids := cs.pool.keys()
	ids.sort_custom(func(a, b): return int(cs.pool[a].visits) > int(cs.pool[b].visits))
	for id in ids.slice(0, 12):
		var p: Dictionary = cs.pool[id]
		var t := cs.type_data(str(p.type))
		body.add_child(UiKit.label("%s (%s) — %d visitas, apostou %s, satisfação %d%%%s" % [p.name, t.get("name", ""), int(p.visits), Fmt.money(float(p.staked)), int(p.satisfaction), "  [PERDIDO]" if p.lost else ""], 13, UiKit.RED if p.lost else UiKit.TEXT, true))


# --- Funcionários ---------------------------------------------------------------------

func build_staff(body: VBoxContainer) -> void:
	if not _need_business(body):
		return
	var s := sim()
	var es := s.employees
	es.refresh_candidates()
	body.add_child(UiKit.label("Equipe: %d / %d  |  Folha diária: %s" % [es.staff.size(), s.business.max_staff(), Fmt.money(es.staff.reduce(func(a, e): return a + float(e.salary), 0.0))], 16, UiKit.GOLD))
	for e in es.staff:
		var c := UiKit.card(body)
		var h := UiKit.hbox()
		c.add_child(h)
		var info := UiKit.vbox(2)
		h.add_child(UiKit.expand(info))
		info.add_child(UiKit.label("%s — %s  [%s]%s" % [e.name, es.role_name(str(e.role)), e.state, "  (FALTOU HOJE)" if e.absent else ""], 16))
		info.add_child(UiKit.label("Salário %s/dia | Eficiência %d%% | Nível %d (%d XP) | Satisfação %d%% | Erro %s | Perfil: %s" % [Fmt.money(float(e.salary)), int(float(e.efficiency) * 100), int(e.level), int(e.experience), int(e.satisfaction), Fmt.pct(float(e.error_chance)), es.trait_data(str(e.trait)).get("name", "")], 13, UiKit.MUTED, true))
		var col := UiKit.vbox(4)
		h.add_child(col)
		col.add_child(UiKit.button("Treinar (%s)" % Fmt.money(es.train_cost(e)), func():
			es.train(str(e.id))
			ui.refresh(), false, s.economy.can_afford(es.train_cost(e))))
		col.add_child(UiKit.button("Aumento +15%", func():
			es.raise_salary(str(e.id))
			ui.refresh()))
		col.add_child(UiKit.button("Demitir", func():
			es.fire(str(e.id))
			ui.refresh()))
	body.add_child(UiKit.heading("Candidatos", 18))
	body.add_child(UiKit.label("Contratar custa 1 dia de salário. Funcionários melhores custam mais. Novos candidatos a cada 3 dias.", 13, UiKit.MUTED, true))
	for cnd in es.candidates:
		var c2 := UiKit.card(body)
		var h2 := UiKit.hbox()
		c2.add_child(h2)
		var info2 := UiKit.vbox(2)
		h2.add_child(UiKit.expand(info2))
		info2.add_child(UiKit.label("%s — %s" % [cnd.name, es.role_name(str(cnd.role))], 16))
		info2.add_child(UiKit.label("Salário %s/dia | Habilidade %d%% | Experiência nível %d | Perfil: %s" % [Fmt.money(float(cnd.salary)), int(float(cnd.efficiency) * 100), int(cnd.level), es.trait_data(str(cnd.trait)).get("name", "")], 13, UiKit.MUTED, true))
		info2.add_child(UiKit.label(str(es.role_data(str(cnd.role)).get("desc", "")), 12, UiKit.MUTED, true))
		var why := es.hire_block_reason(cnd)
		if why != "":
			info2.add_child(UiKit.label(why, 13, UiKit.ORANGE))
		h2.add_child(UiKit.button("Contratar", func():
			es.hire(str(cnd.id))
			ui.refresh(), true, why == ""))
	body.add_child(UiKit.button("Anunciar vaga (novos candidatos) — R$ 50", func():
		if s.economy.spend(50, EconomySystem.MARKETING):
			es.refresh_candidates(true)
		ui.refresh()))


# --- Equipamentos --------------------------------------------------------------------

func build_equipment(body: VBoxContainer) -> void:
	if not _need_business(body):
		return
	var s := sim()
	var b := s.business
	if not b.supplier_discount.is_empty() and int(b.supplier_discount.until) > s.time.abs_minute():
		body.add_child(UiKit.label("Desconto de fornecedor ativo: %s em todos os equipamentos!" % Fmt.pct(float(b.supplier_discount.pct), 0), 15, UiKit.GREEN))
	body.add_child(UiKit.heading("Seus equipamentos", 17))
	if b.equipment.is_empty():
		body.add_child(UiKit.label("Nenhum. Comece com um balcão simples e um computador básico.", 14, UiKit.ORANGE))
	for e in b.equipment:
		var d := b.item_data(str(e.id))
		var h := UiKit.hbox()
		body.add_child(h)
		h.add_child(UiKit.expand(UiKit.label("%s%s  (manutenção %s/dia)" % [d.name, "  — QUEBRADO" if e.broken else "", Fmt.money(float(d.get("maintenance", 0)))], 14, UiKit.RED if e.broken else UiKit.TEXT)))
		if e.broken:
			h.add_child(UiKit.button("Consertar (%s)" % Fmt.money(b.repair_cost(int(e.uid))), func():
				b.repair(int(e.uid))
				ui.refresh(), true))
		h.add_child(UiKit.button("Vender", func():
			b.sell_equipment(int(e.uid))
			ui.refresh()))
	body.add_child(UiKit.heading("Comprar", 17))
	for d in b.all_items():
		if d.has("casino"):
			continue
		var why := b.buy_block_reason(str(d.id))
		if why.begins_with("Requer estágio") and int(d.get("min_stage", 1)) > b.stage + 1:
			continue
		var c := UiKit.card(body)
		var h2 := UiKit.hbox()
		c.add_child(h2)
		var info := UiKit.vbox(2)
		h2.add_child(UiKit.expand(info))
		info.add_child(UiKit.label("%s — %s" % [d.name, Fmt.money(b.price_of(str(d.id)))], 16))
		info.add_child(UiKit.label("%s  Manutenção %s/dia, energia %s/dia." % [d.desc, Fmt.money(float(d.get("maintenance", 0))), Fmt.money(float(d.get("energy", 0)))], 13, UiKit.MUTED, true))
		if why != "":
			info.add_child(UiKit.label(why, 13, UiKit.ORANGE))
		h2.add_child(UiKit.button("Comprar", func():
			b.buy_equipment(str(d.id))
			ui.refresh(), true, why == ""))


# --- Propriedades e expansão ------------------------------------------------------------

func build_properties(body: VBoxContainer) -> void:
	var s := sim()
	var ps := s.properties
	if s.has_business():
		var c := UiKit.card(body, UiKit.PANEL2, UiKit.GOLD.darkened(0.3))
		c.add_child(UiKit.heading("Expansão — estágio atual: %d (%s)" % [s.business.stage, s.business.stage_name()], 17))
		var nd := s.business.stage_data(s.business.stage + 1)
		if nd.is_empty():
			c.add_child(UiKit.label("Estágio máximo alcançado!", 15, UiKit.GREEN))
		else:
			c.add_child(UiKit.label("Próximo: %s — %s" % [nd.name, nd.desc], 15, UiKit.TEXT, true))
			c.add_child(UiKit.label("Capacidade %d pessoas, %d guichês, até %d funcionários. Energia %s/dia, internet %s/dia, limpeza %s/dia." % [int(nd.capacity), int(nd.counters), int(nd.max_staff), Fmt.money(float(nd.energy)), Fmt.money(float(nd.internet)), Fmt.money(float(nd.cleaning))], 13, UiKit.MUTED, true))
			for r in s.business.upgrade_requirements():
				UiKit.status_line(c, r.ok, r.text)
			c.add_child(UiKit.button("EXPANDIR", func():
				s.business.upgrade()
				ui.refresh(), true, s.business.can_upgrade()))
	body.add_child(UiKit.heading("Imóveis da cidade", 17))
	for p in ps.all():
		var id := str(p.id)
		var c2 := UiKit.card(body)
		var h := UiKit.hbox()
		c2.add_child(h)
		var info := UiKit.vbox(2)
		h.add_child(UiKit.expand(info))
		var contract := str(ps.contracts.get(id, ""))
		var tag: String = str({"rented": "  [ALUGADO]", "owned": "  [SEU]"}.get(contract, ""))
		if ps.in_use(id):
			tag += "  [SUA BANCA]"
		info.add_child(UiKit.label(str(p.name) + tag, 16, UiKit.GREEN if contract != "" else UiKit.TEXT))
		var line := "Compra %s" % Fmt.money(ps.price(id))
		if float(p.get("rent", 0)) > 0:
			line = "Aluguel %s/dia (contrato %s)  |  " % [Fmt.money(float(p.rent)), Fmt.money(float(p.get("deposit", 0)))] + line
		if p.get("type", "") == "investment":
			line += "  |  Renda %s/dia" % Fmt.money(float(p.rental_income))
		else:
			line += "  |  Estágios %s" % ", ".join(PackedStringArray(p.stages.map(func(x): return str(int(x)))))
		info.add_child(UiKit.label(line, 13, UiKit.MUTED, true))
		LotActions.add(h, s, id, ui)


# --- Risco -------------------------------------------------------------------------

func build_risk(body: VBoxContainer) -> void:
	if not _need_business(body):
		return
	var s := sim()
	var ex := s.betting.total_exposure()
	var lvl := s.betting.risk_level(ex.worst_net)
	var c := UiKit.card(body, UiKit.PANEL2, UiKit.risk_color(lvl))
	c.add_child(UiKit.label("RISCO DA OPERAÇÃO: " + lvl, 24, UiKit.risk_color(lvl)))
	UiKit.kv(c, "Apostas em aberto", "%d bilhetes / %s" % [ex.bets, Fmt.money(ex.stakes)])
	UiKit.kv(c, "Pior cenário de pagamento", Fmt.money(ex.worst_payout))
	UiKit.kv(c, "Exposição líquida (pior cenário)", Fmt.money(ex.worst_net), UiKit.RED)
	UiKit.kv(c, "Caixa disponível", Fmt.money(s.economy.cash), UiKit.money_color(s.economy.cash))
	UiKit.kv(c, "Margem configurada", Fmt.pct(s.business.margin))
	UiKit.kv(c, "Qualidade da precificação", "%d%%" % int((1.0 - s.business.pricing_error() / 0.25) * 100))
	UiKit.kv(c, "Segurança", "%d pontos" % int(s.business.security_score()))
	body.add_child(UiKit.heading("Como reduzir o risco", 16))
	for tip in ["Aumente a margem: odds menores pagam menos (mas atraem menos clientes).",
			"Reduza a aposta máxima para limitar bilhetes grandes.",
			"Suspenda o resultado que concentra o risco na aba Apostas.",
			"Analistas e o sistema de gestão melhoram a precificação; clientes profissionais exploram odds mal calculadas.",
			"Mantenha caixa: a exposição só vira prejuízo se você não puder pagar."]:
		body.add_child(UiKit.label("• " + tip, 14, UiKit.TEXT, true))


# --- Reputação ----------------------------------------------------------------------

func build_reputation(body: VBoxContainer) -> void:
	var s := sim()
	var r := s.reputation
	var c := UiKit.card(body)
	c.add_child(UiKit.label("Reputação: %d / 100 — %s  (%.1f estrelas)" % [int(r.value), r.label(), r.stars()], 20, UiKit.BLUE))
	c.add_child(UiKit.bar(r.value, 100, UiKit.BLUE, 12))
	c.add_child(UiKit.label("Reputação aumenta clientes, frequência, clientes VIP e participação de mercado.", 13, UiKit.MUTED, true))
	body.add_child(UiKit.heading("Variações de hoje", 16))
	if r.today_changes.is_empty():
		body.add_child(UiKit.label("Nenhuma mudança ainda hoje.", 14, UiKit.MUTED))
	for k in r.today_changes:
		var v := float(r.today_changes[k])
		UiKit.kv(body, str(k), "%+.1f" % v, UiKit.GREEN if v >= 0 else UiKit.RED)
	if s.customers != null and s.has_business():
		var sat := 0.0
		var n := 0
		for id in s.customers.pool:
			if not s.customers.pool[id].lost:
				sat += float(s.customers.pool[id].satisfaction)
				n += 1
		body.add_child(UiKit.heading("Avaliações", 16))
		UiKit.kv(body, "Satisfação média dos clientes", "%d%%" % int(sat / maxf(1, n)))
		UiKit.kv(body, "Clientes perdidos (total)", str(int(s.stat("customers_lost"))))
		UiKit.kv(body, "Desistências na fila (total)", str(int(s.stat("customers_abandoned"))))


# --- Concorrência -----------------------------------------------------------------

func build_competition(body: VBoxContainer) -> void:
	var s := sim()
	if s.has_business():
		var c := UiKit.card(body)
		c.add_child(UiKit.heading("Participação de mercado", 17))
		for row in s.competition.market_shares():
			var h := UiKit.hbox()
			c.add_child(h)
			var l := UiKit.label(str(row[0]), 14, UiKit.GOLD if str(row[0]).ends_with("(você)") else UiKit.TEXT)
			l.custom_minimum_size.x = 220
			h.add_child(l)
			var b := UiKit.bar(float(row[1]), 1.0, UiKit.GOLD if str(row[0]).ends_with("(você)") else UiKit.BLUE, 12)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(b)
			h.add_child(UiKit.label(Fmt.pct(float(row[1]), 0), 14))
		c.add_child(UiKit.label("Você compete mais com casas de porte parecido com o seu. Reputação, odds, conforto e promoções decidem quem leva o cliente.", 13, UiKit.MUTED, true))
	for comp in s.competition.comps:
		CompetitorCard.build(body, s, str(comp.id), ui, false)
	var br := s.competition.branches()
	if br.size() > 0:
		body.add_child(UiKit.heading("Suas filiais", 17))
		for c2 in br:
			UiKit.kv(body, str(c2.name), Fmt.money(s.competition.branch_income(c2)) + "/dia", UiKit.GREEN)


# --- Promoções -------------------------------------------------------------------

func build_promotions(body: VBoxContainer) -> void:
	if not _need_business(body):
		return
	var s := sim()
	var ps := s.promotions
	body.add_child(UiKit.label("Fator de clientes por promoções agora: x%.2f" % ps.arrival_mult(), 15, UiKit.GOLD))
	for p in ps.all():
		var id := str(p.id)
		var c := UiKit.card(body, UiKit.PANEL2, UiKit.GREEN if ps.is_active(id) else Color(1, 1, 1, 0.05))
		var h := UiKit.hbox()
		c.add_child(h)
		var info := UiKit.vbox(2)
		h.add_child(UiKit.expand(info))
		info.add_child(UiKit.label("%s%s" % [p.name, "  [ATIVA]" if ps.is_active(id) else ""], 16, UiKit.GREEN if ps.is_active(id) else UiKit.TEXT))
		info.add_child(UiKit.label(str(p.desc), 13, UiKit.MUTED, true))
		var est := ps.estimated_return(id)
		var line := "Custo %s | %d dia(s) | Alcance +%d%% clientes | Reputação +%.1f | Retorno estimado %s" % [Fmt.money(float(p.cost)), int(p.days), int(float(p.reach) * 100), float(p.get("rep", 0)), Fmt.signed_money(est)]
		if float(p.get("per_customer", 0)) > 0:
			line += " | Custo por cliente atendido %s" % Fmt.money(float(p.per_customer))
		info.add_child(UiKit.label(line, 13, UiKit.TEXT, true))
		var why := ps.block_reason(id)
		if why != "" and not ps.is_active(id):
			info.add_child(UiKit.label(why, 13, UiKit.ORANGE))
		h.add_child(UiKit.button("Lançar", func():
			ps.launch(id)
			ui.refresh(), true, why == ""))


# --- Cassino (dono) ------------------------------------------------------------------

func build_casino(body: VBoxContainer) -> void:
	if not _need_business(body):
		return
	var s := sim()
	var b := s.business
	body.add_child(UiKit.label("Jogos de cassino do seu estabelecimento geram receita por hora, com a margem e a volatilidade de cada jogo. Mesas só funcionam com um crupiê trabalhando.", 14, UiKit.MUTED, true))
	if not s.licenses.has("entretenimento"):
		body.add_child(UiKit.label("Requer a Licença de Entretenimento (e estágio 4: Grande Salão).", 15, UiKit.ORANGE, true))
	var owned := 0
	for e in b.equipment:
		var d := b.item_data(str(e.id))
		if not d.has("casino"):
			continue
		owned += 1
		var stt: Dictionary = b.casino_stats.get(str(e.id), {})
		UiKit.kv(body, "%s%s%s" % [d.name, "  (QUEBRADO)" if e.broken else "", "  [mesa]" if d.get("dealer", false) else ""], "hoje %s  |  total %s" % [Fmt.signed_money(float(stt.get("today", 0.0))), Fmt.signed_money(float(stt.get("total", 0.0)))], UiKit.money_color(float(stt.get("total", 0.0))))
	if owned == 0:
		body.add_child(UiKit.label("Você ainda não tem jogos de cassino.", 15, UiKit.MUTED))
	var missing := b.casino_tables_without_dealer()
	if missing > 0:
		body.add_child(UiKit.label("%d mesa(s) parada(s) sem crupiê! Contrate em Funcionários." % missing, 15, UiKit.RED))
	UiKit.kv(body, "Resultado do cassino hoje", Fmt.signed_money(b.casino_today), UiKit.money_color(b.casino_today))
	body.add_child(UiKit.heading("Catálogo de jogos", 17))
	for d in b.all_items():
		if not d.has("casino"):
			continue
		var why := b.buy_block_reason(str(d.id))
		var c := UiKit.card(body)
		var h := UiKit.hbox()
		c.add_child(h)
		var info := UiKit.vbox(2)
		h.add_child(UiKit.expand(info))
		var cz: Dictionary = d.casino
		info.add_child(UiKit.label("%s — %s%s" % [d.name, Fmt.money(b.price_of(str(d.id))), "  (precisa de crupiê)" if d.get("dealer", false) else ""], 16))
		info.add_child(UiKit.label("%s  Vantagem da casa %s | %d jogadas/h | aposta média %s | manutenção %s/dia" % [d.desc, Fmt.pct(float(cz.edge)), int(cz.plays), Fmt.money(float(cz.avg_bet)), Fmt.money(float(d.maintenance))], 13, UiKit.MUTED, true))
		if why != "":
			info.add_child(UiKit.label(why, 13, UiKit.ORANGE))
		h.add_child(UiKit.button("Comprar", func():
			b.buy_equipment(str(d.id))
			ui.refresh(), true, why == ""))
