class_name DecisionPanel
extends Control
## Painel de decisão dos jogadores humanos DESTA máquina.
## Vários jogadores na mesma máquina: "passa o controle" com cortina entre eles.
## Entradas: choice (botões em vários layouts), auction (lances abertos), reaction,
## precision / targets / memory / race (minijogos de habilidade em games/).

const REACTION_KEYS := [KEY_SPACE, KEY_Q, KEY_P, KEY_Z, KEY_M, KEY_A, KEY_L, KEY_X]
const REACTION_KEY_NAMES := ["ESPAÇO", "Q", "P", "Z", "M", "A", "L", "X"]
const SKILL_GAMES := {"precision": "PrecisionGame", "targets": "TargetGame", "memory": "MemoryGame", "race": "RaceGame"}

var info: Dictionary = {}
var queue: Array = []          # pids locais que ainda não escolheram
var current := -1
var curtain_ok := false
var box: VBoxContainer
var _shield_cb: CheckButton
var _shown_at := 0.0
var _bid := 0
var _bid_lbl: Label
var _bid_slider: HSlider
# reação
var _react_go_at := -1.0
var _react_done: Dictionary = {}
var _react_circle: Panel
var _react_lbl: Label
var _react_players: Array = []
var _react_go_shown := false


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	box = AW.vbox(10)
	var cc := AW.centered(box)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.offset_top = 60
	cc.offset_bottom = -120
	add_child(cc)
	visible = false
	Game.phase_changed.connect(_on_phase)
	Game.private_info_received.connect(func(_pid, _i): if visible and current < 0 and str(info.get("input", "")) != "reaction": _next())


func _input_type() -> String:
	return str(info.get("input", "choice"))


func _on_phase(phase: String, i: Dictionary) -> void:
	if phase != "decision" and phase != "allwin_decision":
		visible = false
		AW.clear(box)
		return
	info = i
	visible = true
	current = -1
	curtain_ok = false
	var deciders: Array = i.get("deciders", [])
	queue = Game.local_players().map(func(p): return int(p.id)).filter(func(pid): return deciders.has(pid))
	if _input_type() == "reaction":
		_start_reaction()
	else:
		_next()


func _has_private(pid: int) -> bool:
	return Game.private_infos.has(pid) and int(Game.private_infos[pid].get("stage", 1)) == int(info.get("stage", 1))


func _next() -> void:
	AW.clear(box)
	_shield_cb = null
	queue = queue.filter(func(pid): return not Game.has_submitted(pid) and pid != current)
	current = -1
	if queue.is_empty():
		_waiting()
		return
	var pid: int = queue[0]
	if not _has_private(pid):
		_waiting()
		return
	if Game.local_players().size() > 1 and not curtain_ok:
		_curtain(pid)
		return
	curtain_ok = false
	current = pid
	_shown_at = Game.clock
	var it := _input_type()
	if it == "auction":
		_build_auction(pid)
	elif SKILL_GAMES.has(it):
		_build_skill(pid, it)
	else:
		_build_choice(pid)


func _waiting() -> void:
	var local := Game.local_players()
	if local.is_empty():
		box.add_child(_header("VOCÊ ESTÁ ASSISTINDO", "Os jogadores estão decidindo..."))
		return
	var deciders: Array = info.get("deciders", [])
	var mine_in := local.any(func(p): return deciders.has(int(p.id)))
	if not mine_in:
		box.add_child(_header("VOCÊ ESTÁ FORA DESTA ETAPA", "Assista os outros decidirem..."))
		return
	box.add_child(_header("ESCOLHA FEITA!", "Aguardando os outros jogadores..."))


func _header(t: String, sub: String) -> PanelContainer:
	var p := AW.panel(Color(AW.BG, 0.85), AW.CYAN)
	var v := AW.vbox(4)
	p.add_child(v)
	v.add_child(AW.center(AW.label(t, 30, AW.GOLD, "ExtraBold", 4)))
	v.add_child(AW.center(AW.label(sub, 18, AW.MUTED)))
	return p


func _curtain(pid: int) -> void:
	var pv := Game.player_view(pid)
	var col := GameData.character_color(str(pv.character))
	var p := AW.panel(Color(AW.BG, 0.97), col, 30)
	var v := AW.vbox(14)
	p.add_child(v)
	v.add_child(AW.center(AW.label("VEZ DE", 22, AW.MUTED, "Bold")))
	v.add_child(AW.title(str(pv.name), 64, col))
	v.add_child(AW.center(AW.label("Os outros jogadores: não olhem a tela!", 20, AW.TEXT)))
	if Game.missions.has(pid):
		var m := AW.center(AW.label("Sua missão secreta: " + str(Game.missions[pid]), 16, AW.GOLD, "Bold"))
		v.add_child(m)
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


## Cabeçalho comum: quem, título da etapa, pergunta (prompt), linhas e SAFE CARD.
func _panel_for(pid: int, glow: Color, min_w: float = 0.0) -> VBoxContainer:
	var priv: Dictionary = Game.private_infos[pid]
	var pv := Game.player_view(pid)
	var col := GameData.character_color(str(pv.character))
	var p := AW.panel(Color(AW.BG, 0.92), glow, 22)
	if min_w > 0:
		p.custom_minimum_size.x = min_w
	var v := AW.vbox(8)
	p.add_child(v)
	var top := AW.hbox(10)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	var who := str(pv.name) + ", SUA VEZ!" if Game.local_players().size() > 1 else "SUA DECISÃO"
	top.add_child(AW.label(who, 18, col, "ExtraBold", 4))
	var st := str(info.get("stage_title", ""))
	if st != "":
		top.add_child(AW.label("·  " + st, 18, AW.CYAN, "Bold", 3))
	v.add_child(top)
	if str(priv.get("prompt", "")) != "":
		var pr := AW.label(str(priv.prompt), 28 if str(priv.prompt).length() < 60 else 22, Color.WHITE, "ExtraBold", 5)
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		AW.wrap(pr)
		pr.custom_minimum_size.x = 760
		v.add_child(pr)
	var small: bool = priv.get("small_lines", false)
	for line in priv.get("lines", []):
		var l := AW.label(str(line), 15 if small else 18, AW.TEXT if not str(line).ends_with(":") else AW.GOLD, "SemiBold" if small else "Bold", 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if small else HORIZONTAL_ALIGNMENT_CENTER
		AW.wrap(l)
		l.custom_minimum_size.x = 760
		v.add_child(l)
	if int(priv.get("shields", 0)) > 0:
		_shield_cb = CheckButton.new()
		_shield_cb.text = "USAR SAFE CARD (protege das perdas deste desafio) — você tem %d" % int(priv.shields)
		_shield_cb.add_theme_color_override("font_color", AW.CYAN)
		var sh := AW.hbox()
		sh.alignment = BoxContainer.ALIGNMENT_CENTER
		sh.add_child(_shield_cb)
		v.add_child(sh)
	box.add_child(p)
	AW.fade_in(p, 0.25, 30)
	return v


func _build_choice(pid: int) -> void:
	var priv: Dictionary = Game.private_infos[pid]
	var v := _panel_for(pid, Color(str(info.get("color", "#ff2e88"))))
	var layout := str(priv.get("layout", ""))
	var opts: Array = priv.get("options", [])
	var is_allwin := str(info.get("id", "")) == "allwin"
	var container: Container
	match layout:
		"grid":
			var g := GridContainer.new()
			g.columns = 2
			g.add_theme_constant_override("h_separation", 12)
			g.add_theme_constant_override("v_separation", 12)
			container = g
		"boxes", "cards":
			var g := GridContainer.new()
			g.columns = 6 if layout == "boxes" else 4
			g.add_theme_constant_override("h_separation", 10)
			g.add_theme_constant_override("v_separation", 10)
			container = g
		"list":
			container = AW.vbox(8)
		_:
			var h := AW.hbox(16)
			h.alignment = BoxContainer.ALIGNMENT_CENTER
			container = h
	var wrap := CenterContainer.new()
	wrap.add_child(container)
	v.add_child(wrap)
	if layout == "boxes":
		_build_boxes(pid, container as GridContainer, priv, opts)
	else:
		for o in opts:
			container.add_child(_option_button(pid, o, layout, is_allwin))
	if str(priv.get("footer", "")) != "":
		v.add_child(AW.center(AW.label(str(priv.footer), 16, AW.GOLD, "Bold", 3)))


func _option_button(pid: int, o: Dictionary, layout: String, is_allwin: bool) -> Control:
	var oid := str(o.id)
	var oc: Color = o.color if o.color is Color else Color(str(o.color))
	var size := 30
	var min_size := Vector2(240, 96)
	match layout:
		"grid":
			size = 20
			min_size = Vector2(380, 70)
		"doors":
			size = 36
			min_size = Vector2(220, 210)
		"cards":
			size = 44
			min_size = Vector2(120, 150)
		"list":
			size = 18
			min_size = Vector2(620, 54)
	if is_allwin:
		size = 40
		min_size = Vector2(300, 120)
	var b := AW.button(str(o.label), func(): _choose(pid, {"choice": oid}), oc, size)
	b.custom_minimum_size = min_size
	if layout == "grid" or layout == "list":
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desc := str(o.get("desc", ""))
	if desc == "" or desc == "?":
		return b
	var bv := AW.vbox(4)
	bv.add_child(b)
	var d := AW.label(desc, 15, AW.TEXT, "SemiBold", 3)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size.x = min_size.x
	AW.wrap(d)
	bv.add_child(d)
	return bv


func _build_boxes(pid: int, grid: GridContainer, priv: Dictionary, opts: Array) -> void:
	var revealed: Dictionary = priv.get("revealed", {})
	var available := {}
	var stop_opt: Dictionary = {}
	for o in opts:
		if str(o.id) == "stop":
			stop_opt = o
		else:
			available[int(o.id)] = o
	var count := int(info.get("public", {}).get("count", 12))
	for i in count:
		if available.has(i):
			var idx := str(i)
			var b := AW.button(str(i + 1), func(): _choose(pid, {"choice": idx}), AW.PURPLE, 30)
			b.custom_minimum_size = Vector2(100, 80)
			grid.add_child(b)
		else:
			var r := str(revealed.get(i, revealed.get(str(i), "?")))
			var txt: String = {"bomb": "BOMBA", "jackpot": "JACKPOT"}.get(r, r)
			var p := Panel.new()
			p.custom_minimum_size = Vector2(100, 80)
			p.add_theme_stylebox_override("panel", AW.style(Color("8a1020") if r == "bomb" else (Color("7a5a00") if r == "jackpot" else Color("12402c")), 14))
			var l := AW.center(AW.label(txt, 16, Color.WHITE, "ExtraBold", 3))
			AW.full_rect(l)
			p.add_child(l)
			grid.add_child(p)
	if not stop_opt.is_empty():
		var h := AW.hbox()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(AW.button(str(stop_opt.label), func(): _choose(pid, {"choice": "stop"}), AW.GREEN, 26, 360))
		grid.get_parent().get_parent().add_child(h)


func _build_auction(pid: int) -> void:
	var priv: Dictionary = Game.private_infos[pid]
	var v := _panel_for(pid, AW.ORANGE, 760)
	var maxb := int(priv.get("max_bid", 0))
	var minb := int(priv.get("min_bid", 0))
	var high := int(priv.get("high", 0))
	var high_name := str(priv.get("high_name", ""))
	var hist: Array = priv.get("history", [])
	var info_row := AW.hbox(20)
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.add_child(AW.label("MAIOR LANCE: " + (Fmt.money(high) + " (" + high_name + ")" if high > 0 else "nenhum"), 20, AW.GOLD, "ExtraBold", 3))
	info_row.add_child(AW.label("Você tem " + Fmt.money(maxb), 18, AW.TEXT, "Bold"))
	v.add_child(info_row)
	if hist.size() > 0:
		var hs := []
		for h in hist.slice(maxi(0, hist.size() - 6)):
			hs.append("%s: %s" % [h[0], "passou" if int(h[1]) < 0 else Fmt.money(int(h[1]))])
		var hl := AW.label("Lances: " + "  ·  ".join(hs), 15, AW.MUTED, "SemiBold")
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		AW.wrap(hl)
		hl.custom_minimum_size.x = 740
		v.add_child(hl)
	var is_high := high_name == str(Game.player_view(pid).get("name", "")) and high > 0
	if maxb < minb and not is_high:
		v.add_child(AW.center(AW.label("Você não tem dinheiro para cobrir o lance.", 18, AW.RED, "Bold")))
		var h0 := AW.hbox()
		h0.alignment = BoxContainer.ALIGNMENT_CENTER
		h0.add_child(AW.button("PASSAR", func(): _choose(pid, {"pass": true}), AW.PANEL2, 24, 260))
		v.add_child(h0)
		return
	_bid = mini(minb, maxb)
	_bid_lbl = AW.center(AW.label(Fmt.money(_bid), 44, Color.WHITE, "ExtraBold", 5))
	v.add_child(_bid_lbl)
	_bid_slider = HSlider.new()
	_bid_slider.min_value = minb
	_bid_slider.max_value = maxi(minb, maxb)
	_bid_slider.step = 50
	_bid_slider.value = minb
	_bid_slider.custom_minimum_size = Vector2(620, 28)
	_bid_slider.value_changed.connect(func(val):
		_bid = int(val)
		_bid_lbl.text = Fmt.money(_bid))
	v.add_child(_bid_slider)
	var q := AW.hbox(8)
	q.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(q)
	for add in [200, 500, 1000, 3000]:
		q.add_child(AW.button("+" + Fmt.money(add), func(): _bid_slider.value = mini(maxb, _bid + add), AW.PURPLE, 16))
	q.add_child(AW.button("ALL IN", func(): _bid_slider.value = maxb, AW.RED, 16))
	var h := AW.hbox(14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(AW.button("DAR LANCE", func(): _choose(pid, {"bid": _bid}), AW.GREEN, 26, 260))
	h.add_child(AW.button("SEGURAR MEU LANCE" if is_high else "PASSAR (sair)", func(): _choose(pid, {"pass": true}), AW.PANEL2, 22, 260))
	v.add_child(h)


func _build_skill(pid: int, it: String) -> void:
	var priv: Dictionary = Game.private_infos[pid]
	var v := _panel_for(pid, AW.GREEN)
	var game: Control
	match it:
		"precision": game = PrecisionGame.new()
		"targets": game = TargetGame.new()
		"memory": game = MemoryGame.new()
		_: game = RaceGame.new()
	game.setup(info.get("public", {}), priv)
	game.finished.connect(func(action: Dictionary): _choose(pid, action))
	var cc := CenterContainer.new()
	cc.add_child(game)
	v.add_child(cc)


func _choose(pid: int, action: Dictionary) -> void:
	if current != pid:
		return
	if _shield_cb and _shield_cb.button_pressed:
		action["shield"] = true
	if bool(Game.private_infos.get(pid, {}).get("timed", false)) and not action.has("ms"):
		action["ms"] = int((Game.clock - _shown_at) * 1000.0 / maxf(Engine.time_scale, 0.001))
	Audio.play("confirm")
	Game.submit_action(pid, action)
	queue.erase(pid)
	_next()


# --- Reação --------------------------------------------------------------------

func _start_reaction() -> void:
	AW.clear(box)
	var deciders: Array = info.get("deciders", [])
	_react_players = Game.local_players().map(func(p): return int(p.id)).filter(func(pid): return deciders.has(pid)).slice(0, REACTION_KEYS.size())
	_react_done.clear()
	_react_go_shown = false
	_react_go_at = Game.clock + float(info.get("public", {}).get("delay", 3.0))
	if _react_players.is_empty():
		box.add_child(_header("REFLEXO!", "Os jogadores estão a postos..."))
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
	if not visible or _input_type() != "reaction" or _react_circle == null or not is_instance_valid(_react_circle):
		return
	if not _react_go_shown and Game.clock >= _react_go_at:
		_react_go_shown = true
		_react_circle.add_theme_stylebox_override("panel", AW.glow_style(Color("0f8a4a"), AW.GREEN, 130, 6, 0))
		_react_lbl.text = "AGORA!"
		Audio.play("countdown_go")
		AW.pop(_react_circle, 1.15, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _input_type() != "reaction":
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
