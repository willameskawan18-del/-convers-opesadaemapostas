class_name ItemProp
## Monta um "objeto de galpão" com formas simples a partir do formato e da cor.


static func build(shape: String, col: String, seed_v: int) -> Node3D:
	var n := Node3D.new()
	var c := Color(col)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mat := M3.solid(c, 0.7)
	var card := M3.solid(Color("b08a5a"), 0.9)
	match shape:
		"box":
			var s := Vector3(rng.randf_range(0.5, 0.9), rng.randf_range(0.4, 0.8), rng.randf_range(0.5, 0.8))
			M3.box(n, s, Vector3(0, s.y / 2, 0), card if rng.randf() < 0.5 else mat)
			M3.box(n, Vector3(s.x * 1.01, 0.06, 0.1), Vector3(0, s.y - 0.02, 0), M3.solid(Color("d9c08a"), 0.9))
		"tall":
			var h := rng.randf_range(1.2, 1.9)
			M3.box(n, Vector3(0.7, h, 0.5), Vector3(0, h / 2, 0), mat)
			M3.box(n, Vector3(0.05, 0.12, 0.05), Vector3(0.25, h * 0.55, 0.27), M3.solid(Color("d4af37"), 0.3, 0.8))
		"flat":
			var f := M3.box(n, Vector3(1.0, 0.8, 0.08), Vector3(0, 0.55, 0), M3.solid(Color("6d4c2f"), 0.6))
			f.rotation.x = -0.25
			var inner := M3.box(n, Vector3(0.84, 0.64, 0.03), Vector3(0, 0.56, 0.05), mat)
			inner.rotation.x = -0.25
		"round":
			var cyl := M3.cylinder(n, 0.35, 0.38, 0.7, Vector3(0, 0.35, 0), mat, 16)
			cyl.rotation.z = 0.0 if rng.randf() < 0.6 else PI / 2
		"long":
			var l := M3.box(n, Vector3(1.5, 0.22, 0.35), Vector3(0, 0.6, 0), mat)
			l.rotation.z = 0.5
			M3.box(n, Vector3(0.12, 1.0, 0.12), Vector3(-0.4, 0.5, 0), M3.solid(Color("444444"), 0.5, 0.5))
		_:
			M3.box(n, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), mat)
	return n


## Lona cobrindo um item escondido.
static func tarp(seed_v: int) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var s := M3.sphere(n, 0.6, Vector3(0, 0.25, 0), M3.solid(Color("3d4a3a").darkened(rng.randf() * 0.3), 0.95), 12)
	s.scale = Vector3(rng.randf_range(1.0, 1.6), rng.randf_range(0.6, 1.3), rng.randf_range(0.9, 1.3))
	return n
