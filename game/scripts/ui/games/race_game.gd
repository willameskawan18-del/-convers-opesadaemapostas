class_name RaceGame
extends Control
## Corrida: aperte ESPAÇO (ou CORRER) várias vezes para acelerar e ↑/W (ou PULAR) nos
## obstáculos. Bateu? Tropeça e perde tempo. Envia {time, score}.

signal finished(action: Dictionary)

var length := 100.0
var obstacles: Array = []
var seconds := 20.0
var color := Color.WHITE
var _x := 0.0
var _v := 0.0
var _jump := 0.0
var _stun := 0.0
var _t := 0.0
var _done := false
var _hit: Dictionary = {}
var _go_in := 1.5
var track: Control
var info: Label


func setup(public: Dictionary, _priv: Dictionary) -> void:
	length = float(public.get("length", 100.0))
	obstacles = public.get("obstacles", [])
	seconds = float(public.get("seconds", 20.0))


func _ready() -> void:
	custom_minimum_size = Vector2(760, 250)
	var v := AW.vbox(10)
	AW.full_rect(v)
	add_child(v)
	track = Control.new()
	track.custom_minimum_size = Vector2(760, 140)
	track.draw.connect(_draw_track)
	v.add_child(track)
	info = AW.center(AW.label("PREPARAR...", 24, AW.GOLD, "ExtraBold", 4))
	v.add_child(info)
	var h := AW.hbox(20)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var run := AW.button("CORRER (ESPAÇO)", _tap, AW.GREEN, 20, 260)
	run.focus_mode = Control.FOCUS_NONE
	var jmp := AW.button("PULAR (↑ / W)", _do_jump, AW.CYAN.darkened(0.2), 20, 220)
	jmp.focus_mode = Control.FOCUS_NONE
	h.add_child(run)
	h.add_child(jmp)
	v.add_child(h)


func _tap() -> void:
	if _done or _go_in > 0.0 or _stun > 0.0:
		return
	_v = minf(_v + 2.2, 16.0)


func _do_jump() -> void:
	if _done or _go_in > 0.0 or _jump > 0.0:
		return
	_jump = 0.6
	Audio.play("whoosh", -10.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_tap()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_UP, KEY_W]:
			_do_jump()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _done:
		return
	if _go_in > 0.0:
		_go_in -= delta
		info.text = "PREPARAR..." if _go_in > 0.5 else "JÁ!"
		if _go_in <= 0.0:
			Audio.play("countdown_go")
		track.queue_redraw()
		return
	_t += delta
	_jump = maxf(0.0, _jump - delta)
	if _stun > 0.0:
		_stun -= delta
		_v = 0.0
	else:
		_v = maxf(0.0, _v - delta * 5.0)
	var nx := _x + _v * delta
	for o in obstacles:
		var ox := float(o)
		if _x < ox and nx >= ox and _jump <= 0.0 and not _hit.has(ox):
			_hit[ox] = true
			_stun = 0.9
			nx = ox - 0.5
			Audio.play("error", -4.0)
			info.text = "TROPEÇOU!"
	_x = nx
	if _stun <= 0.0:
		info.text = "%.1fs  ·  %d%%" % [_t, int(_x / length * 100.0)]
	if _x >= length:
		_finish(_t)
	elif _t >= seconds:
		_finish(99.0)
	track.queue_redraw()


func _finish(time: float) -> void:
	_done = true
	info.text = ("CHEGOU! %.2fs" % time) if time < 90.0 else "NÃO TERMINOU!"
	Audio.play("win" if time < 90.0 else "lose")
	get_tree().create_timer(1.0).timeout.connect(func(): finished.emit({"time": snappedf(time, 0.01), "score": clampf((20.0 - time) / 12.0, 0.0, 1.0)}))


func _draw_track() -> void:
	var w := track.size.x
	var h := track.size.y
	track.draw_rect(Rect2(0, h * 0.55, w, h * 0.3), Color("3a1f2b"))
	for i in 12:
		track.draw_rect(Rect2(i * w / 12.0, h * 0.69, w / 24.0, 3), Color(1, 1, 1, 0.3))
	var sx := func(x: float) -> float: return 30.0 + x / length * (w - 60.0)
	track.draw_rect(Rect2(sx.call(length), h * 0.35, 6, h * 0.5), Color.WHITE)
	for o in obstacles:
		var ox: float = sx.call(float(o))
		track.draw_rect(Rect2(ox - 5, h * 0.42, 10, h * 0.22), AW.ORANGE)
	var px: float = sx.call(_x)
	var jy := -sin(clampf(_jump / 0.6, 0.0, 1.0) * PI) * 38.0 if _jump > 0.0 else 0.0
	var col := AW.PINK if _stun <= 0.0 else AW.RED
	track.draw_circle(Vector2(px, h * 0.5 + jy), 16, col)
	track.draw_circle(Vector2(px + 5, h * 0.47 + jy), 4, Color.WHITE)
