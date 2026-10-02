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
var window_mat: StandardMaterial3D
var neon_mat: StandardMaterial3D
var lamp_mat: StandardMaterial3D
var sidewalk_nodes: Array = []    # Vector3
var sidewalk_edges: Dictionary = {}  # índice -> [índices vizinhos]
var door_points: Array = []       # portas visitáveis por pedestres
var comp_signs: Dictionary = {}   # id do concorrente -> Label3D do letreiro

var c_asphalt := WorldKit.mat(Color(0.16, 0.17, 0.19), 0.95)
var c_sidewalk := WorldKit.mat(Color(0.62, 0.6, 0.57), 0.9)
var c_grass := WorldKit.mat(Color(0.32, 0.5, 0.26), 1.0)
var c_line := WorldKit.mat(Color(0.95, 0.9, 0.7), 0.8)
var c_dark := WorldKit.mat(Color(0.12, 0.12, 0.14), 0.6)
var c_glass := WorldKit.mat(Color(0.3, 0.45, 0.55), 0.15, 0.3)


func _ready() -> void:
	day_night = DayNight.new()
	add_child(day_night)
	window_mat = StandardMaterial3D.new()
	window_mat.albedo_color = Color(0.25, 0.32, 0.4)
	window_mat.roughness = 0.2
	window_mat.emission_enabled = true
	window_mat.emission = Color(1.0, 0.82, 0.5)
	day_night.register_night_material(window_mat, 1.6)
	neon_mat = StandardMaterial3D.new()
	neon_mat.albedo_color = Color(1.0, 0.8, 0.25)
	neon_mat.emission_enabled = true
	neon_mat.emission = Color(1.0, 0.75, 0.2)
	day_night.register_night_material(neon_mat, 3.0)
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.95, 0.95, 0.85)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.85, 0.6)
	day_night.register_night_material(lamp_mat, 4.0)
	_build_ground()
	_build_roads()
	_build_buildings()
	_build_plaza(Vector3(-18, 0, 18.5))
	_build_street_props()
	_build_bounds()
	_build_sidewalk_graph()


# --- Terreno e ruas ----------------------------------------------------------

func _build_ground() -> void:
	WorldKit.solid(self, Vector3(HALF * 2.4, 1.0, HALF * 2.4), Vector3(0, -0.5, 0), c_grass)


func _build_roads() -> void:
	var road_h := 0.02
	# Avenida central
	WorldKit.box(self, Vector3(HALF * 2, road_h, AVENUE_W), Vector3(0, road_h / 2, 0), c_asphalt, false)
	for x in range(-96, 97, 8):
		WorldKit.box(self, Vector3(4.0, 0.03, 0.25), Vector3(x, 0.03, 0), c_line, false)
	# Ruas de trás
	for z in BACK_Z:
		WorldKit.box(self, Vector3(HALF * 2, road_h, 10.0), Vector3(0, road_h / 2, z), c_asphalt, false)
	# Transversais
	for x in CROSS_X:
		WorldKit.box(self, Vector3(10.0, road_h + 0.005, BACK_Z[1] * 2 + 10.0), Vector3(x, road_h / 2 + 0.003, 0), c_asphalt, false)
		for z in [-9.5, 9.5, -51.5, 51.5]:
			_crosswalk(Vector3(x, 0.035, z), true)
	# Calçadas (elevadas 12 cm, sem colisão separada para não travar o personagem)
	for z in [-7.5, 7.5]:
		_sidewalk_strip(Vector3(0, 0, z), Vector3(HALF * 2, 0.12, 3.0))
	for z in [-53.5, 53.5]:
		_sidewalk_strip(Vector3(0, 0, z), Vector3(HALF * 2, 0.12, 3.0))
	for x in CROSS_X:
		for side in [-6.5, 6.5]:
			_sidewalk_strip(Vector3(x + side, 0, 0), Vector3(3.0, 0.12, BACK_Z[1] * 2 - 10.0))


func _crosswalk(center: Vector3, along_x: bool) -> void:
	for i in range(-3, 4):
		var off := Vector3(i * 1.2, 0, 0) if along_x else Vector3(0, 0, i * 1.2)
		WorldKit.box(self, Vector3(0.6, 0.02, 3.0) if along_x else Vector3(3.0, 0.02, 0.6), center + off, c_line, false)


func _sidewalk_strip(center: Vector3, size: Vector3) -> void:
	WorldKit.solid(self, size, center + Vector3(0, size.y / 2, 0), c_sidewalk)


func _build_bounds() -> void:
	WorldKit.solid(self, Vector3(HALF * 2.2, 8, 1), Vector3(0, 4, HALF + 8), null)
	WorldKit.solid(self, Vector3(HALF * 2.2, 8, 1), Vector3(0, 4, -HALF - 8), null)
	WorldKit.solid(self, Vector3(1, 8, HALF * 2.2), Vector3(HALF + 8, 4, 0), null)
	WorldKit.solid(self, Vector3(1, 8, HALF * 2.2), Vector3(-HALF - 8, 4, 0), null)
	# Arbustos marcando o fim da cidade
	for x in range(-104, 105, 8):
		for z in [-HALF - 7.0, HALF + 7.0]:
			WorldKit.sphere(self, 2.2, Vector3(x, 1.0, z), WorldKit.mat(Color(0.2, 0.38, 0.18)))
	for z in range(-104, 105, 8):
		for x in [-HALF - 7.0, HALF + 7.0]:
			WorldKit.sphere(self, 2.2, Vector3(x, 1.0, z), WorldKit.mat(Color(0.2, 0.38, 0.18)))


# --- Prédios -----------------------------------------------------------------

## Definição dos prédios. dir = +1: fachada voltada para +z (corpo em z menor).
func _defs() -> Array:
	return [
		# Avenida, lado norte (fachada em z = -9.5)
		{"id": "casa_jogador", "name": "EDIFÍCIO AURORA", "x": -80, "fz": -9.5, "dir": 1, "w": 10, "d": 10, "h": 12, "color": Color(0.85, 0.78, 0.65), "awning": Color(0.5, 0.3, 0.2)},
		{"id": "banco", "name": "BANCO CENTRAL", "x": -60, "fz": -9.5, "dir": 1, "w": 14, "d": 12, "h": 11, "color": Color(0.55, 0.6, 0.68), "awning": Color(0.15, 0.25, 0.45), "columns": true},
		{"id": "mercado", "name": "MERCADO BOM PREÇO", "x": -22, "fz": -9.5, "dir": 1, "w": 16, "d": 12, "h": 6, "color": Color(0.9, 0.9, 0.85), "awning": Color(0.2, 0.6, 0.25)},
		{"id": "lot_sala", "lot": "sala_comercio", "x": -6, "fz": -9.5, "dir": 1, "w": 8, "d": 8, "h": 5, "color": Color(0.75, 0.7, 0.62)},
		{"id": "loja", "name": "ELETRO CENTER", "x": 10, "fz": -9.5, "dir": 1, "w": 12, "d": 10, "h": 6.5, "color": Color(0.82, 0.86, 0.92), "awning": Color(0.15, 0.35, 0.8)},
		{"id": "ze", "kind": "kiosk", "name": "BANCA DO ZÉ", "x": 56, "fz": -9.5, "dir": 1, "w": 8, "d": 6, "h": 3.6, "color": Color(0.9, 0.55, 0.2), "awning": Color(0.8, 0.2, 0.15)},
		{"id": "lucky", "name": "LUCKY BET", "x": 78, "fz": -9.5, "dir": 1, "w": 16, "d": 12, "h": 7, "color": Color(0.18, 0.5, 0.3), "awning": Color(0.95, 0.8, 0.2), "neon": true},
		# Avenida, lado sul (fachada em z = 9.5)
		{"id": "deposito", "name": "DEPÓSITO LOGÍSTICO", "x": -82, "fz": 9.5, "dir": -1, "w": 14, "d": 14, "h": 8, "color": Color(0.6, 0.55, 0.5), "awning": Color(0.7, 0.5, 0.1), "garage": true},
		{"id": "lot_galpao", "lot": "galpao_porto", "x": -60, "fz": 9.5, "dir": -1, "w": 22, "d": 26, "h": 9, "color": Color(0.55, 0.57, 0.6)},
		{"id": "lot_salao", "lot": "salao_avenida", "x": 12, "fz": 9.5, "dir": -1, "w": 20, "d": 14, "h": 7, "color": Color(0.8, 0.75, 0.7)},
		{"id": "lot_terreno", "lot": "terreno_central", "x": 72, "fz": 9.5, "dir": -1, "w": 44, "d": 38, "h": 0, "color": Color(0.5, 0.45, 0.35)},
		# Rua de trás norte (fachada em z = -51.5, voltada para -z)
		{"id": "casa_1", "kind": "house", "x": -85, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.9, 0.85, 0.7)},
		{"id": "casa_2", "kind": "house", "x": -65, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.75, 0.82, 0.9)},
		{"id": "casa_3", "kind": "house", "x": -15, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.92, 0.75, 0.7)},
		{"id": "casa_4", "kind": "house", "x": 5, "fz": -51.5, "dir": -1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.8, 0.9, 0.75)},
		{"id": "royal", "name": "ROYAL APOSTAS", "x": 75, "fz": -51.5, "dir": -1, "w": 18, "d": 14, "h": 9, "color": Color(0.35, 0.15, 0.4), "awning": Color(0.9, 0.75, 0.3), "neon": true, "columns": true},
		# Rua de trás sul (fachada em z = 51.5, voltada para +z)
		{"id": "casa_5", "kind": "house", "lot": "casa_azul", "x": -25, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.45, 0.6, 0.85)},
		{"id": "casa_6", "kind": "house", "lot": "casa_verde", "x": -5, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.5, 0.75, 0.5)},
		{"id": "casa_7", "kind": "house", "x": 15, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.9, 0.9, 0.8)},
		{"id": "casa_8", "kind": "house", "x": -85, "fz": 51.5, "dir": 1, "w": 9, "d": 9, "h": 5.5, "color": Color(0.85, 0.7, 0.55)},
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
			"house":
				_house(node, d)
			_:
				_generic(node, d)
		if d.get("kind", "") != "house":
			door_points.append(door)
	# Pontos de trabalho específicos
	points["mercado_porta"] = points["mercado"]
	points["mercado_caminhao"] = Vector3(-32, 0, -7.5)
	points["galpao_porta"] = points["lot_galpao"]
	points["praca"] = Vector3(-18, 0, 18.5)
	points["ponto_onibus"] = Vector3(30, 0, 7.8)
	points["spawn"] = Vector3(-80, 0.2, -7.0)
	# Caminhão do mercado
	_truck(Vector3(-32, 0, -4.2))


func _facade_basis(d: Dictionary) -> Dictionary:
	var dir: float = float(d.dir)
	var center := Vector3(float(d.x), 0, float(d.fz) - dir * float(d.d) / 2.0)
	return {"dir": dir, "center": center, "fz": float(d.fz)}


func _generic(node: Node3D, d: Dictionary) -> void:
	var b := _facade_basis(d)
	var w: float = d.w
	var h: float = d.h
	var depth: float = d.d
	var dir: float = b.dir
	var col: Color = d.color
	WorldKit.solid(node, Vector3(w, h, depth), b.center + Vector3(0, h / 2, 0), WorldKit.mat(col))
	WorldKit.box(node, Vector3(w + 0.4, 0.4, depth + 0.4), b.center + Vector3(0, h + 0.2, 0), WorldKit.mat(col.darkened(0.3)))
	var fz: float = b.fz + dir * 0.03
	# Porta e vitrine
	WorldKit.box(node, Vector3(2.0, 2.6, 0.08), Vector3(d.x, 1.3, fz), c_dark, false)
	if not d.get("garage", false):
		for side in [-1, 1]:
			if w > 9:
				WorldKit.box(node, Vector3(w * 0.28, 2.0, 0.06), Vector3(float(d.x) + side * w * 0.3, 1.5, fz), window_mat, false)
	else:
		WorldKit.box(node, Vector3(5.0, 4.0, 0.08), Vector3(float(d.x) + w * 0.25, 2.0, fz), WorldKit.mat(Color(0.45, 0.45, 0.48), 0.5, 0.5), false)
	# Janelas dos andares superiores
	var floors := int((h - 3.5) / 3.0)
	for f in floors:
		var y := 4.6 + f * 3.0
		var n := int(w / 3.0)
		for i in n:
			var x := float(d.x) - w / 2.0 + (i + 0.5) * (w / n)
			WorldKit.box(node, Vector3(1.4, 1.5, 0.06), Vector3(x, y, fz), window_mat, false)
	# Toldo e letreiro
	if d.has("awning"):
		var aw := WorldKit.box(node, Vector3(minf(w * 0.7, 9.0), 0.15, 1.6), Vector3(d.x, 3.0, fz + dir * 0.8), WorldKit.mat(d.awning), true)
		aw.rotation.x = -dir * 0.15
	if d.get("columns", false):
		for side in [-1, 1]:
			WorldKit.cylinder(node, 0.35, h - 0.5, Vector3(float(d.x) + side * (w / 2.0 - 1.0), (h - 0.5) / 2.0, fz + dir * 0.5), WorldKit.mat(col.lightened(0.3)))
	var sl := _sign(node, str(d.name), Vector3(d.x, 3.9, fz + dir * 0.12), dir, d.get("neon", false), 56)
	comp_signs[d.id] = sl


func _sign(node: Node3D, text: String, pos: Vector3, dir: float, neon: bool, size: int = 56) -> Label3D:
	var board_w := text.length() * 0.36 + 0.8
	WorldKit.box(node, Vector3(board_w, 0.9, 0.12), pos - Vector3(0, 0, dir * 0.06), WorldKit.mat(Color(0.1, 0.1, 0.12)), false)
	var l := WorldKit.label(node, text, pos + Vector3(0, 0, dir * 0.03), size, Color(1, 0.85, 0.3) if neon else Color.WHITE, 8)
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
	var wall := WorldKit.mat(d.color)
	# Paredes laterais/fundo (frente aberta com balcão)
	WorldKit.solid(node, Vector3(w, h, 0.3), c + Vector3(0, h / 2, -dir * depth / 2), wall)
	WorldKit.solid(node, Vector3(0.3, h, depth), c + Vector3(-w / 2, h / 2, 0), wall)
	WorldKit.solid(node, Vector3(0.3, h, depth), c + Vector3(w / 2, h / 2, 0), wall)
	WorldKit.box(node, Vector3(w + 0.6, 0.25, depth + 0.8), c + Vector3(0, h, dir * 0.2), WorldKit.mat(d.awning))
	WorldKit.solid(node, Vector3(w - 0.6, 1.1, 0.6), c + Vector3(0, 0.55, dir * (depth / 2 - 0.5)), WorldKit.mat(Color(0.35, 0.22, 0.12)))
	# TV com jogos
	WorldKit.box(node, Vector3(2.2, 1.2, 0.1), c + Vector3(0, 2.3, -dir * (depth / 2 - 0.2)), WorldKit.mat(Color(0.1, 0.3, 0.5), 0.3, 0.0, Color(0.3, 0.6, 1.0), 0.8), false)
	comp_signs[d.id] = _sign(node, str(d.name), c + Vector3(0, h + 0.7, dir * (depth / 2 + 0.6)), dir, true, 60)
	# Zé atrás do balcão
	var ze := Humanoid.new()
	node.add_child(ze)
	ze.setup(Color(0.85, 0.3, 0.2), Color(0.2, 0.2, 0.25), Color(0.7, 0.5, 0.38), Color(0.5, 0.5, 0.5))
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
	var h: float = d.h
	var dir: float = b.dir
	var c: Vector3 = b.center
	var col: Color = d.color
	WorldKit.solid(node, Vector3(w, h - 1.5, d.d), c + Vector3(0, (h - 1.5) / 2, 0), WorldKit.mat(col))
	var roof := WorldKit.box(node, Vector3(w + 0.8, 1.6, float(d.d) + 0.8), c + Vector3(0, h - 0.6, 0), WorldKit.mat(Color(0.55, 0.25, 0.18)))
	roof.scale = Vector3(1, 1, 1)
	var fz: float = b.fz + dir * 0.03
	WorldKit.box(node, Vector3(1.2, 2.2, 0.08), Vector3(d.x, 1.1, fz), WorldKit.mat(Color(0.4, 0.25, 0.15)), false)
	for side in [-1, 1]:
		WorldKit.box(node, Vector3(1.4, 1.2, 0.06), Vector3(float(d.x) + side * 2.6, 1.8, fz), window_mat, false)
	# Cerquinha e jardim
	WorldKit.box(node, Vector3(w, 0.05, 2.0), Vector3(d.x, 0.13, fz + dir * 1.0), WorldKit.mat(Color(0.3, 0.55, 0.28)), false)
	if d.has("lot"):
		lots[d.lot]["sign_pos"] = Vector3(float(d.x) + 3.0, 0, fz + dir * 1.6)


func _truck(pos: Vector3) -> void:
	var t := Node3D.new()
	add_child(t)
	t.position = pos
	WorldKit.solid(t, Vector3(6.0, 2.6, 2.4), Vector3(-0.8, 1.7, 0), WorldKit.mat(Color(0.92, 0.92, 0.9)))
	WorldKit.solid(t, Vector3(1.8, 2.0, 2.3), Vector3(3.2, 1.4, 0), WorldKit.mat(Color(0.2, 0.45, 0.8)))
	for x in [-2.8, 1.0, 3.2]:
		for z in [-1.15, 1.15]:
			var wheel := WorldKit.cylinder(t, 0.45, 0.3, Vector3(x, 0.45, z), c_dark)
			wheel.rotation.x = PI / 2
	var l := WorldKit.label(t, "BOM PREÇO", Vector3(-0.8, 2.2, 1.22), 48, Color(0.2, 0.55, 0.2), 4)
	l.modulate = Color(0.15, 0.5, 0.2)


# --- Praça e props ----------------------------------------------------------------

func _build_plaza(center: Vector3) -> void:
	var p := Node3D.new()
	p.name = "praca"
	add_child(p)
	WorldKit.box(p, Vector3(22, 0.1, 16), center + Vector3(0, 0.05, 0), WorldKit.mat(Color(0.7, 0.66, 0.6)), false)
	WorldKit.solid(p, Vector3(4.2, 0.6, 4.2), center + Vector3(0, 0.3, 0), WorldKit.mat(Color(0.6, 0.6, 0.62)))
	WorldKit.cylinder(p, 1.7, 0.1, center + Vector3(0, 0.62, 0), WorldKit.mat(Color(0.3, 0.55, 0.8), 0.1, 0.0, Color(0.2, 0.4, 0.7), 0.3))
	WorldKit.cylinder(p, 0.25, 1.6, center + Vector3(0, 1.2, 0), WorldKit.mat(Color(0.75, 0.75, 0.78)))
	for off in [Vector3(-7, 0, -4), Vector3(7, 0, -4), Vector3(-7, 0, 4), Vector3(7, 0, 4)]:
		_tree(p, center + off)
	for off in [Vector3(-4, 0, -6), Vector3(4, 0, -6), Vector3(-4, 0, 6), Vector3(4, 0, 6)]:
		_bench(p, center + off)
	# Ponto de ônibus
	var stop: Vector3 = points["ponto_onibus"]
	WorldKit.box(p, Vector3(4, 0.1, 1.6), stop + Vector3(0, 2.6, 0.8), WorldKit.mat(Color(0.2, 0.3, 0.45)))
	for x in [-1.9, 1.9]:
		WorldKit.box(p, Vector3(0.1, 2.6, 0.1), stop + Vector3(x, 1.3, 1.4), c_dark)
	WorldKit.label(p, "PONTO", stop + Vector3(0, 2.9, 0.2), 40)


func _tree(parent: Node, pos: Vector3) -> void:
	WorldKit.cylinder(parent, 0.22, 2.4, pos + Vector3(0, 1.2, 0), WorldKit.mat(Color(0.4, 0.28, 0.18)), 8)
	WorldKit.sphere(parent, 1.6, pos + Vector3(0, 3.2, 0), WorldKit.mat(Color(0.22, 0.48, 0.22)))
	WorldKit.sphere(parent, 1.1, pos + Vector3(0.6, 4.1, 0.3), WorldKit.mat(Color(0.26, 0.55, 0.25)))


func _bench(parent: Node, pos: Vector3) -> void:
	WorldKit.box(parent, Vector3(2.0, 0.12, 0.6), pos + Vector3(0, 0.5, 0), WorldKit.mat(Color(0.5, 0.32, 0.18)))
	WorldKit.box(parent, Vector3(2.0, 0.5, 0.1), pos + Vector3(0, 0.8, 0.28), WorldKit.mat(Color(0.5, 0.32, 0.18)))


func _build_street_props() -> void:
	var props := Node3D.new()
	props.name = "props"
	add_child(props)
	var lit := 0
	for z in [-7.5, 7.5]:
		for x in range(-92, 93, 16):
			if absf(x - CROSS_X[0]) < 6 or absf(x - CROSS_X[1]) < 6:
				continue
			var side := -1.0 if z < 0 else 1.0
			_lamp(props, Vector3(x, 0, z - side * 1.2), lit % 2 == 0)
			lit += 1
	for z in [-53.5, 53.5]:
		for x in range(-88, 89, 30):
			_lamp(props, Vector3(x, 0, z), false)
	# Árvores nas calçadas
	for x in range(-88, 89, 22):
		for z in [-7.5, 7.5]:
			if absf(x + 18) < 12:
				continue
			_tree(props, Vector3(x + 8, 0, z + (1.0 if z > 0 else -1.0) * 0.6))
	# Carros estacionados
	var colors := [Color(0.8, 0.15, 0.15), Color(0.15, 0.3, 0.7), Color(0.9, 0.9, 0.9), Color(0.1, 0.1, 0.1), Color(0.85, 0.7, 0.1), Color(0.3, 0.55, 0.35)]
	var i := 0
	for x in [-70, -50, -12, 20, 64, 90, -88, 50]:
		_car(props, Vector3(x, 0, -4.6 if i % 2 == 0 else 4.6), colors[i % colors.size()])
		i += 1


func _lamp(parent: Node, pos: Vector3, with_light: bool) -> void:
	WorldKit.cylinder(parent, 0.08, 5.0, pos + Vector3(0, 2.5, 0), c_dark, 6)
	WorldKit.box(parent, Vector3(0.5, 0.15, 0.5), pos + Vector3(0, 5.05, 0), lamp_mat, false)
	if with_light:
		var l := OmniLight3D.new()
		l.position = pos + Vector3(0, 4.6, 0)
		l.omni_range = 13.0
		l.light_energy = 1.6
		l.light_color = Color(1.0, 0.85, 0.6)
		l.shadow_enabled = false
		parent.add_child(l)
		day_night.register_light(l)


func _car(parent: Node, pos: Vector3, color: Color) -> void:
	var car := Node3D.new()
	parent.add_child(car)
	car.position = pos
	WorldKit.solid(car, Vector3(4.2, 0.8, 1.8), Vector3(0, 0.7, 0), WorldKit.mat(color, 0.35, 0.4))
	WorldKit.box(car, Vector3(2.2, 0.65, 1.6), Vector3(-0.2, 1.42, 0), c_glass)
	for x in [-1.3, 1.3]:
		for z in [-0.9, 0.9]:
			var wheel := WorldKit.cylinder(car, 0.36, 0.25, Vector3(x, 0.36, z), c_dark, 10)
			wheel.rotation.x = PI / 2


# --- Navegação dos pedestres -------------------------------------------------------

func _build_sidewalk_graph() -> void:
	var xs := [-96.0, -46.5, -33.5, 33.5, 46.5, 96.0]
	var zs := [-53.5, -7.5, 7.5, 53.5]
	var index := {}
	for x in xs:
		for z in zs:
			index[Vector2(x, z)] = sidewalk_nodes.size()
			sidewalk_nodes.append(Vector3(x, 0.12, z))
	for i in sidewalk_nodes.size():
		sidewalk_edges[i] = []
	# Horizontais
	for z in zs:
		for k in xs.size() - 1:
			_edge(index[Vector2(xs[k], z)], index[Vector2(xs[k + 1], z)])
	# Verticais (apenas nas transversais)
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
