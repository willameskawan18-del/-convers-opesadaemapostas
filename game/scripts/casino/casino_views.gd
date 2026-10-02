class_name CasinoViews
## Componentes visuais dos jogos: cartas desenhadas (naipes vetoriais), dados, rolos,
## gráfico do aviãozinho, tabuleiro de plinko e um "revelador" animado genérico.


## Carta de baralho desenhada por código.
class CardView extends Control:
	var card := 0
	var face_down := false

	func _init(c: int = 0, h: bool = false) -> void:
		card = c
		face_down = h
		custom_minimum_size = Vector2(62, 88)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(7)
		sb.shadow_size = 4
		sb.shadow_color = Color(0, 0, 0, 0.4)
		if face_down:
			sb.bg_color = Color("7a1d2c")
			sb.border_color = Color("f5c542")
			sb.set_border_width_all(2)
			draw_style_box(sb, r)
			for i in 6:
				draw_line(Vector2(8 + i * 9, 8), Vector2(8, 8 + i * 12), Color(1, 0.85, 0.4, 0.35), 1.5)
			return
		sb.bg_color = Color("fbfaf6")
		sb.border_color = Color(0, 0, 0, 0.2)
		sb.set_border_width_all(1)
		draw_style_box(sb, r)
		var suit := CasinoLogic.suit_of(card)
		var col := Color("d0312d") if suit == 1 or suit == 2 else Color("1b1b22")
		var font := get_theme_default_font()
		var rank: String = CasinoLogic.RANKS[CasinoLogic.rank_of(card)]
		draw_string(font, Vector2(6, 20), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
		CasinoViews.draw_suit(self, suit, size / 2.0 + Vector2(0, 6), 15.0, col)
		CasinoViews.draw_suit(self, suit, Vector2(12, 32), 5.0, col)


static func draw_suit(ci: CanvasItem, suit: int, c: Vector2, s: float, col: Color) -> void:
	match suit:
		1: # copas
			ci.draw_circle(c + Vector2(-s * 0.48, -s * 0.25), s * 0.52, col)
			ci.draw_circle(c + Vector2(s * 0.48, -s * 0.25), s * 0.52, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.98, -s * 0.05), c + Vector2(s * 0.98, -s * 0.05), c + Vector2(0, s * 1.05)]), col)
		2: # ouros
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, 0), c + Vector2(0, s), c + Vector2(-s * 0.75, 0)]), col)
		0: # espadas
			ci.draw_circle(c + Vector2(-s * 0.45, s * 0.2), s * 0.5, col)
			ci.draw_circle(c + Vector2(s * 0.45, s * 0.2), s * 0.5, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.93, s * 0.05), c + Vector2(s * 0.93, s * 0.05), c + Vector2(0, -s * 1.05)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.3), c + Vector2(s * 0.35, s * 1.0), c + Vector2(-s * 0.35, s * 1.0)]), col)
		3: # paus
			ci.draw_circle(c + Vector2(0, -s * 0.45), s * 0.42, col)
			ci.draw_circle(c + Vector2(-s * 0.48, s * 0.15), s * 0.42, col)
			ci.draw_circle(c + Vector2(s * 0.48, s * 0.15), s * 0.42, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(s * 0.32, s * 1.0), c + Vector2(-s * 0.32, s * 1.0)]), col)


## Dado com pontos.
class DieView extends Control:
	var value := 1
	var tint := Color("fbfaf6")

	func _init(v: int = 1, t: Color = Color("fbfaf6")) -> void:
		value = v
		tint = t
		custom_minimum_size = Vector2(54, 54)

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = tint
		sb.set_corner_radius_all(10)
		sb.shadow_size = 4
		sb.shadow_color = Color(0, 0, 0, 0.4)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var pip := Color("c0392b") if value == 1 else Color("1b1b22")
		var pts := {1: [[0.5, 0.5]], 2: [[0.28, 0.28], [0.72, 0.72]], 3: [[0.25, 0.25], [0.5, 0.5], [0.75, 0.75]],
			4: [[0.28, 0.28], [0.72, 0.28], [0.28, 0.72], [0.72, 0.72]], 5: [[0.25, 0.25], [0.75, 0.25], [0.5, 0.5], [0.25, 0.75], [0.75, 0.75]],
			6: [[0.28, 0.22], [0.72, 0.22], [0.28, 0.5], [0.72, 0.5], [0.28, 0.78], [0.72, 0.78]]}
		for p in pts.get(value, []):
			draw_circle(Vector2(p[0], p[1]) * size, size.x * 0.085, pip)


## Símbolo de rolo (caça-níquel).
class ReelView extends PanelContainer:
	func _init(text: String, col: Color, big: bool = true) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("10131f")
		sb.border_color = col.darkened(0.2)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		add_theme_stylebox_override("panel", sb)
		custom_minimum_size = Vector2(130, 110) if big else Vector2(70, 60)
		var l := Label.new()
		l.text = text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 26 if big else 14)
		l.add_theme_color_override("font_color", col)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		add_child(l)


## Revelador: mostra valores aleatórios girando e, ao fim, chama on_done uma única vez
## (também se a janela for fechada antes — o resultado nunca se perde).
class Spinner extends Label:
	var choices: Array = []
	var final_text := ""
	var duration := 1.2
	var on_done: Callable
	var _t := 0.0
	var _done := false
	var _tick := 0.0

	func _init(p_choices: Array, p_final: String, p_done: Callable, p_duration: float = 1.2) -> void:
		choices = p_choices
		final_text = p_final
		on_done = p_done
		duration = p_duration
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_theme_font_size_override("font_size", 40)
		add_theme_color_override("font_color", Color("f5c542"))
		tree_exiting.connect(_finish)

	func _process(delta: float) -> void:
		if _done:
			return
		_t += delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.06 + _t * 0.05
			text = str(choices[randi() % choices.size()])
			Audio.play("hover", -14.0, 1.5)
		if _t >= duration:
			text = final_text
			_finish()

	func _finish() -> void:
		if _done:
			return
		_done = true
		text = final_text
		if on_done.is_valid():
			on_done.call()


## Gráfico do aviãozinho: o multiplicador sobe até o ponto de queda.
class CrashView extends Control:
	signal finished(cashed_at: float)
	var crash_at := 1.0
	var auto_cash := 0.0
	var t := 0.0
	var mult := 1.0
	var running := true
	var cashed := 0.0

	func _init(p_crash: float, p_auto: float) -> void:
		crash_at = p_crash
		auto_cash = p_auto
		custom_minimum_size = Vector2(560, 240)
		tree_exiting.connect(func():
			if running:
				_end())

	func cash_out() -> void:
		if running and cashed <= 0.0:
			cashed = mult
			Audio.play("cash")
			_end()

	func _end() -> void:
		running = false
		finished.emit(cashed)

	func _process(delta: float) -> void:
		if running:
			t += delta
			mult = CasinoLogic.crash_multiplier_at(t)
			if auto_cash > 1.0 and mult >= auto_cash and auto_cash <= crash_at:
				mult = auto_cash
				cash_out()
			elif mult >= crash_at:
				mult = crash_at
				Audio.play("lose")
				_end()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0e1526"))
		for i in 5:
			var y := size.y - 20 - i * (size.y - 40) / 4.0
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.06))
		var max_t := maxf(t, 4.0)
		var max_m := maxf(mult, 2.0)
		var pts := PackedVector2Array()
		var steps := 60
		for i in steps + 1:
			var tt := t * i / steps
			var m := CasinoLogic.crash_multiplier_at(tt)
			pts.append(Vector2(20 + tt / max_t * (size.x - 60), size.y - 20 - (m - 1.0) / (max_m - 1.0) * (size.y - 60)))
		if pts.size() > 1:
			draw_polyline(pts, Color("ff4d6d") if not running and cashed <= 0.0 else Color("f5c542"), 4.0, true)
		var tip: Vector2 = pts[pts.size() - 1]
		# aviãozinho
		var col := Color("ff4d6d")
		draw_colored_polygon(PackedVector2Array([tip + Vector2(14, 0), tip + Vector2(-10, -7), tip + Vector2(-6, 0), tip + Vector2(-10, 7)]), col)
		var font := get_theme_default_font()
		var txt := "%.2fx" % mult
		var color := Color("3ddc84") if cashed > 0.0 else (Color("ff4d6d") if not running else Color.WHITE)
		draw_string(font, Vector2(size.x / 2 - 70, size.y / 2), txt, HORIZONTAL_ALIGNMENT_CENTER, 140, 46, color)
		if not running:
			draw_string(font, Vector2(size.x / 2 - 150, size.y / 2 + 40), "SACOU!" if cashed > 0.0 else "VOOU EMBORA!", HORIZONTAL_ALIGNMENT_CENTER, 300, 22, color)


## Plinko: a bolinha desce pelos pinos seguindo o caminho sorteado.
class PlinkoView extends Control:
	signal landed(slot: int)
	var path: Array = []
	var t := 0.0
	var dropping := false
	var slot := -1

	func _init() -> void:
		custom_minimum_size = Vector2(460, 320)

	func drop(p: Array) -> void:
		path = p
		t = 0.0
		dropping = true
		slot = -1

	func _process(delta: float) -> void:
		if dropping:
			t += delta * 5.0
			if t >= path.size():
				dropping = false
				slot = path.reduce(func(a, b): return a + b, 0)
				landed.emit(slot)
			queue_redraw()

	func _peg(row: int, col: int) -> Vector2:
		var dx := size.x / 11.0
		return Vector2(size.x / 2.0 + (col - row / 2.0) * dx, 30 + row * (size.y - 80) / 8.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0e1526"))
		for row in 9:
			for col in row + 1:
				if row < 8:
					draw_circle(_peg(row, col), 3.5, Color(1, 1, 1, 0.6))
		var font := get_theme_default_font()
		var dx := size.x / 11.0
		for i in 9:
			var x := size.x / 2.0 + (i - 4) * dx
			var m: float = CasinoLogic.PLINKO_MULTS[i]
			var col := Color("ff4d6d") if m >= 5 else (Color("f5c542") if m >= 2 else (Color("3ddc84") if m >= 1 else Color("4ea8ff")))
			var r := Rect2(Vector2(x - dx * 0.45, size.y - 40), Vector2(dx * 0.9, 30))
			draw_rect(r, col.darkened(0.5 if i != slot else 0.0))
			draw_string(font, r.position + Vector2(0, 21), ("%sx" % str(m)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color.WHITE)
		if dropping or slot >= 0:
			var step := mini(int(t), path.size())
			var col_i := 0
			for k in step:
				col_i += int(path[k])
			var p := _peg(step, col_i) if step < 8 else Vector2(size.x / 2.0 + (col_i - 4) * dx, size.y - 50)
			if dropping and step < path.size():
				var nxt_col := col_i + int(path[step])
				var p2 := _peg(step + 1, nxt_col) if step + 1 < 8 else Vector2(size.x / 2.0 + (nxt_col - 4) * dx, size.y - 50)
				var f := t - floorf(t)
				p = p.lerp(p2, f) + Vector2(0, -sin(f * PI) * 10.0)
			draw_circle(p, 8, Color("ff4d6d"))
