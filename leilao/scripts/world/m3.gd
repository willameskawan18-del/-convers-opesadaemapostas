class_name M3
## Materiais e malhas 3D simples (estilo cartoon de game show), com cache.

static var _cache: Dictionary = {}


static func solid(c: Color, rough: float = 0.45, metal: float = 0.0, rim: bool = true) -> StandardMaterial3D:
	var key := "s%s%.2f%.2f%s" % [c.to_html(), rough, metal, rim]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if rim:
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.4
	_cache[key] = m
	return m


static func glow(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "g%s%.2f" % [c.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


static func beam(c: Color, alpha: float = 0.1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c, alpha)
	m.disable_receive_shadows = true
	return m


static func mesh(parent: Node, m: Mesh, pos: Vector3, mat: Material, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, shadows: bool = true) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh(parent, b, pos, mat, shadows)


static func sphere(parent: Node, r: float, pos: Vector3, mat: Material, segs: int = 24) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(6, segs / 2)
	return mesh(parent, s, pos, mat)


static func cylinder(parent: Node, r_top: float, r_bottom: float, h: float, pos: Vector3, mat: Material, segs: int = 32) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = segs
	return mesh(parent, c, pos, mat)


static func capsule(parent: Node, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 24
	c.rings = 8
	return mesh(parent, c, pos, mat)


static func torus(parent: Node, inner: float, outer: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	t.ring_segments = 12
	return mesh(parent, t, pos, mat)


static func label(parent: Node, text: String, pos: Vector3, size: int = 48, color: Color = Color.WHITE, outline: int = 10, billboard: bool = false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = AW.font("ExtraBold")
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l
