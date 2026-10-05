class_name CharacterModel
extends Node3D
## Personagem cartoon montado com formas simples. 8 visuais: sortudo, azarado, rico,
## trapaceiro, apostador, gênio, medroso e maluco. Animações procedurais.

var character := "sortudo"
var color := Color.WHITE
var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var mouth: Node3D
var extras: Node3D
var _t := 0.0
var _anim := "idle"
var _anim_t := 0.0
var _phase := 0.0


static func create(char_id: String) -> CharacterModel:
	var c := CharacterModel.new()
	c.character = char_id
	c.color = GameData.character_color(char_id)
	c._build()
	return c


func _build() -> void:
	_phase = randf() * TAU
	body = Node3D.new()
	add_child(body)
	var skin := M3.solid(color, 0.4)
	var dark := M3.solid(Color(0.08, 0.05, 0.1), 0.3)
	var white := M3.solid(Color(1, 1, 1), 0.25, 0.0, false)
	var big_head := 1.18 if character == "genio" else 1.0
	# corpo (feijão) + barriga mais clara
	M3.capsule(body, 0.42, 1.15, Vector3(0, 0.78, 0), skin)
	var belly := M3.sphere(body, 0.3, Vector3(0, 0.68, 0.2), M3.solid(color.lightened(0.35), 0.5))
	belly.scale = Vector3(1.0, 1.1, 0.5)
	# pés
	for sx in [-0.18, 0.18]:
		var foot := M3.sphere(body, 0.15, Vector3(sx, 0.12, 0.08), dark)
		foot.scale = Vector3(1.0, 0.6, 1.4)
	# braços (pivô no ombro)
	arm_l = _arm(skin, -1)
	arm_r = _arm(skin, 1)
	# cabeça
	head = Node3D.new()
	head.position = Vector3(0, 1.48, 0)
	head.scale = Vector3.ONE * big_head
	body.add_child(head)
	M3.sphere(head, 0.4, Vector3(0, 0.12, 0), skin)
	# olhos
	var eye_r := 0.105
	var pupil := 0.05
	if character == "medroso":
		eye_r = 0.14
		pupil = 0.03
	for sx in [-0.14, 0.14]:
		var er := eye_r
		if character == "maluco" and sx > 0:
			er = eye_r * 1.4
		M3.sphere(head, er, Vector3(sx, 0.2, 0.31), white, 16)
		M3.sphere(head, pupil if character != "maluco" else pupil * (1.6 if sx > 0 else 0.8), Vector3(sx + (0.02 if character == "trapaceiro" else 0.0), 0.2, 0.31 + er * 0.85), dark, 12)
	# boca
	mouth = Node3D.new()
	mouth.position = Vector3(0, -0.02, 0.36)
	head.add_child(mouth)
	var smile := 1.0
	if character in ["azarado", "medroso"]:
		smile = -1.0
	for i in 5:
		var x := (i - 2) * 0.05
		var y := smile * (0.02 * (absf(i - 2) - 1.0))
		M3.sphere(mouth, 0.022, Vector3(x, y, 0), dark, 8)
	extras = Node3D.new()
	head.add_child(extras)
	_accessories(dark, white)


func _arm(mat: Material, side: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.4 * side, 1.12, 0)
	body.add_child(pivot)
	var a := M3.capsule(pivot, 0.09, 0.5, Vector3(0.06 * side, -0.22, 0), mat)
	a.rotation.z = 0.25 * side
	M3.sphere(pivot, 0.11, Vector3(0.12 * side, -0.46, 0.02), mat, 12)
	pivot.rotation.z = 0.15 * side
	return pivot


func _accessories(dark: Material, white: Material) -> void:
	match character:
		"sortudo":
			# boné verde com trevo de quatro folhas
			M3.cylinder(extras, 0.3, 0.36, 0.16, Vector3(0, 0.5, 0), M3.solid(Color("1e8c4e")))
			var aba := M3.cylinder(extras, 0.3, 0.3, 0.03, Vector3(0, 0.43, 0.22), M3.solid(Color("1e8c4e")))
			aba.scale = Vector3(1.0, 1.0, 0.8)
			for a in 4:
				var ang := a * PI / 2.0 + PI / 4.0
				M3.sphere(extras, 0.07, Vector3(cos(ang) * 0.07, 0.68 + sin(ang) * 0.07, 0.05), M3.glow(Color("6dff8a"), 1.2), 10)
		"azarado":
			# nuvem de chuva e curativo
			var cloud := Node3D.new()
			cloud.name = "Cloud"
			cloud.position = Vector3(0, 1.05, 0)
			extras.add_child(cloud)
			for p in [Vector3(-0.18, 0, 0), Vector3(0.15, 0.02, 0), Vector3(0, 0.1, 0), Vector3(0.05, -0.04, 0.1)]:
				M3.sphere(cloud, 0.17, p, M3.solid(Color("4a4f63"), 0.9), 12)
			for i in 4:
				var drop := M3.capsule(cloud, 0.015, 0.09, Vector3(-0.15 + i * 0.1, -0.25 - (i % 2) * 0.1, 0), M3.glow(Color("7fb2ff"), 1.0))
				drop.name = "Drop%d" % i
			var band := M3.box(extras, Vector3(0.22, 0.06, 0.02), Vector3(0.18, 0.42, 0.28), M3.solid(Color("f2d0a9")))
			band.rotation = Vector3(-0.5, 0, 0.6)
		"rico":
			M3.cylinder(extras, 0.24, 0.24, 0.42, Vector3(0, 0.68, 0), M3.solid(Color("111111"), 0.3))
			M3.cylinder(extras, 0.4, 0.4, 0.04, Vector3(0, 0.48, 0), M3.solid(Color("111111"), 0.3))
			M3.cylinder(extras, 0.245, 0.245, 0.08, Vector3(0, 0.53, 0), M3.solid(Color("c0392b")))
			var mono := M3.torus(extras, 0.07, 0.095, Vector3(0.14, 0.2, 0.36), M3.solid(Color("ffd700"), 0.2, 0.9))
			mono.rotation.x = PI / 2
			for sx in [-1.0, 1.0]:
				var m := M3.sphere(extras, 0.08, Vector3(0.07 * sx, 0.05, 0.36), M3.solid(Color("3b2412")), 10)
				m.scale = Vector3(1.4, 0.5, 0.6)
			# gravata borboleta (no corpo)
			for sx in [-1.0, 1.0]:
				var b := M3.sphere(body, 0.08, Vector3(0.08 * sx, 1.18, 0.36), M3.solid(Color("c0392b")), 10)
				b.scale = Vector3(1.2, 0.8, 0.5)
		"trapaceiro":
			# chapéu fedora com uma carta e óculos escuros
			M3.cylinder(extras, 0.28, 0.32, 0.24, Vector3(0, 0.56, 0), M3.solid(Color("2c1745")))
			M3.cylinder(extras, 0.46, 0.46, 0.03, Vector3(0, 0.45, 0), M3.solid(Color("2c1745")))
			var card := M3.box(extras, Vector3(0.14, 0.2, 0.01), Vector3(0.2, 0.66, 0.1), M3.solid(Color.WHITE))
			card.rotation.z = -0.4
			M3.label(card, "A", Vector3(0, 0, 0.01), 16, Color("c0392b"), 0)
			M3.box(extras, Vector3(0.52, 0.11, 0.04), Vector3(0, 0.21, 0.4), M3.solid(Color("050505"), 0.1, 0.5))
			var stache := M3.box(extras, Vector3(0.2, 0.025, 0.02), Vector3(0, 0.05, 0.38), dark)
			stache.rotation.z = 0.05
		"apostador":
			# viseira verde e dado na mão
			var visor := M3.cylinder(extras, 0.42, 0.42, 0.03, Vector3(0, 0.36, 0.18), M3.glow(Color("1abc9c"), 0.6))
			visor.scale = Vector3(1.0, 1.0, 0.6)
			M3.torus(extras, 0.36, 0.41, Vector3(0, 0.36, 0), M3.solid(Color("16a085")))
			var die := M3.box(arm_r, Vector3(0.16, 0.16, 0.16), Vector3(0.14, -0.6, 0.06), M3.solid(Color.WHITE, 0.3))
			die.rotation = Vector3(0.4, 0.6, 0.2)
			die.name = "Die"
			M3.sphere(die, 0.025, Vector3(0, 0, 0.081), dark, 8)
		"genio":
			# óculos redondos e lâmpada
			for sx in [-0.14, 0.14]:
				var g := M3.torus(extras, 0.1, 0.125, Vector3(sx, 0.2, 0.37), M3.solid(Color("222222"), 0.3, 0.5))
				g.rotation.x = PI / 2
			var bulb := Node3D.new()
			bulb.name = "Bulb"
			bulb.position = Vector3(0, 0.95, 0)
			extras.add_child(bulb)
			M3.sphere(bulb, 0.13, Vector3(0, 0.05, 0), M3.glow(Color("fff27a"), 2.5), 14)
			M3.cylinder(bulb, 0.06, 0.06, 0.1, Vector3(0, -0.1, 0), M3.solid(Color("aaaaaa"), 0.3, 0.8), 10)
		"medroso":
			# gota de suor e sobrancelhas preocupadas
			var drop := M3.sphere(extras, 0.06, Vector3(0.36, 0.38, 0.12), M3.glow(Color("8fd3ff"), 0.8), 10)
			drop.scale = Vector3(0.8, 1.3, 0.8)
			for sx in [-1.0, 1.0]:
				var brow := M3.box(extras, Vector3(0.12, 0.025, 0.02), Vector3(0.14 * sx, 0.38, 0.33), dark)
				brow.rotation.z = -0.35 * sx
		"maluco":
			# cabelo espetado multicolorido e língua de fora
			var cols := [Color("ff2e88"), Color("27e1ff"), Color("ffcc33"), Color("3ddc97"), Color("b072ff")]
			for i in 9:
				var ang := -1.2 + i * 0.3
				var spike := M3.cylinder(extras, 0.0, 0.09, 0.38, Vector3(sin(ang) * 0.28, 0.5 + cos(ang) * 0.1, -0.05), M3.solid(cols[i % cols.size()]), 8)
				spike.rotation.z = -ang * 0.9
			var tongue := M3.sphere(extras, 0.06, Vector3(0.05, -0.08, 0.37), M3.solid(Color("ff6b8b")), 10)
			tongue.scale = Vector3(1.0, 1.4, 0.6)


## Animações: idle, celebrate, sad, shock, think, wave
func play(anim: String) -> void:
	_anim = anim
	_anim_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	var bob := sin(_t * 2.2 + _phase) * 0.03
	var tremble := 0.0
	if character == "medroso":
		tremble = sin(_t * 40.0) * 0.012
	body.position = Vector3(tremble, bob, 0)
	body.rotation = Vector3.ZERO
	head.rotation = Vector3(0, sin(_t * 0.7 + _phase) * 0.15, 0)
	var arm_up := 0.0
	var sq := 1.0
	match _anim:
		"celebrate":
			body.position.y += absf(sin(_anim_t * 9.0)) * 0.35
			body.rotation.y = sin(_anim_t * 4.0) * 0.4
			arm_up = 2.6 + sin(_anim_t * 18.0) * 0.3
			if _anim_t > 2.5:
				_anim = "idle"
		"sad":
			head.rotation.x = 0.45
			head.rotation.y = sin(_anim_t * 5.0) * 0.25
			sq = 0.93
			arm_up = -0.1
			if _anim_t > 2.6:
				_anim = "idle"
		"shock":
			sq = 1.0 + sin(minf(_anim_t * 10.0, PI)) * 0.15
			arm_up = 1.4
			head.rotation.x = -0.25
			if _anim_t > 1.2:
				_anim = "idle"
		"think":
			head.rotation.z = 0.25
			arm_r.rotation.x = -1.4
			if _anim_t > 2.5:
				_anim = "idle"
		"wave":
			arm_up = 0.0
			arm_r.rotation.z = 2.4 + sin(_anim_t * 12.0) * 0.4
			if _anim_t > 1.6:
				_anim = "idle"
	body.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq))
	if _anim != "wave" and _anim != "think":
		var swing := sin(_t * 2.2 + _phase) * 0.08
		arm_l.rotation = Vector3(swing, 0, -(0.15 + arm_up))
		arm_r.rotation = Vector3(-swing, 0, 0.15 + arm_up)
	elif _anim == "think":
		arm_l.rotation = Vector3(0, 0, -0.15)
	if character == "azarado":
		var cloud := extras.get_node_or_null("Cloud")
		if cloud:
			cloud.position.x = sin(_t * 1.3) * 0.08
			for i in 4:
				var d := cloud.get_node_or_null("Drop%d" % i) as Node3D
				if d:
					d.position.y = -0.2 - fmod(_t * 1.2 + i * 0.27, 0.6)
	elif character == "genio":
		var bulb := extras.get_node_or_null("Bulb") as Node3D
		if bulb:
			bulb.position.y = 0.95 + sin(_t * 3.0) * 0.04
			bulb.scale = Vector3.ONE * (1.0 + (0.25 if _anim == "celebrate" or _anim == "think" else 0.0))
	elif character == "maluco":
		extras.rotation.z = sin(_t * 6.0) * 0.08
