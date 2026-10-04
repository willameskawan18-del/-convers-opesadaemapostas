class_name PhaseOverlay
extends Control
## Apresentação 2D por cima da arena: aberturas, cartão do desafio, revelações
## (moeda, lances, tempos, roleta do ALL WIN), resultado da rodada e faixas de cinema.

var layer: Control
var bars: Array[ColorRect] = []
var _reels: Array = []      # [{lbl, result, stop_at}]
var _reel_t := 0.0
var _spin := false
var _countdown_lbl: Label


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		b.custom_minimum_size.y = 0
		b.size.y = 0
		add_child(b)
		bars.append(b)
	layer = Control.new()
	AW.full_rect(layer)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_countdown_lbl = AW.title("", 160, AW.RED)
	_countdown_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_countdown_lbl.visible = false
	add_child(_countdown_lbl)
	Game.phase_changed.connect(_on_phase)
	Game.reveal_step.connect(_on_step)


func letterbox(on: bool) -> void:
	var h := 70.0 if on else 0.0
	for i in bars.size():
		var b := bars[i]
		var tw := b.create_tween()
		if i == 0:
			tw.tween_property(b, "offset_bottom", h, 0.6)
		else:
			tw.tween_property(b, "offset_top", -h, 0.6)


func clear() -> void:
	AW.clear(layer)
	_reels.clear()
	_spin = false


func _center_panel(glow: Color, min_w: float = 0.0, y_off: float = 0.0) -> VBoxContainer:
	var p := AW.panel(Color(AW.BG, 0.88), glow, 26)
	if min_w > 0:
		p.custom_minimum_size.x = min_w
	var v := AW.vbox(8)
	p.add_child(v)
	var cc := AW.centered(p)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.offset_top = y_off
	cc.offset_bottom = y_off
	layer.add_child(cc)
	AW.slam(p, 1.6, 0.4)
	return v


## Faixa no topo (não cobre os personagens)
func banner(title: String, text: String = "", col: Color = AW.GOLD) -> void:
	clear()
	var p := AW.panel(Color(AW.BG, 0.85), col, 18)
	var v := AW.vbox(2)
	p.add_child(v)
	v.add_child(AW.title(title, 46, col))
	if text != "":
		var t := AW.center(AW.label(text, 22, AW.TEXT, "Bold", 4))
		AW.wrap(t)
		t.custom_minimum_size.x = 700
		v.add_child(t)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.position.y = 86
	layer.add_child(p)
	AW.slam(p, 1.8, 0.35)


# --- Fases -----------------------------------------------------------------------

func _on_phase(phase: String, info: Dictionary) -> void:
	_countdown_lbl.visible = false
	match phase:
		"intro":
			clear()
			letterbox(false)
			var v := _center_panel(AW.GOLD, 720)
			v.add_child(AW.center(AW.label("SENHORAS E SENHORES...", 22, AW.CYAN, "Bold")))
			v.add_child(AW.title("ALL WIN", 110))
			v.add_child(AW.center(AW.label(str(info.get("text", "")), 26, AW.TEXT, "Bold", 4)))
			v.add_child(AW.center(AW.label("Termine com o MAIOR patrimônio. Arrisque. Blefe. Vire o jogo.", 18, AW.MUTED)))
		"round_intro", "event_intro":
			clear()
			_challenge_card(phase, info)
		"decision", "allwin_decision":
			clear()
			if phase == "allwin_decision":
				var t := AW.title("ALL WIN  OU  SAFE?", 44, AW.GOLD)
				t.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
				t.grow_horizontal = Control.GROW_DIRECTION_BOTH
				t.position.y = 80
				layer.add_child(t)
		"reveal", "allwin_reveal":
			clear()
		"round_results":
			_round_results(info)
		"allwin_intro":
			clear()
			letterbox(true)
			_allwin_intro(info)
		"final":
			clear()
			letterbox(false)


func _challenge_card(phase: String, info: Dictionary) -> void:
	var col := Color(str(info.get("color", "#ff2e88")))
	var v := _center_panel(col, 760, -40)
	var r := int(Game.view.get("round", 0))
	var top := "EVENTO ESPECIAL!" if phase == "event_intro" else "RODADA %d DE %d" % [r, int(Game.view.get("total_rounds", 0))]
	v.add_child(AW.center(AW.label(top, 24, AW.CYAN, "ExtraBold", 4)))
	var title_text := str(info.get("title", ""))
	if phase == "event_intro":
		title_text = str(info.get("public", {}).get("title", title_text))
	var t := AW.title(title_text, 84, col.lightened(0.2))
	v.add_child(t)
	# "roleta" de nomes antes de cravar o desafio
	if phase == "round_intro":
		var names := ["AS PORTAS", "RISCO", "REAÇÃO", "LEILÃO", "BLUFF"]
		var tw := t.create_tween()
		for i in 10:
			tw.tween_callback(func():
				t.text = names[i % names.size()]
				Audio.play("tick", -8.0, 1.0 + i * 0.05)).set_delay(0.07 + i * 0.012)
		tw.tween_callback(func():
			t.text = title_text
			Audio.play("reveal")
			AW.pop(t, 1.6))
	else:
		Audio.play("jackpot")
	var tag := str(info.get("tagline", ""))
	if phase == "event_intro":
		tag = str(info.get("public", {}).get("text", ""))
	v.add_child(AW.center(AW.label(tag, 24, AW.TEXT, "Bold", 4)))
	if phase == "round_intro":
		var rules := AW.label(str(info.get("rules", "")), 19, AW.MUTED, "SemiBold")
		rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		AW.wrap(rules)
		rules.custom_minimum_size.x = 700
		v.add_child(rules)


func _allwin_intro(info: Dictionary) -> void:
	var cc := Control.new()
	AW.full_rect(cc)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cc)
	var v := AW.vbox(6)
	var c2 := AW.centered(v)
	c2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c2)
	var pre := AW.center(AW.label("A RODADA FINAL", 28, AW.TEXT, "ExtraBold", 5))
	v.add_child(pre)
	var big := AW.title("ALL WIN", 170, AW.GOLD)
	big.modulate.a = 0.0
	v.add_child(big)
	var lines := [
		"SAFE: você guarda 90% do seu patrimônio.",
		"ALL WIN: tudo na roleta!  JACKPOT x4  ·  DOBROU x2  ·  ou PERDE quase tudo.",
		"Quem está atrás... ainda pode virar o jogo.",
	]
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(func():
		big.modulate.a = 1.0
		AW.slam(big, 4.0, 0.5)
		Audio.play("jackpot"))
	for l in lines:
		var lbl := AW.center(AW.label(l, 22, AW.TEXT, "Bold", 4))
		lbl.modulate.a = 0.0
		v.add_child(lbl)
		tw.tween_interval(1.2)
		tw.tween_callback(func():
			lbl.modulate.a = 1.0
			AW.pop(lbl, 1.3)
			Audio.play("whoosh"))


func _round_results(info: Dictionary) -> void:
	clear()
	var v := _center_panel(AW.CYAN, 560, -30)
	v.add_child(AW.center(AW.label("PLACAR", 34, AW.GOLD, "ExtraBold", 5)))
	var deltas: Dictionary = info.get("deltas", {})
	var winners: Array = info.get("winners", [])
	var pos := 0
	for pid in info.get("ranking", []):
		pos += 1
		var pv := Game.player_view(int(pid))
		var d := int(deltas.get(pid, deltas.get(str(pid), 0)))
		var row := AW.hbox(10)
		var place := AW.label(Fmt.place(Game.position_in_view(int(pid))), 24, AW.place_color(Game.position_in_view(int(pid))), "ExtraBold", 3)
		place.custom_minimum_size.x = 50
		row.add_child(place)
		var nm := AW.label(str(pv.get("name", "?")) + ("  ★ VENCEU A RODADA" if winners.has(pid) or winners.has(int(pid)) else ""), 20,
			GameData.character_color(str(pv.get("character", ""))), "Bold", 3)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var dl := AW.label(Fmt.delta(d) if d != 0 else "—", 18, AW.GREEN if d > 0 else (AW.RED if d < 0 else AW.MUTED), "Bold", 3)
		dl.custom_minimum_size.x = 110
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(dl)
		var ml := AW.label(Fmt.money(int(pv.get("money", 0))), 22, AW.GOLD, "ExtraBold", 3)
		ml.custom_minimum_size.x = 120
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(ml)
		v.add_child(row)
		row.modulate.a = 0.0
		var tw := row.create_tween()
		tw.tween_interval(0.12 * pos)
		tw.tween_property(row, "modulate:a", 1.0, 0.25)


# --- Revelações -------------------------------------------------------------------

func _on_step(s: Dictionary) -> void:
	var kind := str(s.kind)
	var col := _fx_color(str(s.fx))
	match kind:
		"reaction_board": _list_panel(str(s.title), _reaction_rows(s.board))
		"bids": _list_panel(str(s.title) + " — " + str(s.text), _bid_rows(s.bids))
		"coin": _coin(s)
		"prize": _prize(s)
		"event_intro":
			banner(str(s.title), str(s.text), AW.GOLD)
		"allwin_choices": _allwin_cards(s)
		"allwin_spin": _allwin_spin(s)
		"allwin_result": _allwin_result(s)
		_:
			if s.has("pid") and int(s.pid) >= 0:
				col = GameData.character_color(str(Game.player_view(int(s.pid)).get("character", ""))).lerp(col, 0.4)
			banner(str(s.title), str(s.text), col)


func _fx_color(fx: String) -> Color:
	match fx:
		"win": return AW.GREEN
		"lose": return AW.RED
		"jackpot": return AW.GOLD
		"drumroll", "suspense": return AW.PURPLE
	return AW.CYAN


func _list_panel(title: String, rows: Array) -> void:
	clear()
	var v := _center_panel(AW.CYAN, 520, -40)
	v.add_child(AW.center(AW.label(title, 28, AW.GOLD, "ExtraBold", 4)))
	var i := 0
	for r in rows:
		var row := AW.hbox(10)
		var a := AW.label(str(r[0]), 22, r[2], "Bold", 3)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(a)
		row.add_child(AW.label(str(r[1]), 22, r[3], "ExtraBold", 3))
		v.add_child(row)
		row.modulate.a = 0.0
		var tw := row.create_tween()
		tw.tween_interval(0.25 * i)
		tw.tween_property(row, "modulate:a", 1.0, 0.2)
		tw.tween_callback(func(): Audio.play("tick", -6.0))
		i += 1


func _pcol(pid: int) -> Color:
	return GameData.character_color(str(Game.player_view(pid).get("character", "")))


func _reaction_rows(board: Array) -> Array:
	var out := []
	var place := 0
	for b in board:
		var pid := int(b[0])
		var ms := int(b[1])
		var nm := str(Game.player_view(pid).get("name", "?"))
		if ms >= 0:
			place += 1
			out.append(["%dº  %s" % [place, nm], "%d ms" % ms, _pcol(pid), AW.GOLD if place == 1 else AW.TEXT])
		elif ms == -1:
			out.append(["X  " + nm, "QUEIMOU", _pcol(pid), AW.RED])
		else:
			out.append(["—  " + nm, "DORMIU", _pcol(pid), AW.MUTED])
	return out


func _bid_rows(bids: Array) -> Array:
	var out := []
	for i in bids.size():
		var pid := int(bids[i][0])
		out.append(["%s%s" % ["★ " if i == 0 and int(bids[i][1]) > 0 else "", Game.player_view(pid).get("name", "?")], Fmt.money(int(bids[i][1])), _pcol(pid), AW.GOLD if i == 0 else AW.TEXT])
	return out


func _coin(s: Dictionary) -> void:
	clear()
	var won := str(s.get("coin", "")) == "win"
	var v := _center_panel(AW.GOLD if won else AW.RED, 0, -60)
	var name_l := AW.title(str(Game.player_view(int(s.pid)).get("name", "")), 40, _pcol(int(s.pid)))
	v.add_child(name_l)
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(200, 200)
	coin.add_theme_stylebox_override("panel", AW.glow_style(Color("b8860b"), AW.GOLD, 100, 8, 0))
	var face := AW.center(AW.label("?", 54, Color.WHITE, "ExtraBold", 6))
	AW.full_rect(face)
	coin.add_child(face)
	var h := AW.hbox()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(coin)
	v.add_child(h)
	var res := AW.title("", 44, AW.GREEN if won else AW.RED)
	v.add_child(res)
	var tw := coin.create_tween()
	for i in 6:
		tw.tween_callback(func():
			coin.pivot_offset = coin.size / 2.0
			Audio.play("coin", -6.0, 0.8 + i * 0.08))
		tw.tween_property(coin, "scale:x", 0.05, 0.08)
		tw.tween_callback(func(): face.text = "$" if i % 2 == 0 else "X")
		tw.tween_property(coin, "scale:x", 1.0, 0.08)
	tw.tween_callback(func():
		face.text = "$" if won else "X"
		coin.add_theme_stylebox_override("panel", AW.glow_style(Color("0f8a4a") if won else Color("8a1020"), AW.GREEN if won else AW.RED, 100, 8, 0))
		res.text = ("GANHOU " if won else "PERDEU ") + str(s.text)
		AW.slam(res, 2.0, 0.3))


func _prize(s: Dictionary) -> void:
	clear()
	var v := _center_panel(_fx_color(str(s.fx)), 520, -40)
	var box_l := AW.title("?", 120, AW.GOLD)
	v.add_child(box_l)
	var sub := AW.center(AW.label("", 24, AW.TEXT, "Bold", 4))
	v.add_child(sub)
	var tw := box_l.create_tween()
	for i in 8:
		tw.tween_property(box_l, "rotation", 0.12 if i % 2 == 0 else -0.12, 0.06)
	tw.tween_callback(func():
		box_l.rotation = 0.0
		box_l.text = str(s.title)
		box_l.add_theme_font_size_override("font_size", 56)
		box_l.add_theme_color_override("font_color", _fx_color(str(s.fx)))
		sub.text = str(s.text)
		AW.slam(box_l, 2.5, 0.4))


func _allwin_cards(s: Dictionary) -> void:
	clear()
	var t := AW.title(str(s.title), 46, AW.GOLD)
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	t.grow_horizontal = Control.GROW_DIRECTION_BOTH
	t.position.y = 84
	layer.add_child(t)
	var row := AW.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cc := AW.centered(row)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cc)
	var choices: Dictionary = s.choices
	for pid in choices:
		var ch := str(choices[pid])
		var allin := ch == "ALL WIN"
		var card := AW.panel(Color(AW.BG, 0.92), AW.GOLD if allin else AW.GREEN, 14)
		card.custom_minimum_size = Vector2(150, 170)
		var v := AW.vbox(6)
		card.add_child(v)
		v.add_child(AW.center(AW.label(str(Game.player_view(int(pid)).get("name", "")), 18, _pcol(int(pid)), "Bold", 3)))
		var face := AW.title("?", 40, AW.TEXT)
		v.add_child(face)
		row.add_child(card)
		# todas viram AO MESMO TEMPO
		var tw := card.create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(func(): card.pivot_offset = card.size / 2.0)
		tw.tween_property(card, "scale:x", 0.0, 0.18)
		tw.tween_callback(func():
			face.text = ch
			face.add_theme_color_override("font_color", AW.GOLD if allin else AW.GREEN)
			face.add_theme_font_size_override("font_size", 34))
		tw.tween_property(card, "scale:x", 1.0, 0.18)


func _allwin_spin(s: Dictionary) -> void:
	clear()
	var t := AW.title("TUDO OU NADA...", 50, AW.GOLD)
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	t.grow_horizontal = Control.GROW_DIRECTION_BOTH
	t.position.y = 84
	layer.add_child(t)
	var row := AW.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cc := AW.centered(row)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cc)
	var results: Dictionary = s.results
	_reels.clear()
	_reel_t = 0.0
	_spin = true
	for pid in s.players:
		var card := AW.panel(Color(AW.BG, 0.94), _pcol(int(pid)), 14)
		card.custom_minimum_size = Vector2(190, 190)
		var v := AW.vbox(6)
		card.add_child(v)
		v.add_child(AW.center(AW.label(str(Game.player_view(int(pid)).get("name", "")), 20, _pcol(int(pid)), "Bold", 3)))
		var reel := AW.title("x2", 46, AW.TEXT)
		v.add_child(reel)
		row.add_child(card)
		var res := str(results.get(pid, results.get(str(pid), "lose")))
		_reels.append({"lbl": reel, "result": res, "stop_at": float(s.duration) - 0.6})


func _reel_text(r: String) -> String:
	return {"jackpot": "JACKPOT x4", "double": "DOBROU x2", "lose": "PERDEU"}.get(r, r)


func _reel_color(r: String) -> Color:
	return {"jackpot": AW.GOLD, "double": AW.GREEN, "lose": AW.RED}.get(r, AW.TEXT)


func _allwin_result(s: Dictionary) -> void:
	_spin = false
	var results: Dictionary = s.results
	var any_jackpot := false
	for r in _reels:
		var l: Label = r.lbl
		l.text = _reel_text(str(r.result))
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", _reel_color(str(r.result)))
		AW.slam(l, 2.2, 0.35)
		if str(r.result) == "jackpot":
			any_jackpot = true
	var t := AW.title("JACKPOT!!!" if any_jackpot else "RESULTADO!", 56, AW.GOLD)
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	t.grow_horizontal = Control.GROW_DIRECTION_BOTH
	t.position.y = -200
	layer.add_child(t)
	AW.slam(t, 3.0, 0.4)
	if results.is_empty():
		pass


func _process(delta: float) -> void:
	if _spin:
		_reel_t += delta
		var opts := ["jackpot", "double", "lose"]
		for r in _reels:
			var l: Label = r.lbl
			if _reel_t < float(r.stop_at):
				var speed := lerpf(18.0, 4.0, clampf(_reel_t / float(r.stop_at), 0.0, 1.0))
				var idx := int(_reel_t * speed) % 3
				var txt := _reel_text(opts[idx])
				if l.text != txt:
					l.text = txt
					l.add_theme_color_override("font_color", _reel_color(opts[idx]))
					l.add_theme_font_size_override("font_size", 30)
					Audio.play("tick", -14.0, 1.4)
	# contagem regressiva dramática na decisão final
	var ph := str(Game.view.get("phase", ""))
	if ph == "allwin_decision" and Game.time_left() <= 5.0 and Game.time_left() > 0.0:
		_countdown_lbl.visible = true
		var n := str(ceili(Game.time_left()))
		if _countdown_lbl.text != n:
			_countdown_lbl.text = n
			_countdown_lbl.pivot_offset = _countdown_lbl.size / 2.0
			AW.pop(_countdown_lbl, 2.0, 0.4)
	elif _countdown_lbl.visible and ph != "allwin_decision":
		_countdown_lbl.visible = false
