class_name PrecisionGame
extends Control
## Barra de precisão: o marcador vai e volta; aperte (clique/ESPAÇO) para parar.
## Opcionalmente escolhe a aposta antes. Envia {offset, stake, score}.

signal finished(action: Dictionary)

var speed := 1.3
var stakes: Array = []
var stake_idx := 0
var seconds := 10.0
var _pos := 0.0
var _dir := 1.0
var _running := false
var _done := false
var _t := 0.0
var _result := ""
var _offset := 1.0
var bar: Control
var info_lbl: Label
var stake_row: HBoxContainer


func setup(public: Dictionary, priv: Dictionary) -> void:
	speed = float(public.get("speed", 1.3))
	seconds = float(public.get("seconds", 10.0))
	if not public.get("no_stake", false):
		stakes = priv.get("stakes", [])


func _ready() -> void:
	custom_minimum_size = Vector2(700, 230)
	var v := AW.vbox(10)
	AW.full_rect(v)
	add_child(v)
	stake_row = AW.hbox(10)
	stake_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(stake_row)
	if stakes.is_empty():
		stake_row.visible = false
		_running = true
	else:
		stake_row.add_child(AW.label("APOSTA:", 20, AW.TEXT, "Bold"))
		var names := ["BAIXA", "MÉDIA", "ALTA"]
		var cols := [AW.GREEN, AW.ORANGE, AW.RED]
		for i in stakes.size():
			var idx := i
			stake_row.add_child(AW.button("%s %s" % [names[i], Fmt.money(int(stakes[i]))], func(): _choose_stake(idx), cols[i], 18))
	bar = Control.new()
	bar.custom_minimum_size = Vector2(680, 90)
	bar.draw.connect(_draw_bar)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_stop())
	v.add_child(bar)
	info_lbl = AW.center(AW.label("Escolha a aposta para começar!" if not stakes.is_empty() else "CLIQUE ou ESPAÇO para parar!", 22, AW.GOLD, "ExtraBold", 4))
	v.add_child(info_lbl)


func _choose_stake(i: int) -> void:
	stake_idx = i
	stake_row.visible = false
	_running = true
	_t = 0.0
	info_lbl.text = "CLIQUE ou ESPAÇO para parar!"
	Audio.play("confirm")


func _process(delta: float) -> void:
	if _done:
		return
	if _running:
		_t += delta
		_pos += _dir * delta * speed
		if _pos >= 1.0:
			_pos = 1.0
			_dir = -1.0
		elif _pos <= 0.0:
			_pos = 0.0
			_dir = 1.0
		if _t > seconds:
			_stop()
	bar.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _running and not _done and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		_stop()
		get_viewport().set_input_as_handled()


func _stop() -> void:
	if not _running or _done:
		return
	_done = true
	_running = false
	_offset = absf(_pos - 0.5) / 0.5
	_result = SkillChallengeGrade.label(_offset)
	info_lbl.text = "%s!  (%d%% do centro)" % [_result, int(_offset * 100.0)]
	info_lbl.add_theme_color_override("font_color", AW.GREEN if _offset <= 0.25 else AW.RED)
	AW.pop(info_lbl, 1.6)
	Audio.play("win" if _offset <= 0.12 else ("confirm" if _offset <= 0.25 else "error"))
	bar.queue_redraw()
	get_tree().create_timer(0.9).timeout.connect(func(): finished.emit({"offset": _offset, "stake": stake_idx, "score": 1.0 - _offset}))


func _draw_bar() -> void:
	var w := bar.size.x
	var h := bar.size.y
	var y0 := h * 0.25
	var bh := h * 0.5
	bar.draw_rect(Rect2(0, y0, w, bh), Color("2a1257"))
	var zones := [[0.25, AW.ORANGE.darkened(0.2)], [0.12, AW.GREEN.darkened(0.1)], [0.04, AW.GOLD]]
	for z in zones:
		var half: float = float(z[0]) * w / 2.0
		bar.draw_rect(Rect2(w / 2.0 - half, y0, half * 2.0, bh), z[1])
	bar.draw_rect(Rect2(0, y0, w, bh), Color(1, 1, 1, 0.4), false, 2.0)
	var x := _pos * w
	bar.draw_rect(Rect2(x - 4, 0, 8, h), Color.WHITE)
	bar.draw_circle(Vector2(x, 6), 9, AW.PINK)
