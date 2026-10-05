class_name CornerCasino
extends Node3D
## Cassino Estrela: cassino aberto desde o início do jogo, com interior visitável dividido
## em áreas sinalizadas. Cada máquina/mesa mostra o nome do jogo e abre o jogo com [E].

const W := 11.0
const D := 26.0
const H := 5.5

## Áreas da frente para o fundo: nome, cor, jogos (lado esquerdo, lado direito)
const ZONES := [
	["MÁQUINAS", Color("ff3b8d"), ["caca_niquel", "video_slot", "jackpot"], ["caca_niquel", "video_slot", "video_poker"]],
	["MESAS DE CARTAS", Color("3ddc84"), ["blackjack", "bacara"], ["dragao_tigre", "bac_dados"]],
	["ROLETA & RODA", Color("ffb020"), ["roleta", "sic_bo"], ["roda", "roleta"]],
	["JOGOS RÁPIDOS", Color("4ea8ff"), ["aviaozinho", "plinko", "minas"], ["dados", "hilo", "keno"]],
	["SORTE & BINGO", Color("c77dff"), ["bingo"], ["raspadinha"]],
]
const KIND_VISUAL := {
	"caca_niquel": "slot", "video_slot": "slot", "jackpot": "jackpot", "video_poker": "slot",
	"blackjack": "table", "bacara": "table", "dragao_tigre": "table", "bac_dados": "table", "sic_bo": "table",
	"roleta": "wheel", "roda": "bigwheel", "aviaozinho": "screen", "plinko": "screen", "minas": "terminal",
	"dados": "terminal", "hilo": "terminal", "keno": "screen", "bingo": "screen", "raspadinha": "terminal",
}

var roof: Node3D
var interior: Rect2
var dir := 1.0
var gamblers: Array = []


## fz = z da fachada; dir = +1 se a fachada aponta para +z.
func build(x: float, fz: float, p_dir: float, city: City) -> void:
	dir = p_dir
	position = Vector3(x, 0, fz - p_dir * D / 2.0)
	rotation.y = 0.0 if p_dir > 0 else PI
	var wall := Mats.facade(Color(0.16, 0.08, 0.24), 2)
	var gold := Mats.metal(Color(0.95, 0.75, 0.3), 0.25)
	var t := 0.3
	# Piso de carpete e paredes
	WorldKit.solid(self, Vector3(W, 0.12, D), Vector3(0, 0.06, 0), Mats.carpet(Color(0.3, 0.05, 0.12), Color(0.95, 0.75, 0.3)))
	WorldKit.solid(self, Vector3(W, H, t), Vector3(0, H / 2, -D / 2 + t / 2), wall)
	WorldKit.solid(self, Vector3(t, H, D), Vector3(-W / 2 + t / 2, H / 2, 0), wall)
	WorldKit.solid(self, Vector3(t, H, D), Vector3(W / 2 - t / 2, H / 2, 0), wall)
	var door_w := 3.0
	var side_w := (W - door_w) / 2.0
	for sgn in [-1.0, 1.0]:
		WorldKit.solid(self, Vector3(side_w, H, t), Vector3(sgn * (door_w / 2 + side_w / 2), H / 2, D / 2 - t / 2), wall)
		WorldKit.box(self, Vector3(side_w * 0.75, 2.2, 0.05), Vector3(sgn * (door_w / 2 + side_w / 2), 1.6, D / 2 + 0.01), city.window_mat, false)
	WorldKit.solid(self, Vector3(door_w, H - 3.2, t), Vector3(0, 3.2 + (H - 3.2) / 2, D / 2 - t / 2), wall)
	# Fachada: pórtico dourado, marquise com luzes e letreiro
	for sgn in [-1.0, 1.0]:
		WorldKit.cylinder(self, 0.28, H + 0.6, Vector3(sgn * (door_w / 2 + 0.5), (H + 0.6) / 2, D / 2 + 0.6), gold, 14)
	WorldKit.box(self, Vector3(W + 0.6, 0.3, 2.4), Vector3(0, 3.5, D / 2 + 1.1), Mats.plastic(Color(0.12, 0.05, 0.16), 0.3))
	for i in 12:
		WorldKit.sphere(self, 0.09, Vector3(-W / 2 + 0.5 + i * (W - 1.0) / 11.0, 3.32, D / 2 + 2.25), Mats.glow(Color(1.0, 0.85, 0.4), 4.0))
	var sign_board := WorldKit.box(self, Vector3(W - 0.6, 1.5, 0.2), Vector3(0, H + 0.9, D / 2 + 0.05), Mats.plastic(Color(0.07, 0.03, 0.1), 0.3), false)
	sign_board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorldKit.label(self, "CASSINO ESTRELA", Vector3(0, H + 1.05, D / 2 + 0.17), 120, Color("ffd36b"), 12)
	WorldKit.label(self, "ABERTO 24 HORAS  ·  ENTRADA LIVRE", Vector3(0, H + 0.45, D / 2 + 0.17), 40, Color(1, 1, 1, 0.95), 6)
	WorldKit.box(self, Vector3(W - 0.4, 0.06, 0.06), Vector3(0, H + 0.12, D / 2 + 0.16), Mats.glow(Color("ff3b8d"), 4.0), false)
	WorldKit.box(self, Vector3(W - 0.4, 0.06, 0.06), Vector3(0, H + 1.68, D / 2 + 0.16), Mats.glow(Color("ff3b8d"), 4.0), false)
	# Tapete vermelho na entrada
	WorldKit.box(self, Vector3(2.4, 0.03, 3.0), Vector3(0, 0.03, D / 2 + 1.5), Mats.cloth(Color(0.65, 0.05, 0.1)), false)
	# Teto (escondido quando o jogador entra)
	roof = Node3D.new()
	add_child(roof)
	WorldKit.box(roof, Vector3(W + 0.4, 0.3, D + 0.4), Vector3(0, H + 0.15, 0), Mats.roof())
	interior = Rect2(Vector2(-W / 2, -D / 2), Vector2(W, D))
	# Luzes e faixas de neon
	for k in 4:
		var l := OmniLight3D.new()
		l.position = Vector3(0, H - 0.7, -D / 2 + D * (k + 0.5) / 4.0)
		l.omni_range = 9.0
		l.light_energy = 1.8
		l.light_color = Color(1.0, 0.85, 0.7)
		add_child(l)
	for sgn in [-1.0, 1.0]:
		WorldKit.box(self, Vector3(0.05, 0.08, D - 0.8), Vector3(sgn * (W / 2 - 0.33), H - 0.4, 0), Mats.glow(Color("ff3b8d"), 2.5), false)
		WorldKit.box(self, Vector3(0.05, 0.08, D - 0.8), Vector3(sgn * (W / 2 - 0.33), 0.25, 0), Mats.glow(Color("4ea8ff"), 2.0), false)
	# Recepção (caixa de fichas)
	var rz := D / 2 - 2.2
	WorldKit.solid(self, Vector3(2.6, 1.1, 0.7), Vector3(-W / 2 + 1.8, 0.55, rz), Mats.plastic(Color(0.1, 0.05, 0.08), 0.3))
	WorldKit.box(self, Vector3(2.8, 0.08, 0.9), Vector3(-W / 2 + 1.8, 1.12, rz), gold, false)
	var host := Humanoid.new()
	add_child(host)
	host.setup(Color(0.1, 0.1, 0.12), Color(0.08, 0.08, 0.1), Color(0.8, 0.6, 0.45), Color(0.15, 0.1, 0.05), 3)
	host.position = Vector3(-W / 2 + 1.8, 0.12, rz - 0.9)
	var hl := WorldKit.label(self, "RECEPÇÃO", Vector3(-W / 2 + 1.8, 2.3, rz), 40, Color("ffd36b"), 6)
	hl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interact(Vector3(-W / 2 + 1.8, 1.0, rz + 0.8), "Recepção: ver todos os jogos do cassino", "")
	# Áreas com jogos
	var zone_len := (D - 5.0) / ZONES.size()
	for zi in ZONES.size():
		var z: Array = ZONES[zi]
		var z_center := D / 2 - 4.2 - zi * zone_len - zone_len / 2.0
		_zone_sign(str(z[0]), z[1], z_center + zone_len / 2.0 - 0.3)
		for side in [-1, 1]:
			var games: Array = z[2] if side < 0 else z[3]
			for gi in games.size():
				var gz := z_center + zone_len / 2.0 - (gi + 0.5) * (zone_len / games.size())
				var gx: float = side * (W / 2 - 1.3)
				_game_station(str(games[gi]), Vector3(gx, 0.12, gz), side, z[1])
	# Jogadores (NPCs) em algumas máquinas
	var shirts := [Color(0.8, 0.2, 0.2), Color(0.2, 0.5, 0.8), Color(0.9, 0.9, 0.9), Color(0.3, 0.6, 0.35), Color(0.95, 0.6, 0.2), Color(0.5, 0.3, 0.6)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 6:
		var g := Humanoid.new()
		add_child(g)
		g.setup(shirts[i], Color(0.15, 0.17, 0.25), [Color(0.95, 0.78, 0.65), Color(0.6, 0.42, 0.3), Color(0.42, 0.28, 0.2)][i % 3])
		var side: int = -1 if i % 2 == 0 else 1
		g.position = Vector3(side * (W / 2 - 2.6), 0.12, D / 2 - 5.0 - i * 3.3)
		g.rotation.y = -side * PI / 2
		gamblers.append(g)


func _zone_sign(text: String, col: Color, z: float) -> void:
	var board := WorldKit.box(self, Vector3(4.6, 0.7, 0.1), Vector3(0, H - 1.1, z), Mats.plastic(Color(0.05, 0.03, 0.08), 0.3), false)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorldKit.box(self, Vector3(4.6, 0.05, 0.12), Vector3(0, H - 1.47, z), Mats.glow(col, 3.0), false)
	for face in [1.0, -1.0]:
		var l := WorldKit.label(self, text, Vector3(0, H - 1.08, z + face * 0.07), 64, col.lightened(0.25), 8)
		l.no_depth_test = false
		l.visibility_range_end = 11.0
		l.visibility_range_end_margin = 2.0
		l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if face < 0:
			l.rotation.y = PI
	WorldKit.cylinder(self, 0.015, 1.0, Vector3(-2.0, H - 0.3, z), Mats.metal(), 4)
	WorldKit.cylinder(self, 0.015, 1.0, Vector3(2.0, H - 0.3, z), Mats.metal(), 4)


func _game_station(game: String, p: Vector3, side: int, col: Color) -> void:
	var info: Dictionary = CasinoLogic.GAMES.get(game, {})
	var node := Node3D.new()
	node.position = p
	node.rotation.y = side * -PI / 2   # de frente para o corredor central
	add_child(node)
	match str(KIND_VISUAL.get(game, "slot")):
		"slot", "jackpot":
			var body_c := Color(0.55, 0.08, 0.14) if game != "jackpot" else Color(0.75, 0.6, 0.15)
			WorldKit.solid(node, Vector3(0.9, 1.9, 0.8), Vector3(0, 0.95, 0), Mats.car_paint(body_c))
			WorldKit.box(node, Vector3(0.7, 0.6, 0.05), Vector3(0, 1.35, 0.41), Mats.glow(Color(1.0, 0.8, 0.3), 1.3), false)
			WorldKit.box(node, Vector3(0.92, 0.16, 0.82), Vector3(0, 1.98, 0), Mats.glow(col, 3.0), false)
			WorldKit.box(node, Vector3(0.55, 0.06, 0.28), Vector3(0, 0.98, 0.5), Mats.metal(Color(0.85, 0.85, 0.88), 0.2), false)
			var lever := WorldKit.cylinder(node, 0.03, 0.5, Vector3(0.5, 1.4, 0.1), Mats.metal(), 6)
			lever.rotation.z = 0.2
			WorldKit.sphere(node, 0.07, Vector3(0.55, 1.65, 0.1), Mats.car_paint(Color(0.9, 0.1, 0.1)))
		"table":
			WorldKit.solid(node, Vector3(1.9, 0.85, 1.2), Vector3(0, 0.42, 0), Mats.plastic(Color(0.25, 0.14, 0.08), 0.4))
			WorldKit.box(node, Vector3(1.7, 0.03, 1.0), Vector3(0, 0.87, 0), Mats.cloth(Color(0.05, 0.42, 0.22)), false)
			for k in 3:
				WorldKit.cylinder(node, 0.2, 0.55, Vector3(-0.6 + k * 0.6, 0.28, 0.95), Mats.plastic(Color(0.5, 0.08, 0.1), 0.5), 10)
			var dealer := Humanoid.new()
			node.add_child(dealer)
			dealer.setup(Color(0.95, 0.95, 0.95), Color(0.08, 0.08, 0.1), Color(0.75, 0.55, 0.42), Color(0.1, 0.08, 0.05), 1)
			dealer.position = Vector3(0, 0, -0.95)
		"wheel":
			WorldKit.solid(node, Vector3(1.9, 0.85, 1.2), Vector3(0, 0.42, 0), Mats.plastic(Color(0.25, 0.14, 0.08), 0.4))
			WorldKit.box(node, Vector3(1.7, 0.03, 1.0), Vector3(0, 0.87, 0), Mats.cloth(Color(0.05, 0.42, 0.22)), false)
			WorldKit.cylinder(node, 0.38, 0.12, Vector3(-0.45, 0.95, 0), Mats.plastic(Color(0.55, 0.08, 0.08), 0.3), 24)
			WorldKit.cylinder(node, 0.08, 0.2, Vector3(-0.45, 1.05, 0), Mats.metal(Color(0.9, 0.75, 0.3), 0.2))
		"bigwheel":
			WorldKit.solid(node, Vector3(1.4, 0.6, 0.6), Vector3(0, 0.3, 0), Mats.plastic(Color(0.15, 0.08, 0.2), 0.4))
			var wheel := WorldKit.cylinder(node, 0.95, 0.12, Vector3(0, 1.75, 0), Mats.plastic(Color(0.95, 0.75, 0.25), 0.3), 32)
			wheel.rotation.x = PI / 2
			WorldKit.cylinder(node, 0.12, 0.2, Vector3(0, 1.75, 0.1), Mats.glow(col, 3.0)).rotation.x = PI / 2
		"screen":
			WorldKit.solid(node, Vector3(1.6, 0.9, 0.5), Vector3(0, 0.45, 0), Mats.plastic(Color(0.12, 0.12, 0.18), 0.3))
			WorldKit.box(node, Vector3(1.6, 1.0, 0.08), Vector3(0, 1.55, -0.1), Mats.glow(col.darkened(0.2), 1.4), false)
		_:
			WorldKit.solid(node, Vector3(0.75, 1.45, 0.55), Vector3(0, 0.72, 0), Mats.plastic(Color(0.12, 0.12, 0.16), 0.3))
			WorldKit.box(node, Vector3(0.6, 0.5, 0.05), Vector3(0, 1.12, 0.28), Mats.glow(col, 1.4), false)
	# Placa com o nome do jogo, voltada para o corredor, e interação
	var plate := WorldKit.box(node, Vector3(1.3, 0.34, 0.04), Vector3(0, 2.32, 0.42), Mats.plastic(Color(0.05, 0.03, 0.08), 0.3), false)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorldKit.box(node, Vector3(1.3, 0.03, 0.05), Vector3(0, 2.14, 0.42), Mats.glow(col, 2.5), false)
	var name_lbl := WorldKit.label(node, str(info.get("name", game)).to_upper(), Vector3(0, 2.33, 0.45), 15, col.lightened(0.45), 4)
	name_lbl.width = 125.0
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.no_depth_test = false
	var kind_lbl := WorldKit.label(node, "%s · aperte E" % info.get("kind", ""), Vector3(0, 2.02, 0.45), 9, Color(1, 1, 1, 0.85), 3)
	kind_lbl.visibility_range_end = 5.0
	kind_lbl.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var it := Interactable.create("Jogar " + str(info.get("name", game)), func(): Game.request_ui("casino_game", {"venue": "estrela", "game": game}), 1.1)
	it.position = Vector3(0, 1.0, 0.9)
	node.add_child(it)


func _interact(local_pos: Vector3, prompt: String, game: String) -> void:
	var it := Interactable.create(prompt, func(): Game.request_ui("casino_game", {"venue": "estrela", "game": game}), 1.2)
	it.position = local_pos
	add_child(it)


func _process(_d: float) -> void:
	var p: Node3D = Game.player if Game.playing and is_instance_valid(Game.player) else null
	if p == null:
		roof.visible = true
		return
	var l := to_local(p.global_position)
	var inside := interior.grow(-0.2).has_point(Vector2(l.x, l.z))
	roof.visible = not inside
	if inside and p is PlayerController:
		p.rig.set_indoor(true)
	elif p is PlayerController and _was_inside:
		p.rig.set_indoor(false)
	_was_inside = inside
	for i in gamblers.size():
		gamblers[i].animate(0.0, _d)


var _was_inside := false
