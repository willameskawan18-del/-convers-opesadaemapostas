class_name Minimap
extends Control
## Minimapa no canto da tela: ruas, quarteirões, locais importantes, objetivo (dourado),
## trabalho em andamento (azul) e o jogador (seta na direção da câmera). Norte para cima.

const SIZE := 210.0
const RANGE := 70.0          # metros visíveis do centro até a borda
const PLACES := [
	["casa_jogador", "Casa", Color("74b9ff")], ["banco", "Banco", Color("74b9ff")], ["mercado", "Mercado", Color("55efc4")],
	["loja", "Loja", Color("55efc4")], ["deposito", "Depósito", Color("55efc4")], ["ze", "Zé", Color("fdcb6e")],
	["cassino", "Cassino", Color("ff3b8d")], ["lucky", "Lucky", Color("a29bfe")], ["royal", "Royal", Color("a29bfe")],
	["praca", "Praça", Color("81ecec")],
]

var _defs: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	var vs := get_viewport_rect().size
	position = Vector2(vs.x - SIZE - 16, 16)
	queue_redraw()


func _world() -> GameWorld:
	if Game.player and is_instance_valid(Game.player):
		return Game.player.get_parent() as GameWorld
	return null


func _draw() -> void:
	var w := _world()
	if w == null or Game.player == null:
		return
	var center := Vector2(SIZE, SIZE) / 2.0
	var pp: Vector3 = Game.player.global_position
	var sc := (SIZE / 2.0) / RANGE
	var to := func(p: Vector3) -> Vector2: return center + Vector2(p.x - pp.x, p.z - pp.z) * sc
	# Fundo
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.06, 0.1, 0.82)
	bg.set_corner_radius_all(14)
	bg.border_color = Color(1, 1, 1, 0.12)
	bg.set_border_width_all(2)
	draw_style_box(bg, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)))
	var clip := Rect2(Vector2(6, 6), Vector2(SIZE - 12, SIZE - 12))
	# Grama/quarteirões
	draw_rect(clip, Color(0.12, 0.2, 0.12, 0.9))
	# Ruas
	var road := Color(0.32, 0.33, 0.36)
	_rect_world(Rect2(Vector2(-110, -6), Vector2(220, 12)), to, sc, road, clip)
	for z in [-60.0, 60.0]:
		_rect_world(Rect2(Vector2(-110, z - 5), Vector2(220, 10)), to, sc, road, clip)
	for x in [-40.0, 40.0]:
		_rect_world(Rect2(Vector2(x - 5, -65), Vector2(10, 130)), to, sc, road, clip)
	# Prédios (lotes da cidade)
	var city := w.city
	if _defs.is_empty():
		_defs = city._defs()
	for d in _defs:
		var is_lot: bool = d.has("lot") and d.get("kind", "") != "house"
		_building(d, to, sc, Color(0.36, 0.34, 0.32) if is_lot else Color(0.5, 0.47, 0.42), clip)
	_building({"x": 25.5, "fz": -9.5, "dir": 1, "w": CornerCasino.W, "d": CornerCasino.D}, to, sc, Color(0.55, 0.15, 0.35), clip)
	var font := ThemeDB.fallback_font
	# Locais
	for p in PLACES:
		var wp: Vector3 = city.point(p[0])
		if wp == Vector3.ZERO:
			continue
		var sp: Vector2 = to.call(wp)
		if not clip.grow(-4).has_point(sp):
			continue
		draw_circle(sp, 4.5, p[2])
		draw_string(font, sp + Vector2(6, 4), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
	# Sua banca
	var sim := Game.sim
	if sim.has_business():
		for id in ["lot_sala", "lot_salao", "lot_galpao", "lot_terreno"]:
			var d2: Dictionary = city.lots.get(sim.business.property_id, {}).get("def", {})
			if d2.get("id", "") == id:
				_marker(to.call(city.point(id)), Color("3ddc84"), "Sua banca", clip, font)
	# Objetivo e trabalho
	var obj = w.objective_point()
	if obj != null:
		_marker(to.call(obj), Color("f5c542"), "Objetivo", clip, font)
	var stop: String = sim.jobs.current_stop()
	if stop != "":
		_marker(to.call(city.point(stop)), Color("4ea8ff"), "Trabalho", clip, font)
	# Jogador (seta na direção da câmera)
	var yaw: float = (Game.player as PlayerController).rig.yaw if Game.player is PlayerController else 0.0
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var tip := center + fwd * 9
	draw_colored_polygon(PackedVector2Array([tip, center - fwd * 6 + right * 6, center - fwd * 3, center - fwd * 6 - right * 6]), Color.WHITE)
	draw_string(font, Vector2(SIZE / 2 - 6, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))


## Marcador que fica preso na borda quando o alvo está fora do mapa.
func _marker(sp: Vector2, col: Color, text: String, clip: Rect2, font: Font) -> void:
	var inner := clip.grow(-8)
	var c := Vector2(SIZE, SIZE) / 2.0
	var p := sp
	if not inner.has_point(p):
		var d := (p - c)
		var k := minf(absf((inner.size.x / 2) / maxf(absf(d.x), 0.001)), absf((inner.size.y / 2) / maxf(absf(d.y), 0.001)))
		p = c + d * k
	draw_circle(p, 7, col)
	draw_circle(p, 3, Color(0, 0, 0, 0.6))
	draw_string(font, p + Vector2(-20, -10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _rect_world(r: Rect2, to: Callable, sc: float, col: Color, clip: Rect2) -> void:
	var a: Vector2 = to.call(Vector3(r.position.x, 0, r.position.y))
	var rr := Rect2(a, r.size * sc).intersection(clip)
	if rr.size.x > 0 and rr.size.y > 0:
		draw_rect(rr, col)


func _building(d: Dictionary, to: Callable, sc: float, col: Color, clip: Rect2) -> void:
	var dir := float(d.dir)
	var cz := float(d.fz) - dir * float(d.d) / 2.0
	_rect_world(Rect2(Vector2(float(d.x) - float(d.w) / 2, cz - float(d.d) / 2), Vector2(float(d.w), float(d.d))), to, sc, col, clip)
