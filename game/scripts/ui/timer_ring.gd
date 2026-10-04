class_name TimerRing
extends Control
## Cronômetro circular. Fica vermelho e pulsa nos últimos 5 segundos.

var total := 20.0
var left := 20.0
var _last_sec := -1


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 6.0
	var frac := clampf(left / maxf(total, 0.01), 0.0, 1.0)
	var urgent := left <= 5.0
	var col := AW.RED if urgent else AW.GOLD
	draw_circle(c, r + 4, Color(AW.BG, 0.85))
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.12), 8, true)
	draw_arc(c, r, -PI / 2, -PI / 2 + TAU * frac, 48, col, 8, true)
	var f := AW.font("ExtraBold")
	var txt := str(ceili(left))
	var fs := 40 if not urgent else int(40 + 8 * absf(sin(Time.get_ticks_msec() * 0.01)))
	var ts := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(f, c + Vector2(-ts.x / 2.0, ts.y / 3.0), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)
	var sec := ceili(left)
	if urgent and sec != _last_sec and sec > 0 and visible:
		Audio.play("tick")
	_last_sec = sec
