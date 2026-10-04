class_name MemoryGame
extends Control
## Memória: a sequência de cores pisca; depois o jogador repete clicando nos botões.
## Envia {correct, score}.

signal finished(action: Dictionary)

const COLS := [Color("ff4d6d"), Color("4dabf7"), Color("3ddc97"), Color("ffd43b"), Color("b072ff"), Color("ff9f1c")]
var sequence: Array = []
var names: Array = []
var seconds := 20.0
var _showing := true
var _idx := 0
var _t := 0.0
var _input := 0
var _done := false
var display: Panel
var display_lbl: Label
var buttons: HBoxContainer
var info: Label


func setup(public: Dictionary, _priv: Dictionary) -> void:
	sequence = public.get("sequence", [])
	names = public.get("colors", [])
	seconds = float(public.get("seconds", 20.0))


func _ready() -> void:
	custom_minimum_size = Vector2(720, 300)
	var v := AW.vbox(12)
	AW.full_rect(v)
	add_child(v)
	display = Panel.new()
	display.custom_minimum_size = Vector2(300, 150)
	display.add_theme_stylebox_override("panel", AW.glow_style(Color("1d0b40"), AW.PURPLE, 20, 4, 0))
	display_lbl = AW.center(AW.label("PRESTE ATENÇÃO!", 30, Color.WHITE, "ExtraBold", 6))
	AW.full_rect(display_lbl)
	display.add_child(display_lbl)
	var c := AW.hbox()
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(display)
	v.add_child(c)
	info = AW.center(AW.label("", 20, AW.MUTED, "Bold"))
	v.add_child(info)
	buttons = AW.hbox(8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)
	for i in COLS.size():
		var ci := i
		var b := AW.button(str(names[i]) if i < names.size() else "?", func(): _press(ci), COLS[i], 16)
		b.custom_minimum_size = Vector2(108, 64)
		b.disabled = true
		buttons.add_child(b)
	_t = -1.0


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _showing:
		var slot := 0.8
		var k := int(floor(_t / slot)) if _t >= 0.0 else -1
		if k >= sequence.size():
			_showing = false
			_t = 0.0
			display.add_theme_stylebox_override("panel", AW.glow_style(Color("1d0b40"), AW.GOLD, 20, 4, 0))
			display_lbl.text = "SUA VEZ!"
			info.text = "Repita a sequência (%d cores)" % sequence.size()
			for b in buttons.get_children():
				(b as Button).disabled = false
			return
		if k >= 0:
			var on := fmod(_t, slot) < slot * 0.7
			var ci: int = sequence[k]
			display.add_theme_stylebox_override("panel", AW.glow_style(COLS[ci] if on else Color("1d0b40"), COLS[ci], 20, 4, 0))
			display_lbl.text = str(names[ci]) if on else ""
			if on and k != _idx:
				_idx = k
				Audio.play("tick", -4.0, 0.8 + ci * 0.1)
			info.text = "%d / %d" % [k + 1, sequence.size()]
	elif _t > seconds - sequence.size() * 0.8:
		_finish()


func _press(ci: int) -> void:
	if _showing or _done:
		return
	if int(sequence[_input]) == ci:
		_input += 1
		Audio.play("coin", -6.0, 0.9 + _input * 0.05)
		display.add_theme_stylebox_override("panel", AW.glow_style(COLS[ci], COLS[ci], 20, 4, 0))
		display_lbl.text = "%d / %d" % [_input, sequence.size()]
		if _input >= sequence.size():
			display_lbl.text = "PERFEITO!"
			Audio.play("jackpot")
			_finish()
	else:
		Audio.play("error")
		display_lbl.text = "ERROU! (%d certas)" % _input
		display.add_theme_stylebox_override("panel", AW.glow_style(Color("8a1020"), AW.RED, 20, 4, 0))
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	for b in buttons.get_children():
		(b as Button).disabled = true
	get_tree().create_timer(0.9).timeout.connect(func(): finished.emit({"correct": _input, "score": float(_input) / maxf(1.0, sequence.size())}))
