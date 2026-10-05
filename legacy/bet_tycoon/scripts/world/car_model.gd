class_name CarModel
## Carro estilizado: carroceria com pintura metálica, cabine de vidro, faróis, lanternas e rodas.

const COLORS := [Color("c0392b"), Color("1f4e9c"), Color("ecf0f1"), Color("1b1b1f"), Color("d4a017"), Color("2e7d4f"), Color("7f8c8d"), Color("8e44ad"), Color("e67e22")]


static func build(color: Color, with_collision: bool = false, taxi: bool = false) -> Node3D:
	var car := Node3D.new()
	var paint := Mats.car_paint(color)
	var dark := Mats.plastic(Color(0.06, 0.06, 0.07), 0.5)
	var glass := Mats.window_glass(0.0)
	if with_collision:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(4.3, 1.4, 1.85)
		cs.shape = sh
		cs.position.y = 0.75
		body.add_child(cs)
		car.add_child(body)
	# Carroceria em camadas para formar o perfil
	WorldKit.box(car, Vector3(4.3, 0.5, 1.82), Vector3(0, 0.62, 0), paint)
	WorldKit.box(car, Vector3(4.1, 0.16, 1.78), Vector3(0, 0.95, 0), paint)
	var cabin := WorldKit.box(car, Vector3(2.2, 0.5, 1.62), Vector3(-0.25, 1.28, 0), glass)
	cabin.scale = Vector3(1, 1, 1)
	WorldKit.box(car, Vector3(2.0, 0.07, 1.6), Vector3(-0.25, 1.56, 0), paint)
	# Colunas
	for z in [-0.78, 0.78]:
		WorldKit.box(car, Vector3(0.12, 0.5, 0.06), Vector3(0.8, 1.28, z), paint)
		WorldKit.box(car, Vector3(0.12, 0.5, 0.06), Vector3(-1.3, 1.28, z), paint)
	# Para-choques
	WorldKit.box(car, Vector3(0.16, 0.24, 1.86), Vector3(2.18, 0.5, 0), dark)
	WorldKit.box(car, Vector3(0.16, 0.24, 1.86), Vector3(-2.18, 0.5, 0), dark)
	# Faróis e lanternas
	for z in [-0.62, 0.62]:
		WorldKit.box(car, Vector3(0.06, 0.14, 0.34), Vector3(2.16, 0.78, z), Mats.glow(Color(1.0, 0.97, 0.85), 2.5), false)
		WorldKit.box(car, Vector3(0.06, 0.12, 0.36), Vector3(-2.16, 0.78, z), Mats.glow(Color(1.0, 0.1, 0.08), 2.0), false)
	# Grade
	WorldKit.box(car, Vector3(0.05, 0.14, 0.7), Vector3(2.17, 0.66, 0), dark, false)
	# Retrovisores
	for z in [-0.98, 0.98]:
		WorldKit.box(car, Vector3(0.14, 0.1, 0.12), Vector3(0.75, 1.05, z), paint, false)
	# Rodas
	var tire := Mats.plastic(Color(0.05, 0.05, 0.05), 0.85)
	var rim := Mats.metal(Color(0.75, 0.76, 0.78), 0.25)
	var wheels: Array = []
	for x in [-1.35, 1.35]:
		for z in [-0.88, 0.88]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.36, z)
			car.add_child(w)
			var t := WorldKit.cylinder(w, 0.36, 0.26, Vector3.ZERO, tire, 14)
			t.rotation.x = PI / 2
			var r := WorldKit.cylinder(w, 0.22, 0.28, Vector3.ZERO, rim, 10)
			r.rotation.x = PI / 2
			wheels.append(w)
	if taxi:
		WorldKit.box(car, Vector3(0.6, 0.18, 0.35), Vector3(-0.25, 1.68, 0), Mats.glow(Color(1, 0.85, 0.2), 1.5), false)
	car.set_meta("wheels", wheels)
	return car
