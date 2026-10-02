class_name Humanoid
extends Node3D
## Personagem estilizado montado com primitivas (sem assets externos).
## Malhas e materiais são compartilhados entre instâncias para economizar memória/draw setup.
## Animação procedural simples de caminhada.

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _phase := 0.0
var _head: Node3D
var body_color := Color(0.2, 0.4, 0.8)


static func mat(c: Color, rough: float = 0.8) -> StandardMaterial3D:
	var key := c.to_html() + str(rough)
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_materials[key] = m
	return _materials[key]


static func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		"torso":
			var c := CapsuleMesh.new()
			c.radius = 0.26
			c.height = 0.8
			m = c
		"head":
			var s := SphereMesh.new()
			s.radius = 0.17
			s.height = 0.34
			m = s
		"limb":
			var c2 := CapsuleMesh.new()
			c2.radius = 0.08
			c2.height = 0.7
			m = c2
		"arm":
			var c3 := CapsuleMesh.new()
			c3.radius = 0.065
			c3.height = 0.62
			m = c3
		"hair":
			var s2 := SphereMesh.new()
			s2.radius = 0.18
			s2.height = 0.2
			s2.is_hemisphere = true
			m = s2
	_meshes[kind] = m
	return m


func setup(shirt: Color, pants: Color = Color(0.15, 0.15, 0.2), skin: Color = Color(0.85, 0.65, 0.5), hair: Color = Color(0.1, 0.07, 0.05)) -> void:
	for c in get_children():
		c.queue_free()
	_legs.clear()
	_arms.clear()
	body_color = shirt
	var torso := _part("torso", shirt, Vector3(0, 1.15, 0))
	torso.scale = Vector3(1.0, 1.0, 0.75)
	_head = _part("head", skin, Vector3(0, 1.68, 0))
	var h := _part("hair", hair, Vector3(0, 1.72, 0))
	h.scale = Vector3(1.0, 1.0, 1.0)
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(0.12 * side, 0.78, 0)
		add_child(hip)
		var leg := MeshInstance3D.new()
		leg.mesh = _mesh("limb")
		leg.material_override = mat(pants)
		leg.position = Vector3(0, -0.36, 0)
		hip.add_child(leg)
		_legs.append(hip)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.33 * side, 1.43, 0)
		add_child(shoulder)
		var arm := MeshInstance3D.new()
		arm.mesh = _mesh("arm")
		arm.material_override = mat(shirt.darkened(0.1))
		arm.position = Vector3(0, -0.28, 0)
		shoulder.add_child(arm)
		_arms.append(shoulder)


func _part(kind: String, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.material_override = mat(c)
	mi.position = pos
	add_child(mi)
	return mi


## speed em m/s; chamar a cada frame.
func animate(speed: float, delta: float) -> void:
	if speed > 0.1:
		_phase += delta * (4.0 + speed * 1.4)
		var a := sin(_phase) * clampf(speed / 6.0, 0.25, 0.75)
		if _legs.size() == 2:
			_legs[0].rotation.x = a
			_legs[1].rotation.x = -a
			_arms[0].rotation.x = -a * 0.8
			_arms[1].rotation.x = a * 0.8
	else:
		_phase = 0.0
		for n in _legs + _arms:
			n.rotation.x = lerpf(n.rotation.x, 0.0, minf(1.0, delta * 10.0))


func set_head_visible(v: bool) -> void:
	if _head:
		_head.visible = v
