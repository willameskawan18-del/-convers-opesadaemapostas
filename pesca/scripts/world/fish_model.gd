class_name FishModel
## Peixe 3D simples (corpo, cauda, barbatana, olhos, brilho) a partir dos dados da captura.


static func build(f: Dictionary) -> Node3D:
	var n := Node3D.new()
	var col := Color(str(f.get("color", "#9fb4c8")))
	var size := clampf(float(f.get("size", 0.5)), 0.25, 2.2)
	var glow := bool(f.get("glow", false))
	var body_mat := M3.solid(col, 0.35, 0.2)
	if glow:
		body_mat = body_mat.duplicate()
		body_mat.emission_enabled = true
		body_mat.emission = col.lightened(0.3)
		body_mat.emission_energy_multiplier = 0.8
	var body := M3.sphere(n, 0.5, Vector3.ZERO, body_mat, 18)
	body.scale = Vector3(0.38, 0.5, 1.0) * size
	var belly := M3.sphere(n, 0.45, Vector3(0, -0.05 * size, 0.02 * size), M3.solid(col.lightened(0.35), 0.4), 14)
	belly.scale = Vector3(0.32, 0.35, 0.85) * size
	var tail := M3.box(n, Vector3(0.04, 0.45, 0.32) * size, Vector3(0, 0, -0.55 * size), M3.solid(col.darkened(0.2), 0.5))
	tail.name = "Tail"
	var fin := M3.box(n, Vector3(0.03, 0.22, 0.35) * size, Vector3(0, 0.27 * size, -0.05 * size), M3.solid(col.darkened(0.15), 0.5))
	fin.rotation.x = -0.3
	for sx in [-1.0, 1.0]:
		M3.sphere(n, 0.06 * size, Vector3(sx * 0.15 * size, 0.07 * size, 0.33 * size), M3.solid(Color.WHITE, 0.2), 10)
		M3.sphere(n, 0.035 * size, Vector3(sx * 0.18 * size, 0.07 * size, 0.36 * size), M3.solid(Color.BLACK, 0.2), 8)
	if glow:
		var lure := M3.sphere(n, 0.06 * size, Vector3(0, 0.45 * size, 0.45 * size), M3.glow(Color("fff27a"), 4.0), 8)
		lure.name = "Lure"
		var l := OmniLight3D.new()
		l.light_color = col.lightened(0.4)
		l.light_energy = 1.5
		l.omni_range = 3.0
		n.add_child(l)
	return n


## Respingo na água.
static func splash(parent: Node, pos: Vector3, big: bool = false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40 if big else 18
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 35
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0 if big else 3.5
	p.gravity = Vector3(0, -9.8, 0)
	var m := SphereMesh.new()
	m.radius = 0.05
	m.height = 0.1
	m.radial_segments = 4
	m.rings = 2
	m.material = M3.glow(Color("cfefff"), 0.8)
	p.mesh = m
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
