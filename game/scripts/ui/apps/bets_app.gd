extends AppBase
## Apostas pessoais do jogador (como apostador). No balcão da Banca do Zé ou, a partir
## do nível 2, pelo celular.

var sel_event := ""
var sel_outcome := -1
var stake := 20.0
var stake_edit: LineEdit


func title() -> String:
	return "Apostas Esportivas"


func subtitle() -> String:
	return "Banca do Zé — odds do mercado" if arg == "ze" else "App de apostas (odds do mercado)"


func window_size() -> Vector2:
	return Vector2(920, 600)


func build(body: VBoxContainer) -> void:
	var s := sim()
	if arg != "ze" and s.progression.level < 2:
		body.add_child(UiKit.label("O app de apostas é liberado no nível 2.\nPor enquanto, aposte pessoalmente na Banca do Zé (avenida, lado leste).", 18, UiKit.TEXT, true))
		return
	var top := UiKit.hbox()
	body.add_child(top)
	top.add_child(UiKit.expand(UiKit.label("Saldo: " + Fmt.money(s.economy.cash), 18, UiKit.GOLD)))
	top.add_child(UiKit.label("Dica: leia as Notícias. Elas revelam informações que o mercado ainda não precificou.", 13, UiKit.MUTED))
	var cols := UiKit.hbox(14)
	body.add_child(cols)
	var left := UiKit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	cols.add_child(left)
	var right := UiKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	left.add_child(UiKit.heading("Próximos eventos", 18))
	var evs := s.betting.open_events(5)
	if evs.is_empty():
		left.add_child(UiKit.label("Nenhum evento aberto agora. Volte mais tarde.", 15, UiKit.MUTED))
	for ev in evs.slice(0, 14):
		_event_row(left, ev)
	_slip(right)
	_my_bets(right)


func _event_row(parent: Control, ev: Dictionary) -> void:
	var s := sim()
	var c := UiKit.card(parent, UiKit.PANEL2 if ev.id != sel_event else UiKit.PANEL2.lightened(0.08), UiKit.GOLD if ev.id == sel_event else Color(1, 1, 1, 0.05))
	var h := UiKit.hbox()
	c.add_child(h)
	h.add_child(UiKit.label(str(ev.sport_name).to_upper(), 12, UiKit.BLUE))
	h.add_child(UiKit.expand(UiKit.label(str(ev.name), 15, UiKit.GOLD if float(ev.hype) > 1.2 else UiKit.TEXT)))
	h.add_child(UiKit.label(Fmt.hm(int(ev.start) % 1440) + ("" if int(ev.day) == s.time.day else " (amanhã)"), 13, UiKit.MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	c.add_child(flow)
	for i in ev.outcomes.size():
		var o := s.betting.market_odds(ev, i)
		var selected: bool = ev.id == sel_event and i == sel_outcome
		var b := UiKit.button("%s  %s" % [ev.outcomes[i], Fmt.odds(o)], func():
			sel_event = ev.id
			sel_outcome = i
			ui.refresh(), selected)
		flow.add_child(b)


func _slip(parent: Control) -> void:
	var s := sim()
	var c := UiKit.card(parent, UiKit.PANEL2, UiKit.GOLD.darkened(0.4))
	c.add_child(UiKit.heading("Bilhete", 18))
	var ev := s.betting.get_event(sel_event)
	if ev.is_empty() or sel_outcome < 0 or ev.status != "scheduled":
		c.add_child(UiKit.label("Escolha um resultado ao lado.", 14, UiKit.MUTED))
		return
	var odds := s.betting.market_odds(ev, sel_outcome)
	c.add_child(UiKit.label(str(ev.name), 14, UiKit.MUTED, true))
	c.add_child(UiKit.label("Palpite: %s @ %s" % [ev.outcomes[sel_outcome], Fmt.odds(odds)], 16))
	var quick := UiKit.hbox(4)
	c.add_child(quick)
	for v in [10, 25, 50, 100, 250]:
		quick.add_child(UiKit.button(str(v), func():
			stake = float(v)
			ui.refresh()))
	var h := UiKit.hbox()
	c.add_child(h)
	h.add_child(UiKit.label("Valor R$", 15, UiKit.MUTED))
	stake_edit = LineEdit.new()
	stake_edit.text = str(int(stake))
	stake_edit.custom_minimum_size.x = 100
	stake_edit.text_changed.connect(func(t): stake = maxf(0.0, t.to_float()))
	h.add_child(stake_edit)
	c.add_child(UiKit.label("Retorno potencial: " + Fmt.money(stake * odds), 15, UiKit.GREEN))
	c.add_child(UiKit.button("CONFIRMAR APOSTA", func():
		if s.betting.place_player_bet(sel_event, sel_outcome, stake):
			s.after_action()
			sel_outcome = -1
		ui.refresh(), true))


func _my_bets(parent: Control) -> void:
	var s := sim()
	parent.add_child(UiKit.heading("Minhas apostas", 16))
	if s.betting.player_bets.is_empty():
		parent.add_child(UiKit.label("Nenhuma aposta em aberto.", 14, UiKit.MUTED))
	for b in s.betting.player_bets:
		var ev := s.betting.get_event(str(b.event_id))
		var st := "AO VIVO" if ev.get("status", "") == "live" else Fmt.hm(int(ev.get("start", 0)) % 1440)
		parent.add_child(UiKit.label("%s @ %s — %s  [%s]" % [b.pick, Fmt.odds(float(b.odds)), Fmt.money(float(b.stake)), st], 14, UiKit.TEXT, true))
	var hist: Array = s.betting.player_history.duplicate()
	hist.reverse()
	if hist.size() > 0:
		parent.add_child(UiKit.label("Resultados recentes", 14, UiKit.MUTED))
	for b in hist.slice(0, 6):
		var txt := "%s @ %s: %s" % [b.pick, Fmt.odds(float(b.odds)), ("GANHOU " + Fmt.money(float(b.payout))) if b.won else "perdeu " + Fmt.money(float(b.stake))]
		parent.add_child(UiKit.label(txt, 13, UiKit.GREEN if b.won else UiKit.RED, true))
