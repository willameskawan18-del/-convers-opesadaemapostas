class_name Arena
extends Node3D
## THE ALL WIN ARENA — estúdio de game show montado proceduralmente:
## palco principal, plataforma central, púlpitos dos jogadores, telão, painel de dinheiro,
## área VIP, arquibancadas com plateia, portas dos desafios e iluminação de espetáculo.

const MOODS := {
	"normal": [Color("ff2e88"), Color("27e1ff"), Color("b072ff"), Color("ffcc33")],
	"allwin": [Color("ff1a1a"), Color("ffcc33"), Color("ff6a00"), Color("ffcc33")],
	"win": [Color("ffcc33"), Color("3ddc97"), Color("ffffff"), Color("ffcc33")],
	"lose": [Color("3a4cff"), Color("6b2cff"), Color("2a2a8a"), Color("3a4cff")],
	"menu": [Color("ff2e88"), Color("27e1ff"), Color("ffcc33"), Color("b072ff")],
}

var camera: CameraDirector
var env: Environment
var podiums: Dictionary = {}     # pid -> Podium
var podium_root: Node3D
var doors_root: Node3D
var doors: Array = []            # [{pivot, prize_lbl, letter, picks_lbl}]
var screen_title: Label
var screen_text: Label
var screen_bg: ColorRect
var board_rows: Array[Label3D] = []
var spots: Array = []            # [{light, beam, base_rot, speed, phase}]
var crowd_mat: ShaderMaterial
var chaser_mat: ShaderMaterial
var floor_mat: ShaderMaterial
var center_ring: MeshInstance3D
var confetti: CPUParticles3D
var sparks: Array[CPUParticles3D] = []
var mood := "normal"
var _mood_cols: Array = MOODS.normal
var _t := 0.0
var _crowd_energy := 0.3
var _key: DirectionalLight3D


func _ready() -> void:
	_build_environment()
	_build_stage()
	_build_screen()
	_build_board()
	_build_vip()
	_build_crowd()
	_build_lights()
	_build_doors()
	_build_fx()
	podium_root = Node3D.new()
	add_child(podium_root)
	camera = CameraDirector.new()
	camera.arena = self
	add_child(camera)
	camera.make_current()
	set_mood("menu")


# --- Construção ------------------------------------------------------------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07020f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a3a8a")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.fog_enabled = true
	env.fog_light_color = Color("1a0730")
	env.fog_density = 0.008
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.8, 0.75, 1.0)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	_key = DirectionalLight3D.new()
	_key.rotation = Vector3(deg_to_rad(-55), deg_to_rad(20), 0)
	_key.light_energy = 0.35
	_key.light_color = Color("c9b8ff")
	_key.shadow_enabled = true
	add_child(_key)


func _build_stage() -> void:
	# piso brilhante do estúdio
	var fl := PlaneMesh.new()
	fl.size = Vector2(80, 80)
	var floor_mi := M3.mesh(self, fl, Vector3.ZERO, M3.solid(Color("0b0518"), 0.12, 0.5, false))
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# palco principal (meia-lua) com LED animado
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = load("res://scripts/arena/led_floor.gdshader")
	var stage := M3.cylinder(self, 13.0, 13.4, 0.4, Vector3(0, 0.2, -4), floor_mat, 64)
	stage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	M3.torus(self, 13.2, 13.5, Vector3(0, 0.38, -4), M3.glow(AW.PINK, 2.5))
	# plataforma central
	M3.cylinder(self, 3.2, 3.4, 0.5, Vector3(0, 0.6, 1.5), M3.solid(Color("1d0b40"), 0.2, 0.7), 48)
	center_ring = M3.torus(self, 3.15, 3.35, Vector3(0, 0.86, 1.5), M3.glow(AW.GOLD, 3.0))
	M3.torus(self, 2.2, 2.3, Vector3(0, 0.86, 1.5), M3.glow(AW.CYAN, 2.0))
	# escadas na frente do palco
	for i in 3:
		M3.box(self, Vector3(6.0 - i * 0.6, 0.13, 0.6), Vector3(0, 0.07 + i * 0.13, 9.6 - i * 0.55), M3.solid(Color("1d0b40"), 0.25, 0.5))
	# paredes de fundo com painéis e colunas de luz
	var wall_mat := M3.solid(Color("140728"), 0.6)
	M3.box(self, Vector3(60, 22, 1), Vector3(0, 11, -22), wall_mat)
	for i in 12:
		var x := -27.5 + i * 5.0
		if absf(x) < 11.0:
			continue
		M3.box(self, Vector3(0.25, 16, 0.2), Vector3(x, 8, -21.4), M3.glow([AW.PINK, AW.CYAN, AW.PURPLE][i % 3], 2.0), false)
	# arco de treliça sobre o palco
	var truss := M3.solid(Color("777788"), 0.35, 0.9)
	for sx in [-1.0, 1.0]:
		M3.box(self, Vector3(0.5, 14, 0.5), Vector3(14.5 * sx, 7, -4), truss)
	M3.box(self, Vector3(29.5, 0.5, 0.5), Vector3(0, 14, -4), truss)
	M3.box(self, Vector3(29.5, 0.5, 0.5), Vector3(0, 14, 2), truss)
	for sx in [-1.0, 1.0]:
		M3.box(self, Vector3(0.5, 0.5, 6.5), Vector3(14.5 * sx, 14, -1), truss)


func _build_screen() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 448)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	screen_bg = ColorRect.new()
	screen_bg.color = Color("1d0b40")
	screen_bg.size = Vector2(1024, 448)
	vp.add_child(screen_bg)
	var v := AW.vbox(4)
	v.size = Vector2(1024, 448)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	vp.add_child(v)
	screen_title = AW.title("ALL WIN", 120)
	screen_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(screen_title)
	screen_text = AW.label("THE ALL WIN ARENA", 44, AW.TEXT, "Bold", 6)
	screen_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_text.custom_minimum_size.x = 980
	v.add_child(screen_text)
	var quad := QuadMesh.new()
	quad.size = Vector2(18.0, 7.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vp.get_texture()
	mat.emission_enabled = true
	mat.emission_texture = vp.get_texture()
	mat.emission_energy_multiplier = 0.6
	var scr := M3.mesh(self, quad, Vector3(0, 8.6, -15.9), mat, false)
	scr.name = "Screen"
	# moldura com lâmpadas
	M3.box(self, Vector3(18.8, 8.7, 0.4), Vector3(0, 8.6, -16.15), M3.solid(Color("0a0414"), 0.3, 0.6))
	_bulb_frame(Vector3(0, 8.6, -15.85), 19.2, 8.9)
	# suportes
	for sx in [-1.0, 1.0]:
		M3.box(self, Vector3(0.6, 4.4, 0.6), Vector3(7.5 * sx, 2.2, -16.2), M3.solid(Color("2a1257"), 0.3, 0.6))


func _bulb_frame(center: Vector3, w: float, h: float) -> void:
	chaser_mat = ShaderMaterial.new()
	chaser_mat.shader = load("res://scripts/arena/chaser.gdshader")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 8
	sm.rings = 4
	mm.mesh = sm
	var pts: Array[Vector3] = []
	var step := 0.6
	var nx := int(w / step)
	var ny := int(h / step)
	for i in nx:
		pts.append(center + Vector3(-w / 2 + i * step, h / 2, 0))
	for i in ny:
		pts.append(center + Vector3(w / 2, h / 2 - i * step, 0))
	for i in nx:
		pts.append(center + Vector3(w / 2 - i * step, -h / 2, 0))
	for i in ny:
		pts.append(center + Vector3(-w / 2, -h / 2 + i * step, 0))
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = chaser_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_board() -> void:
	# painel de dinheiro (LED) à direita do palco
	var root := Node3D.new()
	root.position = Vector3(17.5, 0, -9)
	root.rotation.y = deg_to_rad(-35)
	add_child(root)
	M3.box(root, Vector3(5.2, 9.0, 0.4), Vector3(0, 5.2, 0), M3.solid(Color("0a0414"), 0.3, 0.5))
	M3.box(root, Vector3(5.4, 0.12, 0.45), Vector3(0, 9.75, 0), M3.glow(AW.GOLD, 3.0), false)
	M3.box(root, Vector3(5.4, 0.12, 0.45), Vector3(0, 0.65, 0), M3.glow(AW.GOLD, 3.0), false)
	M3.label(root, "PLACAR", Vector3(0, 9.1, 0.25), 70, AW.GOLD, 12)
	for i in 8:
		var l := M3.label(root, "", Vector3(0, 8.1 - i * 0.92, 0.25), 40, Color.WHITE, 8)
		board_rows.append(l)
	M3.box(root, Vector3(1.0, 0.8, 1.0), Vector3(0, 0.4, 0), M3.solid(Color("2a1257"), 0.3, 0.6))


func _build_vip() -> void:
	# camarote VIP à esquerda, elevado, com sofás e corrimão dourado
	var root := Node3D.new()
	root.position = Vector3(-19, 0, -10)
	root.rotation.y = deg_to_rad(35)
	add_child(root)
	M3.box(root, Vector3(9, 3.0, 6), Vector3(0, 1.5, 0), M3.solid(Color("1d0b40"), 0.4, 0.3))
	M3.box(root, Vector3(9, 0.15, 6), Vector3(0, 3.05, 0), M3.solid(Color("4a1a2a"), 0.8))
	var gold := M3.solid(Color("ffcc33"), 0.2, 0.9)
	M3.box(root, Vector3(9, 0.1, 0.1), Vector3(0, 4.1, 3.0), gold)
	for i in 10:
		M3.box(root, Vector3(0.06, 1.0, 0.06), Vector3(-4.5 + i, 3.6, 3.0), gold)
	for i in 3:
		var sofa := M3.box(root, Vector3(2.2, 0.6, 0.9), Vector3(-3 + i * 3, 3.45, -1.0), M3.solid(Color("8e1b3a"), 0.7))
		M3.box(sofa, Vector3(2.2, 0.7, 0.25), Vector3(0, 0.45, -0.35), M3.solid(Color("8e1b3a"), 0.7))
	M3.label(root, "VIP", Vector3(0, 6.2, -2.5), 220, AW.GOLD, 20)
	M3.box(root, Vector3(4.5, 0.08, 0.1), Vector3(0, 5.0, -2.5), M3.glow(AW.PINK, 3.0), false)
	# convidados VIP
	for i in 3:
		var guest := CharacterModel.create(["rico", "trapaceiro", "sortudo"][i])
		guest.position = Vector3(-3 + i * 3, 3.3, -0.5)
		guest.scale = Vector3.ONE * 0.8
		root.add_child(guest)


func _build_crowd() -> void:
	crowd_mat = ShaderMaterial.new()
	crowd_mat.shader = load("res://scripts/arena/crowd.gdshader")
	var bench_mat := M3.solid(Color("1a0b33"), 0.5, 0.2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.1
	cap.radial_segments = 10
	cap.rings = 4
	mm.mesh = cap
	var xforms: Array[Transform3D] = []
	var cols: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var palette := [Color("ff2e88"), Color("27e1ff"), Color("ffcc33"), Color("3ddc97"), Color("b072ff"), Color("ff9f1c"), Color("f2f2f2"), Color("e74c3c")]
	for side in [-1.0, 1.0]:
		for row in 6:
			var x: float = side * (19.0 + row * 1.4)
			var y: float = 0.4 + row * 0.8
			M3.box(self, Vector3(1.4, 0.8 + row * 0.8, 26), Vector3(x, y / 2.0, 4), bench_mat)
			for k in 22:
				if rng.randf() < 0.12:
					continue
				var z := -7.0 + k * 1.05 + rng.randf_range(-0.15, 0.15)
				var basis := Basis(Vector3.UP, side * PI / 2.0 * -1.0)
				xforms.append(Transform3D(basis, Vector3(x, y + 0.85, z)))
				cols.append(palette[rng.randi_range(0, palette.size() - 1)].darkened(rng.randf() * 0.35))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = crowd_mat
	add_child(mmi)
	# plateia na frente (de costas para a câmera, embaixo do palco)
	var front := MultiMesh.new()
	front.transform_format = MultiMesh.TRANSFORM_3D
	front.use_colors = true
	front.mesh = cap
	var fx: Array[Transform3D] = []
	for row in 2:
		for k in 16:
			if absf(k - 7.5) < 2.5:
				continue
			fx.append(Transform3D(Basis(), Vector3(-15.0 + k * 2.0 + rng.randf_range(-0.3, 0.3), 0.75, 14.0 + row * 1.6)))
	front.instance_count = fx.size()
	for i in fx.size():
		front.set_instance_transform(i, fx[i])
		front.set_instance_color(i, palette[rng.randi_range(0, palette.size() - 1)].darkened(0.5))
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = front
	fmi.material_override = crowd_mat
	add_child(fmi)


func _build_lights() -> void:
	var cols: Array = MOODS.normal
	for i in 8:
		var x := -12.6 + i * 3.6
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 13.6, -1.0 if i % 2 == 0 else -4.0)
		add_child(pivot)
		M3.cylinder(pivot, 0.3, 0.35, 0.6, Vector3(0, 0.1, 0), M3.solid(Color("222222"), 0.3, 0.8), 12)
		var sl := SpotLight3D.new()
		sl.spot_range = 22.0
		sl.spot_angle = 14.0
		sl.light_energy = 18.0
		sl.light_volumetric_fog_energy = 1.5
		sl.shadow_enabled = i % 3 == 0
		sl.rotation.x = -PI / 2
		pivot.add_child(sl)
		var beam_mat := M3.beam(cols[i % cols.size()], 0.07)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.18
		cone.bottom_radius = 3.6
		cone.height = 14.0
		cone.radial_segments = 16
		cone.cap_top = false
		cone.cap_bottom = false
		var beam := M3.mesh(pivot, cone, Vector3(0, -7.0, 0), beam_mat, false)
		spots.append({"pivot": pivot, "light": sl, "beam": beam, "mat": beam_mat, "phase": i * 0.8, "speed": 0.5 + (i % 3) * 0.2})
	# luz de frente (para os rostos)
	var front := SpotLight3D.new()
	front.position = Vector3(0, 9, 16)
	front.spot_range = 40.0
	front.spot_angle = 35.0
	front.light_energy = 6.0
	front.light_color = Color("fff1e0")
	add_child(front)
	front.look_at(Vector3(0, 1.5, -4))
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 6, -10)
	fill.omni_range = 18.0
	fill.light_energy = 2.5
	fill.light_color = Color("ff2e88")
	add_child(fill)


func _build_doors() -> void:
	doors_root = Node3D.new()
	doors_root.position = Vector3(0, -6, 1.5)
	doors_root.visible = false
	add_child(doors_root)
	var cols := [Color("ff4d6d"), Color("4dabf7"), Color("ffd43b")]
	for i in 3:
		var x := (i - 1) * 2.3
		var frame := Node3D.new()
		frame.position = Vector3(x, 0.85, 0)
		doors_root.add_child(frame)
		var fm := M3.solid(Color("ffcc33"), 0.25, 0.85)
		M3.box(frame, Vector3(0.18, 3.2, 0.3), Vector3(-0.95, 1.6, 0), fm)
		M3.box(frame, Vector3(0.18, 3.2, 0.3), Vector3(0.95, 1.6, 0), fm)
		M3.box(frame, Vector3(2.08, 0.2, 0.3), Vector3(0, 3.2, 0), fm)
		# interior (brilha com a cor do prêmio)
		var inside := M3.box(frame, Vector3(1.7, 3.0, 0.05), Vector3(0, 1.55, -0.12), M3.glow(Color("222222"), 0.5), false)
		var prize := M3.label(frame, "", Vector3(0, 1.7, -0.05), 110, Color.WHITE, 16)
		prize.visible = false
		var pivot := Node3D.new()
		pivot.position = Vector3(-0.85, 0, 0.02)
		frame.add_child(pivot)
		M3.box(pivot, Vector3(1.7, 3.05, 0.12), Vector3(0.85, 1.55, 0), M3.solid(cols[i], 0.35, 0.2))
		M3.sphere(pivot, 0.08, Vector3(1.5, 1.5, 0.1), M3.solid(Color("ffcc33"), 0.2, 0.9), 10)
		M3.label(pivot, ["A", "B", "C"][i], Vector3(0.85, 1.9, 0.08), 160, Color.WHITE, 18)
		var picks := M3.label(frame, "", Vector3(0, 3.75, 0.2), 30, Color.WHITE, 8, true)
		doors.append({"frame": frame, "pivot": pivot, "prize": prize, "inside": inside, "picks": picks, "color": cols[i]})


func _build_fx() -> void:
	confetti = CPUParticles3D.new()
	confetti.position = Vector3(0, 13, -1)
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 400
	confetti.lifetime = 5.0
	confetti.explosiveness = 0.8
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(13, 0.5, 6)
	confetti.direction = Vector3(0, -1, 0)
	confetti.spread = 30.0
	confetti.initial_velocity_min = 1.0
	confetti.initial_velocity_max = 4.0
	confetti.gravity = Vector3(0, -2.5, 0)
	confetti.angular_velocity_min = -400
	confetti.angular_velocity_max = 400
	confetti.damping_min = 0.5
	confetti.damping_max = 1.5
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.2)
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.emission_enabled = true
	cm.emission_energy_multiplier = 0.4
	cm.emission = Color(0.3, 0.3, 0.3)
	q.material = cm
	confetti.mesh = q
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	grad.colors = PackedColorArray([AW.PINK, AW.GOLD, AW.CYAN, AW.GREEN, AW.PURPLE, AW.ORANGE])
	confetti.color_initial_ramp = grad
	add_child(confetti)
	for sx in [-1.0, 1.0]:
		var sp := CPUParticles3D.new()
		sp.position = Vector3(11.5 * sx, 0.5, -1)
		sp.emitting = false
		sp.one_shot = true
		sp.amount = 160
		sp.lifetime = 1.6
		sp.explosiveness = 0.3
		sp.direction = Vector3(0, 1, 0)
		sp.spread = 8.0
		sp.initial_velocity_min = 10.0
		sp.initial_velocity_max = 15.0
		sp.gravity = Vector3(0, -6, 0)
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		sm.radial_segments = 4
		sm.rings = 2
		sm.material = M3.glow(Color("ffcc33"), 6.0)
		sp.mesh = sm
		add_child(sp)
		sparks.append(sp)


# --- Jogadores -------------------------------------------------------------------

func podium_position(i: int, n: int) -> Vector3:
	var spread := minf(22.0, 3.0 * maxf(n - 1, 1))
	var x := 0.0 if n <= 1 else -spread / 2.0 + spread * i / float(n - 1)
	var z := -6.5 + 0.035 * x * x
	return Vector3(x, 0.4, z)


## Recria/atualiza os púlpitos para a lista de jogadores (sem recriar quem não mudou).
func sync_players(players: Array) -> void:
	var ids := players.map(func(p): return int(p.id))
	for pid in podiums.keys():
		if not ids.has(pid):
			podiums[pid].queue_free()
			podiums.erase(pid)
	for i in players.size():
		var p: Dictionary = players[i]
		var pid := int(p.id)
		var pod: Podium = podiums.get(pid)
		if pod and pod.model.character != str(p.character):
			pod.queue_free()
			podiums.erase(pid)
			pod = null
		if pod == null:
			pod = Podium.new()
			podium_root.add_child(pod)
			pod.setup(p)
			podiums[pid] = pod
			pod.model.play("wave")
		pod.position = podium_position(i, players.size())
		pod.look_at(Vector3(pod.position.x * 0.4, pod.position.y, 18.0), Vector3.UP, true)
		pod.set_money(int(p.money))
	_update_board(players)


func _update_board(players: Array) -> void:
	var r := players.duplicate()
	r.sort_custom(func(a, b): return int(a.money) > int(b.money))
	for i in board_rows.size():
		if i < r.size():
			board_rows[i].text = "%dº %s  %s" % [i + 1, str(r[i].name).substr(0, 10), Fmt.money(int(r[i].money))]
			board_rows[i].modulate = AW.place_color(i + 1) if i < 3 else Color.WHITE
		else:
			board_rows[i].text = ""


func refresh_places(players: Array) -> void:
	for p in players:
		var pod: Podium = podiums.get(int(p.id))
		if pod:
			var pos := 1
			for o in players:
				if int(o.money) > int(p.money):
					pos += 1
			pod.set_place(pos)
	_update_board(players)


func clear_places() -> void:
	for pod in podiums.values():
		pod.set_place(0)


func podium(pid: int) -> Podium:
	return podiums.get(pid)


func set_all_tags(text: String, col: Color = Color.WHITE) -> void:
	for pod in podiums.values():
		pod.set_tag(text, col)


func highlight_only(pid: int, col: Color = AW.GOLD) -> void:
	for k in podiums:
		podiums[k].highlight(k == pid, col)


func animate(pid: int, anim: String) -> void:
	var pod: Podium = podiums.get(pid)
	if pod:
		pod.model.play(anim)


func animate_all(anim: String) -> void:
	for pod in podiums.values():
		pod.model.play(anim)


# --- Telão -----------------------------------------------------------------------

func screen(title_text: String, sub: String = "", col: Color = AW.PANEL) -> void:
	screen_title.text = title_text
	screen_text.text = sub
	screen_bg.color = col.darkened(0.55)
	var size := 120
	if title_text.length() > 12:
		size = 90
	if title_text.length() > 18:
		size = 70
	screen_title.add_theme_font_size_override("font_size", size)


# --- Portas ----------------------------------------------------------------------

func show_doors(on: bool) -> void:
	if on == doors_root.visible and (not on or doors_root.position.y > -0.1):
		return
	var tw := create_tween()
	if on:
		for d in doors:
			d.pivot.rotation.y = 0.0
			d.prize.visible = false
			d.picks.text = ""
			d.inside.material_override = M3.glow(Color("222222"), 0.5)
		doors_root.visible = true
		doors_root.position.y = -6.0
		tw.tween_property(doors_root, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(doors_root, "position:y", -6.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): doors_root.visible = false)


func set_door_picks(idx: int, text: String) -> void:
	doors[idx].picks.text = text


func open_door(idx: int, mult: float) -> void:
	var d: Dictionary = doors[idx]
	var col := AW.RED if mult <= 0.0 else (AW.GOLD if mult >= 5.0 else AW.GREEN)
	d.prize.text = Fmt.mult(mult)
	d.prize.modulate = col
	d.prize.visible = true
	d.inside.material_override = M3.glow(col, 2.5)
	var tw := create_tween()
	tw.tween_property(d.pivot, "rotation:y", -1.9, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	d.prize.scale = Vector3.ONE * 0.2
	create_tween().tween_property(d.prize, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- Clima / efeitos -------------------------------------------------------------

func set_mood(m: String) -> void:
	mood = m
	_mood_cols = MOODS.get(m, MOODS.normal)
	for i in spots.size():
		var c: Color = _mood_cols[i % _mood_cols.size()]
		spots[i].light.light_color = c
		spots[i].mat.albedo_color = Color(c, 0.09 if m != "allwin" else 0.13)
	env.ambient_light_energy = 0.25 if m == "allwin" else 0.55
	env.ambient_light_color = Color("7a1a1a") if m == "allwin" else Color("5a3a8a")
	if floor_mat:
		floor_mat.set_shader_parameter("color_a", _mood_cols[0])
		floor_mat.set_shader_parameter("color_b", _mood_cols[1])
	if chaser_mat:
		chaser_mat.set_shader_parameter("color_a", _mood_cols[3])
		chaser_mat.set_shader_parameter("color_b", _mood_cols[0])


func celebrate(big: bool = false) -> void:
	confetti.amount = 600 if big else 260
	confetti.restart()
	confetti.emitting = true
	_crowd_energy = 1.0
	if big:
		for s in sparks:
			s.restart()
			s.emitting = true
		camera.shake(0.35)


func boo() -> void:
	_crowd_energy = 0.6


func flash(col: Color = Color.WHITE) -> void:
	env.adjustment_brightness = 1.6
	var tw := create_tween()
	tw.tween_property(env, "adjustment_brightness", 1.0, 0.5)
	if col != Color.WHITE:
		pass


func _process(delta: float) -> void:
	_t += delta
	var speed := 0.35 if mood == "allwin" else 0.8
	for s in spots:
		var p: Node3D = s.pivot
		var ph: float = s.phase
		p.rotation = Vector3(sin(_t * speed * s.speed + ph) * 0.45, 0, cos(_t * speed * 0.8 * s.speed + ph * 1.3) * 0.4)
	_crowd_energy = move_toward(_crowd_energy, 0.25, delta * 0.25)
	if crowd_mat:
		crowd_mat.set_shader_parameter("energy", _crowd_energy)
	center_ring.rotation.y += delta * 0.6
