class_name MatchPanels
extends Control
## Painéis da partida: intro, loja, espiar, leilão ao vivo, abertura, venda, fim do dia.

var layer: Control
var timer: TimerRing
var _auction_box: Control
var _price_lbl: Label
var _leader_lbl: Label
var _call_lbl: Label
var _bar: ProgressBar
var _hist_lbl: Label
var _bid_rows: Array = []      # [{pid, buttons:[[Button, delta]]}]
var _reveal_list: VBoxContainer
var _sell_choices: Dictionary = {}
var _shop_buy: Dictionary = {}


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer = Control.new()
	AW.full_rect(layer)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	timer = TimerRing.new()
	timer.custom_minimum_size = Vector2(90, 90)
	timer.size = Vector2(90, 90)
	timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer.position = Vector2(-45, 12)
	timer.visible = false
	add_child(timer)
	Game.phase_changed.connect(_on_phase)
	Game.step.connect(_on_step)
	Game.auction_changed.connect(_on_auction)
	Game.private_info_received.connect(func(pid, info): _on_private(pid, info))


func clear() -> void:
	AW.clear(layer)
	_auction_box = null
	_reveal_list = null
	_bid_rows.clear()
	timer.visible = false


func _center(glow: Color, w: float = 0.0, y: float = 0.0) -> VBoxContainer:
	var p := AW.panel(Color(AW.BG, 0.92), glow, 22)
	if w > 0:
		p.custom_minimum_size.x = w
	var v := AW.vbox(8)
	p.add_child(v)
	var cc := AW.centered(p)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.offset_top = y
	cc.offset_bottom = y
	layer.add_child(cc)
	AW.slam(p, 1.3, 0.3)
	return v


func _side(glow: Color, w: float = 420.0) -> VBoxContainer:
	var p := AW.panel(Color(AW.BG, 0.9), glow, 18)
	p.custom_minimum_size.x = w
	p.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.offset_right = -16
	p.offset_left = -16
	var v := AW.vbox(6)
	p.add_child(v)
	layer.add_child(p)
	AW.fade_in(p, 0.3, 0)
	return v


func banner(title: String, text: String = "", col: Color = AW.GOLD) -> void:
	var old := layer.get_node_or_null("Banner")
	if old:
		old.queue_free()
	var p := AW.panel(Color(AW.BG, 0.88), col, 16)
	p.name = "Banner"
	var v := AW.vbox(2)
	p.add_child(v)
	v.add_child(AW.title(title, 40, col))
	if text != "":
		v.add_child(AW.center(AW.label(text, 20, AW.TEXT, "Bold", 3)))
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.position.y = 110
	layer.add_child(p)
	AW.slam(p, 1.6, 0.3)


func _first_local_pending() -> int:
	for p in Game.local_players():
		if not Game.has_submitted(int(p.id)) and Game.private_infos.has(int(p.id)):
			return int(p.id)
	return -1


# --- Fases -------------------------------------------------------------------------

func _on_phase(phase: String, info: Dictionary) -> void:
	clear()
	var dl := float(info.get("deadline_in", -1.0))
	timer.visible = dl > 0.0
	timer.total = dl
	match phase:
		"intro":
			var v := _center(AW.ORANGE, 720)
			v.add_child(AW.title("LEILÃO DE GARAGEM", 64, AW.GOLD))
			v.add_child(AW.center(AW.label(str(info.get("text", "")), 24, AW.TEXT, "Bold", 3)))
			v.add_child(AW.center(AW.label("Espie o galpão, dê lances AO VIVO, abra e revenda. Quem tiver mais no fim, vence!", 17, AW.MUTED)))
		"shop":
			_build_shop()
		"peek":
			_build_peek(info)
		"auction":
			_build_auction(info)
		"open":
			_reveal_list = _side(AW.GOLD, 400)
			_reveal_list.add_child(AW.label("DENTRO DO GALPÃO", 20, AW.GOLD, "ExtraBold", 3))
		"sell":
			_build_sell()
		"day_end":
			var v := _center(AW.CYAN, 520)
			v.add_child(AW.title("FIM DO DIA %d" % int(info.get("day", 1)), 48, AW.CYAN))
			var i := 0
			for pid in info.get("ranking", []):
				i += 1
				var p := Game.player_view(int(pid))
				var h := AW.hbox(10)
				var n := AW.label("%dº  %s" % [i, p.get("name", "?")], 22, GameData.character_color(str(p.get("character", ""))), "Bold", 3)
				n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(n)
				h.add_child(AW.label(Fmt.money(int(p.get("money", 0))), 22, AW.GOLD, "ExtraBold", 3))
				v.add_child(h)
		"collections":
			banner("COLEÇÕES", "Itens guardados valem o preço cheio. 3 do mesmo tipo = +50%!", AW.PURPLE)


func _on_private(pid: int, info: Dictionary) -> void:
	var ph := str(Game.view.get("phase", ""))
	if ph == "sell" and _first_local_pending() == pid and layer.get_child_count() == 0:
		_build_sell()
	elif ph == "shop" and layer.get_child_count() == 0:
		_build_shop()


# --- Loja ---------------------------------------------------------------------------

func _build_shop() -> void:
	var pid := _first_local_pending()
	if pid < 0:
		banner("LOJA DE MELHORIAS", "Os outros compradores estão comprando...", AW.CYAN)
		return
	var priv: Dictionary = Game.private_infos[pid]
	_shop_buy.clear()
	var v := _center(AW.CYAN, 860)
	v.add_child(AW.title("LOJA DE MELHORIAS", 44, AW.CYAN))
	v.add_child(AW.center(AW.label("Você tem %s. As melhorias valem até o fim do jogo." % Fmt.money(int(priv.money)), 18, AW.TEXT, "Bold")))
	var row := AW.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var ups: Dictionary = priv.upgrades
	var owned: Dictionary = priv.owned
	for k in ups:
		var key := str(k)
		var u: Array = ups[k]
		var card := AW.panel(Color(AW.PANEL, 0.95), AW.GOLD if owned.has(key) else AW.PURPLE, 14)
		card.custom_minimum_size = Vector2(250, 190)
		var cv := AW.vbox(6)
		card.add_child(cv)
		cv.add_child(AW.center(AW.label(str(u[1]), 24, AW.GOLD, "ExtraBold", 3)))
		var d := AW.label(str(u[2]), 15, AW.TEXT)
		AW.wrap(d)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.custom_minimum_size.x = 220
		cv.add_child(d)
		if owned.has(key):
			cv.add_child(AW.center(AW.label("JÁ É SEU", 18, AW.GREEN, "ExtraBold")))
		else:
			var b := AW.button("COMPRAR " + Fmt.money(int(u[0])), func(): pass, AW.GREEN.darkened(0.2), 17)
			b.toggle_mode = true
			b.disabled = int(priv.money) < int(u[0])
			b.toggled.connect(func(on): _shop_buy[key] = on)
			cv.add_child(b)
		row.add_child(card)
	var h := AW.hbox()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(AW.button("CONFIRMAR", func():
		var buy := _shop_buy.keys().filter(func(x): return _shop_buy[x])
		Game.submit_action(pid, {"buy": buy})
		clear()
		banner("PRONTO!", "Esperando os outros...", AW.GREEN), AW.GREEN, 24, 300))
	v.add_child(h)


# --- Espiar ---------------------------------------------------------------------------

func _build_peek(info: Dictionary) -> void:
	banner("GALPÃO %d — ESPIE!" % int(info.unit), "A porta abriu só um pouquinho... olhe bem antes do leilão.", AW.ORANGE)
	var v := _side(AW.ORANGE, 430)
	v.add_child(AW.label("O QUE DÁ PARA VER", 20, AW.ORANGE, "ExtraBold", 3))
	v.add_child(AW.label("Volumes lá dentro: ~%d" % int(info.count), 16, AW.TEXT, "Bold"))
	var r := AW.label("Boato: " + str(info.rumor), 15, AW.CYAN, "SemiBold")
	AW.wrap(r)
	r.custom_minimum_size.x = 390
	v.add_child(r)
	var local := Game.local_players()
	var pid := int(local[0].id) if local.size() > 0 else -1
	var priv: Dictionary = Game.private_infos.get(pid, {})
	if str(priv.get("kind", "")) != "peek":
		for it in info.get("visible_public", []):
			v.add_child(AW.label("• " + str(it.name), 16, AW.TEXT))
		return
	for it in priv.get("visible", []):
		var t := "• " + str(it.name)
		if it.has("est"):
			t += "   (" + str(it.est) + ")"
		v.add_child(AW.label(t, 16, AW.TEXT))
	if str(priv.get("tip", "")) != "":
		var tl := AW.label(str(priv.tip), 15, AW.GOLD, "Bold")
		AW.wrap(tl)
		tl.custom_minimum_size.x = 390
		v.add_child(tl)
	var b := AW.button("PRONTO", func():
		Game.submit_action(pid, {"ready": true}), AW.GREEN, 20, 380)
	v.add_child(b)


# --- Leilão ao vivo ----------------------------------------------------------------------

func _build_auction(info: Dictionary) -> void:
	var p := AW.panel(Color(AW.BG, 0.93), AW.GOLD, 18)
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -16
	p.custom_minimum_size.x = 820
	var v := AW.vbox(6)
	p.add_child(v)
	layer.add_child(p)
	_auction_box = p
	var top := AW.hbox(16)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(AW.label("GALPÃO %d" % int(info.get("unit", 0)), 20, AW.ORANGE, "ExtraBold", 3))
	_call_lbl = AW.label("LANCES ABERTOS!", 22, AW.CYAN, "ExtraBold", 4)
	top.add_child(_call_lbl)
	v.add_child(top)
	_price_lbl = AW.title("$0", 64, AW.GOLD)
	v.add_child(_price_lbl)
	_leader_lbl = AW.center(AW.label("Ninguém deu lance ainda", 20, AW.TEXT, "Bold", 3))
	v.add_child(_leader_lbl)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(760, 14)
	_bar.max_value = 9.0
	v.add_child(_bar)
	for lp in Game.local_players():
		var pid := int(lp.id)
		var row := AW.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		if Game.local_players().size() > 1:
			row.add_child(AW.label(str(lp.name), 16, GameData.character_color(str(lp.character)), "Bold"))
		var buttons := []
		for d in [0, 500, 1000, 5000]:
			var delta: int = d
			var b := AW.button("LANCE" if delta == 0 else "+" + Fmt.money(delta), func(): _bid(pid, delta), AW.GREEN if delta == 0 else AW.PURPLE, 22 if delta == 0 else 18)
			if delta == 0:
				b.custom_minimum_size.x = 230
			row.add_child(b)
			buttons.append([b, delta])
		v.add_child(row)
		_bid_rows.append({"pid": pid, "buttons": buttons})
	_hist_lbl = AW.center(AW.label("", 14, AW.MUTED))
	v.add_child(_hist_lbl)
	_on_auction(Game.view.get("auction", {}))


func _bid(pid: int, delta: int) -> void:
	var a: Dictionary = Game.view.get("auction", {})
	var amount := int(a.get("next_min", 100)) + delta
	Audio.play("confirm")
	Game.bid(pid, amount)


func _on_auction(a: Dictionary) -> void:
	if _auction_box == null or not is_instance_valid(_auction_box) or a.is_empty():
		return
	var price := int(a.get("price", 0))
	_price_lbl.text = Fmt.money(price) if int(a.get("leader", -1)) >= 0 else "LANCE INICIAL " + Fmt.money(int(a.get("next_min", 100)))
	_price_lbl.add_theme_font_size_override("font_size", 64 if int(a.get("leader", -1)) >= 0 else 40)
	AW.pop(_price_lbl, 1.15, 0.2)
	if int(a.get("leader", -1)) >= 0:
		var mine := Game.local_players().any(func(p): return int(p.id) == int(a.leader))
		_leader_lbl.text = ("VOCÊ ESTÁ NA FRENTE!" if mine else "Maior lance: " + str(a.leader_name))
		_leader_lbl.add_theme_color_override("font_color", AW.GREEN if mine else AW.TEXT)
	var call := str(a.get("call", ""))
	_call_lbl.text = call if call != "" else "LANCES ABERTOS!"
	_call_lbl.add_theme_color_override("font_color", AW.RED if call != "" else AW.CYAN)
	if call != "":
		AW.pop(_call_lbl, 1.5, 0.3)
	var hist := []
	for h in a.get("history", []):
		hist.append("%s %s" % [h[0], Fmt.money(int(h[1]))])
	_hist_lbl.text = "  ·  ".join(hist.slice(maxi(0, hist.size() - 5)))
	var nm := int(a.get("next_min", 100))
	for r in _bid_rows:
		var me := Game.player_view(int(r.pid))
		var money := int(me.get("money", 0))
		for bd in r.buttons:
			var b: Button = bd[0]
			var amt: int = nm + int(bd[1])
			if int(bd[1]) == 0:
				b.text = "LANCE " + Fmt.money(amt)
			b.disabled = amt > money or int(a.get("leader", -1)) == int(r.pid) or float(a.get("ends_in", 0.0)) <= 0.0


func _process(_d: float) -> void:
	if timer.visible:
		timer.left = Game.time_left()
		timer.queue_redraw()
	if _bar and is_instance_valid(_bar):
		_bar.value = Game.auction_left()


# --- Abertura e vendas -----------------------------------------------------------------

func _on_step(s: Dictionary) -> void:
	match str(s.kind):
		"door":
			banner(str(s.title), "", AW.ORANGE)
		"item":
			if _reveal_list == null or not is_instance_valid(_reveal_list):
				return
			var it: Dictionary = s.item
			var est := "???" if it.mystery else "%s – %s" % [Fmt.money(int(it.est_lo)), Fmt.money(int(it.est_hi))]
			var h := AW.hbox(8)
			var n := AW.label(str(it.name), 16 if not s.big else 18, AW.GOLD if s.big else AW.TEXT, "Bold" if not s.big else "ExtraBold", 2)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n)
			h.add_child(AW.label(est, 15, AW.GREEN if not it.mystery else AW.PURPLE, "Bold"))
			_reveal_list.add_child(h)
			AW.pop(n, 1.4 if s.big else 1.1, 0.25)
			Audio.play("jackpot" if s.big else "coin", -2.0 if s.big else -8.0)
		"summary":
			var good := int(s.est_hi + s.est_lo) / 2 > int(s.paid)
			banner(str(s.title), str(s.text), AW.GREEN if good else AW.RED)
		"sales":
			var v := _center(GameData.character_color(str(Game.player_view(int(s.pid)).get("character", ""))), 640, -20)
			v.add_child(AW.label(str(s.title), 26, AW.GOLD, "ExtraBold", 3))
			for r in s.rows:
				var h := AW.hbox(8)
				var n := AW.label(str(r[0]), 15, AW.TEXT, "SemiBold")
				n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(n)
				h.add_child(AW.label(str(r[1]), 15, AW.GOLD if int(r[2]) > 1500 else (AW.RED if str(r[1]).contains("VAZIO") else AW.GREEN), "Bold"))
				v.add_child(h)
		"collection":
			banner(str(s.title), str(s.text), AW.PURPLE)


# --- Vender ---------------------------------------------------------------------------

func _build_sell() -> void:
	clear()
	timer.visible = true
	var pid := _first_local_pending()
	if pid < 0:
		banner("HORA DE VENDER", "Os compradores estão decidindo...", AW.GREEN)
		return
	var priv: Dictionary = Game.private_infos[pid]
	if str(priv.get("kind", "")) != "sell":
		return
	_sell_choices.clear()
	var v := _center(AW.GREEN, 980, -30)
	v.add_child(AW.title("HORA DE VENDER", 40, AW.GREEN))
	var cols: Dictionary = priv.get("collections", {})
	var ctext := []
	for c in cols:
		ctext.append("%s: %d" % [GameData.load_json("items").categories.get(c, c), int(cols[c])])
	v.add_child(AW.center(AW.label("LOJA: 85% garantido  ·  ONLINE: 50% a 160% (sorte!)  ·  GUARDAR: coleção no fim (3 iguais = +50%)", 14, AW.MUTED)))
	if ctext.size() > 0:
		v.add_child(AW.center(AW.label("Sua coleção: " + ", ".join(ctext), 14, AW.PURPLE, "Bold")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(940, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := AW.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	v.add_child(scroll)
	var cats: Dictionary = GameData.load_json("items").categories
	for it in priv.get("items", []):
		var uid := str(it.uid)
		var row := AW.hbox(6)
		var nm := AW.label(str(it.name), 15, AW.GOLD if it.rare else AW.TEXT, "Bold")
		nm.custom_minimum_size.x = 250
		nm.clip_text = true
		row.add_child(nm)
		var ct := AW.label(str(cats.get(it.cat, it.cat)), 12, AW.MUTED)
		ct.custom_minimum_size.x = 120
		row.add_child(ct)
		var est := AW.label("???" if it.mystery else "%s–%s" % [Fmt.money(int(it.est_lo)), Fmt.money(int(it.est_hi))], 13, AW.GREEN)
		est.custom_minimum_size.x = 140
		row.add_child(est)
		var opts := [["abrir", "ABRIR", AW.GOLD], ["fechado", "VENDER FECHADO", AW.PANEL2]] if it.mystery else [["loja", "LOJA", AW.GREEN.darkened(0.2)], ["online", "ONLINE", AW.ORANGE.darkened(0.2)], ["guardar", "GUARDAR", AW.PURPLE.darkened(0.2)]]
		var group := ButtonGroup.new()
		for o in opts:
			var key: String = o[0]
			var b := AW.button(str(o[1]), func(): _sell_choices[uid] = key, o[2], 13)
			b.toggle_mode = true
			b.button_group = group
			row.add_child(b)
			if o == opts[0]:
				b.button_pressed = true
				_sell_choices[uid] = key
		list.add_child(row)
	var h := AW.hbox()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(AW.button("CONFIRMAR VENDAS", func():
		Game.submit_action(pid, {"choices": _sell_choices.duplicate()})
		if _first_local_pending() >= 0:
			_build_sell()
		else:
			clear()
			banner("VENDAS ENVIADAS!", "Esperando os outros...", AW.GREEN), AW.GREEN, 22, 320))
	v.add_child(h)
