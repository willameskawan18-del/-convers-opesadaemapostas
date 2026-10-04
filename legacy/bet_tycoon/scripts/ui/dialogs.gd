class_name Dialogs
## Construtores de diálogos modais (relatório diário, decisão, vitória, falência, pausa).


static func _modal(parent: Control, w: float, h: float, border: Color = UiKit.GOLD) -> Array:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var p := PanelContainer.new()
	p.theme = UiKit.theme()
	p.add_theme_stylebox_override("panel", UiKit.style(UiKit.PANEL, 16, border.darkened(0.2), 2, 22))
	p.custom_minimum_size = Vector2(w, h)
	center.add_child(p)
	var v := UiKit.vbox(8)
	p.add_child(v)
	return [shade, v]


static func daily_report(parent: Control, r: Dictionary, on_close: Callable) -> Control:
	var m := _modal(parent, 620, 0)
	var v: VBoxContainer = m[1]
	v.add_child(UiKit.label("RELATÓRIO DO DIA %d" % int(r.day), 26, UiKit.GOLD))
	var cols := UiKit.hbox(24)
	v.add_child(cols)
	var a := UiKit.vbox(4)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(a)
	var b := UiKit.vbox(4)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(b)
	UiKit.kv(a, "Receita", Fmt.money(float(r.revenue)), UiKit.GREEN)
	UiKit.kv(a, "Despesas", Fmt.money(float(r.expenses)), UiKit.RED)
	UiKit.kv(a, "Lucro / Prejuízo", Fmt.signed_money(float(r.profit)), UiKit.money_color(float(r.profit)))
	if float(r.get("investments", 0)) > 0:
		UiKit.kv(a, "Investimentos", Fmt.money(float(r.investments)), UiKit.BLUE)
	UiKit.kv(a, "Caixa", Fmt.money(float(r.cash)), UiKit.money_color(float(r.cash)))
	UiKit.kv(a, "Patrimônio", Fmt.money(float(r.net_worth)), UiKit.GOLD)
	UiKit.kv(a, "Dívidas", Fmt.money(float(r.debt)), UiKit.RED if float(r.debt) > 0 else UiKit.TEXT)
	UiKit.kv(b, "Clientes atendidos", str(int(r.served)))
	UiKit.kv(b, "Novos clientes", str(int(r.new_customers)))
	UiKit.kv(b, "Clientes perdidos", str(int(r.lost_customers)), UiKit.RED if int(r.lost_customers) > 0 else UiKit.TEXT)
	UiKit.kv(b, "Reputação", "%d → %d" % [int(r.rep_from), int(r.rep_to)], UiKit.GREEN if float(r.rep_to) >= float(r.rep_from) else UiKit.RED)
	UiKit.kv(b, "Exposição aberta", Fmt.money(float(r.exposure)))
	UiKit.kv(b, "XP", "+%d" % int(r.xp), UiKit.GOLD)
	UiKit.sep(v)
	v.add_child(UiKit.label("Análise", 17, UiKit.GOLD))
	v.add_child(UiKit.label("Seu maior custo hoje foi: " + str(r.biggest_cost), 15, UiKit.TEXT, true))
	v.add_child(UiKit.label("Seu maior problema foi: " + str(r.biggest_problem), 15, UiKit.TEXT, true))
	v.add_child(UiKit.label("Seu melhor resultado foi: " + str(r.best_result), 15, UiKit.TEXT, true))
	if r.has("warning"):
		v.add_child(UiKit.label(str(r.warning), 16, UiKit.RED, true))
	var shade: Control = m[0]
	v.add_child(UiKit.button("CONTINUAR PARA O DIA %d" % (int(r.day) + 1), func():
		shade.queue_free()
		on_close.call(), true))
	return shade


static func decision(parent: Control, ev: Dictionary, on_choose: Callable) -> Control:
	var m := _modal(parent, 560, 0, UiKit.ORANGE)
	var v: VBoxContainer = m[1]
	var shade: Control = m[0]
	v.add_child(UiKit.label(str(ev.get("title", "EVENTO")).to_upper(), 24, UiKit.ORANGE))
	v.add_child(UiKit.label(str(ev.get("text", "")), 16, UiKit.TEXT, true))
	UiKit.sep(v)
	var opts: Array = ev.get("options", [])
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := UiKit.button(str(o.label), func():
			shade.queue_free()
			on_choose.call(i), i == 0)
		b.custom_minimum_size.y = 44
		v.add_child(b)
		if o.has("desc"):
			v.add_child(UiKit.label(str(o.desc), 13, UiKit.MUTED, true))
	return shade


static func message(parent: Control, title: String, lines: Array, button: String, on_close: Callable, color: Color = UiKit.GOLD, size: int = 30) -> Control:
	var m := _modal(parent, 640, 0, color)
	var v: VBoxContainer = m[1]
	var shade: Control = m[0]
	var t := UiKit.label(title, size, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for l in lines:
		var lb := UiKit.label(str(l), 17, UiKit.TEXT, true)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lb)
	v.add_child(UiKit.button(button, func():
		shade.queue_free()
		on_close.call(), true))
	return shade


static func pause_menu(parent: Control, actions: Dictionary) -> Control:
	var m := _modal(parent, 360, 0)
	var v: VBoxContainer = m[1]
	var t := UiKit.label("PAUSADO", 28, UiKit.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for k in actions:
		var b := UiKit.button(k, actions[k], k == "Continuar")
		b.custom_minimum_size.y = 44
		v.add_child(b)
	return m[0]
