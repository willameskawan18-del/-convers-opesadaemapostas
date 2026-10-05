class_name TargetGame
extends Control
## Tiro ao alvo (15 s): clique nos alvos. NORMAL +1 · DOURADO +3 · x2 dobra os pontos ·
## VERMELHO -3 · JACKPOT (raro) leva o jackpot. Envia {points, score, jackpot}.

signal finished(action: Dictionary)

const AREA := Vector2(760, 340)
var seconds := 15.0
var rng := RandomNumberGenerator.new()
var jackpot_target := false
var _targets: Array = []   # {pos, kind, r, life, max}
var _t := 0.0
var _spawn := 0.0
var _points := 0
var _jackpot := false
var _jp_time := -1.0
var _done := false
var _started := false
var _hud: Label
var _flashes: Array = []   # [pos, text, color, t]


func setup(public: Dictionary, _priv: Dictionary) -> void:
	seconds = float(public.get("seconds", 15.0))
	rng.seed = int(public.get("seed", 1)) + randi() % 1000
	jackpot_target = bool(public.get("jackpot_target", false))
	if jackpot_target:
		_jp_time = rng.randf_range(4.0, seconds - 3.0)


func _ready() -> void:
	custom_minimum_size = AREA + Vector2(0, 40)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hud = AW.label("", 22, AW.GOLD, "ExtraBold", 4)
	_hud.position = Vector2(10, AREA.y + 4)
	add_child(_hud)
	_started = true


func _process(delta: float) -> void:
	if _done or not _started:
		return
	_t += delta
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = rng.randf_range(0.3, 0.55)
		var r := rng.randf()
		var kind := "normal"
		if r < 0.15:
			kind = "gold"
		elif r < 0.25:
			kind = "mult"
		elif r < 0.43:
			kind = "neg"
		var life := rng.randf_range(0.9, 1.5)
		_targets.append({"pos": Vector2(rng.randf_range(40, AREA.x - 40), rng.randf_range(40, AREA.y - 40)), "kind": kind, "r": 30.0 if kind != "gold" else 24.0, "life": life, "max": life})
	if _jp_time > 0.0 and _t >= _jp_time:
		_jp_time = -1.0
		_targets.append({"pos": Vector2(rng.randf_range(60, AREA.x - 60), rng.randf_range(60, AREA.y - 60)), "kind": "jackpot", "r": 20.0, "life": 0.9, "max": 0.9})
	for tg in _targets:
		tg.life = float(tg.life) - delta
	_targets = _targets.filter(func(tg): return float(tg.life) > 0.0)
	for f in _flashes:
		f[3] = float(f[3]) - delta
	_flashes = _flashes.filter(func(f): return float(f[3]) > 0.0)
	_hud.text = "PONTOS: %d    TEMPO: %d" % [_points, ceili(maxf(0.0, seconds - _t))]
	if _t >= seconds:
		_done = true
		Audio.play("whoosh")
		finished.emit({"points": _points, "score": clampf(_points / 40.0, 0.0, 1.0), "jackpot": _jackpot})
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _done or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	for i in range(_targets.size() - 1, -1, -1):
		var tg: Dictionary = _targets[i]
		if p.distance_to(tg.pos) <= float(tg.r):
			_hit(tg)
			_targets.remove_at(i)
			return
	Audio.play("hover", -10.0)


func _hit(tg: Dictionary) -> void:
	var txt := ""
	var col := Color.WHITE
	match str(tg.kind):
		"normal":
			_points += 1
			txt = "+1"
			Audio.play("coin", -8.0)
		"gold":
			_points += 3
			txt = "+3"
			col = AW.GOLD
			Audio.play("money_gain", -6.0)
		"mult":
			_points = _points * 2 if _points > 0 else _points + 2
			txt = "x2!"
			col = AW.CYAN
			Audio.play("win", -6.0)
		"neg":
			_points -= 3
			txt = "-3"
			col = AW.RED
			Audio.play("error", -4.0)
		"jackpot":
			_points += 5
			_jackpot = true
			txt = "JACKPOT!!!"
			col = AW.GOLD
			Audio.play("jackpot")
	_flashes.append([tg.pos, txt, col, 0.6])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, AREA), Color("0d0420"))
	draw_rect(Rect2(Vector2.ZERO, AREA), Color(AW.PINK, 0.6), false, 3.0)
	for tg in _targets:
		var p: Vector2 = tg.pos
		var r: float = tg.r * clampf(float(tg.life) / float(tg.max) * 3.0, 0.3, 1.0)
		match str(tg.kind):
			"normal":
				draw_circle(p, r, Color.WHITE)
				draw_circle(p, r * 0.66, AW.PINK)
				draw_circle(p, r * 0.33, Color.WHITE)
			"gold":
				draw_circle(p, r, AW.GOLD)
				draw_circle(p, r * 0.5, Color("fff3b0"))
			"mult":
				draw_circle(p, r, AW.CYAN)
				_text(p, "x2", Color("0d0420"))
			"neg":
				draw_circle(p, r, AW.RED)
				_text(p, "-3", Color.WHITE)
			"jackpot":
				draw_circle(p, r + 6.0 + sin(_t * 30.0) * 3.0, Color(AW.GOLD, 0.5))
				draw_circle(p, r, AW.GOLD)
				_text(p, "$", Color("0d0420"))
	for f in _flashes:
		_text(f[0] + Vector2(0, -20 - (0.6 - float(f[3])) * 40.0), str(f[1]), f[2])


func _text(p: Vector2, t: String, c: Color) -> void:
	var f := AW.font("ExtraBold")
	var s := f.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	draw_string(f, p + Vector2(-s.x / 2.0, 7), t, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, c)
