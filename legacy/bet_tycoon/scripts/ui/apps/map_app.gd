extends AppBase
## Mapa 2D da cidade com a posição do jogador e locais importantes.

const PLACES := [
	["casa_jogador", "Seu apartamento"], ["banco", "Banco"], ["mercado", "Mercado"], ["lot_sala", "Sala Comercial"],
	["loja", "Eletro Center"], ["ze", "Banca do Zé"], ["lucky", "Lucky Bet"], ["deposito", "Depósito"],
	["lot_galpao", "Galpão do Porto"], ["praca", "Praça"], ["lot_salao", "Salão da Avenida"],
	["lot_terreno", "Terreno Central"], ["royal", "Royal Apostas"], ["casa_5", "Casa Azul"], ["casa_6", "Casa Verde"],
]


func title() -> String:
	return "Mapa da cidade"


func window_size() -> Vector2:
	return Vector2(860, 620)


func live() -> bool:
	return true


func build(body: VBoxContainer) -> void:
	var c := MapCanvas.new()
	c.custom_minimum_size = Vector2(780, 500)
	c.places = PLACES
	body.add_child(c)


class MapCanvas extends Control:
	var places: Array = []

	func _draw() -> void:
		var w := Game.player.get_parent() if Game.player else null
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("0e1526"))
		var sc := minf(size.x, size.y) / 220.0
		var o := size / 2.0
		var to := func(p: Vector3) -> Vector2: return o + Vector2(p.x, p.z) * sc
		var road := Color(0.25, 0.27, 0.3)
		draw_rect(Rect2(to.call(Vector3(-100, 0, -6)), Vector2(200, 12) * sc), road)
		for z in [-60.0, 60.0]:
			draw_rect(Rect2(to.call(Vector3(-100, 0, z - 5)), Vector2(200, 10) * sc), road)
		for x in [-40.0, 40.0]:
			draw_rect(Rect2(to.call(Vector3(x - 5, 0, -65)), Vector2(10, 130) * sc), road)
		if w == null:
			return
		var city: City = w.city
		var font := ThemeDB.fallback_font
		for p in places:
			var pos: Vector3 = city.point(p[0])
			var sp: Vector2 = to.call(pos)
			draw_circle(sp, 5, UiKit.GOLD)
			draw_string(font, sp + Vector2(7, 4), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.TEXT)
		var pp: Vector2 = to.call(Game.player.global_position)
		draw_circle(pp, 7, UiKit.GREEN)
		draw_string(font, pp + Vector2(8, -6), "VOCÊ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.GREEN)
