class_name Traffic
extends Node3D
## Trânsito ambiente na avenida: carros em duas faixas que param no sinal vermelho,
## atrás de outros carros e diante do jogador. Sem física (barato).

const LANES := [{"z": -2.6, "dir": 1.0}, {"z": 2.6, "dir": -1.0}]
const LIMIT := 112.0
const SPEED := 9.0
const LIGHT_X := [-40.0, 40.0]
const GREEN_TIME := 14.0
const RED_TIME := 8.0

var cars: Array = []
var lights: Array = []   # [Node3D de cada semáforo, materiais]
var _t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 99
	for lane in LANES:
		for i in 4:
			var col: Color = CarModel.COLORS[rng.randi_range(0, CarModel.COLORS.size() - 1)]
			var node := CarModel.build(col, false, rng.randf() < 0.2)
			add_child(node)
			var x := -LIMIT + i * (LIMIT * 2.0 / 4.0) + rng.randf_range(0, 20)
			node.position = Vector3(x, 0.02, lane.z)
			node.rotation.y = 0.0 if lane.dir > 0 else PI
			cars.append({"node": node, "lane": lane, "speed": SPEED * rng.randf_range(0.8, 1.1), "v": 0.0})
	# Ônibus amarelo que para no ponto
	var bus := _build_bus()
	add_child(bus)
	bus.position = Vector3(80, 0.02, LANES[1].z)
	bus.rotation.y = PI
	cars.append({"node": bus, "lane": LANES[1], "speed": 7.0, "v": 0.0, "bus": true, "stop_t": 0.0, "stopped_lap": false})
	for x in LIGHT_X:
		for side in [-1.0, 1.0]:
			_build_light(Vector3(x - side * 6.5, 0, side * 7.6), side)


func _build_bus() -> Node3D:
	var b := Node3D.new()
	var yellow := Mats.car_paint(Color(0.98, 0.75, 0.1))
	WorldKit.box(b, Vector3(10.0, 2.4, 2.5), Vector3(0, 1.6, 0), yellow)
	WorldKit.box(b, Vector3(9.4, 0.9, 2.52), Vector3(-0.2, 2.15, 0), Mats.window_glass(0.0), false)
	WorldKit.box(b, Vector3(10.05, 0.18, 2.55), Vector3(0, 1.25, 0), Mats.car_paint(Color(0.1, 0.45, 0.25)), false)
	WorldKit.box(b, Vector3(0.06, 1.3, 2.2), Vector3(5.02, 2.0, 0), Mats.window_glass(0.0), false)
	WorldKit.box(b, Vector3(0.08, 0.3, 1.6), Vector3(5.03, 2.85, 0), Mats.glow(Color(1.0, 0.6, 0.1), 2.0), false)
	for z in [-0.85, 0.85]:
		WorldKit.box(b, Vector3(0.06, 0.18, 0.4), Vector3(5.03, 0.8, z), Mats.glow(Color(1, 0.97, 0.85), 2.5), false)
		WorldKit.box(b, Vector3(0.06, 0.18, 0.4), Vector3(-5.03, 0.8, z), Mats.glow(Color(1, 0.1, 0.08), 2.0), false)
	var tire := Mats.plastic(Color(0.05, 0.05, 0.05), 0.85)
	var wheels: Array = []
	for x in [-3.3, 3.3]:
		for z in [-1.15, 1.15]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.5, z)
			b.add_child(w)
			var t := WorldKit.cylinder(w, 0.5, 0.3, Vector3.ZERO, tire, 14)
			t.rotation.x = PI / 2
			wheels.append(w)
	var l := WorldKit.label(b, "CIRCULAR - CENTRO", Vector3(0, 2.75, 1.27), 40, Color(0.1, 0.3, 0.15), 0)
	l.modulate = Color(0.08, 0.3, 0.15)
	b.set_meta("wheels", wheels)
	return b


func _build_light(pos: Vector3, side: float) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var pole := Mats.metal(Color(0.15, 0.16, 0.18), 0.5)
	WorldKit.cylinder(n, 0.08, 4.2, Vector3(0, 2.1, 0), pole, 8)
	WorldKit.box(n, Vector3(0.1, 0.1, 2.4), Vector3(0, 4.1, -side * 1.2), pole)
	var housing := WorldKit.box(n, Vector3(0.35, 1.0, 0.35), Vector3(0, 3.6, -side * 2.3), Mats.plastic(Color(0.08, 0.08, 0.09)))
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mats := []
	var cols := [Color(1, 0.1, 0.05), Color(1, 0.75, 0.1), Color(0.1, 1, 0.35)]
	for i in 3:
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i].darkened(0.7)
		m.emission_enabled = true
		m.emission = cols[i]
		m.emission_energy_multiplier = 0.0
		WorldKit.sphere(n, 0.11, Vector3(0.18 * (1 if side > 0 else -1) * 0.0 + 0.19, 3.9 - i * 0.3, -side * 2.3), m)
		mats.append(m)
	lights.append(mats)


## Estado do sinal da avenida: "green", "yellow" ou "red".
func signal_state() -> String:
	var cyc := fmod(_t, GREEN_TIME + RED_TIME)
	if cyc < GREEN_TIME - 2.5:
		return "green"
	if cyc < GREEN_TIME:
		return "yellow"
	return "red"


func _process(delta: float) -> void:
	_t += delta
	var stt := signal_state()
	for mats in lights:
		mats[0].emission_energy_multiplier = 3.0 if stt == "red" else 0.0
		mats[1].emission_energy_multiplier = 3.0 if stt == "yellow" else 0.0
		mats[2].emission_energy_multiplier = 3.0 if stt == "green" else 0.0
	var player: Node3D = Game.player if Game.playing and is_instance_valid(Game.player) else null
	for c in cars:
		var node: Node3D = c.node
		var dir: float = c.lane.dir
		var x := node.position.x
		var target_v: float = c.speed
		# Carro da frente
		for o in cars:
			if o == c or o.lane != c.lane:
				continue
			var gap: float = (o.node.position.x - x) * dir
			if gap > 0.0 and gap < 9.0:
				target_v = minf(target_v, maxf(0.0, (gap - 5.5) * 2.0))
		# Semáforo
		if stt != "green":
			for lx in LIGHT_X:
				var stop_x: float = lx - dir * 8.5
				var dist: float = (stop_x - x) * dir
				if dist > 0.0 and dist < 14.0:
					target_v = minf(target_v, maxf(0.0, dist - 1.0) * 1.2)
		# Ônibus para no ponto (x = 30) uma vez por volta
		if c.get("bus", false):
			var dist_stop: float = (30.0 - x) * dir
			if not c.stopped_lap and dist_stop > 0.0 and dist_stop < 12.0:
				target_v = minf(target_v, maxf(0.0, dist_stop - 0.5) * 0.9)
				if dist_stop < 1.0:
					c.stop_t = float(c.stop_t) + delta
					if float(c.stop_t) > 4.0:
						c.stopped_lap = true
						c.stop_t = 0.0
			if dist_stop < -20.0:
				c.stopped_lap = false
		# Jogador na pista
		if player:
			var dz: float = absf(player.global_position.z - c.lane.z)
			var dx: float = (player.global_position.x - x) * dir
			if dz < 2.2 and dx > 0.0 and dx < 10.0:
				target_v = minf(target_v, maxf(0.0, dx - 4.0))
		c.v = move_toward(float(c.v), target_v, delta * (6.0 if target_v < c.v else 3.0))
		x += float(c.v) * dir * delta
		if x * dir > LIMIT:
			x = -LIMIT * dir
		node.position.x = x
		for w in node.get_meta("wheels"):
			w.rotation.z -= float(c.v) * delta / 0.36 * dir * (1.0 if dir > 0 else -1.0)
