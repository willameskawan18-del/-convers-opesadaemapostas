class_name RaceReplay
extends Control
## Replay da corrida: cada jogador avança conforme o próprio tempo real (o mais rápido
## cruza a linha primeiro). Todos assistem juntos.

var times: Dictionary = {}
var duration := 5.0
var _t := 0.0
var _max_time := 1.0


func setup(t: Dictionary, d: float) -> void:
	times = t
	duration = maxf(1.0, d)
	for k in times:
		if float(times[k]) < 90.0:
			_max_time = maxf(_max_time, float(times[k]))
	custom_minimum_size = Vector2(780, 44 * maxi(1, times.size()) + 10)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var lane := 44.0
	var i := 0
	var f := AW.font("Bold")
	var race_t := _t / duration * (_max_time * 1.05)
	for k in times:
		var pid := int(k)
		var pv := Game.player_view(pid)
		var col := GameData.character_color(str(pv.get("character", "")))
		var y := 8.0 + i * lane
		draw_rect(Rect2(0, y, w, lane - 6), Color(1, 1, 1, 0.05))
		draw_string(f, Vector2(6, y + 26), str(pv.get("name", "?")), HORIZONTAL_ALIGNMENT_LEFT, 130, 16, col)
		var tt := float(times[k])
		var frac := clampf(race_t / tt, 0.0, 1.0) if tt < 90.0 else clampf(race_t / (_max_time * 1.6), 0.0, 0.7)
		var x0 := 140.0
		var x := x0 + frac * (w - x0 - 30.0)
		draw_line(Vector2(w - 24, y), Vector2(w - 24, y + lane - 6), Color.WHITE, 3.0)
		var bob := absf(sin(_t * 18.0 + i)) * 4.0 if frac < 1.0 else 0.0
		draw_circle(Vector2(x, y + 19 - bob), 14, col)
		if frac >= 1.0:
			draw_string(f, Vector2(w - 120, y + 26), "%.2fs" % tt, HORIZONTAL_ALIGNMENT_LEFT, 90, 16, AW.GOLD)
		i += 1
