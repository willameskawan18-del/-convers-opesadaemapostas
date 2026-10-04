class_name RaceView
extends Control
## Corrida de cavalos animada. O vencedor é sorteado antes (pre_result) e a animação
## apenas mostra a corrida chegando nesse resultado.

const COLORS := [Color("e74c3c"), Color("3498db"), Color("f1c40f"), Color("2ecc71"), Color("9b59b6"), Color("e67e22"), Color("1abc9c"), Color("ecf0f1")]

var ev: Dictionary
var finals: Array = []


func _init(p_ev: Dictionary) -> void:
	ev = p_ev
	custom_minimum_size = Vector2(560, 34 * p_ev.outcomes.size() + 20)
	var winner := int(ev.get("pre_result", ev.get("result", 0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(ev.id))
	for i in ev.outcomes.size():
		finals.append(1.0 if i == winner else rng.randf_range(0.78, 0.97))


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var sim: Simulation = Game.sim
	var p := 1.0 if ev.status == "finished" else sim.betting.live_progress(ev)
	draw_rect(Rect2(Vector2.ZERO, size), Color("1c5b2f"))
	var font := get_theme_default_font()
	var lane_h: float = (size.y - 20.0) / float(ev.outcomes.size())
	var start_x := 150.0
	var end_x := size.x - 30.0
	draw_line(Vector2(end_x, 4), Vector2(end_x, size.y - 4), Color.WHITE, 3)
	for i in ev.outcomes.size():
		var y: float = 10.0 + i * lane_h
		draw_rect(Rect2(Vector2(0, y), Vector2(size.x, lane_h - 2)), Color(0.55, 0.38, 0.2) if i % 2 == 0 else Color(0.6, 0.42, 0.23))
		draw_string(font, Vector2(8, y + lane_h * 0.65), str(ev.outcomes[i]), HORIZONTAL_ALIGNMENT_LEFT, 140, 13, Color.WHITE)
		var wob := sin(p * 30.0 + i * 1.7) * 0.012 * (1.0 - p)
		var prog := clampf(p * float(finals[i]) + wob * float(p > 0.02), 0.0, 1.0)
		var x := start_x + (end_x - start_x) * prog
		var c: Color = COLORS[i % COLORS.size()]
		var cy: float = y + lane_h * 0.5
		draw_rect(Rect2(Vector2(x - 26, cy - 6), Vector2(24, 11)), Color(0.35, 0.2, 0.1))
		draw_circle(Vector2(x - 2, cy - 5), 5, Color(0.35, 0.2, 0.1))
		draw_rect(Rect2(Vector2(x - 18, cy - 13), Vector2(9, 9)), c)
	if ev.status == "finished" and int(ev.result) >= 0:
		draw_string(font, Vector2(start_x, size.y - 2), "VENCEDOR: " + str(ev.outcomes[int(ev.result)]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f5c542"))
