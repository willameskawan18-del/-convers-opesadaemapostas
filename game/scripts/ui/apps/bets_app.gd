extends AppBase
## Apostas pessoais do jogador: simples e visual. Abas por esporte, botões grandes,
## corrida de cavalos rápida a cada 30 minutos e bilhete em 3 passos.

const SPORT_COLORS := {"futebol": Color("2ecc71"), "basquete": Color("e67e22"), "tenis": Color("f1c40f"), "corrida": Color("e74c3c"),
	"volei": Color("3498db"), "mma": Color("c0392b"), "esports": Color("9b59b6"), "cavalos": Color("a0522d")}

var sel_event := ""
var sel_outcome := -1
var stake := 20.0
var sport := "todos"


func title() -> String:
	return "Apostas"


func subtitle() -> String:
	return "Banca do Zé" if arg == "ze" else "App de apostas"


func window_size() -> Vector2:
	return Vector2(1000, 640)


func live() -> bool:
	return true


func build(body: VBoxContainer) -> void:
	var s := sim()
	if arg != "ze" and s.progression.level < 2:
		body.add_child(UiKit.label("O app de apostas libera no nível 2.\nPor enquanto, aposte pessoalmente na Banca do Zé (avenida, lado leste) — siga o feixe dourado.", 18, UiKit.TEXT, true))
		return
	var top := UiKit.hbox()
	body.add_child(top)
	top.add_child(UiKit.bold(UiKit.label("Saldo: " + Fmt.money(s.economy.cash), 20, UiKit.GOLD)))
	top.add_child(UiKit.spacer())
	top.add_child(UiKit.label("1. Escolha um palpite   2. Escolha o valor   3. Confirme", 14, UiKit.MUTED))
	var cols := UiKit.hbox(14)
	body.add_child(cols)
	var left := UiKit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.7
	cols.add_child(left)
	var right := UiKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_quick_race(left)
	_sport_tabs(left)
	var evs: Array = s.betting.open_events(3).filter(func(e): return not e.get("quick", false) and (sport == "todos" or e.sport == sport))
	if evs.is_empty():
		left.add_child(UiKit.label("Nenhum jogo aberto nesta modalidade agora.", 15, UiKit.MUTED))
	for ev in evs.slice(0, 8):
		_event_card(left, ev)
	_slip(right)
	_my_bets(right)


# --- Corrida rápida -----------------------------------------------------------

func _quick_race(parent: Control) -> void:
	var s := sim()
	var live := s.betting.live_quick_race()
	var c := UiKit.card(parent, Color("2b1d12"), Color("a0522d"))
	if not live.is_empty():
		c.add_child(UiKit.bold(UiKit.label("CORRIDA DE CAVALOS — AO VIVO", 16, Color("ffcc80"))))
		c.add_child(RaceView.new(live))
		return
	var last := _last_finished_race()
	if not last.is_empty() and s.time.abs_minute() - (int(last.start) + int(last.duration)) < 8:
		c.add_child(UiKit.bold(UiKit.label("CORRIDA ENCERRADA", 16, Color("ffcc80"))))
		c.add_child(RaceView.new(last))
		return
	var nxt := s.betting.next_quick_race()
	if nxt.is_empty():
		c.add_child(UiKit.label("Corridas de cavalos: das 09:00 às 23:00, a cada 30 minutos.", 14, UiKit.MUTED))
		return
	var mins := int(nxt.start) - s.time.abs_minute()
	c.add_child(UiKit.bold(UiKit.label("CORRIDA DE CAVALOS RÁPIDA — largada em %d min (%s)" % [mins, Fmt.hm(int(nxt.start) % 1440)], 16, Color("ffcc80"))))
	c.add_child(UiKit.label("Escolha um cavalo. O resultado sai em poucos segundos!", 13, UiKit.MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	c.add_child(flow)
	for i in nxt.outcomes.size():
		flow.add_child(_pick_button(nxt, i, "%s  %s" % [nxt.outcomes[i], Fmt.odds(s.betting.market_odds(nxt, i))]))


func _last_finished_race() -> Dictionary:
	var best: Dictionary = {}
	for e in sim().betting.events:
		if e.get("quick", false) and e.status == "finished":
			if best.is_empty() or int(e.start) > int(best.start):
				best = e
	return best


# --- Abas e eventos ------------------------------------------------------------

func _sport_tabs(parent: Control) -> void:
	var s := sim()
	var open := s.betting.open_events(3)
	var present := {}
	for e in open:
		if not e.get("quick", false):
			present[e.sport] = e.sport_name
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	parent.add_child(flow)
	flow.add_child(UiKit.button("Todos", func():
		sport = "todos"
		ui.refresh(), sport == "todos"))
	for sp in GameData.list("sports", "sports"):
		if not present.has(sp.id):
			continue
		var id: String = sp.id
		flow.add_child(UiKit.button(str(sp.name), func():
			sport = id
			ui.refresh(), sport == id))


func _pick_button(ev: Dictionary, i: int, text: String) -> Button:
	var selected: bool = ev.id == sel_event and i == sel_outcome
	var b := UiKit.button(text, func():
		sel_event = ev.id
		sel_outcome = i
		ui.refresh(), selected)
	b.custom_minimum_size = Vector2(150, 44)
	b.add_theme_font_size_override("font_size", 15)
	return b


func _event_card(parent: Control, ev: Dictionary) -> void:
	var s := sim()
	var col: Color = SPORT_COLORS.get(str(ev.sport), UiKit.BLUE)
	var c := UiKit.card(parent, UiKit.PANEL2, UiKit.GOLD if ev.id == sel_event else col.darkened(0.5))
	var h := UiKit.hbox()
	c.add_child(h)
	h.add_child(UiKit.bold(UiKit.label(str(ev.sport_name).to_upper(), 12, col)))
	h.add_child(UiKit.expand(UiKit.label(str(ev.name), 16, UiKit.GOLD if float(ev.hype) > 1.2 else UiKit.TEXT)))
	h.add_child(UiKit.label(Fmt.hm(int(ev.start) % 1440) + ("" if int(ev.day) == s.time.day else " amanhã"), 13, UiKit.MUTED))
	var row := UiKit.hbox(6)
	c.add_child(row)
	var fav := 0
	for i in ev.outcomes.size():
		if float(ev.market_p[i]) > float(ev.market_p[fav]):
			fav = i
	for i in ev.outcomes.size():
		var label := str(ev.outcomes[i])
		if ev.outcomes.size() > 3:
			label = label.substr(0, 14)
		var b := _pick_button(ev, i, "%s\n%s%s" % [label, Fmt.odds(s.betting.market_odds(ev, i)), "  (favorito)" if i == fav else ""])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	if str(ev.news) != "":
		c.add_child(UiKit.label("Notícia: " + str(ev.news), 12, UiKit.ORANGE, true))


# --- Bilhete -----------------------------------------------------------------

func _slip(parent: Control) -> void:
	var s := sim()
	var c := UiKit.card(parent, UiKit.PANEL2, UiKit.GOLD.darkened(0.3))
	c.add_child(UiKit.heading("Seu bilhete", 18))
	var ev := s.betting.get_event(sel_event)
	if ev.is_empty() or sel_outcome < 0 or ev.status != "scheduled":
		c.add_child(UiKit.label("Toque em um palpite ao lado.", 15, UiKit.MUTED))
		return
	var odds := s.betting.market_odds(ev, sel_outcome)
	c.add_child(UiKit.label(str(ev.name), 13, UiKit.MUTED, true))
	c.add_child(UiKit.bold(UiKit.label("%s  @ %s" % [ev.outcomes[sel_outcome], Fmt.odds(odds)], 18)))
	var quick := HFlowContainer.new()
	quick.add_theme_constant_override("h_separation", 4)
	quick.add_theme_constant_override("v_separation", 4)
	c.add_child(quick)
	for v in [5, 10, 20, 50, 100, 500]:
		quick.add_child(UiKit.button(Fmt.money(v), func():
			stake = float(v)
			ui.refresh(), is_equal_approx(stake, float(v))))
	var h := UiKit.hbox()
	c.add_child(h)
	h.add_child(UiKit.button("-", func():
		stake = maxf(5.0, stake - 5.0)
		ui.refresh()))
	h.add_child(UiKit.expand(UiKit.bold(UiKit.label("Valor: " + Fmt.money(stake), 17))))
	h.add_child(UiKit.button("+", func():
		stake += 5.0
		ui.refresh()))
	c.add_child(UiKit.label("Se acertar, você recebe: " + Fmt.money(stake * odds), 16, UiKit.GREEN))
	var b := UiKit.button("CONFIRMAR APOSTA", func():
		if s.betting.place_player_bet(sel_event, sel_outcome, stake):
			s.after_action()
			sel_outcome = -1
		ui.refresh(), true, s.economy.can_afford(stake))
	b.custom_minimum_size.y = 48
	c.add_child(b)


func _my_bets(parent: Control) -> void:
	var s := sim()
	if s.betting.player_bets.size() > 0:
		parent.add_child(UiKit.heading("Apostas em andamento", 15))
	for b in s.betting.player_bets:
		var ev := s.betting.get_event(str(b.event_id))
		var st := "AO VIVO" if ev.get("status", "") == "live" else Fmt.hm(int(ev.get("start", 0)) % 1440)
		parent.add_child(UiKit.label("%s — %s → %s  [%s]" % [b.pick, Fmt.money(float(b.stake)), Fmt.money(float(b.stake) * float(b.odds)), st], 14, UiKit.TEXT, true))
	var hist: Array = s.betting.player_history.duplicate()
	hist.reverse()
	if hist.size() > 0:
		parent.add_child(UiKit.heading("Resultados", 15))
	for b in hist.slice(0, 5):
		var txt := "%s: %s" % [b.pick, ("GANHOU " + Fmt.money(float(b.payout))) if b.won else "perdeu " + Fmt.money(float(b.stake))]
		parent.add_child(UiKit.label(txt, 13, UiKit.GREEN if b.won else UiKit.RED, true))
