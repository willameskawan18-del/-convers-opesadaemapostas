class_name Yard
extends Node3D
## O pátio de galpões à noite: fileira de portas de enrolar, luzes de sódio, leiloeiro,
## compradores na frente do galpão da vez e o interior com os itens.

const DOORS := 5
const DOOR_W := 3.6
const ACTIVE := 2          # índice da porta central (galpão da vez)

var cam: Camera3D
var env: Environment
var doors: Array[Node3D] = []
var door_labels: Array[Label3D] = []
var interior: Node3D
var bidders: Dictionary = {}   # pid -> CharacterModel
var bidder_labels: Dictionary = {}
var auctioneer: CharacterModel
var flash: SpotLight3D
var inside_light: OmniLight3D
var item_nodes: Array = []     # [{node, label, uid}]
var _cam_from := Transform3D()
var _cam_to := Transform3D()
var _cam_t := 1.0
var _cam_dur := 1.0
var _t := 0.0
var _door_open := 0.0
var _door_target := 0.0
var _orbit := false
var labels_on := false         # nomes 3D só aparecem com a porta aberta


func _ready() -> void:
	add_to_group("yard")
	_env()
	_ground()
	_building()
	_props()
	cam = Camera3D.new()
	cam.fov = 55
	add_child(cam)
	cam.make_current()
	shot("wide", 0.01)


func _env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0f1e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a5a8a")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("1a2238")
	env.fog_density = 0.012
	env.ssao_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-30), 0)
	moon.light_color = Color("9fb4ff")
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	add_child(moon)


func _ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	var g := M3.mesh(self, pm, Vector3(0, 0, 8), M3.solid(Color("2a2d33"), 0.85, 0.0, false))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# faixas pintadas no chão
	for i in 8:
		M3.box(self, Vector3(0.15, 0.01, 2.0), Vector3(-14 + i * 4, 0.01, 6), M3.solid(Color("d4b106"), 0.6), false)
	# poças refletindo as luzes
	for p in [Vector3(-4, 0.012, 4), Vector3(5, 0.012, 7), Vector3(1, 0.012, 10)]:
		var puddle := M3.cylinder(self, 1.2, 1.2, 0.01, p, M3.solid(Color("10131a"), 0.05, 0.6, false), 20)
		puddle.scale = Vector3(1.6, 1, 1)


func _building() -> void:
	var wall := M3.solid(Color("8a8f99"), 0.8)
	var total_w := DOORS * (DOOR_W + 0.8) + 0.8
	var seg := DOOR_W + 0.8
	var inner := M3.solid(Color("5c616b"), 0.9)
	for i in DOORS:
		var x := (i - ACTIVE) * seg
		if i != ACTIVE:
			M3.box(self, Vector3(seg, 4.2, 8), Vector3(x, 2.1, -4.2), wall)
		else:
			# galpão da vez é oco: paredes, fundo, teto e a verga acima da porta
			M3.box(self, Vector3(0.4, 4.2, 8), Vector3(x - seg / 2 + 0.2, 2.1, -4.2), wall)
			M3.box(self, Vector3(0.4, 4.2, 8), Vector3(x + seg / 2 - 0.2, 2.1, -4.2), wall)
			M3.box(self, Vector3(seg, 4.2, 0.4), Vector3(x, 2.1, -8.0), inner)
			M3.box(self, Vector3(seg, 0.3, 8), Vector3(x, 4.05, -4.2), inner)
			M3.box(self, Vector3(seg, 1.2, 0.4), Vector3(x, 3.6, -0.4), wall)
			for k in 3:
				M3.box(self, Vector3(0.1, 3.0, 7.6), Vector3(x - seg / 2 + 0.45, 1.5, -4.2), M3.solid(Color("777b84"), 0.7, 0.4))
	M3.box(self, Vector3(total_w + 0.6, 0.3, 8.6), Vector3(0, 4.35, -4.2), M3.solid(Color("5a5f69"), 0.6, 0.3))
	M3.label(self, "GUARDA-TUDO SELF STORAGE", Vector3(0, 3.65, -0.18), 64, Color("ffcf6b"), 10)
	for i in DOORS:
		var x := (i - ACTIVE) * (DOOR_W + 0.8)
		# moldura
		M3.box(self, Vector3(DOOR_W + 0.3, 0.25, 0.2), Vector3(x, 3.05, -0.12), M3.solid(Color("4a4f59"), 0.5, 0.5))
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0, -0.1)
		add_child(pivot)
		var door := Node3D.new()
		pivot.add_child(door)
		var col := Color("e8742a") if i != ACTIVE else Color("f28b30")
		for k in 8:
			M3.box(door, Vector3(DOOR_W, 0.36, 0.08), Vector3(0, 0.19 + k * 0.36, 0), M3.solid(col.darkened(0.06 * (k % 2)), 0.6, 0.3))
		M3.box(door, Vector3(0.5, 0.08, 0.1), Vector3(0, 0.35, 0.06), M3.solid(Color("cccccc"), 0.3, 0.8))
		doors.append(door)
		var num := M3.label(self, str(100 + i), Vector3(x, 3.3, 0.05), 40, Color.WHITE, 8)
		door_labels.append(num)
		# luz de sódio sobre cada porta
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 3.6, 1.2)
		lamp.light_color = Color("ffb04a")
		lamp.light_energy = 2.2 if i == ACTIVE else 1.2
		lamp.omni_range = 7.0
		lamp.shadow_enabled = i == ACTIVE
		add_child(lamp)
		M3.box(self, Vector3(0.6, 0.15, 0.4), Vector3(x, 3.75, 0.3), M3.glow(Color("ffb04a"), 2.5), false)
	# interior do galpão da vez
	interior = Node3D.new()
	interior.position = Vector3(0, 0, -4.2)
	add_child(interior)
	M3.box(interior, Vector3(DOOR_W - 0.1, 0.05, 7.4), Vector3(0, 0.02, 0), M3.solid(Color("3a3d44"), 0.9), false)
	inside_light = OmniLight3D.new()
	inside_light.position = Vector3(0, 2.8, 0)
	inside_light.light_color = Color("fff1d0")
	inside_light.light_energy = 0.0
	inside_light.omni_range = 7.0
	inside_light.shadow_enabled = true
	interior.add_child(inside_light)
	flash = SpotLight3D.new()
	flash.position = Vector3(0, 1.2, 4.6)
	flash.spot_angle = 24
	flash.spot_range = 12
	flash.light_energy = 0.0
	flash.light_color = Color("fffbe6")
	flash.shadow_enabled = true
	interior.add_child(flash)
	flash.look_at(interior.global_position + Vector3(0, 0.4, 2.0) if is_inside_tree() else Vector3(0, 0.4, -2.2))


func _props() -> void:
	# caminhonete do leiloeiro, cones, cerca e o palco do leiloeiro
	var truck := Node3D.new()
	truck.position = Vector3(-11, 0, 9)
	truck.rotation.y = 0.6
	add_child(truck)
	M3.box(truck, Vector3(2.0, 1.0, 4.2), Vector3(0, 0.9, 0), M3.solid(Color("2e6b8a"), 0.4, 0.4))
	M3.box(truck, Vector3(1.9, 0.8, 1.8), Vector3(0, 1.8, 0.9), M3.solid(Color("2e6b8a"), 0.4, 0.4))
	M3.box(truck, Vector3(1.7, 0.5, 0.05), Vector3(0, 1.85, 1.81), M3.solid(Color("90b8d0"), 0.1, 0.2))
	for w in [Vector3(-1, 0.4, 1.4), Vector3(1, 0.4, 1.4), Vector3(-1, 0.4, -1.4), Vector3(1, 0.4, -1.4)]:
		var wh := M3.cylinder(truck, 0.4, 0.4, 0.3, w, M3.solid(Color("111111"), 0.8), 16)
		wh.rotation.z = PI / 2
	M3.box(truck, Vector3(0.5, 0.2, 0.05), Vector3(-0.6, 0.9, 2.11), M3.glow(Color("fff2c0"), 3.0), false)
	M3.box(truck, Vector3(0.5, 0.2, 0.05), Vector3(0.6, 0.9, 2.11), M3.glow(Color("fff2c0"), 3.0), false)
	for x in [-3.0, 3.0]:
		M3.cylinder(self, 0.02, 0.18, 0.5, Vector3(x, 0.25, 2.2), M3.solid(Color("ff6a00"), 0.5), 10)
	for i in 14:
		M3.box(self, Vector3(0.05, 2.0, 0.05), Vector3(-26 + i * 4, 1.0, 22), M3.solid(Color("777777"), 0.4, 0.8))
	M3.box(self, Vector3(56, 1.8, 0.02), Vector3(0, 1.0, 22), M3.solid(Color(0.6, 0.6, 0.6, 1), 0.4, 0.8))
	# palquinho do leiloeiro
	M3.box(self, Vector3(1.6, 0.5, 1.2), Vector3(7.0, 0.25, 1.4), M3.solid(Color("6d4c2f"), 0.6))
	M3.box(self, Vector3(1.0, 1.0, 0.5), Vector3(7.0, 1.0, 1.9), M3.solid(Color("8b5e3c"), 0.6))
	M3.label(self, "LEILÃO HOJE", Vector3(7.0, 1.2, 2.17), 28, Color("ffd43b"), 6)
	auctioneer = CharacterModel.create("rico")
	auctioneer.position = Vector3(7.0, 0.5, 1.2)
	auctioneer.rotation.y = -0.6
	add_child(auctioneer)


# --- Compradores ----------------------------------------------------------------------

func sync_bidders(players: Array) -> void:
	var ids := players.map(func(p): return int(p.id))
	for pid in bidders.keys():
		if not ids.has(pid):
			bidders[pid].queue_free()
			bidders.erase(pid)
	var n := players.size()
	for i in n:
		var p: Dictionary = players[i]
		var pid := int(p.id)
		var m: CharacterModel = bidders.get(pid)
		if m and m.character != str(p.character):
			m.queue_free()
			bidders.erase(pid)
			m = null
		if m == null:
			m = CharacterModel.create(str(p.character))
			add_child(m)
			bidders[pid] = m
			var lbl := M3.label(m, str(p.name), Vector3(0, 2.6, 0), 30, GameData.character_color(str(p.character)).lightened(0.3), 8, true)
			bidder_labels[pid] = lbl
		var ang := lerpf(-0.9, 0.9, 0.5 if n == 1 else float(i) / (n - 1))
		m.position = Vector3(sin(ang) * 5.2, 0, 1.6 + cos(ang) * 5.2 * 0.7)
		m.look_at(Vector3(0, 0, -1), Vector3.UP, true)
		m.scale = Vector3.ONE * 0.85
		(bidder_labels[pid] as Label3D).text = "%s  %s" % [p.name, Fmt.money(int(p.money))]


func bidder_anim(pid: int, anim: String) -> void:
	if bidders.has(pid):
		bidders[pid].play(anim)


func all_anim(anim: String) -> void:
	for m in bidders.values():
		m.play(anim)


## Balão de fala sobre o comprador.
func say(pid: int, text: String) -> void:
	if not bidders.has(pid):
		return
	var m: Node3D = bidders[pid]
	var old := m.get_node_or_null("Bubble")
	if old:
		old.queue_free()
	var l := M3.label(m, "“" + text + "”", Vector3(0, 3.5, 0), 26, Color("fff3bf"), 12, true)
	l.outline_modulate = Color("2a1640")
	l.no_depth_test = true
	l.name = "Bubble"
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func bidder_pos(pid: int) -> Vector3:
	return bidders[pid].global_position if bidders.has(pid) else Vector3.ZERO


# --- Galpão -----------------------------------------------------------------------------

func load_unit(number: int) -> void:
	labels_on = false
	_clear_items()
	for i in DOORS:
		door_labels[i].text = str(number - ACTIVE + i)
	set_door(0.0)
	inside_light.light_energy = 0.0
	flash.light_energy = 0.0


func _clear_items() -> void:
	for it in item_nodes:
		it.node.queue_free()
	item_nodes.clear()


## Monta o interior: os primeiros `visible` itens aparecem; o resto fica sob lonas.
func fill(items: Array, total: int, visible: int) -> void:
	_clear_items()
	for i in total:
		var row := int(i / 3)
		var col := i % 3
		var pos := Vector3((col - 1) * 1.05, 0, 2.6 - row * 1.5)
		var node: Node3D
		var lbl: Label3D = null
		if i < items.size() and i < visible:
			var it: Dictionary = items[i]
			node = ItemProp.build(str(it.shape), str(it.color), i * 13 + total)
			lbl = _item_label(node, str(it.name), i, Color.WHITE)
		else:
			node = ItemProp.tarp(i * 7 + total)
		node.position = pos
		node.rotation.y = randf_range(-0.4, 0.4)
		interior.add_child(node)
		item_nodes.append({"node": node, "label": lbl, "index": i})


## Nome do item flutuando acima dele, quebrado em linhas e em alturas alternadas para
## os nomes vizinhos não se sobreporem.
func _item_label(node: Node3D, text: String, index: int, col: Color, big: bool = false) -> Label3D:
	var l := M3.label(node, text, Vector3(0, 1.25 + (index % 2) * 0.32, 0), 15 if big else 12, col, 6, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = 140.0
	l.visible = labels_on
	return l


## Revela um item (substitui a lona) com um pulinho.
func reveal_item(index: int, it: Dictionary, big: bool) -> void:
	for e in item_nodes:
		if int(e.index) != index:
			continue
		var pos: Vector3 = e.node.position
		e.node.queue_free()
		var node := ItemProp.build(str(it.shape), str(it.color), index * 13 + 99)
		node.position = pos
		interior.add_child(node)
		var col := Color("ffd43b") if big else Color.WHITE
		var lbl := _item_label(node, str(it.name), index, col, big)
		e.node = node
		e.label = lbl
		node.scale = Vector3.ONE * 0.2
		create_tween().tween_property(node, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if big:
			var glow := OmniLight3D.new()
			glow.light_color = Color("ffd43b")
			glow.light_energy = 3.0
			glow.omni_range = 2.5
			glow.position = Vector3(0, 1.0, 0.6)
			node.add_child(glow)
		return


func set_door(target: float) -> void:
	_door_target = target


func peek_lights() -> void:
	flash.light_energy = 10.0
	inside_light.light_energy = 0.0


func open_lights() -> void:
	labels_on = true
	for e in item_nodes:
		if e.label and is_instance_valid(e.label):
			e.label.visible = true
	flash.light_energy = 2.0
	inside_light.light_energy = 2.5


# --- Câmera ------------------------------------------------------------------------------

func shot(name_: String, dur: float = 1.0, focus: Vector3 = Vector3.ZERO) -> void:
	_orbit = name_ == "menu"
	var pos := Vector3(0, 4.5, 13)
	var look := Vector3(0, 1.4, 0)
	match name_:
		"wide":
			pos = Vector3(0, 5.5, 14)
			look = Vector3(0, 1.5, -1)
		"door":
			pos = Vector3(0, 0.75, 3.4)
			look = Vector3(0, 0.45, -3.0)
		"inside":
			pos = Vector3(0, 2.6, 3.0)
			look = Vector3(0, 0.6, -3.6)
		"bidders":
			pos = Vector3(0, 2.4, 0.6)
			look = Vector3(0, 1.1, 6.0)
		"bidder":
			pos = focus + Vector3(0, 2.6, -3.2)
			look = focus + Vector3(0, 1.2, 0)
		"menu":
			pos = Vector3(6, 4.0, 12)
			look = Vector3(0, 1.5, -1)
	_cam_from = cam.global_transform
	_cam_to = Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	_cam_t = 0.0
	_cam_dur = maxf(dur, 0.01)


func _process(delta: float) -> void:
	_t += delta
	_door_open = move_toward(_door_open, _door_target, delta * 0.9)
	for i in doors.size():
		var o := _door_open if i == ACTIVE else 0.0
		doors[i].position.y = o * 2.7
		doors[i].scale.y = 1.0 - o * 0.85
	if _orbit:
		var a := _t * 0.08
		cam.global_transform = Transform3D(Basis(), Vector3(sin(a) * 9.0, 4.2, 9.0 + cos(a) * 3.0)).looking_at(Vector3(0, 1.4, -1), Vector3.UP)
		return
	_cam_t = minf(1.0, _cam_t + delta / _cam_dur)
	var k := ease(_cam_t, -2.2)
	var tr := _cam_from.interpolate_with(_cam_to, k)
	tr.origin += Vector3(sin(_t * 0.7) * 0.03, sin(_t * 0.9) * 0.02, 0)
	cam.global_transform = tr
