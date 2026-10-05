class_name World
extends Node3D
## Monta o mundo: céu noturno, névoa, mar, porto com farol e peixaria, boias das zonas,
## o barco e as criaturas. Aplica o estado enviado pelo host.

var env: Environment
var sky_mat: ShaderMaterial
var ocean: Ocean
var boat: Boat
var creatures: Creatures
var lighthouse_beam: Node3D
var _state: Dictionary = {}
var _boat_pos := Vector3(0, 0, 18)
var _boat_yaw := 0.0
var _depth := 0.0


func _ready() -> void:
	_environment()
	ocean = Ocean.new()
	add_child(ocean)
	_dock()
	_buoys()
	boat = Boat.new()
	add_child(boat)
	creatures = Creatures.new()
	creatures.boat = boat
	add_child(creatures)
	Game.world_state.connect(func(s): _state = s)
	Game.run_changed.connect(_on_run)
	Game.fx.connect(_on_fx)


func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://scripts/world/sky.gdshader")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4a6a")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("0a1424")
	env.fog_density = 0.01
	env.fog_sky_affect = 0.6
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(deg_to_rad(-30), deg_to_rad(150), 0)
	moon.light_color = Color("a9c0ff")
	moon.light_energy = 0.4
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)


func _dock() -> void:
	var wood := M3.solid(Color("6b4a2b"), 0.85)
	var post := M3.solid(Color("4a3220"), 0.9)
	# píer
	M3.box(self, Vector3(4, 0.3, 26), Vector3(-4.5, 1.2, 4), wood)
	for z in range(-8, 17, 4):
		for x in [-6.3, -2.7]:
			M3.cylinder(self, 0.2, 0.22, 4.0, Vector3(x, -0.6, z), post, 8)
	# peixaria
	M3.box(self, Vector3(9, 4, 7), Vector3(-10, 3.3, -6), M3.solid(Color("2e6b8a"), 0.7))
	M3.box(self, Vector3(9.6, 0.4, 7.6), Vector3(-10, 5.5, -6), M3.solid(Color("b0302a"), 0.6))
	M3.box(self, Vector3(12, 1.3, 12), Vector3(-10, 0.65, -6), M3.solid(Color("3a3f45"), 0.9))
	M3.label(self, "PEIXARIA DO PORTO", Vector3(-10, 4.8, -2.4), 70, Color("27e1ff"), 10)
	M3.box(self, Vector3(4.6, 0.12, 0.1), Vector3(-10, 4.25, -2.45), M3.glow(Color("27e1ff"), 3.0), false)
	for x in [-13.0, -7.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 4.0, -1.6)
		lamp.light_color = Color("ffb04a")
		lamp.light_energy = 2.5
		lamp.omni_range = 14
		add_child(lamp)
	for z in [0.0, 8.0, 15.0]:
		M3.cylinder(self, 0.05, 0.06, 3.0, Vector3(-6.2, 2.8, z), M3.solid(Color("555555"), 0.5, 0.6), 6)
		M3.sphere(self, 0.15, Vector3(-6.2, 4.3, z), M3.glow(Color("ffd27a"), 3.0), 8)
		var l := OmniLight3D.new()
		l.position = Vector3(-6.2, 4.2, z)
		l.light_color = Color("ffd27a")
		l.light_energy = 1.5
		l.omni_range = 9
		add_child(l)
	# farol
	var lh := Node3D.new()
	lh.position = Vector3(-24, 0, -16)
	add_child(lh)
	M3.cylinder(lh, 2.5, 3.5, 2.0, Vector3(0, 0.5, 0), M3.solid(Color("4a4f55"), 0.9), 16)
	for i in 5:
		M3.cylinder(lh, 1.4 - i * 0.08, 1.48 - i * 0.08, 2.4, Vector3(0, 2.6 + i * 2.4, 0), M3.solid(Color("f2f2f2") if i % 2 == 0 else Color("c0392b"), 0.6), 16)
	M3.sphere(lh, 0.8, Vector3(0, 15.0, 0), M3.glow(Color("fff2c0"), 4.0), 12)
	lighthouse_beam = Node3D.new()
	lighthouse_beam.position = Vector3(0, 15.0, 0)
	lh.add_child(lighthouse_beam)
	var beam := CylinderMesh.new()
	beam.top_radius = 0.6
	beam.bottom_radius = 7.0
	beam.height = 70.0
	beam.cap_top = false
	beam.cap_bottom = false
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(1.0, 0.95, 0.75, 0.06)
	var bmi := M3.mesh(lighthouse_beam, beam, Vector3(0, 0, 35), bm, false)
	bmi.rotation.x = PI / 2
	var sl := SpotLight3D.new()
	sl.spot_range = 120
	sl.spot_angle = 6
	sl.light_energy = 8
	sl.light_color = Color("fff2c0")
	sl.rotation.y = PI
	lighthouse_beam.add_child(sl)


func _buoys() -> void:
	var zones := [[140.0, Color("ff4d6d"), "MAR FUNDO"], [320.0, Color("b072ff"), "O ABISMO"]]
	for z in zones:
		var r: float = z[0]
		for i in 16:
			var a := TAU * i / 16.0
			var b := Node3D.new()
			b.position = Vector3(cos(a) * r, 0, sin(a) * r)
			add_child(b)
			M3.cylinder(b, 0.25, 0.6, 1.4, Vector3(0, 0.3, 0), M3.solid(z[1], 0.5), 10)
			M3.sphere(b, 0.18, Vector3(0, 1.2, 0), M3.glow(z[1], 4.0), 8)
			if i % 4 == 0:
				M3.label(b, str(z[2]), Vector3(0, 2.4, 0), 64, z[1], 12, true)
			b.set_meta("bob", randf() * TAU)
			b.add_to_group("buoys")


func _on_run(r: Dictionary) -> void:
	boat.set_lantern(bool(r.get("lantern", true)))
	_depth = {"raso": 0.0, "fundo": 0.55, "abismo": 1.0}.get(str(r.get("zone_id", "raso")), 0.0)


func _on_fx(kind: String, data: Dictionary) -> void:
	match kind:
		"thump":
			boat.shake(1.0)
			Audio.play("thump")
		"tentacle_rise":
			creatures.tentacle_rise(float(data.get("side", 1.0)))
			Audio.play("roar")
		"tentacle_hit":
			creatures.tentacle_hit()
			Audio.play("door")
		"tentacle_gone":
			creatures.tentacle_down()
		"tentacle_smash":
			boat.shake(2.0)
			creatures.tentacle_down()
			Audio.play("thump")
			Audio.play("roar")
		"eyes":
			creatures.show_eyes(float(data.get("angle", 0.0)))
			Audio.play("suspense")
		"eyes_gone":
			creatures.hide_eyes()
		"leviathan":
			creatures.hide_eyes()
			boat.shake(2.5)
			Audio.play("roar")
			Audio.play("thump")
		"sink":
			Audio.play("lose")


func _process(delta: float) -> void:
	if not _state.is_empty():
		var tp: Vector3 = _state.pos
		_boat_pos = _boat_pos.lerp(tp, minf(1.0, delta * 10.0)) if _boat_pos.distance_to(tp) < 20.0 else tp
		_boat_yaw = lerp_angle(_boat_yaw, float(_state.yaw), minf(1.0, delta * 10.0))
		boat.sync_leaks(_state.get("leaks", []))
		boat.set_engine(absf(float(_state.get("speed", 0.0))) > 0.5)
	boat.place(_boat_pos, _boat_yaw, delta)
	ocean.follow(boat.global_position)
	var cur := float(ocean.mat.get_shader_parameter("depth")) if ocean.mat.get_shader_parameter("depth") != null else 0.0
	var dk := move_toward(cur, _depth, delta * 0.2)
	ocean.set_depth(dk)
	env.fog_density = lerpf(0.012, 0.04, dk)
	env.fog_light_color = Color("0a1424").lerp(Color("05070c"), dk)
	env.ambient_light_energy = lerpf(0.5, 0.18, dk)
	sky_mat.set_shader_parameter("gloom", dk)
	lighthouse_beam.rotation.y += delta * 0.5
	for b in get_tree().get_nodes_in_group("buoys"):
		var n := b as Node3D
		n.position.y = Ocean.height(n.position.x, n.position.z) * 0.8 - 0.1
		n.rotation.z = sin(Ocean.time + float(n.get_meta("bob"))) * 0.15
