class_name FishPreview
extends Control
## Desenho simples do peixe no cartão de captura (corpo, cauda, olho, brilho).

var col := Color.WHITE
var glow := false
var size_k := 0.5
var _t := 0.0


func setup(f: Dictionary) -> void:
	col = Color(str(f.get("color", "#ffffff")))
	if col.get_luminance() < 0.25:
		col = col.lightened(0.35)
	glow = bool(f.get("glow", false))
	size_k = clampf(float(f.get("size", 0.5)), 0.25, 2.2)
	custom_minimum_size = Vector2(260, 110)


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0 + Vector2(0, sin(_t * 3.0) * 3.0)
	var l := 60.0 + size_k * 30.0
	var h := l * 0.42
	if glow:
		draw_circle(c, l * 0.9, Color(col, 0.15))
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * l * 0.6, sin(a) * h * 0.5))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_colored_polygon(pts, col)
	draw_polyline(outline, Color(1, 1, 1, 0.5), 2.0, true)
	var tail := PackedVector2Array([c + Vector2(-l * 0.5, 0), c + Vector2(-l * 0.95, -h * 0.5 + sin(_t * 8.0) * 6.0), c + Vector2(-l * 0.95, h * 0.5 + sin(_t * 8.0) * 6.0)])
	draw_colored_polygon(tail, col.darkened(0.2))
	draw_circle(c + Vector2(l * 0.35, -h * 0.1), 7.0, Color.WHITE)
	draw_circle(c + Vector2(l * 0.37, -h * 0.1), 3.5, Color.BLACK)
	if glow:
		draw_circle(c + Vector2(l * 0.62, -h * 0.55), 6.0, Color(1, 1, 0.6))
