class_name Boat
extends Node3D
## Barco de pesca: casco, convés, cabine com timão, lanterna, motor, caixa térmica.
## O convés é o "mundo" dos pescadores (eles são filhos deste nó).

var lantern_light: OmniLight3D
var lantern_bulb: MeshInstance3D
var engine_smoke: CPUParticles3D
var deck: Node3D
var leaks: Dictionary = {}      # id -> Node3D
var wheel_pos := Vector3(0, 1.35, -1.25)
var cooler_pos := Vector3(0.75, 0.95, 0.4)
var _shake := 0.0


func _ready() -> void:
	var hull_mat := M3.solid(Color("e8e2d0"), 0.6)
	var red := M3.solid(Color("b0302a"), 0.6)
	var wood := M3.solid(Color("7a5634"), 0.85)
	# casco
	M3.box(self, Vector3(2.6, 0.9, 6.0), Vector3(0, 0.1, -0.4), hull_mat)
	M3.box(self, Vector3(2.62, 0.25, 6.02), Vector3(0, -0.3, -0.4), red)
	var bow := M3.box(self, Vector3(1.85, 0.9, 1.85), Vector3(0, 0.1, 2.6), hull_mat)
	bow.rotation.y = PI / 4
	bow.scale = Vector3(1.0, 1.0, 1.0)
	var bow_red := M3.box(self, Vector3(1.86, 0.25, 1.86), Vector3(0, -0.3, 2.6), red)
	bow_red.rotation.y = PI / 4
	# convés e amuradas
	deck = Node3D.new()
	add_child(deck)
	M3.box(deck, Vector3(2.4, 0.06, 5.8), Vector3(0, 0.56, -0.4), wood)
	for sx in [-1.25, 1.25]:
		M3.box(self, Vector3(0.08, 0.45, 5.6), Vector3(sx, 0.8, -0.3), hull_mat)
		M3.box(self, Vector3(0.1, 0.05, 5.6), Vector3(sx, 1.05, -0.3), wood)
	M3.box(self, Vector3(2.6, 0.45, 0.08), Vector3(0, 0.8, -3.4), hull_mat)
	# cabine
	var cab := M3.solid(Color("dfe6ea"), 0.5)
	M3.box(self, Vector3(2.2, 1.7, 0.08), Vector3(0, 1.4, -3.3), cab)
	for sx in [-1.08, 1.08]:
		M3.box(self, Vector3(0.08, 1.7, 1.6), Vector3(sx, 1.4, -2.5), cab)
	M3.box(self, Vector3(2.3, 0.1, 1.9), Vector3(0, 2.3, -2.45), M3.solid(Color("2e5a7a"), 0.5))
	var glass := M3.solid(Color(0.6, 0.8, 0.9), 0.05, 0.3)
	M3.box(self, Vector3(2.0, 0.6, 0.04), Vector3(0, 1.85, -1.7), glass)
	# painel e timão
	M3.box(self, Vector3(1.2, 0.8, 0.4), Vector3(0, 0.95, -1.6), M3.solid(Color("3a3f45"), 0.5, 0.4))
	var wheel := M3.torus(self, 0.22, 0.27, wheel_pos + Vector3(0, 0, 0.12), M3.solid(Color("8b5a2b"), 0.6))
	wheel.rotation.x = PI / 2 - 0.4
	M3.label(self, "TIMÃO", wheel_pos + Vector3(0, 0.4, 0.2), 14, Color("ffcc33"), 4, true)
	# caixa térmica
	M3.box(self, Vector3(0.7, 0.5, 0.5), cooler_pos + Vector3(0, -0.15, 0), M3.solid(Color("2b7bd6"), 0.4))
	M3.box(self, Vector3(0.72, 0.08, 0.52), cooler_pos + Vector3(0, 0.12, 0), M3.solid(Color("f2f2f2"), 0.4))
	M3.label(self, "PEIXES", cooler_pos + Vector3(0, 0.45, 0), 14, Color("27e1ff"), 4, true)
	# motor de popa
	M3.box(self, Vector3(0.6, 0.9, 0.6), Vector3(0, 1.0, -3.8), M3.solid(Color("222428"), 0.4, 0.5))
	engine_smoke = CPUParticles3D.new()
	engine_smoke.position = Vector3(0, 1.5, -3.9)
	engine_smoke.amount = 24
	engine_smoke.lifetime = 1.6
	engine_smoke.direction = Vector3(0, 1, -0.3)
	engine_smoke.spread = 15
	engine_smoke.initial_velocity_min = 0.5
	engine_smoke.initial_velocity_max = 1.2
	engine_smoke.scale_amount_min = 0.2
	engine_smoke.scale_amount_max = 0.5
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.radial_segments = 6
	sm.rings = 3
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.3, 0.3, 0.32, 0.35)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smoke_mat
	engine_smoke.mesh = sm
	engine_smoke.emitting = false
	add_child(engine_smoke)
	# lanterna no mastro da proa
	M3.cylinder(self, 0.04, 0.05, 2.0, Vector3(-0.95, 1.55, -1.45), M3.solid(Color("777777"), 0.4, 0.8), 8)
	lantern_bulb = M3.sphere(self, 0.14, Vector3(-0.95, 2.6, -1.45), M3.glow(Color("ffd27a"), 1.6), 12)
	lantern_light = OmniLight3D.new()
	lantern_light.position = Vector3(-0.95, 2.55, -1.45)
	lantern_light.light_color = Color("ffd9a0")
	lantern_light.light_energy = 3.0
	lantern_light.omni_range = 20.0
	lantern_light.shadow_enabled = true
	add_child(lantern_light)
	var cab_light := OmniLight3D.new()
	cab_light.position = Vector3(0, 2.0, -2.5)
	cab_light.light_color = Color("9fd0ff")
	cab_light.light_energy = 0.6
	cab_light.omni_range = 4.0
	add_child(cab_light)
	# nome
	M3.label(self, "ESPERANÇA", Vector3(1.32, 0.3, -1.0), 30, Color("1a2a3a"), 0).rotation.y = PI / 2
	# boias salva-vidas
	for z in [0.8, -1.0]:
		var ring := M3.torus(self, 0.16, 0.26, Vector3(-1.3, 0.85, z), M3.solid(Color("ff6a00"), 0.6))
		ring.rotation.z = PI / 2


func set_lantern(on: bool) -> void:
	lantern_light.visible = on
	lantern_bulb.material_override = M3.glow(Color("ffd27a"), 1.6) if on else M3.solid(Color("443a2a"), 0.6)


func set_engine(on: bool) -> void:
	engine_smoke.emitting = on


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Mantém os vazamentos (jatos de água) em sincronia com o host.
func sync_leaks(list: Array) -> void:
	var ids := {}
	for l in list:
		var id := int(l[0])
		ids[id] = true
		if not leaks.has(id):
			var n := Node3D.new()
			n.position = l[1]
			add_child(n)
			var p := CPUParticles3D.new()
			p.amount = 40
			p.lifetime = 0.8
			p.direction = Vector3(-signf(n.position.x), 0.6, 0)
			p.spread = 20
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 3.5
			p.gravity = Vector3(0, -9, 0)
			var dm := SphereMesh.new()
			dm.radius = 0.04
			dm.height = 0.08
			dm.radial_segments = 4
			dm.rings = 2
			dm.material = M3.glow(Color("8fd3ff"), 0.6)
			p.mesh = dm
			n.add_child(p)
			M3.label(n, "VAZAMENTO [E]", Vector3(0, 0.6, 0), 18, Color("ff4d6d"), 6, true)
			leaks[id] = n
	for id in leaks.keys():
		if not ids.has(id):
			leaks[id].queue_free()
			leaks.erase(id)


## Balanço do barco nas ondas (posição/rotação do host + ondas locais).
func place(pos: Vector3, yaw: float, delta: float) -> void:
	var h := Ocean.height(pos.x, pos.z)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var hf := Ocean.height(pos.x + fwd.x * 2.5, pos.z + fwd.z * 2.5)
	var hb := Ocean.height(pos.x - fwd.x * 2.5, pos.z - fwd.z * 2.5)
	var hr := Ocean.height(pos.x + right.x * 1.2, pos.z + right.z * 1.2)
	var hl := Ocean.height(pos.x - right.x * 1.2, pos.z - right.z * 1.2)
	var pitch := atan2(hb - hf, 5.0) * 0.6
	var roll := atan2(hl - hr, 2.4) * 0.6
	_shake = maxf(0.0, _shake - delta * 1.5)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.08
	global_position = Vector3(pos.x, h * 0.8 - 0.15, pos.z) + sh
	rotation = Vector3(pitch + sh.x, yaw, roll + sh.z)
