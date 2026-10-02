extends AppBase
## Salão de jogos (dinheiro fictício do jogo). arg = local: "royal", "lucky" ou "online".
## Cada jogo tem sua função _g_<id>. O resultado é sorteado antes da animação e é sempre
## liquidado, mesmo se a janela for fechada no meio (on_close).

const VENUES := {
	"estrela": {"name": "Cassino Estrela", "max": 1000.0, "games": []},
	"royal": {"name": "Salão de Jogos — Royal Apostas", "max": 5000.0, "games": []},
	"lucky": {"name": "Lucky Games — Lucky Bet", "max": 500.0, "games": ["caca_niquel", "video_slot", "aviaozinho", "minas", "plinko", "dados", "raspadinha", "keno", "hilo", "roleta", "dragao_tigre"]},
	"online": {"name": "Cassino Online (Royal)", "max": 1000.0, "games": []},
}
const CHIPS := [1, 5, 10, 25, 100, 500, 1000]
const KIND_COLORS := {"Máquina": Color("c77dff"), "Mesa": Color("3ddc84"), "Show": Color("ff9f43"), "Crash": Color("ff4d6d"), "Instantâneo": Color("4ea8ff"), "Cartas": Color("f5c542"), "Sorteio": Color("48dbfb")}

var game := ""
var bet := 10.0
var st: Dictionary = {}
var session_net := 0.0
var rng := RandomNumberGenerator.new()
var _pending: Callable


func _init() -> void:
	rng.randomize()


var _venue_id := ""


func venue_id() -> String:
	if _venue_id == "":
		if arg is Dictionary:
			_venue_id = str(arg.get("venue", "estrela"))
			if str(arg.get("game", "")) != "":
				game = str(arg.game)
		else:
			_venue_id = str(arg) if arg != null else "estrela"
	return _venue_id


func venue() -> Dictionary:
	return VENUES.get(venue_id(), VENUES.estrela)


func title() -> String:
	return str(venue().name)


func subtitle() -> String:
	return "Jogos fictícios com dinheiro do jogo. A casa sempre tem vantagem."


func window_size() -> Vector2:
	return Vector2(1000, 650)


func games() -> Array:
	var g: Array = venue().games
	return g if not g.is_empty() else CasinoLogic.GAMES.keys()


func max_bet() -> float:
	return float(venue().max)


func on_close() -> void:
	_settle_pending()


func _settle_pending() -> void:
	if _pending.is_valid():
		var p := _pending
		_pending = Callable()
		p.call()


# --- Dinheiro ----------------------------------------------------------------------

func _take(amount: float) -> bool:
	amount = floorf(amount)
	if amount < 1.0:
		sim().notify("Escolha um valor de aposta.", "error")
		return false
	if amount > max_bet():
		sim().notify("Aposta máxima aqui: " + Fmt.money(max_bet()), "error")
		return false
	if not sim().economy.spend(amount, EconomySystem.PERSONAL_BET):
		return false
	session_net -= amount
	sim().add_stat("casino_rounds")
	sim().add_stat("casino_wagered", amount)
	Audio.play("machine", -8.0)
	return true


func _pay(amount: float, msg: String = "") -> void:
	if amount > 0.0:
		sim().economy.earn(amount, EconomySystem.PERSONAL_WIN)
		session_net += amount
		sim().add_stat("casino_won", amount)
		sim().notify((msg + " " if msg != "" else "") + "Você recebeu " + Fmt.money(amount), "win")
	elif msg != "":
		sim().notify(msg, "lose")


# --- Estrutura -----------------------------------------------------------------------

func build(body: VBoxContainer) -> void:
	venue_id()
	if _venue_id == "online" and sim().progression.level < 3:
		body.add_child(UiKit.label("O cassino online é liberado no nível 3. Até lá, visite o salão de jogos da Royal Apostas ou da Lucky Bet.", 17, UiKit.TEXT, true))
		return
	if game == "":
		_lobby(body)
		return
	var head := UiKit.hbox()
	body.add_child(head)
	head.add_child(UiKit.button("< Salão", func():
		_settle_pending()
		game = ""
		st = {}
		ui.refresh()))
	var info: Dictionary = CasinoLogic.GAMES.get(game, {})
	head.add_child(UiKit.expand(UiKit.label(str(info.get("name", game)).to_upper(), 22, UiKit.GOLD)))
	head.add_child(UiKit.label("Retorno ao jogador: " + str(info.get("rtp", "?")), 13, UiKit.MUTED))
	var bar := UiKit.hbox()
	body.add_child(bar)
	bar.add_child(UiKit.label("Saldo: " + Fmt.money(sim().economy.cash), 16, UiKit.GOLD))
	bar.add_child(UiKit.spacer())
	bar.add_child(UiKit.label("Resultado da sessão: " + Fmt.signed_money(session_net), 15, UiKit.money_color(session_net)))
	call("_g_" + game, body)


func _lobby(body: VBoxContainer) -> void:
	var top := UiKit.hbox()
	body.add_child(top)
	top.add_child(UiKit.expand(UiKit.label("Saldo: " + Fmt.money(sim().economy.cash), 18, UiKit.GOLD)))
	top.add_child(UiKit.label("Aposta máxima: " + Fmt.money(max_bet()), 14, UiKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for id in games():
		var g: Dictionary = CasinoLogic.GAMES[id]
		var col: Color = KIND_COLORS.get(str(g.kind), UiKit.GOLD)
		var b := Button.new()
		b.custom_minimum_size = Vector2(225, 92)
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s\n%s  ·  RTP %s" % [g.name, g.kind, g.rtp]
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_stylebox_override("normal", UiKit.style(col.darkened(0.72), 12, col.darkened(0.2), 1, 10))
		b.add_theme_stylebox_override("hover", UiKit.style(col.darkened(0.55), 12, col, 2, 10))
		b.add_theme_stylebox_override("pressed", UiKit.style(col.darkened(0.4), 12, Color.WHITE, 2, 10))
		var gid: String = id
		b.pressed.connect(func():
			Audio.play("click")
			game = gid
			st = {}
			ui.refresh())
		grid.add_child(b)
	body.add_child(UiKit.label("Lembrete: jogue apenas com dinheiro do jogo que você pode perder. O dinheiro da banca é o mesmo do seu bolso.", 13, UiKit.MUTED, true))


func _bet_bar(parent: Control) -> void:
	var h := UiKit.hbox(4)
	parent.add_child(h)
	h.add_child(UiKit.label("Aposta: " + Fmt.money(bet), 18, UiKit.TEXT))
	h.add_child(UiKit.spacer())
	for c in CHIPS:
		if c > max_bet():
			continue
		h.add_child(UiKit.button(str(c), func():
			bet = minf(max_bet(), float(c) if bet <= 0 else bet + c)
			ui.refresh()))
	h.add_child(UiKit.button("x2", func():
		bet = minf(max_bet(), bet * 2.0)
		ui.refresh()))
	h.add_child(UiKit.button("½", func():
		bet = maxf(1.0, floorf(bet / 2.0))
		ui.refresh()))
	h.add_child(UiKit.button("Limpar", func():
		bet = 0.0
		ui.refresh()))


func _busy() -> bool:
	return st.get("busy", false)


func _result_line(parent: Control) -> void:
	if st.has("msg"):
		var l := UiKit.label(str(st.msg), 22, st.get("msg_color", UiKit.GOLD))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(l)


func _set_msg(text: String, won: bool) -> void:
	st.msg = text
	st.msg_color = UiKit.GREEN if won else UiKit.RED


func _center_row(parent: Control, sep: int = 12) -> HBoxContainer:
	var h := UiKit.hbox(sep)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(h)
	return h


# --- Máquinas --------------------------------------------------------------------------

func _slot_machine(body: VBoxContainer, symbols: Array, colors: Array, spin_fn: Callable, extra_info: String) -> void:
	var row := _center_row(body, 14)
	var reels: Array = st.get("reels", [-1, -1, -1])
	if _busy():
		var res: Dictionary = st.pending_res
		for i in 3:
			var sp := CasinoViews.Spinner.new(symbols, str(symbols[int(res.reels[i])]), func():
				if i == 2:
					_settle_pending(), 0.7 + i * 0.45)
			sp.custom_minimum_size = Vector2(150, 110)
			row.add_child(sp)
	else:
		for i in 3:
			var r := int(reels[i])
			row.add_child(CasinoViews.ReelView.new(str(symbols[r]) if r >= 0 else "?", colors[r] if r >= 0 else UiKit.MUTED))
	_result_line(body)
	_bet_bar(body)
	var go := UiKit.button("GIRAR", func():
		if _busy() or not _take(bet):
			return
		var res: Dictionary = spin_fn.call()
		var stake := bet
		st.busy = true
		st.pending_res = res
		_pending = func():
			st.busy = false
			st.reels = res.reels
			var win := float(res.get("mult", 0.0)) * stake
			if res.get("pot", false):
				var pot := float(sim().stat("jackpot_pot"))
				win = roundf(pot * clampf(stake / 50.0, 0.05, 1.0))
				sim().stats["jackpot_pot"] = maxf(5000.0, pot - win)
				Audio.play("levelup")
			if win > 0.0:
				_set_msg("GANHOU " + Fmt.money(win) + "!", true)
				_pay(win)
			else:
				_set_msg("Não foi dessa vez.", false)
			ui.refresh()
		ui.refresh(), true, not _busy())
	go.custom_minimum_size = Vector2(220, 52)
	_center_row(body).add_child(go)
	body.add_child(UiKit.label(extra_info, 13, UiKit.MUTED, true))


func _g_caca_niquel(body: VBoxContainer) -> void:
	var pays := []
	for i in CasinoLogic.SLOT_SYMBOLS.size():
		pays.append("3x %s = %dx" % [CasinoLogic.SLOT_SYMBOLS[i], CasinoLogic.SLOT_PAY3[i]])
	_slot_machine(body, CasinoLogic.SLOT_SYMBOLS, CasinoLogic.SLOT_COLORS, func(): return CasinoLogic.slot_spin(rng), "Tabela: " + ", ".join(pays) + ", 2 cerejas = 2,5x.")


func _g_video_slot(body: VBoxContainer) -> void:
	_slot_machine(body, CasinoLogic.VS_SYMBOLS, CasinoLogic.VS_COLORS, func(): return CasinoLogic.video_slot_spin(rng), "O CURINGA substitui qualquer símbolo. 3 curingas = 280x. Moeda 3,5x · Taça 7x · Coroa 14x · Baú 32x · Diamante 80x.")


func _g_jackpot(body: VBoxContainer) -> void:
	if sim().stat("jackpot_pot") < 5000.0:
		sim().stats["jackpot_pot"] = 25000.0
	var pot := UiKit.label("POTE ACUMULADO: " + Fmt.money(sim().stat("jackpot_pot")), 30, UiKit.GOLD)
	pot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(pot)
	_slot_machine(body, CasinoLogic.JP_SYMBOLS, CasinoLogic.JP_COLORS, func():
		sim().stats["jackpot_pot"] = sim().stat("jackpot_pot") + bet * 0.04
		return CasinoLogic.jackpot_spin(rng), "3 DIAMANTES ganham o pote (integral com aposta a partir de R$ 50). Moeda 6x · Sino 12x · Trevo 30x · Estrela 90x · 2 moedas 1,5x. 4% de cada aposta alimenta o pote.")


func _g_video_poker(body: VBoxContainer) -> void:
	var phase := str(st.get("phase", "bet"))
	var hand: Array = st.get("hand", [])
	var holds: Array = st.get("holds", [false, false, false, false, false])
	var row := _center_row(body, 10)
	for i in 5:
		var col := UiKit.vbox(4)
		row.add_child(col)
		col.add_child(CasinoViews.CardView.new(int(hand[i]) if hand.size() == 5 else 0, hand.size() != 5))
		if phase == "hold":
			col.add_child(UiKit.button("SEGURAR" if not holds[i] else "SEGURO", func():
				holds[i] = not holds[i]
				st.holds = holds
				ui.refresh(), holds[i]))
	_result_line(body)
	if phase != "hold":
		_bet_bar(body)
		_center_row(body).add_child(UiKit.button("DAR CARTAS", func():
			if not _take(bet):
				return
			var deck := CasinoLogic.shuffled_deck(rng)
			st = {"phase": "hold", "deck": deck, "hand": deck.slice(0, 5), "holds": [false, false, false, false, false], "stake": bet, "next": 5}
			_pending = func(): _vp_draw()
			ui.refresh(), true))
	else:
		_center_row(body).add_child(UiKit.button("TROCAR CARTAS", func(): _vp_draw(), true))
	var lines: Array = []
	for k in CasinoLogic.VP_PAY:
		lines.append("%s %sx" % [k, str(CasinoLogic.VP_PAY[k])])
	body.add_child(UiKit.label("Tabela (Valete ou Melhor): " + " · ".join(lines), 13, UiKit.MUTED, true))


func _vp_draw() -> void:
	_pending = Callable()
	var hand: Array = st.hand
	var deck: Array = st.deck
	var nxt := int(st.next)
	for i in 5:
		if not st.holds[i]:
			hand[i] = deck[nxt]
			nxt += 1
	var hand_name := CasinoLogic.vp_evaluate(hand)
	var mult := float(CasinoLogic.VP_PAY.get(hand_name, 0.0))
	var stake := float(st.stake)
	st = {"phase": "bet", "hand": hand}
	if mult > 0.0:
		_set_msg("%s! %s" % [hand_name.to_upper(), Fmt.money(stake * mult)], true)
		_pay(stake * mult)
	else:
		_set_msg("Sem combinação.", false)
	ui.refresh()


# --- Mesas ----------------------------------------------------------------------------

func _cards_row(parent: Control, label: String, cards: Array, hide_second: bool = false) -> void:
	var col := UiKit.vbox(4)
	parent.add_child(col)
	col.add_child(UiKit.label(label, 15, UiKit.MUTED))
	var row := UiKit.hbox(6)
	col.add_child(row)
	for i in cards.size():
		row.add_child(CasinoViews.CardView.new(int(cards[i]), hide_second and i == 1))


func _g_blackjack(body: VBoxContainer) -> void:
	var phase := str(st.get("phase", "bet"))
	var table := _center_row(body, 60)
	if st.has("player"):
		var dealer: Array = st.dealer
		var hide := phase == "play"
		_cards_row(table, "CRUPIÊ" + ("" if hide else " — %d" % CasinoLogic.bj_value(dealer)), dealer, hide)
		_cards_row(table, "VOCÊ — %d" % CasinoLogic.bj_value(st.player), st.player)
	_result_line(body)
	if phase == "play":
		var row := _center_row(body)
		row.add_child(UiKit.button("PEDIR CARTA", func():
			st.player.append(CasinoLogic.draw(rng))
			if CasinoLogic.bj_value(st.player) >= 21:
				_bj_finish()
			ui.refresh(), true))
		row.add_child(UiKit.button("PARAR", func():
			_bj_finish()
			ui.refresh()))
		var can_double: bool = st.player.size() == 2 and sim().economy.can_afford(float(st.stake))
		row.add_child(UiKit.button("DOBRAR", func():
			if _take(float(st.stake)):
				st.stake = float(st.stake) * 2.0
				st.player.append(CasinoLogic.draw(rng))
				_bj_finish()
			ui.refresh(), false, can_double))
	else:
		_bet_bar(body)
		_center_row(body).add_child(UiKit.button("DISTRIBUIR", func():
			if not _take(bet):
				return
			st = {"phase": "play", "player": [CasinoLogic.draw(rng), CasinoLogic.draw(rng)], "dealer": [CasinoLogic.draw(rng), CasinoLogic.draw(rng)], "stake": bet}
			_pending = func(): _bj_finish()
			if CasinoLogic.bj_is_blackjack(st.player):
				_bj_finish()
			ui.refresh(), true))
	body.add_child(UiKit.label("Blackjack paga 3 para 2. O crupiê compra até 17. Dobrar: dobra a aposta e recebe só mais uma carta.", 13, UiKit.MUTED, true))


func _bj_finish() -> void:
	_pending = Callable()
	if CasinoLogic.bj_value(st.player) <= 21:
		CasinoLogic.bj_dealer_play(rng, st.dealer)
	var mult := CasinoLogic.bj_settle(st.player, st.dealer)
	var stake := float(st.stake)
	st.phase = "done"
	match mult:
		2.5: _set_msg("BLACKJACK! " + Fmt.money(stake * mult), true)
		2.0: _set_msg("VOCÊ VENCEU! " + Fmt.money(stake * mult), true)
		1.0: _set_msg("EMPATE — aposta devolvida.", true)
		_: _set_msg("O crupiê venceu.", false)
	_pay(stake * mult)


func _g_roleta(body: VBoxContainer) -> void:
	var sel := str(st.get("sel", "vermelho"))
	var view := _center_row(body)
	if _busy():
		var nums: Array = []
		for i in 37:
			nums.append(str(i))
		var sp := CasinoViews.Spinner.new(nums, str(st.result), func(): _settle_pending(), 1.8)
		sp.add_theme_font_size_override("font_size", 64)
		view.add_child(sp)
	elif st.has("last"):
		var n := int(st.last)
		var l := UiKit.label("%d  %s" % [n, CasinoLogic.roulette_color(n).to_upper()], 54, {"vermelho": Color("ff4d4d"), "preto": Color("dfe6e9"), "verde": Color("2ecc71")}[CasinoLogic.roulette_color(n)])
		view.add_child(l)
	_result_line(body)
	var hist: Array = st.get("history", [])
	if hist.size() > 0:
		body.add_child(UiKit.label("Últimos: " + "  ".join(PackedStringArray(hist.map(func(x): return str(x)))), 14, UiKit.MUTED))
	var opts := [["vermelho", "Vermelho 1:1"], ["preto", "Preto 1:1"], ["par", "Par 1:1"], ["impar", "Ímpar 1:1"], ["baixo", "1–18 1:1"], ["alto", "19–36 1:1"], ["d1", "1ª dúzia 2:1"], ["d2", "2ª dúzia 2:1"], ["d3", "3ª dúzia 2:1"]]
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	body.add_child(flow)
	for o in opts:
		flow.add_child(UiKit.button(o[1], func():
			st.sel = o[0]
			ui.refresh(), sel == o[0]))
	var nh := UiKit.hbox()
	body.add_child(nh)
	nh.add_child(UiKit.label("Número único (35:1):", 14, UiKit.MUTED))
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 36
	spin.value = int(st.get("num", 17))
	spin.value_changed.connect(func(v): st.num = int(v))
	nh.add_child(spin)
	nh.add_child(UiKit.button("Apostar no número", func():
		st.sel = "n%d" % int(st.get("num", 17))
		ui.refresh(), sel.begins_with("n")))
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("GIRAR A ROLETA (%s)" % (("número " + sel.substr(1)) if sel.begins_with("n") else sel), func():
		if _busy() or not _take(bet):
			return
		var n := rng.randi_range(0, 36)
		var stake := bet
		var b := sel
		st.busy = true
		st.result = n
		_pending = func():
			st.busy = false
			st.last = n
			var h: Array = st.get("history", [])
			h.push_front(n)
			st.history = h.slice(0, 12)
			var pay := CasinoLogic.roulette_payout(b, n) * stake
			if pay > 0.0:
				_set_msg("DEU %d! Você ganhou %s" % [n, Fmt.money(pay)], true)
				_pay(pay)
			else:
				_set_msg("Deu %d (%s)." % [n, CasinoLogic.roulette_color(n)], false)
			ui.refresh()
		ui.refresh(), true, not _busy()))


func _side_bet_buttons(body: VBoxContainer, opts: Array) -> String:
	var sel := str(st.get("sel", opts[0][0]))
	var row := _center_row(body, 8)
	for o in opts:
		row.add_child(UiKit.button(o[1], func():
			st.sel = o[0]
			ui.refresh(), sel == o[0]))
	return sel


func _g_bacara(body: VBoxContainer) -> void:
	if st.has("hand"):
		var h: Dictionary = st.hand
		var table := _center_row(body, 60)
		_cards_row(table, "JOGADOR — %d" % int(h.pv), h.player)
		_cards_row(table, "BANCA — %d" % int(h.bv), h.banker)
	_result_line(body)
	var sel := _side_bet_buttons(body, [["jogador", "Jogador 1:1"], ["banca", "Banca 0,95:1"], ["empate", "Empate 8:1"]])
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("DISTRIBUIR", func():
		if not _take(bet):
			return
		var h := CasinoLogic.baccarat_deal(rng)
		st.hand = h
		var pay := CasinoLogic.baccarat_payout(sel, str(h.winner)) * bet
		_set_msg("Vitória: %s. %s" % [str(h.winner).to_upper(), ("Você recebeu " + Fmt.money(pay)) if pay > 0 else "Você perdeu."], pay > bet * 0.99)
		_pay(pay)
		ui.refresh(), true))
	body.add_child(UiKit.label("Regras clássicas: quem chega mais perto de 9 vence; terceira carta pela tabela oficial. Empate devolve apostas em Jogador/Banca.", 13, UiKit.MUTED, true))


func _g_bac_dados(body: VBoxContainer) -> void:
	if st.has("roll"):
		var r: Dictionary = st.roll
		var table := _center_row(body, 60)
		for side in [["JOGADOR", r.player, int(r.ps), Color("cfe8ff")], ["BANCA", r.banker, int(r.bs), Color("ffd6d6")]]:
			var col := UiKit.vbox(4)
			table.add_child(col)
			col.add_child(UiKit.label("%s — %d" % [side[0], side[2]], 16, UiKit.MUTED))
			var dr := UiKit.hbox(6)
			col.add_child(dr)
			for v in side[1]:
				dr.add_child(CasinoViews.DieView.new(int(v), side[3]))
	_result_line(body)
	var sel := _side_bet_buttons(body, [["jogador", "Jogador 1:1"], ["banca", "Banca 1:1"], ["empate", "Empate 7:1"]])
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("ROLAR OS DADOS", func():
		if not _take(bet):
			return
		var r := CasinoLogic.bac_dice(rng)
		st.roll = r
		var pay := CasinoLogic.bac_dice_payout(sel, str(r.winner)) * bet
		_set_msg("%d x %d — %s" % [int(r.ps), int(r.bs), ("Você recebeu " + Fmt.money(pay)) if pay > 0 else "Você perdeu."], pay >= bet)
		_pay(pay)
		ui.refresh(), true))
	body.add_child(UiKit.label("Cada lado rola dois dados; o maior total vence. No empate, Jogador/Banca devolvem 90% da aposta.", 13, UiKit.MUTED, true))


func _g_dragao_tigre(body: VBoxContainer) -> void:
	if st.has("res"):
		var r: Dictionary = st.res
		var table := _center_row(body, 80)
		_cards_row(table, "DRAGÃO", [r.dragon])
		_cards_row(table, "TIGRE", [r.tiger])
	_result_line(body)
	var sel := _side_bet_buttons(body, [["dragao", "Dragão 1:1"], ["tigre", "Tigre 1:1"], ["empate", "Empate 11:1"]])
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("REVELAR", func():
		if not _take(bet):
			return
		var r := CasinoLogic.dragon_tiger(rng)
		st.res = r
		var pay := CasinoLogic.dragon_tiger_payout(sel, str(r.winner)) * bet
		_set_msg("%s! %s" % [str(r.winner).to_upper(), ("Você recebeu " + Fmt.money(pay)) if pay > 0 else "Você perdeu."], pay >= bet)
		_pay(pay)
		ui.refresh(), true))
	body.add_child(UiKit.label("Uma carta para cada lado; a maior vence (Ás é a menor). No empate, Dragão/Tigre devolvem metade.", 13, UiKit.MUTED, true))


func _g_sic_bo(body: VBoxContainer) -> void:
	if st.has("dice"):
		var row := _center_row(body, 10)
		for v in st.dice:
			row.add_child(CasinoViews.DieView.new(int(v)))
	_result_line(body)
	var sel := _side_bet_buttons(body, [["pequeno", "Pequeno 4–10"], ["grande", "Grande 11–17"], ["trinca", "Qualquer trinca 30:1"]])
	var faces := _center_row(body, 6)
	faces.add_child(UiKit.label("Face:", 14, UiKit.MUTED))
	for f in range(1, 7):
		faces.add_child(UiKit.button(str(f), func():
			st.sel = "f%d" % f
			ui.refresh(), sel == "f%d" % f))
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("ROLAR 3 DADOS", func():
		if not _take(bet):
			return
		var d := CasinoLogic.sic_bo_roll(rng)
		st.dice = d
		var pay := CasinoLogic.sic_bo_payout(sel, d) * bet
		_set_msg("Total %d. %s" % [int(d[0]) + int(d[1]) + int(d[2]), ("Você recebeu " + Fmt.money(pay)) if pay > 0 else "Você perdeu."], pay > 0)
		_pay(pay)
		ui.refresh(), true))
	body.add_child(UiKit.label("Pequeno/Grande perdem em trincas. Face: paga 1:1 por dado com a face (até 3:1).", 13, UiKit.MUTED, true))


func _g_roda(body: VBoxContainer) -> void:
	var keys: Array = CasinoLogic.WHEEL_SEGMENTS.keys()
	var view := _center_row(body)
	if _busy():
		var sp := CasinoViews.Spinner.new(keys, str(st.result), func(): _settle_pending(), 2.0)
		sp.add_theme_font_size_override("font_size", 64)
		view.add_child(sp)
	elif st.has("last"):
		view.add_child(UiKit.label(str(st.last), 60, UiKit.GOLD))
	_result_line(body)
	var opts: Array = []
	for k in keys:
		opts.append([k, "%s (%d casas)" % [k, int(CasinoLogic.WHEEL_SEGMENTS[k][0])]])
	var sel := _side_bet_buttons(body, opts)
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("GIRAR A RODA", func():
		if _busy() or not _take(bet):
			return
		var seg := CasinoLogic.wheel_spin(rng)
		var stake := bet
		st.busy = true
		st.result = seg
		_pending = func():
			st.busy = false
			st.last = seg
			if seg == sel:
				var pay: float = float(CasinoLogic.WHEEL_SEGMENTS[seg][1]) * stake
				_set_msg("DEU %s! %s" % [seg, Fmt.money(pay)], true)
				_pay(pay)
			else:
				_set_msg("Deu %s." % seg, false)
			ui.refresh()
		ui.refresh(), true, not _busy()))
	body.add_child(UiKit.label("A roda tem 54 casas. Quanto mais raro o número, maior o prêmio.", 13, UiKit.MUTED, true))


# --- Instantâneos -------------------------------------------------------------------------

func _g_aviaozinho(body: VBoxContainer) -> void:
	var hist: Array = st.get("history", [])
	if hist.size() > 0:
		body.add_child(UiKit.label("Voos anteriores: " + "  ".join(PackedStringArray(hist.map(func(x): return "%.2fx" % float(x)))), 14, UiKit.MUTED))
	var holder := _center_row(body)
	if st.get("flying", false):
		var view: CasinoViews.CrashView = st.view if st.has("view") and is_instance_valid(st.view) else null
		if view == null:
			view = CasinoViews.CrashView.new(float(st.crash), float(st.get("auto", 0.0)))
			view.finished.connect(_crash_done)
			st.view = view
		if view.get_parent():
			view.get_parent().remove_child(view)
		holder.add_child(view)
		var b := UiKit.button("SACAR AGORA", func():
			if is_instance_valid(view):
				view.cash_out(), true)
		b.custom_minimum_size = Vector2(260, 56)
		_center_row(body).add_child(b)
		return
	_result_line(body)
	var auto := float(st.get("auto", 0.0))
	var ah := _center_row(body, 6)
	ah.add_child(UiKit.label("Saque automático:", 14, UiKit.MUTED))
	for a in [0.0, 1.5, 2.0, 3.0, 5.0, 10.0]:
		ah.add_child(UiKit.button("Desligado" if a == 0.0 else "%.1fx" % a, func():
			st.auto = a
			ui.refresh(), auto == a))
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("APOSTAR E DECOLAR", func():
		if not _take(bet):
			return
		st.flying = true
		st.crash = CasinoLogic.crash_point(rng)
		st.stake = bet
		st.erase("view")
		ui.refresh(), true))
	body.add_child(UiKit.label("O multiplicador sobe até o avião ir embora. Saque antes para multiplicar sua aposta. Se fechar a janela durante o voo, o saque é automático.", 13, UiKit.MUTED, true))


func _crash_done(cashed: float) -> void:
	var stake := float(st.get("stake", 0.0))
	var crash := float(st.get("crash", 1.0))
	st.flying = false
	st.erase("view")
	var h: Array = st.get("history", [])
	h.push_front(crash)
	st.history = h.slice(0, 10)
	if cashed > 0.0:
		_set_msg("SACOU EM %.2fx! %s" % [cashed, Fmt.money(stake * cashed)], true)
		_pay(roundf(stake * cashed * 100.0) / 100.0)
	else:
		_set_msg("O avião voou em %.2fx." % crash, false)
	if ui and ui.current_app == self:
		ui.refresh()


func _g_minas(body: VBoxContainer) -> void:
	var playing: bool = st.get("playing", false)
	var mines := int(st.get("mines", 3))
	var revealed: Array = st.get("revealed", [])
	var layout: Array = st.get("layout", [])
	var mult := CasinoLogic.mines_multiplier(mines, revealed.size())
	var info := UiKit.label("Minas: %d   |   Multiplicador: %.2fx   |   Próximo: %.2fx" % [mines, mult, CasinoLogic.mines_multiplier(mines, revealed.size() + 1)], 16, UiKit.GOLD)
	body.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_center_row(body).add_child(grid)
	var show_all: bool = st.get("show_all", false)
	for i in 25:
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 52)
		b.focus_mode = Control.FOCUS_NONE
		var is_mine: bool = i in layout
		if i in revealed:
			b.text = "OK"
			b.add_theme_stylebox_override("normal", UiKit.style(Color("1e6b45"), 8))
		elif show_all and is_mine:
			b.text = "MINA"
			b.add_theme_stylebox_override("normal", UiKit.style(Color("8b1e2d"), 8))
		elif show_all:
			b.text = ""
			b.add_theme_stylebox_override("normal", UiKit.style(Color("1b2540"), 8))
		else:
			b.text = "?"
		b.disabled = not playing or i in revealed
		b.pressed.connect(func():
			if is_mine:
				Audio.play("lose")
				st.playing = false
				st.show_all = true
				_pending = Callable()
				_set_msg("BOOM! Você achou uma mina.", false)
			else:
				Audio.play("cash", -10.0)
				revealed.append(i)
				st.revealed = revealed
				if revealed.size() >= 25 - mines:
					_mines_cash()
			ui.refresh())
		grid.add_child(b)
	_result_line(body)
	if playing:
		_center_row(body).add_child(UiKit.button("SACAR %s" % Fmt.money(float(st.stake) * mult), func():
			_mines_cash()
			ui.refresh(), true, revealed.size() > 0))
		return
	var mh := _center_row(body, 6)
	mh.add_child(UiKit.label("Quantidade de minas:", 14, UiKit.MUTED))
	for m in [1, 3, 5, 10, 15]:
		mh.add_child(UiKit.button(str(m), func():
			st.mines = m
			ui.refresh(), mines == m))
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("COMEÇAR", func():
		if not _take(bet):
			return
		st = {"playing": true, "mines": mines, "layout": CasinoLogic.mines_layout(rng, mines), "revealed": [], "stake": bet}
		_pending = func(): _mines_cash()
		ui.refresh(), true))


func _mines_cash() -> void:
	_pending = Callable()
	if not st.get("playing", false):
		return
	var mult := CasinoLogic.mines_multiplier(int(st.mines), st.revealed.size())
	var pay := float(st.stake) * mult
	st.playing = false
	st.show_all = true
	if st.revealed.size() == 0:
		pay = float(st.stake)
	_set_msg("Sacou %.2fx: %s" % [mult, Fmt.money(pay)], true)
	_pay(pay)


func _g_plinko(body: VBoxContainer) -> void:
	var view: CasinoViews.PlinkoView = st.view if st.has("view") and is_instance_valid(st.view) else null
	if view == null:
		view = CasinoViews.PlinkoView.new()
		view.landed.connect(func(slot):
			_settle_pending())
		st.view = view
	if view.get_parent():
		view.get_parent().remove_child(view)
	_center_row(body).add_child(view)
	_result_line(body)
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("SOLTAR BOLINHA", func():
		if _busy() or not _take(bet):
			return
		var path := CasinoLogic.plinko_drop(rng)
		var slot: int = path.reduce(func(a, b): return a + b, 0)
		var stake := bet
		st.busy = true
		_pending = func():
			st.busy = false
			var m: float = CasinoLogic.PLINKO_MULTS[slot]
			var pay := stake * m
			_set_msg("%.1fx — %s" % [m, Fmt.money(pay)], m >= 1.0)
			_pay(pay)
			if ui and ui.current_app == self:
				ui.refresh()
		view.drop(path), true, not _busy()))


func _g_dados(body: VBoxContainer) -> void:
	var target := int(st.get("target", 50))
	var over: bool = st.get("over", true)
	var chance := CasinoLogic.dice_win_chance(target, over)
	var mult := CasinoLogic.dice_multiplier(target, over)
	var view := _center_row(body)
	if _busy():
		var nums: Array = []
		for i in 100:
			nums.append(str(i))
		var sp := CasinoViews.Spinner.new(nums, str(st.roll), func(): _settle_pending(), 0.9)
		sp.add_theme_font_size_override("font_size", 64)
		view.add_child(sp)
	elif st.has("last"):
		view.add_child(UiKit.label(str(st.last), 64, UiKit.GOLD))
	_result_line(body)
	body.add_child(UiKit.label("Ganha se sair %s %d   |   Chance %s   |   Paga %.2fx" % ["ACIMA de" if over else "ABAIXO de", target, Fmt.pct(chance, 0), mult], 16))
	var slider := HSlider.new()
	slider.min_value = 5
	slider.max_value = 95
	slider.value = target
	slider.custom_minimum_size.x = 500
	slider.drag_ended.connect(func(_c):
		st.target = int(slider.value)
		ui.refresh())
	_center_row(body).add_child(slider)
	var row := _center_row(body)
	row.add_child(UiKit.button("Acima", func():
		st.over = true
		ui.refresh(), over))
	row.add_child(UiKit.button("Abaixo", func():
		st.over = false
		ui.refresh(), not over))
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("ROLAR (0–99)", func():
		if _busy() or not _take(bet):
			return
		var roll := rng.randi_range(0, 99)
		var won := roll > target if over else roll < target
		var stake := bet
		st.busy = true
		st.roll = roll
		_pending = func():
			st.busy = false
			st.last = roll
			if won:
				_set_msg("Saiu %d! %s" % [roll, Fmt.money(stake * mult)], true)
				_pay(stake * mult)
			else:
				_set_msg("Saiu %d." % roll, false)
			ui.refresh()
		ui.refresh(), true, not _busy()))


func _g_hilo(body: VBoxContainer) -> void:
	var playing: bool = st.get("playing", false)
	var row := _center_row(body, 10)
	var shown: Array = st.get("cards", [])
	for c in shown.slice(maxi(0, shown.size() - 6)):
		row.add_child(CasinoViews.CardView.new(int(c)))
	_result_line(body)
	if playing:
		var cur := CasinoLogic.rank_of(int(shown[-1]))
		var mult := float(st.mult)
		body.add_child(UiKit.label("Multiplicador atual: %.2fx  (%s)" % [mult, Fmt.money(float(st.stake) * mult)], 18, UiKit.GOLD))
		var r2 := _center_row(body)
		for higher in [true, false]:
			var step := CasinoLogic.hilo_step_mult(cur, higher)
			r2.add_child(UiKit.button("%s (%.2fx)" % ["MAIOR" if higher else "MENOR", step], func():
				var nc := CasinoLogic.draw(rng)
				shown.append(nc)
				st.cards = shown
				var nr := CasinoLogic.rank_of(nc)
				var ok: bool = nr > cur if higher else nr < cur
				if ok:
					st.mult = mult * step
					Audio.play("cash", -10.0)
				else:
					st.playing = false
					_pending = Callable()
					_set_msg("Errou! Saiu %s." % CasinoLogic.card_name(nc), false)
				ui.refresh(), true, step > 0.0))
		r2.add_child(UiKit.button("SACAR", func():
			_hilo_cash()
			ui.refresh(), false, shown.size() > 1))
		return
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("COMEÇAR", func():
		if not _take(bet):
			return
		st = {"playing": true, "cards": [CasinoLogic.draw(rng)], "mult": 1.0, "stake": bet}
		_pending = func(): _hilo_cash()
		ui.refresh(), true))
	body.add_child(UiKit.label("Adivinhe se a próxima carta é maior ou menor (empate perde). Cada acerto multiplica o prêmio.", 13, UiKit.MUTED, true))


func _hilo_cash() -> void:
	_pending = Callable()
	if not st.get("playing", false):
		return
	st.playing = false
	var pay := float(st.stake) * float(st.mult)
	_set_msg("Sacou %.2fx: %s" % [float(st.mult), Fmt.money(pay)], true)
	_pay(pay)


# --- Sorteios ---------------------------------------------------------------------------

func _g_keno(body: VBoxContainer) -> void:
	var picks: Array = st.get("picks", [])
	var drawn: Array = st.get("drawn", [])
	body.add_child(UiKit.label("Escolha de 1 a 5 números. 10 números serão sorteados entre 40.", 15, UiKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_center_row(body).add_child(grid)
	for n in range(1, 41):
		var b := Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(48, 38)
		b.focus_mode = Control.FOCUS_NONE
		var picked: bool = n in picks
		var hit: bool = n in drawn
		var col := UiKit.PANEL2
		if picked and hit:
			col = Color("1e8f55")
		elif picked:
			col = Color("8a6d1a")
		elif hit:
			col = Color("2d4d7a")
		b.add_theme_stylebox_override("normal", UiKit.style(col, 6))
		b.pressed.connect(func():
			if n in picks:
				picks.erase(n)
			elif picks.size() < 5:
				picks.append(n)
			st.picks = picks
			st.drawn = []
			st.erase("msg")
			ui.refresh())
		grid.add_child(b)
	_result_line(body)
	var table: Dictionary = CasinoLogic.KENO_PAY.get(picks.size(), {})
	var t: Array = []
	for k in table:
		t.append("%d acertos = %sx" % [k, str(table[k])])
	body.add_child(UiKit.label("Tabela para %d número(s): %s" % [picks.size(), ", ".join(t) if t.size() > 0 else "-"], 14, UiKit.TEXT, true))
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("SORTEAR", func():
		if picks.is_empty():
			sim().notify("Escolha pelo menos um número.", "error")
			return
		if not _take(bet):
			return
		var d := CasinoLogic.keno_draw(rng)
		st.drawn = d
		var m := CasinoLogic.keno_payout(picks, d)
		var hits := picks.filter(func(x): return x in d).size()
		_set_msg("%d acerto(s). %s" % [hits, ("Você recebeu " + Fmt.money(bet * m)) if m > 0 else "Sem prêmio."], m > 0)
		_pay(bet * m)
		ui.refresh(), true))


func _g_bingo(body: VBoxContainer) -> void:
	var card: Array = st.get("card", [])
	var balls: Array = st.get("balls", [])
	if card.is_empty():
		card = CasinoLogic.bingo_card(rng)
		st.card = card
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_center_row(body).add_child(grid)
	for n in card:
		var p := PanelContainer.new()
		var hit: bool = n in balls
		p.add_theme_stylebox_override("panel", UiKit.style(Color("1e8f55") if hit else UiKit.PANEL2, 8, UiKit.GOLD if hit else Color(1, 1, 1, 0.1), 1, 10))
		p.custom_minimum_size = Vector2(70, 46)
		var l := UiKit.label(str(n), 20, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		grid.add_child(p)
	if balls.size() > 0:
		body.add_child(UiKit.label("Bolas: " + " ".join(PackedStringArray(balls.map(func(x): return str(x)))), 13, UiKit.MUTED, true))
	_result_line(body)
	var t: Array = []
	for k in CasinoLogic.BINGO_PAY:
		t.append("%d = %sx" % [k, str(CasinoLogic.BINGO_PAY[k])])
	body.add_child(UiKit.label("30 bolas de 75. Prêmios por acertos: " + ", ".join(t) + " (cartela cheia!)", 13, UiKit.MUTED, true))
	_bet_bar(body)
	var row := _center_row(body)
	row.add_child(UiKit.button("Trocar cartela", func():
		st = {"card": CasinoLogic.bingo_card(rng)}
		ui.refresh()))
	row.add_child(UiKit.button("JOGAR", func():
		if not _take(bet):
			return
		var b := CasinoLogic.bingo_balls(rng)
		st.balls = b
		var hits := card.filter(func(x): return x in b).size()
		var m := float(CasinoLogic.BINGO_PAY.get(hits, 0.0))
		_set_msg("%d acertos! %s" % [hits, ("Você recebeu " + Fmt.money(bet * m)) if m > 0 else "Sem prêmio."], m > 0)
		_pay(bet * m)
		ui.refresh(), true))


func _g_raspadinha(body: VBoxContainer) -> void:
	var playing: bool = st.get("playing", false)
	var res: Dictionary = st.get("res", {})
	var shown: Array = st.get("shown", [])
	if not res.is_empty():
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_center_row(body).add_child(grid)
		for i in 9:
			if i in shown:
				var s := int(res.cells[i])
				var win: bool = s == int(res.symbol)
				grid.add_child(CasinoViews.ReelView.new(CasinoLogic.SCRATCH_SYMBOLS[s], UiKit.GOLD if win else UiKit.TEXT, false))
			else:
				var b := Button.new()
				b.text = "RASPAR"
				b.custom_minimum_size = Vector2(110, 60)
				b.focus_mode = Control.FOCUS_NONE
				b.add_theme_stylebox_override("normal", UiKit.style(Color("8a8f99"), 8))
				b.pressed.connect(func():
					shown.append(i)
					st.shown = shown
					Audio.play("step", -6.0, 1.8)
					if shown.size() >= 9:
						_scratch_done()
					ui.refresh())
				grid.add_child(b)
	_result_line(body)
	if playing:
		_center_row(body).add_child(UiKit.button("RASPAR TUDO", func():
			st.shown = [0, 1, 2, 3, 4, 5, 6, 7, 8]
			_scratch_done()
			ui.refresh(), true))
		return
	_bet_bar(body)
	_center_row(body).add_child(UiKit.button("COMPRAR RASPADINHA", func():
		if not _take(bet):
			return
		st = {"playing": true, "res": CasinoLogic.scratch(rng), "shown": [], "stake": bet}
		_pending = func():
			st.shown = [0, 1, 2, 3, 4, 5, 6, 7, 8]
			_scratch_done()
		ui.refresh(), true))
	body.add_child(UiKit.label("Três símbolos iguais ganham. Prêmios de 1x a 500x.", 13, UiKit.MUTED, true))


func _scratch_done() -> void:
	_pending = Callable()
	if not st.get("playing", false):
		return
	st.playing = false
	var m := float(st.res.mult)
	var pay := float(st.stake) * m
	if m > 0.0:
		_set_msg("3 x %s! Você ganhou %s" % [CasinoLogic.SCRATCH_SYMBOLS[int(st.res.symbol)], Fmt.money(pay)], true)
	else:
		_set_msg("Não foi dessa vez.", false)
	_pay(pay)
