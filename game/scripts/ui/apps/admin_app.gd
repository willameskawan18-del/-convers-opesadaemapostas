extends AppBase
## Painel de administração (computador da banca / celular). Abas consistentes; cada aba é
## uma função build_<id>. Abas de negócio só aparecem quando há sistemas/negócio.

const TABS := [
	["overview", "Visão Geral"], ["finance", "Finanças"], ["bets", "Apostas"], ["customers", "Clientes"],
	["staff", "Funcionários"], ["equipment", "Equipamentos"], ["properties", "Propriedades"],
	["licenses", "Licenças"], ["promotions", "Promoções"], ["risk", "Risco"], ["reputation", "Reputação"],
	["competition", "Concorrência"],
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
