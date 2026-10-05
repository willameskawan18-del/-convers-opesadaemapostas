class_name WorldKit
## Funções utilitárias para montar geometria procedural (caixas, cilindros, placas).

static var _mats: Dictionary = {}
static var _box_meshes: Dictionary = {}


static func mat(c: Color, rough: float = 0.85, metal: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.2f" % [c.to_html(), rough, metal, emission.to_html(), emission_energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "%.2f,%.2f,%.2f" % [size.x, size.y, size.z]
	if not _box_meshes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_box_meshes[key] = b
	return _box_meshes[key]


## Caixa visual (sem colisão). pos = centro.
static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, cast_shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.material_override = material
	mi.position = pos
	if not cast_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Caixa com colisão estática.
static func solid(parent: Node, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	if material:
		var mi := MeshInstance3D.new()
		mi.mesh = box_mesh(size)
		mi.material_override = material
		body.add_child(mi)
	return body


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, material: Material, sides: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = sides
	mi.mesh = c
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label(parent: Node, text: String, pos: Vector3, size: int = 64, color: Color = Color.WHITE, outline: int = 12, billboard: bool = false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = true
	parent.add_child(l)
	return l
