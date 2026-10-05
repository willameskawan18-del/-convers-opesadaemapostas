class_name EstablishmentView
extends Node3D
## Visual do estabelecimento do jogador, reconstruído quando estágio/equipamentos mudam.
## Espaço local: fachada em +z, fundo em -z. Fornece pontos de ancoragem para NPCs.

const STYLES := {
	1: {"wall": Color(0.86, 0.8, 0.68), "floor": Color(0.55, 0.55, 0.56), "trim": Color(0.5, 0.4, 0.3), "h": 4.0, "neon": false},
	2: {"wall": Color(0.95, 0.95, 0.97), "floor": Color(0.55, 0.38, 0.24), "trim": Color(0.15, 0.4, 0.75), "h": 4.0, "neon": true},
	3: {"wall": Color(0.16, 0.2, 0.35), "floor": Color(0.7, 0.68, 0.64), "trim": Color(0.95, 0.75, 0.25), "h": 5.0, "neon": true},
	4: {"wall": Color(0.12, 0.15, 0.28), "floor": Color(0.35, 0.12, 0.15), "trim": Color(0.95, 0.78, 0.3), "h": 5.5, "neon": true},
	5: {"wall": Color(0.3, 0.32, 0.36), "floor": Color(0.25, 0.26, 0.3), "trim": Color(0.2, 0.85, 1.0), "h": 8.0, "neon": true},
	6: {"wall": Color(0.2, 0.05, 0.08), "floor": Color(0.45, 0.06, 0.1), "trim": Color(1.0, 0.82, 0.3), "h": 9.0, "neon": true},
}

var w := 8.0
var d := 8.0
var h := 4.0
var stage := 1
var counter_pos: Array = []      # posição do cliente sendo atendido em cada guichê
var staff_pos: Array = []        # posição do atendente atrás de cada guichê
var terminal_pos: Array = []
var queue_origin := Vector3.ZERO
var door_inside := Vector3.ZERO
var door_outside := Vector3.ZERO
var lounge_pos: Array = []
var role_pos: Dictionary = {}
var behind_rect := Rect2()       # área atrás dos balcões (jogador atende daqui)
var interior_rect := Rect2()
var roof: Node3D
var _night_mats: Array = []


## Constrói. `def` = definição do lote da cidade; `items` = lista de ids de equipamentos (com estado).
func build(def: Dictionary, p_stage: int, items: Array, brand: String, stage_name: String, city: City) -> void:
	stage = p_stage
	var st: Dictionary = STYLES.get(stage, STYLES[1])
	w = float(def.w)
	d = float(def.d)
	if stage == 6:
		w = 36.0
		d = 28.0
	h = float(st.h)
	var dir := float(def.dir)
	position = Vector3(float(def.x), 0, float(def.fz) - dir * float(def.d) / 2.0)
	if stage == 6:
		position = Vector3(float(def.x), 0, float(def.fz) - dir * (d / 2.0 + 3.0))
	rotation.y = 0.0 if dir > 0 else PI
	var wall_m := Mats.facade(st.wall, [0, 0, 0, 2, 2, 3, 2][stage])
	var trim_m := Mats.metal(st.trim, 0.3) if stage >= 3 else Mats.plastic(st.trim, 0.4)
	var floor_m := Mats.carpet(st.floor, st.trim) if stage >= 4 else Mats.paving(st.floor)
	# Piso
	WorldKit.solid(self, Vector3(w, 0.1, d), Vector3(0, 0.05, 0), floor_m)
	# Paredes (fundo, laterais, frente com porta)
	var t := 0.3
	WorldKit.solid(self, Vector3(w, h, t), Vector3(0, h / 2, -d / 2 + t / 2), wall_m)
	WorldKit.solid(self, Vector3(t, h, d), Vector3(-w / 2 + t / 2, h / 2, 0), wall_m)
	WorldKit.solid(self, Vector3(t, h, d), Vector3(w / 2 - t / 2, h / 2, 0), wall_m)
	var door_w := 2.4 if stage < 5 else 4.0
	var side_w := (w - door_w) / 2.0
	for sgn in [-1, 1]:
		WorldKit.solid(self, Vector3(side_w, h, t), Vector3(sgn * (door_w / 2 + side_w / 2), h / 2, d / 2 - t / 2), wall_m)
		# Vitrines
		WorldKit.box(self, Vector3(side_w * 0.7, 1.6, 0.05), Vector3(sgn * (door_w / 2 + side_w / 2), 1.6, d / 2 + 0.01), city.window_mat, false)
	WorldKit.solid(self, Vector3(door_w, h - 3.0, t), Vector3(0, 3.0 + (h - 3.0) / 2, d / 2 - t / 2), wall_m)
	# Faixa decorativa e marquise
	WorldKit.box(self, Vector3(w + 0.2, 0.3, t + 0.1), Vector3(0, h - 0.4, d / 2 - t / 2), trim_m)
	WorldKit.box(self, Vector3(door_w + 1.6, 0.15, 1.6), Vector3(0, 3.1, d / 2 + 0.8), trim_m)
	# Teto (escondido quando o jogador entra)
	roof = Node3D.new()
	add_child(roof)
	WorldKit.box(roof, Vector3(w + 0.4, 0.3, d + 0.4), Vector3(0, h + 0.15, 0), Mats.roof())
	WorldKit.box(self, Vector3(w + 0.1, 0.5, d + 0.1), Vector3(0, 0.25, 0), Mats.facade(Color(st.wall).darkened(0.45), 2))
	# Luzes internas
	var lamp_m := WorldKit.mat(Color(1, 0.95, 0.85), 0.5, 0.0, Color(1, 0.92, 0.75), 2.0)
	for lx in _spread(maxi(1, int(w / 7.0)), w * 0.7):
		WorldKit.box(self, Vector3(1.4, 0.06, 0.4), Vector3(lx, h - 0.05, 0), lamp_m, false)
	# Grade de luzes internas (ambientes grandes têm várias)
	var nx := maxi(1, int(round(w / 11.0)))
	var nz := maxi(1, int(round(d / 11.0)))
	for ix in nx:
		for iz in nz:
			var light := OmniLight3D.new()
			light.position = Vector3(-w / 2 + w * (ix + 0.5) / nx, h - 0.6, -d / 2 + d * (iz + 0.5) / nz)
			light.omni_range = maxf(w / nx, d / nz) * 1.1 + 2.0
			light.light_energy = 1.5 if stage < 5 else 1.9
			light.light_color = Color(1, 0.93, 0.8) if stage < 6 else Color(1, 0.85, 0.65)
			add_child(light)
	if stage >= 3:
		_interior_decor(st, city)
	# Letreiro
	_sign(brand.to_upper() if stage < 6 else "GRANDE CASSINO " + brand.to_upper(), stage_name.to_upper(), st, city)
	if stage <= 2:
		_facade_screens(st, city)
	_layout_anchors()
	_build_counters(items, trim_m)
	_build_items(items, city)
	if stage >= 4:
		_columns(trim_m)
	if stage == 6:
		_casino_facade(trim_m)


## Banca de esquina: TVs na fachada (futebol e corrida de cavalos) e lâmpadas no letreiro.
func _facade_screens(st: Dictionary, city: City) -> void:
	var y := 2.5
	var fz := d / 2 + 0.06
	var field := Mats.glow(Color(0.15, 0.6, 0.2), 1.1)
	var track := Mats.glow(Color(0.6, 0.4, 0.2), 1.0)
	for sgn in [-1.0, 1.0]:
		var x: float = sgn * (w / 2 - 1.1)
		WorldKit.box(self, Vector3(1.4, 0.9, 0.08), Vector3(x, y, fz), Mats.plastic(Color(0.05, 0.05, 0.06), 0.3), false)
		WorldKit.box(self, Vector3(1.25, 0.75, 0.03), Vector3(x, y, fz + 0.05), field if sgn < 0 else track, false)
		WorldKit.box(self, Vector3(0.03, 0.75, 0.01), Vector3(x, y, fz + 0.07), Mats.glow(Color(1, 1, 1), 1.2), false)
		WorldKit.label(self, "AO VIVO" if sgn < 0 else "TURFE", Vector3(x, y + 0.6, fz + 0.06), 24, Color(1, 1, 1), 4)
	# lâmpadas em volta do letreiro
	var sy := h + 0.9
	var bulbs := Mats.glow(Color(1.0, 0.85, 0.45), 4.0)
	for i in 14:
		var bx := -w / 2 + 0.6 + i * (w - 1.2) / 13.0
		WorldKit.sphere(self, 0.07, Vector3(bx, sy + 0.62, d / 2 + 0.2), bulbs)
		WorldKit.sphere(self, 0.07, Vector3(bx, sy - 0.62, d / 2 + 0.2), bulbs)


func _interior_decor(st: Dictionary, city: City) -> void:
	var neon := Mats.glow(Color(st.trim), 2.5)
	# Faixas de neon nas paredes
	WorldKit.box(self, Vector3(w - 0.8, 0.08, 0.06), Vector3(0, h - 0.5, -d / 2 + 0.33), neon, false)
	for sgn in [-1.0, 1.0]:
		WorldKit.box(self, Vector3(0.06, 0.08, d - 0.8), Vector3(sgn * (w / 2 - 0.33), h - 0.5, 0), neon, false)
		WorldKit.box(self, Vector3(0.06, 0.08, d - 0.8), Vector3(sgn * (w / 2 - 0.33), 0.3, 0), neon, false)
	# Quadros de odds/jogos nas paredes laterais
	for sgn in [-1.0, 1.0]:
		for k in maxi(1, int(d / 8.0)):
			var z := -d / 2 + 4.0 + k * 8.0
			if z > d / 2 - 3.0:
				break
			var scr := WorldKit.box(self, Vector3(0.08, 1.6, 2.8), Vector3(sgn * (w / 2 - 0.36), h * 0.55, z), Mats.glow(Color(0.15, 0.45, 0.9) if k % 2 == 0 else Color(0.1, 0.6, 0.3), 0.8), false)
			scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if stage >= 4:
		# Bar
		var bx := w / 2 - 3.0
		var bz := d / 2 - 4.0
		WorldKit.solid(self, Vector3(3.6, 1.1, 0.8), Vector3(bx, 0.55, bz), Mats.plastic(Color(0.1, 0.07, 0.06), 0.3))
		WorldKit.box(self, Vector3(3.8, 0.08, 1.0), Vector3(bx, 1.12, bz), Mats.metal(Color(st.trim), 0.25), false)
		WorldKit.box(self, Vector3(3.4, 1.4, 0.3), Vector3(bx, 2.2, bz + 1.3), Mats.plastic(Color(0.08, 0.06, 0.05), 0.4), false)
		for i in 6:
			WorldKit.cylinder(self, 0.06, 0.3, Vector3(bx - 1.4 + i * 0.55, 2.4, bz + 1.2), Mats.glow(Color(0.9, 0.6, 0.2).lerp(Color(0.3, 0.8, 1.0), i / 6.0), 1.2), 6)
		var lb := WorldKit.label(self, "BAR", Vector3(bx, 3.2, bz + 1.1), 64, Color(st.trim), 8)
		lb.rotation.y = PI
	if stage >= 6:
		# Lustres
		for ix in 3:
			for iz in 2:
				var c := Vector3(-w / 3 + ix * w / 3, h - 1.4, -d / 4 + iz * d / 2)
				WorldKit.cylinder(self, 0.03, 1.0, c + Vector3(0, 0.6, 0), Mats.metal(Color(0.9, 0.75, 0.3), 0.2), 6)
				WorldKit.sphere(self, 0.55, c, Mats.glow(Color(1.0, 0.88, 0.6), 2.5))
				for k in 8:
					var a := TAU * k / 8.0
					WorldKit.sphere(self, 0.12, c + Vector3(cos(a) * 0.9, -0.2, sin(a) * 0.9), Mats.glow(Color(1.0, 0.9, 0.7), 3.0))
		# Palco central com letreiro
		WorldKit.cylinder(self, 2.4, 0.3, Vector3(-w / 4.0, 0.15, 2.0), Mats.metal(Color(st.trim), 0.3), 32)
		var sl := WorldKit.label(self, "GRANDE CASSINO", Vector3(-w / 4.0, 3.2, 2.0), 110, Color(st.trim).lightened(0.2), 10, true)
		sl.no_depth_test = false


func _spread(n: int, width: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(-width / 2.0 + width * (i + 0.5) / n)
	return out


func _sign(text: String, sub: String, st: Dictionary, city: City) -> void:
	var size := 64 if stage < 3 else (90 if stage < 6 else 150)
	var y := h + 0.9 if stage < 6 else h + 2.2
	var board_w := text.length() * size * 0.0058 + 1.0
	WorldKit.box(self, Vector3(board_w, size * 0.016, 0.15), Vector3(0, y, d / 2 + 0.05), WorldKit.mat(Color(0.06, 0.06, 0.08)), false)
	var l := WorldKit.label(self, text, Vector3(0, y + 0.1, d / 2 + 0.15), size, st.trim if st.neon else Color.WHITE, 10)
	if st.neon:
		l.modulate = Color(st.trim).lightened(0.2)
	WorldKit.label(self, sub, Vector3(0, y - size * 0.0055, d / 2 + 0.15), int(size * 0.4), Color(1, 1, 1, 0.9), 6)
	if st.neon:
		WorldKit.box(self, Vector3(board_w + 0.2, 0.06, 0.06), Vector3(0, y - size * 0.008 - 0.05, d / 2 + 0.14), city.neon_mat, false)
		WorldKit.box(self, Vector3(board_w + 0.2, 0.06, 0.06), Vector3(0, y + size * 0.008 + 0.05, d / 2 + 0.14), city.neon_mat, false)


func _layout_anchors() -> void:
	var back := -d / 2.0
	var n := _counter_count()
	var spacing := clampf((w - 2.0) / maxf(n, 1), 1.8, 2.6)
	counter_pos.clear()
	staff_pos.clear()
	var xs := []
	for i in n:
		xs.append((i - (n - 1) / 2.0) * spacing)
	for x in xs:
		counter_pos.append(Vector3(x, 0.1, back + 2.6))
		staff_pos.append(Vector3(x, 0.1, back + 0.9))
	behind_rect = Rect2(Vector2(-w / 2 + 0.3, back + 0.2), Vector2(w - 0.6, 1.4))
	interior_rect = Rect2(Vector2(-w / 2, -d / 2), Vector2(w, d))
	queue_origin = Vector3(0, 0.1, back + 3.8)
	door_inside = Vector3(0, 0.1, d / 2 - 1.0)
	door_outside = Vector3(0, 0.1, d / 2 + 2.0)
	lounge_pos.clear()
	for i in 6:
		lounge_pos.append(Vector3(-w / 2 + 0.9, 0.1, back + 3.5 + i * 0.9))
	role_pos = {
		"seguranca": Vector3(door_w_half() + 0.8, 0.1, d / 2 - 1.2),
		"caixa": Vector3(-w / 2 + 0.9, 0.1, back + 0.9),
		"analista": Vector3(w / 2 - 1.0, 0.1, back + 0.9),
		"gerente": Vector3(w / 2 - 1.5, 0.1, back + 3.0),
		"especialista": Vector3(w / 2 - 1.2, 0.1, 0.0),
		"rest": Vector3(w / 2 - 0.8, 0.1, back + 1.5),
	}


func door_w_half() -> float:
	return 1.2 if stage < 5 else 2.0


func _counter_count() -> int:
	return maxi(1, _stage_counters())


func _stage_counters() -> int:
	for s in GameData.list("stages", "stages"):
		if int(s.stage) == stage:
			return int(s.counters)
	return 1


## Fila: serpenteia na metade da frente da sala.
func queue_point(k: int) -> Vector3:
	var per_row := maxi(3, int((d / 2.0 + 0.5) / 0.9))
	var row := k / per_row
	var col := k % per_row
	var x := 0.6 + row * 0.9
	if row % 2 == 1:
		col = per_row - 1 - col
	var p := queue_origin + Vector3(x, 0, col * 0.9)
	p.x = minf(p.x, w / 2 - 0.6)
	return p


func _build_counters(items: Array, trim_m: Material) -> void:
	var counters_owned: Array = items.filter(func(e): return _cat(e) == "counter")
	var computers: Array = items.filter(func(e): return _cat(e) == "computer")
	var wood := WorldKit.mat(Color(0.4, 0.27, 0.17)) if stage < 3 else WorldKit.mat(Color(0.12, 0.12, 0.15), 0.3, 0.4)
	for i in staff_pos.size():
		var pos: Vector3 = (staff_pos[i] + counter_pos[i]) / 2.0
		if i < counters_owned.size():
			WorldKit.solid(self, Vector3(1.8, 1.05, 0.7), pos + Vector3(0, 0.52, 0), wood)
			WorldKit.box(self, Vector3(1.9, 0.06, 0.8), pos + Vector3(0, 1.08, 0), trim_m)
			if i < computers.size():
				var broken: bool = computers[i].broken
				var scr := WorldKit.mat(Color(0.05, 0.05, 0.08), 0.3, 0.0, Color(1, 0.2, 0.2) if broken else Color(0.3, 0.7, 1.0), 1.2)
				WorldKit.box(self, Vector3(0.6, 0.4, 0.05), pos + Vector3(0, 1.4, -0.1), scr, false)
				WorldKit.box(self, Vector3(0.08, 0.2, 0.08), pos + Vector3(0, 1.18, -0.1), WorldKit.mat(Color(0.2, 0.2, 0.2)), false)
		else:
			# Guichê vazio (pode comprar mais balcões)
			WorldKit.box(self, Vector3(1.8, 0.02, 0.7), pos + Vector3(0, 0.11, 0), WorldKit.mat(Color(1, 1, 1, 0.15)), false)


func _cat(e: Dictionary) -> String:
	return str(GameData.find("equipment", "items", str(e.id)).get("category", ""))


func _build_items(items: Array, city: City) -> void:
	var back := -d / 2.0
	var chairs := 0
	var tvs := 0
	var cams := 0
	var casino := 0
	var terminals := 0
	var registers := 0
	for e in items:
		var cat := _cat(e)
		match cat:
			"chair":
				if chairs < lounge_pos.size():
					var cp: Vector3 = lounge_pos[chairs]
					var col := Color(0.2, 0.3, 0.6) if str(e.id) == "cadeiras" else Color(0.55, 0.12, 0.15)
					WorldKit.box(self, Vector3(0.6, 0.5, 0.6), cp + Vector3(-0.1, 0.25, 0), WorldKit.mat(col), true)
					WorldKit.box(self, Vector3(0.12, 0.6, 0.6), cp + Vector3(-0.4, 0.6, 0), WorldKit.mat(col.darkened(0.2)), true)
				chairs += 1
			"tv":
				var tv_w := 1.6 if str(e.id) == "tv" else 3.6
				var x := -w / 2.0 + 2.0 + tvs * (tv_w + 0.8)
				var scr := WorldKit.mat(Color(0.05, 0.08, 0.12), 0.2, 0.0, Color(0.2, 0.75, 0.35) if tvs % 2 == 0 else Color(0.3, 0.5, 1.0), 0.9)
				WorldKit.box(self, Vector3(tv_w, tv_w * 0.56, 0.08), Vector3(minf(x, w / 2 - tv_w), h * 0.62, back + 0.2), scr, false)
				tvs += 1
			"camera":
				var corners := [Vector3(-w / 2 + 0.4, h - 0.4, back + 0.4), Vector3(w / 2 - 0.4, h - 0.4, back + 0.4), Vector3(-w / 2 + 0.4, h - 0.4, d / 2 - 0.5), Vector3(w / 2 - 0.4, h - 0.4, d / 2 - 0.5)]
				var cpos: Vector3 = corners[cams % 4]
				WorldKit.box(self, Vector3(0.25, 0.18, 0.35), cpos, WorldKit.mat(Color(0.9, 0.9, 0.9)), false)
				WorldKit.sphere(self, 0.05, cpos + Vector3(0, -0.02, 0.18), WorldKit.mat(Color(1, 0, 0), 0.5, 0.0, Color(1, 0, 0), 2.0))
				cams += 1
			"cashier":
				var rp: Vector3 = staff_pos[0] + Vector3(-1.3, 0, 0.8)
				if registers == 0:
					WorldKit.solid(self, Vector3(0.9, 1.0, 0.6), rp + Vector3(0, 0.5, 0), WorldKit.mat(Color(0.25, 0.25, 0.3)))
					WorldKit.box(self, Vector3(0.45, 0.25, 0.35), rp + Vector3(0, 1.12, 0), WorldKit.mat(Color(0.1, 0.1, 0.12), 0.4, 0.0, Color(0.3, 1, 0.4), 0.6), false)
				registers += 1
			"printer":
				WorldKit.box(self, Vector3(0.35, 0.2, 0.3), staff_pos[0] + Vector3(0.6, 1.2, 0.8), WorldKit.mat(Color(0.85, 0.85, 0.85)), false)
			"security":
				WorldKit.box(self, Vector3(0.5, 0.7, 0.1), Vector3(door_w_half() + 0.6, 1.6, d / 2 - 0.35), WorldKit.mat(Color(0.2, 0.2, 0.25), 0.4, 0.0, Color(0.2, 1, 0.4), 0.8), false)
			"terminal":
				var tp := Vector3(-w / 2 + 1.0 + terminals * 1.4, 0.1, 0.5)
				terminal_pos.append(tp + Vector3(0, 0, 0.9))
				WorldKit.solid(self, Vector3(0.7, 1.6, 0.5), tp + Vector3(0, 0.8, 0), WorldKit.mat(Color(0.15, 0.15, 0.2), 0.3, 0.4))
				WorldKit.box(self, Vector3(0.55, 0.7, 0.05), tp + Vector3(0, 1.2, 0.26), WorldKit.mat(Color(0.05, 0.05, 0.1), 0.2, 0.0, Color(0.95, 0.75, 0.25), 1.0), false)
				terminals += 1
			"server":
				pass
			"management":
				WorldKit.box(self, Vector3(1.0, 0.75, 0.6), role_pos.analista + Vector3(0, 0.4, 0.5), WorldKit.mat(Color(0.3, 0.3, 0.35)), false)
			"vip":
				var vc := Vector3(w / 2 - 3.5, 0.11, 1.0)
				WorldKit.box(self, Vector3(5.0, 0.02, 5.0), vc, WorldKit.mat(Color(0.5, 0.05, 0.1)), false)
				WorldKit.label(self, "ÁREA VIP", vc + Vector3(0, 2.6, -2.4), 60, Color(1, 0.85, 0.3), 8)
				for k in 3:
					WorldKit.box(self, Vector3(1.6, 0.5, 0.7), vc + Vector3(-1.6 + k * 1.6, 0.25, 1.6), WorldKit.mat(Color(0.15, 0.1, 0.1)), true)
			"casino":
				_casino_item(str(GameData.find("equipment", "items", str(e.id)).get("visual", "slot")), casino, city)
				casino += 1


## Máquinas e mesas em grade na metade direita/frontal.
func _casino_item(cat: String, idx: int, city: City) -> void:
	var cols := maxi(2, int((w * 0.55) / 3.4))
	var col := idx % cols
	var row := idx / cols
	var p := Vector3(-w / 2 + w * 0.4 + col * 3.4, 0.1, -d / 2 + 5.5 + row * 3.2)
	if p.z > d / 2 - 3.0:
		return
	match cat:
		"slot":
			for k in 3:
				var q := p + Vector3(-0.9 + k * 0.9, 0, 0)
				WorldKit.solid(self, Vector3(0.8, 1.9, 0.7), q + Vector3(0, 0.95, 0), Mats.car_paint(Color(0.55, 0.08, 0.14)))
				WorldKit.box(self, Vector3(0.62, 0.55, 0.05), q + Vector3(0, 1.35, 0.36), Mats.glow(Color(1.0, 0.75, 0.25), 1.2), false)
				WorldKit.box(self, Vector3(0.82, 0.14, 0.72), q + Vector3(0, 1.97, 0), Mats.glow(Color(1.0, 0.3, 0.5), 2.5), false)
				WorldKit.box(self, Vector3(0.5, 0.06, 0.25), q + Vector3(0, 0.95, 0.45), Mats.metal(Color(0.8, 0.8, 0.82), 0.2), false)
		"table":
			WorldKit.solid(self, Vector3(2.0, 0.85, 1.2), p + Vector3(0, 0.42, 0), Mats.plastic(Color(0.25, 0.14, 0.08), 0.4))
			WorldKit.box(self, Vector3(1.8, 0.03, 1.0), p + Vector3(0, 0.87, 0), Mats.cloth(Color(0.05, 0.42, 0.22)), false)
			for k in 4:
				WorldKit.cylinder(self, 0.22, 0.55, p + Vector3(-0.75 + k * 0.5, 0.28, 0.95), Mats.plastic(Color(0.5, 0.08, 0.1), 0.5), 10)
		"terminal":
			WorldKit.solid(self, Vector3(0.7, 1.4, 0.5), p + Vector3(0, 0.7, 0), WorldKit.mat(Color(0.12, 0.12, 0.16), 0.3, 0.4))
			WorldKit.box(self, Vector3(0.55, 0.45, 0.05), p + Vector3(0, 1.1, 0.26), WorldKit.mat(Color(0.05, 0.05, 0.1), 0.2, 0.0, Color(0.3, 0.9, 1.0), 1.2), false)
		"screen":
			WorldKit.solid(self, Vector3(1.8, 0.9, 0.4), p + Vector3(0, 0.45, 0), WorldKit.mat(Color(0.15, 0.15, 0.2)))
			WorldKit.box(self, Vector3(1.8, 1.1, 0.08), p + Vector3(0, 1.6, -0.1), WorldKit.mat(Color(0.05, 0.05, 0.1), 0.2, 0.0, Color(1.0, 0.35, 0.3), 1.4), false)
		"wheel":
			WorldKit.solid(self, Vector3(1.6, 0.85, 1.2), p + Vector3(0, 0.42, 0), WorldKit.mat(Color(0.3, 0.18, 0.1)))
			var wh := WorldKit.cylinder(self, 0.55, 0.12, p + Vector3(0, 0.95, 0), WorldKit.mat(Color(0.6, 0.1, 0.1), 0.3, 0.3), 24)
			wh.rotation.x = 0.0
			WorldKit.cylinder(self, 0.12, 0.2, p + Vector3(0, 1.05, 0), WorldKit.mat(Color(0.9, 0.75, 0.3), 0.3, 0.8))
		"jackpot":
			WorldKit.solid(self, Vector3(1.2, 2.6, 1.0), p + Vector3(0, 1.3, 0), WorldKit.mat(Color(0.8, 0.65, 0.15), 0.3, 0.8))
			WorldKit.label(self, "JACKPOT", p + Vector3(0, 2.9, 0.5), 48, Color(1, 0.9, 0.3), 8)


func _columns(trim_m: Material) -> void:
	for x in [-w / 4.0, w / 4.0]:
		for z in [-d / 6.0, d / 6.0]:
			WorldKit.solid(self, Vector3(0.5, h, 0.5), Vector3(x, h / 2, z), trim_m)


func _casino_facade(trim_m: Material) -> void:
	# Pórtico dourado e escadaria
	for x in [-6.0, -2.5, 2.5, 6.0]:
		WorldKit.solid(self, Vector3(0.9, h + 1.5, 0.9), Vector3(x, (h + 1.5) / 2, d / 2 + 2.2), trim_m)
	WorldKit.box(self, Vector3(14.0, 0.5, 4.0), Vector3(0, h + 1.5, d / 2 + 2.0), trim_m)
	WorldKit.box(self, Vector3(14.0, 0.15, 5.0), Vector3(0, 0.075, d / 2 + 2.5), WorldKit.mat(Color(0.5, 0.05, 0.08)), false)
	for i in 6:
		WorldKit.sphere(self, 0.35, Vector3(-w / 2 + 4 + i * (w - 8) / 5.0, h - 0.8, 0), WorldKit.mat(Color(1, 0.9, 0.6), 0.2, 0.0, Color(1, 0.85, 0.5), 3.0))


## Converte posição global para local (para checar se o jogador está atrás do balcão).
func local_xz(global_pos: Vector3) -> Vector2:
	var l := to_local(global_pos)
	return Vector2(l.x, l.z)


func is_behind_counter(global_pos: Vector3) -> bool:
	return behind_rect.has_point(local_xz(global_pos))


func is_inside(global_pos: Vector3) -> bool:
	return interior_rect.grow(-0.2).has_point(local_xz(global_pos))
