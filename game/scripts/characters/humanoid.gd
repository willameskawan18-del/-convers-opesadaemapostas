class_name Humanoid
extends Node3D
## Personagem estilizado montado com primitivas articuladas (quadril, joelho, ombro,
## cotovelo, cabeça). Malhas e materiais são compartilhados entre instâncias.
## Frente do modelo = +Z. Animação procedural de caminhada e de respiração.

static var _meshes: Dictionary = {}

const HAIR_STYLES := 5

var body_color := Color(0.2, 0.4, 0.8)
var _pelvis: Node3D
var _spine: Node3D
var _head: Node3D
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _shirt_meshes: Array[MeshInstance3D] = []
var _phase := 0.0
var _t := 0.0
var _amp := 0.0


## Mantido para compatibilidade com código antigo (materiais simples por cor).
static func mat(c: Color, _rough: float = 0.8) -> Material:
	return Mats.cloth(c)


static func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		"torso":
			m = _capsule(0.19, 0.62)
		"hips":
			m = _capsule(0.16, 0.36)
		"head":
			var s := SphereMesh.new()
			s.radius = 0.125
			s.height = 0.27
			m = s
		"neck":
			var c := CylinderMesh.new()
			c.top_radius = 0.05
			c.bottom_radius = 0.06
			c.height = 0.14
			m = c
		"upper_arm":
			m = _capsule(0.055, 0.32)
		"forearm":
			m = _capsule(0.048, 0.3)
		"hand":
			var h := SphereMesh.new()
			h.radius = 0.05
			h.height = 0.11
			m = h
		"thigh":
			m = _capsule(0.08, 0.46)
		"shin":
			m = _capsule(0.065, 0.44)
		"shoe":
			var b := BoxMesh.new()
			b.size = Vector3(0.11, 0.08, 0.26)
			m = b
		"eye":
			var e := SphereMesh.new()
			e.radius = 0.016
			e.height = 0.032
			e.radial_segments = 8
			e.rings = 4
			m = e
		"hair_cap":
			var hc := SphereMesh.new()
			hc.radius = 0.135
			hc.height = 0.16
			hc.is_hemisphere = true
			m = hc
		"hair_long":
			var hl := BoxMesh.new()
			hl.size = Vector3(0.24, 0.26, 0.08)
			m = hl
		"bun":
			var bn := SphereMesh.new()
			bn.radius = 0.06
			bn.height = 0.12
			m = bn
		"hat":
			var ht := CylinderMesh.new()
			ht.top_radius = 0.12
			ht.bottom_radius = 0.135
			ht.height = 0.09
			m = ht
		"brim":
			var br := BoxMesh.new()
			br.size = Vector3(0.2, 0.015, 0.12)
			m = br
	_meshes[kind] = m
	return m


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


func _part(parent: Node3D, kind: String, material: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.material_override = material
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## style: estilo de cabelo (0..4); -1 escolhe pelo hash da cor da camisa.
func setup(shirt: Color, pants: Color = Color(0.15, 0.15, 0.2), skin: Color = Color(0.85, 0.65, 0.5), hair: Color = Color(0.1, 0.07, 0.05), style: int = -1) -> void:
	for c in get_children():
		if not (c is Area3D) and not (c is Label3D):
			c.queue_free()
	_thighs.clear()
	_knees.clear()
	_shoulders.clear()
	_elbows.clear()
	_shirt_meshes.clear()
	body_color = shirt
	if style < 0:
		style = absi(hash(shirt.to_html() + pants.to_html())) % HAIR_STYLES
	var m_shirt := Mats.cloth(shirt)
	var m_pants := Mats.cloth(pants)
	var m_skin := Mats.skin(skin)
	var m_hair := Mats.cloth(hair)
	var m_shoe := Mats.plastic(Color(0.08, 0.08, 0.09), 0.4)
	_pelvis = _joint(self, Vector3(0, 0.9, 0))
	_part(_pelvis, "hips", m_pants, Vector3(0, 0.02, 0), Vector3(1.0, 0.55, 0.7)).rotation.z = PI / 2
	_spine = _joint(_pelvis, Vector3(0, 0.06, 0))
	_shirt_meshes.append(_part(_spine, "torso", m_shirt, Vector3(0, 0.3, 0), Vector3(1.15, 1.0, 0.72)))
	_part(_spine, "neck", m_skin, Vector3(0, 0.63, 0))
	_head = _joint(_spine, Vector3(0, 0.76, 0))
	_part(_head, "head", m_skin, Vector3.ZERO, Vector3(0.95, 1.05, 1.0))
	var m_eye := Mats.plastic(Color(0.05, 0.04, 0.04), 0.2)
	for sx in [-1.0, 1.0]:
		_part(_head, "eye", m_eye, Vector3(0.042 * sx, 0.02, 0.112))
	match style:
		0:
			_part(_head, "hair_cap", m_hair, Vector3(0, 0.03, -0.01), Vector3(1.0, 0.9, 1.05))
		1:
			_part(_head, "hair_cap", m_hair, Vector3(0, 0.045, -0.005), Vector3(0.97, 0.6, 1.0))
		2:
			_part(_head, "hair_cap", m_hair, Vector3(0, 0.03, -0.01), Vector3(1.03, 0.95, 1.08))
			_part(_head, "hair_long", m_hair, Vector3(0, -0.07, -0.08))
		3:
			_part(_head, "hair_cap", m_hair, Vector3(0, 0.03, -0.01), Vector3(1.0, 0.9, 1.05))
			_part(_head, "bun", m_hair, Vector3(0, 0.1, -0.11))
		_:
			var m_hat := Mats.cloth(shirt.darkened(0.35))
			_part(_head, "hat", m_hat, Vector3(0, 0.1, 0))
			_part(_head, "brim", m_hat, Vector3(0, 0.07, 0.11))
	for sx in [-1.0, 1.0]:
		var sh := _joint(_spine, Vector3(0.235 * sx, 0.52, 0))
		_shirt_meshes.append(_part(sh, "upper_arm", m_shirt, Vector3(0, -0.15, 0)))
		var el := _joint(sh, Vector3(0, -0.3, 0))
		_part(el, "forearm", m_skin, Vector3(0, -0.14, 0))
		_part(el, "hand", m_skin, Vector3(0, -0.31, 0.01))
		sh.rotation.z = 0.08 * sx
		_shoulders.append(sh)
		_elbows.append(el)
		var hip := _joint(_pelvis, Vector3(0.1 * sx, 0.0, 0))
		_part(hip, "thigh", m_pants, Vector3(0, -0.22, 0))
		var kn := _joint(hip, Vector3(0, -0.43, 0))
		_part(kn, "shin", m_pants, Vector3(0, -0.21, 0))
		_part(kn, "shoe", m_shoe, Vector3(0, -0.43, 0.05))
		_thighs.append(hip)
		_knees.append(kn)
	_t = randf() * 10.0


func set_shirt(c: Color) -> void:
	body_color = c
	var m := Mats.cloth(c)
	for mi in _shirt_meshes:
		mi.material_override = m


## speed em m/s; chamar a cada frame.
func animate(speed: float, delta: float) -> void:
	if _thighs.size() < 2:
		return
	_t += delta
	var target_amp := clampf(speed / 5.0, 0.0, 1.0)
	_amp = lerpf(_amp, target_amp, minf(1.0, delta * 8.0))
	if speed > 0.1:
		_phase += delta * (3.2 + speed * 1.55)
	var s := sin(_phase)
	var a := _amp
	var stride := 0.35 + a * 0.45
	for i in 2:
		var sign_i := 1.0 if i == 0 else -1.0
		var ls := s * sign_i
		_thighs[i].rotation.x = ls * stride * a
		_knees[i].rotation.x = maxf(0.0, sin(_phase * sign_i + (0.0 if i == 0 else PI) - 1.2)) * 1.1 * a
		_shoulders[i].rotation.x = -ls * (0.25 + 0.5 * a) * a
		_elbows[i].rotation.x = -0.25 - 0.45 * a - maxf(0.0, -ls) * 0.3 * a
	_pelvis.position.y = 0.9 + absf(cos(_phase)) * 0.045 * a - 0.02 * a
	_spine.rotation.y = s * 0.12 * a
	_spine.rotation.x = 0.08 * a
	# Respiração (parado)
	var breath := sin(_t * 1.8) * 0.012 * (1.0 - a)
	_spine.scale = Vector3(1.0, 1.0 + breath, 1.0 + breath * 0.5)
	if a < 0.05:
		for i in 2:
			_shoulders[i].rotation.x = lerpf(_shoulders[i].rotation.x, sin(_t * 0.9 + i) * 0.03, minf(1.0, delta * 4.0))
			_elbows[i].rotation.x = lerpf(_elbows[i].rotation.x, -0.15, minf(1.0, delta * 4.0))
	_head.rotation.y = sin(_t * 0.37) * 0.15 * (1.0 - a)


func set_head_visible(v: bool) -> void:
	if _head:
		_head.visible = v
