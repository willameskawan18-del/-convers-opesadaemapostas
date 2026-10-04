class_name City
extends Node3D
## Cidade explorável: 3 colunas de quarteirões, avenida central, ruas transversais,
## calçadas, comércios, banco, praça, casas, concorrentes e lotes para o negócio do jogador.
## Pontos nomeados (portas, pontos de trabalho) ficam em `points` para outros sistemas.

const AVENUE_W := 12.0
const CROSS_X := [-40.0, 40.0]
const BACK_Z := [-60.0, 60.0]
const HALF := 100.0

var points: Dictionary = {}       # nome -> Vector3
var lots: Dictionary = {}         # id do imóvel -> {node, def}
var day_night: DayNight
var window_mat: Material          # vitrines (acendem à noite)
var neon_mat: StandardMaterial3D
var lamp_mat: StandardMaterial3D
var sidewalk_nodes: Array = []    # Vector3
var sidewalk_edges: Dictionary = {}  # índice -> [índices vizinhos]
var door_points: Array = []       # portas visitáveis por pedestres
var comp_signs: Dictionary = {}   # id do concorrente -> Label3D do letreiro
var traffic: Traffic

var c_dark := Mats.plastic(Color(0.1, 0.1, 0.11), 0.5)
var c_line := Mats.plastic(Color(0.92, 0.9, 0.82), 0.7)
var c_yellow := Mats.plastic(Color(0.95, 0.75, 0.15), 0.7)
var c_curb := Mats.facade(Color(0.55, 0.55, 0.55), 2)
var c_frame := Mats.metal(Color(0.2, 0.21, 0.23), 0.45)
var c_pole := Mats.metal(Color(0.16, 0.17, 0.19), 0.5)
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 4242
	day_night = DayNight.new()
	add_child(day_night)
	window_mat = Mats.storefront()
	neon_mat = StandardMaterial3D.new()
	neon_mat.albedo_color = Color(1.0, 0.8, 0.25)
	neon_mat.emission_enabled = true
	neon_mat.emission = Color(1.0, 0.75, 0.2)
	day_night.register_night_material(neon_mat, 4.0)
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.95, 0.95, 0.85)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.85, 0.6)
	day_night.register_night_material(lamp_mat, 6.0)
	_build_ground()
	_build_roads()
	_build_buildings()
	_build_plaza(Vector3(-18, 0, 18.5))
	_build_street_props()
	_build_bounds()
	_build_sidewalk_graph()
	traffic = Traffic.new()
	add_child(traffic)


# --- Terreno e ruas ----------------------------------------------------------

func _build_ground() -> void:
	WorldKit.solid(self, Vector3(HALF * 2.4, 1.0, HALF * 2.4), Vector3(0, -0.5, 0), Mats.grass())


func _build_roads() -> void:
	var asphalt := Mats.asphalt()
	var road_h := 0.02
	WorldKit.box(self, Vector3(HALF * 2.2, road_h, AVENUE_W), Vector3(0, road_h / 2, 0), asphalt, false)
	# Faixa dupla amarela no centro e tracejado das bordas
	for zz in [-0.12, 0.12]:
		WorldKit.box(self, Vector3(HALF * 2.2, 0.025, 0.1), Vector3(0, 0.03, zz), c_yellow, false)
	for x in range(-104, 105, 6):
		if absf(x - CROSS_X[0]) < 7 or absf(x - CROSS_X[1]) < 7:
			continue
		for zz in [-5.2, 5.2]:
			WorldKit.box(self, Vector3(2.5, 0.025, 0.12), Vector3(x, 0.03, zz), c_line, false)
	for z in BACK_Z:
		WorldKit.box(self, Vector3(HALF * 2.2, road_h, 10.0), Vector3(0, road_h / 2, z), asphalt, false)
		for x in range(-100, 101, 8):
			WorldKit.box(self, Vector3(3.0, 0.025, 0.12), Vector3(x, 0.03, z), c_line, false)
	for x in CROSS_X:
		WorldKit.box(self, Vector3(10.0, road_h + 0.006, BACK_Z[1] * 2 + 10.0), Vector3(x, road_h / 2 + 0.003, 0), asphalt, false)
		for z in [-9.5, 9.5, -51.5, 51.5]:
			_crosswalk(Vector3(x, 0.035, z), true)
		for z in [-7.8, 7.8]:
			_crosswalk(Vector3(x + (6.6 if z < 0 else -6.6), 0.035, 0), false)
	# Calçadas com meio-fio
	for z in [-7.5, 7.5, -53.5, 53.5]:
		_sidewalk_strip(Vector3(0, 0, z), Vector3(HALF * 2.2, 0.15, 3.0), true)
	for x in CROSS_X:
		for side in [-6.5, 6.5]:
			_sidewalk_strip(Vector3(x + side, 0, 0), Vector3(3.0, 0.15, BACK_Z[1] * 2 - 10.0), false)


func _crosswalk(center: Vector3, along_x: bool) -> void:
	for i in range(-3, 4):
		var off := Vector3(i * 1.2, 0, 0) if along_x else Vector3(0, 0, i * 1.2)
		WorldKit.box(self, Vector3(0.6, 0.02, 3.2) if along_x else Vector3(3.2, 0.02, 0.6), center + off, c_line, false)


func _sidewalk_strip(center: Vector3, size: Vector3, along_x: bool) -> void:
	WorldKit.solid(self, size, center + Vector3(0, size.y / 2, 0), Mats.sidewalk())
	# meio-fio levemente mais alto e escuro nas duas bordas
	for sgn in [-1.0, 1.0]:
		var off := Vector3(0, 0, sgn * (size.z / 2 - 0.1)) if along_x else Vector3(sgn * (size.x / 2 - 0.1), 0, 0)
		var cs := Vector3(size.x, 0.18, 0.2) if along_x else Vector3(0.2, 0.18, size.z)
		WorldKit.box(self, cs, center + off + Vector3(0, 0.09, 0), c_curb, false)


func _build_bounds() -> void:
	WorldKit.solid(self, Vector3(HALF * 2.2, 8, 1), Vector3(0, 4, HALF + 8), null)
	WorldKit.solid(self, Vector3(HALF * 2.2, 8, 1), Vector3(0, 4, -HALF - 8), null)
	WorldKit.solid(self, Vector3(1, 8, HALF * 2.2), Vector3(HALF + 8, 4, 0), null)
	WorldKit.solid(self, Vector3(1, 8, HALF * 2.2), Vector3(-HALF - 8, 4, 0), null)
	# Cinturão verde e prédios distantes (silhueta da cidade ao fundo)
	var leaves := Mats.leaves(Color(0.2, 0.38, 0.17))
	for x in range(-108, 109, 7):
		for z in [-HALF - 7.0, HALF + 7.0]:
			WorldKit.sphere(self, rng.randf_range(2.0, 3.2), Vector3(x + rng.randf_range(-1.5, 1.5), 1.2, z + rng.randf_range(-1, 1)), leaves)
	for z in range(-108, 109, 7):
		for x in [-HALF - 7.0, HALF + 7.0]:
			WorldKit.sphere(self, rng.randf_range(2.0, 3.2), Vector3(x + rng.randf_range(-1, 1), 1.2, z + rng.randf_range(-1.5, 1.5)), leaves)
	# Morros verdes ao fundo (silhueta suave em vez de prédios soltos)
	var hill := Mats.leaves(Color(0.24, 0.4, 0.2))
	for i in 34:
		var ang := TAU * i / 34.0 + rng.randf_range(-0.04, 0.04)
		var r := rng.randf_range(150.0, 175.0)
		var rad := rng.randf_range(16.0, 28.0)
		var m := WorldKit.sphere(self, rad, Vector3(cos(ang) * r, -rad * 0.55, sin(ang) * r), hill)
		m.scale = Vector3(1.6, 1.0, 1.6)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Prédios -----------------------------------------------------------------

## Definição dos prédios. dir = +1: fachada voltada para +z (corpo em z menor).
## facade: 0 reboco, 1 tijolo, 2 concreto, 3 metal.
func _defs() -> Array:
	return [
		# Avenida, lado norte (fachada em z = -9.5)
		{"id": "casa_jogador", "name": "EDIFÍCIO AURORA", "x": -80, "fz": -9.5, "dir": 1, "w": 10, "d": 10, "h": 15, "color": Color(0.72, 0.42, 0.32), "facade": 1, "awning": Color(0.25, 0.3, 0.38), "residential": true},
		{"id": "banco", "name": "BANCO CENTRAL", "x": -60, "fz": -9.5, "dir": 1, "w": 14, "d": 12, "h": 12, "color": Color(0.78, 0.78, 0.76), "facade": 2, "columns": true, "sign_color": Color(0.85, 0.9, 1.0)},
		{"id": "mercado", "name": "MERCADO BOM PREÇO", "x": -22, "fz": -9.5, "dir": 1, "w": 16, "d": 12, "h": 6.5, "color": Color(0.93, 0.92, 0.86), "facade": 0, "awning": Color(0.18, 0.6, 0.25), "awning2": Color(0.95, 0.95, 0.9), "sign_color": Color(0.4, 1.0, 0.5)},
		{"id": "lot_sala", "lot": "sala_comercio", "x": -6, "fz": -9.5, "dir": 1, "w": 8, "d": 8, "h": 5, "color": Color(0.75, 0.7, 0.62)},
		{"id": "loja", "name": "ELETRO CENTER", "x": 10, "fz": -9.5, "dir": 1, "w": 12, "d": 10, "h": 7, "color": Color(0.82, 0.86, 0.92), "facade": 2, "awning": Color(0.12, 0.3, 0.8), "awning2": Color(0.9, 0.92, 0.95), "sign_color": Color(0.5, 0.8, 1.0)},
		{"id": "ze", "kind": "kiosk", "name": "BANCA DO ZÉ", "x": 56, "fz": -9.5, "dir": 1, "w": 8, "d": 6, "h": 3.6, "color": Color(0.9, 0.55, 0.2), "awning": Color(0.8, 0.2, 0.15), "awning2": Color(0.98, 0.9, 0.7)},
		{"id": "lucky", "name": "LUCKY BET", "x": 78, "fz": -9.5, "dir": 1, "w": 16, "d": 12, "h": 8, "color": Color(0.12, 0.42, 0.26), "facade": 2, "awning": Color(0.95, 0.8, 0.2), "awning2": Color(0.1, 0.35, 0.2), "neon": true, "sign_color": Color(0.3, 1.0, 0.5)},
		# Avenida, lado sul (fachada em z = 9.5)
		{"id": "deposito", "name": "DEPÓSITO LOGÍSTICO", "x": -82, "fz": 9.5, "dir": -1, "w": 14, "d": 14, "h": 8, "color": Color(0.5, 0.55, 0.6), "facade": 3, "garage": true, "sign_color": Color(1.0, 0.75, 0.3)},
		{"id": "lot_galpao", "lot": "galpao_porto", "x": -60, "fz": 9.5, "dir": -1, "w": 22, "d": 26, "h": 9, "color": Color(0.55, 0.57, 0.6)},
		{"id": "lot_salao", "lot": "salao_avenida", "x": 12, "fz": 9.5, "dir": -1, "w": 20, "d": 14, "h": 7, "color": Color(0.8, 0.75, 0.7)},
		{"id": "lot_terreno", "lot": "terreno_central", "x": 72, "fz": 9.5, "dir": -1, "w": 44, "d": 38, "h": 0, "color": Color(0.5, 0.45, 0.35)},
		# Rua de trás norte (fachada em z = -51.5, voltada para -z)
		{"id": "casa_1", "kind": "house", "x": -85, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.95, 0.88, 0.7)},
		{"id": "casa_2", "kind": "house", "x": -65, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.75, 0.84, 0.92)},
		{"id": "casa_3", "kind": "house", "x": -15, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.95, 0.76, 0.7)},
		{"id": "casa_4", "kind": "house", "x": 5, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.82, 0.92, 0.76)},
		{"id": "royal", "name": "ROYAL APOSTAS", "x": 75, "fz": -51.5, "dir": -1, "w": 18, "d": 14, "h": 10, "color": Color(0.3, 0.12, 0.35), "facade": 2, "awning": Color(0.9, 0.75, 0.3), "awning2": Color(0.35, 0.1, 0.4), "neon": true, "columns": true, "sign_color": Color(1.0, 0.82, 0.35)},
		# Rua de trás sul (fachada em z = 51.5, voltada para +z)
		{"id": "casa_5", "kind": "house", "lot": "casa_azul", "x": -25, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.5, 0.65, 0.88)},
		{"id": "casa_6", "kind": "house", "lot": "casa_verde", "x": -5, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.55, 0.78, 0.55)},
		{"id": "casa_7", "kind": "house", "x": 15, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.95, 0.94, 0.86)},
		{"id": "casa_8", "kind": "house", "x": -85, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.9, 0.74, 0.58)},
		# Mais casas (bairro denso)
		{"id": "casa_9", "kind": "house", "x": -75, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.96, 0.82, 0.55)},
		{"id": "casa_10", "kind": "house", "x": -55, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.85, 0.6, 0.5)},
		{"id": "casa_11", "kind": "house", "x": -27, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.7, 0.85, 0.8)},
		{"id": "casa_12", "kind": "house", "x": 18, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.98, 0.9, 0.62)},
		{"id": "casa_13", "kind": "house", "x": 27, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.82, 0.74, 0.9)},
		{"id": "casa_14", "kind": "house", "x": -65, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.94, 0.7, 0.5)},
		{"id": "casa_15", "kind": "house", "x": -15, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.75, 0.88, 0.95)},
		{"id": "casa_16", "kind": "house", "x": 25, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.95, 0.85, 0.75)},
		# Comércio de bairro
		{"id": "padaria", "kind": "shop", "name": "PADARIA PÃO QUENTE", "x": -2.5, "fz": 9.5, "dir": -1, "w": 8, "d": 9, "h": 6.5, "color": Color(0.88, 0.55, 0.32), "facade": 0, "awning": Color(0.85, 0.35, 0.15), "awning2": Color(0.98, 0.92, 0.8), "tables": true, "sign_color": Color(1.0, 0.8, 0.45)},
		{"id": "farmacia", "kind": "shop", "name": "FARMÁCIA", "x": 1, "fz": -9.5, "dir": 1, "w": 5.6, "d": 8, "h": 7.5, "color": Color(0.92, 0.94, 0.95), "facade": 2, "awning": Color(0.1, 0.6, 0.35), "awning2": Color(0.95, 0.98, 0.95), "cross": true, "sign_color": Color(0.3, 1.0, 0.55)},
		{"id": "lanchonete", "kind": "shop", "name": "LANCHONETE", "x": 27, "fz": 9.5, "dir": -1, "w": 8, "d": 9, "h": 5.5, "color": Color(0.95, 0.78, 0.35), "facade": 0, "awning": Color(0.8, 0.15, 0.15), "awning2": Color(0.98, 0.95, 0.85), "tables": true, "sign_color": Color(1.0, 0.5, 0.35)},
		{"id": "mercadinho", "kind": "shop", "name": "MERCADINHO", "x": 65, "fz": -9.5, "dir": 1, "w": 8, "d": 10, "h": 5.5, "color": Color(0.7, 0.82, 0.88), "facade": 0, "awning": Color(0.15, 0.4, 0.75), "awning2": Color(0.95, 0.95, 0.95), "sign_color": Color(0.6, 0.85, 1.0)},
	]


func _build_buildings() -> void:
	for d in _defs():
		var node := Node3D.new()
		node.name = d.id
		add_child(node)
		var dir: float = float(d.dir)
		var door := Vector3(float(d.x), 0, float(d.fz) + dir * 1.4)
		points[d.id] = door
		if d.has("lot"):
			lots[d.lot] = {"node": node, "def": d}
			if d.get("kind", "") == "house":
				_house(node, d)
			continue
		match str(d.get("kind", "")):
			"kiosk":
				_kiosk(node, d)
			"shop":
				_generic(node, d)
				_shop_extras(node, d)
			"house":
				_house(node, d)
			_:
				_generic(node, d)
		if d.get("kind", "") != "house":
			door_points.append(door)
	points["mercado_porta"] = points["mercado"]
	points["mercado_caminhao"] = Vector3(-32, 0, -7.5)
	points["galpao_porta"] = points["lot_galpao"]
	points["praca"] = Vector3(-18, 0, 18.5)
	points["ponto_onibus"] = Vector3(30, 0, 7.8)
	points["spawn"] = Vector3(-80, 0.2, -7.0)
	_truck(Vector3(-32, 0, -4.9))
	# Cassino Estrela (aberto desde o início, interior visitável)
	var casino := CornerCasino.new()
	casino.name = "cassino_estrela"
	add_child(casino)
	casino.build(25.5, -9.5, 1.0, self)
	points["cassino"] = Vector3(25.5, 0, -7.6)
	door_points.append(points["cassino"])


func _facade_basis(d: Dictionary) -> Dictionary:
	var dir: float = float(d.dir)
	var center := Vector3(float(d.x), 0, float(d.fz) - dir * float(d.d) / 2.0)
	return {"dir": dir, "center": center, "fz": float(d.fz)}


## Janela com moldura (quadro + vidro + peitoril).
func _window(node: Node3D, pos: Vector3, size: Vector2, dir: float, glass: Material = null) -> void:
	var g := glass if glass else Mats.window_glass(0.55)
	WorldKit.box(node, Vector3(size.x + 0.16, size.y + 0.16, 0.08), pos + Vector3(0, 0, dir * 0.02), c_frame, false)
	WorldKit.box(node, Vector3(size.x, size.y, 0.06), pos + Vector3(0, 0, dir * 0.06), g, false)
	WorldKit.box(node, Vector3(size.x + 0.3, 0.08, 0.22), pos + Vector3(0, -size.y / 2 - 0.08, dir * 0.11), Mats.facade(Color(0.8, 0.8, 0.78), 2), false)
	# divisória
	WorldKit.box(node, Vector3(0.05, size.y, 0.04), pos + Vector3(0, 0, dir * 0.1), c_frame, false)


## Janela em parede lateral (normal no eixo X).
func _side_window(node: Node3D, pos: Vector3, size: Vector2, side: float) -> void:
	var fr := WorldKit.box(node, Vector3(0.08, size.y + 0.16, size.x + 0.16), pos + Vector3(side * 0.02, 0, 0), c_frame, false)
	fr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorldKit.box(node, Vector3(0.06, size.y, size.x), pos + Vector3(side * 0.06, 0, 0), Mats.window_glass(0.55), false)
	WorldKit.box(node, Vector3(0.22, 0.08, size.x + 0.3), pos + Vector3(side * 0.11, -size.y / 2 - 0.08, 0), Mats.facade(Color(0.8, 0.8, 0.78), 2), false)


func _generic(node: Node3D, d: Dictionary) -> void:
	var b := _facade_basis(d)
	var w: float = d.w
	var h: float = d.h
	var depth: float = d.d
	var dir: float = b.dir
	var col: Color = d.color
	var wall := Mats.facade(col, int(d.get("facade", 0)))
	WorldKit.solid(node, Vector3(w, h, depth), b.center + Vector3(0, h / 2, 0), wall)
	var fz: float = b.fz + dir * 0.02
	# Rodapé, cornija e platibanda
	WorldKit.box(node, Vector3(w + 0.1, 0.6, depth + 0.1), b.center + Vector3(0, 0.3, 0), Mats.facade(col.darkened(0.45), 2))
	WorldKit.box(node, Vector3(w + 0.5, 0.3, depth + 0.5), b.center + Vector3(0, h - 0.15, 0), Mats.facade(col.lightened(0.25), 2))
	WorldKit.box(node, Vector3(w + 0.2, 0.7, depth + 0.2), b.center + Vector3(0, h + 0.35, 0), Mats.facade(col.darkened(0.15), int(d.get("facade", 0))))
	WorldKit.box(node, Vector3(w - 0.4, 0.05, depth - 0.4), b.center + Vector3(0, h + 0.03, 0), Mats.roof(), false)
	# Andar térreo: vitrine com moldura e porta de vidro
	if d.get("garage", false):
		WorldKit.box(node, Vector3(5.0, 4.2, 0.08), Vector3(float(d.x) + w * 0.22, 2.1, fz), Mats.facade(Color(0.55, 0.57, 0.6), 3), false)
		WorldKit.box(node, Vector3(5.3, 0.25, 0.2), Vector3(float(d.x) + w * 0.22, 4.3, fz + dir * 0.05), Mats.plastic(Color(0.95, 0.75, 0.1)), false)
		WorldKit.box(node, Vector3(1.6, 2.6, 0.08), Vector3(float(d.x) - w * 0.25, 1.3, fz), c_frame, false)
	else:
		var sw := minf(w - 1.2, 11.0)
		WorldKit.box(node, Vector3(sw + 0.3, 3.0, 0.1), Vector3(d.x, 1.75, fz), c_frame, false)
		WorldKit.box(node, Vector3(sw, 2.7, 0.06), Vector3(d.x, 1.75, fz + dir * 0.06), window_mat, false)
		for k in range(1, int(sw / 2.4) + 1):
			var xx := float(d.x) - sw / 2 + k * (sw / (int(sw / 2.4) + 1))
			WorldKit.box(node, Vector3(0.07, 2.7, 0.05), Vector3(xx, 1.75, fz + dir * 0.1), c_frame, false)
		WorldKit.box(node, Vector3(1.8, 2.5, 0.05), Vector3(d.x, 1.45, fz + dir * 0.11), Mats.plastic(Color(0.05, 0.07, 0.09), 0.1), false)
	# Andares superiores
	var floors := int((h - 4.0) / 3.0)
	for f in floors:
		var y := 5.2 + f * 3.0
		WorldKit.box(node, Vector3(w + 0.12, 0.12, 0.12), Vector3(d.x, y - 1.15, fz + dir * 0.05), Mats.facade(col.lightened(0.2), 2), false)
		var n := maxi(1, int(w / 2.8))
		for i in n:
			var x := float(d.x) - w / 2.0 + (i + 0.5) * (w / n)
			_window(node, Vector3(x, y, fz), Vector2(1.3, 1.6), dir)
		var nd := maxi(1, int(depth / 3.2))
		for side in [-1.0, 1.0]:
			for j in nd:
				var zz: float = b.center.z - depth / 2.0 + (j + 0.5) * (depth / nd)
				_side_window(node, Vector3(float(d.x) + side * (w / 2.0 + 0.02), y, zz), Vector2(1.2, 1.5), side)
		if d.get("residential", false) and f % 2 == 0:
			WorldKit.box(node, Vector3(w * 0.4, 0.1, 0.9), Vector3(d.x, y - 0.95, fz + dir * 0.45), Mats.facade(col.lightened(0.3), 2), true)
			WorldKit.box(node, Vector3(w * 0.4, 0.8, 0.04), Vector3(d.x, y - 0.55, fz + dir * 0.9), Mats.metal(Color(0.2, 0.2, 0.22), 0.4), false)
	# Toldo listrado
	if d.has("awning"):
		var aw := WorldKit.box(node, Vector3(minf(w * 0.75, 10.0), 0.08, 1.8), Vector3(d.x, 3.35, fz + dir * 0.9), Mats.awning(d.awning, d.get("awning2", Color(0.95, 0.95, 0.95))), true)
		aw.rotation.x = -dir * 0.22
	if d.get("columns", false):
		for side in [-1, 1]:
			WorldKit.cylinder(node, 0.38, h - 0.6, Vector3(float(d.x) + side * (w / 2.0 - 1.2), (h - 0.6) / 2.0, fz + dir * 0.7), Mats.facade(col.lightened(0.35), 2), 16)
		WorldKit.box(node, Vector3(w * 0.8, 0.4, 1.6), Vector3(d.x, h - 0.8, fz + dir * 0.7), Mats.facade(col.lightened(0.3), 2))
	# Equipamentos no telhado
	for i in rng.randi_range(1, 3):
		var rp: Vector3 = b.center + Vector3(rng.randf_range(-w / 3, w / 3), h + 0.45, rng.randf_range(-depth / 3, depth / 3))
		WorldKit.box(node, Vector3(1.2, 0.8, 1.0), rp, Mats.metal(Color(0.7, 0.72, 0.74), 0.5))
	if h > 9 and rng.randf() < 0.7:
		var tp: Vector3 = b.center + Vector3(-w / 4, h + 1.4, -dir * depth / 4)
		WorldKit.cylinder(node, 0.9, 1.6, tp, Mats.metal(Color(0.55, 0.57, 0.6), 0.6), 14)
	var sc: Color = d.get("sign_color", Color(1, 0.85, 0.3))
	var sl := _sign(node, str(d.name), Vector3(d.x, 4.2, fz + dir * 0.14), dir, sc, 60)
	comp_signs[d.id] = sl


## Detalhes de comércio de bairro: mesinhas com guarda-sol, cruz da farmácia, caixa d'água.
func _shop_extras(node: Node3D, d: Dictionary) -> void:
	var b := _facade_basis(d)
	var dir: float = b.dir
	var fz: float = b.fz
	if d.get("tables", false):
		var umbrella_cols := [Color(0.9, 0.3, 0.15), Color(0.95, 0.85, 0.3)]
		for k in 2:
			var tp := Vector3(float(d.x) - 2.0 + k * 4.0, 0.15, fz + dir * 2.2)
			WorldKit.cylinder(node, 0.45, 0.05, tp + Vector3(0, 0.75, 0), Mats.plastic(Color(0.95, 0.95, 0.92)), 14)
			WorldKit.cylinder(node, 0.04, 0.75, tp + Vector3(0, 0.37, 0), Mats.metal(), 6)
			WorldKit.cylinder(node, 0.025, 2.2, tp + Vector3(0, 1.1, 0), Mats.metal(), 6)
			var umb := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.05
			cone.bottom_radius = 1.2
			cone.height = 0.45
			cone.radial_segments = 8
			umb.mesh = cone
			umb.material_override = Mats.awning(umbrella_cols[k], Color(0.98, 0.95, 0.88))
			umb.position = tp + Vector3(0, 2.25, 0)
			node.add_child(umb)
			for sgn in [-1.0, 1.0]:
				WorldKit.cylinder(node, 0.2, 0.45, tp + Vector3(sgn * 0.75, 0.23, 0), Mats.plastic(Color(0.9, 0.9, 0.88)), 8)
	if d.get("cross", false):
		var cp := Vector3(float(d.x) + float(d.w) / 2.0 - 0.2, 4.6, fz + dir * 0.6)
		var gm := Mats.glow(Color(0.15, 1.0, 0.45), 3.0)
		WorldKit.box(node, Vector3(0.12, 1.1, 0.35), cp, gm, false)
		WorldKit.box(node, Vector3(0.12, 0.35, 1.1), cp, gm, false)
	var tank: Vector3 = b.center + Vector3(float(d.w) * 0.2, float(d.h) + 1.2, 0)
	WorldKit.cylinder(node, 0.6, 0.85, tank, Mats.plastic(Color(0.15, 0.4, 0.75), 0.5), 14)


func _sign(node: Node3D, text: String, pos: Vector3, dir: float, glow_col: Color, size: int = 60) -> Label3D:
	var board_w := text.length() * size * 0.0062 + 1.0
	WorldKit.box(node, Vector3(board_w, size * 0.017, 0.16), pos - Vector3(0, 0, dir * 0.05), Mats.plastic(Color(0.07, 0.07, 0.09), 0.3), false)
	var m := StandardMaterial3D.new()
	m.albedo_color = glow_col
	m.emission_enabled = true
	m.emission = glow_col
	day_night.register_night_material(m, 3.5)
	WorldKit.box(node, Vector3(board_w + 0.1, 0.05, 0.05), pos + Vector3(0, -size * 0.0085 - 0.02, dir * 0.05), m, false)
	var l := WorldKit.label(node, text, pos + Vector3(0, 0, dir * 0.04), size, glow_col.lightened(0.3), 8)
	if dir < 0:
		l.rotation.y = PI
	return l


func _kiosk(node: Node3D, d: Dictionary) -> void:
	var b := _facade_basis(d)
	var w: float = d.w
	var h: float = d.h
	var depth: float = d.d
	var dir: float = b.dir
	var c: Vector3 = b.center
	var wall := Mats.facade(d.color, 0)
	WorldKit.solid(node, Vector3(w, h, 0.3), c + Vector3(0, h / 2, -dir * depth / 2), wall)
	WorldKit.solid(node, Vector3(0.3, h, depth), c + Vector3(-w / 2, h / 2, 0), wall)
	WorldKit.solid(node, Vector3(0.3, h, depth), c + Vector3(w / 2, h / 2, 0), wall)
	WorldKit.box(node, Vector3(w, 0.08, depth), c + Vector3(0, 0.05, 0), Mats.paving(Color(0.6, 0.5, 0.4)), false)
	var aw := WorldKit.box(node, Vector3(w + 0.8, 0.12, depth + 1.4), c + Vector3(0, h, dir * 0.4), Mats.awning(d.awning, d.get("awning2", Color.WHITE)))
	aw.rotation.x = -dir * 0.08
	WorldKit.solid(node, Vector3(w - 0.6, 1.1, 0.6), c + Vector3(0, 0.55, dir * (depth / 2 - 0.5)), Mats.facade(Color(0.42, 0.26, 0.14), 0))
	WorldKit.box(node, Vector3(w - 0.4, 0.06, 0.75), c + Vector3(0, 1.12, dir * (depth / 2 - 0.5)), Mats.plastic(Color(0.85, 0.82, 0.75), 0.4), false)
	# TV com jogos e quadro de odds
	WorldKit.box(node, Vector3(2.2, 1.2, 0.1), c + Vector3(-1.2, 2.3, -dir * (depth / 2 - 0.2)), Mats.glow(Color(0.25, 0.6, 1.0), 1.0), false)
	WorldKit.box(node, Vector3(1.6, 1.4, 0.06), c + Vector3(1.8, 2.2, -dir * (depth / 2 - 0.2)), Mats.plastic(Color(0.08, 0.2, 0.1), 0.6), false)
	var odds := WorldKit.label(node, "ODDS\nDO DIA", c + Vector3(1.8, 2.3, -dir * (depth / 2 - 0.26)), 28, Color(0.95, 0.95, 0.8), 2)
	if dir < 0:
		odds.rotation.y = PI
	comp_signs[d.id] = _sign(node, str(d.name), c + Vector3(0, h + 0.75, dir * (depth / 2 + 0.6)), dir, Color(1.0, 0.7, 0.3), 64)
	var ze := Humanoid.new()
	node.add_child(ze)
	ze.setup(Color(0.85, 0.3, 0.2), Color(0.2, 0.2, 0.25), Color(0.7, 0.5, 0.38), Color(0.55, 0.55, 0.55), 4)
	ze.position = c + Vector3(0, 0, dir * (depth / 2 - 1.5))
	ze.rotation.y = 0.0 if dir > 0 else PI
	var counter_front := c + Vector3(0, 1.0, dir * (depth / 2 + 0.6))
	points[d.id] = Vector3(counter_front.x, 0, counter_front.z)
	var it := Interactable.create("Apostar na Banca do Zé", func(): Game.request_ui("bet_shop", d.id), 1.8)
	it.position = counter_front
	node.add_child(it)


func _house(node: Node3D, d: Dictionary) -> void:
	var b := _facade_basis(d)
	var w: float = d.w
	var depth: float = d.d
	var dir: float = b.dir
	var c: Vector3 = b.center
	var col: Color = d.color
	var wall_h := 3.6
	WorldKit.solid(node, Vector3(w, wall_h, depth), c + Vector3(0, wall_h / 2, 0), Mats.facade(col, 0))
	WorldKit.box(node, Vector3(w + 0.1, 0.5, depth + 0.1), c + Vector3(0, 0.25, 0), Mats.facade(col.darkened(0.4), 2))
	# Telhado de duas águas com telhas cerâmicas
	var roof_mi := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(depth + 1.0, 2.2, w + 0.8)
	roof_mi.mesh = prism
	roof_mi.material_override = Mats.tiles(Color(0.62, 0.28, 0.18))
	roof_mi.position = c + Vector3(0, wall_h + 1.1, 0)
	roof_mi.rotation.y = PI / 2
	node.add_child(roof_mi)
	var fz: float = b.fz + dir * 0.02
	# Porta, degrau e luz da varanda
	WorldKit.box(node, Vector3(1.3, 2.3, 0.1), Vector3(d.x, 1.4, fz), c_frame, false)
	WorldKit.box(node, Vector3(1.1, 2.15, 0.08), Vector3(d.x, 1.35, fz + dir * 0.04), Mats.plastic(Color(0.42, 0.26, 0.15), 0.6), false)
	WorldKit.box(node, Vector3(2.0, 0.2, 1.0), Vector3(d.x, 0.1, fz + dir * 0.5), Mats.facade(Color(0.7, 0.7, 0.68), 2))
	WorldKit.box(node, Vector3(0.2, 0.2, 0.2), Vector3(float(d.x) + 0.95, 2.6, fz + dir * 0.1), lamp_mat, false)
	for side in [-1, 1]:
		var wp := Vector3(float(d.x) + side * 2.7, 2.0, fz)
		_window(node, wp, Vector2(1.4, 1.2), dir)
		# venezianas
		for s2 in [-1, 1]:
			WorldKit.box(node, Vector3(0.45, 1.3, 0.05), wp + Vector3(s2 * 0.95, 0, dir * 0.08), Mats.plastic(col.darkened(0.45), 0.7), false)
	# Janelas laterais e dos fundos
	for side in [-1.0, 1.0]:
		_side_window(node, Vector3(float(d.x) + side * (w / 2.0 + 0.02), 2.0, c.z), Vector2(1.4, 1.2), side)
	_window(node, Vector3(d.x, 2.0, c.z - dir * (depth / 2.0 + 0.02)), Vector2(1.6, 1.2), -dir)
	# Jardim, cerca e arbustos
	WorldKit.box(node, Vector3(w, 0.06, 2.6), Vector3(d.x, 0.17, fz + dir * 1.3), Mats.grass(), false)
	var fence := Mats.plastic(Color(0.95, 0.95, 0.92), 0.6)
	for side in [-1, 1]:
		WorldKit.box(node, Vector3(w / 2 - 1.0, 0.7, 0.06), Vector3(float(d.x) + side * (w / 4 + 0.5), 0.5, fz + dir * 2.6), fence, false)
	var bush := Mats.leaves(Color(0.22, 0.45, 0.2))
	for side in [-1, 1]:
		WorldKit.sphere(node, 0.6, Vector3(float(d.x) + side * 3.3, 0.55, fz + dir * 1.2), bush)
	# Caixa d'água azul no telhado (bem brasileiro)
	if hash(str(d.id)) % 3 != 0:
		var tank := c + Vector3(-w * 0.22, wall_h + 1.6, -dir * depth * 0.15)
		WorldKit.cylinder(node, 0.55, 0.8, tank, Mats.plastic(Color(0.15, 0.4, 0.75), 0.5), 14)
		WorldKit.cylinder(node, 0.58, 0.08, tank + Vector3(0, 0.44, 0), Mats.plastic(Color(0.1, 0.32, 0.62), 0.5), 14)
	if d.has("lot"):
		lots[d.lot]["sign_pos"] = Vector3(float(d.x) + 3.0, 0, fz + dir * 1.9)


func _truck(pos: Vector3) -> void:
	var t := Node3D.new()
	add_child(t)
	t.position = pos
	var body := Mats.plastic(Color(0.95, 0.95, 0.93), 0.4)
	WorldKit.solid(t, Vector3(6.0, 2.7, 2.4), Vector3(-0.8, 1.85, 0), body)
	WorldKit.solid(t, Vector3(1.9, 2.0, 2.3), Vector3(3.2, 1.45, 0), Mats.car_paint(Color(0.15, 0.4, 0.75)))
	WorldKit.box(t, Vector3(0.06, 0.8, 2.0), Vector3(4.16, 1.9, 0), Mats.window_glass(0.0), false)
	var tire := Mats.plastic(Color(0.05, 0.05, 0.05), 0.85)
	for x in [-2.8, 1.0, 3.2]:
		for z in [-1.15, 1.15]:
			var wheel := WorldKit.cylinder(t, 0.48, 0.32, Vector3(x, 0.48, z), tire, 14)
			wheel.rotation.x = PI / 2
	var l := WorldKit.label(t, "MERCADO BOM PREÇO", Vector3(-0.8, 2.2, 1.22), 44, Color(0.15, 0.55, 0.2), 0)
	l.modulate = Color(0.12, 0.5, 0.18)


# --- Praça e props ----------------------------------------------------------------

func _build_plaza(center: Vector3) -> void:
	var p := Node3D.new()
	p.name = "praca"
	add_child(p)
	WorldKit.box(p, Vector3(22, 0.1, 16), center + Vector3(0, 0.05, 0), Mats.paving(Color(0.72, 0.66, 0.58)), false)
	# Fonte
	WorldKit.solid(p, Vector3(4.6, 0.6, 4.6), center + Vector3(0, 0.3, 0), Mats.facade(Color(0.75, 0.74, 0.7), 2))
	WorldKit.box(p, Vector3(4.0, 0.05, 4.0), center + Vector3(0, 0.58, 0), Mats.water(), false)
	WorldKit.cylinder(p, 0.3, 1.8, center + Vector3(0, 1.3, 0), Mats.facade(Color(0.8, 0.8, 0.78), 2), 12)
	WorldKit.cylinder(p, 0.9, 0.15, center + Vector3(0, 2.2, 0), Mats.facade(Color(0.8, 0.8, 0.78), 2), 16)
	var jet := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.05
	pm.scale_max = 0.09
	jet.process_material = pm
	var drop := SphereMesh.new()
	drop.radius = 0.5
	drop.height = 1.0
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = Mats.plastic(Color(0.7, 0.85, 1.0, 1.0), 0.05)
	jet.draw_pass_1 = drop
	jet.amount = 80
	jet.lifetime = 1.0
	jet.position = center + Vector3(0, 2.3, 0)
	p.add_child(jet)
	for off in [Vector3(-7.5, 0, -4.5), Vector3(7.5, 0, -4.5), Vector3(-7.5, 0, 4.5), Vector3(7.5, 0, 4.5)]:
		_tree(p, center + off, 1.2)
	for off in [Vector3(-4, 0, -6.3), Vector3(4, 0, -6.3), Vector3(-4, 0, 6.3), Vector3(4, 0, 6.3)]:
		_bench(p, center + off, 0.0 if off.z < 0 else PI)
	for off in [Vector3(-10, 0, 0), Vector3(10, 0, 0)]:
		_planter(p, center + off)
	# Ponto de ônibus
	var stop: Vector3 = points["ponto_onibus"]
	var glass := Mats.window_glass(0.0)
	WorldKit.box(p, Vector3(4, 0.12, 1.8), stop + Vector3(0, 2.7, 0.9), Mats.metal(Color(0.2, 0.3, 0.45), 0.4))
	WorldKit.box(p, Vector3(4, 2.2, 0.05), stop + Vector3(0, 1.5, 1.75), glass, false)
	for x in [-1.9, 1.9]:
		WorldKit.box(p, Vector3(0.1, 2.7, 0.1), stop + Vector3(x, 1.35, 1.6), c_pole)
	WorldKit.box(p, Vector3(3.0, 0.1, 0.5), stop + Vector3(0, 0.5, 1.4), Mats.metal(Color(0.6, 0.6, 0.62), 0.4))
	WorldKit.label(p, "PONTO DE ÔNIBUS", stop + Vector3(0, 3.0, 0.0), 32)


func _tree(parent: Node, pos: Vector3, scale_f: float = 1.0) -> void:
	var h := 2.4 * scale_f
	WorldKit.cylinder(parent, 0.2 * scale_f, h, pos + Vector3(0, h / 2, 0), Mats.bark(), 8)
	var tones := [Color(0.2, 0.42, 0.16), Color(0.25, 0.48, 0.18), Color(0.3, 0.5, 0.2)]
	var leaves := Mats.leaves(tones[rng.randi_range(0, 2)])
	var base := pos + Vector3(0, h + 0.9 * scale_f, 0)
	WorldKit.sphere(parent, 1.5 * scale_f, base, leaves)
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf()
		WorldKit.sphere(parent, rng.randf_range(0.8, 1.1) * scale_f, base + Vector3(cos(a) * 1.0, rng.randf_range(-0.2, 0.7), sin(a) * 1.0) * scale_f, leaves)
	WorldKit.sphere(parent, 0.9 * scale_f, base + Vector3(0, 1.1 * scale_f, 0), leaves)


func _bench(parent: Node, pos: Vector3, rot: float) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation.y = rot
	parent.add_child(b)
	var wood := Mats.plastic(Color(0.55, 0.36, 0.2), 0.7)
	for i in 3:
		WorldKit.box(b, Vector3(2.0, 0.06, 0.16), Vector3(0, 0.48, -0.2 + i * 0.2), wood)
	for i in 2:
		WorldKit.box(b, Vector3(2.0, 0.14, 0.05), Vector3(0, 0.75 + i * 0.2, 0.3), wood)
	for x in [-0.85, 0.85]:
		WorldKit.box(b, Vector3(0.08, 0.5, 0.6), Vector3(x, 0.25, 0.05), c_pole)


func _planter(parent: Node, pos: Vector3) -> void:
	WorldKit.solid(parent, Vector3(2.4, 0.6, 1.2), pos + Vector3(0, 0.3, 0), Mats.facade(Color(0.7, 0.68, 0.64), 2))
	WorldKit.box(parent, Vector3(2.2, 0.1, 1.0), pos + Vector3(0, 0.62, 0), Mats.plastic(Color(0.3, 0.2, 0.12), 0.95), false)
	var cols := [Color(0.9, 0.2, 0.3), Color(1.0, 0.8, 0.2), Color(0.8, 0.3, 0.9)]
	for i in 6:
		WorldKit.sphere(parent, 0.18, pos + Vector3(-0.85 + i * 0.34, 0.8, rng.randf_range(-0.25, 0.25)), Mats.plastic(cols[i % 3], 0.6))
	WorldKit.sphere(parent, 0.45, pos + Vector3(0, 0.95, 0), Mats.leaves(Color(0.25, 0.5, 0.2)))


func _build_street_props() -> void:
	var props := Node3D.new()
	props.name = "props"
	add_child(props)
	var lit := 0
	for z in [-7.5, 7.5]:
		for x in range(-92, 93, 16):
			if absf(x - CROSS_X[0]) < 7 or absf(x - CROSS_X[1]) < 7:
				continue
			var side := -1.0 if z < 0 else 1.0
			_lamp(props, Vector3(x, 0, z + side * 1.1), side, lit % 2 == 0)
			lit += 1
	for z in [-53.5, 53.5]:
		for x in range(-88, 89, 30):
			_lamp(props, Vector3(x, 0, z), -1.0 if z < 0 else 1.0, false)
	# Árvores na calçada
	for x in range(-88, 89, 22):
		for z in [-7.5, 7.5]:
			if absf(x + 18) < 12:
				continue
			_tree(props, Vector3(x + 8, 0.15, z + (1.0 if z > 0 else -1.0) * 0.4), 0.9)
	# Lixeiras e hidrantes
	for x in range(-84, 85, 28):
		for z in [-6.8, 6.8]:
			_trash(props, Vector3(x + 3, 0.15, z))
	for x in [-50.0, -12.0, 30.0, 66.0]:
		_hydrant(props, Vector3(x, 0.15, -6.7))
		_hydrant(props, Vector3(x + 10, 0.15, 6.7))
	# Carros estacionados
	var i := 0
	for x in [-70, -50, -12, 20, 64, 90, -88, 50]:
		var car := CarModel.build(CarModel.COLORS[i % CarModel.COLORS.size()], true)
		car.position = Vector3(x, 0.02, -5.0 if i % 2 == 0 else 5.0)
		car.rotation.y = 0.0 if i % 2 == 0 else PI
		props.add_child(car)
		i += 1
	# Postes de energia com fiação (calçadas da avenida)
	for z in [-8.6, 8.6]:
		var prev := Vector3.INF
		for x in range(-96, 97, 18):
			if absf(x - CROSS_X[0]) < 7 or absf(x - CROSS_X[1]) < 7:
				prev = Vector3.INF
				continue
			var top := _utility_pole(props, Vector3(x + 4, 0.15, z))
			if prev != Vector3.INF:
				_wire(props, prev, top)
				_wire(props, prev + Vector3(0, -0.5, 0.4), top + Vector3(0, -0.5, 0.4))
			prev = top
	# Palmeiras
	for pp in [Vector3(-29, 0.1, 11.5), Vector3(-7, 0.1, 11.5), Vector3(-29, 0.1, 25.5), Vector3(-7, 0.1, 25.5), Vector3(33.5, 0.15, -14), Vector3(-33.5, 0.15, 14), Vector3(33.5, 0.15, 30), Vector3(-33.5, 0.15, -30)]:
		_palm(props, pp)
	# Bueiros
	var manhole := Mats.metal(Color(0.18, 0.18, 0.19), 0.6)
	for x in range(-90, 91, 23):
		WorldKit.cylinder(props, 0.42, 0.03, Vector3(x + 5, 0.03, -2.6 if (x / 23) % 2 == 0 else 2.6), manhole, 16)
	_build_backyards(props)
	# Outdoors
	_billboard(props, Vector3(-40, 0, -24), PI / 2, "LUCKY BET", "ODDS TURBINADAS TODO DIA", Color(0.15, 0.55, 0.3), Color(1.0, 0.85, 0.2))
	_billboard(props, Vector3(40, 0, 24), -PI / 2, "ROYAL APOSTAS", "SALÃO DE JOGOS ABERTO 24H", Color(0.35, 0.12, 0.4), Color(1.0, 0.82, 0.35))
	_billboard(props, Vector3(-40, 0, 30), PI / 2, "ANUNCIE AQUI", "ESPAÇO DISPONÍVEL", Color(0.15, 0.17, 0.22), Color(0.9, 0.9, 0.9))


func _lamp(parent: Node, pos: Vector3, side: float, with_light: bool) -> void:
	WorldKit.cylinder(parent, 0.09, 5.4, pos + Vector3(0, 2.7, 0), c_pole, 8)
	WorldKit.box(parent, Vector3(0.08, 0.08, 1.2), pos + Vector3(0, 5.35, side * 0.55), c_pole)
	WorldKit.box(parent, Vector3(0.45, 0.14, 0.7), pos + Vector3(0, 5.3, side * 1.05), c_pole)
	WorldKit.box(parent, Vector3(0.36, 0.04, 0.6), pos + Vector3(0, 5.22, side * 1.05), lamp_mat, false)
	if with_light:
		var l := SpotLight3D.new()
		l.position = pos + Vector3(0, 5.1, side * 1.05)
		l.rotation.x = -PI / 2
		l.spot_range = 14.0
		l.spot_angle = 60.0
		l.light_energy = 3.0
		l.light_color = Color(1.0, 0.82, 0.55)
		l.shadow_enabled = false
		parent.add_child(l)
		day_night.register_light(l)


## Fundo dos quarteirões: quintais com árvores, muros, varais e um estacionamento.
func _build_backyards(props: Node3D) -> void:
	var wall := Mats.facade(Color(0.82, 0.78, 0.7), 0)
	# Faixas entre os prédios da avenida e as casas da rua de trás
	for zr in [[-40.0, -26.0], [26.0, 40.0]]:
		for x in range(-92, 93, 7):
			if absf(x - CROSS_X[0]) < 9 or absf(x - CROSS_X[1]) < 9:
				continue
			if zr[0] > 0 and x > 48:
				continue  # terreno central
			if zr[0] > 0 and x > -72 and x < -48:
				continue  # galpão
			if zr[0] < 0 and x >= 19 and x <= 32:
				continue  # cassino
			var z := rng.randf_range(float(zr[0]), float(zr[1]))
			var r := rng.randf()
			if r < 0.45:
				_tree(props, Vector3(x + rng.randf_range(-2, 2), 0, z), rng.randf_range(0.8, 1.3))
			elif r < 0.6:
				_palm(props, Vector3(x, 0, z))
			elif r < 0.75:
				WorldKit.box(props, Vector3(3.0, 2.4, 2.6), Vector3(x, 1.2, z), Mats.facade(Color(0.9, 0.85, 0.75).darkened(rng.randf() * 0.2), 0))
				WorldKit.box(props, Vector3(3.3, 0.15, 2.9), Vector3(x, 2.45, z), Mats.metal(Color(0.6, 0.6, 0.62), 0.5))
			else:
				WorldKit.sphere(props, rng.randf_range(0.7, 1.1), Vector3(x, 0.6, z), Mats.leaves(Color(0.25, 0.45, 0.2)))
		# muros de divisa
		for x in range(-90, 91, 14):
			if absf(x - CROSS_X[0]) < 9 or absf(x - CROSS_X[1]) < 9:
				continue
			if zr[0] > 0 and (x > 48 or (x > -72 and x < -48)):
				continue
			if zr[0] < 0 and x >= 16 and x <= 34:
				continue
			WorldKit.box(props, Vector3(0.2, 1.6, 12.0), Vector3(x + 3.5, 0.8, (float(zr[0]) + float(zr[1])) / 2.0), wall)
	# Estacionamento atrás da loja e do mercado
	var lot_c := Vector3(-2.0, 0.03, -32.0)
	WorldKit.box(props, Vector3(18.0, 0.04, 9.0), lot_c, Mats.asphalt(), false)
	for k in 6:
		WorldKit.box(props, Vector3(0.12, 0.02, 4.0), lot_c + Vector3(-7.5 + k * 3.0, 0.03, -2.0), c_line, false)
	for k in 4:
		var car := CarModel.build(CarModel.COLORS[(k * 3 + 1) % CarModel.COLORS.size()], true)
		car.position = lot_c + Vector3(-6.0 + k * 3.0 + (1.5 if k > 1 else 0.0), 0.0, -2.0)
		car.rotation.y = PI / 2
		props.add_child(car)


func _utility_pole(parent: Node, pos: Vector3) -> Vector3:
	var wood := Mats.facade(Color(0.55, 0.55, 0.52), 2)
	WorldKit.cylinder(parent, 0.13, 8.0, pos + Vector3(0, 4.0, 0), wood, 8)
	WorldKit.box(parent, Vector3(0.12, 0.12, 1.4), pos + Vector3(0, 7.6, 0.2), wood)
	for k in 3:
		WorldKit.cylinder(parent, 0.05, 0.12, pos + Vector3(0, 7.72, -0.4 + k * 0.4), Mats.plastic(Color(0.85, 0.85, 0.8)), 6)
	if hash(pos) % 3 == 0:
		WorldKit.cylinder(parent, 0.28, 0.7, pos + Vector3(0, 6.6, 0.25), Mats.metal(Color(0.5, 0.52, 0.55), 0.5), 10)
	return pos + Vector3(0, 7.75, 0)


## Fio com barriga entre dois postes (segmentos finos).
func _wire(parent: Node, a: Vector3, b: Vector3) -> void:
	var segs := 6
	var m := Mats.plastic(Color(0.06, 0.06, 0.07), 0.6)
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(b, t) + Vector3(0, -sin(t * PI) * 0.7, 0)
		var mid := (prev + p) / 2.0
		var len := prev.distance_to(p)
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.015
		c.bottom_radius = 0.015
		c.height = len
		c.radial_segments = 4
		c.rings = 1
		mi.mesh = c
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.position = mid
		mi.look_at_from_position(mid, p, Vector3.UP if absf((p - prev).normalized().y) < 0.99 else Vector3.RIGHT)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2)
		prev = p


func _palm(parent: Node, pos: Vector3) -> void:
	var trunk := Mats.bark()
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
	var p := pos
	for i in 6:
		var seg := WorldKit.cylinder(parent, 0.2 - i * 0.015, 1.1, p + Vector3(0, 0.55, 0), trunk, 8)
		seg.rotation = Vector3(lean.z * 0.3, 0, -lean.x * 0.3)
		p += Vector3(lean.x * 0.25, 1.05, lean.z * 0.25)
	var leaves := Mats.leaves(Color(0.22, 0.48, 0.18))
	for k in 9:
		var a := TAU * k / 9.0
		var frond := Node3D.new()
		frond.position = p
		frond.rotation = Vector3(0, a, 0)
		parent.add_child(frond)
		var leaf := WorldKit.box(frond, Vector3(0.5, 0.05, 2.6), Vector3(0, -0.35, 1.2), leaves)
		leaf.rotation.x = 0.45
	WorldKit.sphere(parent, 0.35, p, Mats.plastic(Color(0.35, 0.25, 0.12), 0.8))


func _trash(parent: Node, pos: Vector3) -> void:
	WorldKit.cylinder(parent, 0.28, 0.85, pos + Vector3(0, 0.43, 0), Mats.metal(Color(0.2, 0.35, 0.25), 0.5), 10)
	WorldKit.cylinder(parent, 0.31, 0.06, pos + Vector3(0, 0.88, 0), c_pole, 10)


func _hydrant(parent: Node, pos: Vector3) -> void:
	var red := Mats.car_paint(Color(0.8, 0.1, 0.08))
	WorldKit.cylinder(parent, 0.14, 0.6, pos + Vector3(0, 0.3, 0), red, 10)
	WorldKit.sphere(parent, 0.15, pos + Vector3(0, 0.62, 0), red)
	var nz := WorldKit.cylinder(parent, 0.06, 0.4, pos + Vector3(0, 0.4, 0), red, 8)
	nz.rotation.z = PI / 2


func _billboard(parent: Node, pos: Vector3, rot: float, title: String, sub: String, bg: Color, fg: Color) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation.y = rot
	parent.add_child(b)
	for x in [-2.5, 2.5]:
		WorldKit.cylinder(b, 0.15, 6.0, Vector3(x, 3.0, 0), c_pole, 8)
	WorldKit.box(b, Vector3(8.4, 3.4, 0.25), Vector3(0, 7.2, 0), c_frame)
	var m := StandardMaterial3D.new()
	m.albedo_color = bg
	m.emission_enabled = true
	m.emission = bg
	day_night.register_night_material(m, 0.6)
	WorldKit.box(b, Vector3(8.0, 3.0, 0.1), Vector3(0, 7.2, 0.1), m, false)
	WorldKit.label(b, title, Vector3(0, 7.7, 0.17), 150, fg, 10)
	WorldKit.label(b, sub, Vector3(0, 6.5, 0.17), 70, Color(1, 1, 1, 0.95), 6)
	var back := WorldKit.label(b, title, Vector3(0, 7.4, -0.15), 120, fg, 8)
	back.rotation.y = PI


# --- Navegação dos pedestres -------------------------------------------------------

func _build_sidewalk_graph() -> void:
	var xs := [-96.0, -46.5, -33.5, 33.5, 46.5, 96.0]
	var zs := [-53.5, -7.5, 7.5, 53.5]
	var index := {}
	for x in xs:
		for z in zs:
			index[Vector2(x, z)] = sidewalk_nodes.size()
			sidewalk_nodes.append(Vector3(x, 0.15, z))
	for i in sidewalk_nodes.size():
		sidewalk_edges[i] = []
	for z in zs:
		for k in xs.size() - 1:
			_edge(index[Vector2(xs[k], z)], index[Vector2(xs[k + 1], z)])
	for x in [-46.5, -33.5, 33.5, 46.5]:
		for k in zs.size() - 1:
			_edge(index[Vector2(x, zs[k])], index[Vector2(x, zs[k + 1])])


func _edge(a: int, b: int) -> void:
	sidewalk_edges[a].append(b)
	sidewalk_edges[b].append(a)


func nearest_node(pos: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in sidewalk_nodes.size():
		var d := pos.distance_squared_to(sidewalk_nodes[i])
		if d < bd:
			bd = d
			best = i
	return best


func point(name_id: String) -> Vector3:
	return points.get(name_id, Vector3.ZERO)
