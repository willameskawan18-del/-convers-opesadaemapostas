class_name DecisionPanel
extends Control
## Painel de decisão dos jogadores humanos DESTA máquina.
## Vários jogadores na mesma máquina: modo "passa o controle" com cortina entre eles.
## Tipos: choice (botões), bid (lance), reaction (tempo de reação, todos juntos).

const REACTION_KEYS := [KEY_SPACE, KEY_Q, KEY_P, KEY_Z, KEY_M, KEY_A, KEY_L, KEY_X]
const REACTION_KEY_NAMES := ["ESPAÇO", "Q", "P", "Z", "M", "A", "L", "X"]

var info: Dictionary = {}
var queue: Array = []          # pids locais que ainda não escolheram
var current := -1
var curtain_ok := false
var box: VBoxContainer
var _bid := 0
var _bid_lbl: Label
var _bid_slider: HSlider
# reação
var _react_go_at := -1.0
var _react_start := 0.0
var _react_done: Dictionary = {}
var _react_circle: Panel
var _react_lbl: Label
var _react_players: Array = []
var _react_go_shown := false


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	box = AW.vbox(12)
	var cc := AW.centered(box)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.offset_bottom = -120
	add_child(cc)
	visible = false
	Game.phase_changed.connect(_on_phase)
	Game.private_info_received.connect(func(_pid, _i): if visible and current < 0: _next())


func _on_phase(phase: String, i: Dictionary) -> void:
	if phase != "decision" and phase != "allwin_decision":
		visible = false
		AW.clear(box)
		return
	info = i
	visible = true
	current = -1
	queue = Game.local_players().map(func(p): return int(p.id))
	if str(info.get("input", "")) == "reaction":
		_start_reaction()
	else:
		_next()


func _next() -> void:
	AW.clear(box)
	queue = queue.filter(func(pid): return not Game.has_submitted(pid) and pid != current)
	current = -1
	if queue.is_empty():
		_waiting()
		return
	var pid: int = queue[0]
	if not Game.private_infos.has(pid):
		_waiting()
		return
	if Game.local_players().size() > 1 and not curtain_ok:
		_curtain(pid)
		return
	curtain_ok = false
	current = pid
	match str(info.get("input", "choice")):
		"bid": _build_bid(pid)
		_: _build_choice(pid)


func _waiting() -> void:
	if Game.local_players().is_empty():
		box.add_child(_header("VOCÊ ESTÁ ASSISTINDO", "Os jogadores estão decidindo..."))
		return
	var p := _header("ESCOLHA FEITA!", "Aguardando os outros jogadores...")
	box.add_child(p)


func _header(t: String, sub: String) -> PanelContainer:
	var p := AW.panel(Color(AW.BG, 0.85), AW.CYAN)
	var v := AW.vbox(4)
	p.add_child(v)
	v.add_child(AW.center(AW.label(t, 30, AW.GOLD, "ExtraBold", 4)))
	v.add_child(AW.center(AW.label(sub, 18, AW.MUTED)))
	return p


func _curtain(pid: int) -> void:
	var pv := Game.player_view(pid)
	var p := AW.panel(Color(AW.BG, 0.97), GameData.character_color(str(pv.character)), 30)
	var v := AW.vbox(14)
	p.add_child(v)
	v.add_child(AW.center(AW.label("VEZ DE", 22, AW.MUTED, "Bold")))
	v.add_child(AW.title(str(pv.name), 64, GameData.character_color(str(pv.character))))
	v.add_child(AW.center(AW.label("Os outros jogadores: não olhem a tela!", 20, AW.TEXT)))
	var b := AW.button("ESTOU PRONTO", func():
		curtain_ok = true
		_next(), AW.GREEN, 26, 320)
	var h := AW.hbox()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(b)
	v.add_child(h)
	box.add_child(p)
	AW.slam(p, 1.3)
	b.grab_focus()


func _context_lines(pid: int, priv: Dictionary) -> Array:
	var out := []
	var pub: Dictionary = info.get("public", {})
	match str(info.get("id", "")):
		"portas":
			out.append("Sua aposta: %s%s" % [Fmt.money(int(priv.get("stake", 0))), "  (ficha de resgate: não perde nada!)" if priv.get("free", false) else ""])
			out.append("Prêmios atrás das portas:  x5   ·   x2   ·   x0")
		"bluff":
			out.append("SUA OFERTA SECRETA: " + Fmt.money(int(priv.get("offer", 0))))
		"risco":
			out.append("Você tem " + Fmt.money(int(Game.player_view(pid).get("money", 0))))
		"allwin":
			out.append("Seu patrimônio: " + Fmt.money(int(Game.player_view(pid).get("money", 0))) + "   ·   Posição: " + Fmt.place(Game.position_in_view(pid)))
			out.append(str(pub.get("chances", "")))
	return out


func _build_choice(pid: int) -> void:
	var priv: Dictionary = Game.private_infos[pid]
	var pv := Game.player_view(pid)
	var col := GameData.character_color(str(pv.character))
	var p := AW.panel(Color(AW.BG, 0.9), Color(str(info.get("color", "#ff2e88"))), 24)
	var v := AW.vbox(14)
	p.add_child(v)
	var who := str(pv.name) + ", ESCOLHA!" if Game.local_players().size() > 1 else "SUA ESCOLHA"
	v.add_child(AW.center(AW.label(who, 22, col, "ExtraBold", 4)))
	for line in _context_lines(pid, priv):
		v.add_child(AW.center(AW.label(str(line), 20, AW.TEXT, "Bold", 3)))
	var row := AW.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var is_doors := str(info.get("id", "")) == "portas"
	var is_allwin := str(info.get("id", "")) == "allwin"
	for o in priv.get("options", []):
		var oid := str(o.id)
		var oc: Color = o.color if o.color is Color else Color(str(o.color))
		var text := str(o.label)
		var b := AW.button(text, func(): _choose(pid, {"choice": oid}), oc, 44 if is_doors else (40 if is_allwin else 34))
		if is_doors:
			b.custom_minimum_size = Vector2(190, 250)
		else:
			b.custom_minimum_size = Vector2(300 if is_allwin else 260, 120)
		var bv := AW.vbox(4)
		bv.add_child(b)
		if str(o.desc) != "?":
			var d := AW.label(str(o.desc), 16, AW.TEXT, "SemiBold", 3)
			d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			d.custom_minimum_size.x = b.custom_minimum_size.x
			AW.wrap(d)
			bv.add_child(d)
		row.add_child(bv)
	box.add_child(p)
	AW.fade_in(p, 0.3, 40)


func _build_bid(pid: int) -> void:
	var priv: Dictionary = Game.private_infos[pid]
	var pub: Dictionary = info.get("public", {})
	var maxb := int(priv.get("max_bid", 0))
	_bid = 0
	var p := AW.panel(Color(AW.BG, 0.9), AW.CYAN, 24)
	var v := AW.vbox(10)
	p.custom_minimum_size.x = 640
	p.add_child(v)
	v.add_child(AW.center(AW.label(str(pub.get("item", "PRÊMIO")), 34, AW.GOLD, "ExtraBold", 5)))
	v.add_child(AW.center(AW.label("DICA: vale entre %s e %s" % [Fmt.money(int(pub.get("hint_lo", 0))), Fmt.money(int(pub.get("hint_hi", 0)))], 20, AW.CYAN, "Bold")))
	v.add_child(AW.center(AW.label("Seu dinheiro: %s  ·  Lance secreto. O maior lance leva!" % Fmt.money(maxb), 16, AW.MUTED)))
	_bid_lbl = AW.label(Fmt.money(0), 48, Color.WHITE, "ExtraBold", 5)
	v.add_child(AW.center(_bid_lbl))
	_bid_slider = HSlider.new()
	_bid_slider.min_value = 0
	_bid_slider.max_value = maxb
	_bid_slider.step = 50
	_bid_slider.custom_minimum_size = Vector2(560, 28)
	_bid_slider.value_changed.connect(func(val):
		_bid = int(val)
		_bid_lbl.text = Fmt.money(_bid))
	v.add_child(_bid_slider)
	var q := AW.hbox(8)
	q.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(q)
	for add in [100, 500, 1000]:
		q.add_child(AW.button("+" + Fmt.money(add), func(): _bid_slider.value = mini(maxb, _bid + add), AW.PURPLE, 18))
	q.add_child(AW.button("ZERAR", func(): _bid_slider.value = 0, AW.PANEL2, 18))
	q.add_child(AW.button("ALL IN", func(): _bid_slider.value = maxb, AW.RED, 18))
	var h := AW.hbox()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(AW.button("DAR LANCE", func(): _choose(pid, {"bid": _bid}), AW.GREEN, 28, 300))
	v.add_child(h)
	box.add_child(p)
	AW.fade_in(p, 0.3, 40)


func _choose(pid: int, action: Dictionary) -> void:
	Audio.play("confirm")
	Game.submit_action(pid, action)
	queue.erase(pid)
	_next()


# --- Reação --------------------------------------------------------------------

func _start_reaction() -> void:
	AW.clear(box)
	_react_players = Game.local_players().map(func(p): return int(p.id)).slice(0, REACTION_KEYS.size())
	_react_done.clear()
	_react_go_shown = false
	_react_start = Game.clock
	_react_go_at = Game.clock + float(info.get("public", {}).get("delay", 3.0))
	if _react_players.is_empty():
		box.add_child(_header("REAÇÃO!", "Os jogadores estão a postos..."))
		return
	var p := AW.panel(Color(AW.BG, 0.85), AW.GREEN, 24)
	var v := AW.vbox(12)
	p.add_child(v)
	_react_circle = Panel.new()
	_react_circle.custom_minimum_size = Vector2(260, 260)
	_react_circle.add_theme_stylebox_override("panel", AW.glow_style(Color("8a1020"), AW.RED, 130, 6, 0))
	_react_circle.mouse_filter = Control.MOUSE_FILTER_STOP
	_react_circle.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and _react_players.size() > 0:
			_react_press(_react_players[0]))
	_react_lbl = AW.center(AW.label("ESPERE...", 40, Color.WHITE, "ExtraBold", 6))
	AW.full_rect(_react_lbl)
	_react_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_react_circle.add_child(_react_lbl)
	var cc := AW.hbox()
	cc.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(_react_circle)
	v.add_child(cc)
	var keys := AW.hbox(16)
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(keys)
	for i in _react_players.size():
		var pv := Game.player_view(_react_players[i])
		var k := AW.label("%s: [%s]%s" % [pv.name, REACTION_KEY_NAMES[i], " ou clique" if i == 0 else ""], 18, GameData.character_color(str(pv.character)), "Bold", 3)
		k.name = "K%d" % _react_players[i]
		keys.add_child(k)
	v.add_child(AW.center(AW.label("Apertou antes do VERDE? Queimou a largada!", 15, AW.MUTED)))
	box.add_child(p)


func _react_press(pid: int) -> void:
	if _react_done.has(pid) or Game.has_submitted(pid):
		return
	if Game.clock < _react_go_at:
		_react_done[pid] = -1
		Game.submit_action(pid, {"false_start": true})
		Audio.play("error")
		_set_key_text(pid, "QUEIMOU!", AW.RED)
	else:
		var ms := int((Game.clock - _react_go_at) * 1000.0 / maxf(Engine.time_scale, 0.001))
		_react_done[pid] = ms
		Game.submit_action(pid, {"ms": ms})
		Audio.play("confirm")
		_set_key_text(pid, "%d ms" % ms, AW.GREEN)
		if _react_players.size() == 1:
			_react_lbl.text = "%d ms" % ms


func _set_key_text(pid: int, t: String, c: Color) -> void:
	var k := box.find_child("K%d" % pid, true, false) as Label
	if k:
		k.text = "%s: %s" % [Game.player_view(pid).name, t]
		k.add_theme_color_override("font_color", c)
		AW.pop(k, 1.4)


func _process(_d: float) -> void:
	if not visible or str(info.get("input", "")) != "reaction" or _react_circle == null or not is_instance_valid(_react_circle):
		return
	if not _react_go_shown and Game.clock >= _react_go_at:
		_react_go_shown = true
		_react_circle.add_theme_stylebox_override("panel", AW.glow_style(Color("0f8a4a"), AW.GREEN, 130, 6, 0))
		_react_lbl.text = "AGORA!"
		Audio.play("countdown_go")
		AW.pop(_react_circle, 1.15, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or str(info.get("input", "")) != "reaction":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		for i in _react_players.size():
			if event.keycode == REACTION_KEYS[i] or (i == 0 and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)):
				_react_press(_react_players[i])
				get_viewport().set_input_as_handled()
				return
		if _react_players.size() == 1:
			_react_press(_react_players[0])
			get_viewport().set_input_as_handled()
